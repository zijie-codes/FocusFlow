import Foundation
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = TodayViewModel()
    @State private var pendingDeletion: TaskItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodaySummaryCard(viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    if viewModel.visibleTasks.isEmpty {
                        EmptyStateView(
                            systemImage: viewModel.completionScope == .planned ? "checklist" : "sparkles",
                            title: viewModel.emptyTitle,
                            message: viewModel.emptyMessage,
                            actionTitle: viewModel.completionScope == .planned ? "添加任务" : nil,
                            action: viewModel.completionScope == .planned ? viewModel.presentNewTask : nil
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.visibleTasks) { task in
                            TaskRowView(
                                task: task,
                                list: viewModel.list(for: task),
                                onToggleCompletion: { viewModel.toggleCompletion(of: task) },
                                onEdit: { viewModel.presentEditor(for: task) },
                                onDelete: { pendingDeletion = task },
                                onPostpone: task.isCompleted ? nil : { viewModel.postponeToTomorrow(task) }
                            )
                            .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 16))
                            .listRowBackground(FocusFlowTheme.cardBackground)
                        }
                        .onMove(perform: viewModel.moveVisibleTasks)
                    }
                } header: {
                    HStack {
                        Text(viewModel.completionScope == .planned ? "待办任务" : "完成记录")
                        Spacer()
                        if !viewModel.visibleTasks.isEmpty {
                            Text("\(viewModel.visibleTasks.count) 项")
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(FocusFlowTheme.pageBackground)
            .navigationTitle(viewModel.navigationTitle)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "搜索任务、备注或清单"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.visibleTasks.count > 1 {
                        EditButton()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    filterMenu

                    Button {
                        viewModel.isListManagerPresented = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                    }
                    .accessibilityLabel("管理清单")

                    Button(action: viewModel.presentNewTask) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加任务")
                }
            }
            .tint(FocusFlowTheme.accent)
            .onAppear {
                viewModel.bind(to: container.store)
            }
            .sheet(isPresented: $viewModel.isTaskEditorPresented) {
                TaskEditorView(
                    task: viewModel.editingTask,
                    lists: viewModel.lists,
                    onSave: viewModel.save
                )
            }
            .sheet(isPresented: $viewModel.isListManagerPresented) {
                TaskListManagerView(
                    lists: viewModel.lists,
                    onSave: viewModel.saveList,
                    onDelete: viewModel.deleteList
                )
            }
            .confirmationDialog(
                "删除这项任务？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除任务", role: .destructive) {
                    if let task = pendingDeletion { viewModel.delete(task) }
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("此操作需要确认，以避免滑动误删。")
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TodayViewModel.DayScope.allCases) { scope in
                        FilterChip(
                            title: scope.rawValue,
                            systemImage: scope.systemImage,
                            isSelected: viewModel.dayScope == scope
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.dayScope = scope
                            }
                        }
                    }

                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 2)

                    ForEach(TodayViewModel.CompletionScope.allCases) { scope in
                        FilterChip(
                            title: scope.rawValue,
                            systemImage: scope == .planned ? "circle.dashed" : "checkmark.circle",
                            count: scope == .planned && viewModel.dayScope == .today ? viewModel.todayPlannedCount : nil,
                            isSelected: viewModel.completionScope == scope
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.completionScope = scope
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if !viewModel.searchText.isEmpty {
                Label("正在当前筛选范围内搜索", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }
            if viewModel.hasActiveFilters {
                Button("清除清单、标签和优先级筛选") { viewModel.clearFilters() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FocusFlowTheme.accent)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Menu("清单") {
                Button("全部清单") { viewModel.selectedListID = nil }
                ForEach(viewModel.lists) { list in
                    Button {
                        viewModel.selectedListID = list.id
                    } label: {
                        Label(list.name, systemImage: viewModel.selectedListID == list.id ? "checkmark" : list.iconName)
                    }
                }
            }
            Menu("优先级") {
                Button("全部优先级") { viewModel.selectedPriority = nil }
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button(priorityFilterName(priority)) { viewModel.selectedPriority = priority }
                }
            }
            if !viewModel.availableTags.isEmpty {
                Menu("标签") {
                    Button("全部标签") { viewModel.selectedTag = nil }
                    ForEach(viewModel.availableTags, id: \.self) { tag in
                        Button(tag) { viewModel.selectedTag = tag }
                    }
                }
            }
            if viewModel.hasActiveFilters {
                Divider()
                Button("清除筛选", action: viewModel.clearFilters)
            }
        } label: {
            Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("筛选任务")
    }

    private func priorityFilterName(_ priority: TaskPriority) -> String {
        switch priority {
        case .none: return "无优先级"
        case .low: return "低优先级"
        case .medium: return "中优先级"
        case .high: return "高优先级"
        }
    }
}

private struct TodaySummaryCard: View {
    @ObservedObject var viewModel: TodayViewModel

    private var dateText: String {
        Date().formatted(
            .dateTime
                .locale(Locale(identifier: "zh_CN"))
                .month(.wide)
                .day()
                .weekday(.wide)
        )
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<19: return "下午好"
        default: return "晚上好"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.title2.weight(.bold))
                    Text(dateText)
                        .font(.subheadline)
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                }

                Spacer()

                ZStack {
                    CircularProgressView(progress: viewModel.todayProgress, lineWidth: 7, tint: FocusFlowTheme.accent)
                    Text("\(Int(viewModel.todayProgress * 100))%")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(FocusFlowTheme.primaryText)
                }
                .frame(width: 58, height: 58)
            }

            HStack(spacing: 0) {
                TodayMetric(
                    title: "待完成",
                    value: "\(viewModel.todayPlannedCount)",
                    systemImage: "list.bullet",
                    tint: FocusFlowTheme.sky
                )
                Divider().frame(height: 48)
                TodayMetric(
                    title: "已完成",
                    value: "\(viewModel.todayCompletedCount)",
                    systemImage: "checkmark",
                    tint: FocusFlowTheme.mint
                )
                Divider().frame(height: 48)
                TodayMetric(
                    title: "今日专注",
                    value: viewModel.todayFocusText,
                    systemImage: "clock.fill",
                    tint: FocusFlowTheme.amber
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.elevatedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .stroke(FocusFlowTheme.separator.opacity(0.35), lineWidth: 0.5)
        )
    }
}

private struct TodayMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Label {
                Text(value)
                    .font(.headline.monospacedDigit())
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(FocusFlowTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .accessibilityElement(children: .combine)
    }
}

private struct TaskListManagerView: View {
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
                    Text("用清单区分工作、学习和生活，让每天的重点更清晰。")
                }

                Section("我的清单") {
                    if lists.isEmpty {
                        Text("还没有自定义清单")
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }

                    ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                        HStack(spacing: 12) {
                            Image(systemName: list.iconName)
                                .foregroundStyle(FocusFlowTheme.categoryColor(at: index))
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle().fill(FocusFlowTheme.categoryColor(at: index).opacity(0.12))
                                )

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
                        .swipeActions {
                            Button(role: .destructive) { deletingList = list } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                editingList = list
                                editName = list.name
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(FocusFlowTheme.sky)
                        }
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
                    .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Text("确认后将删除该清单。")
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
