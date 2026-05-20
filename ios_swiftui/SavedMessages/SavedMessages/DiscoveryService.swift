import Foundation
import Combine

struct DiscoveredServer: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let scheme: String
    let discoveredAt: Date

    var urlString: String {
        "\(scheme)://\(host):\(port)"
    }

    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.host == rhs.host
            && lhs.port == rhs.port
            && lhs.scheme == rhs.scheme
    }
}

final class DiscoveryService: NSObject, ObservableObject {
    @Published private(set) var servers: [DiscoveredServer] = []
    @Published private(set) var status = "Bonjour не запущен"
    @Published private(set) var isSearching = false

    private static let serviceType = "_http._tcp."
    private static let serviceDomain = "local."
    private static let appName = "SoloDrop"
    private static let stableHost = "solodrop.local"
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
        status = "Поиск SoloDrop через Bonjour"
        isSearching = true
        browser.searchForServices(ofType: Self.serviceType, inDomain: Self.serviceDomain)
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        browser.stop()
        resolvingServices.removeAll()
        servers = []
        isSearching = false
        status = "Bonjour остановлен"
    }
}

extension DiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard service.name.localizedCaseInsensitiveContains(Self.appName) else { return }
        service.delegate = self
        resolvingServices.append(service)
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.servers.removeAll { $0.name == service.name }
            if self.servers.isEmpty {
                self.status = self.isSearching ? "SoloDrop сервер не найден" : "Bonjour остановлен"
            }
        }
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        DispatchQueue.main.async {
            self.isSearching = true
            self.status = "Поиск SoloDrop через Bonjour"
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        DispatchQueue.main.async {
            guard !self.isSearching else { return }
            self.isSearching = false
            if self.servers.isEmpty {
                self.status = "Bonjour остановлен"
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.isSearching = false
            self.status = "Bonjour недоступен: \(errorDict)"
        }
    }
}

extension DiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        let txt = NetService.dictionary(fromTXTRecord: sender.txtRecordData() ?? Data())
        let app = txt["app"].flatMap { String(data: $0, encoding: .utf8) }
        guard app == nil || app == Self.appName || sender.name.localizedCaseInsensitiveContains(Self.appName) else {
            removeResolvingService(sender)
            return
        }

        let scheme = txt["scheme"].flatMap { String(data: $0, encoding: .utf8) } ?? "http"
        let advertisedHost = txt["stableHost"].flatMap { String(data: $0, encoding: .utf8) }
            ?? txt["stable_host"].flatMap { String(data: $0, encoding: .utf8) }
            ?? sender.hostName
            ?? Self.stableHost
        let host = normalizedHost(advertisedHost)
        let discovered = DiscoveredServer(
            id: "\(host):\(sender.port)",
            name: sender.name,
            host: host,
            port: sender.port,
            scheme: scheme,
            discoveredAt: Date()
        )

        DispatchQueue.main.async {
            if let index = self.servers.firstIndex(where: { $0.id == discovered.id || $0.name == discovered.name }) {
                self.servers[index] = discovered
            } else {
                self.servers.append(discovered)
            }
            self.status = "Найден \(discovered.name) · \(discovered.host):\(discovered.port)"
            self.removeResolvingService(sender)
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.removeResolvingService(sender)
            if self.servers.isEmpty {
                self.status = "Bonjour resolve failed: \(errorDict)"
            }
        }
    }

    private func normalizedHost(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return trimmed.isEmpty ? Self.stableHost : trimmed
    }

    private func removeResolvingService(_ service: NetService) {
        resolvingServices.removeAll { $0 === service }
    }
}
