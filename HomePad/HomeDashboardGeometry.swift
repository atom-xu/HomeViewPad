import Foundation

/// Three square columns use the available height; the fixed sidebar uses the
/// remaining width, so a wide iPad does not gain empty outer gutters. Layout
/// guarantees apply to iPad viewports at least 320 × 240 points; smaller
/// transition proposals retain finite sizes rather than becoming valid grids.
struct HomeDashboardGeometry {
    let cellSide: CGFloat
    let boardWidth: CGFloat
    let sidebarWidth: CGFloat
    let sidebarCardHeight: CGFloat
    let viewportHeight: CGFloat

    init(width: CGFloat, height: CGFloat, visibleRows: Int = 3, inset: CGFloat = 12, gap: CGFloat = 12) {
        let availableWidth = max(1, width - inset * 2)
        viewportHeight = max(1, height - inset * 2)
        let rows = max(1, visibleRows)
        let heightSide = max(1, (viewportHeight - gap * CGFloat(rows - 1)) / CGFloat(rows))
        // Reserve enough width for readable horizontal shortcut cards.
        let widthSide = max(1, (availableWidth - gap * 3) / 4.2)
        cellSide = min(heightSide, widthSide)
        boardWidth = cellSide * 3 + gap * 2
        sidebarWidth = max(1, availableWidth - boardWidth - gap)
        sidebarCardHeight = cellSide
    }
}
