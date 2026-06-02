import SwiftUI

struct SplashView: View {
    @ObservedObject var game: GameState
    var onFinish: () -> Void

    @State private var animTick: Int = 0
    @State private var loadingProgress: CGFloat = 0
    @State private var loadingDone = false
    @State private var showTapPrompt = false
    @State private var tapPromptVisible = true
    @State private var lettersRevealed: Int = 0

    private let title = "GRUB"
    private let letterDelay: Double = 0.375 // ~1.5s / 4 letters

    var body: some View {
        ZStack {
            GrubPalette.void_color.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Pixel title drawn via Canvas
                titleCanvas
                    .frame(height: 80)
                    .padding(.bottom, 24)

                // Grub sprite bobbing
                spriteCanvas
                    .frame(width: 120, height: 120)
                    .padding(.bottom, 32)

                // Loading bar
                loadingBar
                    .padding(.horizontal, 60)
                    .padding(.bottom, 40)

                // TAP TO START
                if showTapPrompt {
                    Text("TAP TO START")
                        .font(GrubFont.size(14))
                        .foregroundColor(GrubPalette.pale)
                        .opacity(tapPromptVisible ? 1.0 : 0.0)
                }

                Spacer()
            }
        }
        .onTapGesture {
            if loadingDone {
                onFinish()
            }
        }
        .onAppear {
            startAnimTimer()
            startLetterReveal()
            startLoading()
        }
        .statusBarHidden()
    }

    // MARK: - Title Canvas

    private var titleCanvas: some View {
        Canvas { context, size in
            let px: CGFloat = 4
            let letters = pixelLetters
            let totalWidth = CGFloat(letters.reduce(0) { $0 + letterWidth($1) + 1 }) * px - px
            var xOffset = (size.width - totalWidth) / 2

            for (index, letter) in letters.enumerated() {
                guard index < lettersRevealed else { break }
                for (row, line) in letter.enumerated() {
                    for (col, char) in line.enumerated() {
                        if char == "#" {
                            let rect = CGRect(
                                x: xOffset + CGFloat(col) * px,
                                y: CGFloat(row) * px + (size.height - CGFloat(letter.count) * px) / 2,
                                width: px - 0.5,
                                height: px - 0.5
                            )
                            context.fill(Path(rect), with: .color(GrubPalette.green))
                        }
                    }
                }
                xOffset += CGFloat(letterWidth(letter) + 1) * px
            }
        }
    }

    // MARK: - Sprite Canvas

    private var spriteCanvas: some View {
        // PNG hero: pixel-perfect directional sprite, with the same gentle bob
        // the procedural renderer had. Filling the parent's 120x120 frame
        // (no horizontal padding — that was shrinking it to a sliver).
        let bob = sin(Double(animTick) * 0.15) * 3.0
        return GrubSpriteView(state: "idle", tick: animTick)
            .offset(y: CGFloat(bob))
    }

    // MARK: - Loading Bar

    private var loadingBar: some View {
        Canvas { context, size in
            let px: CGFloat = 3
            let cols = Int(size.width / px)
            let rows = Int(size.height / px)
            let filledCols = Int(CGFloat(cols) * loadingProgress)

            // Background track
            for c in 0..<cols {
                for r in 0..<rows {
                    let rect = CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px, width: px - 0.5, height: px - 0.5)
                    context.fill(Path(rect), with: .color(GrubPalette.moss))
                }
            }

            // Filled portion
            for c in 0..<filledCols {
                for r in 0..<rows {
                    let rect = CGRect(x: CGFloat(c) * px, y: CGFloat(r) * px, width: px - 0.5, height: px - 0.5)
                    if r == 0 {
                        context.fill(Path(rect), with: .color(GrubPalette.green.opacity(0.6)))
                    } else {
                        context.fill(Path(rect), with: .color(GrubPalette.green))
                    }
                }
            }
        }
        .frame(height: 9)
    }

    // MARK: - Timers

    private func startAnimTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            DispatchQueue.main.async {
                animTick += 1

                // Blink tap prompt
                if showTapPrompt && animTick % 10 == 0 {
                    tapPromptVisible.toggle()
                }
            }
        }
    }

    private func startLetterReveal() {
        for i in 0..<title.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + letterDelay * Double(i + 1)) {
                withAnimation(.none) {
                    lettersRevealed = i + 1
                }
            }
        }
    }

    private func startLoading() {
        let interval = 0.05
        let steps = 2.0 / interval // 2 seconds
        var step = 0.0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            DispatchQueue.main.async {
                step += 1
                loadingProgress = min(CGFloat(step / steps), 1.0)

                if loadingProgress >= 1.0 {
                    timer.invalidate()
                    loadingDone = true
                    showTapPrompt = true
                    #if DEBUG
                    // Auto-advance in DEBUG so headless sim screenshots skip the manual tap.
                    // (No effect on release builds.)
                    if ProcessInfo.processInfo.environment["GRUB_AUTOSTART"] == "1" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onFinish() }
                    }
                    #endif
                }
            }
        }
    }

    // MARK: - Pixel Letter Data

    private var pixelLetters: [[String]] {
        [pixelG, pixelR, pixelU, pixelB]
    }

    private func letterWidth(_ letter: [String]) -> Int {
        letter.first?.count ?? 0
    }

    private let pixelG: [String] = [
        ".####.",
        "#....#",
        "#.....",
        "#.###.",
        "#...#.",
        "#..##.",
        ".####.",
    ]

    private let pixelR: [String] = [
        "#####.",
        "#....#",
        "#....#",
        "#####.",
        "#..#..",
        "#...#.",
        "#....#",
    ]

    private let pixelU: [String] = [
        "#....#",
        "#....#",
        "#....#",
        "#....#",
        "#....#",
        "#...##",
        ".####.",
    ]

    private let pixelB: [String] = [
        "#####.",
        "#....#",
        "#....#",
        "#####.",
        "#....#",
        "#....#",
        "#####.",
    ]
}
