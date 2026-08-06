import BackgroundTasks
import WidgetKit

/// 后台任务管理器：注册并调度 BGAppRefreshTask，让 App 在后台也能定期更新限行数据
enum BackgroundTaskManager {
    static let refreshTaskID = "com.example.IPAExample.traffic.refresh"

    /// 注册后台任务（必须在 App 启动时调用，且在 didFinishLaunching 之前）
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskID,
            using: nil
        ) { task in
            handleRefreshTask(task as! BGAppRefreshTask)
        }
    }

    /// 调度下一次后台刷新任务
    static func scheduleNextRefresh(after interval: TimeInterval = 30 * 60) {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // 调度失败（可能系统不允许多任务或低电量模式），忽略
        }
    }

    /// 处理后台刷新任务
    private static func handleRefreshTask(_ task: BGAppRefreshTask) {
        // 无论任务成功失败，都调度下一次
        scheduleNextRefresh()

        let operation = RefreshOperation()
        task.expirationHandler = {
            operation.cancel()
        }

        operation.completion = { success in
            task.setTaskCompleted(success: success)
        }

        operation.start()
    }

    /// 实际执行刷新操作的小帮手
    private final class RefreshOperation: Operation {
        var completion: ((Bool) -> Void)?
        private var task: Task<Void, Never>?

        override func start() {
            task = Task {
                let result = await TrafficFetcher.shared.fetch()
                switch result {
                case .success(let data):
                    TrafficLimitCache.save(data)
                    // 通知 Widget 刷新
                    WidgetCenter.shared.reloadAllTimelines()
                    completion?(true)
                case .captcha, .failure:
                    // 验证码或失败时用缓存兜底，仍标记为成功（避免系统降低调度频率）
                    if TrafficLimitCache.load() != nil {
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                }
            }
        }

        override func cancel() {
            task?.cancel()
            completion?(false)
        }
    }
}
