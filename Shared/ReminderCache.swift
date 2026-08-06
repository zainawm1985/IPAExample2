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

    static func todayReminders(now: Date = Date()) -> [Reminder] {
        let all = loadAll()
        return all
            .filter { $0.enabled }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
}
