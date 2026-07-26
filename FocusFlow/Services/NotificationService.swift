import Foundation
import Combine
import UserNotifications

/// 本地通知的唯一入口。所有标识符都带有稳定前缀，避免误删其他通知。
@MainActor
final class NotificationService: ObservableObject {
    enum Category {
        static let timerCompleted = "focusflow.timer.completed"
        static let taskReminder = "focusflow.task.reminder"
    }

    enum Identifier {
        static let timerPrefix = "focusflow.timer."
        static let taskPrefix = "focusflow.task."
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func scheduleTimerCompletion(
        sessionID: UUID,
        fireDate: Date,
        title: String,
        body: String,
        soundEnabled: Bool
    ) async throws {
        let identifier = Identifier.timerPrefix + sessionID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Category.timerCompleted
        content.threadIdentifier = "focusflow.timer"
        content.userInfo = ["sessionID": sessionID.uuidString]
        content.sound = soundEnabled ? .default : nil

        let interval = max(fireDate.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelTimerCompletion(sessionID: UUID) {
        let identifier = Identifier.timerPrefix + sessionID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func scheduleTaskReminder(
        taskID: UUID,
        fireDate: Date,
        title: String,
        body: String = "该开始处理这项任务了",
        soundEnabled: Bool = true
    ) async throws {
        let identifier = Identifier.taskPrefix + taskID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = Category.taskReminder
        content.threadIdentifier = "focusflow.tasks"
        content.userInfo = ["taskID": taskID.uuidString]
        content.sound = soundEnabled ? .default : nil

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelTaskReminder(taskID: UUID) {
        let identifier = Identifier.taskPrefix + taskID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func removeAllFocusFlowNotifications() {
        center.getPendingNotificationRequests { [center] requests in
            let identifiers = requests.map(\.identifier).filter {
                $0.hasPrefix(Identifier.timerPrefix) || $0.hasPrefix(Identifier.taskPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    static func registerCategories(on center: UNUserNotificationCenter = .current()) {
        let timerCategory = UNNotificationCategory(
            identifier: Category.timerCompleted,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: Category.taskReminder,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([timerCategory, taskCategory])
    }
}
