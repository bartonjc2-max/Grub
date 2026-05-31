import SwiftUI
import StoreKit
import UIKit

struct RootView: View {
    @StateObject private var game: GameState
    @State private var appPhase: AppPhase = .splash
    @Environment(\.scenePhase) private var scenePhase

    // Growth services (Phase 1). Constructed here, where GameState is owned.
    private let analytics: AnalyticsService
    private let retention: RetentionTracker

    init() {
        let analytics = ConsoleAnalytics()
        let rating = RatingPrompt(request: {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        })
        self.analytics = analytics
        self.retention = RetentionTracker()
        _game = StateObject(wrappedValue: GameState(analytics: analytics, rating: rating))
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
            if newPhase == .active {
                let info = retention.registerOpen()
                analytics.log(.appOpen(isFirstOpen: info.isFirstOpen))
            }
        }
    }
}
