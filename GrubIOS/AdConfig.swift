import Foundation

/// Central configuration for all AdMob ad unit IDs and behavior settings.
struct AdConfig {
    // MARK: - App ID (also in Info.plist GADApplicationIdentifier)
    static let appId = "ca-app-pub-2693240777289599~6001078046"

    // MARK: - Ad Unit IDs
    static let interstitialAdUnitId = "ca-app-pub-2693240777289599/7173359804"
    static let rewardedAdUnitId = "ca-app-pub-2693240777289599/9678400920"

    // MARK: - Test Ad Unit IDs (use during development)
    static let testInterstitialId = "ca-app-pub-3940256099942544/4411468910"
    static let testRewardedId = "ca-app-pub-3940256099942544/1712485313"

    // MARK: - Behavior
    /// Minimum seconds between interstitial ads (5 minutes)
    static let interstitialCooldownSeconds: TimeInterval = 300

    /// Whether to use test ad unit IDs
    #if DEBUG
    static let useTestAds = true
    #else
    static let useTestAds = false
    #endif

    /// Resolved interstitial ID based on environment
    static var activeInterstitialId: String {
        useTestAds ? testInterstitialId : interstitialAdUnitId
    }

    /// Resolved rewarded ID based on environment
    static var activeRewardedId: String {
        useTestAds ? testRewardedId : rewardedAdUnitId
    }
}

// MARK: - Reward Types
/// All the rewarded ad placements in the game
enum AdRewardType: String {
    case skipExpeditionTimer
    case skipForageCooldown
    case reviveGrub
    case doubleMinigameXP
    case doubleForageLoot
    case bonusExpeditionLoot
}
