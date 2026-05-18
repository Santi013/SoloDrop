import BackgroundTasks
import Foundation

final class BackgroundSyncScheduler {
    static let shared = BackgroundSyncScheduler()
    static let taskIdentifier = "com.solodrop.app.sync"

    private var isRegistered = false

    private init() {}

    func register(handler: @escaping @MainActor () async -> Void) {
        guard !isRegistered else { return }
        isRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            self.handle(task: task, handler: handler)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(task: BGTask, handler: @escaping @MainActor () async -> Void) {
        schedule()

        let syncTask = Task { @MainActor in
            await handler()
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }
}
