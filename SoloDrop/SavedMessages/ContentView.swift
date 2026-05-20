import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var isShowingFileImporter = false
    @State private var isShowingSettings = false
    @State private var isShowingSidebar = false
    @State private var selectedDateKey: String?
    @State private var selectedMenuMessage: Message?
    @State private var didDismissKeyboardForDrag = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if visibleMessages.isEmpty {
                                EmptyCurrentExchangeView()
                                    .padding(.top, 120)
                            } else {
                                DateDividerView(title: dateTitle(for: currentDateKey))
                                ForEach(visibleMessages) { message in
                                    MessageBubble(
                                        message: message,
                                        serverAddress: store.serverAddress,
                                        connectionStatus: store.connectionStatus,
                                        isSaved: store.savedFileMessageIds.contains(message.id),
                                        onRetry: {
                                            store.retry(message: message)
                                        },
                                        onLongPress: {
                                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                                selectedMenuMessage = message
                                            }
                                        }
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { _ in
                                dismissKeyboardForInteraction(reason: "message scroll")
                            }
                            .onEnded { _ in
                                didDismissKeyboardForDrag = false
                            }
                    )
                    .refreshable {
                        dismissKeyboardForInteraction(reason: "pull-to-refresh", oncePerDrag: false)
                        await store.refresh()
                        didDismissKeyboardForDrag = false
                    }

                    if let errorText = store.errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemBackground))
                    }

                    if let syncResultText = store.syncResultText {
                        SyncResultBanner(text: syncResultText)
                    }

                    ComposerBar(
                        text: $store.draftText,
                        isFocused: $composerFocused,
                        onAttach: { isShowingFileImporter = true },
                        onSend: store.sendDraft
                    )
                }

                if isShowingSidebar {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isShowingSidebar = false
                            }
                        }

                    HistorySidebar(
                        groups: historyGroups,
                        selectedKey: currentDateKey,
                        onSelect: { key in
                            selectedDateKey = key
                            withAnimation(.easeOut(duration: 0.18)) {
                                isShowingSidebar = false
                            }
                        },
                        onClose: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isShowingSidebar = false
                            }
                        }
                    )
                    .transition(.move(edge: .leading))
                }

                if let selectedMenuMessage {
                    FixedMessageMenu(
                        message: selectedMenuMessage,
                        serverAddress: store.serverAddress,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.16)) {
                                self.selectedMenuMessage = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .navigationTitle("SoloDrop")
            .navigationBarTitleDisplayMode(.inline)
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.startLocation.x < 24 && value.translation.width > 70 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowingSidebar = true
                            }
                        }
                    }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isShowingSidebar = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("История")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        ConnectionBadge(status: store.connectionStatus, isSyncing: store.isSyncing)
                        Button {
                            isShowingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Настройки")
                    }
                }
            }
        }
        .task {
            store.start()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                serverAddress: store.serverAddress,
                manualServerAddress: $store.manualServerAddress,
                manualServerOverrideEnabled: $store.manualServerOverrideEnabled,
                autosaveEnabled: $store.autosaveEnabled,
                pairingCode: $store.pairingCode,
                connectionStatus: store.connectionStatus,
                restHealthStatus: store.restHealthStatus,
                webSocketStatus: store.webSocketStatus,
                discoveryStatus: store.discoveryStatus,
                pairingStatus: store.pairingStatus,
                connectedServerInfo: store.connectedServerInfo,
                trustedDeviceStatus: store.trustedDeviceStatus,
                errorText: store.errorText,
                deviceId: store.deviceId,
                discoveredServers: store.discoveredServers,
                onSelectServer: store.select(server:),
                onUseBonjour: { store.useBonjourDiscovery() },
                onApplyManualServer: { store.applyManualServerOverride() },
                onPair: store.pairWithCurrentServer,
                onRetryFailed: store.retryFailedItems,
                onResetPairing: store.resetPairing,
                onReconnect: store.reconnect
            ) {
                store.reconnect()
                isShowingSettings = false
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.sendFile(fileURL: url)
            }
        }
    }

    private var currentDateKey: String {
        selectedDateKey ?? dayKey(for: Date())
    }

    private var visibleMessages: [Message] {
        store.messages.filter { dayKey(for: $0.date) == currentDateKey }
    }

    private var historyGroups: [HistoryDayGroup] {
        let grouped = Dictionary(grouping: store.messages.filter { $0.kind == "file" }) { dayKey(for: $0.date) }
        return grouped.map { key, messages in
            HistoryDayGroup(key: key, title: dateTitle(for: key), count: messages.count)
        }
        .sorted { $0.key > $1.key }
    }

    private func dismissKeyboardForInteraction(reason: String, oncePerDrag: Bool = true) {
        if oncePerDrag, didDismissKeyboardForDrag {
            return
        }
        didDismissKeyboardForDrag = true
        print("[SoloDrop iOS] keyboard dismiss trigger reason=\(reason)")
        composerFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct MessageBubble: View {
    let message: Message
    let serverAddress: String
    let connectionStatus: String
    let isSaved: Bool
    let onRetry: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack {
            if message.isFromCurrentDevice {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.isFromCurrentDevice ? .trailing : .leading, spacing: 5) {
                messageContent
                Text(metaText)
                    .font(.caption2)
                    .foregroundStyle(message.isFromCurrentDevice ? .white.opacity(0.75) : .secondary)
                if message.isFileBacked && isSaved {
                    Text("Файл сохранен")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(message.isFromCurrentDevice ? .white.opacity(0.8) : .secondary)
                }
                if message.syncStatus == .failed {
                    Button(action: onRetry) {
                        Label("Повторить", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(message.isFromCurrentDevice ? .white : .blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(message.isFromCurrentDevice ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(message.isFromCurrentDevice ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)

            if !message.isFromCurrentDevice {
                Spacer(minLength: 48)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if message.isFileBacked,
           let fileName = message.fileName {
            if let url = displayURL {
                Link(destination: url) {
                    Label(fileName, systemImage: "paperclip")
                        .font(.body)
                        .lineLimit(3)
                }
            } else {
                Label(fileName, systemImage: "paperclip")
                    .font(.body)
                    .lineLimit(3)
            }
        } else if message.kind == "link",
                  let text = message.text,
                  let url = URL(string: text) {
            Link(text, destination: url)
                .font(.body)
                .multilineTextAlignment(message.isFromCurrentDevice ? .trailing : .leading)
        } else {
            Text(message.text ?? "")
                .font(.body)
                .multilineTextAlignment(message.isFromCurrentDevice ? .trailing : .leading)
        }
    }

    private var metaText: String {
        "\(message.sender == "ios" || message.sender == "iphone" ? "iPhone" : "ПК") · \(shortDate(message.createdAt)) · \(statusText)"
    }

    private var statusText: String {
        switch message.syncStatus {
        case .pending:
            if connectionStatus == "Офлайн" || connectionStatus == "Требуется pairing" {
                return "offline"
            }
            return "pending"
        case .synced:
            return "synced"
        case .failed:
            return "failed"
        }
    }

    private var displayURL: URL? {
        if let localFilePath = message.localFilePath {
            return URL(fileURLWithPath: localFilePath)
        }
        if let previewUrl = message.previewUrl {
            return absoluteURL(path: previewUrl)
        }
        if let fileUrl = message.fileUrl {
            return absoluteURL(path: fileUrl)
        }
        return nil
    }

    private func absoluteURL(path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        let trimmedServer = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedServer)\(path)")
    }

    private func shortDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) ?? Date()

        let output = DateFormatter()
        output.locale = Locale(identifier: "ru_RU")
        output.dateFormat = "dd.MM HH:mm"
        return output.string(from: date)
    }

    private func copyMessage() {
        if message.isFileBacked,
           let url = displayURL {
            Task {
                await copyFile(url: url, mimeType: message.mimeType)
            }
            return
        }

        UIPasteboard.general.string = message.text ?? ""
    }

    @MainActor
    private func copyFile(url: URL, mimeType: String?) async {
        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: url)
                data = remoteData
            }
            if mimeType?.hasPrefix("image/") == true,
               let image = UIImage(data: data) {
                UIPasteboard.general.image = image
                return
            }

            if let mimeType,
               let typeIdentifier = UTType(mimeType: mimeType)?.identifier {
                UIPasteboard.general.setData(data, forPasteboardType: typeIdentifier)
                return
            }

            UIPasteboard.general.url = url
        } catch {
            UIPasteboard.general.url = url
        }
    }
}

struct FixedMessageMenu: View {
    let message: Message
    let serverAddress: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 6) {
                Button {
                    copyMessage()
                    onDismiss()
                } label: {
                    Label("Копировать", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .frame(width: 220)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(radius: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyMessage() {
        if message.isFileBacked,
           let url = displayURL {
            Task { await copyFile(url: url, mimeType: message.mimeType) }
        } else {
            UIPasteboard.general.string = message.text ?? ""
        }
    }

    private var displayURL: URL? {
        if let localFilePath = message.localFilePath {
            return URL(fileURLWithPath: localFilePath)
        }
        if let fileUrl = message.fileUrl {
            return absoluteURL(path: fileUrl)
        }
        return nil
    }

    private func absoluteURL(path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        let trimmedServer = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedServer)\(path)")
    }

    @MainActor
    private func copyFile(url: URL, mimeType: String?) async {
        do {
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: url)
                data = remoteData
            }
            if mimeType?.hasPrefix("image/") == true, let image = UIImage(data: data) {
                UIPasteboard.general.image = image
            } else if let mimeType, let typeIdentifier = UTType(mimeType: mimeType)?.identifier {
                UIPasteboard.general.setData(data, forPasteboardType: typeIdentifier)
            } else {
                UIPasteboard.general.url = url
            }
        } catch {
            UIPasteboard.general.url = url
        }
    }
}

private func dayKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = .current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func dateTitle(for key: String) -> String {
    let formatter = DateFormatter()
    formatter.calendar = .current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: key) else { return key }

    if Calendar.current.isDateInToday(date) { return "Сегодня" }
    if Calendar.current.isDateInYesterday(date) { return "Вчера" }

    let output = DateFormatter()
    output.locale = Locale(identifier: "ru_RU")
    output.dateFormat = "d MMMM yyyy"
    return output.string(from: date)
}

struct HistoryDayGroup: Identifiable {
    let key: String
    let title: String
    let count: Int
    var id: String { key }
}

struct HistorySidebar: View {
    let groups: [HistoryDayGroup]
    let selectedKey: String
    let onSelect: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("История")
                        .font(.headline)
                    Text("Передачи по датам")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
            }
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(groups) { group in
                        Button {
                            onSelect(group.key)
                        } label: {
                            HStack {
                                Text(group.title)
                                Spacer()
                                Text("\(group.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(group.key == selectedKey ? Color(.secondarySystemGroupedBackground) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if groups.isEmpty {
                        Text("Файлов пока нет")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(width: 310)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
        .shadow(radius: 22)
    }
}

struct DateDividerView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .padding(.vertical, 6)
    }
}

struct ConnectionBadge: View {
    let status: String
    let isSyncing: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(isSyncing ? "syncing" : status.lowercased())
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel("Статус подключения: \(status)")
    }

    private var color: Color {
        if isSyncing { return .orange }
        if status == "Онлайн" { return .green }
        if status == "Подключение" || status == "Переподключение" || status == "Синхронизация" { return .orange }
        return .secondary
    }
}

struct SyncResultBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(.systemBackground))
            .accessibilityLabel(text)
    }
}

struct EmptyCurrentExchangeView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Текущий обмен")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Отправьте файл или откройте историю слева, чтобы посмотреть передачи за нужный день.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
    }
}

struct ComposerBar: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let onAttach: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAttach) {
                Image(systemName: "paperclip")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Прикрепить файл")

            TextField("Сообщение или ссылка", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .submitLabel(.send)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Отправить")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct SettingsView: View {
    let serverAddress: String
    @Binding var manualServerAddress: String
    @Binding var manualServerOverrideEnabled: Bool
    @Binding var autosaveEnabled: Bool
    @Binding var pairingCode: String
    let connectionStatus: String
    let restHealthStatus: String
    let webSocketStatus: String
    let discoveryStatus: String
    let pairingStatus: String
    let connectedServerInfo: String
    let trustedDeviceStatus: String
    let errorText: String?
    let deviceId: String
    let discoveredServers: [DiscoveredServer]
    let onSelectServer: (DiscoveredServer) -> Void
    let onUseBonjour: () -> Void
    let onApplyManualServer: () -> Void
    let onPair: () -> Void
    let onRetryFailed: () -> Void
    let onResetPairing: () -> Void
    let onReconnect: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер на ПК") {
                    LabeledContent("Адрес", value: serverAddress)
                    LabeledContent("Статус", value: connectionStatus)
                    LabeledContent("REST", value: restHealthStatus)
                    LabeledContent("WebSocket", value: webSocketStatus)
                    LabeledContent("Bonjour", value: discoveryStatus)
                    LabeledContent("Pairing", value: pairingStatus)
                    LabeledContent("Trusted", value: trustedDeviceStatus)
                    Text(connectedServerInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Bonjour discovery") {
                    if discoveredServers.isEmpty {
                        Text("Серверы не найдены")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(discoveredServers) { server in
                            Button {
                                onSelectServer(server)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name)
                                    Text(server.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button("Использовать Bonjour / solodrop.local", action: onUseBonjour)
                    if manualServerOverrideEnabled {
                        Text("Manual override включён: Bonjour показывается, но не меняет активный адрес автоматически.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pairing") {
                    TextField("PIN с ПК", text: $pairingCode)
                        .keyboardType(.numberPad)
                    Button(pairingStatus == "Подключено" ? "Re-pair с PIN" : "Подключить по PIN", action: onPair)
                        .disabled(pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Device ID: \(deviceId)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Manual override") {
                    Toggle("Включить manual server address", isOn: $manualServerOverrideEnabled)
                    TextField("http://192.168.1.10:8000", text: $manualServerAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button("Применить manual address", action: onApplyManualServer)
                    Text("Backup/debug режим. Для обычного подключения используется Bonjour и stable hostname solodrop.local.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Автосохранение", isOn: $autosaveEnabled)
                }

                Section {
                    Button("Переподключиться", action: onReconnect)
                    Button("Повторить failed items", action: onRetryFailed)
                    Button("Disconnect / reset pairing", role: .destructive, action: onResetPairing)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", action: onSave)
                }
            }
        }
    }
}
