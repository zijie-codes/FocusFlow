import Combine
import Foundation
import SwiftUI
import UIKit

/// 应用级依赖容器。页面只观察这个对象及 TimerEngine，持久化、通知和媒体服务由这里协调。
@MainActor
final class AppContainer: ObservableObject {
    let store: AppStore
    let timer: TimerEngine
    let notifications: NotificationService
    let feedback: FeedbackService
    let speech: SpeechService
    let whiteNoise: WhiteNoiseService
    let backup: BackupService

    /// 兼容页面级 ViewModel 的语义化命名。
    var timerEngine: TimerEngine { timer }

    @Published private(set) var lastTimerMessage: String?
    @Published private(set) var completedFocusSessions: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var lastFocusTaskID: UUID?
    private var knownReminderTaskIDs = Set<UUID>()

    convenience init() {
    self.init(
        store: AppStore(),
        notifications: NotificationService(),
        feedback: FeedbackService(),
        speech: SpeechService(),
        whiteNoise: WhiteNoiseService(),
        backup: BackupService()
    )
}

init(
    store: AppStore,
    notifications: NotificationService,
    feedback: FeedbackService,
    speech: SpeechService,
    whiteNoise: WhiteNoiseService,
    backup: BackupService
) {
        self.store = store
        self.notifications = notifications
        self.feedback = feedback
        self.speech = speech
        self.whiteNoise = whiteNoise
        self.backup = backup
        self.timer = TimerEngine(store: store)
        self.completedFocusSessions = store.records.filter {
            $0.kind == .focus && $0.result == .completed
        }.count

        store.$data
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.objectWillChange.send()
                self?.synchronizeTaskReminders(from: data)
            }
            .store(in: &cancellables)

        timer.$phase
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard phase == .expired else { return }
                self?.completeExpiredTimer()
            }
            .store(in: &cancellables)

        synchronizeTaskReminders(from: store.data)
    }

    var appearanceScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func applicationDidBecomeActive() {
        timer.tick()
        if timer.isExpired {
            completeExpiredTimer()
        }
    }

    func applicationWillResignActive() {
        timer.tick()
    }

    func requestNotificationPermissionIfNeeded() {
        guard store.settings.notificationsEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            if self.notifications.authorizationStatus == .notDetermined {
                _ = await self.notifications.requestAuthorization()
            } else {
                await self.notifications.refreshAuthorizationStatus()
            }
        }
    }

    func startFocus(taskID: UUID?, mode: TimerMode, duration: TimeInterval? = nil) {
        guard !timer.hasActiveSession else {
            lastTimerMessage = "已有正在进行的计时，请先完成、暂停或放弃它。"
            return
        }

        let settings = store.settings
        let plannedDuration: TimeInterval? = mode == .countdown
            ? (duration ?? settings.defaultFocusDuration)
            : nil
        do {
            let session: ActiveTimerSession
            switch mode {
            case .countdown:
                session = try timer.startCountdown(
                    duration: plannedDuration ?? settings.defaultFocusDuration,
                    taskID: taskID,
                    kind: .focus
                )
            case .countUp:
                session = try timer.startCountUp(taskID: taskID, kind: .focus)
            }
            configureKeepAwake(settings.keepScreenAwake)
            scheduleTimerNotification(for: session)
            lastTimerMessage = nil
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    func startBreak(kind: FocusSessionKind, duration customDuration: TimeInterval? = nil) {
        guard kind == .shortBreak || kind == .longBreak else { return }
        guard !timer.hasActiveSession else { return }
        let defaultDuration = kind == .shortBreak ? store.settings.shortBreakDuration : store.settings.longBreakDuration
        let duration = customDuration ?? defaultDuration
        do {
            let session = try timer.startCountdown(duration: duration, kind: kind)
            configureKeepAwake(store.settings.keepScreenAwake)
            scheduleTimerNotification(for: session)
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    func pauseTimer() {
        do {
            try timer.pause()
            if let session = timer.session { notifications.cancelTimerCompletion(sessionID: session.id) }
            whiteNoise.handleFocusPaused()
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    func resumeTimer() {
        do {
            try timer.resume()
            if let session = timer.session { scheduleTimerNotification(for: session) }
            if whiteNoise.selectedKind != nil { whiteNoise.resume() }
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    func finishTimer(early: Bool = false) {
        // “提前完成”按实际有效时长记为完成；“放弃”才记为取消。
        finishTimer(outcome: .completed)
    }

    func abandonTimer() {
        finishTimer(outcome: .cancelled)
    }

    func dismissTimerMessage() {
        lastTimerMessage = nil
    }

    func updateSettings(_ settings: AppSettings) {
        store.updateSettings(settings)
        configureKeepAwake(settings.keepScreenAwake && timer.isRunning)
        if settings.notificationsEnabled { requestNotificationPermissionIfNeeded() }
    }

    func replaceData(_ data: AppData) throws {
        timer.discard()
        var imported = data
        imported.activeTimerSession = nil
        try store.replaceData(imported)
        completedFocusSessions = imported.records.filter { $0.kind == .focus && $0.result == .completed }.count
        synchronizeTaskReminders(from: imported)
    }

    func clearAllData() {
        timer.discard()
        whiteNoise.stop()
        notifications.removeAllFocusFlowNotifications()
        do {
            try store.replaceData(.empty)
            completedFocusSessions = 0
            lastTimerMessage = "所有本地数据已清除。"
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    private func completeExpiredTimer() {
        finishTimer(outcome: .completed)
    }

    private func finishTimer(outcome: FocusRecordOutcome) {
        guard let activeSession = timer.session else { return }
        do {
            let record = try timer.stop(outcome: outcome)
            notifications.cancelTimerCompletion(sessionID: activeSession.id)
            whiteNoise.handleFocusEnded()
            configureKeepAwake(false)
            handleFinished(record: record)
        } catch {
            lastTimerMessage = error.localizedDescription
        }
    }

    private func handleFinished(record: FocusRecord) {
        let settings = store.settings
        let completed = record.result == .completed

        if completed {
            let event: FeedbackService.Event = record.kind == .focus ? .focusCompleted : .breakCompleted
            feedback.play(event, soundEnabled: settings.soundEnabled, hapticEnabled: settings.hapticsEnabled)
        }

        switch record.kind {
        case .focus:
            lastFocusTaskID = record.taskID
            if completed {
                completedFocusSessions += 1
                incrementPomodoro(for: record.taskID)
                let taskTitle = record.taskID.flatMap { id in store.tasks.first { $0.id == id }?.title }
                if settings.voiceEnabled { speech.announceFocusCompletion(taskTitle: taskTitle) }
                lastTimerMessage = "专注完成，已写入历史记录。"
                if settings.autoStartBreak {
                    let breakKind: FocusSessionKind = completedFocusSessions.isMultiple(of: settings.longBreakInterval)
                        ? .longBreak
                        : .shortBreak
                    startBreak(kind: breakKind)
                }
            } else {
                lastTimerMessage = record.result == .cancelled ? "本次专注已放弃。" : "本次专注已提前结束。"
            }
        case .shortBreak, .longBreak:
            if completed {
                if settings.voiceEnabled { speech.announceBreakCompletion() }
                lastTimerMessage = "休息结束，准备开始下一次专注。"
                if settings.continuousFocus { startFocus(taskID: lastFocusTaskID, mode: .countdown) }
            } else {
                lastTimerMessage = "休息已结束。"
            }
        }
    }

    private func incrementPomodoro(for taskID: UUID?) {
        guard let taskID, var task = store.tasks.first(where: { $0.id == taskID }) else { return }
        task.completedPomodoros += 1
        task.updatedAt = Date()
        store.upsertTask(task)
    }

    private func scheduleTimerNotification(for session: ActiveTimerSession) {
        guard store.settings.notificationsEnabled,
              let end = session.scheduledEndAt,
              session.mode == .countdown else { return }
        let isFocus = session.kind == .focus
        let title = isFocus ? "专注结束" : "休息结束"
        let body: String
        if isFocus, let taskID = session.taskID, let task = store.tasks.first(where: { $0.id == taskID }) {
            body = "\(task.title) 的本次专注已完成。"
        } else {
            body = isFocus ? "完成一次专注，给自己一点缓冲。" : "准备回到下一件重要的事。"
        }
        Task { [weak self] in
            guard let self else { return }
            try? await self.notifications.scheduleTimerCompletion(
                sessionID: session.id,
                fireDate: end,
                title: title,
                body: body,
                soundEnabled: self.store.settings.soundEnabled
            )
        }
    }

    private func synchronizeTaskReminders(from data: AppData) {
        let eligibleTasks = data.tasks.filter {
            !$0.isCompleted && $0.reminderDate.map { $0 > Date() } == true
        }
        let nextIDs = data.settings.notificationsEnabled ? Set(eligibleTasks.map(\.id)) : []
        for removedID in knownReminderTaskIDs.subtracting(nextIDs) {
            notifications.cancelTaskReminder(taskID: removedID)
        }
        knownReminderTaskIDs = nextIDs
        guard data.settings.notificationsEnabled else { return }

        for task in eligibleTasks {
            guard let reminder = task.reminderDate else { continue }
            Task { [weak self] in
                guard let self else { return }
                try? await self.notifications.scheduleTaskReminder(
                    taskID: task.id,
                    fireDate: reminder,
                    title: task.title,
                    soundEnabled: data.settings.soundEnabled
                )
            }
        }
    }

    private func configureKeepAwake(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}
