import Foundation
import SwiftUI

/// 计时进行中的全屏沉浸页面：超大数字倒计时 + 细进度条 + 白噪音快捷开关。
/// 由 RootTabView 在存在活动会话时以 fullScreenCover 呈现，会话结束自动关闭。
struct FocusSessionView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var timer: TimerEngine
    @EnvironmentObject private var whiteNoise: WhiteNoiseService

    @State private var isAbandonPresented = false
    @State private var isFinishPresented = false

    private var sessionKind: FocusSessionKind {
        timer.session?.kind ?? .focus
    }

    private var kindTint: Color {
        switch sessionKind {
        case .focus: return FocusFlowTheme.accent
        case .shortBreak: return FocusFlowTheme.mint
        case .longBreak: return FocusFlowTheme.violet
        }
    }

    private var kindTitle: String {
        switch sessionKind {
        case .focus: return "专注中"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    private var taskTitle: String? {
        guard let id = timer.session?.taskID else { return nil }
        return container.store.tasks.first { $0.id == id }?.title
    }

    private var isCountdown: Bool {
        timer.session?.mode == .countdown
    }

    private var displaySeconds: Int {
        if isCountdown {
            return max(Int((timer.remaining ?? 0).rounded()), 0)
        }
        return max(Int(timer.elapsed.rounded()), 0)
    }

    private var timeText: String {
        let hours = displaySeconds / 3600
        let minutes = (displaySeconds % 3600) / 60
        let seconds = displaySeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var progress: Double {
        guard let session = timer.session, session.mode == .countdown,
              let planned = session.plannedDuration, planned > 0 else { return 0 }
        return min(max(timer.elapsed / planned, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 30)
            Spacer()
            timeDisplay
            if isCountdown {
                progressBar
                    .padding(.top, 30)
                    .padding(.horizontal, 12)
            }
            Spacer()
            noiseRow
                .padding(.bottom, 28)
            controls
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FocusFlowTheme.elevatedBackground.ignoresSafeArea())
        .confirmationDialog(
            "放弃本次计时？",
            isPresented: $isAbandonPresented,
            titleVisibility: .visible
        ) {
            Button("放弃并记录", role: .destructive) { container.abandonTimer() }
            Button("继续", role: .cancel) {}
        } message: {
            Text("已投入的有效时间会保留在历史中，并标记为放弃。")
        }
        .confirmationDialog(
            "提前结束本次计时？",
            isPresented: $isFinishPresented,
            titleVisibility: .visible
        ) {
            Button("完成并记录") { container.finishTimer(early: true) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("已投入的时间会保存到专注历史。")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(kindTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(kindTint)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(kindTint.opacity(0.12)))
            if let taskTitle {
                Text(taskTitle)
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.primaryText)
                    .lineLimit(1)
            }
        }
    }

    private var timeDisplay: some View {
        VStack(spacing: 14) {
            Text(timeText)
                .font(.system(size: 82, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(FocusFlowTheme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            statusLabel
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if timer.phase == .paused {
            Label("已暂停", systemImage: "pause.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kindTint)
        } else if timer.phase == .expired {
            Text("时间到")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(kindTint)
        } else {
            Text(isCountdown ? "剩余时间" : "正向计时")
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
                Capsule()
                    .fill(kindTint)
                    .frame(width: max(proxy.size.width * progress, 6))
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.35), value: progress)
        .accessibilityHidden(true)
    }

    private var noiseRow: some View {
        HStack(spacing: 8) {
            ForEach(WhiteNoiseKind.allCases) { kind in
                noiseChip(kind)
            }
        }
    }

    private func noiseChip(_ kind: WhiteNoiseKind) -> some View {
        let isActive = whiteNoise.selectedKind == kind && whiteNoise.isPlaying
        return Button {
            whiteNoise.toggle(kind)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: kind.systemImage)
                    .font(.subheadline)
                Text(kind.title)
                    .font(.caption2)
            }
            .foregroundStyle(isActive ? kindTint : FocusFlowTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: FocusFlowTheme.compactCornerRadius, style: .continuous)
                    .fill(isActive ? kindTint.opacity(0.10) : Color(uiColor: .tertiarySystemFill).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title)白噪音")
        .accessibilityValue(isActive ? "正在播放" : "未播放")
    }

    @ViewBuilder
    private var controls: some View {
        if timer.phase == .expired {
            Button("完成") { container.finishTimer() }
                .buttonStyle(PrimaryActionButtonStyle(color: kindTint))
        } else {
            HStack {
                sideButton(title: "放弃") { isAbandonPresented = true }
                Spacer()
                pauseResumeButton
                Spacer()
                sideButton(title: "提前完成") { isFinishPresented = true }
            }
            .padding(.horizontal, 6)
        }
    }

    private var pauseResumeButton: some View {
        Button(action: togglePause) {
            Image(systemName: timer.phase == .paused ? "play.fill" : "pause.fill")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(Circle().fill(kindTint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timer.phase == .paused ? "继续计时" : "暂停计时")
    }

    private func sideButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(FocusFlowTheme.secondaryText)
            .frame(minWidth: 70)
    }

    private func togglePause() {
        if timer.phase == .paused {
            container.resumeTimer()
        } else {
            container.pauseTimer()
        }
    }
}
