import Foundation
import SQLite3
import UniformTypeIdentifiers

enum LocalStoreError: LocalizedError {
    case databaseUnavailable
    case sqlite(String)
    case fileCacheUnavailable

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Local database is unavailable."
        case .sqlite(let message):
            return message
        case .fileCacheUnavailable:
            return "Local file cache is unavailable."
        }
    }
}

final class LocalStore {
    static let shared = LocalStore()

    private let queue = DispatchQueue(label: "com.solodrop.local-store")
    private let fileManager = FileManager.default
    private var db: OpaquePointer?
    private var initializationError: Error?

    private lazy var rootDirectory: URL = {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return documents.appendingPathComponent("SoloDrop", isDirectory: true)
    }()

    private lazy var uploadsDirectory: URL = {
        rootDirectory.appendingPathComponent("uploads", isDirectory: true)
    }()

    private lazy var databaseURL: URL = {
        rootDirectory.appendingPathComponent("solodrop.sqlite3")
    }()

    init() {
        do {
            try fileManager.createDirectory(at: uploadsDirectory, withIntermediateDirectories: true)
            try openDatabase()
            try migrate()
        } catch {
            initializationError = error
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func createTextItem(_ text: String, deviceId: String) throws -> Message {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ? "link" : "text"
        let item = Message(type: type, text: trimmed, deviceId: deviceId)
        try upsertLocal(item)
        return item
    }

    func createFileItem(from sourceURL: URL, deviceId: String) throws -> Message {
        let cached = try cacheFile(from: sourceURL)
        let mimeType = cached.mimeType
        let type = (mimeType.hasPrefix("image/") || mimeType.hasPrefix("video/")) ? "media" : "file"
        let item = Message(
            type: type,
            localFilePath: cached.localURL.path,
            fileName: cached.fileName,
            mimeType: cached.mimeType,
            deviceId: deviceId
        )
        try upsertLocal(item)
        return item
    }

    func listItems() throws -> [Message] {
        try queue.sync {
            try ensureReady()
            return deduplicatedCanonicalMessages(try fetchMessages("SELECT * FROM items ORDER BY created_at ASC"))
        }
    }

    func getPendingItems() throws -> [Message] {
        try queue.sync {
            try ensureReady()
            return try fetchMessages(
                "SELECT * FROM items WHERE sync_status = ? ORDER BY created_at ASC",
                [.text(SyncStatus.pending.rawValue)]
            )
        }
    }

    func getRetryableFailedItems(maxRetryCount: Int = 8) throws -> [Message] {
        try queue.sync {
            try ensureReady()
            return try fetchMessages(
                "SELECT * FROM items WHERE sync_status = ? AND retry_count < ? ORDER BY updated_at ASC",
                [.text(SyncStatus.failed.rawValue), .int(maxRetryCount)]
            )
        }
    }

    func upsertLocal(_ item: Message) throws {
        try queue.sync {
            try ensureReady()
            try insertOrReplace(item.canonicalized())
        }
    }

    @discardableResult
    func upsertRemote(_ remoteItem: Message) throws -> Bool {
        try queue.sync {
            try ensureReady()
            let remoteItem = remoteItem.canonicalized()
            let localMatches = try fetchMessages(matching: remoteItem)

            var item = mergedSyncedItem(remoteItem, localMatches: localMatches)
            item.syncStatus = .synced
            item.retryCount = 0
            item.lastError = nil

            if localMatches.count == 1, localMatches[0] == item {
                return false
            }
            try deleteCanonicalDuplicates(except: item.id, localMatches: localMatches)
            try insertOrReplace(item)
            return true
        }
    }

    func markSynced(_ item: Message, remote: Message? = nil) throws {
        try queue.sync {
            try ensureReady()
            let canonicalItem = item.canonicalized()
            let localMatches = try fetchMessages(matching: canonicalItem) + (remote.map { try fetchMessages(matching: $0.canonicalized()) } ?? [])
            var synced = mergedSyncedItem(remote?.canonicalized() ?? canonicalItem, localMatches: localMatches)
            synced.syncStatus = .synced
            synced.retryCount = 0
            synced.lastError = nil
            if synced.serverId == nil {
                synced.serverId = canonicalItem.serverId ?? synced.id
            }
            try deleteCanonicalDuplicates(except: synced.id, localMatches: localMatches)
            try insertOrReplace(synced)
        }
    }

    func markFailed(id: String, error: Error) throws {
        try queue.sync {
            try ensureReady()
            let canonicalID = Message.canonicalID(id)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            try execute(
                """
                UPDATE items
                SET sync_status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ?
                WHERE id = ? OR lower(id) = ?
                """,
                [.text(SyncStatus.failed.rawValue), .text(message), .text(DateFormatter.solodropISO.string(from: Date())), .text(id), .text(canonicalID)]
            )
        }
    }

    func markPending(id: String) throws {
        try queue.sync {
            try ensureReady()
            let canonicalID = Message.canonicalID(id)
            try execute(
                "UPDATE items SET sync_status = ?, last_error = NULL, updated_at = ? WHERE id = ? OR lower(id) = ?",
                [.text(SyncStatus.pending.rawValue), .text(DateFormatter.solodropISO.string(from: Date())), .text(id), .text(canonicalID)]
            )
        }
    }

    func deleteItem(id: String) throws {
        try queue.sync {
            try ensureReady()
            try execute("DELETE FROM items WHERE id = ?", [.text(id)])
        }
    }

    func lastSyncAt() throws -> String? {
        try queue.sync {
            try ensureReady()
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, "SELECT value FROM metadata WHERE key = ?", -1, &statement, nil) == SQLITE_OK else {
                throw LocalStoreError.sqlite(lastErrorMessage)
            }
            sqlite3_bind_text(statement, 1, "last_sync_at", -1, SQLITE_TRANSIENT)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return columnString(statement, 0)
        }
    }

    func setLastSyncAt(_ value: String) throws {
        try queue.sync {
            try ensureReady()
            try execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                [.text("last_sync_at"), .text(value)]
            )
        }
    }

    private func openDatabase() throws {
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw LocalStoreError.databaseUnavailable
        }
    }

    private func migrate() throws {
        try queue.sync {
            try ensureReady()
            try execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id TEXT PRIMARY KEY,
                    type TEXT NOT NULL,
                    sender TEXT NOT NULL,
                    text TEXT,
                    local_file_path TEXT,
                    file_name TEXT,
                    file_url TEXT,
                    preview_url TEXT,
                    mime_type TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    sync_status TEXT NOT NULL,
                    retry_count INTEGER NOT NULL DEFAULT 0,
                    last_error TEXT,
                    server_id TEXT,
                    device_id TEXT
                )
                """
            )
            try execute("CREATE INDEX IF NOT EXISTS idx_items_sync_status ON items(sync_status)")
            try execute("CREATE INDEX IF NOT EXISTS idx_items_updated_at ON items(updated_at)")
            try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            try consolidateCanonicalDuplicates()
        }
    }

    private func cacheFile(from sourceURL: URL) throws -> (localURL: URL, fileName: String, mimeType: String) {
        try fileManager.createDirectory(at: uploadsDirectory, withIntermediateDirectories: true)

        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = sanitizedFilename(sourceURL.lastPathComponent.isEmpty ? "solodrop-file" : sourceURL.lastPathComponent)
        let destination = uploadsDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        let resourceValues = try? sourceURL.resourceValues(forKeys: [.contentTypeKey])
        let mimeType = resourceValues?.contentType?.preferredMIMEType
            ?? UTType(filenameExtension: sourceURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"

        return (destination, fileName, mimeType)
    }

    private func sanitizedFilename(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "solodrop-file" : trimmed
        return fallback
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
    }

    private func insertOrReplace(_ item: Message) throws {
        let item = item.canonicalized()
        try execute(
            """
            INSERT OR REPLACE INTO items (
                id, type, sender, text, local_file_path, file_name, file_url, preview_url, mime_type,
                created_at, updated_at, sync_status, retry_count, last_error, server_id, device_id
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(item.id),
                .text(item.type),
                .text(item.sender),
                .text(item.text),
                .text(item.localFilePath),
                .text(item.fileName),
                .text(item.fileUrl),
                .text(item.previewUrl),
                .text(item.mimeType),
                .text(item.createdAt),
                .text(item.updatedAt),
                .text(item.syncStatus.rawValue),
                .int(item.retryCount),
                .text(item.lastError),
                .text(item.serverId),
                .text(item.deviceId)
            ]
        )
    }

    private func fetchMessage(id: String) throws -> Message? {
        try fetchMessages(matchingCanonicalID: Message.canonicalID(id)).first
    }

    private func fetchMessages(matching item: Message) throws -> [Message] {
        let identities = Set(([item.id, item.serverId].compactMap { $0 }).map(Message.canonicalID))
        var matches: [Message] = []
        var seenIDs = Set<String>()
        for identity in identities {
            let identityMatches = try fetchMessages(matchingCanonicalID: identity)
            for match in identityMatches where !seenIDs.contains(match.id) {
                seenIDs.insert(match.id)
                matches.append(match)
            }
        }
        return matches
    }

    private func fetchMessages(matchingCanonicalID canonicalID: String) throws -> [Message] {
        try fetchMessages(
            """
            SELECT * FROM items
            WHERE lower(id) = ? OR lower(COALESCE(server_id, '')) = ?
            ORDER BY
                CASE sync_status
                    WHEN ? THEN 0
                    WHEN ? THEN 1
                    ELSE 2
                END,
                updated_at DESC
            """,
            [.text(canonicalID), .text(canonicalID), .text(SyncStatus.synced.rawValue), .text(SyncStatus.pending.rawValue)]
        )
    }

    private func fetchMessages(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [Message] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalStoreError.sqlite(lastErrorMessage)
        }
        bind(values: bindings, to: statement)

        var messages: [Message] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            messages.append(message(from: statement))
        }
        return messages
    }

    private func message(from statement: OpaquePointer?) -> Message {
        Message(
            id: columnString(statement, 0) ?? UUID().uuidString,
            type: columnString(statement, 1) ?? "text",
            sender: columnString(statement, 2) ?? "ios",
            text: columnString(statement, 3),
            localFilePath: columnString(statement, 4),
            fileName: columnString(statement, 5),
            fileUrl: columnString(statement, 6),
            previewUrl: columnString(statement, 7),
            mimeType: columnString(statement, 8),
            createdAt: columnString(statement, 9) ?? DateFormatter.solodropISO.string(from: Date()),
            updatedAt: columnString(statement, 10) ?? DateFormatter.solodropISO.string(from: Date()),
            syncStatus: SyncStatus(rawValue: columnString(statement, 11) ?? "") ?? .pending,
            retryCount: Int(sqlite3_column_int(statement, 12)),
            lastError: columnString(statement, 13),
            serverId: columnString(statement, 14),
            deviceId: columnString(statement, 15)
        )
    }

    private func mergedSyncedItem(_ item: Message, localMatches: [Message]) -> Message {
        let canonicalItem = item.canonicalized()
        let preferredLocal = preferredCanonicalMessage(from: localMatches)
        var merged = canonicalItem
        merged.localFilePath = preferredLocal?.localFilePath ?? merged.localFilePath
        merged.fileName = merged.fileName ?? preferredLocal?.fileName
        merged.fileUrl = merged.fileUrl ?? preferredLocal?.fileUrl
        merged.previewUrl = merged.previewUrl ?? preferredLocal?.previewUrl
        merged.mimeType = merged.mimeType ?? preferredLocal?.mimeType
        merged.serverId = merged.serverId ?? preferredLocal?.serverId.map(Message.canonicalID) ?? merged.id
        merged.deviceId = merged.deviceId ?? preferredLocal?.deviceId
        return merged
    }

    private func deduplicatedCanonicalMessages(_ messages: [Message]) -> [Message] {
        var grouped: [String: [Message]] = [:]
        for message in messages {
            grouped[message.canonicalID, default: []].append(message)
        }
        return grouped.values
            .compactMap { preferredCanonicalMessage(from: $0) }
            .sorted { $0.date < $1.date }
    }

    private func preferredCanonicalMessage(from messages: [Message]) -> Message? {
        messages.sorted { lhs, rhs in
            let lhsRank = syncStatusRank(lhs.syncStatus)
            let rhsRank = syncStatusRank(rhs.syncStatus)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            let lhsDate = DateFormatter.solodropDate(from: lhs.updatedAt) ?? .distantPast
            let rhsDate = DateFormatter.solodropDate(from: rhs.updatedAt) ?? .distantPast
            return lhsDate > rhsDate
        }.first?.canonicalized()
    }

    private func syncStatusRank(_ status: SyncStatus) -> Int {
        switch status {
        case .synced:
            return 0
        case .pending:
            return 1
        case .failed:
            return 2
        }
    }

    private func deleteCanonicalDuplicates(except canonicalID: String, localMatches: [Message]) throws {
        for local in localMatches where local.id != canonicalID {
            try execute("DELETE FROM items WHERE id = ?", [.text(local.id)])
        }
    }

    private func consolidateCanonicalDuplicates() throws {
        let messages = try fetchMessages("SELECT * FROM items ORDER BY created_at ASC")
        let grouped = Dictionary(grouping: messages) { $0.canonicalID }
        for (canonicalID, duplicates) in grouped where duplicates.count > 1 {
            guard var preferred = preferredCanonicalMessage(from: duplicates) else { continue }
            preferred.id = canonicalID
            preferred.serverId = preferred.serverId.map(Message.canonicalID) ?? canonicalID
            if preferred.syncStatus == .synced {
                preferred.retryCount = 0
                preferred.lastError = nil
            }
            try deleteCanonicalDuplicates(except: canonicalID, localMatches: duplicates)
            try insertOrReplace(preferred)
        }
    }

    private enum SQLiteValue {
        case text(String?)
        case int(Int)
    }

    private func execute(_ sql: String, _ bindings: [SQLiteValue] = []) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw LocalStoreError.sqlite(lastErrorMessage)
        }
        bind(values: bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LocalStoreError.sqlite(lastErrorMessage)
        }
    }

    private func bind(values: [SQLiteValue], to statement: OpaquePointer?) {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let text):
                if let text {
                    sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(statement, position)
                }
            case .int(let int):
                sqlite3_bind_int(statement, position, Int32(int))
            }
        }
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func ensureReady() throws {
        if let initializationError {
            throw initializationError
        }
        if db == nil {
            throw LocalStoreError.databaseUnavailable
        }
    }

    private var lastErrorMessage: String {
        if let db, let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "Unknown SQLite error."
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
