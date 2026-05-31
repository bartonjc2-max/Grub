import Foundation

/// Closed taxonomy of analytics events (spec §9.1). Add cases here, never ad-hoc strings.
/// Descent events (descent_start/floor_cleared/extract/death) and share_card are
/// intentionally omitted until Phase 2.
enum AnalyticsEvent {
    case appOpen(isFirstOpen: Bool)
    case homeAction(type: String)                  // feed/heal/craft/play/forage
    case adShown(placement: String, optedIn: Bool, completed: Bool)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .homeAction: return "home_action"
        case .adShown: return "ad_shown"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appOpen(let first):
            return ["is_first_open": first]
        case .homeAction(let type):
            return ["type": type]
        case .adShown(let p, let o, let c):
            return ["placement": p, "opted_in": o, "completed": c]
        }
    }
}
