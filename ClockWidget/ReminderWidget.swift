import WidgetKit
import SwiftUI

struct ReminderEntry: TimelineEntry {
    let date: Date
    let reminders: [Reminder]
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: Date(), reminders: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> Void) {
        completion(ReminderEntry(date: Date(), reminders: ReminderCache.displayReminders()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> Void) {
        let reminders = ReminderCache.displayReminders()
        let entry = ReminderEntry(date: Date(), reminders: reminders)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ReminderWidget: Widget {
    let kind: String = "ReminderWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            ReminderWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("提醒")
        .description("显示当日提醒事件")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ReminderWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ReminderEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallReminderView(entry: entry)
        case .systemMedium:
            MediumReminderView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeReminderView(entry: entry)
        default:
            SmallReminderView(entry: entry)
        }
    }
}

struct SmallReminderView: View {
    let entry: ReminderEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text("今日提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.reminders.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let first = entry.reminders.first {
                Text(first.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(first.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
                Text("今日无提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
    }
}

struct MediumReminderView: View {
    let entry: ReminderEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text("今日提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.reminders.count)条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if entry.reminders.isEmpty {
                Text("今日无提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.reminders.prefix(4)) { r in
                    HStack {
                        Text(r.timeString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(r.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(r.statusText)
                            .font(.system(size: 9))
                            .foregroundStyle(statusColor(r.statusText))
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "已完成": return .green
        case "提醒中": return .red
        default: return .secondary
        }
    }
}

struct LargeReminderView: View {
    let entry: ReminderEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.orange)
                Text("今日提醒")
                    .font(.headline)
                Spacer()
                Text("\(entry.reminders.count)条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if entry.reminders.isEmpty {
                Text("今日无提醒")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.reminders) { r in
                    HStack {
                        Text(r.timeString)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(r.title)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Text(r.statusText)
                            .font(.caption)
                            .foregroundStyle(statusColor(r.statusText))
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer()
        }
        .padding()
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "已完成": return .green
        case "提醒中": return .red
        default: return .secondary
        }
    }
}
