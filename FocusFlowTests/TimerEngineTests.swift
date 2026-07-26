import Foundation
import XCTest
@testable import FocusFlow

@MainActor
final class TimerEngineTests: XCTestCase {
    func testCountdownUsesDatesAndExcludesPausedTime() throws {
        let start = date(2026, 7, 26, 9, 0, 0)
        let engine = TimerEngine(automaticallyTicks: false, now: { start })

        _ = try engine.startCountdown(duration: 60, at: start)
        engine.tick(at: start.addingTimeInterval(30))
        XCTAssertEqual(engine.elapsed, 30, accuracy: 0.001)
        XCTAssertEqual(engine.remaining ?? -1, 30, accuracy: 0.001)

        try engine.pause(at: start.addingTimeInterval(30))
        XCTAssertEqual(engine.session?.interruptionCount, 1)
        engine.tick(at: start.addingTimeInterval(50))
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.elapsed, 30, accuracy: 0.001)
        XCTAssertEqual(engine.remaining ?? -1, 30, accuracy: 0.001)

        try engine.resume(at: start.addingTimeInterval(50))
        engine.tick(at: start.addingTimeInterval(79))
        XCTAssertEqual(engine.phase, .running)
        XCTAssertEqual(engine.elapsed, 59, accuracy: 0.001)
        XCTAssertEqual(engine.remaining ?? -1, 1, accuracy: 0.001)

        engine.tick(at: start.addingTimeInterval(80))
        XCTAssertEqual(engine.phase, .expired)
        XCTAssertEqual(engine.remaining ?? -1, 0, accuracy: 0.001)

        let record = try engine.stop(at: start.addingTimeInterval(120))
        XCTAssertEqual(record.result, .completed)
        XCTAssertEqual(record.actualDuration, 60, accuracy: 0.001)
        XCTAssertEqual(record.interruptions, 1)
        XCTAssertFalse(engine.hasActiveSession)
    }

    func testCountUpCrossesMidnightWithoutDrift() throws {
        let start = date(2026, 12, 31, 23, 59, 30)
        let engine = TimerEngine(automaticallyTicks: false, now: { start })

        _ = try engine.startCountUp(at: start)
        engine.tick(at: date(2027, 1, 1, 0, 1, 0))

        XCTAssertEqual(engine.phase, .running)
        XCTAssertNil(engine.remaining)
        XCTAssertEqual(engine.elapsed, 90, accuracy: 0.001)
    }

    func testRestoresExpiredCountdownAndRejectsDuplicateStart() throws {
        let start = date(2026, 7, 26, 9, 0, 0)
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = AppStore(fileURL: fileURL, automaticallySaves: false, autoload: false)
        store.setActiveTimerSession(
            ActiveTimerSession(
                mode: .countdown,
                startedAt: start,
                plannedDuration: 60,
                scheduledEndAt: start.addingTimeInterval(60)
            )
        )

        let engine = TimerEngine(
            store: store,
            automaticallyTicks: false,
            now: { start.addingTimeInterval(61) }
        )

        XCTAssertEqual(engine.phase, .expired)
        XCTAssertTrue(engine.hasExpired())
        XCTAssertThrowsError(try engine.startCountdown(duration: 25 * 60)) { error in
            XCTAssertEqual(error as? TimerEngineError, .sessionAlreadyActive)
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
