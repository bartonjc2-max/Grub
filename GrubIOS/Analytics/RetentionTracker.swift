import Foundation

struct OpenInfo { let isFirstOpen: Bool; let daysSinceFirstOpen: Int }

/// Derives D1/D7 retention from first-open + each open (spec §9.1 — retention is
/// derived, not bespoke D1/D7 events). Clock is injected for testability.
final class RetentionTracker {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let firstKey = "retention_first_open"
    private let lastKey = "retention_last_open"

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    @discardableResult
    func registerOpen() -> OpenInfo {
        let current = now()
        let first: Date
        let isFirst: Bool
        if let stored = defaults.object(forKey: firstKey) as? Date {
            first = stored
            isFirst = false
        } else {
            first = current
            isFirst = true
            defaults.set(current, forKey: firstKey)
        }
        defaults.set(current, forKey: lastKey)
        let days = Calendar.current.dateComponents([.day], from: first, to: current).day ?? 0
        return OpenInfo(isFirstOpen: isFirst, daysSinceFirstOpen: max(0, days))
    }
}
