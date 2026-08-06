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

            TrafficLimitView()
                .tabItem {
                    Label("限行", systemImage: "car.2")
                }
                .tag(1)

            InfoView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
