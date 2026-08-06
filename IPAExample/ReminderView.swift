import SwiftUI
import WidgetKit

struct ReminderView: View {
    @StateObject private var store = ReminderStore()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if store.todayReminders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("今日无提醒")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.todayReminders) { reminder in
                            ReminderRow(reminder: reminder) {
                                store.confirm(reminder.id)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(reminder.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("提醒")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(store.headerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $store.showAddSheet) {
                AddReminderSheet { newReminder in
                    store.add(newReminder)
                }
            }
            .onAppear {
                store.refresh()
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                Text(reminder.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(reminder.statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                if !reminder.confirmed {
                    Button("确认") {
                        onConfirm()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch reminder.statusText {
        case "已完成": return .green
        case "提醒中": return .red
        default: return .secondary
        }
    }
}

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var reminderDate: Date = Date().addingTimeInterval(3600) // 默认1小时后
    @State private var enabled: Bool = true
    let onSave: (Reminder) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("事件") {
                    TextField("标题", text: $title)
                }
                Section("提醒时间") {
                    DatePicker("时间", selection: $reminderDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                Section {
                    Toggle("启用提醒", isOn: $enabled)
                }
            }
            .navigationTitle("新建提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let r = Reminder(title: title.isEmpty ? "提醒" : title, reminderDate: reminderDate, enabled: enabled)
                        onSave(r)
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

final class ReminderStore: ObservableObject {
    @Published var todayReminders: [Reminder] = []
    @Published var showAddSheet: Bool = false

    var headerText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM月dd日 EEEE"
        return "\(f.string(from: Date())) · 共\(todayReminders.count)条"
    }

    func refresh() {
        todayReminders = ReminderCache.todayReminders()
    }

    func add(_ reminder: Reminder) {
        var all = ReminderCache.loadAll()
        all.append(reminder)
        ReminderCache.saveAll(all)
        NotificationManager.shared.scheduleReminder(reminder)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func delete(_ id: UUID) {
        var all = ReminderCache.loadAll()
        all.removeAll { $0.id == id }
        ReminderCache.saveAll(all)
        NotificationManager.shared.cancelReminder(id)
        refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func confirm(_ id: UUID) {
        var all = ReminderCache.loadAll()
        if let idx = all.firstIndex(where: { $0.id == id }) {
            all[idx].confirmed = true
            ReminderCache.saveAll(all)
            NotificationManager.shared.confirmReminder(id)
            refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
