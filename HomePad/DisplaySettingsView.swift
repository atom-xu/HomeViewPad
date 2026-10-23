import SwiftUI

/// Section content for the settings hub's Display Form.
struct DisplaySettingsView: View {
    @ObservedObject var coordinator: DisplayCoordinator
    @AppStorage("display.standbyContent") private var standbyContent = "clock"
    var openPhotos: () -> Void = {}

    var body: some View {
        Section {
            ForEach(DisplayScreenBehavior.allCases, id: \.self) { behavior in
                Button { coordinator.selectScreenBehavior(behavior) } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(Self.title(for: behavior)).font(.headline)
                            Text(detail(for: behavior)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        if coordinator.screenBehaviorSelection == behavior {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor).accessibilityHidden(true)
                        }
                    }.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(coordinator.screenBehaviorSelection == behavior ? "Selected".tr : "")
                .accessibilityAddTraits(coordinator.screenBehaviorSelection == behavior ? .isSelected : [])
                .accessibilityIdentifier("screenBehavior-\(behavior.rawValue)")
            }
        } header: {
            Text("While HomePad is open".tr)
        } footer: {
            if !coordinator.hasExplicitScreenBehavior {
                Text("Choose a mode to apply its idle behavior. Until then, your previous display settings stay in use.".tr)
                    .accessibilityIdentifier("legacyDisplayBehavior")
            }
        }

        if coordinator.screenBehaviorSelection != .followSystem {
            Section {
                Picker("No activity for".tr, selection: Binding(get: { coordinator.standbyDelay }, set: coordinator.setStandbyDelay)) {
                    Text("30 seconds".tr).tag(30.0)
                    Text("1 minute".tr).tag(60.0)
                    Text("2 minutes".tr).tag(120.0)
                    Text("5 minutes".tr).tag(300.0)
                }.pickerStyle(.menu).accessibilityIdentifier("standbyDelay")
            } header: {
                Text("Idle timer".tr)
            } footer: {
                Text((coordinator.screenBehaviorSelection == .keepDisplay
                      ? "The current page dims after this time. The first touch restores brightness without activating a control. Music can keep playing."
                      : "The clock or photo wall appears after this time. The first touch returns to your page. Music can keep playing.").tr)
            }
        }

        Section {
            standbyContentPicker
            Button { coordinator.previewStandby() } label: {
                Text("Preview clock or photos".tr)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Color.accentColor).accessibilityIdentifier("standbyPreview")
        } header: {
            Text((coordinator.screenBehaviorSelection == .idleClock ? "Idle screen & preview" : "Clock & photo preview").tr)
        } footer: {
            Text((coordinator.screenBehaviorSelection == .idleClock
                  ? "Your selection is used for the idle screen and this manual preview."
                  : "This manual preview temporarily opens the clock or photo wall. It does not preview dimming the current page.").tr)
        }

        Section {
            Picker("Night dimming".tr, selection: Binding(get: { coordinator.nightMode }, set: coordinator.setNightMode)) {
                ForEach(DisplayNightMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }.pickerStyle(.segmented).accessibilityIdentifier("nightMode")
            if coordinator.nightMode == .automatic {
                Picker("Starts at".tr, selection: Binding(get: { coordinator.nightStartHour }, set: coordinator.setNightStartHour)) {
                    ForEach(0..<24) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }.pickerStyle(.menu).accessibilityIdentifier("nightStartHour")
                Picker("Ends at".tr, selection: Binding(get: { coordinator.nightEndHour }, set: coordinator.setNightEndHour)) {
                    ForEach(0..<24) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }.pickerStyle(.menu).accessibilityIdentifier("nightEndHour")
                if coordinator.nightStartHour == coordinator.nightEndHour {
                    Text("Choose different start and end times to enable the schedule.".tr).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text(coordinator.nightActive ? "Night mode is on.".tr : "Night mode is off.".tr)
                .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("nightModeStatus")
        } header: {
            Text("At night".tr)
        } footer: {
            Text("Use a lower brightness while HomePad is idle. Touch once to restore the previous brightness. Scheduled times follow this iPad's local time.".tr)
        }

        Section {
            Text("HomePad cannot unlock iPad or replace its lock screen. If iPad locks, unlock it manually to return.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    static func title(for behavior: DisplayScreenBehavior) -> String {
        switch behavior {
        case .followSystem: return "Follow iPad Auto-Lock".tr
        case .keepDisplay: return "Keep current page".tr
        case .idleClock: return "Switch to clock or photos".tr
        }
    }

    private func detail(for behavior: DisplayScreenBehavior) -> String {
        switch behavior {
        case .followSystem: return "iPad locks at its Auto-Lock time. Unlock it manually to return.".tr
        case .keepDisplay: return "Keep this page visible, dim when idle, and touch once to restore brightness.".tr
        case .idleClock: return "Show your clock or photo wall when idle. Touch once to return.".tr
        }
    }

    @ViewBuilder private var standbyContentPicker: some View {
        Picker((coordinator.screenBehaviorSelection == .idleClock ? "Show in standby" : "Preview content").tr, selection: $standbyContent) {
            Text("Clock".tr).tag("clock")
            Text("Photo wall".tr).tag("photos")
        }.pickerStyle(.menu).accessibilityIdentifier("standbyContent")
        if standbyContent == "photos" {
            Button(action: openPhotos) {
                Text("Choose photos and albums".tr)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Color.accentColor).accessibilityIdentifier("standbyPhotos")
            Text("Uses the independent Photos page, not the Home and Clock background photo.".tr)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
