import SwiftUI

enum RootTab: Hashable {
    case today
    case focus
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
                    Label("待办", systemImage: selection == .today ? "checkmark.circle.fill" : "checkmark.circle")
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
