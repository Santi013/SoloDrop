import SwiftUI

@main
@MainActor
struct SavedMessagesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: ChatStore

    init() {
        let store = ChatStore()
        _store = StateObject(wrappedValue: store)
        BackgroundSyncScheduler.shared.register {
            await store.syncNow()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task {
                            await store.processSharedImports()
                            await store.syncNow()
                        }
                    } else if newPhase == .background {
                        BackgroundSyncScheduler.shared.schedule()
                    }
                }
        }
    }
}
