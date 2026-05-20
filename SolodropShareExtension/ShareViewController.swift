import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let store = SharedImportStore()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Сохраняем в SoloDrop..."
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterface()
        handleSharedContent()
    }

    private func configureInterface() {
        view.backgroundColor = .systemBackground

        let stackView = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        activityIndicator.startAnimating()
    }

    private func handleSharedContent() {
        Task {
            do {
                let items = try await extractItems()
                guard !items.isEmpty else {
                    throw ShareExtensionError.noSupportedItems
                }

                let batch = SharedImportBatch(id: UUID(), items: items, createdAt: Date())
                try store.save(batch: batch)
                completeSuccessfully()
            } catch {
                presentFailure(error)
            }
        }
    }

    private func extractItems() async throws -> [SharedImportItem] {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return []
        }

        var importedItems: [SharedImportItem] = []

        for extensionItem in extensionItems {
            for provider in extensionItem.attachments ?? [] {
                if let item = try await loadURL(from: provider) {
                    importedItems.append(item)
                    continue
                }

                if let item = try await loadMediaOrFile(from: provider) {
                    importedItems.append(item)
                }
            }
        }

        return importedItems
    }

    private func loadURL(from provider: NSItemProvider) async throws -> SharedImportItem? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else {
            return nil
        }

        let item = try await provider.solodropLoadItem(forTypeIdentifier: UTType.url.identifier)
        let url: URL?

        if let loadedURL = item as? URL {
            url = loadedURL
        } else if let string = item as? String {
            url = URL(string: string)
        } else {
            url = nil
        }

        guard let url else { return nil }

        return SharedImportItem(
            id: UUID(),
            kind: .url,
            originalFilename: nil,
            sourceURL: url,
            localRelativePath: nil,
            createdAt: Date()
        )
    }

    private func loadMediaOrFile(from provider: NSItemProvider) async throws -> SharedImportItem? {
        let supportedTypes: [(type: UTType, kind: SharedImportItem.Kind)] = [
            (.image, .image),
            (.movie, .video),
            (.audiovisualContent, .video),
            (.data, .file),
            (.item, .file)
        ]

        guard let match = supportedTypes.first(where: {
            provider.hasItemConformingToTypeIdentifier($0.type.identifier)
        }) else {
            return nil
        }

        let copiedURL = try await provider.solodropCopyFileRepresentation(
            forTypeIdentifier: match.type.identifier,
            into: store,
            suggestedFilename: provider.suggestedName
        )

        return SharedImportItem(
            id: UUID(),
            kind: match.kind,
            originalFilename: provider.suggestedName,
            sourceURL: nil,
            localRelativePath: store.relativePath(for: copiedURL),
            createdAt: Date()
        )
    }

    private func completeSuccessfully() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func presentFailure(_ error: Error) {
        activityIndicator.stopAnimating()
        statusLabel.text = "Не удалось сохранить контент"

        let alert = UIAlertController(
            title: "SoloDrop",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Закрыть", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: error)
        })

        present(alert, animated: true)
    }
}

private enum ShareExtensionError: LocalizedError {
    case noSupportedItems

    var errorDescription: String? {
        switch self {
        case .noSupportedItems:
            return "В выбранном контенте нет URL или поддерживаемого файла."
        }
    }
}

private extension NSItemProvider {
    func solodropLoadItem(forTypeIdentifier typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let item = item as? NSSecureCoding else {
                    continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    return
                }

                continuation.resume(returning: item)
            }
        }
    }

    func solodropCopyFileRepresentation(
        forTypeIdentifier typeIdentifier: String,
        into store: SharedImportStore,
        suggestedFilename: String?
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: typeIdentifier) { temporaryURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let temporaryURL else {
                    continuation.resume(throwing: CocoaError(.fileNoSuchFile))
                    return
                }

                do {
                    let copiedURL = try store.copyIntoSharedContainer(
                        sourceURL: temporaryURL,
                        suggestedFilename: suggestedFilename
                    )
                    continuation.resume(returning: copiedURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
