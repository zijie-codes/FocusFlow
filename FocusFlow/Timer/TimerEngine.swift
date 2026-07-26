import Combine
import Foundation

public enum TimerEnginePhase: String, Codable, Sendable {
    case idle
    case running
    case paused
    case expired
}

public enum TimerEngineError: LocalizedError, Equatable {
    case sessionAlreadyActive
    case noActiveSession
    case invalidDuration
    case invalidTransition(from: TimerEnginePhase)

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "已有正在进行的计时。"
        case .noActiveSession:
            return "当前没有可操作的计时。"
        case .invalidDuration:
            return "倒计时时长必须大于零。"
        case let .invalidTransition(phase):
            return "当前计时状态（\(phase.rawValue)）不能执行此操作。"
        }
    }
}

public enum TimerRestorationResult: Equatable, Sendable {
    case none
    case running
    case paused
    case expired
}

/// Date-driven timer state. The one-second ticker only refreshes presentation;
/// elapsed time is always derived from persisted dates, so suspending the app,
/// crossing midnight, and missed timer callbacks do not introduce drift.
@MainActor
public final class TimerEngine: ObservableObject {
    @Published public private(set) var session: ActiveTimerSession?
    @Published public private(set) var phase: TimerEnginePhase = .idle
    @Published public private(set) var elapsed: TimeInterval = 0
    @Published public private(set) var remaining: TimeInterval?

    public var isRunning: Bool { phase == .running }
    public var isPaused: Bool { phase == .paused }
    public var isExpired: Bool { phase == .expired }
    public var hasActiveSession: Bool { session != nil }

    private weak var store: AppStore?
    private let nowProvider: () -> Date
    private let automaticallyTicks: Bool
    private var ticker: Timer?

    public init(
        store: AppStore? = nil,
        automaticallyTicks: Bool = true,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.automaticallyTicks = automaticallyTicks
        self.nowProvider = now
        self.session = store?.activeTimerSession

        refresh(at: now())
        if phase == .running {
            startTickerIfNeeded()
        }
    }

    deinit {
        ticker?.invalidate()
    }

    @discardableResult
    public func startCountdown(
        duration: TimeInterval,
        taskID: UUID? = nil,
        kind: FocusSessionKind = .focus,
        at date: Date? = nil
    ) throws -> ActiveTimerSession {
        try start(mode: .countdown, duration: duration, taskID: taskID, kind: kind, at: date)
    }

    @discardableResult
    public func startCountUp(
        taskID: UUID? = nil,
        kind: FocusSessionKind = .focus,
        at date: Date? = nil
    ) throws -> ActiveTimerSession {
        try start(mode: .countUp, duration: nil, taskID: taskID, kind: kind, at: date)
    }

    @discardableResult
    public func start(
        mode: TimerMode,
        duration: TimeInterval? = nil,
        taskID: UUID? = nil,
        kind: FocusSessionKind = .focus,
        at suppliedDate: Date? = nil
    ) throws -> ActiveTimerSession {
        guard session == nil else { throw TimerEngineError.sessionAlreadyActive }
        if mode == .countdown {
            guard let duration, duration > 0 else { throw TimerEngineError.invalidDuration }
        }

        let date = suppliedDate ?? nowProvider()
        let newSession = ActiveTimerSession(
            taskID: taskID,
            kind: kind,
            mode: mode,
            startedAt: date,
            plannedDuration: mode == .countdown ? duration : nil,
            scheduledEndAt: mode == .countdown
                ? date.addingTimeInterval(duration ?? 0)
                : nil,
            lastUpdatedAt: date
        )
        session = newSession
        phase = .running
        refresh(at: date)
        persistSession()
        startTickerIfNeeded()
        return newSession
    }

    public func pause(at suppliedDate: Date? = nil) throws {
        let date = suppliedDate ?? nowProvider()
        guard var current = session else { throw TimerEngineError.noActiveSession }

        refresh(at: date)
        guard phase == .running else {
            throw TimerEngineError.invalidTransition(from: phase)
        }

        current.pausedAt = date
        current.interruptionCount += 1
        current.lastUpdatedAt = date
        session = current
        refresh(at: date)
        persistSession()
        stopTicker()
    }

    public func resume(at suppliedDate: Date? = nil) throws {
        let date = suppliedDate ?? nowProvider()
        guard var current = session else { throw TimerEngineError.noActiveSession }
        guard let pausedAt = current.pausedAt else {
            throw TimerEngineError.invalidTransition(from: phase)
        }

        let pauseDuration = max(0, date.timeIntervalSince(pausedAt))
        current.accumulatedPausedDuration += pauseDuration
        if let scheduledEndAt = current.scheduledEndAt {
            current.scheduledEndAt = scheduledEndAt.addingTimeInterval(pauseDuration)
        }
        current.pausedAt = nil
        current.lastUpdatedAt = date
        session = current
        refresh(at: date)
        persistSession()
        startTickerIfNeeded()
    }

    /// Refreshes published values using an absolute date. Safe to call from
    /// scene foreground/background transitions and deterministic tests.
    public func tick(at suppliedDate: Date? = nil) {
        refresh(at: suppliedDate ?? nowProvider())
        if phase == .expired || phase == .paused || phase == .idle {
            stopTicker()
        }
    }

    public func hasExpired(at suppliedDate: Date? = nil) -> Bool {
        guard let session else { return false }
        return session.isExpired(at: suppliedDate ?? nowProvider())
    }

    /// Re-reads the persisted session. A countdown whose scheduled end passed
    /// while the app was terminated is restored as `.expired`.
    @discardableResult
    public func restoreFromStore(at suppliedDate: Date? = nil) -> TimerRestorationResult {
        stopTicker()
        session = store?.activeTimerSession
        refresh(at: suppliedDate ?? nowProvider())
        if phase == .running { startTickerIfNeeded() }
        return restorationResult
    }

    /// Installs a decoded session when persistence is managed outside AppStore.
    @discardableResult
    public func restore(
        _ savedSession: ActiveTimerSession,
        at suppliedDate: Date? = nil
    ) throws -> TimerRestorationResult {
        guard session == nil else { throw TimerEngineError.sessionAlreadyActive }
        session = savedSession
        refresh(at: suppliedDate ?? nowProvider())
        persistSession()
        if phase == .running { startTickerIfNeeded() }
        return restorationResult
    }

    /// Ends the active session and returns a history record. If a countdown is
    /// ended after its deadline, its outcome is automatically `completed` and
    /// its duration is capped at the planned duration.
    @discardableResult
    public func stop(
        outcome requestedOutcome: FocusRecordOutcome = .stopped,
        note: String = "",
        at suppliedDate: Date? = nil,
        saveRecord: Bool = true
    ) throws -> FocusRecord {
        let date = suppliedDate ?? nowProvider()
        guard let current = session else { throw TimerEngineError.noActiveSession }

        refresh(at: date)
        let expired = current.isExpired(at: date)
        let effectiveOutcome: FocusRecordOutcome = expired ? .completed : requestedOutcome
        let effectiveEnd = expired ? (current.scheduledEndAt ?? date) : date
        let record = FocusRecord(
            taskID: current.taskID,
            sessionID: current.id,
            kind: current.kind,
            mode: current.mode,
            startedAt: current.startedAt,
            endedAt: effectiveEnd,
            actualDuration: current.elapsed(at: date),
            pausedDuration: totalPausedDuration(for: current, at: date),
            plannedDuration: current.plannedDuration,
            interruptions: current.interruptionCount,
            result: effectiveOutcome,
            note: note
        )

        clearSession()
        if saveRecord { store?.appendFocusRecord(record) }
        return record
    }

    @discardableResult
    public func finish(
        note: String = "",
        at date: Date? = nil,
        saveRecord: Bool = true
    ) throws -> FocusRecord {
        try stop(outcome: .completed, note: note, at: date, saveRecord: saveRecord)
    }

    /// Drops the session without adding a history record.
    public func discard() {
        clearSession()
    }

    public func attach(to store: AppStore, restore: Bool = true) {
        self.store = store
        if restore {
            _ = restoreFromStore()
        } else {
            persistSession()
        }
    }

    private var restorationResult: TimerRestorationResult {
        switch phase {
        case .idle: return .none
        case .running: return .running
        case .paused: return .paused
        case .expired: return .expired
        }
    }

    private func refresh(at date: Date) {
        guard let current = session else {
            phase = .idle
            elapsed = 0
            remaining = nil
            return
        }

        elapsed = current.elapsed(at: date)
        remaining = current.remaining(at: date)
        if current.isPaused {
            phase = .paused
        } else if current.isExpired(at: date) {
            phase = .expired
        } else {
            phase = .running
        }
    }

    private func totalPausedDuration(
        for session: ActiveTimerSession,
        at date: Date
    ) -> TimeInterval {
        let currentPause = session.pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return session.accumulatedPausedDuration + currentPause
    }

    private func persistSession() {
        store?.setActiveTimerSession(session)
    }

    private func clearSession() {
        stopTicker()
        session = nil
        phase = .idle
        elapsed = 0
        remaining = nil
        persistSession()
    }

    private func startTickerIfNeeded() {
        guard automaticallyTicks, ticker == nil, phase == .running else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
