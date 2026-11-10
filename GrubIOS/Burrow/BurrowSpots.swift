/// The fixed places where finds get buried (spec: 8 spots in open soil).
/// Index = `BuriedFind.spot` = `BurrowSave.holes` entry. Order is part of the save format:
/// append new spots, never reorder.
enum BurrowSpots {
    static let anchors: [CellAnchor] = [
        CellAnchor(ref: .chamberTop, x: 6, dy: 13),     // 0  left of the chamber
        CellAnchor(ref: .surface, x: 39, dy: 9),        // 1  upper soil, middle
        CellAnchor(ref: .surface, x: 59, dy: 15),       // 2  upper soil, right edge
        CellAnchor(ref: .chamberBottom, x: 34, dy: 11), // 3  below the chamber
        CellAnchor(ref: .surface, x: 20, dy: 6),        // 4  upper soil, above the crawl tunnel
        CellAnchor(ref: .chamberTop, x: 5, dy: 28),     // 5  far left, above the left side-room
        CellAnchor(ref: .chamberTop, x: 62, dy: 22),    // 6  far right, beside the right connector
        CellAnchor(ref: .chamberBottom, x: 42, dy: 18), // 7  deep soil, left of the right side-room
    ]

    static func anchor(_ spot: Int) -> CellAnchor? {
        anchors.indices.contains(spot) ? anchors[spot] : nil
    }
}
