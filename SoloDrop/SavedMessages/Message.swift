import Foundation

enum SyncStatus: String, Codable, Equatable {
    case pending
    case synced
    case failed
}

struct Message: Identifiable, Codable, Equatable {
    var id: String
    var type: String
    var sender: String
    var text: String?
    var localFilePath: String?
    var fileName: String?
    var fileUrl: String?
    var previewUrl: String?
    var mimeType: String?
    var createdAt: String
    var updatedAt: String
    var syncStatus: SyncStatus
    var retryCount: Int
    var lastError: String?
    var serverId: String?
    var deviceId: String?

    var kind: String { type }
    var remoteFileUrl: String? { fileUrl }

    var isFromCurrentDevice: Bool {
        sender == "ios" || sender == "iphone"
    }

    var isFileBacked: Bool {
        type == "file" || type == "media"
    }

    var canonicalID: String {
        Self.canonicalID(id)
    }

    var date: Date {
        DateFormatter.solodropDate(from: createdAt) ?? .distantPast
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        type: String,
        sender: String = "ios",
        text: String? = nil,
        localFilePath: String? = nil,
        fileName: String? = nil,
        fileUrl: String? = nil,
        previewUrl: String? = nil,
        mimeType: String? = nil,
        createdAt: String = DateFormatter.solodropISO.string(from: Date()),
        updatedAt: String = DateFormatter.solodropISO.string(from: Date()),
        syncStatus: SyncStatus = .pending,
        retryCount: Int = 0,
        lastError: String? = nil,
        serverId: String? = nil,
        deviceId: String? = nil
    ) {
        self.id = Self.storedID(id)
        self.type = type
        self.sender = sender
        self.text = text
        self.localFilePath = localFilePath
        self.fileName = fileName
        self.fileUrl = fileUrl
        self.previewUrl = previewUrl
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.retryCount = retryCount
        self.lastError = lastError
        self.serverId = serverId.map(Self.storedID)
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case kind
        case sender
        case text
        case localFilePath
        case fileName
        case fileUrl
        case remoteFileUrl
        case previewUrl
        case mimeType
        case createdAt
        case updatedAt
        case syncStatus
        case retryCount
        case lastError
        case serverId
        case deviceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.storedID(try container.decode(String.self, forKey: .id))
        type = try container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
            ?? "text"
        sender = try container.decodeIfPresent(String.self, forKey: .sender) ?? "ios"
        text = try container.decodeIfPresent(String.self, forKey: .text)
        localFilePath = try container.decodeIfPresent(String.self, forKey: .localFilePath)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileUrl = try container.decodeIfPresent(String.self, forKey: .fileUrl)
            ?? container.decodeIfPresent(String.self, forKey: .remoteFileUrl)
        previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? DateFormatter.solodropISO.string(from: Date())
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? createdAt
        syncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .syncStatus) ?? .synced
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        serverId = try container.decodeIfPresent(String.self, forKey: .serverId).map(Self.storedID)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
    }

    nonisolated static func canonicalID(_ value: String) -> String {
        storedID(value).lowercased()
    }

    private nonisolated static func storedID(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UUID().uuidString.lowercased()
        }
        return trimmed
    }

    func canonicalized() -> Message {
        var copy = self
        copy.id = Self.canonicalID(id)
        copy.serverId = serverId.map(Self.canonicalID)
        return copy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(sender, forKey: .sender)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(localFilePath, forKey: .localFilePath)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(fileUrl, forKey: .fileUrl)
        try container.encodeIfPresent(previewUrl, forKey: .previewUrl)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(syncStatus, forKey: .syncStatus)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(lastError, forKey: .lastError)
        try container.encodeIfPresent(serverId, forKey: .serverId)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
    }
}

struct WebSocketEnvelope: Decodable {
    let type: String
    let payload: Message?
    let message: Message?

    var item: Message? {
        payload ?? message
    }
}

extension DateFormatter {
    static let solodropISO: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func solodropDate(from value: String) -> Date? {
        solodropISO.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
