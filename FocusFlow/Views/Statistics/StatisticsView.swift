import Charts
import Foundation
import SwiftUI

/// 数据统计页：整页蓝紫背景 + 白色卡片（累计专注 / 今日专注 / 时长分布 / 时段分布）。
struct StatisticsView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel = StatisticsViewModel()

    @State private var distSegment: DistSegment = .day
    @State private var distAnchor = Date()
    @State private var hourAnchor = Date()
    @State private var isRecordsPresented = false
    @State private var isSettingsPresented = false

    enum DistSegment: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"

        var id: String { rawValue }
    }

    struct DistPoint: Identifiable {
        let label: String
        let minutes: Double

        var id: String { label }
    }

    private var focusRecords: [FocusRecord] {
        viewModel.records.filter { $0.kind == .focus }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(spacing: 14) {
                    totalCard
                    todayCard
                    distributionCard
                    hourCard
                }
                .padding(.horizontal, 15)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
        }
        .background(FocusFlowTheme.statsBackground.ignoresSafeArea())
        .onAppear {
            viewModel.bind(to: container.store)
        }
        .sheet(isPresented: $isRecordsPresented) {
            FocusRecordListView(records: viewModel.records, tasks: viewModel.tasks)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 26) {
            Spacer()
            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("设置")

            Button {
                isRecordsPresented = true
            } label: {
                Image(systemName: "rosette")
            }
            .accessibilityLabel("专注记录")

            ShareLink(item: shareSummary) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享统计")
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(FocusFlowTheme.statsBackground.ignoresSafeArea(edges: .top))
    }

    private var shareSummary: String {
        "我在 FocusFlow 累计专注 \(totalCount) 次，共 \(totalMinutes) 分钟。"
    }

    // MARK: - 累计专注

    private var totalCount: Int {
        focusRecords.filter { $0.result == .completed }.count
    }

    private var totalMinutes: Int {
        Int(focusRecords.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    private var activeDayCount: Int {
        let calendar = Calendar.current
        return Set(focusRecords.map { calendar.startOfDay(for: $0.endedAt) }).count
    }

    private var averageMinutes: Int {
        totalMinutes / max(activeDayCount, 1)
    }

    private var totalCard: some View {
        StatsCard {
            HStack(spacing: 8) {
                Text("累计专注")
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.accentDeep)
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(FocusFlowTheme.accentDeep)
                Spacer()
                Image(systemName: "circle.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .systemGray3))
            }
            HStack(spacing: 0) {
                StatsMetric(title: "次数") {
                    numberText("\(totalCount)")
                }
                StatsMetric(title: "时长") {
                    durationText(minutes: totalMinutes)
                }
                StatsMetric(title: "日均时长") {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        numberText("\(averageMinutes)")
                        unitText("分钟")
                    }
                }
            }
        }
    }

    // MARK: - 今日专注

    private var todayRecords: [FocusRecord] {
        focusRecords.filter { Calendar.current.isDateInToday($0.endedAt) }
    }

    private var todayCard: some View {
        let count = todayRecords.filter { $0.result == .completed }.count
        let minutes = Int(todayRecords.reduce(0) { $0 + $1.actualDuration } / 60)
        let abandoned = todayRecords.filter { $0.result == .cancelled }.count
        return StatsCard {
            HStack {
                Text("今日专注")
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.accentDeep)
                Spacer()
            }
            HStack(spacing: 0) {
                StatsMetric(title: "次数") {
                    numberText("\(count)")
                }
                StatsMetric(title: "时长") {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        numberText("\(minutes)")
                        unitText("分钟")
                    }
                }
                StatsMetric(title: "放弃次数") {
                    numberText("\(abandoned)")
                }
            }
        }
    }

    // MARK: - 专注时长分布

    private var distributionCard: some View {
        StatsCard {
            HStack(spacing: 8) {
                Text("专注时长分布 \(distTitle)")
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.accentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                arrowButton("chevron.left") { shiftDistAnchor(-1) }
                arrowButton("chevron.right") { shiftDistAnchor(1) }
            }

            segmentedPicker

            distChartArea

            HStack {
                Spacer()
                Button {
                    isRecordsPresented = true
                } label: {
                    Text("查看专注记录")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FocusFlowTheme.accentDeep)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(FocusFlowTheme.accentSoft))
                }
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(DistSegment.allCases) { segment in
                segmentButton(segment)
            }
        }
        .overlay(
            Capsule().stroke(FocusFlowTheme.accentSoft, lineWidth: 1.5)
        )
        .clipShape(Capsule())
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity)
    }

    private func segmentButton(_ segment: DistSegment) -> some View {
        let isSelected = distSegment == segment
        return Button {
            distSegment = segment
        } label: {
            Text(segment.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? FocusFlowTheme.accentDeep : Color(uiColor: .systemGray2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? FocusFlowTheme.accentSoft : Color.clear)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var distChartArea: some View {
        let points = distPoints
        if points.allSatisfy({ $0.minutes < 0.5 }) {
            Text("无数据,点击待办上的开始按钮来专注计时吧")
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("时段", point.label),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(FocusFlowTheme.accent)
                .cornerRadius(3)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 200)
        }
    }

    private var distTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch distSegment {
        case .day:
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: distAnchor)
        case .week:
            formatter.dateFormat = "MM-dd"
            let start = startOfWeek(distAnchor)
            return formatter.string(from: start) + " 当周"
        case .month:
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: distAnchor)
        }
    }

    private func shiftDistAnchor(_ direction: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component
        let value: Int
        switch distSegment {
        case .day:
            component = .day
            value = direction
        case .week:
            component = .day
            value = direction * 7
        case .month:
            component = .month
            value = direction
        }
        distAnchor = calendar.date(byAdding: component, value: value, to: distAnchor) ?? distAnchor
    }

    private var distPoints: [DistPoint] {
        switch distSegment {
        case .day:
            return hourlyPoints(records: records(inDayOf: distAnchor))
        case .week:
            return weekdayPoints()
        case .month:
            return monthDayPoints()
        }
    }

    private func records(inDayOf date: Date) -> [FocusRecord] {
        let calendar = Calendar.current
        return focusRecords.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    private func hourlyPoints(records: [FocusRecord]) -> [DistPoint] {
        let calendar = Calendar.current
        var buckets = [Double](repeating: 0, count: 24)
        for record in records {
            let hour = calendar.component(.hour, from: record.startedAt)
            buckets[hour] += record.actualDuration / 60
        }
        return (0..<24).map { DistPoint(label: "\($0)", minutes: buckets[$0]) }
    }

    private func startOfWeek(_ date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday + 5) % 7  // 周一为一周开始
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    private func weekdayPoints() -> [DistPoint] {
        let calendar = Calendar.current
        let start = startOfWeek(distAnchor)
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        var points: [DistPoint] = []
        for index in 0..<7 {
            let day = calendar.date(byAdding: .day, value: index, to: start) ?? start
            let minutes = records(inDayOf: day).reduce(0) { $0 + $1.actualDuration } / 60
            points.append(DistPoint(label: "周\(labels[index])", minutes: minutes))
        }
        return points
    }

    private func monthDayPoints() -> [DistPoint] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: distAnchor),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: distAnchor)) else {
            return []
        }
        var points: [DistPoint] = []
        for index in 0..<range.count {
            let day = calendar.date(byAdding: .day, value: index, to: monthStart) ?? monthStart
            let minutes = records(inDayOf: day).reduce(0) { $0 + $1.actualDuration } / 60
            points.append(DistPoint(label: "\(index + 1)", minutes: minutes))
        }
        return points
    }

    // MARK: - 本月专注时段分布

    private var hourCard: some View {
        StatsCard {
            HStack(spacing: 8) {
                Text("本月专注时段分布 \(hourTitle)")
                    .font(.headline)
                    .foregroundStyle(FocusFlowTheme.accentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                arrowButton("chevron.left") { shiftHourAnchor(-1) }
                arrowButton("chevron.right") { shiftHourAnchor(1) }
            }
            hourChartArea
        }
    }

    private var hourTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: hourAnchor)
    }

    private func shiftHourAnchor(_ direction: Int) {
        hourAnchor = Calendar.current.date(byAdding: .month, value: direction, to: hourAnchor) ?? hourAnchor
    }

    private var monthHourPoints: [DistPoint] {
        let calendar = Calendar.current
        let monthRecords = focusRecords.filter {
            calendar.isDate($0.startedAt, equalTo: hourAnchor, toGranularity: .month)
        }
        return hourlyPoints(records: monthRecords)
    }

    @ViewBuilder
    private var hourChartArea: some View {
        let points = monthHourPoints
        if points.allSatisfy({ $0.minutes < 0.5 }) {
            Text("本月还没有专注数据")
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 150)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("时段", point.label),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(FocusFlowTheme.accent)
                .cornerRadius(3)
                .annotation(position: .top) {
                    if point.minutes >= 1 {
                        Text("\(Int(point.minutes))")
                            .font(.caption2)
                            .foregroundStyle(FocusFlowTheme.accentDeep)
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 170)
        }
    }

    // MARK: - 小组件

    private func arrowButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .systemGray))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    private func numberText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 34, weight: .medium).monospacedDigit())
            .foregroundStyle(FocusFlowTheme.accentDeep)
    }

    private func unitText(_ value: String) -> some View {
        Text(value)
            .font(.footnote)
            .foregroundStyle(FocusFlowTheme.accentDeep)
    }

    private func durationText(minutes: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if minutes >= 60 {
                numberText("\(minutes / 60)")
                unitText("小时")
                numberText("\(minutes % 60)")
                unitText("分钟")
            } else {
                numberText("\(minutes)")
                unitText("分钟")
            }
        }
    }
}

/// 统计页通用白卡片容器。
private struct StatsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
    }
}

/// 三栏数字指标（标签在上，数值在下）。
private struct StatsMetric<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(FocusFlowTheme.accentDeep.opacity(0.85))
            value
        }
        .frame(maxWidth: .infinity)
    }
}
