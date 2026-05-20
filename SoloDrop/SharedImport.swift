import Foundation

enum SharedImportConstants {
    static let appGroupIdentifier = "group.com.SoloDrop"
}

struct SharedImportItem: Codable, Identifiable {
    enum Kind: String, Codable {
        case url
        case image
        case video
        case file
    }

    let id: UUID
    let kind: Kind
    let originalFilename: String?
    let sourceURL: URL?
    let localRelativePath: String?
    let createdAt: Date
}

struct SharedImportBatch: Codable, Identifiable {
    let id: UUID
    let items: [SharedImportItem]
    let createdAt: Date
}

final class SharedImportStore {
    enum StoreError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            "App Group недоступен. Проверь App Groups у приложения и extension."
        }
    }

    private let fileManager = FileManager.default

    private var containerURL: URL {
        get throws {
            guard let url = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: SharedImportConstants.appGroupIdentifier
            ) else {
                throw StoreError.appGroupUnavailable
            }

            return url
        }
    }

    private var importsDirectory: URL {
        get throws {
            let url = try containerURL
            return url.appendingPathComponent("SharedImports", isDirectory: true)
        }
    }

    private var queueFileURL: URL {
        get throws {
            let directory = try importsDirectory
            return directory.appendingPathComponent("queue.json")
        }
    }

    func save(batch: SharedImportBatch) throws {
        let directory = try importsDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var queue = try loadBatches()
        queue.append(batch)

        let data = try JSONEncoder.solodrop.encode(queue)
        try data.write(to: try queueFileURL, options: [.atomic])
    }

    func loadBatches() throws -> [SharedImportBatch] {
        let fileURL = try queueFileURL

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.solodrop.decode([SharedImportBatch].self, from: data)
    }

    func clearQueue() throws {
        let fileURL = try queueFileURL

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    func copyIntoSharedContainer(sourceURL: URL, suggestedFilename: String?) throws -> URL {
        let directory = try importsDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let filename = sanitizedFilename(suggestedFilename ?? sourceURL.lastPathComponent)
        let destinationURL = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func relativePath(for fileURL: URL) -> String {
        fileURL.lastPathComponent
    }

    func absoluteURL(for relativePath: String) throws -> URL {
        let directory = try importsDirectory
        return directory.appendingPathComponent(relativePath)
    }

    private func sanitizedFilename(_ filename: String) -> String {
        let fallback = "solodrop-shared-file"
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? fallback : trimmed
        let forbidden = CharacterSet(charactersIn: "/\\:")

        return candidate
            .components(separatedBy: forbidden)
            .joined(separator: "-")
    }
}

private extension JSONEncoder {
    static var solodrop: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var solodrop: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
