import Foundation

enum ReminderCache {
    private static let filename = "reminders.json"
    static let appGroupID = "group.com.example.IPAExample"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(filename)
    }

    static func loadAll() -> [Reminder] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let reminders = try? JSONDecoder().decode([Reminder].self, from: data) else {
            return []
        }
        return reminders
    }

    static func saveAll(_ reminders: [Reminder]) {
        guard let container = containerURL else { return }
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        guard let url = fileURL, let data = try? JSONEncoder().encode(reminders) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 获取当日事件（按时间升序）
    static func todayReminders(now: Date = Date()) -> [Reminder] {
        let all = loadAll()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!
        return all
            .filter { $0.enabled && $0.reminderDate >= todayStart && $0.reminderDate < todayEnd }
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    /// 获取需要显示的事件（今日事件 + 所有未确认的过期事件）
    static func displayReminders(now: Date = Date()) -> [Reminder] {
        let all = loadAll()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!

        return all
            .filter { reminder in
                guard reminder.enabled else { return false }
                // 今日事件
                if reminder.reminderDate >= todayStart && reminder.reminderDate < todayEnd {
                    return true
                }
                // 未确认的过期事件（跨天后也持续显示）
                if !reminder.confirmed && reminder.reminderDate < todayStart {
                    return true
                }
                return false
            }
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    /// 获取未来事件（明日及以后）
    static func upcomingReminders(now: Date = Date()) -> [Reminder] {
        let all = loadAll()
        let cal = Calendar.current
        let todayEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!

        return all
            .filter { $0.enabled && $0.reminderDate >= todayEnd && $0.confirmed == false }
            .sorted { $0.reminderDate < $1.reminderDate }
    }
}
