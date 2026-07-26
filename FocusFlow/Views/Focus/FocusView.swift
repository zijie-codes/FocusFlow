import Foundation
import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = FocusViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    presetPicker
                    timerSection

                    if viewModel.phase == .idle {
                        preparationSection
                    } else {
                        activeSessionSection
                    }

                    whiteNoiseSection
                }
                .padding(.horizontal, FocusFlowTheme.horizontalPadding)
                .padding(.vertical, 14)
            }
            .background(FocusFlowTheme.pageBackground)
            .navigationTitle("专注")
            .navigationBarTitleDisplayMode(.large)
            .tint(FocusFlowTheme.accent)
            .onAppear {
                viewModel.bind(container: container)
            }
            .sheet(isPresented: $viewModel.isTaskPickerPresented) {
                FocusTaskPickerView(
                    tasks: viewModel.tasks,
                    selectedTaskID: viewModel.selectedTaskID,
                    onSelect: viewModel.selectTask
                )
            }
            .alert("无法执行操作", isPresented: errorBinding) {
                Button("知道了", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "提前结束本次专注？",
                isPresented: $viewModel.isFinishConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("完成并记录") { viewModel.finish() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("已投入的时间会保存到专注历史。")
            }
            .confirmationDialog(
                "放弃本次专注？",
                isPresented: $viewModel.isAbandonConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("放弃并记录", role: .destructive) { viewModel.abandon() }
                Button("继续专注", role: .cancel) {}
            } message: {
                Text("已投入的有效时间会保留在历史中，并标记为放弃。")
            }
        }
    }

    private var presetPicker: some View {
        HStack(spacing: 8) {
            ForEach(FocusViewModel.SessionPreset.allCases) { preset in
                Button {
                    viewModel.choosePreset(preset)
                } label: {
                    Label(preset.rawValue, systemImage: preset.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(viewModel.selectedPreset == preset ? Color.white : FocusFlowTheme.secondaryText)
                        .background(
                            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                                .fill(viewModel.selectedPreset == preset ? accent(for: preset) : FocusFlowTheme.cardBackground)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.phase != .idle)
                .accessibilityAddTraits(viewModel.selectedPreset == preset ? .isSelected : [])
            }
        }
    }

    private var timerSection: some View {
        VStack(spacing: 16) {
            FocusTimerDial(
                duration: viewModel.displayDuration,
                progress: viewModel.progress,
                isCountUp: viewModel.session?.mode == .countUp || (viewModel.phase == .idle && viewModel.usesCountUp),
                tint: accent(for: viewModel.activeKind),
                phase: viewModel.phase
            )
            .frame(width: 250, height: 250)
            .padding(.top, 4)

            VStack(spacing: 5) {
                Text(viewModel.activeKind.title)
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.primaryText)
                Text(viewModel.modeDescription)
                    .font(.subheadline)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let task = viewModel.activeTask ?? viewModel.selectedTask {
                    Text("\(task.title) · 计划 \(max(task.estimatedPomodoros, 1)) 个 · 已完成 \(task.completedPomodoros) 个")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("当前任务 \(task.title)，计划 \(max(task.estimatedPomodoros, 1)) 个番茄，已完成 \(task.completedPomodoros) 个")
                }
            }

            Button(action: viewModel.performPrimaryAction) {
                Label(viewModel.primaryActionTitle, systemImage: primaryIcon)
            }
            .buttonStyle(PrimaryActionButtonStyle(color: accent(for: viewModel.activeKind)))
            .accessibilityHint(primaryAccessibilityHint)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.elevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .stroke(FocusFlowTheme.separator.opacity(0.35), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var preparationSection: some View {
        VStack(spacing: 12) {
            if viewModel.selectedPreset == .focus {
                Button {
                    viewModel.isTaskPickerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.selectedTask == nil ? "checklist" : "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(FocusFlowTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(FocusFlowTheme.accent.opacity(0.11)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("本次任务")
                                .font(.caption)
                                .foregroundStyle(FocusFlowTheme.secondaryText)
                            Text(viewModel.selectedTask?.title ?? "暂不关联任务")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(FocusFlowTheme.primaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FocusFlowTheme.tertiaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .surfaceCard(padding: 14)
                .accessibilityLabel("本次任务，\(viewModel.selectedTask?.title ?? "暂不关联")")
                .accessibilityHint("双击选择要推进的任务")
            }

            if viewModel.selectedPreset == .focus {
                Toggle(isOn: $viewModel.usesCountUp) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("正向计时")
                            .font(.body.weight(.semibold))
                        Text("不设截止时间，结束时再记录投入时长")
                            .font(.caption)
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }
                }
                .tint(FocusFlowTheme.accent)
                .surfaceCard(padding: 14)
            }

            if !viewModel.usesCountUp {
                HStack(spacing: 12) {
                    Button {
                        viewModel.adjustDuration(by: -5)
                    } label: {
                        Label("减少 5 分钟", systemImage: "minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(QuietActionButtonStyle())
                    .accessibilityLabel("减少五分钟")

                    Text(timeText(viewModel.selectedDuration))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(minWidth: 82)
                        .accessibilityLabel("计时长度 \(timeText(viewModel.selectedDuration))")

                    Button {
                        viewModel.adjustDuration(by: 5)
                    } label: {
                        Label("增加 5 分钟", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(QuietActionButtonStyle())
                    .accessibilityLabel("增加五分钟")
                }
                .surfaceCard(padding: 12)
            }
        }
    }

    private var activeSessionSection: some View {
        HStack(spacing: 10) {
            if viewModel.phase == .running || viewModel.phase == .paused {
                Button("提前完成", action: viewModel.requestFinish)
                    .buttonStyle(QuietActionButtonStyle())
                    .frame(maxWidth: .infinity)
            }

            Button(role: .destructive) {
                viewModel.isAbandonConfirmationPresented = true
            } label: {
                Label("放弃", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietActionButtonStyle())
            .accessibilityHint("会停止当前计时并标记为放弃")
        }
    }

    private var whiteNoiseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "白噪音",
                subtitle: viewModel.whiteNoise.isPlaying ? "正在播放 \(viewModel.whiteNoise.selectedKind?.title ?? "")" : "选一种声景，降低环境干扰"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(WhiteNoiseKind.allCases) { kind in
                    Button {
                        viewModel.toggleNoise(kind)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: kind.systemImage)
                                .foregroundStyle(viewModel.whiteNoise.selectedKind == kind ? FocusFlowTheme.accent : FocusFlowTheme.secondaryText)
                                .frame(width: 24)
                            Text(kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FocusFlowTheme.primaryText)
                            Spacer(minLength: 0)
                            if viewModel.whiteNoise.selectedKind == kind {
                                Image(systemName: viewModel.whiteNoise.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(.caption)
                                    .foregroundStyle(FocusFlowTheme.accent)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                                .fill(viewModel.whiteNoise.selectedKind == kind ? FocusFlowTheme.accent.opacity(0.10) : FocusFlowTheme.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.title)白噪音")
                    .accessibilityValue(viewModel.whiteNoise.selectedKind == kind && viewModel.whiteNoise.isPlaying ? "正在播放" : "未播放")
                }
            }

            if viewModel.whiteNoise.selectedKind != nil {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.whiteNoise.volume) },
                            set: { viewModel.whiteNoise.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .tint(FocusFlowTheme.accent)
                    Text("\(Int(viewModel.whiteNoise.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            }
        }
        .surfaceCard(padding: 14)
    }

    private var primaryIcon: String {
        switch viewModel.phase {
        case .idle: return "play.fill"
        case .running: return "pause.fill"
        case .paused: return "play.fill"
        case .expired: return "checkmark"
        }
    }

    private var primaryAccessibilityHint: String {
        switch viewModel.phase {
        case .idle: return "开始本次计时"
        case .running: return "暂停后可以继续"
        case .paused: return "恢复当前计时"
        case .expired: return "保存本次专注记录"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func accent(for preset: FocusViewModel.SessionPreset) -> Color {
        accent(for: preset.kind)
    }

    private func accent(for kind: FocusSessionKind) -> Color {
        switch kind {
        case .focus: return FocusFlowTheme.accent
        case .shortBreak: return FocusFlowTheme.mint
        case .longBreak: return FocusFlowTheme.violet
        }
    }

    private func timeText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct FocusTimerDial: View {
    let duration: TimeInterval
    let progress: Double
    let isCountUp: Bool
    let tint: Color
    let phase: TimerEnginePhase

    private var timeText: String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 12)

            if isCountUp {
                Circle()
                    .trim(from: 0, to: phase == .running ? 0.84 : 0.58)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: [1, 8]))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: phase)
            } else {
                Circle()
                    .trim(from: 0, to: max(progress, phase == .idle ? 0.03 : 0))
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }

            VStack(spacing: 8) {
                Text(timeText)
                    .font(.system(size: 42, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text(isCountUp ? "正向计时" : "剩余时间")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(FocusFlowTheme.secondaryText)
                if phase == .paused {
                    Label("已暂停", systemImage: "pause.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }
        }
        .scaleEffect(phase == .running && duration > 0 && duration <= 3 ? 1.035 : 1)
        .animation(.easeInOut(duration: 0.2), value: Int(duration.rounded(.up)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCountUp ? "正向计时" : "剩余时间")
        .accessibilityValue(timeText)
    }
}

private struct FocusTaskPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [TaskItem]
    let selectedTaskID: UUID?
    let onSelect: (TaskItem?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Label("暂不关联任务", systemImage: "tray")
                        Spacer()
                        if selectedTaskID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(FocusFlowTheme.accent)
                        }
                    }
                }
                .foregroundStyle(FocusFlowTheme.primaryText)

                Section("待完成任务") {
                    if tasks.isEmpty {
                        Text("没有可关联的待办任务")
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }
                    ForEach(tasks) { task in
                        Button {
                            onSelect(task)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title)
                                        .foregroundStyle(FocusFlowTheme.primaryText)
                                    if let date = task.dueDate {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(FocusFlowTheme.secondaryText)
                                    }
                                }
                                Spacer()
                                if selectedTaskID == task.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FocusFlowTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

private extension FocusSessionKind {
    var title: String {
        switch self {
        case .focus: return "专注中"
        case .shortBreak: return "短休中"
        case .longBreak: return "长休中"
        }
    }
}
