import Foundation

enum RatingMoment { case positive, negative }

/// Gates SKStoreReviewController behind positive-moment + cooldown rules (spec §10 Phase 1).
/// Decision logic is pure + testable; the actual review request is injected as a closure.
final class RatingPrompt {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let request: () -> Void
    private let lastKey = "rating_last_request"
    private let cooldown: TimeInterval = 60 * 60 * 24 * 90   // 90 days

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         request: @escaping () -> Void) {
        self.defaults = defaults
        self.now = now
        self.request = request
    }

    func consider(moment: RatingMoment) {
        guard moment == .positive else { return }
        if let last = defaults.object(forKey: lastKey) as? Date,
           now().timeIntervalSince(last) < cooldown {
            return
        }
        defaults.set(now(), forKey: lastKey)
        request()
    }
}
