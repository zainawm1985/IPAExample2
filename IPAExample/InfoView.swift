import SwiftUI

struct InfoView: View {
    private let appName: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? "IPAExample"

    private let version: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"

    private let build: String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"

    var body: some View {
        NavigationView {
            List {
                Section("应用") {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(appName).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("构建号")
                        Spacer()
                        Text(build).foregroundStyle(.secondary)
                    }
                }
                Section("说明") {
                    Text("这是一个用于演示 iOS 应用开发与 .ipa 打包流程的示例程序。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    InfoView()
}
