import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    @AppStorage("serverAddress") private var serverAddress = "http://192.168.10.3:8765"
    @AppStorage("autosaveEnabled") private var autosaveEnabled = false
    @State private var addressDraft = ""
    @State private var isShowingSettings = false
    @State private var reloadToken = UUID()

    var body: some View {
        NavigationView {
            SoloDropWebView(urlString: serverAddress, reloadToken: reloadToken, autosaveEnabled: autosaveEnabled)
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
                        autosaveEnabled: $autosaveEnabled,
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
    @Binding var autosaveEnabled: Bool
    @Binding var isShowingSettings: Bool
    let onReload: () -> Void

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
                    Toggle("Автосохранение", isOn: $autosaveEnabled)
                }

                if let errorText = errorText {
                    Section {
                        Text(errorText)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
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
}

struct SoloDropWebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: UUID
    let autosaveEnabled: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let source = """
        const viewport = document.querySelector('meta[name=viewport]') || document.createElement('meta');
        viewport.name = 'viewport';
        viewport.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover';
        if (!viewport.parentNode) document.head.appendChild(viewport);
        ['gesturestart', 'gesturechange', 'gestureend'].forEach((name) => {
          document.addEventListener(name, (event) => event.preventDefault(), { passive: false });
        });
        document.addEventListener('touchmove', (event) => {
          if (event.touches.length > 1) event.preventDefault();
        }, { passive: false });
        """
        configuration.userContentController.addUserScript(WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        configuration.userContentController.add(context.coordinator, name: "solodropAutosave")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.bouncesZoom = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.delegate = context.coordinator
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

        let value = autosaveEnabled ? "true" : "false"
        webView.evaluateJavaScript("""
        localStorage.setItem('solodropAutosave:ios', '\(value)');
        const toggle = document.querySelector('#autosaveToggle');
        if (toggle) toggle.checked = \(value);
        """)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, WKScriptMessageHandler {
        var lastReloadToken: UUID?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "solodropAutosave",
                  let payload = message.body as? [String: Any],
                  let urlString = payload["url"] as? String,
                  let url = URL(string: urlString) else {
                return
            }

            let fileName = payload["fileName"] as? String ?? url.lastPathComponent
            let mimeType = payload["mimeType"] as? String ?? "application/octet-stream"
            autosaveFile(url: url, fileName: fileName, mimeType: mimeType)
        }

        private func autosaveFile(url: URL, fileName: String, mimeType: String) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data else { return }

                if mimeType.hasPrefix("image/"), let image = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    return
                }

                do {
                    let documents = try FileManager.default.url(
                        for: .documentDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )
                    let folder = documents.appendingPathComponent("SoloDrop", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = uniqueDestination(in: folder, fileName: fileName)
                    try data.write(to: destination, options: .atomic)
                } catch {
                    return
                }
            }.resume()
        }

        private func uniqueDestination(in folder: URL, fileName: String) -> URL {
            let cleanName = fileName.isEmpty ? "solodrop-file" : fileName
            let base = (cleanName as NSString).deletingPathExtension
            let ext = (cleanName as NSString).pathExtension
            var destination = folder.appendingPathComponent(cleanName)
            var counter = 2

            while FileManager.default.fileExists(atPath: destination.path) {
                let candidate = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
                destination = folder.appendingPathComponent(candidate)
                counter += 1
            }

            return destination
        }
    }
}
