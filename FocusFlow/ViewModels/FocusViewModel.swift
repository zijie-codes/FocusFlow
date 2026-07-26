import Combine
import Foundation

@MainActor
final class FocusViewModel: ObservableObject {
    enum SessionPreset: String, CaseIterable, Identifiable {
        case focus = "专注"
        case shortBreak = "短休"
        case longBreak = "长休"

        var id: String { rawValue }
        var kind: FocusSessionKind {
            switch self {
            case .focus: return .focus
            case .shortBreak: return .shortBreak
            case .longBreak: return .longBreak
            }
        }
        var systemImage: String {
            switch self {
            case .focus: return "scope"
            case .shortBreak: return "cup.and.saucer.fill"
            case .longBreak: return "moon.stars.fill"
            }
        }
    }

    @Published var selectedPreset: SessionPreset = .focus
    @Published var selectedTaskID: UUID?
    @Published var selectedDuration: TimeInterval = 25 * 60
    @Published var usesCountUp = false
    @Published var isTaskPickerPresented = false
    @Published var isAbandonConfirmationPresented = false
    @Published var isFinishConfirmationPresented = false
    @Published var errorMessage: String?
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var settings: AppSettings = .default
    @Published private(set) var session: ActiveTimerSession?
    @Published private(set) var phase: TimerEnginePhase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var remaining: TimeInterval?
    @Published private(set) var completedFocusCount = 0

    private weak var container: AppContainer?
    private weak var engine: TimerEngine?
    private let fallbackNoise = WhiteNoiseService()
    private var cancellables = Set<AnyCancellable>()
    private var lastCountdownSecond = -1

    var whiteNoise: WhiteNoiseService { container?.whiteNoise ?? fallbackNoise }

    func bind(container: AppContainer) {
        guard self.container !== container else { return }
        self.container = container
        self.engine = container.timer
        cancellables.removeAll()

        container.store.$data
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let self else { return }
                tasks = data.tasks.filter { !$0.isCompleted }
                settings = data.settings
                completedFocusCount = data.records.filter {
                    $0.kind == .focus && $0.result == .completed
                }.count
                if phase == .idle {
                    selectedDuration = duration(for: selectedPreset, settings: data.settings)
                }
            }
            .store(in: &cancellables)

        container.timer.$session
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.session = $0 }
            .store(in: &cancellables)
        container.timer.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.phase = $0 }
            .store(in: &cancellables)
        container.timer.$elapsed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.elapsed = $0 }
            .store(in: &cancellables)
        container.timer.$remaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.remaining = value
                self?.handleFinalCountdown(value)
            }
            .store(in: &cancellables)
        container.whiteNoise.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var selectedTask: TaskItem? {
        selectedTaskID.flatMap { id in tasks.first { $0.id == id } }
    }

    var activeTask: TaskItem? {
        session?.taskID.flatMap { id in
            container?.store.tasks.first { $0.id == id }
        }
    }

    var activeKind: FocusSessionKind { session?.kind ?? selectedPreset.kind }

    var displayDuration: TimeInterval {
        session?.mode == .countdown ? (remaining ?? 0) : elapsed
    }

    var progress: Double {
        guard let session, session.mode == .countdown,
              let planned = session.plannedDuration, planned > 0 else { return 0 }
        return min(max(elapsed / planned, 0), 1)
    }

    var primaryActionTitle: String {
        switch phase {
        case .idle: return selectedPreset == .focus ? "开始专注" : "开始休息"
        case .running: return "暂停"
        case .paused: return "继续"
        case .expired: return "完成"
        }
    }

    var modeDescription: String {
        if let session {
            switch (session.kind, session.mode) {
            case (.focus, .countdown): return "保持注意力，完成这一段就休息"
            case (.focus, .countUp): return "正向计时中，按自己的节奏结束"
            case (.shortBreak, _): return "短暂休息，给大脑留一点空白"
            case (.longBreak, _): return "长休时段，慢慢恢复能量"
            }
        }
        switch selectedPreset {
        case .focus: return usesCountUp ? "正向计时，什么时候停由你决定" : "选择时长后，开始一个专注回合"
        case .shortBreak: return "短暂离开屏幕，回来会更专注"
        case .longBreak: return "完成一段节奏后，好好休息"
        }
    }

    var canChooseTask: Bool { phase == .idle && selectedPreset == .focus }

    func choosePreset(_ preset: SessionPreset) {
        guard phase == .idle else { return }
        selectedPreset = preset
        if preset != .focus { usesCountUp = false }
        selectedDuration = duration(for: preset, settings: settings)
    }

    func selectTask(_ task: TaskItem?) {
        selectedTaskID = task?.id
        isTaskPickerPresented = false
    }

    func performPrimaryAction() {
        guard let container else { return }
        switch phase {
        case .idle:
            start(using: container)
        case .running:
            container.pauseTimer()
        case .paused:
            container.resumeTimer()
        case .expired:
            container.finishTimer()
        }
        captureContainerError()
    }

    func requestFinish() {
        guard phase == .running || phase == .paused else { return }
        isFinishConfirmationPresented = true
    }

    func finish() {
        container?.finishTimer(early: true)
        isFinishConfirmationPresented = false
        captureContainerError()
    }

    func abandon() {
        container?.abandonTimer()
        isAbandonConfirmationPresented = false
        captureContainerError()
    }

    func adjustDuration(by minutes: Int) {
        guard phase == .idle else { return }
        selectedDuration = min(max(selectedDuration + TimeInterval(minutes * 60), 60), 180 * 60)
    }

    func toggleNoise(_ kind: WhiteNoiseKind) { whiteNoise.toggle(kind) }

    func toggleNoisePlayback() {
        guard let kind = whiteNoise.selectedKind else { return }
        whiteNoise.toggle(kind)
    }

    private func start(using container: AppContainer) {
        switch selectedPreset {
        case .focus:
            container.startFocus(
                taskID: selectedTaskID,
                mode: usesCountUp ? .countUp : .countdown,
                duration: usesCountUp ? nil : selectedDuration
            )
        case .shortBreak, .longBreak:
            container.startBreak(kind: selectedPreset.kind, duration: selectedDuration)
        }
    }

    private func handleFinalCountdown(_ value: TimeInterval?) {
        guard let value, phase == .running else {
            lastCountdownSecond = -1
            return
        }
        let second = Int(ceil(value))
        guard second != lastCountdownSecond else { return }
        lastCountdownSecond = second
        if (1...3).contains(second) {
            container?.feedback.play(
                .countdownTick,
                soundEnabled: settings.soundEnabled,
                hapticEnabled: settings.hapticsEnabled
            )
        }
    }

    private func duration(for preset: SessionPreset, settings: AppSettings) -> TimeInterval {
        switch preset {
        case .focus: return settings.defaultFocusDuration
        case .shortBreak: return settings.shortBreakDuration
        case .longBreak: return settings.longBreakDuration
        }
    }

    private func captureContainerError() {
        if let message = container?.lastTimerMessage,
           message.contains("已有") || message.contains("无法") {
            errorMessage = message
        }
    }
}
