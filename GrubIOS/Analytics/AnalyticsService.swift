import Foundation
import os.log

protocol AnalyticsService {
    func log(_ event: AnalyticsEvent)
}

/// Default impl until a concrete SDK (O-4) is chosen. In DEBUG, writes through
/// os_log so events appear in `log stream` and Console.app (where `print()` does not).
/// In release, no-op.
final class ConsoleAnalytics: AnalyticsService {
    private let logger = OSLog(subsystem: "com.jessedev.GrubIOS", category: "Analytics")
    func log(_ event: AnalyticsEvent) {
        #if DEBUG
        os_log("📊 %{public}@ %{public}@", log: logger, type: .default,
               event.name, String(describing: event.properties))
        #endif
    }
}

/// For tests and previews — records event names without side effects.
final class NullAnalytics: AnalyticsService {
    private(set) var logged: [String] = []
    func log(_ event: AnalyticsEvent) { logged.append(event.name) }
}
