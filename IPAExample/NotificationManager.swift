import UserNotifications
import WidgetKit

final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() { super.init() }

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = self
    }

    /// 调度提醒（到点触发 + 每60秒自动重复，直到确认）
    func scheduleReminder(_ reminder: Reminder) {
        guard reminder.enabled else { return }

        // 取消旧的通知（防止重复调度）
        cancelReminder(reminder.id)

        let content = UNMutableNotificationContent()
        content.title = "提醒：\(reminder.title)"
        content.body = "点击「确认收到」停止提醒"
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]
        content.categoryIdentifier = "REMINDER_CATEGORY"
        content.interruptionLevel = .timeSensitive

        // 计算从现在到目标时间的秒数
        let timeInterval = reminder.reminderDate.timeIntervalSinceNow

        if timeInterval > 0 {
            // 未来时间：用 UNTimeIntervalNotificationTrigger，首次在目标时间触发，之后每60秒重复
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            center.add(request)

            // 同时调度一个重复通知，在目标时间后60秒开始，每60秒重复
            let repeatContent = UNMutableNotificationContent()
            repeatContent.title = "提醒：\(reminder.title)"
            repeatContent.body = "请确认收到：\(reminder.title)"
            repeatContent.sound = .default
            repeatContent.userInfo = ["reminderId": reminder.id.uuidString]
            repeatContent.categoryIdentifier = "REMINDER_CATEGORY"
            repeatContent.interruptionLevel = .timeSensitive
            let repeatTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval + 60, repeats: true)
            let repeatRequest = UNNotificationRequest(identifier: repeatIdentifier(for: reminder.id), content: repeatContent, trigger: repeatTrigger)
            center.add(repeatRequest)
        } else {
            // 已过时间：立即触发重复通知，每60秒
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            center.add(request)

            // 重复通知
            let repeatContent = UNMutableNotificationContent()
            repeatContent.title = "提醒：\(reminder.title)"
            repeatContent.body = "请确认收到：\(reminder.title)"
            repeatContent.sound = .default
            repeatContent.userInfo = ["reminderId": reminder.id.uuidString]
            repeatContent.categoryIdentifier = "REMINDER_CATEGORY"
            repeatContent.interruptionLevel = .timeSensitive
            let repeatTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
            let repeatRequest = UNNotificationRequest(identifier: repeatIdentifier(for: reminder.id), content: repeatContent, trigger: repeatTrigger)
            center.add(repeatRequest)
        }
    }

    func confirmReminder(_ reminderId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [repeatIdentifier(for: reminderId)])
        center.removeDeliveredNotifications(withIdentifiers: [repeatIdentifier(for: reminderId), reminderId.uuidString])
    }

    func cancelReminder(_ reminderId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [reminderId.uuidString, repeatIdentifier(for: reminderId)])
        center.removeDeliveredNotifications(withIdentifiers: [reminderId.uuidString, repeatIdentifier(for: reminderId)])
    }

    private func repeatIdentifier(for id: UUID) -> String {
        "repeat-\(id.uuidString)"
    }

    func registerCategory() {
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_ACTION",
            title: "确认收到",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [confirmAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.actionIdentifier == "CONFIRM_ACTION",
           let reminderIdStr = response.notification.request.content.userInfo["reminderId"] as? String,
           let reminderId = UUID(uuidString: reminderIdStr) {
            confirmReminder(reminderId)
            var all = ReminderCache.loadAll()
            if let idx = all.firstIndex(where: { $0.id == reminderId }) {
                all[idx].confirmed = true
                ReminderCache.saveAll(all)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
