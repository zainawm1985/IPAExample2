import Foundation

/// 北京限行规则计算器（纯算法，不依赖网络和App Group）
///
/// 规则：
/// - 工作日（周一~周五）限行，周末不限行
/// - 限行时间：7:00-20:00
/// - 限行范围：五环路以内（不含五环路）
/// - 每13周轮换一次，轮换方式：周五规则移到周一，其他后移
///
/// 基准周期：2026-06-29（周一）开始
/// 基准规则：周一1,6 / 周二2,7 / 周三3,8 / 周四4,9 / 周五5,0
enum BeijingLimitCalculator {
    /// 限行周期（13周 = 91天）
    private static let cycleLengthDays = 91
    /// 基准日期：2026-06-29
    private static let baseDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = 29
        comps.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()
    /// 基准规则（周一~周五）
    private static let baseRules = ["1,6", "2,7", "3,8", "4,9", "5,0"]

    /// 上海时区日历
    private static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    // MARK: - 核心查询

    /// 获取某日的限行规则
    /// - Returns: 尾号字符串（如"3,8"），周末返回"不限号"
    static func rule(for date: Date) -> String {
        let weekday = cal.component(.weekday, from: date)
        // weekday: 1=周日, 2=周一, ..., 7=周六
        if weekday == 1 || weekday == 7 {
            return "不限号"
        }
        let weekdayIndex = weekday - 2  // 周一=0, ..., 周五=4

        // 计算当前是第几个周期
        let daysDiff = cal.dateComponents([.day], from: baseDate, to: date).day ?? 0
        let cycleIndex = max(0, daysDiff / cycleLengthDays)
        // 每周期右移1天（周五→周一）
        let shift = cycleIndex % 5
        let ruleIndex = (weekdayIndex - shift + 5) % 5
        return baseRules[ruleIndex]
    }

    // MARK: - 便捷方法

    /// 今日限行
    static func today() -> (dateText: String, rule: String) {
        return (formatDate(Date()), rule(for: Date()))
    }

    /// 明日限行
    static func tomorrow() -> (dateText: String, rule: String) {
        let tmr = cal.date(byAdding: .day, value: 1, to: Date())!
        return (formatDate(tmr), rule(for: tmr))
    }

    /// 本周限行表（周一~周日，7项）
    static func thisWeek() -> (rangeText: String, items: [TrafficLimitData.WeekItem]) {
        return weekTable(offset: 0)
    }

    /// 下周限行表（周一~周日，7项）
    static func nextWeek() -> (rangeText: String, items: [TrafficLimitData.WeekItem]) {
        return weekTable(offset: 1)
    }

    /// 生成完整的 TrafficLimitData（供 Widget 独立使用）
    static func currentData() -> TrafficLimitData {
        let todayInfo = today()
        let tomorrowInfo = tomorrow()
        let this = thisWeek()
        let next = nextWeek()
        return TrafficLimitData(
            city: "北京",
            scope: "本地车",
            today: .init(dateText: todayInfo.dateText, rule: todayInfo.rule),
            tomorrow: .init(dateText: tomorrowInfo.dateText, rule: tomorrowInfo.rule),
            thisWeek: .init(rangeText: this.rangeText, items: this.items),
            nextWeek: .init(rangeText: next.rangeText, items: next.items),
            lastUpdated: Date()
        )
    }

    // MARK: - 私有辅助

    /// 生成某周的限行表
    /// - Parameter offset: 0=本周, 1=下周
    private static func weekTable(offset: Int) -> (rangeText: String, items: [TrafficLimitData.WeekItem]) {
        // 找到本周周一
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let thisWeekMonday = cal.date(from: comps) else {
            return ("", [])
        }
        let targetMonday = cal.date(byAdding: .weekOfYear, value: offset, to: thisWeekMonday)!

        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let items: [TrafficLimitData.WeekItem] = weekdays.enumerated().map { (idx, name) in
            let date = cal.date(byAdding: .day, value: idx, to: targetMonday)!
            return TrafficLimitData.WeekItem(weekday: name, rule: rule(for: date))
        }

        // 范围文本：本周尾号限行（2026年08月03日~2026年08月09日)
        let sunday = cal.date(byAdding: .day, value: 6, to: targetMonday)!
        let rangeText = "\(offset == 0 ? "本周" : "下周")尾号限行（\(formatRangeDate(targetMonday))~\(formatRangeDate(sunday))）"

        return (rangeText, items)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM月dd日(E)"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }

    private static func formatRangeDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年MM月dd日"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: date)
    }
}
