import Foundation

enum ReminderCache {
    private static let filename = "reminders.json"
    static let appGroupID = "group.com.example.IPAExample"

    /// App Group 容器路径（需要合法签名+entitlements才可用，TrollStore下可能为nil）
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(filename)
    }

    /// 硬编码的共享路径（TrollStore 应用以 mobile 用户运行，可访问此目录）
    /// 作为 App Group 不可用时的保底方案，主App和Widget都尝试读写此路径
    private static var sharedFilePath: URL? {
        // /var/mobile/Library/Caches/ 是用户级目录，TrollStore 应用通常可访问
        let path = "/var/mobile/Library/Caches/com.example.IPAExample.shared.json"
        return URL(fileURLWithPath: path)
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
        // 方案1：从 App Group 容器文件读取
        if let url = fileURL,
           let data = try? Data(contentsOf: url) {
            if let reminders = decodeReminders(data) {
                return reminders
            }
        }

        // 方案2：从硬编码共享路径读取（TrollStore 保底方案）
        if let url = sharedFilePath,
           let data = try? Data(contentsOf: url) {
            if let reminders = decodeReminders(data) {
                return reminders
            }
        }

        // 方案3：从 UserDefaults suiteName 读取（备选）
        if let defaults = UserDefaults(suiteName: appGroupID),
           let data = defaults.data(forKey: "reminders_backup") {
            if let reminders = decodeReminders(data) {
                return reminders
            }
        }

        return []
    }

    /// 解码提醒数据（先新格式，再旧格式迁移）
    private static func decodeReminders(_ data: Data) -> [Reminder]? {
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
            saveAll(migrated)
            return migrated
        }
        return nil
    }

    static func saveAll(_ reminders: [Reminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }

        // 方案1：写入 App Group 容器文件
        if let container = containerURL {
            try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            if let url = fileURL {
                try? data.write(to: url, options: .atomic)
            }
        }

        // 方案2：写入硬编码共享路径（TrollStore 保底方案）
        if let url = sharedFilePath {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }

        // 方案3：同时写入 UserDefaults suiteName（三写提高可靠性）
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(data, forKey: "reminders_backup")
        }
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

    /// 诊断信息（用于排查Widget读取不到数据的问题）
    static func diagnosticInfo() -> String {
        var lines: [String] = []
        lines.append("AppGroup ID: \(appGroupID)")

        if let container = containerURL {
            lines.append("AppGroup容器: 可用")
            if let url = fileURL {
                if FileManager.default.fileExists(atPath: url.path) {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attrs?[.size] as? Int ?? 0
                    lines.append("AppGroup文件: \(size) 字节")
                } else {
                    lines.append("AppGroup文件: 不存在")
                }
            }
        } else {
            lines.append("AppGroup容器: nil (不可用)")
        }

        // 检查硬编码共享路径
        if let url = sharedFilePath {
            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs?[.size] as? Int ?? 0
                lines.append("共享文件: \(size) 字节")
                if let data = try? Data(contentsOf: url) {
                    lines.append("共享文件可读: 是 (\(data.count) 字节)")
                }
            } else {
                lines.append("共享文件: 不存在")
            }
        }

        // 也检查 UserDefaults suiteName
        if let defaults = UserDefaults(suiteName: appGroupID) {
            if let data = defaults.data(forKey: "reminders_backup") {
                lines.append("UserDefaults: \(data.count) 字节")
            } else {
                lines.append("UserDefaults: 无")
            }
        } else {
            lines.append("UserDefaults: nil")
        }

        let count = loadAll().count
        lines.append("已加载事件: \(count) 条")

        return lines.joined(separator: "\n")
    }
}
