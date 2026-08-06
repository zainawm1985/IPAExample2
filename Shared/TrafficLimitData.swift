import Foundation

// MARK: - 数据模型

/// 限行规则数据（从本地宝解析）
struct TrafficLimitData: Codable {
    /// 城市名（如"北京"）
    var city: String
    /// 当前Tab（本地车/外地车）
    var scope: String
    /// 今日限行
    var today: LimitDay
    /// 明日限行
    var tomorrow: LimitDay
    /// 本周尾号表（周一~周日）
    var thisWeek: WeekTable
    /// 下周尾号表
    var nextWeek: WeekTable
    /// 最后更新时间
    var lastUpdated: Date

    struct LimitDay: Codable {
        var dateText: String   // "08月05日(周三)"
        var rule: String       // "3,8" 或 "不限号"
    }

    struct WeekTable: Codable {
        var rangeText: String  // "本周尾号限行（2026年08月03日~2026年08月09日)"
        var items: [WeekItem]  // 7项
    }

    struct WeekItem: Codable {
        var weekday: String    // "周一"
        var rule: String       // "1,6" 或 "不限号"
    }
}

// MARK: - 解析器

enum TrafficLimitParser {
    /// 从本地宝页面HTML解析限行数据
    /// - Returns: 解析成功返回 data，否则返回 nil
    static func parse(html: String) -> TrafficLimitData? {
        guard html.contains("今日限行") else { return nil }

        let city = extractFirstMatch(in: html, pattern: #"class="city-name"[^>]*>([^<]+)<"#) ?? "北京"
        let scope = html.contains(#"class="other chouse""#) ? "外地车" : "本地车"

        // 今日限行
        let todayDate = extractBlockContent(in: html, blockClass: "today", innerClass: "date") ?? ""
        let todayRule = extractBlockContent(in: html, blockClass: "today", innerClass: "rule") ?? ""
        // 明日限行
        let tomorrowDate = extractBlockContent(in: html, blockClass: "tomorrow", innerClass: "date") ?? ""
        let tomorrowRule = extractBlockContent(in: html, blockClass: "tomorrow", innerClass: "rule") ?? ""

        // 本周/下周
        let thisWeek = parseWeekTable(in: html, containerClass: "this-week") ?? TrafficLimitData.WeekTable(rangeText: "", items: [])
        let nextWeek = parseWeekTable(in: html, containerClass: "next-week") ?? TrafficLimitData.WeekTable(rangeText: "", items: [])

        return TrafficLimitData(
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: scope,
            today: .init(dateText: todayDate, rule: todayRule),
            tomorrow: .init(dateText: tomorrowDate, rule: tomorrowRule),
            thisWeek: thisWeek,
            nextWeek: nextWeek,
            lastUpdated: Date()
        )
    }

    /// 检测HTML是否为验证码页面
    static func isCaptchaPage(_ html: String) -> Bool {
        return html.contains("请完成拼图验证") || html.contains("拖动拼图块")
    }

    // MARK: - 私有辅助

    private static func extractFirstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        if let m = regex.firstMatch(in: html, options: [], range: range),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: html) {
            return String(html[r])
        }
        return nil
    }

    /// 提取 `<div class="today">...<div class="date ...">xxx</div>...</div>` 这种结构
    private static func extractBlockContent(in html: String, blockClass: String, innerClass: String) -> String? {
        // 找到 blockClass 容器片段（粗略截取）
        guard let blockRange = findBlockRange(in: html, classKeyword: blockClass) else { return nil }
        let block = String(html[blockRange])
        // 在 block 内找 innerClass 的第一个文本（用 [^"]* 兼容任意class组合）
        let pattern = #"class="[^"]*\#(innerClass)[^"]*"[^>]*>([^<]+)<"#
        return extractFirstMatch(in: block, pattern: pattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 找到含指定 class 的 div 起始位置，用 div 深度匹配找到对应闭合 </div>
    private static func findBlockRange(in html: String, classKeyword: String) -> Range<String.Index>? {
        // 找到 class 含 classKeyword 的位置
        guard let classRange = html.range(of: #"class="[^"]*\#(classKeyword)[^"]*""#, options: .regularExpression) else {
            return nil
        }
        // 向前找最近的 <div（用 .backwards 避免找到页面最外层div）
        guard let divOpenRange = html.range(of: "<div", options: [.backwards], range: html.startIndex..<classRange.lowerBound) else {
            return nil
        }
        let start = divOpenRange.lowerBound
        // 用 div 深度匹配找到对应的 </div>
        guard let end = findMatchingCloseDiv(in: html, startingAt: start) else {
            // 兜底：截取 3000 字符
            let fallback = html.index(start, offsetBy: 3000, limitedBy: html.endIndex) ?? html.endIndex
            return start..<fallback
        }
        return start..<end
    }

    /// 从指定的 <div 位置开始，做 div 深度匹配，返回对应 </div> 的结束位置
    private static func findMatchingCloseDiv(in html: String, startingAt start: String.Index) -> String.Index? {
        var depth = 0
        var searchStart = start
        while searchStart < html.endIndex {
            let openRange = html.range(of: "<div", range: searchStart..<html.endIndex)
            let closeRange = html.range(of: "</div>", range: searchStart..<html.endIndex)
            let nextRange: Range<String.Index>
            let nextIsOpen: Bool
            if let o = openRange, let c = closeRange {
                if o.lowerBound < c.lowerBound {
                    nextIsOpen = true
                    nextRange = o
                } else {
                    nextIsOpen = false
                    nextRange = c
                }
            } else if let o = openRange {
                nextIsOpen = true
                nextRange = o
            } else if let c = closeRange {
                nextIsOpen = false
                nextRange = c
            } else {
                break
            }
            if nextIsOpen {
                depth += 1
            } else {
                depth -= 1
                if depth == 0 {
                    return nextRange.upperBound
                }
            }
            searchStart = nextRange.upperBound
        }
        return nil
    }

    private static func parseWeekTable(in html: String, containerClass: String) -> TrafficLimitData.WeekTable? {
        guard let blockRange = findBlockRange(in: html, classKeyword: containerClass) else { return nil }
        let block = String(html[blockRange])

        // 提取 rangeText
        let rangePattern = #"class="date-from[^"]*"[^>]*>([^<]+)<"#
        let rangeText = extractFirstMatch(in: block, pattern: rangePattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 提取所有 item
        let itemPattern = #"class="item[^"]*">\s*<div class="date[^"]*">([^<]+)</div>\s*<div class="num[^"]*">([^<]+)</div>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: []) else {
            return .init(rangeText: rangeText, items: [])
        }
        let nsRange = NSRange(block.startIndex..., in: block)
        let matches = regex.matches(in: block, options: [], range: nsRange)
        var items: [TrafficLimitData.WeekItem] = []
        for m in matches {
            guard m.numberOfRanges >= 3,
                  let r1 = Range(m.range(at: 1), in: block),
                  let r2 = Range(m.range(at: 2), in: block) else { continue }
            items.append(.init(
                weekday: String(block[r1]).trimmingCharacters(in: .whitespacesAndNewlines),
                rule: String(block[r2]).trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        return .init(rangeText: rangeText, items: items)
    }
}

// MARK: - 缓存

/// 数据缓存（通过 App Group 容器文件在主App与Widget之间共享）
/// 主App写入文件 + 触发WidgetCenter刷新，Widget只读文件不做网络请求
enum TrafficLimitCache {
    private static let cacheFilename = "traffic_limit_data.json"
    static let appGroupID = "group.com.example.IPAExample"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// App Group 共享容器是否可用（用于诊断显示）
    static var appGroupAvailable: Bool {
        return containerURL != nil
    }

    /// 共享容器路径（用于诊断显示）
    static var containerPath: String {
        return containerURL?.path ?? "(不可用)"
    }

    private static var fileURL: URL? {
        guard let container = containerURL else { return nil }
        return container.appendingPathComponent(cacheFilename)
    }

    static func load() -> TrafficLimitData? {
        guard let url = fileURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(TrafficLimitData.self, from: data)
    }

    static func save(_ data: TrafficLimitData) {
        guard let container = containerURL else { return }
        // 确保容器目录存在
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        guard let url = fileURL, let json = try? encoder.encode(data) else { return }
        try? json.write(to: url, options: .atomic)
    }

    static func lastUpdated() -> Date? {
        return load()?.lastUpdated
    }
}

// MARK: - 网络抓取（URLSession，主App与Widget共享）

enum TrafficFetchResult {
    case success(TrafficLimitData)
    case captcha   // 需要手动验证
    case failure(String)
}

final class TrafficFetcher {
    static let shared = TrafficFetcher()
    private init() {}

    func fetch() async -> TrafficFetchResult {
        guard let url = URL(string: "https://m.bj.bendibao.com/news/xianxingchaxun/") else {
            return .failure("URL错误")
        }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://m.bj.bendibao.com/", forHTTPHeaderField: "Referer")
        req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
            // 尝试UTF-8解码
            guard let html = String(data: data, encoding: .utf8) else {
                return .failure("编码失败(data长度=\(data.count), 前100字节=\(data.prefix(100).map { String(format: "%02x", $0) }.joined()))")
            }
            // 检查是否为验证码页
            if TrafficLimitParser.isCaptchaPage(html) {
                return .captcha
            }
            // 检查HTML是否包含关键内容
            if !html.contains("今日限行") {
                return .failure("HTML不含今日限行(长度=\(html.count), 前200字=\(String(html.prefix(200)))")
            }
            if let parsed = TrafficLimitParser.parse(html: html) {
                return .success(parsed)
            }
            return .failure("解析失败(items数检查)")
        } catch {
            return .failure("网络错误：\(error.localizedDescription)")
        }
    }
}
