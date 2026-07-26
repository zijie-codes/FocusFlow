import Foundation

public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high
}

public struct Checklist: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public mutating func setCompleted(_ completed: Bool, at date: Date = Date()) {
        isCompleted = completed
        completedAt = completed ? date : nil
    }
}

public typealias ChecklistItem = Checklist

public struct TaskItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var listID: UUID?
    public var title: String
    public var notes: String
    public var priority: TaskPriority
    public var dueDate: Date?
    public var reminderDate: Date?
    public var estimatedFocusDuration: TimeInterval?
    public var estimatedPomodoros: Int
    public var completedPomodoros: Int
    public var isCompleted: Bool
    public var completedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var sortOrder: Int
    public var checklist: [Checklist]
    public var tags: [String]
    public var repeatRule: RepeatRule?

    /// Compatibility spelling used by editor/view-model layers.
    public var note: String {
        get { notes }
        set { notes = newValue }
    }

    public var taskListID: UUID? {
        get { listID }
        set { listID = newValue }
    }

    public init(
        id: UUID = UUID(),
        listID: UUID? = nil,
        title: String,
        notes: String = "",
        note: String? = nil,
        priority: TaskPriority = .none,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        estimatedFocusDuration: TimeInterval? = nil,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0,
        checklist: [Checklist] = [],
        tags: [String] = [],
        repeatRule: RepeatRule? = nil
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.notes = note ?? notes
        self.priority = priority
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.estimatedFocusDuration = estimatedFocusDuration
        self.estimatedPomodoros = max(0, estimatedPomodoros)
        self.completedPomodoros = max(0, completedPomodoros)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.checklist = checklist
        self.tags = tags
        self.repeatRule = repeatRule
    }

    public mutating func setCompleted(_ completed: Bool, at date: Date = Date()) {
        isCompleted = completed
        completedAt = completed ? date : nil
        updatedAt = date
    }
}

public struct TaskList: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var sortOrder: Int
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "list.bullet",
        colorHex: String = "#5B67F1",
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum TimerMode: String, Codable, CaseIterable, Sendable {
    case countdown
    case countUp
}

public enum FocusSessionKind: String, Codable, CaseIterable, Sendable {
    case focus
    case shortBreak
    case longBreak
}

public enum FocusRecordOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case interrupted
    case stopped
    case cancelled
}

public typealias FocusRecordResult = FocusRecordOutcome

public struct FocusRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskID: UUID?
    public var sessionID: UUID?
    public var kind: FocusSessionKind
    public var mode: TimerMode
    public var startedAt: Date
    public var endedAt: Date
    public var actualDuration: TimeInterval
    public var pausedDuration: TimeInterval
    public var plannedDuration: TimeInterval?
    public var interruptions: Int
    public var result: FocusRecordResult
    public var note: String

    public var focusedDuration: TimeInterval {
        get { actualDuration }
        set { actualDuration = max(0, newValue) }
    }

    public var outcome: FocusRecordOutcome {
        get { result }
        set { result = newValue }
    }

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        sessionID: UUID? = nil,
        kind: FocusSessionKind = .focus,
        mode: TimerMode = .countdown,
        startedAt: Date,
        endedAt: Date,
        actualDuration: TimeInterval,
        pausedDuration: TimeInterval = 0,
        plannedDuration: TimeInterval? = nil,
        interruptions: Int = 0,
        result: FocusRecordResult = .completed,
        note: String = ""
    ) {
        self.id = id
        self.taskID = taskID
        self.sessionID = sessionID
        self.kind = kind
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.actualDuration = max(0, actualDuration)
        self.pausedDuration = max(0, pausedDuration)
        self.plannedDuration = plannedDuration
        self.interruptions = max(0, interruptions)
        self.result = result
        self.note = note
    }

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        sessionID: UUID? = nil,
        mode: TimerMode,
        startedAt: Date,
        endedAt: Date,
        focusedDuration: TimeInterval,
        pausedDuration: TimeInterval = 0,
        plannedDuration: TimeInterval? = nil,
        outcome: FocusRecordOutcome = .completed,
        note: String = ""
    ) {
        self.init(
            id: id,
            taskID: taskID,
            sessionID: sessionID,
            kind: .focus,
            mode: mode,
            startedAt: startedAt,
            endedAt: endedAt,
            actualDuration: focusedDuration,
            pausedDuration: pausedDuration,
            plannedDuration: plannedDuration,
            result: outcome,
            note: note
        )
    }
}

public enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var defaultFocusDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    public var longBreakInterval: Int
    public var soundEnabled: Bool
    public var voiceEnabled: Bool
    public var hapticsEnabled: Bool
    public var notificationsEnabled: Bool
    public var keepScreenAwake: Bool
    public var autoStartBreak: Bool
    public var continuousFocus: Bool
    public var appearance: AppAppearance

    public var sessionsBeforeLongBreak: Int {
        get { longBreakInterval }
        set { longBreakInterval = max(1, newValue) }
    }

    public var automaticallyStartBreaks: Bool {
        get { autoStartBreak }
        set { autoStartBreak = newValue }
    }

    public var autoStartBreaks: Bool {
        get { autoStartBreak }
        set { autoStartBreak = newValue }
    }

    public init(
        defaultFocusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        longBreakInterval: Int = 4,
        soundEnabled: Bool = true,
        voiceEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        keepScreenAwake: Bool = false,
        autoStartBreak: Bool = false,
        continuousFocus: Bool = false,
        appearance: AppAppearance = .system,
        sessionsBeforeLongBreak: Int? = nil,
        automaticallyStartBreaks: Bool? = nil
    ) {
        self.defaultFocusDuration = max(1, defaultFocusDuration)
        self.shortBreakDuration = max(1, shortBreakDuration)
        self.longBreakDuration = max(1, longBreakDuration)
        self.longBreakInterval = max(1, sessionsBeforeLongBreak ?? longBreakInterval)
        self.soundEnabled = soundEnabled
        self.voiceEnabled = voiceEnabled
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.keepScreenAwake = keepScreenAwake
        self.autoStartBreak = automaticallyStartBreaks ?? autoStartBreak
        self.continuousFocus = continuousFocus
        self.appearance = appearance
    }

    public static let `default` = AppSettings()
}

public struct ActiveTimerSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskID: UUID?
    public var kind: FocusSessionKind
    public var mode: TimerMode
    public var startedAt: Date
    public var plannedDuration: TimeInterval?
    public var scheduledEndAt: Date?
    public var pausedAt: Date?
    public var accumulatedPausedDuration: TimeInterval
    public var interruptionCount: Int
    public var lastUpdatedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        kind: FocusSessionKind = .focus,
        mode: TimerMode,
        startedAt: Date = Date(),
        plannedDuration: TimeInterval? = nil,
        scheduledEndAt: Date? = nil,
        pausedAt: Date? = nil,
        accumulatedPausedDuration: TimeInterval = 0,
        interruptionCount: Int = 0,
        lastUpdatedAt: Date? = nil
    ) {
        let normalizedDuration = plannedDuration.map { max(0, $0) }
        self.id = id
        self.taskID = taskID
        self.kind = kind
        self.mode = mode
        self.startedAt = startedAt
        self.plannedDuration = normalizedDuration
        self.scheduledEndAt = mode == .countdown
            ? (scheduledEndAt ?? normalizedDuration.map { startedAt.addingTimeInterval($0) })
            : nil
        self.pausedAt = pausedAt
        self.accumulatedPausedDuration = max(0, accumulatedPausedDuration)
        self.interruptionCount = max(0, interruptionCount)
        self.lastUpdatedAt = lastUpdatedAt ?? startedAt
    }

    public var isPaused: Bool { pausedAt != nil }

    public func elapsed(at date: Date) -> TimeInterval {
        let effectiveDate = pausedAt ?? date
        let elapsed = effectiveDate.timeIntervalSince(startedAt) - accumulatedPausedDuration
        if mode == .countdown, let plannedDuration {
            return min(plannedDuration, max(0, elapsed))
        }
        return max(0, elapsed)
    }

    public func remaining(at date: Date) -> TimeInterval? {
        guard mode == .countdown else { return nil }
        if let scheduledEndAt {
            return max(0, scheduledEndAt.timeIntervalSince(pausedAt ?? date))
        }
        guard let plannedDuration else { return 0 }
        return max(0, plannedDuration - elapsed(at: date))
    }

    public func isExpired(at date: Date) -> Bool {
        guard mode == .countdown, pausedAt == nil else { return false }
        return (remaining(at: date) ?? 0) <= 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskID
        case kind
        case mode
        case startedAt
        case plannedDuration
        case scheduledEndAt
        case pausedAt
        case accumulatedPausedDuration
        case interruptionCount
        case lastUpdatedAt
    }

    /// Keeps sessions written before interruption tracking compatible with the
    /// current store format.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            taskID: try container.decodeIfPresent(UUID.self, forKey: .taskID),
            kind: try container.decodeIfPresent(FocusSessionKind.self, forKey: .kind) ?? .focus,
            mode: try container.decode(TimerMode.self, forKey: .mode),
            startedAt: startedAt,
            plannedDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .plannedDuration),
            scheduledEndAt: try container.decodeIfPresent(Date.self, forKey: .scheduledEndAt),
            pausedAt: try container.decodeIfPresent(Date.self, forKey: .pausedAt),
            accumulatedPausedDuration: try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .accumulatedPausedDuration
            ) ?? 0,
            interruptionCount: try container.decodeIfPresent(Int.self, forKey: .interruptionCount) ?? 0,
            lastUpdatedAt: try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        )
    }
}
