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
}
