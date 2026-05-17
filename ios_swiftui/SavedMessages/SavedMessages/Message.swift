import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let sender: String
    let kind: String
    let text: String?
    let fileName: String?
    let fileUrl: String?
    let previewUrl: String?
    let mimeType: String?
    let createdAt: String

    var isFromCurrentDevice: Bool {
        sender == "ios" || sender == "iphone"
    }

    var date: Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) ?? .distantPast
    }
}

struct WebSocketEnvelope: Decodable {
    let type: String
    let message: Message?
}
