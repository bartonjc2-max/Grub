import Foundation

/// Single source of truth for Descent feel/balance. Snappy/arcade starting
/// values — tune on-device. Mirrors the existing DecayConstants pattern.
struct DescentTuning {
    // Movement
    var grubStepDuration: Double = 0.18      // seconds per tile (~5.5 tiles/s; v2: slowed from 0.13)
    // Attack
    var attackCooldown: Double = 0.28        // seconds between attacks
    var attackFlashDuration: Double = 0.14   // attack/hit flash visual window
    var attackRange: Int = 1                 // Chebyshev tiles: HIT auto-targets the nearest enemy within this
    // Enemy
    var enemyHP: Int = 2                      // dies in 1-2 hits
    var enemyStepDuration: Double = 0.38      // seconds per tile (~2.6 tiles/s; v2: slowed from 0.22 so you can kite)
    var enemyTouchDamage: Int = 1            // hearts lost on contact
    var enemyContactIFrames: Double = 0.8     // invuln after a hit
    var hurtFlashDuration: Double = 0.16      // short red hit flash (decoupled from i-frames)
    // Run
    var startHearts: Int = 3                  // fixed for the prototype
}
