import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru
    case en

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .ru:
            return "ru-RU"
        case .en:
            return "en-US"
        }
    }

    var nativeName: String {
        switch self {
        case .ru:
            return "Русский"
        case .en:
            return "English"
        }
    }
}

@MainActor
final class AppLanguageSettings: ObservableObject {
    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "solodrop.iOS.language"

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: stored) {
            current = language
            return
        }

        let preferred = Locale.preferredLanguages
            .compactMap { AppLanguage(rawValue: String($0.prefix(2)).lowercased()) }
            .first
        current = preferred ?? .ru
    }

    var locale: Locale {
        Locale(identifier: current.localeIdentifier)
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func localizedStatus(_ value: String) -> String {
        if let count = pendingCount(in: value, prefix: "Синхронизировано · отправлено ") {
            return String(
                format: localized("Синхронизировано · отправлено %lld ожидающих сообщений"),
                locale: locale,
                count
            )
        }

        if let count = pendingCount(in: value, prefix: "Отправлено ") {
            return String(
                format: localized("Отправлено %lld ожидающих сообщений"),
                locale: locale,
                count
            )
        }

        if value.hasPrefix("Pairing failed: ") {
            let detail = String(value.dropFirst("Pairing failed: ".count))
            return String(format: localized("Pairing failed: %@"), locale: locale, detail)
        }

        if value.hasPrefix("Bonjour недоступен: ") {
            let detail = String(value.dropFirst("Bonjour недоступен: ".count))
            return String(format: localized("Bonjour недоступен: %@"), locale: locale, detail)
        }

        if value.hasPrefix("Найден ") {
            let detail = String(value.dropFirst("Найден ".count))
            return String(format: localized("Найден %@"), locale: locale, detail)
        }

        let generationSeparator = " · gen "
        if let range = value.range(of: generationSeparator) {
            let base = String(value[..<range.lowerBound])
            return localized(base) + String(value[range.lowerBound...])
        }

        let suffixes = [
            " · manual override",
            " · Bonjour/stable"
        ]

        for suffix in suffixes where value.hasSuffix(suffix) {
            let base = String(value.dropLast(suffix.count))
            return localized(base) + localized(suffix)
        }

        return localized(value)
    }

    private func pendingCount(in value: String, prefix: String) -> Int? {
        guard value.hasPrefix(prefix),
              value.hasSuffix(" ожидающих сообщений") else {
            return nil
        }

        let numberText = value
            .dropFirst(prefix.count)
            .dropLast(" ожидающих сообщений".count)
        return Int(numberText)
    }

    func shortDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) ?? Date()

        let output = DateFormatter()
        output.locale = locale
        output.dateFormat = "dd.MM HH:mm"
        return output.string(from: date)
    }

    func dateTitle(for key: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: key) else { return key }

        if Calendar.current.isDateInToday(date) { return localized("Сегодня") }
        if Calendar.current.isDateInYesterday(date) { return localized("Вчера") }

        let output = DateFormatter()
        output.locale = locale
        output.dateFormat = "d MMMM yyyy"
        return output.string(from: date)
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: current.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
