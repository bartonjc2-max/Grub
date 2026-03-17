import SwiftUI
import PetEngine

final class GrubTheme: ThemeProvider {
    // Palette colors
    let voidColor = Color(hex: "#1a1a2e")
    let moss = Color(hex: "#16213e")
    let deepMoss = Color(hex: "#2a2a4e")
    let green = Color(hex: "#4ecca3")
    let pale = Color(hex: "#e8e8d0")
    let red = Color(hex: "#e94560")
    let yellow = Color(hex: "#f5a623")
    let purple = Color(hex: "#7b2d8b")
    let white = Color(hex: "#f0f0f0")
    let moonpale = Color(hex: "#c8c8b8")
    let dimGreen = Color(hex: "#2a7a60")
    let grey = Color(hex: "#888880")
    let bone = Color(hex: "#c0b89a")
    let nearBlack = Color(hex: "#0d0d0d")
    let orange = Color(hex: "#e07020")

    // Sprite palette map
    let spritePalette: [Character: Color] = [
        "1": Color(hex: "#1a1a2e"),
        "2": Color(hex: "#4ecca3"),
        "3": Color(hex: "#e8e8d0"),
        "4": Color(hex: "#e94560"),
        "5": Color(hex: "#f5a623"),
        "6": Color(hex: "#7b2d8b"),
        "7": Color(hex: "#16213e"),
        "8": Color(hex: "#c8c8b8"),
        "9": Color(hex: "#2a7a60"),
        "A": Color(hex: "#ffffff"),
        "B": Color(hex: "#888880"),
        "C": Color(hex: "#c0b89a"),
        "D": Color(hex: "#0d0d0d"),
        "E": Color(hex: "#e07020"),
    ]

    // Font
    let fontName = "PressStart2P-Regular"

    // App identity
    let appName = "GRUB"

    // Labels and strings
    let statLabels = StatLabels(hunger: "HNG", happiness: "HAP", health: "HP")
    let buttonLabels = ButtonLabels(feed: "FEED", play: "PLAY", dig: "DIG", pack: "PACK")
    let uiStrings = UIStrings(
        dyingBanner: "GRUB IS DYING!",
        healPrompt: "FEED TO HEAL",
        nappingBanner: "NAPPING",
        nightBanner: "DREAMS OF BUGS",
        deathMessage: "YOUR GRUB HAS DIED.",
        tapToStart: "TAP TO START",
        overfedWarning: "GRUB IS OVERFED!",
        tooHungryWarning: "GRUB IS TOO HUNGRY!",
        inventoryFullWarning: "INVENTORY IS FULL!",
        cooldownPrefix: "COOLDOWN:",
        foundSomething: "FOUND SOMETHING!",
        exploring: "EXPLORING...",
        adoptNew: "ADOPT NEW GRUB"
    )
}
