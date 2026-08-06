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

    func scheduleReminder(_ reminder: Reminder) {
        guard reminder.enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "提醒：\(reminder.title)"
        content.body = "点击确认收到，否则每分钟重复提醒"
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]
        content.categoryIdentifier = "REMINDER_CATEGORY"

        var comps = DateComponents()
        comps.hour = reminder.hour
        comps.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        center.add(request)
    }

    func startRepeatAlert(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "提醒：\(reminder.title)"
        content.body = "请确认收到"
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]
        content.categoryIdentifier = "REMINDER_CATEGORY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let repeatId = repeatIdentifier(for: reminder.id)
        let request = UNNotificationRequest(identifier: repeatId, content: content, trigger: trigger)
        center.add(request)
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
