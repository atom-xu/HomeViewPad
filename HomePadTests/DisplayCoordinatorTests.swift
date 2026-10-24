import XCTest
import UIKit
import Combine
@testable import HomePad

final class DisplayCoordinatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testStandbyRequiresContinuousUprightStationaryAndIdleWindow() {
        var policy = DisplayStandbyPolicy(now: start)
        for second in 0...59 {
            policy.sample(gravityZ: 0.2, acceleration: 0.001, rotation: 0.01, at: start.addingTimeInterval(Double(second)))
        }
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(59), delay: 60))
        policy.sample(gravityZ: 0.2, acceleration: 0, rotation: 0, at: start.addingTimeInterval(60))
        XCTAssertTrue(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(64), delay: 60), "Stale hardware samples must never trigger standby")
    }

    func testMovementInteractionAndSensorGapsRestartTheEntireWindow() {
        var policy = DisplayStandbyPolicy(now: start)
        for second in 0...60 { policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(Double(second))) }
        XCTAssertTrue(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60))
        policy.interact(at: start.addingTimeInterval(60))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60))
        policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(61))
        policy.sample(gravityZ: 0, acceleration: 0.04, rotation: 0, at: start.addingTimeInterval(62))
        XCTAssertNil(policy.uprightSince)
        policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(63))
        policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(90))
        XCTAssertEqual(policy.uprightSince, start.addingTimeInterval(90))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(90), delay: 60))
    }

    func testVerticalDetectionUsesScreenNormalWithHysteresisAndRejectsInvalidData() {
        var policy = DisplayStandbyPolicy(now: start)
        policy.sample(gravityZ: -0.3, acceleration: 0, rotation: 0, at: start)
        XCTAssertTrue(policy.upright)
        policy.sample(gravityZ: 0.4, acceleration: 0, rotation: 0, at: start.addingTimeInterval(1))
        XCTAssertTrue(policy.upright, "Small angle changes near the threshold preserve the candidate")
        policy.sample(gravityZ: -0.5, acceleration: 0, rotation: 0, at: start.addingTimeInterval(2))
        XCTAssertFalse(policy.upright)
        policy.sample(gravityZ: 0.4, acceleration: 0, rotation: 0, at: start.addingTimeInterval(3))
        XCTAssertFalse(policy.upright, "Entry has a tighter angle than exit")
        policy.sample(gravityZ: .nan, acceleration: 0, rotation: 0, at: start.addingTimeInterval(4))
        XCTAssertNil(policy.lastSample)
        policy.sample(gravityZ: 0, acceleration: .infinity, rotation: 0, at: start.addingTimeInterval(5))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(500), delay: 60))
        XCTAssertFalse(DisplayStandbyPolicy.isWakeMovement(acceleration: .nan, rotation: 2))
        XCTAssertTrue(DisplayStandbyPolicy.isWakeMovement(acceleration: 0.2, rotation: 0))
        XCTAssertTrue(DisplayStandbyPolicy.isWakeMovement(acceleration: 0, rotation: 0.7))
        XCTAssertFalse(DisplayStandbyPolicy.isWakeMovement(acceleration: 0.01, rotation: 0.02))
    }

    func testResetDiscardsPriorForegroundAndClockReversalCannotEnter() {
        var policy = DisplayStandbyPolicy(now: start)
        for second in 0...60 { policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(Double(second))) }
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(-1), delay: 60))
        policy.reset(at: start.addingTimeInterval(61))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(600), delay: 60))
        XCTAssertNil(policy.uprightSince)
    }

    func testNightScheduleCrossesMidnightAndHonorsBoundaries() {
        for hour in [22, 23, 0, 6] { XCTAssertTrue(DisplayNightSchedule.contains(hour: hour, start: 22, end: 7)) }
        for hour in [7, 12, 21] { XCTAssertFalse(DisplayNightSchedule.contains(hour: hour, start: 22, end: 7)) }
        XCTAssertTrue(DisplayNightSchedule.contains(hour: 10, start: 8, end: 17))
        XCTAssertFalse(DisplayNightSchedule.contains(hour: 17, start: 8, end: 17))
        XCTAssertFalse(DisplayNightSchedule.contains(hour: 8, start: 8, end: 8))
        XCTAssertFalse(DisplayNightSchedule.contains(hour: 24, start: 22, end: 7))
    }

    func testContinuousFacePresencePreventsRepeatedStandbyAndWakeCycles() {
        var policy = DisplayStandbyPolicy(now: start)
        for second in 0...300 {
            let now = start.addingTimeInterval(Double(second))
            policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: now)
            if second % 2 == 0 { policy.noteFacePresence(at: now) }
            XCTAssertFalse(policy.shouldEnter(at: now, delay: 60), "A person remaining in front of the display must not see periodic dimming")
        }
        for second in 301...359 {
            let now = start.addingTimeInterval(Double(second))
            policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: now)
            XCTAssertFalse(policy.shouldEnter(at: now, delay: 60), "Absence must last the full selected idle delay")
        }
        let absentForFullDelay = start.addingTimeInterval(360)
        policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: absentForFullDelay)
        XCTAssertTrue(policy.shouldEnter(at: absentForFullDelay, delay: 60))
    }

    func testNewPresenceResetsIdleDelayAndForegroundResetClearsPresence() {
        var policy = DisplayStandbyPolicy(now: start)
        for second in 0...60 { policy.sample(gravityZ: 0, acceleration: 0, rotation: 0, at: start.addingTimeInterval(Double(second))) }
        XCTAssertTrue(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60))
        policy.noteFacePresence(at: start.addingTimeInterval(60))
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60))
        policy.noteFacePresence(at: start.addingTimeInterval(58))
        XCTAssertEqual(policy.lastFacePresence, start.addingTimeInterval(60), "A delayed presence event must not shorten the awake window")
        policy.clearFacePresence()
        XCTAssertTrue(policy.shouldEnter(at: start.addingTimeInterval(60), delay: 60), "Turning detection off removes its independent presence hold")
        policy.noteFacePresence(at: start.addingTimeInterval(60))
        policy.reset(at: start.addingTimeInterval(61))
        XCTAssertNil(policy.lastFacePresence)
        XCTAssertFalse(policy.shouldEnter(at: start.addingTimeInterval(600), delay: 60))
    }

    func testLegacyFacePreferenceDoesNotGrantContinuousCameraConsent() {
        let suite = "HomePadFaceConsentTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "display.faceWake")
        var consent = DisplayFaceCapturePolicy(defaults: defaults)
        XCTAssertTrue(consent.wakeEnabled)
        XCTAssertFalse(consent.continuousAllowed)
        XCTAssertNil(defaults.object(forKey: DisplayFaceCapturePolicy.foregroundConsentKey), "Reading legacy preferences must not synthesize new consent")
        XCTAssertFalse(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: true, cameraAuthorized: true), "Existing system camera permission cannot replace expanded-scope consent")
        XCTAssertTrue(consent.permitsCapture(active: true, standby: true, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        for unknown in [-1, 2, Int.max] {
            defaults.set(unknown, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
            consent = DisplayFaceCapturePolicy(defaults: defaults)
            XCTAssertFalse(consent.continuousAllowed)
            XCTAssertFalse(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: true, cameraAuthorized: true))
            XCTAssertTrue(consent.permitsCapture(active: true, standby: true, suspended: false, cameraAvailable: true, cameraAuthorized: true))
            XCTAssertEqual(defaults.integer(forKey: DisplayFaceCapturePolicy.foregroundConsentKey), unknown, "An unknown consent version must not be silently upgraded")
        }
    }

    func testContinuousFaceConsentRequiresAnIndependentExplicitOperation() {
        var consent = DisplayFaceCapturePolicy(wakeEnabled: false)
        consent.setContinuousConsent(true)
        XCTAssertFalse(consent.continuousAllowed, "The expanded scope cannot enable the master camera preference")
        consent.setWakeEnabled(true)
        XCTAssertFalse(consent.continuousAllowed)
        consent.setContinuousConsent(true)
        XCTAssertEqual(consent.foregroundConsentVersion, 1)
        XCTAssertTrue(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        XCTAssertFalse(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: true, cameraAuthorized: false))
        XCTAssertFalse(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: false, cameraAuthorized: true))
    }

    func testConsentWithdrawalAndMasterOffDoNotRegrantOnReenable() {
        var consent = DisplayFaceCapturePolicy(wakeEnabled: true)
        consent.setContinuousConsent(true)
        consent.setContinuousConsent(false)
        XCTAssertEqual(consent.foregroundConsentVersion, 0)
        XCTAssertFalse(consent.permitsCapture(active: true, standby: false, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        XCTAssertTrue(consent.permitsCapture(active: true, standby: true, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        consent.setContinuousConsent(true)
        consent.setWakeEnabled(false)
        XCTAssertFalse(consent.continuousAllowed)
        XCTAssertEqual(consent.foregroundConsentVersion, 0)
        XCTAssertFalse(consent.permitsCapture(active: true, standby: true, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        consent.setWakeEnabled(true)
        XCTAssertFalse(consent.continuousAllowed)
        var stale = DisplayFaceCapturePolicy(wakeEnabled: false, foregroundConsentVersion: 1)
        stale.setWakeEnabled(true)
        XCTAssertFalse(stale.continuousAllowed, "A stale stored scope with a disabled master cannot spring back into effect")
    }

    func testConsentedCameraPausesForForegroundAndPresentationInterruptions() {
        var consent = DisplayFaceCapturePolicy(wakeEnabled: true)
        consent.setContinuousConsent(true)
        for standby in [false, true] {
            XCTAssertFalse(consent.permitsCapture(active: false, standby: standby, suspended: false, cameraAvailable: true, cameraAuthorized: true))
            XCTAssertFalse(consent.permitsCapture(active: true, standby: standby, suspended: true, cameraAvailable: true, cameraAuthorized: true))
            XCTAssertTrue(consent.permitsCapture(active: true, standby: standby, suspended: false, cameraAvailable: true, cameraAuthorized: true))
        }
        var presence = DisplayStandbyPolicy(now: start)
        presence.noteFacePresence(at: start.addingTimeInterval(10))
        presence.reset(at: start.addingTimeInterval(11))
        XCTAssertNil(presence.lastFacePresence, "Leaving the foreground clears the previous camera activity hold")
        XCTAssertTrue(consent.continuousAllowed, "An interruption pauses previously granted scope; it does not invent or expand consent")
    }

    func testScreenBehaviorPreservesAllLegacyFlagAndMotionCombinations() {
        for automatic in [false, true] {
            for keepAwake in [false, true] {
                let policy = DisplayScreenBehaviorPolicy(explicitMode: nil, legacyAutomaticStandby: automatic, legacyKeepAwake: keepAwake)
                let expectedSelection: DisplayScreenBehavior = automatic ? .idleClock : keepAwake ? .keepDisplay : .followSystem
                XCTAssertEqual(policy.selection, expectedSelection)
                for motion in [false, true] {
                    XCTAssertEqual(policy.disablesIdleTimer(active: true, standby: false, motionAvailable: motion), keepAwake || (automatic && motion))
                    XCTAssertEqual(policy.automaticEntryEnabled(active: true, suspended: false, motionAvailable: motion), automatic && motion)
                }
            }
        }
    }

    func testScreenBehaviorMissingAndUnknownValuesReadWithoutMigratingPreferences() {
        let suite = "HomePadScreenBehaviorReadTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let missing = DisplayScreenBehaviorPolicy(defaults: defaults)
        XCTAssertNil(missing.explicitMode)
        XCTAssertEqual(missing.selection, .idleClock)
        XCTAssertTrue(missing.automaticStandby)
        XCTAssertFalse(missing.keepAwakeIntent)
        XCTAssertFalse(missing.disablesIdleTimer(active: true, standby: false, motionAvailable: false))
        XCTAssertNil(defaults.object(forKey: DisplayScreenBehaviorPolicy.preferenceKey))
        defaults.set(true, forKey: "display.automaticStandby")
        defaults.set(true, forKey: "keepAwake")
        defaults.set("future-unknown-mode", forKey: DisplayScreenBehaviorPolicy.preferenceKey)
        let before = defaults.persistentDomain(forName: suite) ?? [:]
        let unknown = DisplayScreenBehaviorPolicy(defaults: defaults)
        XCTAssertNil(unknown.explicitMode)
        XCTAssertTrue(unknown.disablesIdleTimer(active: true, standby: false, motionAvailable: false), "A legacy double-ON setting must stay awake without motion hardware")
        XCTAssertEqual(NSDictionary(dictionary: defaults.persistentDomain(forName: suite) ?? [:]), NSDictionary(dictionary: before))
    }

    func testExplicitScreenChoicesWriteOnlyTheirNewKeyAndPreserveFaceAndNightPreferences() {
        let suite = "HomePadScreenBehaviorChoiceTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for automatic in [false, true] {
            for keepAwake in [false, true] {
                defaults.set(automatic, forKey: "display.automaticStandby")
                defaults.set(keepAwake, forKey: "keepAwake")
                defaults.set(true, forKey: "display.faceWake")
                defaults.set(1, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
                defaults.set("automatic", forKey: "display.nightMode")
                defaults.set(22, forKey: "display.nightStartHour")
                defaults.set(7, forKey: "display.nightEndHour")
                defaults.removeObject(forKey: DisplayScreenBehaviorPolicy.preferenceKey)
                let original = defaults.persistentDomain(forName: suite) ?? [:]
                let legacy = DisplayScreenBehaviorPolicy(defaults: defaults)
                for mode in DisplayScreenBehavior.allCases {
                    let selected = legacy.selecting(mode, defaults: defaults)
                    XCTAssertEqual(selected.explicitMode, mode)
                    XCTAssertEqual(selected.selection, mode)
                    XCTAssertEqual(selected.automaticStandby, mode == .idleClock)
                    XCTAssertEqual(selected.keepAwakeIntent, mode != .followSystem)
                    for motion in [false, true] {
                        XCTAssertEqual(selected.disablesIdleTimer(active: true, standby: false, motionAvailable: motion), mode != .followSystem)
                    }
                    let restored = DisplayScreenBehaviorPolicy(defaults: defaults)
                    XCTAssertEqual(restored.explicitMode, mode)
                    var remaining = defaults.persistentDomain(forName: suite) ?? [:]
                    remaining.removeValue(forKey: DisplayScreenBehaviorPolicy.preferenceKey)
                    XCTAssertEqual(NSDictionary(dictionary: remaining), NSDictionary(dictionary: original))
                    XCTAssertTrue(DisplayFaceCapturePolicy(defaults: defaults).continuousAllowed)
                    XCTAssertEqual(defaults.string(forKey: "display.nightMode"), "automatic")
                    XCTAssertEqual(defaults.integer(forKey: "display.nightStartHour"), 22)
                    XCTAssertEqual(defaults.integer(forKey: "display.nightEndHour"), 7)
                }
            }
        }
        XCTAssertEqual(DisplayNightMode.automatic.rawValue, "automatic", "Scheduled is a label change, not a preference migration")
    }

    func testScreenBehaviorBackgroundPreviewAndPresentationRulesStayIndependent() {
        for mode in DisplayScreenBehavior.allCases {
            let policy = DisplayScreenBehaviorPolicy(explicitMode: mode, legacyAutomaticStandby: true, legacyKeepAwake: true)
            for motion in [false, true] {
                XCTAssertTrue(policy.disablesIdleTimer(active: true, standby: true, motionAvailable: motion), "A manual clock preview stays awake even in Follow system")
                XCTAssertFalse(policy.disablesIdleTimer(active: false, standby: true, motionAvailable: motion))
                XCTAssertFalse(policy.automaticEntryEnabled(active: false, suspended: false, motionAvailable: motion))
                XCTAssertFalse(policy.automaticEntryEnabled(active: true, suspended: true, motionAvailable: motion))
                // Playback/display 05: explicit V1 modes now follow the user's
                // idle choice, including Keep display and absent motion hardware.
                // Legacy flag behavior remains asserted separately above.
                XCTAssertEqual(policy.automaticEntryEnabled(active: true, suspended: false, motionAvailable: motion), mode != .followSystem)
            }
        }
    }

    func testExplicitV1ChoicesUseOnlyIdleWhileLegacyKeepsTheUprightBoundary() {
        var activity = DisplayStandbyPolicy(now: start)
        // The app can be flat, with no sensor data at all, or with motion.
        // These are not reasons to defeat an explicit wall-display idle timer.
        activity.sample(gravityZ: 1, acceleration: 0.2, rotation: 0.7, at: start.addingTimeInterval(10))
        for mode in [DisplayScreenBehavior.keepDisplay, .idleClock] {
            let policy = DisplayScreenBehaviorPolicy(explicitMode: mode, legacyAutomaticStandby: false, legacyKeepAwake: false)
            XCTAssertFalse(policy.requiresUprightForEntry)
            XCTAssertEqual(policy.keepsCurrentPageOnEntry, mode == .keepDisplay)
            for motion in [false, true] {
                XCTAssertFalse(policy.shouldEnter(activity: activity, at: start.addingTimeInterval(29), delay: 30, active: true, suspended: false, motionAvailable: motion))
                XCTAssertTrue(policy.shouldEnter(activity: activity, at: start.addingTimeInterval(30), delay: 30, active: true, suspended: false, motionAvailable: motion))
                XCTAssertFalse(policy.shouldEnter(activity: activity, at: start.addingTimeInterval(30), delay: 30, active: true, suspended: true, motionAvailable: motion))
                XCTAssertFalse(policy.shouldEnter(activity: activity, at: start.addingTimeInterval(30), delay: 30, active: false, suspended: false, motionAvailable: motion))
            }
        }
        let legacy = DisplayScreenBehaviorPolicy(explicitMode: nil, legacyAutomaticStandby: true, legacyKeepAwake: true)
        XCTAssertTrue(legacy.requiresUprightForEntry)
        XCTAssertFalse(legacy.keepsCurrentPageOnEntry)
        for motion in [false, true] {
            XCTAssertFalse(legacy.shouldEnter(activity: activity, at: start.addingTimeInterval(300), delay: 30, active: true, suspended: false, motionAvailable: motion))
        }
        let system = DisplayScreenBehaviorPolicy(explicitMode: .followSystem, legacyAutomaticStandby: true, legacyKeepAwake: true)
        XCTAssertFalse(system.shouldEnter(activity: activity, at: start.addingTimeInterval(300), delay: 30, active: true, suspended: false, motionAvailable: true))
    }

    func testIdleEntryHonorsInteractionPresenceClockReversalAndInvalidDelays() {
        var policy = DisplayStandbyPolicy(now: start)
        XCTAssertTrue(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(30), delay: 30))
        for invalid in [0.0, -1, .infinity, .nan] {
            XCTAssertFalse(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(300), delay: invalid))
        }
        XCTAssertFalse(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(-1), delay: 30))
        policy.noteFacePresence(at: start.addingTimeInterval(20))
        XCTAssertFalse(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(49), delay: 30))
        XCTAssertTrue(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(50), delay: 30))
        policy.interact(at: start.addingTimeInterval(50))
        XCTAssertFalse(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(79), delay: 30))
        XCTAssertTrue(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(80), delay: 30))
        policy.reset(at: start.addingTimeInterval(81))
        XCTAssertNil(policy.lastFacePresence)
        XCTAssertFalse(policy.shouldEnterAfterIdle(at: start.addingTimeInterval(110), delay: 30))
    }

    @MainActor func testKeepDisplayDimsTheCurrentPageAndTouchStartsAFullNewIdleDelay() {
        let fixture = DisplayTestSystem(now: start)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        defer { display.setActive(false) }
        display.setActive(true)
        XCTAssertTrue(fixture.idleDisabled)
        XCTAssertEqual(fixture.brightness, 0.8, accuracy: 0.0001)
        for second in 1...29 {
            fixture.now = start.addingTimeInterval(Double(second))
            display.evaluateIdle(at: fixture.now)
            XCTAssertFalse(display.isStandby, "Timer ticks, playing music and its progress must not reset or bypass inactivity")
        }
        fixture.now = start.addingTimeInterval(30)
        display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.isStandby)
        XCTAssertTrue(display.standbyKeepsCurrentPage)
        XCTAssertEqual(fixture.brightness, 0.24, accuracy: 0.0001)
        display.noteInteraction()
        XCTAssertFalse(display.isStandby)
        XCTAssertFalse(display.standbyKeepsCurrentPage)
        XCTAssertEqual(fixture.brightness, 0.8, accuracy: 0.0001)
        fixture.now = start.addingTimeInterval(59)
        display.evaluateIdle(at: fixture.now)
        XCTAssertFalse(display.isStandby)
        fixture.now = start.addingTimeInterval(60)
        display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.standbyKeepsCurrentPage)
    }

    @MainActor func testIdleClockEntryAndBothModesRestoreActualSystemStateOnBackground() {
        for mode in [DisplayScreenBehavior.keepDisplay, .idleClock] {
            for initialIdle in [false, true] {
                let fixture = DisplayTestSystem(now: start, idleDisabled: initialIdle)
                let defaults = isolatedDefaults()
                defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
                configureDisplayDefaults(defaults, mode: mode)
                let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
                display.setActive(true)
                fixture.now = start.addingTimeInterval(30)
                display.evaluateIdle(at: fixture.now)
                XCTAssertTrue(display.isStandby)
                XCTAssertEqual(display.standbyKeepsCurrentPage, mode == .keepDisplay)
                display.setActive(false)
                XCTAssertFalse(display.isStandby)
                XCTAssertFalse(display.standbyKeepsCurrentPage)
                XCTAssertEqual(fixture.brightness, 0.8, accuracy: 0.0001)
                XCTAssertEqual(fixture.idleDisabled, initialIdle)
                fixture.now = start.addingTimeInterval(300)
                display.evaluateIdle(at: fixture.now)
                XCTAssertFalse(display.isStandby, "A late timer event cannot reenter in the background")
                display.setActive(true)
                display.evaluateIdle(at: fixture.now)
                XCTAssertFalse(display.isStandby, "Foreground resume starts a fresh idle window")
                display.setActive(false)
                XCTAssertEqual(fixture.idleDisabled, initialIdle)
            }
        }
    }

    @MainActor func testModalPresentationWakesAndSuspendsThenRestartsInactivity() {
        let fixture = DisplayTestSystem(now: start)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        defer { display.setActive(false) }
        display.setActive(true)
        fixture.now = start.addingTimeInterval(30); display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.isStandby)
        display.setPresentationSuspended(true)
        XCTAssertFalse(display.isStandby)
        XCTAssertEqual(fixture.brightness, 0.8, accuracy: 0.0001)
        fixture.now = start.addingTimeInterval(300); display.evaluateIdle(at: fixture.now)
        XCTAssertFalse(display.isStandby)
        display.setPresentationSuspended(false)
        fixture.now = start.addingTimeInterval(329); display.evaluateIdle(at: fixture.now)
        XCTAssertFalse(display.isStandby)
        fixture.now = start.addingTimeInterval(330); display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.standbyKeepsCurrentPage)
    }

    @MainActor func testNightDimmingNeverRaisesAnAlreadyDarkScreenAndModeChangeRestoresIt() {
        let fixture = DisplayTestSystem(now: start, brightness: 0.04)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        defaults.set("on", forKey: "display.nightMode")
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        defer { display.setActive(false) }
        display.setActive(true)
        fixture.now = start.addingTimeInterval(30); display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.standbyKeepsCurrentPage)
        XCTAssertEqual(fixture.brightness, 0.04, accuracy: 0.0001)
        display.selectScreenBehavior(.followSystem)
        XCTAssertFalse(display.isStandby)
        XCTAssertFalse(display.standbyKeepsCurrentPage)
        XCTAssertEqual(fixture.brightness, 0.04, accuracy: 0.0001)
        XCTAssertFalse(fixture.idleDisabled)
        fixture.now = start.addingTimeInterval(300); display.evaluateIdle(at: fixture.now)
        XCTAssertFalse(display.isStandby)
    }

    @MainActor func testRestoredV1ChoicesDoNotChangeStoredFaceNightOrLegacyPreferences() {
        let fixture = DisplayTestSystem(now: start)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        defaults.set(true, forKey: "display.faceWake")
        defaults.set(0, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
        let original = defaults.persistentDomain(forName: defaultsSuite(defaults)) ?? [:]
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        XCTAssertTrue(display.hasExplicitScreenBehavior)
        XCTAssertFalse(display.usesLegacyMotionStandby)
        XCTAssertTrue(display.faceWake)
        XCTAssertFalse(display.faceForegroundConsent)
        XCTAssertEqual(NSDictionary(dictionary: defaults.persistentDomain(forName: defaultsSuite(defaults)) ?? [:]), NSDictionary(dictionary: original))
        defaults.removeObject(forKey: DisplayScreenBehaviorPolicy.preferenceKey)
        defaults.set(true, forKey: "display.automaticStandby")
        let legacy = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        XCTAssertFalse(legacy.hasExplicitScreenBehavior)
        XCTAssertTrue(legacy.usesLegacyMotionStandby)
    }

    @MainActor func testManualPreviewStillShowsTheSelectedStandbyContentInKeepDisplayMode() async {
        let fixture = DisplayTestSystem(now: start)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        defer { display.setActive(false) }
        display.setActive(true)
        let entered = expectation(description: "manual preview entered")
        let observation = display.$isStandby.dropFirst().filter { $0 }.sink { _ in entered.fulfill() }
        defer { observation.cancel() }
        display.previewStandby()
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(display.isStandby)
        XCTAssertFalse(display.standbyKeepsCurrentPage, "Preview is an explicit look at clock/photos, not automatic current-page dimming")
        display.noteInteraction()
        XCTAssertFalse(display.isStandby)
        XCTAssertEqual(fixture.brightness, 0.8, accuracy: 0.0001)
    }

    @MainActor func testPresence09UsesThirtySecondsWithoutRewritingTheConfiguredIdleDelay() {
        // The integration target is an iPad Simulator, whose faceAvailable is
        // false. The policy state is seeded without any camera permission call.
        let fixture = DisplayTestSystem(now: start)
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite(defaults)) }
        configureDisplayDefaults(defaults, mode: .keepDisplay)
        defaults.set(300.0, forKey: "display.standbyDelay")
        defaults.set(true, forKey: "display.faceWake")
        defaults.set(1, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
        let display = DisplayCoordinator(defaults: defaults, now: start, system: fixture.access, clock: { fixture.now })
        defer { display.setActive(false) }
        display.setActive(true)
        fixture.now = start.addingTimeInterval(29)
        display.evaluateIdle(at: fixture.now)
        XCTAssertFalse(display.isStandby)
        fixture.now = start.addingTimeInterval(30)
        display.evaluateIdle(at: fixture.now)
        XCTAssertTrue(display.isStandby, "Explicit App-managed mode and independently consented presence must use 30 seconds, not the saved 300-second idle delay")
        XCTAssertEqual(display.standbyDelay, 300)
        XCTAssertEqual(defaults.double(forKey: "display.standbyDelay"), 300, "The user's ordinary idle preference must not be rewritten")
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "HomePadDisplay05Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        // This test-only registration identifies the suite without touching the
        // global standard defaults or writing an extra app preference key.
        defaults.set(name, forKey: "test.suiteName")
        return defaults
    }
    private func defaultsSuite(_ defaults: UserDefaults) -> String { defaults.string(forKey: "test.suiteName")! }
    private func configureDisplayDefaults(_ defaults: UserDefaults, mode: DisplayScreenBehavior) {
        defaults.set(mode.rawValue, forKey: DisplayScreenBehaviorPolicy.preferenceKey)
        defaults.set(30.0, forKey: "display.standbyDelay")
        defaults.set(false, forKey: "display.motionWake")
        defaults.set(false, forKey: "display.automaticStandby")
        defaults.set(false, forKey: "display.faceWake")
        defaults.set(false, forKey: "display.proximityWake")
        defaults.set("off", forKey: "display.nightMode")
    }

}


@MainActor private final class DisplayTestSystem {
    var now: Date
    var brightness: CGFloat
    var idleDisabled: Bool
    init(now: Date, brightness: CGFloat = 0.8, idleDisabled: Bool = false) {
        self.now = now; self.brightness = brightness; self.idleDisabled = idleDisabled
    }
    var access: DisplaySystemAccess {
        DisplaySystemAccess(brightness: { self.brightness }, setBrightness: { self.brightness = $0 },
                            idleTimerDisabled: { self.idleDisabled }, setIdleTimerDisabled: { self.idleDisabled = $0 })
    }
}
