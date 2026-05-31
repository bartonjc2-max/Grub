import SwiftUI

// MARK: - 8-direction PNG hero

extension SpriteRenderer {
    /// The 8 compass directions of the directional grub sprite set.
    /// Asset names map to `grub_<rawValue>` in `Assets.xcassets`
    /// (e.g. `.s` -> "grub_S", which is grub_S.imageset).
    enum Direction8: String, CaseIterable {
        case n  = "N"
        case ne = "NE"
        case e  = "E"
        case se = "SE"
        case s  = "S"
        case sw = "SW"
        case w  = "W"
        case nw = "NW"

        var assetName: String { "grub_\(rawValue)" }
    }

    /// Canonical idle/render asset name.
    static let canonicalAssetName = "grub_canon"
}
