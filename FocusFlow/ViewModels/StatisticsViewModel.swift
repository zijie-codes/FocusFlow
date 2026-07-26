import Combine
import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case today = "今天"
        case sevenDays = "7 天"
        case thirtyDays = "30 天"
        case all = "全部"

        var id: String { rawValue }
    }

    struct DailyPoint: Identifiable, Hashable {
        let date: Date
        let duration: TimeInterval
        let sessions: Int

        var id: Date { date }
    }

    struct CategoryShare: Identifiable, Hashable {
        let id: UUID?
        let name: String
        let duration: TimeInterval
        let colorIndex: Int

        var fraction: Double { duration }
    }

    @Published var period: Period = .sevenDays
    @Published private(set) var records: [FocusRecord] = []
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var lists: [TaskList] = []

    private weak var store: AppStore?
    private var cancellables = Set<AnyCancellable>()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func bind(to store: AppStore) {
        guard self.store !== store else { return }
        self.store = store
        cancellables.removeAll()
        store.$data
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.records = data.records
                self?.tasks = data.tasks
                self?.lists = data.lists
            }
            .store(in: &cancellables)
    }

    var filteredRecords: [FocusRecord] {
        let interval = dateInterval(for: period)
        return records
            .filter { $0.kind == .focus }
            .filter { interval.contains($0.endedAt) }
            .sorted { $0.endedAt > $1.endedAt }
    }

    var totalDuration: TimeInterval {
        filteredRecords.reduce(0) { $0 + $1.actualDuration }
    }

    var completedSessions: Int {
        filteredRecords.filter { $0.result == .completed }.count
    }

    var interruptionCount: Int {
        filteredRecords.reduce(0) { $0 + $1.interruptions }
    }

    var completedTaskCount: Int {
        let interval = dateInterval(for: period)
        return tasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return interval.contains(completedAt)
        }.count
    }

    var averageDuration: TimeInterval {
        guard !filteredRecords.isEmpty else { return 0 }
        return totalDuration / Double(filteredRecords.count)
    }

    var streakDays: Int {
        let focusedDays = Set(
            records
                .filter { $0.kind == .focus && $0.result == .completed && $0.actualDuration > 0 }
                .map { calendar.startOfDay(for: $0.endedAt) }
        )
        guard !focusedDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let start = focusedDays.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        guard focusedDays.contains(start) else { return 0 }

        var count = 0
        var cursor = start
        while focusedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    var dailyPoints: [DailyPoint] {
        let interval = dateInterval(for: period)
        let firstDate: Date
        switch period {
        case .today:
            firstDate = calendar.startOfDay(for: Date())
        case .sevenDays:
            firstDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        case .thirtyDays:
            firstDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) ?? Date()
        case .all:
            firstDate = records
                .filter { $0.kind == .focus }
                .map(\.endedAt)
                .min()
                .map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: Date())
        }

        var grouped: [Date: (duration: TimeInterval, sessions: Int)] = [:]
        for record in filteredRecords where interval.contains(record.endedAt) {
            let day = calendar.startOfDay(for: record.endedAt)
            var value = grouped[day] ?? (0, 0)
            value.duration += record.actualDuration
            if record.result == .completed { value.sessions += 1 }
            grouped[day] = value
        }

        let maximumDays = period == .all ? 90 : 31
        let dayCount = min(maximumDays, max(calendar.dateComponents([.day], from: firstDate, to: Date()).day ?? 0, 0) + 1)
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDate) else { return nil }
            let value = grouped[day] ?? (0, 0)
            return DailyPoint(date: day, duration: value.duration, sessions: value.sessions)
        }
    }

    var categoryShares: [CategoryShare] {
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var durations: [UUID?: TimeInterval] = [:]
        for record in filteredRecords {
            let listID = record.taskID.flatMap { taskMap[$0]?.listID }
            durations[listID, default: 0] += record.actualDuration
        }

        return durations
            .map { listID, duration in
                let list = listID.flatMap { id in lists.first { $0.id == id } }
                return CategoryShare(
                    id: listID,
                    name: list?.name ?? "未分类",
                    duration: duration,
                    colorIndex: lists.firstIndex(where: { $0.id == listID }) ?? lists.count
                )
            }
            .sorted { $0.duration > $1.duration }
    }

    func taskTitle(for record: FocusRecord) -> String {
        guard let id = record.taskID, let task = tasks.first(where: { $0.id == id }) else {
            return record.kind == .focus ? "未关联任务" : record.kind.statisticsTitle
        }
        return task.title
    }

    func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(Int((duration / 60).rounded()), 0)
        if minutes >= 60 {
            return "\(minutes / 60) 小时 \(minutes % 60) 分"
        }
        return "\(minutes) 分钟"
    }

    private func dateInterval(for period: Period) -> DateInterval {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let start: Date
        switch period {
        case .today:
            start = startOfToday
        case .sevenDays:
            start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        case .thirtyDays:
            start = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
        case .all:
            start = .distantPast
        }
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }
}

private extension FocusSessionKind {
    var statisticsTitle: String {
        switch self {
        case .focus: return "专注"
        case .shortBreak: return "短休"
        case .longBreak: return "长休"
        }
    }
}
