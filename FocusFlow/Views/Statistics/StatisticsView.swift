import Charts
import Foundation
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodPicker
                    overview
                    durationChart
                    pomodoroChart
                    categorySection
                    historySection
                }
                .padding(.horizontal, FocusFlowTheme.horizontalPadding)
                .padding(.vertical, 16)
            }
            .background(FocusFlowTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("统计")
            .onAppear { viewModel.bind(to: container.store) }
        }
    }

    private var periodPicker: some View {
        Picker("统计范围", selection: $viewModel.period) {
            ForEach(StatisticsViewModel.Period.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("统计时间范围")
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "专注概览", subtitle: "连续专注 \(viewModel.streakDays) 天")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                MetricTile(title: "专注时长", value: viewModel.durationText(viewModel.totalDuration), systemImage: "clock.fill", tint: FocusFlowTheme.accent)
                MetricTile(title: "完成番茄", value: "\(viewModel.completedSessions)", systemImage: "timer", tint: FocusFlowTheme.mint)
                MetricTile(title: "完成任务", value: "\(viewModel.completedTaskCount)", systemImage: "checkmark.circle.fill", tint: FocusFlowTheme.sky)
                MetricTile(title: "中断次数", value: "\(viewModel.interruptionCount)", systemImage: "pause.circle.fill", tint: FocusFlowTheme.amber)
            }
        }
    }

    private var durationChart: some View {
        chartCard(title: "每日专注时长", subtitle: "按有效专注分钟统计") {
            Chart(viewModel.dailyPoints) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("分钟", point.duration / 60)
                )
                .foregroundStyle(FocusFlowTheme.accent.gradient)
                .cornerRadius(4)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
            .frame(height: 180)
            .accessibilityLabel("每日专注时长柱状图")
        }
    }

    private var pomodoroChart: some View {
        chartCard(title: "番茄数量趋势", subtitle: "完成的专注回合") {
            Chart(viewModel.dailyPoints) { point in
                LineMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("番茄数", point.sessions)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(FocusFlowTheme.mint)
                PointMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("番茄数", point.sessions)
                )
                .foregroundStyle(FocusFlowTheme.mint)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
            .frame(height: 160)
            .accessibilityLabel("每日完成番茄折线图")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "分类专注占比", subtitle: "按任务所属清单归类")
            if viewModel.categoryShares.isEmpty {
                smallEmptyState("暂无可统计的分类", systemImage: "square.stack.3d.up")
            } else {
                let total = max(viewModel.categoryShares.reduce(0) { $0 + $1.duration }, 1)
                ForEach(viewModel.categoryShares) { share in
                    let fraction = min(max(share.duration / total, 0), 1)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(share.name, systemImage: "circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FocusFlowTheme.categoryColor(at: share.colorIndex))
                            Spacer()
                            Text("\(Int((fraction * 100).rounded()))% · \(viewModel.durationText(share.duration))")
                                .font(.caption)
                                .foregroundStyle(FocusFlowTheme.secondaryText)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule()
                                    .fill(FocusFlowTheme.categoryColor(at: share.colorIndex))
                                    .frame(width: proxy.size.width * fraction)
                            }
                        }
                        .frame(height: 9)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .surfaceCard(padding: 16)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "专注历史", subtitle: "\(viewModel.filteredRecords.count) 条记录")
            if viewModel.filteredRecords.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "还没有专注记录",
                    message: "完成一次专注后，这里会保存对应任务、起止时间和有效时长。"
                )
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(Array(viewModel.filteredRecords.prefix(100))) { record in
                        StatisticsHistoryRow(
                            record: record,
                            title: viewModel.taskTitle(for: record),
                            duration: viewModel.durationText(record.actualDuration)
                        )
                    }
                }
            }
        }
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, subtitle: subtitle)
            if viewModel.filteredRecords.isEmpty {
                smallEmptyState("完成专注后生成趋势", systemImage: "chart.xyaxis.line")
            } else {
                content()
            }
        }
        .surfaceCard(padding: 16)
    }

    private func smallEmptyState(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(FocusFlowTheme.tertiaryText)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
    }
}

private struct StatisticsHistoryRow: View {
    let record: FocusRecord
    let title: String
    let duration: String

    private var tint: Color {
        switch record.result {
        case .completed: return FocusFlowTheme.mint
        case .stopped: return FocusFlowTheme.amber
        case .interrupted, .cancelled: return FocusFlowTheme.accent
        }
    }

    private var resultText: String {
        switch record.result {
        case .completed: return "完成"
        case .stopped: return "提前结束"
        case .interrupted: return "中断"
        case .cancelled: return "放弃"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(record.startedAt.formatted(.dateTime.month().day().hour().minute()) + " – " + record.endedAt.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
                Text("有效 \(duration) · 中断 \(record.interruptions) 次")
                    .font(.caption2)
                    .foregroundStyle(FocusFlowTheme.tertiaryText)
            }
            Spacer(minLength: 6)
            Text(resultText)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .surfaceCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
