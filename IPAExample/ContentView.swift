import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ReminderView()
                .tabItem {
                    Label("提醒", systemImage: "bell")
                }
                .tag(0)

            BillView()
                .tabItem {
                    Label("记账", systemImage: "note.text")
                }
                .tag(1)

            TrafficLimitView()
                .tabItem {
                    Label("限行", systemImage: "car.2")
                }
                .tag(2)

            InfoView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
