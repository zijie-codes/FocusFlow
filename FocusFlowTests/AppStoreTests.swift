import Foundation
import XCTest
@testable import FocusFlow

@MainActor
final class AppStoreTests: XCTestCase {
    func testMutationsPersistAndReloadAsOneSnapshot() throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let list = TaskList(id: UUID(), name: "Work")
        let task = TaskItem(
            id: UUID(),
            listID: list.id,
            title: "Ship FocusFlow",
            note: "Use an atomic file write",
            estimatedPomodoros: 3,
            tags: ["iOS"]
        )

        let store = AppStore(fileURL: fileURL, autoload: false)
        store.upsertList(list)
        store.upsertTask(task)
        store.setTaskCompletion(task.id, completed: true, at: fixedDate)

        let reloaded = AppStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.lists.count, 1)
        XCTAssertEqual(reloaded.lists.first?.id, list.id)
        XCTAssertEqual(reloaded.lists.first?.name, list.name)
        XCTAssertEqual(reloaded.tasks.count, 1)
        XCTAssertEqual(reloaded.tasks[0].note, "Use an atomic file write")
        XCTAssertEqual(reloaded.tasks[0].completedAt, fixedDate)
        XCTAssertTrue(reloaded.tasks[0].isCompleted)
        XCTAssertEqual(reloaded.tasks[0].estimatedPomodoros, 3)
    }

    func testDeleteListLeavesTasksInInboxAndMoveMaintainsSortOrder() {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = AppStore(fileURL: fileURL, automaticallySaves: false, autoload: false)
        let list = TaskList(name: "Personal")
        let first = TaskItem(listID: list.id, title: "First", sortOrder: 0)
        let second = TaskItem(listID: list.id, title: "Second", sortOrder: 1)
        let third = TaskItem(listID: list.id, title: "Third", sortOrder: 2)
        store.upsertList(list)
        store.upsertTask(first)
        store.upsertTask(second)
        store.upsertTask(third)

        store.moveTasks(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(store.tasks.map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(store.tasks.map(\.sortOrder), [0, 1, 2])

        store.deleteList(id: list.id)
        XCTAssertTrue(store.lists.isEmpty)
        XCTAssertTrue(store.tasks.allSatisfy { $0.listID == nil })
    }

    func testCompletingRepeatingTaskCreatesOnlyOneFutureOccurrence() {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let due = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9))!
        let completion = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 12))!
        let task = TaskItem(title: "Daily review", dueDate: due, repeatRule: .daily)
        let store = AppStore(fileURL: fileURL, automaticallySaves: false, autoload: false)
        store.upsertTask(task)

        store.setTaskCompletion(task.id, completed: true, at: completion)
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertEqual(store.tasks[1].dueDate, calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 9)))

        store.setTaskCompletion(task.id, completed: true, at: completion)
        XCTAssertEqual(store.tasks.count, 2)
    }

    private var fixedDate: Date {
        Date(timeIntervalSinceReferenceDate: 762_000_000)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
