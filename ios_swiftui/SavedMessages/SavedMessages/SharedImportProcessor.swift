import Foundation

final class SharedImportProcessor {
    private let importStore = SharedImportStore()
    private let localStore: LocalStore
    private let deviceId: String

    init(localStore: LocalStore, deviceId: String) {
        self.localStore = localStore
        self.deviceId = deviceId
    }

    func processPendingImports() throws -> Int {
        let batches = try importStore.loadBatches()
        var processedCount = 0

        for batch in batches {
            for item in batch.items {
                try process(item)
                processedCount += 1
            }
        }

        if processedCount > 0 {
            try importStore.clearQueue()
        }

        return processedCount
    }

    private func process(_ item: SharedImportItem) throws {
        switch item.kind {
        case .url:
            guard let url = item.sourceURL else { return }
            _ = try localStore.createTextItem(url.absoluteString, deviceId: deviceId)

        case .image, .video, .file:
            guard let relativePath = item.localRelativePath else { return }
            let fileURL = try importStore.absoluteURL(for: relativePath)
            _ = try localStore.createFileItem(from: fileURL, deviceId: deviceId)
        }
    }
}
