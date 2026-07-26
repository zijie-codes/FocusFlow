import Combine
import Foundation
import SwiftUI

/// 待办首页的轻量状态：任务卡片列表与编辑器呈现。
@MainActor
final class TodayViewModel: ObservableObject {
    @Published var isTaskEditorPresented = false
    @Published private(set) var editingTask: TaskItem?
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var lists: [TaskList] = []

    private weak var store: AppStore?
    private var cancellables = Set<AnyCancellable>()

    func bind(to store: AppStore) {
        guard self.store !== store else { return }
        self.store = store
        cancellables.removeAll()

        store.$data
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.tasks = data.tasks
                self?.lists = data.lists.filter { !$0.isArchived }
            }
            .store(in: &cancellables)
    }

    /// 首页卡片只展示未完成任务，按排序序号排列。
    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
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
}
