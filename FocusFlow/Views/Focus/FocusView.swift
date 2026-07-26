import Foundation
import SwiftUI

/// 专注准备页：选择模式、时长、任务与白噪音。计时开始后由全屏 FocusSessionView 接管。
struct FocusView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = FocusViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    presetPicker
                    timeCard
                    if viewModel.selectedPreset == .focus {
                        taskCard
                    }
                    startButton
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
        }
    }

    // MARK: - Sections

    private var presetPicker: some View {
        HStack(spacing: 8) {
            ForEach(FocusViewModel.SessionPreset.allCases) { preset in
                presetPill(preset)
            }
        }
    }

    private func presetPill(_ preset: FocusViewModel.SessionPreset) -> some View {
        let isSelected = viewModel.selectedPreset == preset
        return Button {
            viewModel.choosePreset(preset)
        } label: {
            Label(preset.rawValue, systemImage: preset.systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? Color.white : FocusFlowTheme.secondaryText)
                .background(
                    Capsule()
                        .fill(isSelected ? accent(for: preset) : FocusFlowTheme.cardBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var timeCard: some View {
        VStack(spacing: 18) {
            Text(timeCardText)
                .font(.system(size: 64, weight: .thin, design: .rounded).monospacedDigit())
                .foregroundStyle(FocusFlowTheme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 10)

            if !viewModel.usesCountUp {
                durationAdjustRow
            }

            if viewModel.selectedPreset == .focus {
                countUpToggle
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
    }

    private var durationAdjustRow: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.adjustDuration(by: -5)
            } label: {
                Label("减少 5 分钟", systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietActionButtonStyle())
            .accessibilityLabel("减少五分钟")

            Text("每次 \(Int(viewModel.selectedDuration / 60)) 分钟")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FocusFlowTheme.secondaryText)
                .frame(minWidth: 100)

            Button {
                viewModel.adjustDuration(by: 5)
            } label: {
                Label("增加 5 分钟", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietActionButtonStyle())
            .accessibilityLabel("增加五分钟")
        }
    }

    private var countUpToggle: some View {
        Toggle(isOn: $viewModel.usesCountUp) {
            VStack(alignment: .leading, spacing: 2) {
                Text("正向计时")
                    .font(.subheadline.weight(.semibold))
                Text("不设截止时间，结束时记录投入时长")
                    .font(.caption)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }
        }
        .tint(FocusFlowTheme.accent)
    }

    private var taskCard: some View {
        Button {
            viewModel.isTaskPickerPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedTask == nil ? "checklist" : "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(FocusFlowTheme.accent)
                    .frame(width: 36, height: 36)
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

    private var startButton: some View {
        Button {
            viewModel.performPrimaryAction()
        } label: {
            Label(startTitle, systemImage: "play.fill")
        }
        .buttonStyle(PrimaryActionButtonStyle(color: accent(for: viewModel.selectedPreset)))
        .padding(.top, 2)
        .accessibilityHint("开始本次计时")
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
                    noiseTile(kind)
                }
            }

            if viewModel.whiteNoise.selectedKind != nil {
                volumeRow
            }
        }
        .surfaceCard(padding: 14)
    }

    private func noiseTile(_ kind: WhiteNoiseKind) -> some View {
        let isSelected = viewModel.whiteNoise.selectedKind == kind
        return Button {
            viewModel.toggleNoise(kind)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(isSelected ? FocusFlowTheme.accent : FocusFlowTheme.secondaryText)
                    .frame(width: 24)
                Text(kind.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusFlowTheme.primaryText)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: viewModel.whiteNoise.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(FocusFlowTheme.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: FocusFlowTheme.compactCornerRadius, style: .continuous)
                    .fill(isSelected ? FocusFlowTheme.accent.opacity(0.10) : Color(uiColor: .tertiarySystemFill).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title)白噪音")
        .accessibilityValue(isSelected && viewModel.whiteNoise.isPlaying ? "正在播放" : "未播放")
    }

    private var volumeRow: some View {
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

    // MARK: - Helpers

    private var startTitle: String {
        viewModel.selectedPreset == .focus ? "开始专注" : "开始休息"
    }

    private var timeCardText: String {
        if viewModel.usesCountUp {
            return "00:00"
        }
        let totalSeconds = max(Int(viewModel.selectedDuration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func accent(for preset: FocusViewModel.SessionPreset) -> Color {
        switch preset.kind {
        case .focus: return FocusFlowTheme.accent
        case .shortBreak: return FocusFlowTheme.mint
        case .longBreak: return FocusFlowTheme.violet
        }
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
                noTaskButton

                Section("待完成任务") {
                    if tasks.isEmpty {
                        Text("没有可关联的待办任务")
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }
                    ForEach(tasks) { task in
                        taskButton(task)
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

    private var noTaskButton: some View {
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
    }

    private func taskButton(_ task: TaskItem) -> some View {
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
