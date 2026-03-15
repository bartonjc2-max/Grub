import Foundation

// MARK: - Minigame Definitions
enum MinigameType: String, CaseIterable {
    case dodge = "dodge"
    case feedMe = "feed_me"
    case memory = "memory"
    case bugCatch = "bug_catch"
    case rhythm = "rhythm"

    var name: String {
        switch self {
        case .dodge: return "DODGE"
        case .feedMe: return "FEED ME"
        case .memory: return "MEMORY"
        case .bugCatch: return "BUG CATCH"
        case .rhythm: return "RHYTHM"
        }
    }

    var unlockLevel: Int {
        switch self {
        case .dodge, .feedMe: return 1
        case .memory: return 3
        case .bugCatch: return 5
        case .rhythm: return 7
        }
    }

    var totalRounds: Int {
        switch self {
        case .dodge, .feedMe: return 5
        case .memory, .bugCatch, .rhythm: return 1
        }
    }
}

extension GameState {
    // MARK: - Game Selector
    func isGameUnlocked(_ game: MinigameType) -> Bool {
        ownerLevel >= game.unlockLevel
    }

    func unlockedGames() -> [MinigameType] {
        MinigameType.allCases.filter { isGameUnlocked($0) }
    }

    // MARK: - Open Specific Game
    func openGame(_ game: MinigameType) {
        guard isGameUnlocked(game) else { return }
        audio.play(.tap)
        mgGame = game == .dodge ? 0 : game == .feedMe ? 1 : game == .memory ? 2 : game == .bugCatch ? 3 : 4
        mgRound = 1
        mgWins = 0
        mgResult = ""
        mgPrompt = "GET READY..."
        showGameSelector = false
        showMinigame = true
        setupMGRound()
    }

    func openPlay() {
        audio.play(.tap)
        showGameSelector = true
    }

    // MARK: - Setup Round
    func setupMGRound() {
        mgResult = ""
        mgTimer?.invalidate()

        switch mgGame {
        case 0: // Dodge
            mgWallSide = Bool.random() ? "left" : "right"
            mgWaiting = true
            mgPrompt = "WHICH SIDE IS SAFE?"
        case 1: // Feed Me
            let allFoods = ["meat", "veggie", "cake", "pizza", "carrot"]
            mgFoodItems = Array(allFoods.shuffled().prefix(3))
            mgTargetFood = Int.random(in: 0...2)
            mgPrompt = "FEED: \(mgFoodItems[mgTargetFood].uppercased())"
            mgWaiting = true
            let timeout = max(1.0, 3.5 - Double(mgRound) * 0.5)
            mgTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, self.mgWaiting else { return }
                    self.mgRoundResult(won: false)
                }
            }
        case 2: // Memory
            setupMemoryGame()
        case 3: // Bug Catch
            setupBugCatchGame()
        case 4: // Rhythm
            setupRhythmGame()
        default: break
        }
    }

    // MARK: - Dodge
    func mgChoice(side: String) {
        guard mgWaiting, mgGame == 0 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = side != mgWallSide
        mgRoundResult(won: correct)
    }

    // MARK: - Feed Me
    func mgFoodChoice(index: Int) {
        guard mgWaiting, mgGame == 1 else { return }
        mgWaiting = false
        mgTimer?.invalidate()
        let correct = index == mgTargetFood
        mgRoundResult(won: correct)
    }

    // MARK: - Memory Game
    func setupMemoryGame() {
        let symbols = ["A", "B", "C", "D", "E", "F"]
        mgMemoryCards = (symbols + symbols).shuffled()
        mgMemoryRevealed = Array(repeating: false, count: 12)
        mgMemoryMatched = Array(repeating: false, count: 12)
        mgFirstFlip = nil
        mgMemoryFlips = 0
        mgWins = 0
        mgWaiting = true
        mgPrompt = "MATCH THE PAIRS"
    }

    func memoryFlip(index: Int) {
        guard mgWaiting, mgGame == 2 else { return }
        guard !mgMemoryRevealed[index], !mgMemoryMatched[index] else { return }

        mgMemoryRevealed[index] = true
        mgMemoryFlips += 1

        if let first = mgFirstFlip {
            mgWaiting = false
            if mgMemoryCards[first] == mgMemoryCards[index] {
                mgMemoryMatched[first] = true
                mgMemoryMatched[index] = true
                mgWins += 1
                audio.play(.win)

                if mgWins >= 6 {
                    let score = max(1, 12 - (mgMemoryFlips - 6))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.finishScoreGame(score: score, maxScore: 6, gameName: "memory")
                    }
                } else {
                    mgWaiting = true
                }
            } else {
                audio.play(.lose)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self else { return }
                    self.mgMemoryRevealed[first] = false
                    self.mgMemoryRevealed[index] = false
                    self.mgWaiting = true
                }
            }
            mgFirstFlip = nil
        } else {
            mgFirstFlip = index
        }
    }

    // MARK: - Bug Catch
    func setupBugCatchGame() {
        mgBugs = (0..<8).map { _ in
            BugState(
                x: Double.random(in: 0.1...0.9),
                y: Double.random(in: 0.1...0.9),
                dx: Double.random(in: -0.01...0.01),
                dy: Double.random(in: -0.01...0.01),
                caught: false
            )
        }
        mgBugScore = 0
        mgBugTimeLeft = 15
        mgWaiting = true
        mgPrompt = "CATCH THE BUGS!"

        mgTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self, self.mgGame == 3 else { timer.invalidate(); return }
                self.mgBugTimeLeft -= 0.1
                for i in 0..<self.mgBugs.count where !self.mgBugs[i].caught {
                    self.mgBugs[i].x += self.mgBugs[i].dx
                    self.mgBugs[i].y += self.mgBugs[i].dy
                    if self.mgBugs[i].x < 0 || self.mgBugs[i].x > 1 { self.mgBugs[i].dx *= -1 }
                    if self.mgBugs[i].y < 0 || self.mgBugs[i].y > 1 { self.mgBugs[i].dy *= -1 }
                    self.mgBugs[i].x = min(1, max(0, self.mgBugs[i].x))
                    self.mgBugs[i].y = min(1, max(0, self.mgBugs[i].y))
                }
                if self.mgBugTimeLeft <= 0 {
                    timer.invalidate()
                    self.finishScoreGame(score: self.mgBugScore, maxScore: 8, gameName: "bug_catch")
                }
            }
        }
    }

    func catchBug(at index: Int) {
        guard mgWaiting, mgGame == 3, index < mgBugs.count, !mgBugs[index].caught else { return }
        mgBugs[index].caught = true
        mgBugScore += 1
        audio.play(.win)
    }

    // MARK: - Rhythm (Simon Says)
    func setupRhythmGame() {
        mgRhythmSequence = [Int.random(in: 0...3)]
        mgRhythmPlayerIndex = 0
        mgWins = 0
        mgWaiting = false
        mgPrompt = "WATCH THE PATTERN"
        showRhythmSequence()
    }

    func showRhythmSequence() {
        mgRhythmShowingSequence = true
        mgRhythmHighlight = -1
        var delay = 0.5
        for (_, btn) in mgRhythmSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.mgRhythmHighlight = btn
                self?.audio.play(.tap)
            }
            delay += 0.5
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.mgRhythmHighlight = -1
            }
            delay += 0.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.mgRhythmShowingSequence = false
            self?.mgRhythmPlayerIndex = 0
            self?.mgWaiting = true
            self?.mgPrompt = "YOUR TURN"
        }
    }

    func rhythmTap(_ button: Int) {
        guard mgWaiting, mgGame == 4, !mgRhythmShowingSequence else { return }

        if button == mgRhythmSequence[mgRhythmPlayerIndex] {
            audio.play(.tap)
            mgRhythmPlayerIndex += 1
            if mgRhythmPlayerIndex >= mgRhythmSequence.count {
                mgWins += 1
                mgRhythmSequence.append(Int.random(in: 0...3))
                mgWaiting = false
                mgPrompt = "ROUND \(mgWins + 1)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showRhythmSequence()
                }
            }
        } else {
            audio.play(.lose)
            finishScoreGame(score: mgWins, maxScore: 10, gameName: "rhythm")
        }
    }

    // MARK: - Round-Based Result (Dodge & Feed Me)
    func mgRoundResult(won: Bool) {
        if won {
            mgWins += 1
            audio.play(.win)
            mgResult = "CORRECT!"
        } else {
            audio.play(.lose)
            mgResult = "WRONG!"
        }

        let totalRounds = 5
        if mgRound >= totalRounds {
            let gameWon = mgWins >= 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.finishRoundGame(won: gameWon)
            }
        } else {
            mgRound += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.setupMGRound()
            }
        }
    }

    // MARK: - Finish Handlers
    fileprivate func finishRoundGame(won: Bool) {
        let gameId = mgGame == 0 ? "dodge" : "feed_me"
        let score = mgWins

        if score > (highScores[gameId] ?? 0) {
            highScores[gameId] = score
        }

        happiness = min(100, happiness + (won ? 15 : 5))
        playedCount += 1
        addXP(3)
        trackCare("play")
        if won { trackCare("minigameWin") }

        if won {
            let reward = uncommonIngredients.randomElement() ?? "glowshroom"
            addIngredient(reward)
            let count = Int.random(in: 1...2) + minigameRewardBonus
            if count > 1, let extra = uncommonIngredients.randomElement() {
                addIngredient(extra)
            }
        }

        if won {
            winStreak += 1
            if winStreak >= 3 {
                addIngredient("golden_bug")
                displayToast("3-WIN STREAK! +GOLDEN BUG!")
                winStreak = 0
            }
        } else {
            winStreak = 0
        }

        save()
        showMinigame = false
        if won { petStateAnim = "playing" }
        animStateTimer?.invalidate()
        animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.petStateAnim = "idle" }
        }
    }

    func finishScoreGame(score: Int, maxScore: Int, gameName: String) {
        if score > (highScores[gameName] ?? 0) {
            highScores[gameName] = score
        }

        let ratio = Double(score) / Double(maxScore)
        let hapBonus: Int
        var ingredientReward: String?

        if ratio >= 0.75 {
            hapBonus = 20
            ingredientReward = rareIngredients.filter { $0 != "golden_bug" }.randomElement()
            mgResult = "GREAT! SCORE: \(score)"
        } else if ratio >= 0.4 {
            hapBonus = 15
            ingredientReward = uncommonIngredients.randomElement()
            mgResult = "GOOD! SCORE: \(score)"
        } else {
            hapBonus = 10
            ingredientReward = commonIngredients.randomElement()
            mgResult = "OK. SCORE: \(score)"
        }

        happiness = min(100, happiness + hapBonus)
        playedCount += 1
        addXP(3)
        trackCare("play")
        if ratio >= 0.4 { trackCare("minigameWin") }

        if let reward = ingredientReward {
            addIngredient(reward)
        }

        if ratio >= 0.4 {
            winStreak += 1
            if winStreak >= 3 {
                addIngredient("golden_bug")
                displayToast("3-WIN STREAK! +GOLDEN BUG!")
                winStreak = 0
            }
        } else {
            winStreak = 0
        }

        save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showMinigame = false
            self?.petStateAnim = ratio >= 0.4 ? "playing" : "idle"
            self?.animStateTimer?.invalidate()
            self?.animStateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.petStateAnim = "idle" }
            }
        }
    }

    func closeMinigame() {
        audio.play(.tap)
        mgTimer?.invalidate()
        showMinigame = false
    }
}
