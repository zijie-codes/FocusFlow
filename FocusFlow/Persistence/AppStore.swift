import Combine
import Foundation

public struct AppData: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var tasks: [TaskItem]
    public var lists: [TaskList]
    public var records: [FocusRecord]
    public var settings: AppSettings
    public var activeTimerSession: ActiveTimerSession?

    public init(
        schemaVersion: Int = AppData.currentSchemaVersion,
        tasks: [TaskItem] = [],
        lists: [TaskList] = [],
        records: [FocusRecord] = [],
        settings: AppSettings = .default,
        activeTimerSession: ActiveTimerSession? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.lists = lists
        self.records = records
        self.settings = settings
        self.activeTimerSession = activeTimerSession
    }

    public static let empty = AppData()

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, tasks, lists, records, settings, activeTimerSession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        tasks = try container.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        lists = try container.decodeIfPresent([TaskList].self, forKey: .lists) ?? []
        records = try container.decodeIfPresent([FocusRecord].self, forKey: .records) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? .default
        activeTimerSession = try container.decodeIfPresent(
            ActiveTimerSession.self,
            forKey: .activeTimerSession
        )
    }
}

public enum AppStoreError: LocalizedError, Equatable {
    case unsupportedSchema(found: Int, supported: Int)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(found, supported):
            return "数据版本 \(found) 高于当前支持的版本 \(supported)。"
        case let .persistenceFailed(message):
            return "无法保存 FocusFlow 本地数据：\(message)"
        }
    }
}

@MainActor
public final class AppStore: ObservableObject {
    @Published public private(set) var data: AppData
    @Published public private(set) var persistenceError: AppStoreError?

    public let fileURL: URL
    public var automaticallySaves: Bool

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public var tasks: [TaskItem] { data.tasks }
    public var lists: [TaskList] { data.lists }
    public var taskLists: [TaskList] { data.lists }
    public var focusRecords: [FocusRecord] { data.records }
    public var records: [FocusRecord] { data.records }
    public var settings: AppSettings { data.settings }
    public var activeTimerSession: ActiveTimerSession? { data.activeTimerSession }

    public init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        automaticallySaves: Bool = true,
        autoload: Bool = true
    ) {
        self.fileManager = fileManager
        self.automaticallySaves = automaticallySaves
        self.fileURL = fileURL ?? Self.defaultFileURL(using: fileManager)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.data = .empty
        self.persistenceError = nil

        guard autoload, fileManager.fileExists(atPath: self.fileURL.path) else { return }
        do {
            let loaded = try Self.read(from: self.fileURL, decoder: decoder)
            guard loaded.schemaVersion <= AppData.currentSchemaVersion else {
                throw AppStoreError.unsupportedSchema(
                    found: loaded.schemaVersion,
                    supported: AppData.currentSchemaVersion
                )
            }
            self.data = loaded
        } catch let error as AppStoreError {
            self.persistenceError = error
        } catch {
            self.persistenceError = .persistenceFailed(error.localizedDescription)
        }
    }

    public func reload() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            data = .empty
            persistenceError = nil
            return
        }
        let loaded = try Self.read(from: fileURL, decoder: decoder)
        guard loaded.schemaVersion <= AppData.currentSchemaVersion else {
            throw AppStoreError.unsupportedSchema(
                found: loaded.schemaVersion,
                supported: AppData.currentSchemaVersion
            )
        }
        data = loaded
        persistenceError = nil
    }

    public func save() throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: [.atomic])
            persistenceError = nil
        } catch {
            let storeError = AppStoreError.persistenceFailed(error.localizedDescription)
            persistenceError = storeError
            throw storeError
        }
    }

    public func replaceData(_ newData: AppData, save: Bool = true) throws {
        guard newData.schemaVersion <= AppData.currentSchemaVersion else {
            throw AppStoreError.unsupportedSchema(
                found: newData.schemaVersion,
                supported: AppData.currentSchemaVersion
            )
        }
        data = newData
        if save { try self.save() }
    }

    public func upsertTask(_ task: TaskItem) {
        mutate { data in
            if let index = data.tasks.firstIndex(where: { $0.id == task.id }) {
                data.tasks[index] = task
            } else {
                data.tasks.append(task)
            }
        }
    }

    public func setTaskCompletion(_ id: UUID, completed: Bool, at date: Date = Date()) {
        mutate { data in
            guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }
            let wasCompleted = data.tasks[index].isCompleted
            data.tasks[index].setCompleted(completed, at: date)

            // 仅在“未完成 -> 完成”的瞬间生成下一次，避免反复点击产生重复任务。
            guard completed, !wasCompleted,
                  let rule = data.tasks[index].repeatRule else { return }
            let finishedTask = data.tasks[index]
            let anchor = finishedTask.dueDate ?? date
            guard var nextDueDate = rule.nextDate(after: anchor) else { return }
            var safetyCounter = 0
            while nextDueDate <= date, safetyCounter < 366 {
                guard let following = rule.nextDate(after: nextDueDate) else { return }
                nextDueDate = following
                safetyCounter += 1
            }
            guard nextDueDate > date else { return }

            var nextTask = finishedTask
            nextTask.id = UUID()
            nextTask.isCompleted = false
            nextTask.completedAt = nil
            nextTask.completedPomodoros = 0
            nextTask.createdAt = date
            nextTask.updatedAt = date
            nextTask.dueDate = nextDueDate
            if let reminder = finishedTask.reminderDate,
               let due = finishedTask.dueDate {
                nextTask.reminderDate = nextDueDate.addingTimeInterval(reminder.timeIntervalSince(due))
            }
            nextTask.checklist = finishedTask.checklist.map { item in
                var reset = item
                reset.isCompleted = false
                reset.completedAt = nil
                return reset
            }
            nextTask.sortOrder = (data.tasks.map(\.sortOrder).max() ?? 0) + 1
            data.tasks.append(nextTask)
        }
    }

    public func deferTaskToTomorrow(_ id: UUID, calendar: Calendar = .current, now: Date = Date()) {
        mutate { data in
            guard let index = data.tasks.firstIndex(where: { $0.id == id }),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }
            let source = data.tasks[index].dueDate ?? now
            let time = calendar.dateComponents([.hour, .minute, .second], from: source)
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = time.hour ?? 9
            components.minute = time.minute ?? 0
            components.second = time.second ?? 0
            data.tasks[index].dueDate = calendar.date(from: components) ?? tomorrow
            data.tasks[index].updatedAt = now
        }
    }

    public func deleteTask(id: UUID) {
        mutate { data in
            data.tasks.removeAll { $0.id == id }
        }
    }

    public func moveTasks(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        mutate { data in
            let validOffsets = offsets.filter { data.tasks.indices.contains($0) }.sorted()
            guard !validOffsets.isEmpty else { return }

            let moved = validOffsets.map { data.tasks[$0] }
            for index in validOffsets.reversed() {
                data.tasks.remove(at: index)
            }
            let removedBeforeDestination = validOffsets.filter { $0 < destination }.count
            let adjustedDestination = min(
                max(0, destination - removedBeforeDestination),
                data.tasks.count
            )
            data.tasks.insert(contentsOf: moved, at: adjustedDestination)
            for index in data.tasks.indices {
                data.tasks[index].sortOrder = index
            }
        }
    }

    public func upsertList(_ list: TaskList) {
        mutate { data in
            if let index = data.lists.firstIndex(where: { $0.id == list.id }) {
                data.lists[index] = list
            } else {
                data.lists.append(list)
            }
        }
    }

    /// Deleting a list keeps its tasks and moves them to the unfiled inbox.
    public func deleteList(id: UUID) {
        mutate { data in
            data.lists.removeAll { $0.id == id }
            for index in data.tasks.indices where data.tasks[index].listID == id {
                data.tasks[index].listID = nil
                data.tasks[index].updatedAt = Date()
            }
        }
    }

    public func appendFocusRecord(_ record: FocusRecord) {
        mutate { $0.records.append(record) }
    }

    public func deleteFocusRecord(id: UUID) {
        mutate { $0.records.removeAll { $0.id == id } }
    }

    public func updateSettings(_ settings: AppSettings) {
        mutate { $0.settings = settings }
    }

    public func setActiveTimerSession(_ session: ActiveTimerSession?) {
        mutate { $0.activeTimerSession = session }
    }

    public func clearPersistenceError() {
        persistenceError = nil
    }

    public static func defaultFileURL(using fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("FocusFlow", isDirectory: true)
            .appendingPathComponent("focusflow.json", isDirectory: false)
    }

    private func mutate(_ mutation: (inout AppData) -> Void) {
        var next = data
        mutation(&next)
        data = next
        guard automaticallySaves else { return }
        do {
            try save()
        } catch {
            // The in-memory mutation is intentionally retained. The published
            // error lets the UI offer a retry without losing user input.
        }
    }

    private static func read(from url: URL, decoder: JSONDecoder) throws -> AppData {
        do {
            return try decoder.decode(AppData.self, from: Data(contentsOf: url))
        } catch let error as AppStoreError {
            throw error
        } catch {
            throw AppStoreError.persistenceFailed(error.localizedDescription)
        }
    }
}
