import Foundation

/// 单条账单记录
struct BillRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String           // 内容（如：吃饭、购物）
    var amount: Double          // 价格（金额）
    var date: Date              // 时间（消费日期）
    var createdAt: Date

    init(id: UUID = UUID(), title: String, amount: Double, date: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.createdAt = createdAt
    }

    /// 日期显示 "MM-dd HH:mm"
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }

    /// 完整日期显示 "yyyy-MM-dd HH:mm"
    var fullTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    /// 仅日期显示 "yyyy-MM-dd"
    var dateOnlyString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 金额格式化（保留2位小数）
    var amountString: String {
        String(format: "%.2f", amount)
    }
}

/// 记账整体数据结构（预算 + 所有记录）
struct BillData: Codable, Equatable {
    var budget: Double                   // 预定预算价格
    var records: [BillRecord]            // 所有账单记录

    init(budget: Double = 0, records: [BillRecord] = []) {
        self.budget = budget
        self.records = records
    }

    /// 已消费总额
    var totalSpent: Double {
        records.reduce(0) { $0 + $1.amount }
    }

    /// 剩余预算
    var remaining: Double {
        budget - totalSpent
    }

    /// 消费百分比（0~1）
    var progress: Double {
        guard budget > 0 else { return 0 }
        return min(totalSpent / budget, 1.0)
    }

    /// 按日期分组的记录（按倒序，最新日期在前）
    var recordsByDate: [(date: String, items: [BillRecord])] {
        let grouped = Dictionary(grouping: records) { $0.dateOnlyString }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
    }
}
