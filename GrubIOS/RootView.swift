import SwiftUI
import StoreKit
import UIKit
import UserNotifications

struct RootView: View {
    @StateObject private var game: GameState
    @State private var appPhase: AppPhase = .splash
    @Environment(\.scenePhase) private var scenePhase

    // Growth services (Phase 1). Constructed here, where GameState is owned.
    private let analytics: AnalyticsService
    private let retention: RetentionTracker
    private let notifier: NotificationScheduler

    init() {
        let analytics = ConsoleAnalytics()
        let rating = RatingPrompt(request: {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        })
        let notifier = NotificationScheduler(center: UNUserNotificationCenter.current())
        self.analytics = analytics
        self.retention = RetentionTracker()
        self.notifier = notifier
        _game = StateObject(wrappedValue: GameState(analytics: analytics, rating: rating, notifier: notifier))
    }

    enum AppPhase {
        case splash
        case game
    }

    var body: some View {
        ZStack {
            switch appPhase {
            case .splash:
                SplashView(game: game) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appPhase = .game
                    }
                }
                .transition(.opacity)

            case .game:
                ContentView(game: game)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                let info = retention.registerOpen()
                analytics.log(.appOpen(isFirstOpen: info.isFirstOpen))
                // NOTE: notification permission is NOT requested here.
                // Asking at cold launch is bad UX and an App Store review risk.
                // It is requested after an "earned moment" — see GameState hooks.
            case .background:
                // Reschedule local notifications from the current pet state.
                let plan = NotificationScheduler.plan(
                    hunger: Double(game.hunger),
                    happiness: Double(game.happiness),
                    hungerPerHour: DecayConstants.hungerPerMin * 60,
                    happinessPerHour: DecayConstants.happinessPerMin * 60,
                    expeditionEnd: game.expeditionEndDate,
                    from: Date())
                notifier.apply(plan)
            default:
                break
            }
        }
    }
}
