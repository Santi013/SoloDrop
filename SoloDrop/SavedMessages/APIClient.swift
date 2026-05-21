import Foundation

enum APIClientError: LocalizedError, Equatable {
    case invalidServerAddress
    case unauthorized
    case httpStatus(Int)
    case serverStatus(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            return "Server address is invalid."
        case .unauthorized:
            return "Device pairing is required."
        case .httpStatus(let statusCode):
            return "Server returned HTTP \(statusCode)."
        case .serverStatus(let statusCode, let message):
            return "Server returned HTTP \(statusCode): \(message)"
        case .invalidResponse:
            return "Server response is invalid."
        }
    }
}

struct SyncPushResponse: Decodable {
    let processedItemIds: [String]
    let serverTime: String?

    enum CodingKeys: String, CodingKey {
        case processedItemIds
        case processedItemIdsSnake = "processed_item_ids"
        case serverTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        processedItemIds = try container.decodeIfPresent([String].self, forKey: .processedItemIds)
            ?? container.decodeIfPresent([String].self, forKey: .processedItemIdsSnake)
            ?? []
        serverTime = try container.decodeIfPresent(String.self, forKey: .serverTime)
    }
}

struct SyncPullResponse: Decodable {
    let items: [Message]
    let cursor: String?
    let serverTime: String?
}

struct PairingResult: Decodable {
    let paired: Bool
    let deviceId: String?
    let deviceToken: String?
    let serverUrl: String?

    enum CodingKeys: String, CodingKey {
        case paired
        case deviceId
        case deviceIdSnake = "device_id"
        case deviceToken
        case deviceTokenSnake = "device_token"
        case serverUrl
        case serverUrlSnake = "server_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paired = try container.decode(Bool.self, forKey: .paired)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            ?? container.decodeIfPresent(String.self, forKey: .deviceIdSnake)
        deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
            ?? container.decodeIfPresent(String.self, forKey: .deviceTokenSnake)
        serverUrl = try container.decodeIfPresent(String.self, forKey: .serverUrl)
            ?? container.decodeIfPresent(String.self, forKey: .serverUrlSnake)
    }
}

struct PairingStatusResult: Decodable {
    let pairingEnabled: Bool
    let paired: Bool
    let trusted: Bool
    let tokenValid: Bool

    enum CodingKeys: String, CodingKey {
        case pairingEnabled
        case paired
        case trusted
        case tokenValid
    }
}

enum WebSocketClientEvent {
    case connecting(generation: UUID)
    case connected(generation: UUID, reusedExistingConnection: Bool)
    case disconnected(generation: UUID, errorDescription: String?)
    case invalidAddress(String)
}

struct WebSocketReconnectResult {
    let generation: UUID?
    let reusedExistingConnection: Bool
    let url: URL?
}

final class APIClient {
    var serverAddress: String
    var deviceId: String
    var deviceToken: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var webSocketURL: URL?
    private var webSocketGeneration = UUID()

    var currentWebSocketGenerationID: String {
        webSocketGeneration.uuidString
    }

    init(serverAddress: String, deviceId: String, deviceToken: String? = nil) {
        self.serverAddress = serverAddress
        self.deviceId = deviceId.lowercased()
        self.deviceToken = deviceToken
    }

    private var baseURL: URL? {
        let trimmed = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "http://\(trimmed)")
    }

    func checkHealth() async -> Bool {
        do {
            guard let baseURL else { return false }
            let url = baseURL.appendingPathComponent("health")
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response)
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return object?["online"] as? Bool == true
        } catch {
            return false
        }
    }

    func loadMessages() async throws -> [Message] {
        let response = try await pullChanges(since: nil)
        return response.items
    }

    func pair(code: String, deviceName: String) async throws -> PairingResult {
        guard let baseURL else { throw APIClientError.invalidServerAddress }
        let url = baseURL.appendingPathComponent("pair/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "code": code,
            "deviceId": deviceId,
            "device_id": deviceId,
            "deviceName": deviceName,
            "device_name": deviceName
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PairingResult.self, from: data)
    }

    func pairStatus() async throws -> PairingStatusResult {
        guard let baseURL,
              var components = URLComponents(url: baseURL.appendingPathComponent("pair/status"), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidServerAddress
        }

        var items = [URLQueryItem(name: "device_id", value: deviceId)]
        if let deviceToken {
            items.append(URLQueryItem(name: "device_token", value: deviceToken))
        }
        components.queryItems = items

        guard let url = components.url else { throw APIClientError.invalidServerAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PairingStatusResult.self, from: data)
    }

    func push(items: [Message]) async throws -> SyncPushResponse {
        guard let baseURL else { throw APIClientError.invalidServerAddress }
        let url = baseURL.appendingPathComponent("sync/push")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SyncPushRequest(deviceId: deviceId, deviceToken: deviceToken, items: items))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(SyncPushResponse.self, from: data)
    }

    func upload(item: Message) async throws -> Message {
        guard let baseURL else { throw APIClientError.invalidServerAddress }
        guard let localFilePath = item.localFilePath else {
            throw URLError(.fileDoesNotExist)
        }

        let fileURL = URL(fileURLWithPath: localFilePath)
        let fileData = try await Task.detached(priority: .utility) {
            try Data(contentsOf: fileURL)
        }.value
        let fileName = item.fileName ?? fileURL.lastPathComponent
        let mimeType = item.mimeType ?? "application/octet-stream"
        let boundary = "Boundary-\(UUID().uuidString)"

        var body = Data()
        body.appendMultipartField(name: "client_item_id", value: item.id, boundary: boundary)
        body.appendMultipartField(name: "device_id", value: deviceId, boundary: boundary)
        if let deviceToken {
            body.appendMultipartField(name: "device_token", value: deviceToken, boundary: boundary)
        }
        body.appendMultipartField(name: "created_at", value: item.createdAt, boundary: boundary)
        body.appendMultipartField(name: "updated_at", value: item.updatedAt, boundary: boundary)
        body.appendMultipartFile(
            fieldName: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        let url = baseURL.appendingPathComponent("upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        let envelope = try JSONDecoder().decode(UploadEnvelope.self, from: data)
        return envelope.metadata
    }

    func pullChanges(since: String?) async throws -> SyncPullResponse {
        guard let baseURL,
              var components = URLComponents(url: baseURL.appendingPathComponent("sync/pull"), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidServerAddress
        }
        var items = [URLQueryItem(name: "device_id", value: deviceId)]
        if let deviceToken {
            items.append(URLQueryItem(name: "device_token", value: deviceToken))
        }
        if let since {
            items.append(URLQueryItem(name: "since", value: since))
        }
        components.queryItems = items

        guard let url = components.url else { throw APIClientError.invalidServerAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(SyncPullResponse.self, from: data)
    }

    func sendText(_ text: String) async throws {
        let item = Message(type: text.hasPrefix("http") ? "link" : "text", text: text, deviceId: deviceId)
        _ = try await push(items: [item])
    }

    func sendFile(fileURL: URL) async throws {
        let item = Message(type: "file", localFilePath: fileURL.path, fileName: fileURL.lastPathComponent, deviceId: deviceId)
        _ = try await upload(item: item)
    }

    @discardableResult
    func connectWebSocket(
        forceReconnect: Bool = false,
        onMessage: @escaping (Message) -> Void,
        onEvent: @escaping (WebSocketClientEvent) -> Void
    ) -> WebSocketReconnectResult {
        guard let baseURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            disconnectWebSocket(reason: "invalid server address before websocket connect")
            onEvent(.invalidAddress("Неверный адрес сервера"))
            return WebSocketReconnectResult(generation: nil, reusedExistingConnection: false, url: nil)
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws"
        var queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        if let deviceToken {
            queryItems.append(URLQueryItem(name: "device_token", value: deviceToken))
        }
        components.queryItems = queryItems

        guard let webSocketURL = components.url else {
            disconnectWebSocket(reason: "invalid websocket url")
            onEvent(.invalidAddress("Неверный адрес сервера"))
            return WebSocketReconnectResult(generation: nil, reusedExistingConnection: false, url: nil)
        }

        if !forceReconnect,
           let task = webSocketTask,
           task.state == .running,
           self.webSocketURL == webSocketURL {
            log("websocket reused generation=\(webSocketGeneration.uuidString)")
            onEvent(.connected(generation: webSocketGeneration, reusedExistingConnection: true))
            return WebSocketReconnectResult(generation: webSocketGeneration, reusedExistingConnection: true, url: webSocketURL)
        }

        disconnectWebSocket(reason: forceReconnect ? "force reconnect" : "new websocket connection")
        let generation = UUID()
        let task = URLSession.shared.webSocketTask(with: webSocketURL)
        webSocketTask = task
        self.webSocketURL = webSocketURL
        webSocketGeneration = generation
        log("websocket connecting generation=\(generation.uuidString) url=\(webSocketURL.absoluteString)")
        onEvent(.connecting(generation: generation))
        task.resume()
        task.sendPing { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.isCurrentWebSocket(task: task, generation: generation) else {
                    self.log("websocket stale ping ignored generation=\(generation.uuidString)")
                    return
                }
                if let error {
                    self.webSocketTask = nil
                    self.webSocketURL = nil
                    self.log("websocket ping failed generation=\(generation.uuidString) error=\(error.localizedDescription)")
                    onEvent(.disconnected(generation: generation, errorDescription: error.localizedDescription))
                    return
                }
                self.log("websocket ping ok generation=\(generation.uuidString)")
                onEvent(.connected(generation: generation, reusedExistingConnection: false))
            }
        }
        receiveLoop(task: task, generation: generation, onMessage: onMessage, onEvent: onEvent)
        return WebSocketReconnectResult(generation: generation, reusedExistingConnection: false, url: webSocketURL)
    }

    func suspendWebSocketForBackground() {
        disconnectWebSocket(reason: "background suspend")
    }

    func disconnectWebSocket(reason: String = "manual disconnect") {
        let previousGeneration = webSocketGeneration.uuidString
        if webSocketTask != nil {
            log("websocket stale cleanup reason=\(reason) generation=\(previousGeneration)")
        } else {
            log("websocket cleanup reason=\(reason) no active task generation=\(previousGeneration)")
        }
        webSocketGeneration = UUID()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        webSocketURL = nil
    }

    private func receiveLoop(
        task: URLSessionWebSocketTask,
        generation: UUID,
        onMessage: @escaping (Message) -> Void,
        onEvent: @escaping (WebSocketClientEvent) -> Void
    ) {
        task.receive { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                self?.handleWebSocketReceive(
                    result,
                    task: task,
                    generation: generation,
                    onMessage: onMessage,
                    onEvent: onEvent
                )
            }
        }
    }

    private func handleWebSocketReceive(
        _ result: Result<URLSessionWebSocketTask.Message, Error>,
        task: URLSessionWebSocketTask,
        generation: UUID,
        onMessage: @escaping (Message) -> Void,
        onEvent: @escaping (WebSocketClientEvent) -> Void
    ) {
        guard isCurrentWebSocket(task: task, generation: generation) else {
            log("websocket stale receive ignored generation=\(generation.uuidString)")
            return
        }

        switch result {
        case .success(let event):
            if case .string(let text) = event,
               let data = text.data(using: .utf8),
               let envelope = try? JSONDecoder().decode(WebSocketEnvelope.self, from: data),
               let message = envelope.item {
                guard isCurrentWebSocket(task: task, generation: generation) else { return }
                onMessage(message)
            }
            receiveLoop(task: task, generation: generation, onMessage: onMessage, onEvent: onEvent)

        case .failure(let error):
            guard isCurrentWebSocket(task: task, generation: generation) else {
                log("websocket stale failure ignored generation=\(generation.uuidString)")
                return
            }
            webSocketTask = nil
            webSocketURL = nil
            log("websocket disconnected generation=\(generation.uuidString) error=\(error.localizedDescription)")
            onEvent(.disconnected(generation: generation, errorDescription: error.localizedDescription))
        }
    }

    private func isCurrentWebSocket(task: URLSessionWebSocketTask, generation: UUID) -> Bool {
        webSocketGeneration == generation && webSocketTask === task
    }

    private func log(_ message: String) {
        print("[SoloDrop iOS] \(message)")
    }

    private func validate(response: URLResponse) throws {
        try validate(response: response, data: nil)
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIClientError.serverStatus(httpResponse.statusCode, serverErrorMessage(from: data) ?? "Device pairing is required.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let message = serverErrorMessage(from: data) {
                throw APIClientError.serverStatus(httpResponse.statusCode, message)
            }
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
    }

    private func serverErrorMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = object["detail"] {
            return String(describing: detail)
        }

        return String(data: data, encoding: .utf8)
    }
}

private struct UploadEnvelope: Decodable {
    let metadata: Message
}

private struct SyncPushRequest: Encodable {
    let deviceId: String
    let deviceToken: String?
    let items: [Message]

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceToken = "device_token"
        case items
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}
