import XCTest
@testable import HomePad

final class HomeDashboardGeometryTests: XCTestCase {
    func testElevenAndThirteenInchLandscapeFillTheWidthWithRectangularSidebarCells() {
        for size in [CGSize(width: 1194, height: 834), CGSize(width: 1210, height: 834),
                     CGSize(width: 1376, height: 1032)] {
            let geometry = HomeDashboardGeometry(width: size.width, height: size.height)

            assertFits(geometry, in: size, inset: 12, gap: 12)
            XCTAssertGreaterThan(geometry.sidebarWidth, geometry.cellSide,
                                 "The extra column uses the remaining width instead of another square")
            XCTAssertEqual(geometry.sidebarCardHeight, geometry.cellSide, accuracy: 0.001,
                           "Left and right cells must share the same row height")
            XCTAssertEqual(geometry.boardWidth, geometry.cellSide * 3 + 24, accuracy: 0.001)
        }
    }

    func testLeftBoardKeepsThreeSquareColumnsAndTheTwoByTwoHero() throws {
        let gap: CGFloat = 12
        let geometry = HomeDashboardGeometry(width: 1194, height: 834)
        let placements = HomeWidgetPacking.place(HomeWidgetConfiguration.defaults, columns: 3)
        let hero = try XCTUnwrap(placements.first(where: { $0.id == "slot-0" }))
        let heroRect = rectangle(for: hero, geometry: geometry, gap: gap)

        XCTAssertEqual(hero.column, 0)
        XCTAssertEqual(hero.row, 0)
        XCTAssertEqual(hero.columns, 2)
        XCTAssertEqual(hero.rows, 2)
        XCTAssertEqual(heroRect.width, geometry.cellSide * 2 + gap, accuracy: 0.001)
        XCTAssertEqual(heroRect.width, heroRect.height, accuracy: 0.001)
        for placement in placements.dropFirst() {
            let rect = rectangle(for: placement, geometry: geometry, gap: gap)
            XCTAssertEqual(placement.columns, 1)
            XCTAssertEqual(placement.rows, 1)
            XCTAssertEqual(rect.width, geometry.cellSide, accuracy: 0.001)
            XCTAssertEqual(rect.height, geometry.cellSide, accuracy: 0.001)
            XCTAssertLessThanOrEqual(rect.maxX, geometry.boardWidth + 0.001)
        }
        XCTAssertEqual(placements.map { $0.row + $0.rows }.max(), 3)
    }

    func testMoreWidgetsAddRowsWithoutResizingOrMovingExistingCards() {
        let geometry = HomeDashboardGeometry(width: 1194, height: 834, visibleRows: 3)
        let initial = HomeWidgetPacking.place(HomeWidgetConfiguration.defaults, columns: 3)
        let extra = (0..<24).map {
            HomeWidgetConfiguration(id: "extra-\($0)", kind: .camera, target: nil, size: .small)
        }
        let expanded = HomeWidgetPacking.place(HomeWidgetConfiguration.defaults + extra, columns: 3)

        XCTAssertEqual(Array(expanded.prefix(initial.count)), initial)
        XCTAssertGreaterThan(expanded.map { $0.row + $0.rows }.max() ?? 0, 3)
        XCTAssertGreaterThan((CGFloat(expanded.map { $0.row + $0.rows }.max() ?? 0) * (geometry.cellSide + 12) - 12),
                             geometry.viewportHeight)
        var occupied = Set<String>()
        for placement in expanded {
            XCTAssertLessThanOrEqual(placement.column + placement.columns, 3)
            for row in placement.row..<(placement.row + placement.rows) {
                for column in placement.column..<(placement.column + placement.columns) {
                    XCTAssertTrue(occupied.insert("\(column),\(row)").inserted, "Expanded widgets must not overlap")
                }
            }
        }
    }

    func testSupportedNarrowAndResizedViewportsKeepAllColumnsWithinTheWidth() {
        // Four-column composition supports viewports of at least 320 × 240 pt.
        // Smaller transient sizes below are checked for numeric safety only.
        for size in [CGSize(width: 320, height: 240), CGSize(width: 480, height: 320),
                     CGSize(width: 640, height: 480), CGSize(width: 1024, height: 768),
                     CGSize(width: 1366, height: 768)] {
            let geometry = HomeDashboardGeometry(width: size.width, height: size.height)
            assertFits(geometry, in: size, inset: 12, gap: 12)
            XCTAssertEqual(geometry.sidebarCardHeight, geometry.cellSide, accuracy: 0.001)
            XCTAssertGreaterThan(geometry.cellSide, 0)
            XCTAssertGreaterThan(geometry.sidebarWidth, 0)
        }
    }

    func testProportionalViewportAndSpacingScaleKeepTheSameComposition() {
        let original = HomeDashboardGeometry(width: 1194, height: 834, inset: 12, gap: 12)
        let scaled = HomeDashboardGeometry(width: 597, height: 417, inset: 6, gap: 6)

        XCTAssertEqual(scaled.cellSide, original.cellSide / 2, accuracy: 0.001)
        XCTAssertEqual(scaled.boardWidth, original.boardWidth / 2, accuracy: 0.001)
        XCTAssertEqual(scaled.sidebarWidth, original.sidebarWidth / 2, accuracy: 0.001)
        XCTAssertEqual(scaled.sidebarCardHeight, original.sidebarCardHeight / 2, accuracy: 0.001)
        XCTAssertEqual(scaled.viewportHeight, original.viewportHeight / 2, accuracy: 0.001)
        assertFits(scaled, in: CGSize(width: 597, height: 417), inset: 6, gap: 6)
    }

    func testTransientUndersizedInputsRemainFiniteAndNonnegative() {
        for size in [CGSize.zero, CGSize(width: 1, height: 1), CGSize(width: 40, height: 20),
                     CGSize(width: -1, height: -1), CGSize(width: 320, height: 0)] {
            let geometry = HomeDashboardGeometry(width: size.width, height: size.height)
            for value in [geometry.cellSide, geometry.boardWidth, geometry.sidebarWidth,
                          geometry.sidebarCardHeight, geometry.viewportHeight] {
                XCTAssertTrue(value.isFinite)
                XCTAssertGreaterThanOrEqual(value, 0)
            }
        }
    }

    func testNonpositiveVisibleRowCountUsesOneInitialRow() {
        let one = HomeDashboardGeometry(width: 1194, height: 834, visibleRows: 1)
        for rows in [0, -1] {
            let geometry = HomeDashboardGeometry(width: 1194, height: 834, visibleRows: rows)
            XCTAssertEqual(geometry.cellSide, one.cellSide, accuracy: 0.001)
            XCTAssertEqual(geometry.boardWidth, one.boardWidth, accuracy: 0.001)
            XCTAssertEqual(geometry.sidebarWidth, one.sidebarWidth, accuracy: 0.001)
            XCTAssertEqual(geometry.sidebarCardHeight, one.sidebarCardHeight, accuracy: 0.001)
        }
    }

    private func assertFits(_ geometry: HomeDashboardGeometry, in size: CGSize, inset: CGFloat, gap: CGFloat,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(geometry.boardWidth + gap + geometry.sidebarWidth + inset * 2,
                       size.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(geometry.viewportHeight + inset * 2, size.height, accuracy: 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(geometry.cellSide * 3 + gap * 2, geometry.viewportHeight + 0.001,
                                 file: file, line: line)
    }

    private func rectangle(for placement: HomeWidgetPlacement, geometry: HomeDashboardGeometry, gap: CGFloat) -> CGRect {
        CGRect(x: CGFloat(placement.column) * (geometry.cellSide + gap),
               y: CGFloat(placement.row) * (geometry.cellSide + gap),
               width: CGFloat(placement.columns) * geometry.cellSide + CGFloat(placement.columns - 1) * gap,
               height: CGFloat(placement.rows) * geometry.cellSide + CGFloat(placement.rows - 1) * gap)
    }
}
