import XCTest
@testable import HomePad

final class HomeWidgetLayoutTests: XCTestCase {
    func testReadbackBatchChangesValuesWithoutResortingOrReplacingOtherDevices() throws {
        let ids = (0..<3).map { _ in UUID() }
        let original = ids.enumerated().map { index, id in
            HomeTile(id: id, name: "灯 \(index)", room: "客厅", symbol: "lightbulb.fill", value: "Off",
                     isOn: false, reachable: true, writable: true)
        }
        var turnedOn = original[1]; turnedOn.value = "On"; turnedOn.isOn = true
        let unknown = HomeTile(id: UUID(), name: "New device", room: "Home", symbol: "switch.2", value: "On",
                               isOn: true, reachable: true, writable: true)
        let result = HomeTileUpdates.replacing([turnedOn.id: turnedOn, unknown.id: unknown], in: original)
        XCTAssertEqual(result.map(\.id), ids, "Readback must neither reorder cards nor insert a device from a different topology")
        XCTAssertEqual(result[0], original[0]); XCTAssertEqual(result[2], original[2])
        XCTAssertTrue(result[1].isOn)
        XCTAssertEqual(HomeTileUpdates.replacing([:], in: result), result)
        var offline = result[1]; offline.reachable = false; offline.writable = false; offline.value = "Offline"
        XCTAssertEqual(HomeTileUpdates.replacing([offline.id: offline], in: result)[1], offline,
                       "Coalescing must preserve actual unavailability rather than retaining the earlier On state")
    }
    @MainActor func testBurstOfHomeReadbacksProducesOneRefreshAndCancellationRejectsOldHome() async throws {
        let scheduler = HomeRefreshScheduler()
        var calls: [Bool] = []
        for index in 0..<1_000 {
            scheduler.schedule(read: index == 500) { calls.append($0) }
        }
        try await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(calls, [true], "A burst must retain the strongest refresh intent without rebuilding per characteristic")
        scheduler.schedule(read: false) { calls.append($0) }
        scheduler.cancel()
        scheduler.schedule(read: false) { calls.append($0) }
        try await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(calls, [true, false], "Only the new household generation may deliver after cancellation")
    }

    @MainActor func testCachedConfigurationFollowsEditsHomeSwitchesAndMalformedReplacement() throws {
        let cache = HomeConfigurationCache()
        let first = [HomeWidgetConfiguration(id: "clock", kind: .clock, size: .small)]
        let second = [HomeWidgetConfiguration(id: "large", kind: .clock, size: .large)]
        func encode(_ layouts: [String: [HomeWidgetConfiguration]]) throws -> String {
            String(decoding: try JSONEncoder().encode(layouts), as: UTF8.self)
        }
        let original = try encode(["home-a": first, "home-b": second])
        XCTAssertEqual(cache.widgetLayouts(from: original)["home-a"], first)
        XCTAssertEqual(cache.widgetLayouts(from: original)["home-b"], second)
        XCTAssertEqual(cache.widgetLayouts(from: try encode(["home-a": second]))["home-a"], second)
        XCTAssertTrue(cache.widgetLayouts(from: "broken JSON").isEmpty, "An invalid new value must not retain the previous home's private layout")
        XCTAssertEqual(cache.widgetLayouts(from: original)["home-a"], first)
        XCTAssertTrue(cache.shortcuts(from: "[]").isEmpty, "A deliberately empty sidebar is distinct from defaults")
        XCTAssertEqual(cache.shortcuts(from: "invalid").map(\.id), HomeShortcut.defaults.map(\.id))
        XCTAssertEqual(cache.placements(for: second, columns: 3), HomeWidgetPacking.place(second, columns: 3))
        XCTAssertEqual(cache.placements(for: second, columns: 1), HomeWidgetPacking.place(second, columns: 1))
        XCTAssertEqual(cache.placements(for: first, columns: 1), HomeWidgetPacking.place(first, columns: 1))
    }
    func testLegacyRightColumnContentMigratesOnceWithoutLosingHomeScopeOrOrder() {
        let light = HomeWidgetConfiguration(id: "lamp", kind: .accessory, target: "lamp-id", size: .medium)
        let camera = HomeWidgetConfiguration(id: "front", kind: .camera, target: "camera-id", size: .large)
        let agenda = HomeWidgetConfiguration(id: "calendar", kind: .agenda, size: .small)
        let original = [HomeShortcut(id: "music", kind: .music)]
        let migrated = HomeFavoriteMigration.migrated([light, camera, agenda], shortcuts: original, homeID: "home-a")
        XCTAssertEqual(migrated.widgets, [light])
        XCTAssertEqual(migrated.shortcuts.map(\.id), ["music", "migrated-home-a-front", "migrated-home-a-calendar"])
        XCTAssertEqual(migrated.shortcuts[1].target, "camera-id")
        XCTAssertTrue(migrated.shortcuts[1].belongs(to: "home-a"))
        XCTAssertFalse(migrated.shortcuts[1].belongs(to: "home-b"))
        let retried = HomeFavoriteMigration.migrated([light, camera, agenda], shortcuts: migrated.shortcuts, homeID: "home-a")
        XCTAssertEqual(retried.shortcuts.map(\.id), migrated.shortcuts.map(\.id))
        XCTAssertEqual(retried.widgets, migrated.widgets)
    }

    func testSnappingRespectsActualAccessoryStepAndNonAlignedMaximum() throws {
        let bounds = try XCTUnwrap(HomeAdjustment(minimum: 10, maximum: 29.8, step: 0.5))
        XCTAssertEqual(bounds.snapped(100), 29.5)
        XCTAssertEqual(bounds.snapped(-1), 10)
        XCTAssertEqual(bounds.snapped(22.23), 22)
        XCTAssertTrue(bounds.accepts(bounds.snapped(22.49)))
        XCTAssertEqual(bounds.snapped(.nan), 10)
    }

    @MainActor func testOfflineKnownDashboardSurvivesButRevocationAndUnknownHomeDoNot() {
        let home = HomeStore(); home.startDemo()
        home.status = .offline
        XCTAssertTrue(home.keepsDashboard)
        home.clearUnavailableHome(.denied)
        XCTAssertFalse(home.keepsDashboard)
        XCTAssertTrue(home.tiles.isEmpty)
        home.startDemo(state: .offline)
        XCTAssertFalse(home.keepsDashboard)
    }

    func testMixedWidgetSizesStayWithinCanvasWithoutOverlap() {
        let widgets = (0..<24).map { index in
            HomeWidgetConfiguration(id: String(index), kind: .camera, target: nil,
                                    size: HomeWidgetSize.allCases[index % HomeWidgetSize.allCases.count])
        }
        for columns in [1, 2, 3, 4] {
            let placements = HomeWidgetPacking.place(widgets, columns: columns)
            XCTAssertEqual(placements.map(\.id), widgets.map(\.id))
            var occupied = Set<String>()
            for placement in placements {
                XCTAssertGreaterThanOrEqual(placement.column, 0)
                XCTAssertGreaterThanOrEqual(placement.row, 0)
                XCTAssertLessThanOrEqual(placement.column + placement.columns, columns)
                for row in placement.row..<(placement.row + placement.rows) {
                    for column in placement.column..<(placement.column + placement.columns) {
                        XCTAssertTrue(occupied.insert("\(column),\(row)").inserted,
                                      "Overlapping widget at \(column),\(row) for \(columns) columns")
                    }
                }
            }
        }
    }

    func testEmptyAndNarrowLayoutsRemainUsable() {
        XCTAssertTrue(HomeWidgetPacking.place([], columns: 3).isEmpty)
        let widgets = [HomeWidgetConfiguration(id: "large", kind: .clock, target: nil, size: .large),
                       HomeWidgetConfiguration(id: "small", kind: .camera, target: nil, size: .small)]
        for columns in [0, 1] {
            let placements = HomeWidgetPacking.place(widgets, columns: columns)
            XCTAssertEqual(placements.count, 2)
            XCTAssertTrue(placements.allSatisfy { $0.column == 0 && $0.columns == 1 })
            XCTAssertGreaterThanOrEqual(placements[1].row, placements[0].row + placements[0].rows)
        }
    }

    func testSavedLayoutsKeepDemoAndPhysicalHomesSeparate() throws {
        let homeID = UUID().uuidString
        let camera = HomeWidgetConfiguration(id: "front-door", kind: .camera, target: "camera-id", size: .large)
        let saved = ["demo": HomeWidgetConfiguration.defaults, homeID: [camera], "empty-home": []]
        let decoded = try JSONDecoder().decode([String: [HomeWidgetConfiguration]].self,
                                              from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded[homeID], [camera])
        XCTAssertEqual(decoded["demo"], HomeWidgetConfiguration.defaults)
        XCTAssertEqual(decoded["empty-home"], [])
        XCTAssertNil(decoded["unconfigured-home"])
    }

    func testUnknownAndOfflinePowerNeverClaimOff() {
        XCTAssertEqual(HomePowerState.resolve(value: "On", reachable: true), .on)
        XCTAssertEqual(HomePowerState.resolve(value: "Off", reachable: true), .off)
        for value in ["", "Unavailable", "Offline", "Unknown", "0", "false"] {
            XCTAssertEqual(HomePowerState.resolve(value: value, reachable: true), .unavailable)
        }
        for value in ["On", "Off", "Unavailable"] {
            XCTAssertEqual(HomePowerState.resolve(value: value, reachable: false), .offline)
        }
    }
}
