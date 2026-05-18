import SwiftUI

@main
struct SavedMessagesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    BackgroundSyncScheduler.shared.register {
                        await store.syncNow()
                    }
                }
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
