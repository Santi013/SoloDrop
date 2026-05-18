import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isNetworkAvailable = true
    @Published private(set) var usesWiFi = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.solodrop.network-monitor")
    private var didStart = false

    func start(onChange: @escaping @MainActor (Bool) -> Void) {
        guard !didStart else { return }
        didStart = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let available = path.status == .satisfied
                self?.isNetworkAvailable = available
                self?.usesWiFi = path.usesInterfaceType(.wifi)
                onChange(available)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

final class ServerHealthChecker {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func isServerReachable() async -> Bool {
        await apiClient.checkHealth()
    }
}
