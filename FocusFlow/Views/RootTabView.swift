import SwiftUI

enum RootTab: Hashable {
    case today
    case focus
    case statistics
    case settings
}

struct RootTabView: View {
    @State private var selection: RootTab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem {
                    Label("今天", systemImage: selection == .today ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .tag(RootTab.today)

            FocusView()
                .tabItem {
                    Label("专注", systemImage: selection == .focus ? "timer.circle.fill" : "timer")
                }
                .tag(RootTab.focus)

            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: selection == .statistics ? "chart.bar.fill" : "chart.bar")
                }
                .tag(RootTab.statistics)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: selection == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(RootTab.settings)
        }
        .tint(FocusFlowTheme.accent)
    }
}
