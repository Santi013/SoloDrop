import Foundation
import UIKit

@MainActor
final class ChatStore: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draftText = ""
    @Published var connectionStatus = "Офлайн"
    @Published var errorText: String?
    @Published var savedFileMessageIds: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "savedFileMessageIds") ?? [])
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

    private let apiClient: APIClient
    private lazy var sharedImportProcessor = SharedImportProcessor(apiClient: apiClient)

    init() {
        let savedAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? "http://192.168.1.10:8765"
        self.serverAddress = savedAddress
        self.apiClient = APIClient(serverAddress: savedAddress)
    }

    func start() {
        Task {
            await processSharedImports()
            await refresh()
            connect()
        }
    }

    func refresh() async {
        do {
            messages = try await apiClient.loadMessages()
            sortMessages()
            autosaveReceivedFiles(messages)
            errorText = nil
        } catch {
            connectionStatus = "Нет соединения"
            errorText = "Не удалось загрузить сообщения. Проверьте адрес сервера и Wi-Fi."
        }
    }

    func sendDraft() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""

        Task {
            do {
                try await apiClient.sendText(text)
                errorText = nil
            } catch {
                draftText = text
                errorText = "Не удалось отправить сообщение."
            }
        }
    }

    func sendFile(fileURL: URL) {
        Task {
            do {
                try await apiClient.sendFile(fileURL: fileURL)
                errorText = nil
            } catch {
                errorText = "Не удалось отправить файл."
            }
        }
    }

    func processSharedImports() async {
        do {
            let processedCount = try await sharedImportProcessor.processPendingImports()
            if processedCount > 0 {
                errorText = nil
            }
        } catch SharedImportStore.StoreError.appGroupUnavailable {
            // The app can still run without the extension during local development.
        } catch {
            errorText = "Не удалось отправить контент из окна «Поделиться»."
        }
    }

    func reconnect() {
        apiClient.disconnectWebSocket()
        Task {
            await refresh()
            connect()
        }
    }

    private func connect() {
        apiClient.connectWebSocket { [weak self] message in
            guard let self else { return }
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.sortMessages()
                self.autosaveReceivedFiles([message])
            }
        } onStatus: { [weak self] status in
            self?.connectionStatus = status
        }
    }

    private func sortMessages() {
        messages.sort { $0.date < $1.date }
    }

    private func autosaveReceivedFiles(_ candidates: [Message]) {
        guard autosaveEnabled else { return }

        for message in candidates where message.kind == "file" && !message.isFromCurrentDevice && !savedFileMessageIds.contains(message.id) {
            guard let fileUrl = message.fileUrl,
                  let url = absoluteURL(path: fileUrl) else { continue }

            savedFileMessageIds.insert(message.id)
            persistSavedIds()

            Task {
                await saveFile(url: url, fileName: message.fileName ?? "solodrop-file", mimeType: message.mimeType ?? "application/octet-stream")
            }
        }
    }

    private func saveFile(url: URL, fileName: String, mimeType: String) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
}
