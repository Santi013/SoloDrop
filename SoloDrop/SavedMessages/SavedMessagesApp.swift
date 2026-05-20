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
                    print("[SoloDrop iOS] scenePhase changed \(String(describing: newPhase))")
                    if newPhase == .active {
                        store.appDidBecomeActive()
                    } else if newPhase == .background {
                        store.appDidEnterBackground()
                        BackgroundSyncScheduler.shared.schedule()
                    } else if newPhase == .inactive {
                        store.appWillResignActive()
                    }
                }
        }
    }
}
