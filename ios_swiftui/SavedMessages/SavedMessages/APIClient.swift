import Foundation
import UniformTypeIdentifiers

final class APIClient {
    var serverAddress: String
    private var webSocketTask: URLSessionWebSocketTask?

    init(serverAddress: String) {
        self.serverAddress = serverAddress
    }

    private var baseURL: URL {
        let trimmed = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)!
        }
        return URL(string: "http://\(trimmed)")!
    }

    func loadMessages() async throws -> [Message] {
        let url = baseURL.appendingPathComponent("api/messages")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Message].self, from: data)
    }

    func sendText(_ text: String) async throws {
        let url = baseURL.appendingPathComponent("api/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "sender": "ios",
            "text": text
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func sendFile(fileURL: URL) async throws {
        let canAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey])
        let mimeType = resourceValues?.contentType?.preferredMIMEType ?? "application/octet-stream"
        let boundary = "Boundary-\(UUID().uuidString)"

        var body = Data()
        body.appendMultipartField(name: "sender", value: "ios", boundary: boundary)
        body.appendMultipartFile(
            fieldName: "uploaded_file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        let url = baseURL.appendingPathComponent("api/files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
    }

    func connectWebSocket(onMessage: @escaping (Message) -> Void, onStatus: @escaping (String) -> Void) {
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws"

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
                   envelope.type == "message",
                   let message = envelope.message {
                    DispatchQueue.main.async {
                        onMessage(message)
                    }
                }
                self?.receiveLoop(onMessage: onMessage, onStatus: onStatus)

            case .failure:
                DispatchQueue.main.async {
                    onStatus("Нет соединения")
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
