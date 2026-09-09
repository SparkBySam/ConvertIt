import Foundation
import UserNotifications

enum BatchNotifier {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyBatchComplete(task: String, succeeded: Int, failed: Int) {
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "ConvertIt"
        if failed > 0 {
            content.body = "\(task): \(succeeded) succeeded, \(failed) failed."
        } else {
            content.body = "\(task): \(succeeded) file\(succeeded == 1 ? "" : "s") completed."
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
