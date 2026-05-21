import Combine
import Foundation
import UIKit

private enum RestReachabilityState: Equatable {
    case unknown
    case checking
    case reachable
    case unreachable
}

private enum WebSocketLifecycleState: Equatable {
    case disconnected
    case connecting
    case connected
    case suspended
    case failed
}

private enum RecoveryReason: String {
    case initialStart
    case syncNow
    case foregroundActive
    case manualRefresh
    case manualReconnect
    case connectivityAvailable
    case backgroundFetch
    case sharedImport
    case addressChanged
}

private struct RecoveryResult {
    let isServerReachable: Bool
    let didReconnectWebSocket: Bool
    let didSkipWebSocketForBackground: Bool
    let summary: SyncSummary
}

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draftText = ""
    @Published var connectionStatus = "Офлайн"
    @Published var errorText: String?
    @Published var pairingCode = ""
    @Published var pairingStatus = "Не подключено"
    @Published var isSyncing = false
    @Published var refreshState: ManualRefreshState = .idle
    @Published var syncResultText: String?
    @Published var savedFileMessageIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "savedFileMessageIds") ?? [])
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var discoveryStatus = "Bonjour не запущен"
    @Published var connectedServerInfo = "solodrop.local:8000"
    @Published var trustedDeviceStatus = "Не trusted"
    @Published var restHealthStatus = "REST unknown"
    @Published var webSocketStatus = "WS disconnected"
    @Published var autosaveEnabled = UserDefaults.standard.bool(forKey: "autosaveEnabled") {
        didSet {
            UserDefaults.standard.set(autosaveEnabled, forKey: "autosaveEnabled")
            if autosaveEnabled {
                autosaveReceivedFiles(messages)
            }
        }
    }

    @Published var manualServerAddress: String {
        didSet {
            UserDefaults.standard.set(manualServerAddress, forKey: Self.manualServerAddressKey)
        }
    }

    @Published var manualServerOverrideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(manualServerOverrideEnabled, forKey: Self.manualServerOverrideKey)
            if manualServerOverrideEnabled {
                applyManualServerOverride(triggerSync: true)
            } else {
                useBonjourDiscovery(triggerSync: true)
            }
            updateConnectedServerInfo()
        }
    }

    @Published var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: Self.serverAddressKey)
            apiClient.serverAddress = serverAddress
            updateConnectedServerInfo()
        }
    }

    let deviceId: String

    private let localStore: LocalStore
    private let apiClient: APIClient
    private let syncManager: SyncManager
    private let networkMonitor = NetworkMonitor()
    private let discoveryService = DiscoveryService()
    private lazy var sharedImportProcessor = SharedImportProcessor(localStore: localStore, deviceId: deviceId)
    private var started = false
    private var retryTask: Task<Void, Never>?
    private var connectivityRetryTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var offlineGraceTask: Task<Void, Never>?
    private var recoverySequence = 0
    private var syncResultTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var lastAutoSelectedServerAddress: String?
    private var connectivityRetryAttempt = 0
    private var isAppInBackground = false
    private var hasSyncIssue = false
    private var restReachabilityState: RestReachabilityState = .unknown
    private var webSocketLifecycleState: WebSocketLifecycleState = .disconnected
    private var lastWebSocketGenerationID: String?
    private let connectivityRetryDelays = [5, 15, 30, 60]
    private static let offlineGraceDelayNanoseconds: UInt64 = 2_500_000_000
    private static let stableHost = "solodrop.local"
    private static let defaultServerAddress = "http://solodrop.local:8000"
    private static let serverAddressKey = "serverAddress"
    private static let manualServerAddressKey = "manualServerAddress"
    private static let manualServerOverrideKey = "manualServerOverrideEnabled"
    private static let deviceTokenKey = "deviceToken"
    private static let pairedKey = "pairedDevice"
    private static let pairedServerAddressKey = "pairedServerAddress"

    init(
        localStore: LocalStore? = nil,
        savedAddress: String? = UserDefaults.standard.string(forKey: "serverAddress")
    ) {
        let resolvedLocalStore = localStore ?? .shared
        let resolvedDeviceId = ChatStore.loadDeviceId()
        let storedManualAddress = UserDefaults.standard.string(forKey: Self.manualServerAddressKey)
        let legacyAddress = ChatStore.normalizedServerAddress(savedAddress)
        let initialManualAddress: String
        if let storedManualAddress,
           !storedManualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialManualAddress = ChatStore.normalizedServerAddress(storedManualAddress)
        } else {
            initialManualAddress = ChatStore.isStableBonjourAddress(legacyAddress) ? "" : legacyAddress
        }
        let shouldUseManualOverride = UserDefaults.standard.bool(forKey: Self.manualServerOverrideKey)
            && !initialManualAddress.isEmpty
        let resolvedServerAddress = shouldUseManualOverride
            ? ChatStore.normalizedServerAddress(initialManualAddress)
            : Self.defaultServerAddress
        let storedDeviceToken = UserDefaults.standard.string(forKey: Self.deviceTokenKey)
        let resolvedAPIClient = APIClient(
            serverAddress: resolvedServerAddress,
            deviceId: resolvedDeviceId,
            deviceToken: storedDeviceToken
        )

        self.localStore = resolvedLocalStore
        self.deviceId = resolvedDeviceId
        self.manualServerAddress = initialManualAddress
        self.manualServerOverrideEnabled = shouldUseManualOverride
        self.serverAddress = resolvedServerAddress
        self.apiClient = resolvedAPIClient
        let resolvedSyncManager = SyncManager(localStore: resolvedLocalStore, apiClient: resolvedAPIClient)
        self.syncManager = resolvedSyncManager
        if storedDeviceToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            UserDefaults.standard.set(true, forKey: Self.pairedKey)
            if UserDefaults.standard.string(forKey: Self.pairedServerAddressKey) == nil {
                UserDefaults.standard.set(resolvedServerAddress, forKey: Self.pairedServerAddressKey)
            }
        }
        self.pairingStatus = storedDeviceToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? "Подключено"
            : "Не подключено"
        UserDefaults.standard.set(resolvedServerAddress, forKey: Self.serverAddressKey)

        discoveryService.$servers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] servers in
                self?.discoveredServers = servers
                self?.handleDiscoveredServers(servers)
            }
            .store(in: &cancellables)

        discoveryService.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.discoveryStatus = status
            }
            .store(in: &cancellables)

        updateConnectedServerInfo()
        reconcilePairingForActiveServer()
        updateTrustedDeviceStatus()
    }

    func start() {
        guard !started else { return }
        started = true

        log("store start")
        loadLocalMessages()
        discoveryService.start()
        networkMonitor.start { [weak self] available in
            guard let self else { return }
            self.log("network path changed available=\(available)")
            if available {
                self.cancelOfflineGrace(reason: "network path available")
                self.discoveryService.restart()
                Task {
                    await self.runRecovery(
                        reason: .connectivityAvailable,
                        includeRetryableFailed: false,
                        forceReconnectWebSocket: true,
                        allowWebSocketReconnect: !self.isAppInBackground,
                        showResult: false,
                        processSharedImportsFirst: false,
                        cancelExisting: false
                    )
                }
            } else {
                self.log("network unavailable observed; delaying offline transition background=\(self.isAppInBackground)")
                self.discoveryService.stop()
                self.setWebSocketLifecycle(self.isAppInBackground ? .suspended : .disconnected)
                self.scheduleOfflineGrace(reason: "network path unavailable")
                self.scheduleConnectivityRetry()
            }
        }

        Task {
            await runRecovery(
                reason: .initialStart,
                includeRetryableFailed: false,
                forceReconnectWebSocket: false,
                allowWebSocketReconnect: true,
                showResult: false,
                processSharedImportsFirst: true,
                cancelExisting: false
            )
        }
    }

    func refresh() async {
        log("pull-to-refresh started")
        await runRecovery(
            reason: .manualRefresh,
            includeRetryableFailed: true,
            forceReconnectWebSocket: true,
            allowWebSocketReconnect: !isAppInBackground,
            showResult: true,
            processSharedImportsFirst: false,
            cancelExisting: true
        )
    }

    func appDidEnterBackground() {
        log("app entered background")
        isAppInBackground = true
        cancelOfflineGrace(reason: "entered background")
        setWebSocketLifecycle(.suspended)
        apiClient.suspendWebSocketForBackground()
        log("final connection state after background suspend status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
    }

    func appWillResignActive() {
        log("app became inactive; preserving foreground connection state during grace period")
    }

    func appDidBecomeActive() {
        log("app became active")
        isAppInBackground = false
        cancelOfflineGrace(reason: "became active")
        Task {
            await runRecovery(
                reason: .foregroundActive,
                includeRetryableFailed: false,
                forceReconnectWebSocket: true,
                allowWebSocketReconnect: true,
                showResult: false,
                processSharedImportsFirst: true,
                cancelExisting: true
            )
        }
    }

    func sendDraft() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""

        do {
            let item = try localStore.createTextItem(text, deviceId: deviceId)
            appendOrReplace(item)
            sortMessages()
            Task { await syncNow() }
        } catch {
            draftText = text
            errorText = "Не удалось сохранить сообщение локально."
        }
    }

    func sendFile(fileURL: URL) {
        do {
            let item = try localStore.createFileItem(from: fileURL, deviceId: deviceId)
            appendOrReplace(item)
            sortMessages()
            Task { await syncNow() }
        } catch {
            errorText = "Не удалось сохранить файл локально."
        }
    }

    func processSharedImports() async {
        let processedCount = processPendingSharedImports()
        if processedCount > 0 {
            loadLocalMessages()
            await runRecovery(
                reason: .sharedImport,
                includeRetryableFailed: false,
                forceReconnectWebSocket: false,
                allowWebSocketReconnect: !isAppInBackground,
                showResult: false,
                processSharedImportsFirst: false,
                cancelExisting: false
            )
        }
    }

    func reconnect() {
        Task {
            await runRecovery(
                reason: .manualReconnect,
                includeRetryableFailed: true,
                forceReconnectWebSocket: true,
                allowWebSocketReconnect: !isAppInBackground,
                showResult: true,
                processSharedImportsFirst: false,
                cancelExisting: true
            )
        }
    }

    func retry(message: Message) {
        do {
            try localStore.markPending(id: message.id)
            loadLocalMessages()
            Task { await syncNow() }
        } catch {
            errorText = "Не удалось поставить элемент в очередь повторной синхронизации."
        }
    }

    func retryFailedItems() {
        Task {
            do {
                isSyncing = true
                _ = try await syncManager.retryFailed()
                loadLocalMessages()
                errorText = nil
            } catch {
                handleSyncError(error)
                if errorText == nil {
                    errorText = "Повторная синхронизация пока недоступна."
                }
            }
            isSyncing = false
        }
    }

    func pairWithCurrentServer() {
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        Task {
            do {
                setRestReachability(.checking)
                guard await apiClient.checkHealth() else {
                    setRestReachability(.unreachable)
                    errorText = "SoloDrop Server недоступен. Проверьте /health и адрес сервера."
                    return
                }
                setRestReachability(.reachable)

                let result = try await apiClient.pair(code: code, deviceName: UIDevice.current.name)
                if result.paired {
                    let finalServerAddress = result.serverUrl.map(Self.normalizedServerAddress) ?? serverAddress
                    if !manualServerOverrideEnabled, serverAddress != finalServerAddress {
                        setActiveServerAddress(finalServerAddress, triggerSync: false, preservePairing: true)
                    }

                    guard let deviceToken = result.deviceToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !deviceToken.isEmpty else {
                        clearPairingState()
                        pairingStatus = "Pairing сохранён, token отсутствует"
                        updateConnectionPresentation()
                        return
                    }

                    saveTrustedPairing(deviceToken: deviceToken)
                    pairingStatus = "Подключено"
                    pairingCode = ""
                    updateTrustedDeviceStatus()
                    await syncNow()
                }
            } catch {
                pairingStatus = "PIN не принят"
                errorText = "Pairing failed: \(error.localizedDescription)"
            }
        }
    }

    func select(server: DiscoveredServer) {
        manualServerOverrideEnabled = false
        lastAutoSelectedServerAddress = server.urlString
        setActiveServerAddress(server.urlString, triggerSync: true)
        if !isPaired {
            pairingStatus = "Требуется PIN"
        }
    }

    func useBonjourDiscovery(triggerSync: Bool = true) {
        if manualServerOverrideEnabled {
            manualServerOverrideEnabled = false
            return
        }

        let selected = preferredDiscoveredServer()
        let address = selected?.urlString ?? Self.defaultServerAddress
        lastAutoSelectedServerAddress = selected?.urlString
        setActiveServerAddress(address, triggerSync: triggerSync)
    }

    func applyManualServerOverride(triggerSync: Bool = true) {
        guard manualServerOverrideEnabled else {
            manualServerOverrideEnabled = true
            return
        }

        let normalized = Self.normalizedServerAddress(manualServerAddress.isEmpty ? serverAddress : manualServerAddress)
        if manualServerAddress != normalized {
            manualServerAddress = normalized
        }
        setActiveServerAddress(normalized, triggerSync: triggerSync)
    }

    func resetPairing() {
        apiClient.disconnectWebSocket(reason: "reset pairing")
        pairingCode = ""
        clearPairingState()
        pairingStatus = "Не подключено"
        setWebSocketLifecycle(.disconnected)
        updateConnectionPresentation()
    }

    func applyScannedQRCode(_ value: String) {
        do {
            let payload = try Self.parseScannedConnectionPayload(value)
            if let serverAddress = payload.serverAddress {
                applyScannedServerAddress(serverAddress)
            }
            if let pairingCode = payload.pairingCode {
                self.pairingCode = pairingCode
            }
            errorText = nil
            if payload.pairingCode == nil {
                showSyncResult("QR считан")
            } else {
                showSyncResult("QR считан · выполняется pairing")
                pairWithCurrentServer()
            }
        } catch {
            errorText = "QR-код не распознан. Введите адрес вручную."
        }
    }

    func syncNow() async {
        await runRecovery(
            reason: isAppInBackground ? .backgroundFetch : .syncNow,
            includeRetryableFailed: false,
            forceReconnectWebSocket: false,
            allowWebSocketReconnect: !isAppInBackground,
            showResult: false,
            processSharedImportsFirst: false,
            cancelExisting: false
        )
    }

    private func runRecovery(
        reason: RecoveryReason,
        includeRetryableFailed: Bool,
        forceReconnectWebSocket: Bool,
        allowWebSocketReconnect: Bool,
        showResult: Bool,
        processSharedImportsFirst: Bool,
        cancelExisting: Bool
    ) async {
        if cancelExisting, let existingTask = recoveryTask {
            log("foreground recovery cancelling stale task reason=\(reason.rawValue)")
            existingTask.cancel()
            recoveryTask = nil
        }

        if let existingTask = recoveryTask {
            log("foreground recovery coalesced reason=\(reason.rawValue)")
            await existingTask.value
            return
        }

        recoverySequence += 1
        let sequence = recoverySequence
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRecovery(
                reason: reason,
                recoveryID: sequence,
                includeRetryableFailed: includeRetryableFailed,
                forceReconnectWebSocket: forceReconnectWebSocket,
                allowWebSocketReconnect: allowWebSocketReconnect,
                showResult: showResult,
                processSharedImportsFirst: processSharedImportsFirst
            )
        }
        recoveryTask = task
        await task.value
        if recoverySequence == sequence {
            recoveryTask = nil
        }
    }

    private func performRecovery(
        reason: RecoveryReason,
        recoveryID: Int,
        includeRetryableFailed: Bool,
        forceReconnectWebSocket: Bool,
        allowWebSocketReconnect: Bool,
        showResult: Bool,
        processSharedImportsFirst: Bool
    ) async {
        log("foreground recovery started reason=\(reason.rawValue) forceWS=\(forceReconnectWebSocket) allowWS=\(allowWebSocketReconnect)")
        loadLocalMessages()

        if processSharedImportsFirst {
            let processedCount = processPendingSharedImports()
            if processedCount > 0 {
                log("shared import processed count=\(processedCount)")
                loadLocalMessages()
            }
        }

        clearSyncIssue(reason: "recovery started \(reason.rawValue)")
        applyRefreshState(.refreshing)
        setRestReachability(.checking)
        let isHealthy = await apiClient.checkHealth()
        log("health result reachable=\(isHealthy)")
        guard isCurrentRecovery(recoveryID) else {
            log("stale foreground recovery ignored after health reason=\(reason.rawValue) id=\(recoveryID)")
            return
        }

        guard isHealthy else {
            cancelOfflineGrace(reason: "health failed")
            setRestReachability(.unreachable)
            setWebSocketLifecycle(.disconnected)
            refreshState = .offline
            isSyncing = false
            scheduleConnectivityRetry()
            if showResult {
                showSyncResult("Сервер недоступен")
            }
            log("final connection state status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
            return
        }

        cancelOfflineGrace(reason: "health reachable")
        setRestReachability(.reachable)
        resetConnectivityRetry()

        guard isPaired else {
            requirePairing()
            if showResult {
                showSyncResult("Требуется pairing")
            }
            log("final connection state status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
            return
        }

        guard await verifySavedTokenWithServer() else {
            requirePairing(pairingStatus)
            if showResult {
                showSyncResult("Требуется pairing")
            }
            log("final connection state status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
            return
        }

        pairingStatus = "Подключено"
        updateTrustedDeviceStatus()

        var didReconnectWebSocket = false
        var didSkipWebSocketForBackground = false
        if allowWebSocketReconnect, !isAppInBackground {
            applyRefreshState(.reconnecting)
            didReconnectWebSocket = connect(forceReconnect: forceReconnectWebSocket)
            log("websocket reconnect result connected=\(didReconnectWebSocket) generation=\(lastWebSocketGenerationID ?? "none")")
        } else {
            didSkipWebSocketForBackground = true
            setWebSocketLifecycle(.suspended)
            log("websocket reconnect skipped for background")
        }

        applyRefreshState(.syncing)
        isSyncing = true
        do {
            let summary = try await syncManager.syncPendingItems(includeRetryableFailed: includeRetryableFailed)
            guard isCurrentRecovery(recoveryID) else {
                log("stale foreground recovery ignored after sync reason=\(reason.rawValue) id=\(recoveryID)")
                isSyncing = false
                return
            }
            loadLocalMessages()
            autosaveReceivedFiles(messages)
            refreshState = .idle
            errorText = nil
            clearSyncIssue(reason: "sync completed \(reason.rawValue)")
            isSyncing = false
            updateConnectionPresentation()
            log("sync result pushed=\(summary.pushedCount) pulled=\(summary.pulledCount) retried=\(summary.retriedCount)")
            log("final connection state status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
            if showResult {
                showSyncResult(recoveryMessage(for: RecoveryResult(
                    isServerReachable: true,
                    didReconnectWebSocket: didReconnectWebSocket,
                    didSkipWebSocketForBackground: didSkipWebSocketForBackground,
                    summary: summary
                )))
            }
        } catch {
            isSyncing = false
            loadLocalMessages()
            handleSyncError(error, restWasReachableDuringRecovery: true)
            log("sync result error=\(error.localizedDescription)")
            log("final connection state status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
            if showResult {
                showSyncResult(syncFailureMessage(for: error))
            }
        }
    }

    private func applyRefreshState(_ state: ManualRefreshState) {
        refreshState = state
        switch state {
        case .idle:
            updateConnectionPresentation()
        case .refreshing:
            connectionStatus = "Подключение"
        case .reconnecting:
            connectionStatus = "Переподключение"
        case .syncing:
            connectionStatus = "Синхронизация"
        case .offline:
            setRestReachability(.unreachable)
        case .failed:
            if connectionStatus != "Требуется pairing" {
                updateConnectionPresentation()
            }
        }
    }

    private var isPaired: Bool {
        hasTrustedPairingForActiveServer
    }

    private var savedDeviceToken: String? {
        let token = apiClient.deviceToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        return token?.isEmpty == false ? token : nil
    }

    private var hasTrustedPairingForActiveServer: Bool {
        guard savedDeviceToken != nil,
              UserDefaults.standard.bool(forKey: Self.pairedKey),
              let pairedServerAddress = UserDefaults.standard.string(forKey: Self.pairedServerAddressKey) else {
            return false
        }
        return Self.normalizedServerAddress(pairedServerAddress) == serverAddress
    }

    private func handleDiscoveredServers(_ servers: [DiscoveredServer]) {
        guard !manualServerOverrideEnabled, let selected = preferredDiscoveredServer(from: servers) else {
            return
        }

        guard selected.urlString != lastAutoSelectedServerAddress || serverAddress != selected.urlString else {
            return
        }

        lastAutoSelectedServerAddress = selected.urlString
        setActiveServerAddress(selected.urlString, triggerSync: started)
        if !isPaired {
            pairingStatus = "Требуется PIN"
        }
    }

    private func preferredDiscoveredServer(from servers: [DiscoveredServer]? = nil) -> DiscoveredServer? {
        let candidates = servers ?? discoveredServers
        return candidates.first { $0.host.caseInsensitiveCompare(Self.stableHost) == .orderedSame }
            ?? candidates.first
    }

    private func applyScannedServerAddress(_ address: String) {
        let normalized = Self.normalizedServerAddress(address)
        manualServerAddress = normalized

        if Self.isStableBonjourAddress(normalized) {
            if manualServerOverrideEnabled {
                manualServerOverrideEnabled = false
            } else {
                setActiveServerAddress(normalized, triggerSync: true)
            }
            return
        }

        if manualServerOverrideEnabled {
            applyManualServerOverride(triggerSync: true)
        } else {
            manualServerOverrideEnabled = true
        }
    }

    private func setActiveServerAddress(_ address: String, triggerSync: Bool, preservePairing: Bool = false) {
        let normalized = Self.normalizedServerAddress(address)
        guard serverAddress != normalized else {
            updateConnectedServerInfo()
            if triggerSync {
                Task {
                    await runRecovery(
                        reason: .addressChanged,
                        includeRetryableFailed: false,
                        forceReconnectWebSocket: true,
                        allowWebSocketReconnect: !isAppInBackground,
                        showResult: false,
                        processSharedImportsFirst: false,
                        cancelExisting: true
                    )
                }
            }
            return
        }

        let shouldRequireNewPairing = !preservePairing && savedDeviceToken != nil
        apiClient.disconnectWebSocket(reason: "server address changed")
        setWebSocketLifecycle(.disconnected)
        serverAddress = normalized
        resetConnectivityRetry()
        if shouldRequireNewPairing {
            clearPairingState()
            pairingStatus = "Сменился сервер · нужен PIN"
        }

        if triggerSync {
            Task {
                await runRecovery(
                    reason: .addressChanged,
                    includeRetryableFailed: false,
                    forceReconnectWebSocket: true,
                    allowWebSocketReconnect: !isAppInBackground,
                    showResult: false,
                    processSharedImportsFirst: false,
                    cancelExisting: true
                )
            }
        }
    }

    private func updateConnectedServerInfo() {
        let mode = manualServerOverrideEnabled ? "manual override" : "Bonjour/stable"
        guard let components = URLComponents(string: serverAddress),
              let host = components.host else {
            connectedServerInfo = "\(serverAddress) · \(mode)"
            return
        }
        let port = components.port.map { ":\($0)" } ?? ""
        connectedServerInfo = "\(host)\(port) · \(mode)"
    }

    private func reconcilePairingForActiveServer() {
        guard savedDeviceToken != nil else {
            UserDefaults.standard.set(false, forKey: Self.pairedKey)
            UserDefaults.standard.removeObject(forKey: Self.pairedServerAddressKey)
            pairingStatus = "Не подключено"
            return
        }

        if UserDefaults.standard.string(forKey: Self.pairedServerAddressKey) == nil {
            UserDefaults.standard.set(serverAddress, forKey: Self.pairedServerAddressKey)
        }

        guard hasTrustedPairingForActiveServer else {
            clearPairingState()
            pairingStatus = "Сменился сервер · нужен PIN"
            return
        }

        UserDefaults.standard.set(true, forKey: Self.pairedKey)
        pairingStatus = "Подключено"
    }

    private func saveTrustedPairing(deviceToken: String) {
        apiClient.deviceToken = deviceToken
        UserDefaults.standard.set(deviceToken, forKey: Self.deviceTokenKey)
        UserDefaults.standard.set(true, forKey: Self.pairedKey)
        UserDefaults.standard.set(serverAddress, forKey: Self.pairedServerAddressKey)
    }

    private func requirePairing(_ status: String = "Требуется PIN") {
        apiClient.disconnectWebSocket(reason: "recovery without trusted token")
        setWebSocketLifecycle(.disconnected)
        pairingStatus = status
        refreshState = .failed
        isSyncing = false
        updateTrustedDeviceStatus()
    }

    private func verifySavedTokenWithServer() async -> Bool {
        guard hasTrustedPairingForActiveServer else { return false }

        do {
            let status = try await apiClient.pairStatus()
            guard !status.pairingEnabled || (status.paired && status.trusted && status.tokenValid) else {
                clearPairingState()
                pairingStatus = "Требуется PIN"
                errorText = "Pairing/token не принят сервером. Локальная история сохранена."
                updateConnectionPresentation()
                return false
            }

            pairingStatus = "Подключено"
            updateTrustedDeviceStatus()
            return true
        } catch {
            log("pair/status check skipped error=\(error.localizedDescription)")
            return hasTrustedPairingForActiveServer
        }
    }

    private func updateTrustedDeviceStatus() {
        if hasTrustedPairingForActiveServer {
            trustedDeviceStatus = "Trusted device · token сохранён"
        } else if UserDefaults.standard.bool(forKey: Self.pairedKey), savedDeviceToken == nil {
            trustedDeviceStatus = "Pairing сохранён, token отсутствует"
        } else if savedDeviceToken != nil {
            trustedDeviceStatus = "Token сохранён для другого сервера"
        } else {
            trustedDeviceStatus = "Не trusted · нужен PIN"
        }
    }

    private func setRestReachability(_ state: RestReachabilityState) {
        restReachabilityState = state
        switch state {
        case .unknown:
            restHealthStatus = "REST unknown"
        case .checking:
            restHealthStatus = "REST checking"
        case .reachable:
            restHealthStatus = "REST reachable"
            cancelOfflineGrace(reason: "REST reachable")
        case .unreachable:
            restHealthStatus = "REST offline"
        }
        updateConnectionPresentation()
    }

    private func setWebSocketLifecycle(_ state: WebSocketLifecycleState, generation: UUID? = nil) {
        webSocketLifecycleState = state
        if let generation {
            lastWebSocketGenerationID = generation.uuidString
        }

        let suffix = lastWebSocketGenerationID.map { " · gen \($0.prefix(8))" } ?? ""
        switch state {
        case .disconnected:
            webSocketStatus = "WS disconnected\(suffix)"
        case .connecting:
            webSocketStatus = "WS connecting\(suffix)"
        case .connected:
            webSocketStatus = "WS connected\(suffix)"
        case .suspended:
            webSocketStatus = "WS suspended/background\(suffix)"
        case .failed:
            webSocketStatus = "WS failed\(suffix)"
        }
        updateConnectionPresentation()
    }

    private func updateConnectionPresentation() {
        if isAppInBackground, webSocketLifecycleState == .suspended {
            connectionStatus = "Фон"
            return
        }

        switch restReachabilityState {
        case .unreachable:
            connectionStatus = "Офлайн"
            return
        case .checking:
            connectionStatus = "Подключение"
            return
        case .unknown:
            if connectionStatus == "Офлайн" || connectionStatus == "Требуется pairing" {
                return
            }
        case .reachable:
            break
        }

        guard isPaired else {
            connectionStatus = "Требуется pairing"
            return
        }

        if isSyncing {
            connectionStatus = "Синхронизация"
            return
        }

        switch webSocketLifecycleState {
        case .connected:
            connectionStatus = hasSyncIssue ? "Проблема синхронизации" : "Онлайн"
        case .connecting:
            connectionStatus = "Переподключение"
        case .disconnected, .failed, .suspended:
            connectionStatus = restReachabilityState == .reachable ? "Проблема синхронизации" : "Переподключение"
        }
    }

    private func handleSyncError(_ error: Error, restWasReachableDuringRecovery: Bool = false) {
        if SyncManager.isAuthorizationError(error) {
            apiClient.disconnectWebSocket(reason: "authorization failed")
            setWebSocketLifecycle(.disconnected)
            clearPairingState()
            pairingStatus = "Требуется PIN"
            refreshState = .failed
            errorText = "Pairing/token не принят сервером. Локальная история сохранена."
            updateConnectionPresentation()
            return
        }

        if SyncManager.isTransientNetworkError(error) {
            if restWasReachableDuringRecovery || restReachabilityState == .reachable {
                markSyncIssue(reason: "transient sync error while REST reachable: \(error.localizedDescription)")
                refreshState = .failed
                errorText = nil
                scheduleConnectivityRetry()
                return
            }
            setRestReachability(.unreachable)
            refreshState = .offline
            errorText = nil
            scheduleConnectivityRetry()
            return
        }

        markSyncIssue(reason: "sync error: \(error.localizedDescription)")
        refreshState = .failed
        errorText = "Синхронизация отложена. Локальные данные сохранены."
        scheduleRetry()
    }

    private func isCurrentRecovery(_ recoveryID: Int) -> Bool {
        !Task.isCancelled && recoverySequence == recoveryID
    }

    private func markSyncIssue(reason: String) {
        hasSyncIssue = true
        log("sync issue state active reason=\(reason)")
        updateConnectionPresentation()
    }

    private func clearSyncIssue(reason: String) {
        guard hasSyncIssue else { return }
        hasSyncIssue = false
        log("sync issue state cleared reason=\(reason)")
        updateConnectionPresentation()
    }

    private func scheduleOfflineGrace(reason: String) {
        offlineGraceTask?.cancel()
        log("offline grace scheduled reason=\(reason) delayMs=\(Self.offlineGraceDelayNanoseconds / 1_000_000)")
        offlineGraceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.offlineGraceDelayNanoseconds)
            } catch {
                return
            }
            self?.applyOfflineGrace(reason: reason)
        }
    }

    private func applyOfflineGrace(reason: String) {
        offlineGraceTask = nil
        guard !isAppInBackground else {
            log("offline grace skipped in background reason=\(reason)")
            return
        }
        guard recoveryTask == nil,
              refreshState != .refreshing,
              refreshState != .reconnecting,
              refreshState != .syncing else {
            log("offline grace skipped while recovery active reason=\(reason)")
            return
        }
        guard restReachabilityState != .reachable else {
            log("offline grace skipped because REST is reachable reason=\(reason)")
            return
        }

        setRestReachability(.unreachable)
        setWebSocketLifecycle(.disconnected)
        refreshState = .offline
        log("offline grace applied reason=\(reason) final status=\(connectionStatus) rest=\(restHealthStatus) ws=\(webSocketStatus)")
    }

    private func cancelOfflineGrace(reason: String) {
        if offlineGraceTask != nil {
            log("offline grace cancelled reason=\(reason)")
        }
        offlineGraceTask?.cancel()
        offlineGraceTask = nil
    }

    private func scheduleConnectivityRetry() {
        guard connectivityRetryTask == nil else { return }
        guard hasTrustedPairingForActiveServer else { return }

        let index = min(connectivityRetryAttempt, connectivityRetryDelays.count - 1)
        let delay = connectivityRetryDelays[index]
        connectivityRetryAttempt += 1
        log("connectivity retry scheduled delay=\(delay)s attempt=\(connectivityRetryAttempt)")

        connectivityRetryTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            } catch {
                return
            }
            await self?.runConnectivityRetry()
        }
    }

    private func runConnectivityRetry() async {
        connectivityRetryTask = nil
        await runRecovery(
            reason: .connectivityAvailable,
            includeRetryableFailed: false,
            forceReconnectWebSocket: true,
            allowWebSocketReconnect: !isAppInBackground,
            showResult: false,
            processSharedImportsFirst: false,
            cancelExisting: false
        )
    }

    private func resetConnectivityRetry() {
        connectivityRetryAttempt = 0
        connectivityRetryTask?.cancel()
        connectivityRetryTask = nil
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.syncManager.retryFailed()
                self.loadLocalMessages()
                self.errorText = nil
            } catch {
                // Backoff retry is best-effort; visible failed items remain retryable in UI.
            }
            self.retryTask = nil
        }
    }

    private func clearPairingState() {
        resetConnectivityRetry()
        apiClient.deviceToken = nil
        UserDefaults.standard.removeObject(forKey: Self.deviceTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.pairedServerAddressKey)
        UserDefaults.standard.set(false, forKey: Self.pairedKey)
        updateTrustedDeviceStatus()
    }

    @discardableResult
    private func connect(forceReconnect: Bool = false) -> Bool {
        let result = apiClient.connectWebSocket(forceReconnect: forceReconnect) { [weak self] message in
            guard let self else { return }
            do {
                let didUpsert = try self.localStore.upsertRemote(message)
                self.log("websocket message received id=\(message.id) upserted=\(didUpsert)")
                if didUpsert {
                    self.loadLocalMessages()
                    self.autosaveReceivedFiles([message])
                }
            } catch {
                self.errorText = "Не удалось сохранить входящее обновление."
            }
        } onEvent: { [weak self] event in
            guard let self else { return }
            self.handleWebSocketEvent(event)
        }
        return result.generation != nil
    }

    private func handleWebSocketEvent(_ event: WebSocketClientEvent) {
        switch event {
        case .connecting(let generation):
            guard isCurrentWebSocketGeneration(generation) else {
                log("stale websocket connecting event ignored generation=\(generation.uuidString)")
                return
            }
            log("websocket connecting generation=\(generation.uuidString)")
            setWebSocketLifecycle(.connecting, generation: generation)
        case .connected(let generation, let reusedExistingConnection):
            guard isCurrentWebSocketGeneration(generation) else {
                log("stale websocket connected event ignored generation=\(generation.uuidString)")
                return
            }
            log("websocket connected generation=\(generation.uuidString) reused=\(reusedExistingConnection)")
            setWebSocketLifecycle(.connected, generation: generation)
        case .disconnected(let generation, let errorDescription):
            guard isCurrentWebSocketGeneration(generation) else {
                log("stale websocket disconnected event ignored generation=\(generation.uuidString)")
                return
            }
            log("websocket reconnect result disconnected generation=\(generation.uuidString) error=\(errorDescription ?? "none")")
            if isAppInBackground {
                setWebSocketLifecycle(.suspended, generation: generation)
                return
            }
            setWebSocketLifecycle(.failed, generation: generation)
            if restReachabilityState == .reachable {
                refreshState = .reconnecting
            } else {
                refreshState = .offline
            }
            scheduleConnectivityRetry()
        case .invalidAddress(let status):
            log("websocket invalid address status=\(status)")
            setWebSocketLifecycle(.failed)
            errorText = status
        }
    }

    private func isCurrentWebSocketGeneration(_ generation: UUID) -> Bool {
        apiClient.currentWebSocketGenerationID == generation.uuidString
    }

    private func showSyncResult(_ text: String) {
        syncResultTask?.cancel()
        syncResultText = text
        syncResultTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_400_000_000)
            } catch {
                return
            }
            await MainActor.run {
                self?.syncResultText = nil
            }
        }
    }

    private func syncFailureMessage(for error: Error) -> String {
        if SyncManager.isAuthorizationError(error) {
            return "Требуется pairing"
        }
        if SyncManager.isTransientNetworkError(error) {
            return "Сервер недоступен"
        }
        return "Синхронизация отложена"
    }

    private func recoveryMessage(for result: RecoveryResult) -> String {
        if !result.isServerReachable {
            return "Сервер недоступен"
        }
        if result.didSkipWebSocketForBackground {
            return "Фоновая синхронизация завершена"
        }
        if result.summary.pushedCount > 0, result.summary.pulledCount > 0 {
            return "Синхронизировано · отправлено \(result.summary.pushedCount) ожидающих сообщений"
        }
        if result.summary.pushedCount > 0 {
            return "Отправлено \(result.summary.pushedCount) ожидающих сообщений"
        }
        if result.summary.pulledCount > 0 {
            return "Синхронизировано"
        }
        if result.didReconnectWebSocket {
            return "Переподключено · Нет новых сообщений"
        }
        return "Нет новых сообщений"
    }

    private func processPendingSharedImports() -> Int {
        do {
            return try sharedImportProcessor.processPendingImports()
        } catch SharedImportStore.StoreError.appGroupUnavailable {
            // The app can still run without the extension during local development.
            return 0
        } catch {
            errorText = "Не удалось сохранить контент из окна «Поделиться»."
            return 0
        }
    }

    private func loadLocalMessages() {
        do {
            messages = try localStore.listItems()
            sortMessages()
        } catch {
            errorText = "Не удалось открыть локальную историю."
        }
    }

    private func appendOrReplace(_ item: Message) {
        if let index = messages.firstIndex(where: { $0.id == item.id }) {
            messages[index] = item
        } else {
            messages.append(item)
        }
    }

    private func sortMessages() {
        messages.sort { $0.date < $1.date }
    }

    private func autosaveReceivedFiles(_ candidates: [Message]) {
        guard autosaveEnabled else { return }

        for message in candidates where message.isFileBacked && !message.isFromCurrentDevice && !savedFileMessageIds.contains(message.id) {
            savedFileMessageIds.insert(message.id)
            persistSavedIds()

            if let localPath = message.localFilePath {
                Task {
                    await saveFile(url: URL(fileURLWithPath: localPath), fileName: message.fileName ?? "solodrop-file", mimeType: message.mimeType ?? "application/octet-stream")
                }
            } else if let fileUrl = message.fileUrl,
                      let url = absoluteURL(path: fileUrl) {
                Task {
                    await saveFile(url: url, fileName: message.fileName ?? "solodrop-file", mimeType: message.mimeType ?? "application/octet-stream")
                }
            }
        }
    }

    private func saveFile(url: URL, fileName: String, mimeType: String) async {
        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: url)
                data = remoteData
            }

            if mimeType.hasPrefix("image/"), let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                return
            }

            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = documents.appendingPathComponent("SoloDrop", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: uniqueDestination(in: folder, fileName: fileName), options: .atomic)
        } catch {
            errorText = "Не удалось автосохранить файл."
        }
    }

    private func absoluteURL(path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let trimmedServer = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedServer)\(path)")
    }

    private func uniqueDestination(in folder: URL, fileName: String) -> URL {
        let cleanName = fileName.isEmpty ? "solodrop-file" : fileName
        let nsName = cleanName as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        var destination = folder.appendingPathComponent(cleanName)
        var counter = 2

        while FileManager.default.fileExists(atPath: destination.path) {
            let candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            destination = folder.appendingPathComponent(candidate)
            counter += 1
        }

        return destination
    }

    private func persistSavedIds() {
        UserDefaults.standard.set(Array(Array(savedFileMessageIds).suffix(500)), forKey: "savedFileMessageIds")
    }

    private static func loadDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: "deviceId") {
            let normalized = existing.lowercased()
            if normalized != existing {
                UserDefaults.standard.set(normalized, forKey: "deviceId")
            }
            return normalized
        }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: "deviceId")
        return created
    }

    private static func normalizedServerAddress(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return defaultServerAddress
        }

        let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "http://\(trimmed)"

        guard var components = URLComponents(string: withScheme) else {
            return defaultServerAddress
        }

        if components.host == "localhost" || components.host == "127.0.0.1" || components.host == "::1" {
            return defaultServerAddress
        }

        if components.port == 8765 {
            components.port = 8000
        }

        let normalized = components.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            ?? defaultServerAddress
        return normalized
    }

    private static func isStableBonjourAddress(_ value: String) -> Bool {
        guard let components = URLComponents(string: normalizedServerAddress(value)),
              let host = components.host else {
            return false
        }
        return host.caseInsensitiveCompare(stableHost) == .orderedSame
    }

    private static func parseScannedConnectionPayload(_ rawValue: String) throws -> ScannedConnectionPayload {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 8192 else {
            throw ScannedConnectionPayloadError.invalid
        }

        if let data = value.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let payload = parseScannedJSONObject(object) {
            return payload
        }

        if let serverAddress = scannedServerAddress(from: value) {
            return ScannedConnectionPayload(
                serverAddress: serverAddress,
                pairingCode: scannedPairingCode(fromURL: value)
            )
        }

        if let pairingCode = sanitizedPairingCode(value) {
            return ScannedConnectionPayload(serverAddress: nil, pairingCode: pairingCode)
        }

        throw ScannedConnectionPayloadError.invalid
    }

    private static func parseScannedJSONObject(_ object: [String: Any]) -> ScannedConnectionPayload? {
        if let nested = object["pairingPayload"] as? [String: Any],
           let nestedPayload = parseScannedJSONObject(nested) {
            return nestedPayload
        }

        let app = stringValue(object["app"])?.lowercased()
        let type = stringValue(object["type"])?.lowercased()
        let isSoloDropPayload = app == "solodrop" || type == "solodrop.pairing"
        guard isSoloDropPayload else { return nil }

        let serverAddress = [
            "serverUrl",
            "server_url",
            "lanServerUrl",
            "lan_server_url",
            "pairVerifyUrl",
            "pair_verify_url",
            "lanPairVerifyUrl",
            "lan_pair_verify_url"
        ]
            .compactMap { key in stringValue(object[key]).flatMap(scannedServerAddress(from:)) }
            .first

        let pairingCode = [
            "code",
            "pairCode",
            "pair_code",
            "pin",
            "PIN"
        ]
            .compactMap { key in stringValue(object[key]).flatMap(sanitizedPairingCode(_:)) }
            .first

        guard serverAddress != nil || pairingCode != nil else { return nil }
        return ScannedConnectionPayload(serverAddress: serverAddress, pairingCode: pairingCode)
    }

    private static func scannedServerAddress(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2048 else { return nil }

        let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "http://\(trimmed)"
        guard var components = URLComponents(string: withScheme),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty,
              isAllowedScannedServer(host: host, port: components.port) else {
            return nil
        }

        if components.port == nil {
            components.port = 8000
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return normalizedServerAddress(components.url?.absoluteString)
    }

    private static func scannedPairingCode(fromURL rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "http://\(trimmed)"
        guard let components = URLComponents(string: withScheme) else { return nil }
        return components.queryItems?
            .first { ["code", "pairCode", "pair_code", "pin"].contains($0.name) }
            .flatMap { sanitizedPairingCode($0.value ?? "") }
    }

    private static func sanitizedPairingCode(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6,
              trimmed.allSatisfy(\.isNumber) else {
            return nil
        }
        return trimmed
    }

    private static func isAllowedScannedServer(host: String, port: Int?) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        if normalizedHost == stableHost || normalizedHost.hasSuffix(".local") {
            return true
        }
        if port == 8000 || port == 8765 {
            return true
        }
        return isPrivateIPv4Host(normalizedHost)
    }

    private static func isPrivateIPv4Host(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 192, parts[1] == 168 { return true }
        if parts[0] == 172, (16...31).contains(parts[1]) { return true }
        if parts[0] == 169, parts[1] == 254 { return true }
        return false
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private func log(_ message: String) {
        print("[SoloDrop iOS] \(message)")
    }
}

private struct ScannedConnectionPayload {
    let serverAddress: String?
    let pairingCode: String?
}

private enum ScannedConnectionPayloadError: Error {
    case invalid
}
