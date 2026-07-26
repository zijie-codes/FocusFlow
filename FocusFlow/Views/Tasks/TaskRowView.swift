import Foundation
import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var list: TaskList?
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onPostpone: (() -> Void)? = nil

    private var priorityColor: Color {
        switch task.priority {
        case .none: return FocusFlowTheme.tertiaryText
        case .low: return FocusFlowTheme.sky
        case .medium: return FocusFlowTheme.amber
        case .high: return FocusFlowTheme.accent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(task.isCompleted ? FocusFlowTheme.mint : priorityColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(task.isCompleted ? FocusFlowTheme.secondaryText : FocusFlowTheme.primaryText)
                        .strikethrough(task.isCompleted, color: FocusFlowTheme.secondaryText)
                        .multilineTextAlignment(.leading)

                    if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(task.notes)
                            .font(.caption)
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    metadata
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if task.priority != .none {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 7)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 7)
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

    @ViewBuilder
    private var metadata: some View {
        let hasMetadata = task.dueDate != nil || task.estimatedFocusDuration != nil || list != nil
        if hasMetadata {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let dueDate = task.dueDate {
                        TaskMetadataLabel(
                            text: dueDescription(dueDate),
                            systemImage: isOverdue(dueDate) ? "exclamationmark.circle.fill" : "calendar",
                            tint: isOverdue(dueDate) ? FocusFlowTheme.accent : FocusFlowTheme.secondaryText
                        )
                    }

                    if let duration = task.estimatedFocusDuration, duration > 0 {
                        TaskMetadataLabel(
                            text: durationDescription(duration),
                            systemImage: "timer",
                            tint: FocusFlowTheme.secondaryText
                        )
                    }

                    if let list {
                        TaskMetadataLabel(
                            text: list.name,
                            systemImage: "folder",
                            tint: FocusFlowTheme.secondaryText
                        )
                    }

                }
            }
        }
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
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func durationDescription(_ duration: TimeInterval) -> String {
        let minutes = max(Int(duration / 60), 1)
        if minutes >= 60, minutes.isMultiple(of: 60) {
            return "\(minutes / 60) 小时"
        }
        return "\(minutes) 分钟"
    }
}

private struct TaskMetadataLabel: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}
