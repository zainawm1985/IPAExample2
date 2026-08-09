import SwiftUI
import WidgetKit

struct BillView: View {
    @StateObject private var store = BillStore()

    var body: some View {
        NavigationView {
            List {
                // 顶部汇总卡片
                Section {
                    VStack(spacing: 12) {
                        // 预算设置行
                        HStack {
                            Text("预定预算")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                store.showBudgetSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("¥\(store.bill.budget, specifier: "%.0f")")
                                        .font(.headline)
                                    Image(systemName: "square.and.pencil")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // 进度条
                        ProgressView(value: store.bill.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: store.bill.remaining >= 0 ? .green : .red))

                        // 金额统计
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("已消费")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("¥\(store.bill.totalSpent, specifier: "%.2f")")
                                    .font(.callout)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("剩余")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("¥\(store.bill.remaining, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundStyle(store.bill.remaining >= 0 ? .green : .red)
                            }
                        }

                        // 消费百分比
                        HStack {
                            Text("使用进度")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(store.bill.progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 记录列表
                let grouped = store.bill.recordsByDate
                if grouped.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("暂无记录")
                                    .foregroundStyle(.secondary)
                                Text("点击右上角 + 添加第一条消费记录")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 20)
                    }
                } else {
                    ForEach(grouped, id: \.date) { group in
                        Section(header: Text(group.date)) {
                            ForEach(group.items) { record in
                                BillRecordRow(record: record, remain: store.bill.remaining(after: record)) {
                                    store.delete(record.id)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("记账")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("共\(store.bill.records.count)条")
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
                AddBillSheet { record in
                    store.add(record)
                }
            }
            .sheet(isPresented: $store.showBudgetSheet) {
                SetBudgetSheet(current: store.bill.budget) { budget in
                    store.setBudget(budget)
                }
            }
            .onAppear {
                store.refresh()
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 添加记录 Sheet

struct AddBillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var date: Date = Date()
    let onSave: (BillRecord) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("消费内容") {
                    TextField("如：午餐、打车、购物", text: $title)
                }
                Section("消费金额") {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                }
                Section("消费时间") {
                    DatePicker("时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("新增消费")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
                        if amt > 0 && !title.trimmingCharacters(in: .whitespaces).isEmpty {
                            let r = BillRecord(
                                title: title.trimmingCharacters(in: .whitespaces),
                                amount: amt,
                                date: date
                            )
                            onSave(r)
                            dismiss()
                        }
                    }
                    .disabled(Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 <= 0 || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 设置预算 Sheet

struct SetBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var budgetText: String
    let current: Double
    let onSave: (Double) -> Void

    init(current: Double, onSave: @escaping (Double) -> Void) {
        self.current = current
        self.onSave = onSave
        if current > 0 {
            _budgetText = State(initialValue: String(format: "%.0f", current))
        } else {
            _budgetText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("设置预定预算") {
                    TextField("如：5000", text: $budgetText)
                        .keyboardType(.numberPad)
                    Text("输入本期总预算，将自动显示消费与剩余")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("快捷设置") {
                    HStack(spacing: 8) {
                        ForEach([500, 1000, 2000, 5000], id: \.self) { val in
                            Button {
                                budgetText = "\(val)"
                            } label: {
                                Text("¥\(val)")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("设置预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let val = Double(budgetText) ?? 0
                        onSave(val)
                        dismiss()
                    }
                    .disabled((Double(budgetText) ?? 0) <= 0)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Store

final class BillStore: ObservableObject {
    @Published var bill: BillData = BillData()
    @Published var showAddSheet: Bool = false
    @Published var showBudgetSheet: Bool = false

    func refresh() {
        bill = BillCache.load()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setBudget(_ budget: Double) {
        BillCache.setBudget(budget)
        refresh()
    }

    func add(_ record: BillRecord) {
        BillCache.addRecord(record)
        refresh()
    }

    func delete(_ id: UUID) {
        BillCache.deleteRecord(id)
        refresh()
    }
}

// MARK: - 记录行视图（独立视图避免类型检查器超时）

struct BillRecordRow: View {
    let record: BillRecord
    let remain: Double
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.body)
                Text(record.timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("-¥\(record.amountString)")
                    .font(.callout)
                    .foregroundStyle(.red)
                Text("剩余 ¥\(remain, specifier: "%.2f")")
                    .font(.system(size: 10))
                    .foregroundStyle(remain >= 0 ? Color.secondary : Color.red)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
