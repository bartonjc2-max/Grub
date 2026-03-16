import UIKit
import GoogleMobileAds

/// Singleton ad manager implementing AdService.
/// Handles preloading, frequency capping, and reward callbacks.
final class AdManager: NSObject, AdService {
    static let shared = AdManager()

    // MARK: - State
    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    private var lastInterstitialTime: Date?
    private var rewardCompletion: ((Bool) -> Void)?
    private var pendingRewardType: AdRewardType?

    var isInterstitialReady: Bool { interstitialAd != nil }
    var isRewardedReady: Bool { rewardedAd != nil }

    private override init() {
        super.init()
    }

    // MARK: - Configure

    func configure() {
        GADMobileAds.sharedInstance().start { _ in
            print("[AdManager] SDK initialized")
            self.preloadInterstitial()
            self.preloadRewarded()
        }
    }

    // MARK: - Interstitial

    func preloadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(
            withAdUnitID: AdConfig.activeInterstitialId,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdManager] Interstitial load failed: \(error.localizedDescription)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("[AdManager] Interstitial loaded")
        }
    }

    @discardableResult
    func showInterstitialIfReady() -> Bool {
        // Check cooldown
        if let lastTime = lastInterstitialTime,
           Date().timeIntervalSince(lastTime) < AdConfig.interstitialCooldownSeconds {
            return false
        }

        guard let ad = interstitialAd,
              let rootVC = rootViewController() else {
            return false
        }

        ad.present(fromRootViewController: rootVC)
        lastInterstitialTime = Date()
        interstitialAd = nil
        return true
    }

    // MARK: - Rewarded

    func preloadRewarded() {
        let request = GADRequest()
        GADRewardedAd.load(
            withAdUnitID: AdConfig.activeRewardedId,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("[AdManager] Rewarded load failed: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            print("[AdManager] Rewarded loaded")
        }
    }

    func showRewarded(for rewardType: AdRewardType, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd,
              let rootVC = rootViewController() else {
            completion(false)
            return
        }

        pendingRewardType = rewardType
        rewardCompletion = completion

        ad.present(fromRootViewController: rootVC) {
            // User earned the reward
            print("[AdManager] Reward earned for: \(rewardType.rawValue)")
            self.rewardCompletion?(true)
            self.rewardCompletion = nil
            self.pendingRewardType = nil
        }

        rewardedAd = nil
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return nil }
        return window.rootViewController
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // Preload the next ad after dismissal
        if ad is GADInterstitialAd {
            preloadInterstitial()
        } else if ad is GADRewardedAd {
            // If reward wasn't already granted (user dismissed early)
            if rewardCompletion != nil {
                rewardCompletion?(false)
                rewardCompletion = nil
                pendingRewardType = nil
            }
            preloadRewarded()
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Ad failed to present: \(error.localizedDescription)")
        if ad is GADRewardedAd {
            rewardCompletion?(false)
            rewardCompletion = nil
            pendingRewardType = nil
        }
        // Preload replacements
        if ad is GADInterstitialAd { preloadInterstitial() }
        if ad is GADRewardedAd { preloadRewarded() }
    }
}
