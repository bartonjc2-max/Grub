import SwiftUI

struct RootView: View {
    @StateObject private var game = GameState()
    @State private var appPhase: AppPhase = .splash

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
    }
}
