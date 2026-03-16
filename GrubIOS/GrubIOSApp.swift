import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds

@main
struct GrubIOSApp: App {
    init() {
        // Initialize Google Mobile Ads SDK
        AdManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    requestTrackingPermission()
                }
        }
    }

    private func requestTrackingPermission() {
        // Only request once — ATTrackingManager remembers the choice
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("[ATT] Authorization status: \(status.rawValue)")
                }
            }
        }
    }
}
