import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ClockEntry: TimelineEntry {
    let date: Date
    let timezone: TimeZone
}

// MARK: - Provider

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), timezone: .current)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let entry = ClockEntry(date: Date(), timezone: .current)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        var entries: [ClockEntry] = []
        let currentDate = Date()

        // 生成未来 10 分钟的 timeline，每 1 分钟一个 entry
        for minuteOffset in 0..<10 {
            if let entryDate = Calendar.current.date(
                byAdding: .minute, value: minuteOffset, to: currentDate
            ) {
                // 对齐到整分钟（秒数归零）
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: entryDate
                )
                if let alignedDate = Calendar.current.date(from: components) {
                    entries.append(ClockEntry(date: alignedDate, timezone: .current))
                }
            }
        }

        // 下一次刷新：10 分钟后，或在第一个 entry 的下一分钟刷新
        let nextRefreshDate = Calendar.current.date(
            byAdding: .minute, value: 10, to: currentDate
        ) ?? currentDate.addingTimeInterval(600)

        let timeline = Timeline(entries: entries, policy: .after(nextRefreshDate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct ClockWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ClockEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallClockView(entry: entry)
        case .systemMedium:
            MediumClockView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeClockView(entry: entry)
        default:
            SmallClockView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallClockView: View {
    var entry: ClockEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                AnalogClock(date: entry.date, size: 70)
                Text(entry.date, style: .time)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Medium

struct MediumClockView: View {
    var entry: ClockEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HStack(spacing: 20) {
                AnalogClock(date: entry.date, size: 90)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(entry.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(weekdayText(entry.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
    }

    private func weekdayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Large

struct LargeClockView: View {
    var entry: ClockEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 20) {
                AnalogClock(date: entry.date, size: 130)

                VStack(spacing: 4) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(entry.date, style: .date)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(weekdayText(entry.date))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private func weekdayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Analog Clock Drawing

struct AnalogClock: View {
    let date: Date
    let size: CGFloat

    var body: some View {
        ZStack {
            // 表盘背景
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            // 刻度
            ForEach(0..<60) { tick in
                tickMark(at: tick, size: size)
            }

            // 数字
            ForEach(1...12, id: \.self) { number in
                numberLabel(number, size: size)
            }

            // 时针
            hourHand(date: date, size: size)

            // 分针
            minuteHand(date: date, size: size)

            // 秒针
            secondHand(date: date, size: size)

            // 中心点
            Circle()
                .fill(Color.red)
                .frame(width: size * 0.06, height: size * 0.06)
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.025, height: size * 0.025)
        }
        .frame(width: size, height: size)
    }

    private func tickMark(at tick: Int, size: CGFloat) -> some View {
        let isHour = tick % 5 == 0
        let length: CGFloat = isHour ? size * 0.07 : size * 0.035
        let width: CGFloat = isHour ? size * 0.02 : size * 0.008
        let color: Color = isHour ? .black : .gray.opacity(0.6)
        let angle = Double(tick) * 6.0 - 90.0
        let offset = (size / 2 - length / 2 - size * 0.04)

        return Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .cornerRadius(width / 2)
            .offset(x: offset * cos(angle * .pi / 180),
                    y: offset * sin(angle * .pi / 180))
            .rotationEffect(.degrees(angle + 90))
    }

    private func numberLabel(_ number: Int, size: CGFloat) -> some View {
        let angle = Double(number) * 30.0 - 90.0
        let offset = size * 0.36
        return Text("\(number)")
            .font(.system(size: size * 0.12, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .offset(x: offset * cos(angle * .pi / 180),
                    y: offset * sin(angle * .pi / 180))
    }

    private func hourHand(date: Date, size: CGFloat) -> some View {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(components.minute ?? 0)
        let angle = (hour + minute / 60) * 30.0 - 90.0
        let length = size * 0.28

        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.black)
            .frame(width: size * 0.05, height: length)
            .offset(y: -length / 2 + size * 0.02)
            .rotationEffect(.degrees(angle))
    }

    private func minuteHand(date: Date, size: CGFloat) -> some View {
        let components = Calendar.current.dateComponents([.minute, .second], from: date)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let angle = (minute + second / 60) * 6.0 - 90.0
        let length = size * 0.38

        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.black.opacity(0.85))
            .frame(width: size * 0.03, height: length)
            .offset(y: -length / 2 + size * 0.02)
            .rotationEffect(.degrees(angle))
    }

    private func secondHand(date: Date, size: CGFloat) -> some View {
        let components = Calendar.current.dateComponents([.second], from: date)
        let second = Double(components.second ?? 0)
        let angle = second * 6.0 - 90.0
        let length = size * 0.42

        return Rectangle()
            .fill(Color.red)
            .frame(width: 1.2, height: length)
            .offset(y: -length / 2 + size * 0.05)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Widget Definition

struct ClockWidget: Widget {
    let kind: String = "ClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            ClockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("时钟小组件")
        .description("显示当前时间，包含模拟表盘与数字时钟。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
