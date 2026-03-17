import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds
import PetEngine

@main
struct GrubIOSApp: App {
    private let theme = GrubTheme()
    private let content = GrubContent()
    private let sprite = GrubSprite()

    init() {
        AdManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(theme: theme, content: content, sprite: sprite, adService: AdManager.shared)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    requestTrackingPermission()
                }
        }
    }

    private func requestTrackingPermission() {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("[ATT] Authorization status: \(status.rawValue)")
                }
            }
        }
    }
}
