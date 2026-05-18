import Foundation

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
}

final class APIClient {
    var serverAddress: String
    var deviceId: String
    var deviceToken: String?
    private var webSocketTask: URLSessionWebSocketTask?

    init(serverAddress: String, deviceId: String, deviceToken: String? = nil) {
        self.serverAddress = serverAddress
        self.deviceId = deviceId
        self.deviceToken = deviceToken
    }

    private var baseURL: URL {
        let trimmed = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)!
        }
        return URL(string: "https://\(trimmed)")!
    }

    func checkHealth() async -> Bool {
        do {
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
        let url = baseURL.appendingPathComponent("pair/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "code": code,
            "device_id": deviceId,
            "device_name": deviceName
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(PairingResult.self, from: data)
    }

    func push(items: [Message]) async throws -> SyncPushResponse {
        let url = baseURL.appendingPathComponent("sync/push")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SyncPushRequest(deviceId: deviceId, deviceToken: deviceToken, items: items))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(SyncPushResponse.self, from: data)
    }

    func upload(item: Message) async throws -> Message {
        guard let localFilePath = item.localFilePath else {
            throw URLError(.fileDoesNotExist)
        }

        let fileURL = URL(fileURLWithPath: localFilePath)
        let fileData = try Data(contentsOf: fileURL)
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
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        let envelope = try JSONDecoder().decode(UploadEnvelope.self, from: data)
        return envelope.metadata
    }

    func pullChanges(since: String?) async throws -> SyncPullResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("sync/pull"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "device_id", value: deviceId)]
        if let deviceToken {
            items.append(URLQueryItem(name: "device_token", value: deviceToken))
        }
        if let since {
            items.append(URLQueryItem(name: "since", value: since))
        }
        components.queryItems = items

        let (data, response) = try await URLSession.shared.data(from: components.url!)
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

    func connectWebSocket(onMessage: @escaping (Message) -> Void, onStatus: @escaping (String) -> Void) {
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws"
        var queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        if let deviceToken {
            queryItems.append(URLQueryItem(name: "device_token", value: deviceToken))
        }
        components.queryItems = queryItems

        guard let webSocketURL = components.url else {
            onStatus("Неверный адрес сервера")
            return
        }

        let task = URLSession.shared.webSocketTask(with: webSocketURL)
        webSocketTask = task
        task.resume()
        onStatus("Онлайн")
        receiveLoop(onMessage: onMessage, onStatus: onStatus)
    }

    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func receiveLoop(onMessage: @escaping (Message) -> Void, onStatus: @escaping (String) -> Void) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let event):
                if case .string(let text) = event,
                   let data = text.data(using: .utf8),
                   let envelope = try? JSONDecoder().decode(WebSocketEnvelope.self, from: data),
                   let message = envelope.item {
                    DispatchQueue.main.async {
                        onMessage(message)
                    }
                }
                self?.receiveLoop(onMessage: onMessage, onStatus: onStatus)

            case .failure:
                DispatchQueue.main.async {
                    onStatus("Офлайн")
                }
            }
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
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
