import Foundation

/// Single source of truth for Descent feel/balance. Snappy/arcade starting
/// values — tune on-device. Mirrors the existing DecayConstants pattern.
struct DescentTuning {
    // Movement
    var grubStepDuration: Double = 0.13      // seconds per tile (~7 tiles/s)
    // Attack
    var attackCooldown: Double = 0.25        // seconds between attacks
    var attackFlashDuration: Double = 0.12   // attack/hit flash visual window
    // Enemy
    var enemyHP: Int = 2                      // dies in 1-2 hits
    var enemyStepDuration: Double = 0.22      // seconds per tile (~4.5 tiles/s)
    var enemyTouchDamage: Int = 1            // hearts lost on contact
    var enemyContactIFrames: Double = 0.8     // invuln after a hit
    var hurtFlashDuration: Double = 0.16      // short red hit flash (decoupled from i-frames)
    // Run
    var startHearts: Int = 3                  // fixed for the prototype
}
