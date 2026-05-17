import SwiftUI

@main
struct SavedMessagesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }

                    Task {
                        await store.processSharedImports()
                    }
                }
        }
    }
}
