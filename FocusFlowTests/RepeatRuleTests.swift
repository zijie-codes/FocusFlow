import Foundation
import XCTest
@testable import FocusFlow

final class RepeatRuleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDailyAndWeekdayRulesUseCalendarDates() {
        let friday = date(2026, 7, 24, 9, 15)
        XCTAssertEqual(RepeatRule.daily.nextDate(after: friday, calendar: calendar), date(2026, 7, 25, 9, 15))
        XCTAssertEqual(RepeatRule.weekdays.nextDate(after: friday, calendar: calendar), date(2026, 7, 27, 9, 15))
    }

    func testWeeklyRuleFindsNextSelectedWeekday() {
        let monday = date(2026, 7, 20, 9, 0)
        let rule = RepeatRule.weekly(weekdays: [3, 5]) // Tuesday and Thursday

        XCTAssertEqual(rule.nextDate(after: monday, calendar: calendar), date(2026, 7, 21, 9, 0))
        XCTAssertTrue(rule.occurs(on: date(2026, 7, 23, 18, 0), startingAt: monday, calendar: calendar))
        XCTAssertFalse(rule.occurs(on: date(2026, 7, 22, 18, 0), startingAt: monday, calendar: calendar))
    }

    func testMonthlyRuleClampsToLastDayOfShortMonth() {
        let january = date(2028, 1, 31, 8, 30)
        XCTAssertEqual(
            RepeatRule.monthly(day: 31).nextDate(after: january, calendar: calendar),
            date(2028, 2, 29, 8, 30)
        )
    }

    func testCustomIntervalSupportsMultipleUnits() {
        let start = date(2026, 7, 1, 10, 0)
        XCTAssertEqual(
            RepeatRule.custom(interval: 3, unit: .day).nextDate(after: start, calendar: calendar),
            date(2026, 7, 4, 10, 0)
        )
        XCTAssertEqual(
            RepeatRule.custom(interval: 2, unit: .week).nextDate(after: start, calendar: calendar),
            date(2026, 7, 15, 10, 0)
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
