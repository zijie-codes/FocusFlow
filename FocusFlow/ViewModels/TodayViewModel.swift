import Combine
import Foundation
import SwiftUI

@MainActor
final class TodayViewModel: ObservableObject {
    enum DayScope: String, CaseIterable, Identifiable {
        case inbox = "收集箱"
        case today = "今天"
        case tomorrow = "明天"
        case scheduled = "计划中"
        case all = "全部"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .inbox: return "tray"
            case .today: return "sun.max"
            case .tomorrow: return "sunrise"
            case .scheduled: return "calendar"
            case .all: return "rectangle.stack"
            }
        }
    }

    enum CompletionScope: String, CaseIterable, Identifiable {
        case planned = "计划"
        case completed = "已完成"

        var id: String { rawValue }
    }

    @Published var dayScope: DayScope = .today
    @Published var completionScope: CompletionScope = .planned
    @Published var searchText = ""
    @Published var selectedListID: UUID?
    @Published var selectedPriority: TaskPriority?
    @Published var selectedTag: String?
    @Published var isTaskEditorPresented = false
    @Published var isListManagerPresented = false
    @Published private(set) var editingTask: TaskItem?
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var lists: [TaskList] = []
    @Published private(set) var focusRecords: [FocusRecord] = []

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
                self?.tasks = data.tasks
                self?.lists = data.lists.filter { !$0.isArchived }
                self?.focusRecords = data.records
            }
            .store(in: &cancellables)
    }

    var visibleTasks: [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return tasks
            .filter { isTask($0, in: dayScope) }
            .filter { task in
                switch completionScope {
                case .planned: return !task.isCompleted
                case .completed: return task.isCompleted
                }
            }
            .filter { selectedListID == nil || $0.listID == selectedListID }
            .filter { selectedPriority == nil || $0.priority == selectedPriority }
            .filter { selectedTag == nil || $0.tags.contains(selectedTag ?? "") }
            .filter { task in
                guard !query.isEmpty else { return true }
                return task.title.localizedCaseInsensitiveContains(query)
                    || task.notes.localizedCaseInsensitiveContains(query)
                    || task.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                    || list(for: task)?.name.localizedCaseInsensitiveContains(query) == true
            }
            .sorted(by: taskSort)
    }

    var todayTasks: [TaskItem] {
        tasks.filter { isTask($0, in: .today) }
    }

    var todayPlannedCount: Int {
        todayTasks.filter { !$0.isCompleted }.count
    }

    var todayCompletedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    var todayEstimatedPomodoros: Int {
        todayTasks
            .filter { !$0.isCompleted }
            .reduce(0) { result, task in
                guard let duration = task.estimatedFocusDuration else { return result }
                return result + max(Int(ceil(duration / (25 * 60))), 0)
            }
    }

    var todayFocusText: String {
        let seconds = focusRecords
            .filter { $0.kind == .focus && calendar.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.actualDuration }
        let minutes = max(Int((seconds / 60).rounded()), 0)
        return minutes >= 60 ? "\(minutes / 60)时\(minutes % 60)分" : "\(minutes)分"
    }

    var todayProgress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(todayCompletedCount) / Double(todayTasks.count)
    }

    var availableTags: [String] {
        Array(Set(tasks.flatMap(\.tags))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var hasActiveFilters: Bool {
        selectedListID != nil || selectedPriority != nil || selectedTag != nil
    }

    var navigationTitle: String {
        dayScope.rawValue
    }

    var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "没有匹配的任务"
        }
        return completionScope == .planned ? "安排一点重要的事" : "完成记录会出现在这里"
    }

    var emptyMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "试试更短的关键词，或切换日期和状态。"
        }
        if dayScope == .tomorrow {
            return completionScope == .planned ? "提前写下明天的计划，醒来就知道从哪里开始。" : "明天的完成记录尚为空。"
        }
        return completionScope == .planned ? "把任务拆小一点，完成第一步就很好。" : "每一次勾选，都会成为今天的进度。"
    }

    func list(for task: TaskItem) -> TaskList? {
        guard let listID = task.listID else { return nil }
        return lists.first { $0.id == listID }
    }

    func presentNewTask() {
        editingTask = nil
        isTaskEditorPresented = true
    }

    func presentEditor(for task: TaskItem) {
        editingTask = task
        isTaskEditorPresented = true
    }

    func save(_ task: TaskItem) {
        store?.upsertTask(task)
        isTaskEditorPresented = false
        editingTask = nil
    }

    func toggleCompletion(of task: TaskItem) {
        store?.setTaskCompletion(task.id, completed: !task.isCompleted)
    }

    func delete(_ task: TaskItem) {
        store?.deleteTask(id: task.id)
    }

    func postponeToTomorrow(_ task: TaskItem) {
        store?.deferTaskToTomorrow(task.id)
    }

    func moveVisibleTasks(from source: IndexSet, to destination: Int) {
        var reordered = visibleTasks
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, var task) in reordered.enumerated() {
            task.sortOrder = index
            store?.upsertTask(task)
        }
    }

    func saveList(_ list: TaskList) {
        store?.upsertList(list)
    }

    func deleteList(_ list: TaskList) {
        store?.deleteList(id: list.id)
    }

    func clearFilters() {
        selectedListID = nil
        selectedPriority = nil
        selectedTag = nil
    }

    private func isTask(_ task: TaskItem, in scope: DayScope) -> Bool {
        switch scope {
        case .inbox:
            return task.listID == nil
        case .today:
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDateInToday(dueDate)
                || (!task.isCompleted && dueDate < calendar.startOfDay(for: Date()))
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
                  let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: tomorrow)
        case .scheduled:
            guard let dueDate = task.dueDate,
                  let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date())) else {
                return false
            }
            return dueDate >= dayAfterTomorrow
        case .all:
            return true
        }
    }

    private func taskSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.createdAt < rhs.createdAt
        }
    }
}
