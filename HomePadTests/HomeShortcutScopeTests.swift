import XCTest
@testable import HomePad

final class HomeShortcutScopeTests: XCTestCase {
    func testLegacySceneWithNoSourceHomeCannotRunAMatchingNameInAnotherHome() throws {
        let data = Data(#"[{"id":"old-scene","kind":"scene","target":"Good night","name":"Sleep"}]"#.utf8)
        let old = try XCTUnwrap(JSONDecoder().decode([HomeShortcut].self, from: data).first)
        XCTAssertNil(old.homeID)
        XCTAssertFalse(old.belongs(to: "home-a"))
        XCTAssertFalse(old.belongs(to: "home-b"))
        XCTAssertFalse(old.belongs(to: "demo"))
        XCTAssertFalse(old.belongs(to: nil))
    }

    func testExplicitSceneAndTargetedCameraKeepTheirOriginalHomeScope() {
        for kind in [HomeShortcutKind.scene, .camera] {
            var shortcut = HomeShortcut(id: "owned", kind: kind, target: "target", homeID: "home-a")
            XCTAssertTrue(shortcut.belongs(to: "home-a"))
            XCTAssertFalse(shortcut.belongs(to: "home-b"))
            XCTAssertFalse(shortcut.belongs(to: "demo"))
            shortcut.homeID = nil
            XCTAssertFalse(shortcut.belongs(to: "home-a"))
        }
    }

    func testUnconfiguredCameraAndGenericMediaActionsDoNotRequireHomeAccess() {
        for kind in [HomeShortcutKind.camera, .music, .agenda, .controls] {
            let shortcut = HomeShortcut(id: "generic", kind: kind)
            XCTAssertTrue(shortcut.belongs(to: nil))
            XCTAssertTrue(shortcut.belongs(to: "home-a"))
            XCTAssertTrue(shortcut.belongs(to: "home-b"))
        }
    }

    func testResavingLegacySceneExplicitlyScopesItToTheChosenHome() {
        var shortcut = HomeShortcut(id: "old", kind: .scene, target: "Good night")
        XCTAssertFalse(shortcut.belongs(to: "home-b"))
        shortcut.homeID = "home-b"
        XCTAssertTrue(shortcut.belongs(to: "home-b"))
        XCTAssertFalse(shortcut.belongs(to: "home-a"))
    }
}
