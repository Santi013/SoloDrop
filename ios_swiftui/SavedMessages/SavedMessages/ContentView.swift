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
                                        isSaved: store.savedFileMessageIds.contains(message.id),
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

                    if let errorText = store.errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemBackground))
                    }

                    ComposerBar(
                        text: $store.draftText,
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
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Настройки")
                }
            }
        }
        .task {
            store.start()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(serverAddress: $store.serverAddress, autosaveEnabled: $store.autosaveEnabled) {
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
}

struct MessageBubble: View {
    let message: Message
    let serverAddress: String
    let isSaved: Bool
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
                if message.kind == "file" && isSaved {
                    Text("Файл сохранен")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(message.isFromCurrentDevice ? .white.opacity(0.8) : .secondary)
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
        if message.kind == "file",
           let fileName = message.fileName,
           let fileUrl = message.fileUrl,
           let url = absoluteURL(path: message.previewUrl ?? fileUrl) {
            Link(destination: url) {
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
        "\(message.sender == "ios" || message.sender == "iphone" ? "iPhone" : "ПК") · \(shortDate(message.createdAt))"
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
        if message.kind == "file",
           let fileUrl = message.fileUrl,
           let url = absoluteURL(path: fileUrl) {
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
            let (data, _) = try await URLSession.shared.data(from: url)
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
        if message.kind == "file",
           let fileUrl = message.fileUrl,
           let url = absoluteURL(path: fileUrl) {
            Task { await copyFile(url: url, mimeType: message.mimeType) }
        } else {
            UIPasteboard.general.string = message.text ?? ""
        }
    }

    private func absoluteURL(path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return URL(string: path) }
        let trimmedServer = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedServer)\(path)")
    }

    @MainActor
    private func copyFile(url: URL, mimeType: String?) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
    @Binding var serverAddress: String
    @Binding var autosaveEnabled: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер на ПК") {
                    TextField("http://192.168.1.10:8765", text: $serverAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                Section {
                    Toggle("Автосохранение", isOn: $autosaveEnabled)
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
