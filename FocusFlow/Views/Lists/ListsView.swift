import Foundation
import SwiftUI

/// 待办集：清单分组页。左侧彩色竖条 + 清单名，右侧展开 / 统计 / 新增任务。
struct ListsView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var timer: TimerEngine

    @State private var expandedListIDs: Set<UUID> = []
    @State private var statsList: TaskList?
    @State private var isManagerPresented = false
    @State private var isNewListPresented = false
    @State private var newListName = ""
    @State private var isFreeFocusPresented = false
    @State private var editorContext: TaskEditorContext?

    private let paletteCycle = ["#4A90D9", "#2CA9E1", "#9B8CD9", "#22B88A", "#F0A62E", "#E04D77"]

    private var lists: [TaskList] {
        container.store.lists.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            content
        }
        .background(FocusFlowTheme.cardBackground.ignoresSafeArea())
        .sheet(item: $editorContext) { context in
            TaskEditorView(
                task: context.task,
                lists: lists,
                onSave: { container.store.upsertTask($0) }
            )
        }
        .sheet(item: $statsList) { list in
            ListStatsSheet(
                list: list,
                tasks: container.store.tasks,
                records: container.store.records
            )
        }
        .sheet(isPresented: $isManagerPresented) {
            TaskListManagerView(
                lists: lists,
                onSave: { container.store.upsertList($0) },
                onDelete: { container.store.deleteList(id: $0.id) }
            )
        }
        .sheet(isPresented: $isFreeFocusPresented) {
            FocusView()
        }
        .alert("新建清单", isPresented: $isNewListPresented) {
            TextField("清单名称", text: $newListName)
            Button("取消", role: .cancel) { newListName = "" }
            Button("创建", action: createList)
        } message: {
            Text("用清单归类你的待办。")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 28) {
            Spacer()
            Button {
                isFreeFocusPresented = true
            } label: {
                Image(systemName: "clock")
            }
            .accessibilityLabel("自由计时")

            Button {
                isNewListPresented = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("新建清单")

            Menu {
                Button {
                    isManagerPresented = true
                } label: {
                    Label("清单管理", systemImage: "folder.badge.gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .accessibilityLabel("更多")
        }
        .font(.title2)
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(FocusFlowTheme.banner.ignoresSafeArea(edges: .top))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(lists) { list in
                    listRow(list)
                    if expandedListIDs.contains(list.id) {
                        taskSubrows(list)
                    }
                }
                if lists.isEmpty {
                    emptyHint
                }
            }
            .padding(.top, 10)
        }
    }

    private func listRow(_ list: TaskList) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(FocusFlowTheme.listColor(hex: list.colorHex))
                .frame(width: 5, height: 62)

            Text(list.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(FocusFlowTheme.primaryText)
                .padding(.leading, 22)

            Spacer(minLength: 8)

            HStack(spacing: 30) {
                Image(systemName: expandedListIDs.contains(list.id) ? "chevron.down" : "chevron.right")
                Button {
                    statsList = list
                } label: {
                    Image(systemName: "chart.pie")
                }
                .accessibilityLabel("\(list.name) 统计")
                Button {
                    editorContext = TaskEditorContext(task: TaskItem(listID: list.id, title: ""))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("在 \(list.name) 中新建任务")
            }
            .font(.title3)
            .foregroundStyle(Color(uiColor: .systemGray))
            .padding(.trailing, 24)
        }
        .padding(.vertical, 24)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpanded(list)
        }
    }

    @ViewBuilder
    private func taskSubrows(_ list: TaskList) -> some View {
        let items = container.store.tasks
            .filter { $0.listID == list.id }
            .sorted { $0.sortOrder < $1.sortOrder }
        VStack(spacing: 0) {
            if items.isEmpty {
                Text("这个清单还没有任务")
                    .font(.subheadline)
                    .foregroundStyle(FocusFlowTheme.tertiaryText)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            ForEach(items) { task in
                taskSubrow(task)
            }
        }
        .padding(.bottom, 8)
    }

    private func taskSubrow(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button {
                container.store.setTaskCompletion(task.id, completed: !task.isCompleted)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? FocusFlowTheme.mint : Color(uiColor: .systemGray3))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.body)
                .foregroundStyle(task.isCompleted ? FocusFlowTheme.secondaryText : FocusFlowTheme.primaryText)
                .strikethrough(task.isCompleted)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(minutesText(task))
                .font(.caption)
                .foregroundStyle(FocusFlowTheme.tertiaryText)

            if !task.isCompleted {
                Button("开始") {
                    container.startFocus(taskID: task.id, mode: .countdown, duration: task.estimatedFocusDuration)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FocusFlowTheme.accent)
                .disabled(timer.hasActiveSession)
                .opacity(timer.hasActiveSession ? 0.4 : 1)
            }
        }
        .padding(.leading, 44)
        .padding(.trailing, 24)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            editorContext = TaskEditorContext(task: task)
        }
    }

    private var emptyHint: some View {
        Text("点右上角 + 创建第一个清单")
            .font(.subheadline)
            .foregroundStyle(FocusFlowTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func toggleExpanded(_ list: TaskList) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedListIDs.contains(list.id) {
                expandedListIDs.remove(list.id)
            } else {
                expandedListIDs.insert(list.id)
            }
        }
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        guard !name.isEmpty else { return }
        let colorHex = paletteCycle[lists.count % paletteCycle.count]
        container.store.upsertList(
            TaskList(name: name, colorHex: colorHex, sortOrder: lists.count)
        )
    }

    private func minutesText(_ task: TaskItem) -> String {
        let duration = task.estimatedFocusDuration ?? 25 * 60
        return "\(max(Int(duration / 60), 1)) 分钟"
    }
}

/// 编辑器上下文：包一层 Identifiable 以配合 sheet(item:)。
struct TaskEditorContext: Identifiable {
    let id = UUID()
    let task: TaskItem?
}

/// 单个清单的专注统计浮层。
private struct ListStatsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let list: TaskList
    let tasks: [TaskItem]
    let records: [FocusRecord]

    private var listTaskIDs: Set<UUID> {
        Set(tasks.filter { $0.listID == list.id }.map(\.id))
    }

    private var listRecords: [FocusRecord] {
        records.filter { record in
            guard record.kind == .focus, let taskID = record.taskID else { return false }
            return listTaskIDs.contains(taskID)
        }
    }

    private var completedCount: Int {
        listRecords.filter { $0.result == .completed }.count
    }

    private var totalMinutes: Int {
        Int(listRecords.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    private var todayMinutes: Int {
        let calendar = Calendar.current
        let todayRecords = listRecords.filter { calendar.isDateInToday($0.endedAt) }
        return Int(todayRecords.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                Circle()
                    .fill(FocusFlowTheme.listColor(hex: list.colorHex))
                    .frame(width: 10, height: 10)
                Text("\(list.name) · 专注统计")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FocusFlowTheme.accent)
            }

            HStack(spacing: 0) {
                statColumn(title: "专注次数", value: "\(completedCount)")
                statColumn(title: "累计时长", value: "\(totalMinutes) 分")
                statColumn(title: "今日时长", value: "\(todayMinutes) 分")
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(220)])
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .medium).monospacedDigit())
                .foregroundStyle(FocusFlowTheme.accentDeep)
            Text(title)
                .font(.caption)
                .foregroundStyle(FocusFlowTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 清单管理：新建、重命名、删除（任务保留并移回收集箱）。
struct TaskListManagerView: View {
    @Environment(\.dismiss) private var dismiss

    let lists: [TaskList]
    let onSave: (TaskList) -> Void
    let onDelete: (TaskList) -> Void

    @State private var newListName = ""
    @State private var editingList: TaskList?
    @State private var editName = ""
    @State private var deletingList: TaskList?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        TextField("新清单名称", text: $newListName)
                            .submitLabel(.done)
                            .onSubmit(addList)
                        Button(action: addList) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(cleanNewListName.isEmpty)
                        .accessibilityLabel("创建清单")
                    }
                } footer: {
                    Text("删除清单时，里面的任务会保留并移回未分类。")
                }

                Section("我的清单") {
                    if lists.isEmpty {
                        Text("还没有自定义清单")
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }
                    ForEach(lists) { list in
                        managerRow(list)
                    }
                }
            }
            .navigationTitle("清单管理")
            .navigationBarTitleDisplayMode(.inline)
            .tint(FocusFlowTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("重命名清单", isPresented: renameAlertBinding) {
                TextField("清单名称", text: $editName)
                Button("取消", role: .cancel) { editingList = nil }
                Button("保存", action: saveRename)
            } message: {
                Text("请输入一个容易辨认的名称。")
            }
            .confirmationDialog(
                "删除这个清单？",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("删除清单", role: .destructive) {
                    if let deletingList { onDelete(deletingList) }
                    deletingList = nil
                }
                Button("取消", role: .cancel) { deletingList = nil }
            } message: {
                Text("清单内的任务会保留，并移回未分类。")
            }
        }
    }

    private func managerRow(_ list: TaskList) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(FocusFlowTheme.listColor(hex: list.colorHex))
                .frame(width: 12, height: 12)
            Text(list.name)
                .font(.body.weight(.medium))
            Spacer()
            Menu {
                Button {
                    editingList = list
                    editName = list.name
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deletingList = list
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }
        }
    }

    private var cleanNewListName: String {
        newListName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { editingList != nil },
            set: { if !$0 { editingList = nil } }
        )
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { deletingList != nil },
            set: { if !$0 { deletingList = nil } }
        )
    }

    private func addList() {
        guard !cleanNewListName.isEmpty else { return }
        onSave(TaskList(name: cleanNewListName, sortOrder: lists.count))
        newListName = ""
    }

    private func saveRename() {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var list = editingList, !name.isEmpty else { return }
        list.name = name
        list.updatedAt = Date()
        onSave(list)
        editingList = nil
    }
}
