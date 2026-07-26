import SwiftUI

enum RootTab: Hashable {
    case today
    case lists
    case statistics
    case settings
}

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var timer: TimerEngine
    @State private var selection: RootTab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem {
                    Label("待办", systemImage: "line.3.horizontal")
                }
                .tag(RootTab.today)

            ListsView()
                .tabItem {
                    Label("待办集", systemImage: "line.3.horizontal.decrease")
                }
                .tag(RootTab.lists)

            StatisticsView()
                .tabItem {
                    Label("数据统计", systemImage: selection == .statistics ? "chart.pie.fill" : "chart.pie")
                }
                .tag(RootTab.statistics)

            SettingsView()
                .tabItem {
                    Label("我的", systemImage: selection == .settings ? "person.fill" : "person")
                }
                .tag(RootTab.settings)
        }
        .tint(FocusFlowTheme.accent)
        .fullScreenCover(isPresented: activeSessionBinding) {
            FocusSessionView()
                .environmentObject(container)
                .environmentObject(container.timer)
                .environmentObject(container.whiteNoise)
        }
    }

    /// 有活动计时会话时自动全屏；会话结束（完成/放弃）后自动关闭。
    private var activeSessionBinding: Binding<Bool> {
        Binding(
            get: { timer.hasActiveSession },
            set: { _ in }
        )
    }
}
