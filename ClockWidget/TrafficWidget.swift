import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TrafficEntry: TimelineEntry {
    let date: Date
    let data: TrafficLimitData?
    let needsCaptcha: Bool
    let errorMessage: String?
}

// MARK: - Provider

struct TrafficProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrafficEntry {
        TrafficEntry(date: Date(), data: nil, needsCaptcha: false, errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrafficEntry) -> Void) {
        let cached = TrafficLimitCache.load()
        completion(TrafficEntry(date: Date(), data: cached, needsCaptcha: false, errorMessage: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrafficEntry>) -> Void) {
        // Widget 只读 App Group 容器文件，不做网络请求
        // 主 App 写入数据后会调用 WidgetCenter.reloadAllTimelines() 触发刷新
        let cached = TrafficLimitCache.load()
        let entry: TrafficEntry
        if let d = cached {
            entry = TrafficEntry(date: Date(), data: d, needsCaptcha: false, errorMessage: nil)
        } else {
            entry = TrafficEntry(date: Date(), data: nil, needsCaptcha: false, errorMessage: "暂无数据，请打开App刷新")
        }
        // 每30分钟检查一次（即使没有新数据也会重新读取文件）
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget View

struct TrafficWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TrafficEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTrafficView(entry: entry)
        case .systemMedium:
            MediumTrafficView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeTrafficView(entry: entry)
        default:
            SmallTrafficView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallTrafficView: View {
    var entry: TrafficEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.56, blue: 0.98), Color(red: 0.06, green: 0.32, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                if let d = entry.data {
                    Text("今日限行")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(d.today.dateText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(d.today.rule)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(d.today.rule == "不限号" ? .green : .white)
                    Text(updateText)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Image(systemName: "car.2")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.8))
                    if let err = entry.errorMessage {
                        Text("获取失败")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                        Text(err)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("请打开 App")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("获取限行数据")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    private var updateText: String {
        guard let d = entry.data else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return "更新于 \(f.string(from: d.lastUpdated))"
    }
}

// MARK: - Medium

struct MediumTrafficView: View {
    var entry: TrafficEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.56, blue: 0.98), Color(red: 0.06, green: 0.32, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HStack(spacing: 12) {
                if let d = entry.data {
                    VStack(spacing: 2) {
                        Text("今日")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(d.today.rule)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(d.today.rule == "不限号" ? .green : .white)
                        Text(d.today.dateText)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("本周限行")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 3) {
                            ForEach(d.thisWeek.items.indices, id: \.self) { i in
                                let item = d.thisWeek.items[i]
                                VStack(spacing: 1) {
                                    Text(item.weekday.replacingOccurrences(of: "周", with: ""))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text(item.rule)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(item.rule == "不限号" ? .green : .white)
                                }
                            }
                        }
                        Text(updateText)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 2)
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "car.2")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("请打开 App 获取限行数据")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
        }
    }

    private var updateText: String {
        guard let d = entry.data else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "更新于 \(f.string(from: d.lastUpdated))"
    }
}

// MARK: - Large

struct LargeTrafficView: View {
    var entry: TrafficEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.56, blue: 0.98), Color(red: 0.06, green: 0.32, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                if let d = entry.data {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("今日限行")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(d.today.rule)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(d.today.rule == "不限号" ? .green : .white)
                            Text(d.today.dateText)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        VStack(spacing: 2) {
                            Text("明日限行")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(d.tomorrow.rule)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(d.tomorrow.rule == "不限号" ? .green : .white)
                            Text(d.tomorrow.dateText)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(d.thisWeek.rangeText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(d.thisWeek.items.indices, id: \.self) { i in
                                let item = d.thisWeek.items[i]
                                VStack(spacing: 2) {
                                    Text(item.weekday)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Text(item.rule)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(item.rule == "不限号" ? .green : .white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    HStack {
                        Text(updateText)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(d.city + " · " + d.scope)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "car.2")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("请打开 App 获取限行数据")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("打开主 App 完成验证码后，数据将自动同步到小组件")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding(14)
        }
    }

    private var updateText: String {
        guard let d = entry.data else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return "更新于 \(f.string(from: d.lastUpdated))"
    }
}

// MARK: - Widget Definition

struct TrafficWidget: Widget {
    let kind: String = "TrafficWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrafficProvider()) { entry in
            TrafficWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("限行查询小组件")
        .description("显示北京今日限行尾号，30分钟刷新一次。遇到验证码需打开App处理。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
