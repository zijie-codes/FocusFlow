import SwiftUI

@main
@MainActor
struct FocusFlowApp: App {
    @UIApplicationDelegateAdaptor(FocusFlowAppDelegate.self) private var appDelegate
    @StateObject private var container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .environmentObject(container.timer)
                .environmentObject(container.whiteNoise)
                .preferredColorScheme(container.appearanceScheme)
                .onAppear {
                    NotificationService.registerCategories()
                    container.requestNotificationPermissionIfNeeded()
                    container.applicationDidBecomeActive()
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        container.applicationDidBecomeActive()
                    case .inactive, .background:
                        container.applicationWillResignActive()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
