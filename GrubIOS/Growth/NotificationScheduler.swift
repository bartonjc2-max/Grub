import Foundation
import UserNotifications

struct ScheduledNotice: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

/// Schedules the re-engagement notices (Grub hungry / lonely / expedition ready).
/// The decision (`plan`) is a pure static function — easy to unit-test.
/// The side-effect (`apply`, `requestPermission`) goes through the LocalNotifying seam.
final class NotificationScheduler {
    private let center: LocalNotifying
    init(center: LocalNotifying) { self.center = center }

    /// All notice ids we manage. Used to clear stale ones before applying a new plan.
    static let allIds = ["grub_hungry", "grub_lonely", "expedition_ready"]

    /// Pure decision: which notices to schedule given current pet state.
    /// Computes when hunger/happiness will fall below `lowThreshold` at the given
    /// decay rates, and when an expedition completes. No side effects.
    static func plan(hunger: Double,
                     happiness: Double,
                     hungerPerHour: Double,
                     happinessPerHour: Double,
                     expeditionEnd: Date?,
                     from: Date,
                     lowThreshold: Double = 25) -> [ScheduledNotice] {
        var out: [ScheduledNotice] = []
        if hungerPerHour > 0, hunger > lowThreshold {
            let hours = (hunger - lowThreshold) / hungerPerHour
            out.append(.init(id: "grub_hungry",
                             title: "GRUB",
                             body: "Grub is getting hungry…",
                             fireDate: from.addingTimeInterval(hours * 3600)))
        }
        if happinessPerHour > 0, happiness > lowThreshold {
            let hours = (happiness - lowThreshold) / happinessPerHour
            out.append(.init(id: "grub_lonely",
                             title: "GRUB",
                             body: "Grub misses you.",
                             fireDate: from.addingTimeInterval(hours * 3600)))
        }
        if let end = expeditionEnd, end > from {
            out.append(.init(id: "expedition_ready",
                             title: "GRUB",
                             body: "Grub's expedition is done!",
                             fireDate: end))
        }
        return out
    }

    /// Cancels prior notices and schedules the new plan via the seam.
    func apply(_ notices: [ScheduledNotice]) {
        center.removePending(identifiers: Self.allIds)
        for n in notices {
            let content = UNMutableNotificationContent()
            content.title = n.title
            content.body = n.body
            content.sound = .default
            let interval = max(1, n.fireDate.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.addRequest(UNNotificationRequest(identifier: n.id, content: content, trigger: trigger))
        }
    }

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        center.requestAuth(completion)
    }
}
