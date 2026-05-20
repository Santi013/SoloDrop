import Foundation
import Combine
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
            guard let monitor = self else { return }
            let available = path.status == .satisfied
            let usesWiFi = path.usesInterfaceType(.wifi)
            Task { @MainActor in
                monitor.isNetworkAvailable = available
                monitor.usesWiFi = usesWiFi
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
