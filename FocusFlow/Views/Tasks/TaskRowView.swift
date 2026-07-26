import Foundation
import SwiftUI

/// 番茄ToDo 风格的任务卡片行：左侧完成圈、中间标题与元信息、右侧红色播放键。
struct TaskRowView: View {
    let task: TaskItem
    var list: TaskList?
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onPostpone: (() -> Void)? = nil
    var startDisabled: Bool = false
    var onStartFocus: (() -> Void)? = nil

    private var priorityColor: Color {
        switch task.priority {
        case .none: return FocusFlowTheme.tertiaryText
        case .low: return FocusFlowTheme.sky
        case .medium: return FocusFlowTheme.amber
        case .high: return FocusFlowTheme.accent
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            completionButton
            editArea
            trailingControls
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: FocusFlowTheme.cornerRadius, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onToggleCompletion) {
                Label(task.isCompleted ? "恢复" : "完成", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isCompleted ? FocusFlowTheme.sky : FocusFlowTheme.mint)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
            if let onPostpone {
                Button(action: onPostpone) {
                    Label("延期到明天", systemImage: "calendar.badge.clock")
                }
                .tint(FocusFlowTheme.amber)
            }
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            .tint(FocusFlowTheme.sky)
        }
        .accessibilityElement(children: .contain)
    }

    private var completionButton: some View {
        Button(action: onToggleCompletion) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(task.isCompleted ? FocusFlowTheme.mint : priorityColor)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")
    }

    private var editArea: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 6) {
                titleText
                metaRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var titleText: some View {
        Text(task.title)
            .font(.body.weight(.medium))
            .foregroundStyle(task.isCompleted ? FocusFlowTheme.secondaryText : FocusFlowTheme.primaryText)
            .strikethrough(task.isCompleted, color: FocusFlowTheme.secondaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
    }

    private var metaRow: some View {
        HStack(spacing: 9) {
            PomodoroDots(completed: task.completedPomodoros, estimated: max(task.estimatedPomodoros, 1))
            if let dueDate = task.dueDate {
                dueLabel(dueDate)
            }
            if let list {
                Text(list.name)
                    .font(.caption2)
                    .foregroundStyle(FocusFlowTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        if task.isCompleted {
            EmptyView()
        } else if let onStartFocus {
            PlayCircleButton(size: 36, action: onStartFocus)
                .disabled(startDisabled)
                .opacity(startDisabled ? 0.35 : 1)
        }
    }

    private func dueLabel(_ date: Date) -> some View {
        Text(dueDescription(date))
            .font(.caption2)
            .foregroundStyle(isOverdue(date) ? FocusFlowTheme.accent : FocusFlowTheme.tertiaryText)
            .lineLimit(1)
    }

    private func isOverdue(_ date: Date) -> Bool {
        !task.isCompleted && date < Date() && !Calendar.current.isDateInToday(date)
    }

    private func dueDescription(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
