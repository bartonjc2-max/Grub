import Foundation

protocol AnalyticsService {
    func log(_ event: AnalyticsEvent)
}

/// Default impl until a concrete SDK (O-4) is chosen. Prints in DEBUG, no-ops in release.
final class ConsoleAnalytics: AnalyticsService {
    func log(_ event: AnalyticsEvent) {
        #if DEBUG
        print("📊 \(event.name) \(event.properties)")
        #endif
    }
}

/// For tests and previews — records event names without side effects.
final class NullAnalytics: AnalyticsService {
    private(set) var logged: [String] = []
    func log(_ event: AnalyticsEvent) { logged.append(event.name) }
}
