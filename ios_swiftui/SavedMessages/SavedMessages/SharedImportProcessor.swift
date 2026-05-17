import Foundation

@MainActor
final class SharedImportProcessor {
    private let store = SharedImportStore()
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func processPendingImports() async throws -> Int {
        let batches = try store.loadBatches()
        var processedCount = 0

        for batch in batches {
            for item in batch.items {
                try await process(item)
                processedCount += 1
            }
        }

        if processedCount > 0 {
            try store.clearQueue()
        }

        return processedCount
    }

    private func process(_ item: SharedImportItem) async throws {
        switch item.kind {
        case .url:
            guard let url = item.sourceURL else { return }
            try await apiClient.sendText(url.absoluteString)

        case .image, .video, .file:
            guard let relativePath = item.localRelativePath else { return }
            let fileURL = try store.absoluteURL(for: relativePath)
            try await apiClient.sendFile(fileURL: fileURL)
        }
    }
}
