import SwiftUI
import BackgroundTasks
import WidgetKit

@main
struct IPAExampleApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundTaskManager.register()
        BackgroundTaskManager.scheduleNextRefresh()
        NotificationManager.shared.requestAuthorization()
        NotificationManager.shared.registerCategory()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        BackgroundTaskManager.scheduleNextRefresh()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
    }
}
