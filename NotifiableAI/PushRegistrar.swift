import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let pushTokenAvailable = Notification.Name("NotifiableAI.pushTokenAvailable")
    static let pushRegistrationFailed = Notification.Name("NotifiableAI.pushRegistrationFailed")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else {
                    NotificationCenter.default.post(
                        name: .pushRegistrationFailed,
                        object: nil,
                        userInfo: ["error": "User denied notification permission"]
                    )
                    return
                }
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                NotificationCenter.default.post(
                    name: .pushRegistrationFailed,
                    object: nil,
                    userInfo: ["error": String(describing: error)]
                )
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = PushTokenFormatter.hex(deviceToken)
        NotificationCenter.default.post(
            name: .pushTokenAvailable,
            object: nil,
            userInfo: ["token": token]
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: .pushRegistrationFailed,
            object: nil,
            userInfo: ["error": String(describing: error)]
        )
    }
}

enum PushTokenFormatter {
    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
