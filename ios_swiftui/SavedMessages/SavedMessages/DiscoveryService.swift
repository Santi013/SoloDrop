import Foundation

struct DiscoveredServer: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let scheme: String

    var urlString: String {
        "\(scheme)://\(host):\(port)"
    }
}

final class DiscoveryService: NSObject, ObservableObject {
    @Published private(set) var servers: [DiscoveredServer] = []

    private let browser = NetServiceBrowser()
    private var resolvingServices: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        browser.stop()
        servers = []
        resolvingServices = []
        browser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        resolvingServices.removeAll()
    }
}

extension DiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard service.name.localizedCaseInsensitiveContains("SoloDrop") else { return }
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.servers.removeAll { $0.name == service.name }
        }
    }
}

extension DiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        let txt = NetService.dictionary(fromTXTRecord: sender.txtRecordData() ?? Data())
        let scheme = txt["scheme"].flatMap { String(data: $0, encoding: .utf8) } ?? "https"
        let host = (sender.hostName ?? "solodrop.local").trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let discovered = DiscoveredServer(
            id: "\(host):\(sender.port)",
            name: sender.name,
            host: host,
            port: sender.port,
            scheme: scheme
        )

        DispatchQueue.main.async {
            if !self.servers.contains(discovered) {
                self.servers.append(discovered)
            }
        }
    }
}
