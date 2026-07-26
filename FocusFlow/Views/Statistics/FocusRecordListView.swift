import Foundation
import SwiftUI

/// 专注记录列表：数据统计页「查看专注记录」与我的页「历史时间轴」共用。
struct FocusRecordListView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [FocusRecord]
    let tasks: [TaskItem]

    private var sortedRecords: [FocusRecord] {
        records
            .filter { $0.kind == .focus }
            .sorted { $0.endedAt > $1.endedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedRecords.isEmpty {
                    Text("还没有专注记录")
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                }
                ForEach(Array(sortedRecords.prefix(300))) { record in
                    recordRow(record)
                }
            }
            .navigationTitle("专注记录")
            .navigationBarTitleDisplayMode(.inline)
            .tint(FocusFlowTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func recordRow(_ record: FocusRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title(for: record))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(resultText(record))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(resultTint(record))
            }
            Text(timeRange(record))
                .font(.caption)
                .foregroundStyle(FocusFlowTheme.secondaryText)
            Text("有效 \(max(Int(record.actualDuration / 60), 0)) 分钟 · 中断 \(record.interruptions) 次")
                .font(.caption2)
                .foregroundStyle(FocusFlowTheme.tertiaryText)
        }
        .padding(.vertical, 3)
    }

    private func title(for record: FocusRecord) -> String {
        guard let id = record.taskID, let task = tasks.first(where: { $0.id == id }) else {
            return "自由专注"
        }
        return task.title
    }

    private func timeRange(_ record: FocusRecord) -> String {
        let start = record.startedAt.formatted(.dateTime.month().day().hour().minute())
        let end = record.endedAt.formatted(.dateTime.hour().minute())
        return "\(start) – \(end)"
    }

    private func resultText(_ record: FocusRecord) -> String {
        switch record.result {
        case .completed: return "完成"
        case .stopped: return "提前结束"
        case .interrupted: return "中断"
        case .cancelled: return "放弃"
        }
    }

    private func resultTint(_ record: FocusRecord) -> Color {
        switch record.result {
        case .completed: return FocusFlowTheme.mint
        case .stopped: return FocusFlowTheme.amber
        case .interrupted, .cancelled: return FocusFlowTheme.coral
        }
    }
}
