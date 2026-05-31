import UserNotifications

/// Thin protocol wrapping the subset of UNUserNotificationCenter we use,
/// so NotificationScheduler is testable without the real center.
/// Method names are deliberately distinct from UNUserNotificationCenter's
/// to avoid overload ambiguity.
protocol LocalNotifying {
    func addRequest(_ request: UNNotificationRequest)
    func removePending(identifiers: [String])
    func requestAuth(_ completion: @escaping (Bool) -> Void)
}

extension UNUserNotificationCenter: LocalNotifying {
    func addRequest(_ request: UNNotificationRequest) {
        self.add(request, withCompletionHandler: nil)
    }
    func removePending(identifiers: [String]) {
        self.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func requestAuth(_ completion: @escaping (Bool) -> Void) {
        self.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }
}
