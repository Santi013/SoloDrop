import SwiftUI
import WebKit

struct ContentView: View {
    @AppStorage("serverAddress") private var serverAddress = "http://192.168.10.3:8765"
    @State private var addressDraft = ""
    @State private var isShowingSettings = false
    @State private var reloadToken = UUID()

    var body: some View {
        NavigationView {
            SoloDropWebView(urlString: serverAddress, reloadToken: reloadToken)
                .navigationTitle("SoloDrop")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button(action: {
                        addressDraft = serverAddress
                        isShowingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(
                        addressDraft: $addressDraft,
                        serverAddress: $serverAddress,
                        isShowingSettings: $isShowingSettings,
                        onReload: {
                            reloadToken = UUID()
                        }
                    )
                }
        }
    }
}

struct SettingsView: View {
    @Binding var addressDraft: String
    @Binding var serverAddress: String
    @Binding var isShowingSettings: Bool
    let onReload: () -> Void

    @AppStorage("autosaveEnabled") private var autosaveEnabled = false
    @State private var isShowingClearConfirmation = false
    @State private var errorText: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Адрес сервера SoloDrop")) {
                    TextField("http://192.168.10.3:8765", text: $addressDraft)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                Section {
                    Button(role: .destructive) {
                        isShowingClearConfirmation = true
                    } label: {
                        Label("Очистить чат", systemImage: "trash")
                    }
                }

                Toggle("Автосохранение", isOn: $autosaveEnabled)
                
                if let errorText = errorText {
                    Section {
                        Text(errorText)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Очистить весь чат и удалить загруженные файлы?",
                isPresented: $isShowingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Очистить чат", role: .destructive) {
                    clearChat()
                }

                Button("Отмена", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isShowingSettings = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        serverAddress = addressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        onReload()
                        isShowingSettings = false
                    }
                }
            }
        }
    }

    private func clearChat() {
        let trimmedAddress = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(trimmedAddress)/api/messages") else {
            errorText = "Неверный адрес сервера."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    errorText = "Не удалось очистить чат. Проверьте соединение с сервером."
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    errorText = "Сервер не подтвердил очистку чата."
                    return
                }

                errorText = nil
                onReload()
                isShowingSettings = false
            }
        }.resume()
    }
}

struct SoloDropWebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: UUID

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else {
            return
        }

        if webView.url?.absoluteString != url.absoluteString || context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastReloadToken: UUID?
    }
}
