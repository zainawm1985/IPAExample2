import Foundation

enum BillCache {
    private static let filename = "billdata.json"
    static let appGroupID = ReminderCache.appGroupID

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(filename)
    }

    /// 硬编码的共享路径（TrollStore 保底方案）
    private static var sharedFilePath: URL? {
        URL(fileURLWithPath: "/var/mobile/Library/Caches/com.example.IPAExample.bill.json")
    }

    // MARK: - 读取

    static func load() -> BillData {
        // 方案1：App Group 容器文件
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let bill = try? JSONDecoder().decode(BillData.self, from: data) {
            return bill
        }

        // 方案2：硬编码共享路径
        if let url = sharedFilePath,
           let data = try? Data(contentsOf: url),
           let bill = try? JSONDecoder().decode(BillData.self, from: data) {
            return bill
        }

        // 方案3：UserDefaults suiteName
        if let defaults = UserDefaults(suiteName: appGroupID),
           let data = defaults.data(forKey: "bill_backup"),
           let bill = try? JSONDecoder().decode(BillData.self, from: data) {
            return bill
        }

        return BillData()
    }

    // MARK: - 写入

    static func save(_ bill: BillData) {
        guard let data = try? JSONEncoder().encode(bill) else { return }

        // 方案1：App Group
        if let container = containerURL {
            try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            if let url = fileURL {
                try? data.write(to: url, options: .atomic)
            }
        }

        // 方案2：硬编码共享路径
        if let url = sharedFilePath {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }

        // 方案3：UserDefaults
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(data, forKey: "bill_backup")
        }
    }

    // MARK: - 便捷操作

    /// 设置预算
    static func setBudget(_ budget: Double) {
        var bill = load()
        bill.budget = budget
        save(bill)
    }

    /// 添加一条记录
    static func addRecord(_ record: BillRecord) {
        var bill = load()
        bill.records.append(record)
        save(bill)
    }

    /// 删除一条记录
    static func deleteRecord(_ id: UUID) {
        var bill = load()
        bill.records.removeAll { $0.id == id }
        save(bill)
    }

    // MARK: - 诊断

    static func diagnosticInfo() -> String {
        var lines: [String] = []
        lines.append("AppGroup ID: \(appGroupID)")

        if let container = containerURL {
            lines.append("AppGroup容器: 可用")
            if let url = fileURL {
                if FileManager.default.fileExists(atPath: url.path) {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    lines.append("AppGroup文件: \((attrs?[.size] as? Int) ?? 0) 字节")
                } else {
                    lines.append("AppGroup文件: 不存在")
                }
            }
        } else {
            lines.append("AppGroup容器: nil")
        }

        if let url = sharedFilePath {
            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                lines.append("共享文件: \((attrs?[.size] as? Int) ?? 0) 字节")
            } else {
                lines.append("共享文件: 不存在")
            }
        }

        let bill = load()
        lines.append("预算: \(bill.budget)")
        lines.append("记录数: \(bill.records.count)")
        lines.append("已消费: \(bill.totalSpent)")
        lines.append("剩余: \(bill.remaining)")

        return lines.joined(separator: "\n")
    }
}
