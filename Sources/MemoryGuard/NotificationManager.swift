import AppKit
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func setup() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { self.registerCategories() }
        }
    }

    private func registerCategories() {
        let purge = UNNotificationAction(identifier: "PURGE", title: "🧹 캐시 정리", options: .foreground)
        let ignore = UNNotificationAction(identifier: "IGNORE", title: "🚀 무시", options: [])
        let reply = UNTextInputNotificationAction(
            identifier: "REPLY",
            title: "💬 앱 종료 요청",
            options: [],
            textInputButtonTitle: "전송",
            textInputPlaceholder: "예: 크롬 꺼줘, 파이어폭스 닫아줘"
        )

        let warningCategory = UNNotificationCategory(
            identifier: "MEMORY_WARNING",
            actions: [purge, ignore, reply],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        let criticalCategory = UNNotificationCategory(
            identifier: "MEMORY_CRITICAL",
            actions: [purge, reply],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([warningCategory, criticalCategory])
    }

    func sendWarning(appName: String, usedGB: Double, level: AlertLevel) {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch level {
        case .warning:
            content.title = "⚠️ 메모리 주의"
            content.body = "'\(appName)' 실행 후 \(String(format: "%.1f", usedGB))GB 사용 중. 여유 메모리가 줄어들고 있어요."
            content.categoryIdentifier = "MEMORY_WARNING"
        case .critical:
            content.title = "🚨 메모리 위험!"
            content.body = "'\(appName)' 실행 후 \(String(format: "%.1f", usedGB))GB! 시스템이 느려질 수 있습니다. 지금 정리할까요?"
            content.categoryIdentifier = "MEMORY_CRITICAL"
        case .normal:
            return
        }

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "PURGE":
            runPurge()
        case "REPLY":
            if let text = (response as? UNTextInputNotificationResponse)?.userText {
                handleCommand(text)
            }
        default:
            break
        }
        completionHandler()
    }

    func runPurge() {
        let task = Process()
        task.launchPath = "/usr/sbin/purge"
        try? task.run()
    }

    private func handleCommand(_ input: String) {
        let command = input.lowercased()
        for entry in TerminationSettings.shared.entries where command.contains(entry.keyword) {
            NSWorkspace.shared.runningApplications
                .first { $0.localizedName == entry.appName }?
                .terminate()
            return
        }
    }
}