import Foundation

/// Protocol abstracting all ad operations so GameState never imports GoogleMobileAds.
/// Mock this protocol for testing.
protocol AdService: AnyObject {
    /// Whether an interstitial ad is loaded and ready to show
    var isInterstitialReady: Bool { get }

    /// Whether a rewarded ad is loaded and ready to show
    var isRewardedReady: Bool { get }

    /// Initialize the ad SDK — call once at app launch
    func configure()

    /// Show an interstitial ad if one is loaded and cooldown has elapsed.
    /// Returns true if an ad was shown.
    @discardableResult
    func showInterstitialIfReady() -> Bool

    /// Show a rewarded ad. Calls the completion handler with `true` if the user
    /// earned the reward, `false` if they dismissed early or ad failed.
    func showRewarded(for rewardType: AdRewardType, completion: @escaping (Bool) -> Void)

    /// Preload the next interstitial ad
    func preloadInterstitial()

    /// Preload the next rewarded ad
    func preloadRewarded()
}
