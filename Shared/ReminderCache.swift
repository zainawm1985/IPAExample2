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

    /// 旧格式（hour/minute）兼容结构
    private struct LegacyReminder: Codable {
        let id: UUID
        let title: String
        let hour: Int
        let minute: Int
        let enabled: Bool
        let createdAt: Date
        let lastTriggered: Date?
        let confirmed: Bool
    }

    static func loadAll() -> [Reminder] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else {
            return []
        }
        // 先尝试新格式解码
        if let reminders = try? JSONDecoder().decode([Reminder].self, from: data) {
            return reminders
        }
        // 新格式失败，尝试旧格式（hour/minute）并迁移
        if let legacy = try? JSONDecoder().decode([LegacyReminder].self, from: data) {
            let migrated: [Reminder] = legacy.map { old in
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: old.createdAt)
                comps.hour = old.hour
                comps.minute = old.minute
                let date = cal.date(from: comps) ?? old.createdAt
                return Reminder(
                    id: old.id,
                    title: old.title,
                    reminderDate: date,
                    enabled: old.enabled,
                    createdAt: old.createdAt,
                    lastTriggered: old.lastTriggered,
                    confirmed: old.confirmed
                )
            }
            // 保存迁移后的数据
            saveAll(migrated)
            return migrated
        }
        return []
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
