import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var enabled: Bool
    var createdAt: Date
    var lastTriggered: Date?
    var confirmed: Bool

    init(id: UUID = UUID(), title: String, hour: Int, minute: Int, enabled: Bool = true, createdAt: Date = Date(), lastTriggered: Date? = nil, confirmed: Bool = false) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
        self.createdAt = createdAt
        self.lastTriggered = lastTriggered
        self.confirmed = confirmed
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func isPastDue(now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.hour, .minute], from: now)
        if hour < (nowComps.hour ?? 0) { return true }
        if hour == (nowComps.hour ?? 0) && minute <= (nowComps.minute ?? 0) { return true }
        return false
    }

    var statusText: String {
        if confirmed { return "已完成" }
        if isPastDue() { return "提醒中" }
        return "未到点"
    }
}
