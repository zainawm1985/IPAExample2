import SwiftUI
import WebKit
import WidgetKit

// MARK: - 主视图

struct TrafficLimitView: View {
    @StateObject private var store = TrafficLimitStore()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let data = store.data {
                        headerView(data: data)

                        HStack(spacing: 12) {
                            dayCard(title: "今日限行", date: data.today.dateText, rule: data.today.rule, isToday: true)
                            dayCard(title: "明日限行", date: data.tomorrow.dateText, rule: data.tomorrow.rule, isToday: false)
                        }

                        if !data.thisWeek.items.isEmpty {
                            weekTable(title: data.thisWeek.rangeText, items: data.thisWeek.items, highlightToday: true, todayRule: data.today.rule)
                        }
                        if !data.nextWeek.items.isEmpty {
                            weekTable(title: data.nextWeek.rangeText, items: data.nextWeek.items, highlightToday: false, todayRule: nil)
                        }

                        Button(action: { store.refresh() }) {
                            Label("刷新限行数据", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(store.isLoading)
                        .padding(.top, 8)

                        // 诊断信息
                        DisclosureGroup("诊断信息") {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Group 可用：\(TrafficLimitCache.appGroupAvailable ? "是" : "否")")
                                Text("容器路径：\(TrafficLimitCache.containerPath)")
                                Text("缓存数据：\(TrafficLimitCache.load() != nil ? "存在" : "不存在")")
                                if let d = TrafficLimitCache.load() {
                                    Text("今日规则：\(d.today.rule)")
                                    Text("本周项数：\(d.thisWeek.items.count)")
                                    Text("下周项数：\(d.nextWeek.items.count)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.footnote)

                        Text("数据来源：北京本地宝\n限行时间：7时至20时（工作日）\n限行范围：五环路以内道路（不含五环路）")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } else if store.isLoading {
                        ProgressView("正在获取限行数据…")
                            .padding(.top, 60)
                    } else {
                        emptyView
                    }
                }
                .padding(16)
            }
            .navigationTitle("限行查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.openCaptchaManually()
                    } label: {
                        Image(systemName: "checkmark.shield")
                    }
                }
            }
            .sheet(isPresented: $store.showCaptchaWebView) {
                CaptchaSheet(url: store.sourceURL) { parsed in
                    store.handleParsedResult(parsed)
                }
            }
            .alert("提示", isPresented: $store.showAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(store.alertMessage)
            }
            .onAppear {
                store.refreshIfNeeded()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 子视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.2")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("暂无限行数据")
                .font(.headline)
            Text("点击下方按钮获取最新限行规则")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: { store.refresh() }) {
                Label("获取限行数据", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }

    private func headerView(data: TrafficLimitData) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(data.city)
                    .font(.title3.bold())
                Spacer()
                Text(data.scope)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                Text("最后更新：\(store.formattedUpdate)")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func dayCard(title: String, date: String, rule: String, isToday: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(date)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(rule)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rule == "不限号" ? .green : (isToday ? .red : .primary))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func weekTable(title: String, items: [TrafficLimitData.WeekItem], highlightToday: Bool, todayRule: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    let isTodayItem = highlightToday && item.rule == todayRule
                    VStack(spacing: 2) {
                        Text(item.weekday)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.rule)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(item.rule == "不限号" ? .green : (isTodayItem ? .red : .primary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isTodayItem ? Color.red.opacity(0.12) : Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Store

@MainActor
final class TrafficLimitStore: ObservableObject {
    @Published var data: TrafficLimitData?
    @Published var isLoading: Bool = false
    @Published var showCaptchaWebView: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    let sourceURL = URL(string: "https://m.bj.bendibao.com/news/xianxingchaxun/")!

    /// 数据超过此时间视为过期，触发刷新
    private let cacheStaleThreshold: TimeInterval = 30 * 60  // 30分钟

    /// 判断缓存数据是否跨天（第二天需要重新获取）
    private func isCacheFromToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }

    var formattedUpdate: String {
        guard let d = data?.lastUpdated ?? TrafficLimitCache.lastUpdated() else { return "未更新" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }

    func refreshIfNeeded() {
        if let cached = TrafficLimitCache.load() {
            self.data = cached
            // 规则1：跨天立即刷新（第二天凌晨第一次打开App时获取新一天的数据）
            // 规则2：同一天内超过30分钟刷新
            if !isCacheFromToday(cached.lastUpdated) {
                refresh()
            } else if Date().timeIntervalSince(cached.lastUpdated) > cacheStaleThreshold {
                refresh()
            }
        } else {
            refresh()
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let result = await TrafficFetcher.shared.fetch()
            isLoading = false
            switch result {
            case .success(let d):
                self.data = d
                TrafficLimitCache.save(d)
                // 通知Widget刷新
                WidgetCenter.shared.reloadAllTimelines()
            case .captcha:
                // 直接弹WebView让用户过码，不弹alert（alert会阻塞sheet）
                self.showCaptchaWebView = true
            case .failure(let msg):
                if TrafficLimitCache.load() != nil {
                    self.data = TrafficLimitCache.load()
                    self.alertMessage = "网络获取失败，已显示缓存数据：\(msg)"
                } else {
                    self.alertMessage = "获取失败：\(msg)"
                }
                self.showAlert = true
            }
        }
    }

    /// 用户主动打开WebView过码
    func openCaptchaManually() {
        showCaptchaWebView = true
    }

    /// WebView 解析结果回调
    func handleParsedResult(_ parsed: TrafficLimitData?) {
        guard let parsed = parsed, !parsed.today.rule.isEmpty else {
            alertMessage = "解析失败，请确认网页已加载完成，再点关闭后重试。"
            showAlert = true
            return
        }
        self.data = parsed
        TrafficLimitCache.save(parsed)
        // 通知Widget刷新
        WidgetCenter.shared.reloadAllTimelines()
        alertMessage = "已更新限行数据。"
        showAlert = true
        showCaptchaWebView = false
    }
}

// MARK: - 验证码 WebView（Sheet）

struct CaptchaSheet: View {
    let url: URL
    let onParsed: (TrafficLimitData?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("在下方网页完成验证后，数据会自动更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("关闭") { dismiss() }
                    .font(.subheadline.bold())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            CaptchaWebView(url: url, onParsed: onParsed)
        }
    }
}

struct CaptchaWebView: UIViewRepresentable {
    let url: URL
    let onParsed: (TrafficLimitData?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onParsed: onParsed) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onParsed: (TrafficLimitData?) -> Void
        init(onParsed: @escaping (TrafficLimitData?) -> Void) { self.onParsed = onParsed }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 先用JS检测是否是验证码页
            webView.evaluateJavaScript("document.body.innerText.indexOf('请完成拼图验证') >= 0 || document.body.innerText.indexOf('拖动拼图块') >= 0") { result, _ in
                let isCaptcha = (result as? Bool) ?? false
                if isCaptcha { return }  // 等用户过码
                // 用 JS DOM API 直接提取结构化数据（比正则解析HTML可靠）
                self.extractData(webView: webView)
            }
        }

        private func extractData(webView: WKWebView) {
            let js = """
            (function() {
                function txt(el) { return el ? el.textContent.trim() : ''; }
                function blockText(blockClass, innerClass) {
                    const block = document.querySelector('.' + blockClass);
                    if (!block) return '';
                    return txt(block.querySelector('.' + innerClass));
                }
                function weekTable(containerClass) {
                    const c = document.querySelector('.' + containerClass);
                    if (!c) return { rangeText: '', items: [] };
                    const rangeText = txt(c.querySelector('.date-from'));
                    const items = [];
                    c.querySelectorAll('.item').forEach(function(item) {
                        items.push({
                            weekday: txt(item.querySelector('.date')),
                            rule: txt(item.querySelector('.num'))
                        });
                    });
                    return { rangeText: rangeText, items: items };
                }
                const cityNameEl = document.querySelector('.city-name');
                const city = cityNameEl ? txt(cityNameEl) : '北京';
                const scope = document.querySelector('.other.chouse') ? '外地车' : '本地车';
                const thisWeek = weekTable('this-week');
                const nextWeek = weekTable('next-week');
                return JSON.stringify({
                    city: city,
                    scope: scope,
                    today: {
                        dateText: blockText('today', 'date'),
                        rule: blockText('today', 'rule')
                    },
                    tomorrow: {
                        dateText: blockText('tomorrow', 'date'),
                        rule: blockText('tomorrow', 'rule')
                    },
                    thisWeek: thisWeek,
                    nextWeek: nextWeek,
                    lastUpdated: new Date().toISOString()
                });
            })()
            """
            webView.evaluateJavaScript(js) { result, _ in
                guard let jsonString = result as? String,
                      let jsonData = jsonString.data(using: .utf8) else {
                    self.onParsed(nil)
                    return
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let data = try? decoder.decode(TrafficLimitData.self, from: jsonData) {
                    self.onParsed(data)
                } else {
                    self.onParsed(nil)
                }
            }
        }
    }
}
