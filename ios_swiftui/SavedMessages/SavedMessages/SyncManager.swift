import Foundation

enum SyncConnectionState: Equatable {
    case offline
    case online
    case syncing
}

struct SyncSummary {
    let pushedCount: Int
    let pulledCount: Int
}

@MainActor
final class SyncManager {
    private let localStore: LocalStore
    private let apiClient: APIClient
    private let healthChecker: ServerHealthChecker
    private var isSyncing = false

    init(localStore: LocalStore, apiClient: APIClient) {
        self.localStore = localStore
        self.apiClient = apiClient
        self.healthChecker = ServerHealthChecker(apiClient: apiClient)
    }

    func start() async -> Bool {
        await healthChecker.isServerReachable()
    }

    func syncPendingItems() async throws -> SyncSummary {
        guard !isSyncing else {
            return SyncSummary(pushedCount: 0, pulledCount: 0)
        }
        isSyncing = true
        defer { isSyncing = false }

        guard await healthChecker.isServerReachable() else {
            throw URLError(.cannotConnectToHost)
        }

        var pushedCount = 0
        let pending = try localStore.getPendingItems()
        for item in pending {
            do {
                try await pushItem(item)
                pushedCount += 1
            } catch {
                if Self.isAuthorizationError(error) || Self.isTransientNetworkError(error) {
                    throw error
                }
                try localStore.markFailed(id: item.id, error: error)
            }
        }

        let pullResponse = try await pullChanges()
        return SyncSummary(pushedCount: pushedCount, pulledCount: pullResponse.items.count)
    }

    func retryFailed() async throws -> SyncSummary {
        let failed = try localStore.getRetryableFailedItems()
        for item in failed {
            guard let delay = retryDelaySeconds(for: item.retryCount) else { continue }
            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
            try localStore.markPending(id: item.id)
        }
        return try await syncPendingItems()
    }

    func pushItem(_ item: Message) async throws {
        if item.isFileBacked {
            let remote = try await apiClient.upload(item: item)
            try localStore.markSynced(item, remote: remote)
        } else {
            let response = try await apiClient.push(items: [item])
            guard response.processedItemIds.contains(item.id) else {
                throw URLError(.badServerResponse)
            }
            try localStore.markSynced(item)
        }
    }

    @discardableResult
    func pullChanges() async throws -> SyncPullResponse {
        let since = try localStore.lastSyncAt()
        let response = try await apiClient.pullChanges(since: since)
        for item in response.items {
            try localStore.upsertRemote(item)
        }
        if let cursor = response.cursor ?? response.serverTime {
            try localStore.setLastSyncAt(cursor)
        }
        return response
    }

    func retryDelaySeconds(for retryCount: Int) -> Int? {
        switch retryCount {
        case 0:
            return 5
        case 1:
            return 15
        case 2:
            return 30
        case 3:
            return 60
        default:
            return nil
        }
    }

    static func isAuthorizationError(_ error: Error) -> Bool {
        (error as? APIClientError) == .unauthorized
    }

    static func isTransientNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidServerAddress, .unauthorized, .invalidResponse:
                return true
            case .httpStatus(let statusCode):
                return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
            }
        }

        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .secureConnectionFailed,
             .serverCertificateUntrusted,
             .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .appTransportSecurityRequiresSecureConnection,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}
