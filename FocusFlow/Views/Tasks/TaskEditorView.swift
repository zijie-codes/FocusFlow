import Foundation
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem?
    let lists: [TaskList]
    let onSave: (TaskItem) -> Void

    @State private var title: String
    @State private var notes: String
    @State private var priority: TaskPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var hasReminderDate: Bool
    @State private var reminderDate: Date
    @State private var estimatedMinutes: Int
    @State private var estimatedPomodoros: Int
    @State private var selectedListID: UUID?
    @State private var tagsText: String
    @State private var repeatChoice: RepeatChoice
    @State private var customInterval: Int
    @State private var customUnit: RepeatIntervalUnit
    @State private var checklist: [Checklist]
    @State private var newChecklistTitle = ""

    init(task: TaskItem?, lists: [TaskList], onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.lists = lists
        self.onSave = onSave

        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _priority = State(initialValue: task?.priority ?? .none)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _hasReminderDate = State(initialValue: task?.reminderDate != nil)
        _reminderDate = State(initialValue: task?.reminderDate ?? Date().addingTimeInterval(3600))
        _estimatedMinutes = State(initialValue: task?.estimatedFocusDuration.map { max(Int($0 / 60), 5) } ?? 25)
        _estimatedPomodoros = State(initialValue: max(task?.estimatedPomodoros ?? 1, 1))
        _selectedListID = State(initialValue: task?.listID)
        _tagsText = State(initialValue: task?.tags.joined(separator: "，") ?? "")
        _repeatChoice = State(initialValue: RepeatChoice(rule: task?.repeatRule))
        _checklist = State(initialValue: task?.checklist ?? [])

        if case let .some(.custom(interval, unit)) = task?.repeatRule {
            _customInterval = State(initialValue: max(interval, 1))
            _customUnit = State(initialValue: unit)
        } else {
            _customInterval = State(initialValue: 2)
            _customUnit = State(initialValue: .day)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("例如：完成项目方案", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .submitLabel(.done)

                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("安排") {
                    Picker("清单", selection: $selectedListID) {
                        Label("无清单", systemImage: "tray").tag(UUID?.none)
                        ForEach(lists) { list in
                            Label(list.name, systemImage: list.iconName)
                                .tag(Optional(list.id))
                        }
                    }

                    Toggle("设置日期", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker(
                            "截止时间",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Toggle("提醒我", isOn: $hasReminderDate.animation())

                    if hasReminderDate {
                        DatePicker(
                            "提醒时间",
                            selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Label(priority.editorTitle, systemImage: priority.editorSystemImage)
                                .tag(priority)
                        }
                    }

                    Stepper(value: $estimatedMinutes, in: 5...240, step: 5) {
                        LabeledContent("预计专注") {
                            Text("\(estimatedMinutes) 分钟")
                                .foregroundStyle(FocusFlowTheme.secondaryText)
                        }
                    }

                    Stepper(value: $estimatedPomodoros, in: 1...20) {
                        LabeledContent("预计番茄") {
                            Text("\(estimatedPomodoros) 个")
                                .foregroundStyle(FocusFlowTheme.secondaryText)
                        }
                    }

                    TextField("标签，用逗号分隔", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section("重复") {
                    Picker("频率", selection: $repeatChoice) {
                        ForEach(RepeatChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }

                    if repeatChoice == .custom {
                        Stepper("每 \(customInterval) 个周期", value: $customInterval, in: 1...30)
                        Picker("周期", selection: $customUnit) {
                            ForEach(RepeatIntervalUnit.allCases, id: \.self) { unit in
                                Text(unit.editorTitle).tag(unit)
                            }
                        }
                    }

                    if repeatChoice == .weekly {
                        Text("将按截止日期所在的星期重复。")
                            .font(.caption)
                            .foregroundStyle(FocusFlowTheme.secondaryText)
                    }
                }

                Section("子任务") {
                    ForEach($checklist) { $item in
                        HStack(spacing: 10) {
                            Button {
                                item.setCompleted(!item.isCompleted)
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? FocusFlowTheme.mint : FocusFlowTheme.secondaryText)
                            }
                            .buttonStyle(.plain)

                            TextField("子任务", text: $item.title)
                                .strikethrough(item.isCompleted)
                        }
                    }
                    .onDelete { checklist.remove(atOffsets: $0) }

                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(FocusFlowTheme.accent)
                        TextField("添加子任务", text: $newChecklistTitle)
                            .submitLabel(.done)
                            .onSubmit(addChecklistItem)
                        if !newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("添加", action: addChecklistItem)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .tint(FocusFlowTheme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(cleanTitle.isEmpty)
                }
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addChecklistItem() {
        let value = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        checklist.append(Checklist(title: value))
        newChecklistTitle = ""
    }

    private func save() {
        guard !cleanTitle.isEmpty else { return }

        var result = task ?? TaskItem(title: cleanTitle)
        result.title = cleanTitle
        result.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        result.priority = priority
        result.dueDate = hasDueDate ? dueDate : nil
        result.reminderDate = hasReminderDate ? reminderDate : nil
        result.estimatedFocusDuration = TimeInterval(estimatedMinutes * 60)
        result.estimatedPomodoros = estimatedPomodoros
        result.listID = selectedListID
        result.tags = tagsText
            .split(whereSeparator: { "，, ".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        result.repeatRule = repeatChoice.makeRule(
            anchor: hasDueDate ? dueDate : Date(),
            interval: customInterval,
            unit: customUnit
        )
        result.checklist = checklist.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        result.updatedAt = Date()
        onSave(result)
        dismiss()
    }
}

private enum RepeatChoice: String, CaseIterable, Identifiable {
    case never
    case daily
    case weekdays
    case weekly
    case monthly
    case custom

    var id: String { rawValue }

    init(rule: RepeatRule?) {
        switch rule {
        case nil: self = .never
        case .some(.daily): self = .daily
        case .some(.weekdays): self = .weekdays
        case .some(.weekly): self = .weekly
        case .some(.monthly): self = .monthly
        case .some(.custom): self = .custom
        }
    }

    var title: String {
        switch self {
        case .never: return "不重复"
        case .daily: return "每天"
        case .weekdays: return "每个工作日"
        case .weekly: return "每周"
        case .monthly: return "每月"
        case .custom: return "自定义"
        }
    }

    func makeRule(anchor: Date, interval: Int, unit: RepeatIntervalUnit) -> RepeatRule? {
        switch self {
        case .never:
            return nil
        case .daily:
            return .daily
        case .weekdays:
            return .weekdays
        case .weekly:
            return .weekly(weekday: Calendar.current.component(.weekday, from: anchor))
        case .monthly:
            return .monthly(day: Calendar.current.component(.day, from: anchor))
        case .custom:
            return .every(interval, unit)
        }
    }
}

private extension TaskPriority {
    var editorTitle: String {
        switch self {
        case .none: return "无"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var editorSystemImage: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .medium: return "equal"
        case .high: return "exclamationmark"
        }
    }
}

private extension RepeatIntervalUnit {
    var editorTitle: String {
        switch self {
        case .day: return "天"
        case .week: return "周"
        case .month: return "月"
        }
    }
}
