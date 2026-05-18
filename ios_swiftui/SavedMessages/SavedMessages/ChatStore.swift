import Combine
import Foundation
import UIKit

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draftText = ""
    @Published var connectionStatus = "Офлайн"
    @Published var errorText: String?
    @Published var pairingCode = ""
    @Published var pairingStatus = "Не подключено"
    @Published var isSyncing = false
    @Published var savedFileMessageIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "savedFileMessageIds") ?? [])
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var autosaveEnabled = UserDefaults.standard.bool(forKey: "autosaveEnabled") {
        didSet {
            UserDefaults.standard.set(autosaveEnabled, forKey: "autosaveEnabled")
            if autosaveEnabled {
                autosaveReceivedFiles(messages)
            }
        }
    }

    @Published var serverAddress: String {
        didSet {
            UserDefaults.standard.set(serverAddress, forKey: "serverAddress")
            apiClient.serverAddress = serverAddress
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

    init(
        localStore: LocalStore = .shared,
        savedAddress: String? = UserDefaults.standard.string(forKey: "serverAddress")
    ) {
        self.localStore = localStore
        self.deviceId = ChatStore.loadDeviceId()
        self.serverAddress = savedAddress ?? "http://solodrop.local:8000"
        self.apiClient = APIClient(serverAddress: self.serverAddress, deviceId: self.deviceId)
        self.syncManager = SyncManager(localStore: localStore, apiClient: apiClient)

        discoveryService.$servers
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredServers)
    }

    func start() {
        guard !started else { return }
        started = true

        loadLocalMessages()
        discoveryService.start()
        networkMonitor.start { [weak self] available in
            guard let self else { return }
            if available {
                Task { await self.syncNow() }
            } else {
                self.connectionStatus = "Офлайн"
            }
        }

        Task {
            await processSharedImports()
            await syncNow()
        }
    }

    func refresh() async {
        await syncNow()
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
        do {
            let processedCount = try sharedImportProcessor.processPendingImports()
            if processedCount > 0 {
                loadLocalMessages()
                await syncNow()
            }
        } catch SharedImportStore.StoreError.appGroupUnavailable {
            // The app can still run without the extension during local development.
        } catch {
            errorText = "Не удалось сохранить контент из окна «Поделиться»."
        }
    }

    func reconnect() {
        apiClient.disconnectWebSocket()
        Task { await syncNow() }
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
                errorText = "Повторная синхронизация пока недоступна."
            }
            isSyncing = false
        }
    }

    func pairWithCurrentServer() {
        let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        Task {
            do {
                let result = try await apiClient.pair(code: code, deviceName: UIDevice.current.name)
                if result.paired {
                    pairingStatus = "Подключено"
                    pairingCode = ""
                    if let serverUrl = result.serverUrl {
                        serverAddress = serverUrl
                    }
                    await syncNow()
                }
            } catch {
                pairingStatus = "PIN не принят"
                errorText = "Не удалось выполнить pairing. Проверьте PIN-код на ПК."
            }
        }
    }

    func select(server: DiscoveredServer) {
        serverAddress = server.urlString
        pairingStatus = "Требуется PIN"
    }

    func forgetServer() {
        apiClient.disconnectWebSocket()
        serverAddress = "http://solodrop.local:8000"
        pairingCode = ""
        pairingStatus = "Не подключено"
        connectionStatus = "Офлайн"
    }

    func syncNow() async {
        guard await apiClient.checkHealth() else {
            connectionStatus = "Офлайн"
            return
        }

        connectionStatus = "Синхронизация"
        isSyncing = true
        do {
            _ = try await syncManager.syncPendingItems()
            loadLocalMessages()
            autosaveReceivedFiles(messages)
            connect()
            connectionStatus = "Онлайн"
            pairingStatus = "Подключено"
            errorText = nil
        } catch {
            loadLocalMessages()
            connectionStatus = "Офлайн"
            errorText = "Синхронизация отложена. Локальные данные сохранены."
            scheduleRetry()
        }
        isSyncing = false
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

    private func connect() {
        apiClient.connectWebSocket { [weak self] message in
            guard let self else { return }
            do {
                try self.localStore.upsertRemote(message)
                self.loadLocalMessages()
                self.autosaveReceivedFiles([message])
            } catch {
                self.errorText = "Не удалось сохранить входящее обновление."
            }
        } onStatus: { [weak self] status in
            self?.connectionStatus = status
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
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: "deviceId")
        return created
    }
}
