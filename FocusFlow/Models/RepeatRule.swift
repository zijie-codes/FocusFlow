import Foundation

public enum RepeatIntervalUnit: String, Codable, CaseIterable, Sendable {
    case day
    case week
    case month

    fileprivate var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

/// A calendar repeat rule. Weekday values use `Calendar`'s convention: 1 is
/// Sunday and 7 is Saturday.
public enum RepeatRule: Codable, Hashable, Sendable {
    case daily
    case weekdays
    case weekly(weekdays: Set<Int>)
    case monthly(day: Int)
    case custom(interval: Int, unit: RepeatIntervalUnit)

    public static func weekly(weekday: Int) -> RepeatRule {
        .weekly(weekdays: [normalizedWeekday(weekday)])
    }

    public static func every(_ interval: Int, _ unit: RepeatIntervalUnit) -> RepeatRule {
        .custom(interval: max(1, interval), unit: unit)
    }

    /// Returns the first occurrence strictly after `date`, retaining the time
    /// of day and calendar/time-zone supplied by the caller.
    public func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)

        case .weekdays:
            return nextDay(after: date, calendar: calendar) { weekday in
                (2...6).contains(weekday)
            }

        case let .weekly(weekdays):
            let normalized = Set(weekdays.map(Self.normalizedWeekday))
            let accepted = normalized.isEmpty
                ? Set([calendar.component(.weekday, from: date)])
                : normalized
            return nextDay(after: date, calendar: calendar) { accepted.contains($0) }

        case let .monthly(day):
            return nextMonthlyDate(after: date, requestedDay: day, calendar: calendar)

        case let .custom(interval, unit):
            return calendar.date(
                byAdding: unit.calendarComponent,
                value: max(1, interval),
                to: date
            )
        }
    }

    /// Tests whether `date` is an occurrence on or after `anchor`.
    public func occurs(
        on date: Date,
        startingAt anchor: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let candidateDay = calendar.startOfDay(for: date)
        let anchorDay = calendar.startOfDay(for: anchor)
        guard candidateDay >= anchorDay else { return false }

        switch self {
        case .daily:
            return true

        case .weekdays:
            return (2...6).contains(calendar.component(.weekday, from: candidateDay))

        case let .weekly(weekdays):
            let normalized = Set(weekdays.map(Self.normalizedWeekday))
            let accepted = normalized.isEmpty
                ? Set([calendar.component(.weekday, from: anchorDay)])
                : normalized
            return accepted.contains(calendar.component(.weekday, from: candidateDay))

        case let .monthly(day):
            guard let range = calendar.range(of: .day, in: .month, for: candidateDay) else {
                return false
            }
            let expected = min(max(1, day), range.count)
            return calendar.component(.day, from: candidateDay) == expected

        case let .custom(interval, unit):
            let step = max(1, interval)
            let component = unit.calendarComponent
            guard let distance = calendar.dateComponents(
                [component],
                from: anchorDay,
                to: candidateDay
            ).value(for: component), distance >= 0 else {
                return false
            }
            return distance.isMultiple(of: step)
        }
    }

    private static func normalizedWeekday(_ weekday: Int) -> Int {
        ((weekday - 1) % 7 + 7) % 7 + 1
    }

    private func nextDay(
        after date: Date,
        calendar: Calendar,
        predicate: (Int) -> Bool
    ) -> Date? {
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else {
                return nil
            }
            if predicate(calendar.component(.weekday, from: candidate)) {
                return candidate
            }
        }
        return nil
    }

    private func nextMonthlyDate(
        after date: Date,
        requestedDay: Int,
        calendar: Calendar
    ) -> Date? {
        let safeDay = max(1, requestedDay)
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)

        for monthOffset in 1...24 {
            guard let month = calendar.date(byAdding: .month, value: monthOffset, to: date),
                  let dayRange = calendar.range(of: .day, in: .month, for: month) else {
                continue
            }

            var components = calendar.dateComponents([.era, .year, .month], from: month)
            components.day = min(safeDay, dayRange.count)
            components.hour = time.hour
            components.minute = time.minute
            components.second = time.second
            components.nanosecond = time.nanosecond
            if let candidate = calendar.date(from: components), candidate > date {
                return candidate
            }
        }
        return nil
    }
}
