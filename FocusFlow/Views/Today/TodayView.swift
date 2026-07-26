import Foundation
import SwiftUI

/// 待办首页：蓝紫横幅 + 全宽渐变任务卡片，右侧「开始」直接进入专注。
struct TodayView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var timer: TimerEngine
    @StateObject private var viewModel = TodayViewModel()
    @State private var pendingDeletion: TaskItem?
    @State private var isFreeFocusPresented = false
    @State private var isListManagerPresented = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            cardList
        }
        .background(FocusFlowTheme.pageBackground.ignoresSafeArea())
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
        .sheet(isPresented: $isFreeFocusPresented) {
            FocusView()
        }
        .sheet(isPresented: $isListManagerPresented) {
            TaskListManagerView(
                lists: viewModel.lists,
                onSave: { container.store.upsertList($0) },
                onDelete: { container.store.deleteList(id: $0.id) }
            )
        }
        .confirmationDialog(
            "删除这项任务？",
            isPresented: isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除任务", role: .destructive, action: confirmPendingDeletion)
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("删除后不可恢复。")
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
                viewModel.presentNewTask()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("新建任务")

            Menu {
                Button {
                    isListManagerPresented = true
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

    // MARK: - Cards

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.activeTasks) { task in
                    todoCard(task)
                }
                if viewModel.activeTasks.isEmpty {
                    emptyHint
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
    }

    private func todoCard(_ task: TaskItem) -> some View {
        TodoCard(
            task: task,
            startDisabled: timer.hasActiveSession,
            onStart: { start(task) },
            onTap: { viewModel.presentEditor(for: task) }
        )
        .contextMenu {
            Button {
                viewModel.presentEditor(for: task)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button {
                viewModel.toggleCompletion(of: task)
            } label: {
                Label("标记完成", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                pendingDeletion = task
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(FocusFlowTheme.accent)
            Text("还没有待办，点右上角 + 新建")
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
    }

    // MARK: - Actions

    private func start(_ task: TaskItem) {
        container.startFocus(taskID: task.id, mode: .countdown, duration: task.estimatedFocusDuration)
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func confirmPendingDeletion() {
        if let task = pendingDeletion {
            viewModel.delete(task)
        }
        pendingDeletion = nil
    }
}

/// 单张待办卡片：渐变背景、左侧标题与时长、右侧「开始」。
private struct TodoCard: View {
    let task: TaskItem
    let startDisabled: Bool
    let onStart: () -> Void
    let onTap: () -> Void

    private var minutesText: String {
        let duration = task.estimatedFocusDuration ?? 25 * 60
        return "\(max(Int(duration / 60), 1)) 分钟"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.cardGradient(seed: task.id.uuidString))
            content
        }
        .frame(height: 104)
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(task.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 10)
                Text(minutesText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
            }
            Spacer(minLength: 8)
            startButton
        }
        .padding(.leading, 20)
        .padding(.vertical, 18)
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("开始")
                .font(.title3.weight(.semibold))
                .tracking(4)
                .foregroundStyle(.white)
                .padding(.vertical, 30)
                .padding(.leading, 24)
                .padding(.trailing, 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(startDisabled)
        .opacity(startDisabled ? 0.55 : 1)
        .accessibilityLabel("开始 \(task.title)")
    }
}
