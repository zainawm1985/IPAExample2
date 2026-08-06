import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var reminderDate: Date    // 完整的提醒时间（年月日时分）
    var enabled: Bool
    var createdAt: Date
    var lastTriggered: Date?
    var confirmed: Bool

    init(id: UUID = UUID(), title: String, reminderDate: Date, enabled: Bool = true, createdAt: Date = Date(), lastTriggered: Date? = nil, confirmed: Bool = false) {
        self.id = id
        self.title = title
        self.reminderDate = reminderDate
        self.enabled = enabled
        self.createdAt = createdAt
        self.lastTriggered = lastTriggered
        self.confirmed = confirmed
    }

    /// 格式化时间显示 "MM-dd HH:mm"
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: reminderDate)
    }

    /// 格式化完整时间 "yyyy-MM-dd HH:mm"
    var fullTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: reminderDate)
    }

    /// 判断当前是否已到提醒时间
    func isPastDue(now: Date = Date()) -> Bool {
        return reminderDate <= now
    }

    /// 状态：未到点 / 提醒中 / 已完成
    var statusText: String {
        if confirmed { return "已完成" }
        if isPastDue() { return "提醒中" }
        return "未到点"
    }
}
