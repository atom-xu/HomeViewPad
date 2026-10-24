import SwiftUI
import UIKit

struct AgendaView: View {
    @ObservedObject var store: AgendaStore
    let demo: Bool
    @Binding var enabled: Bool
    var canAddToHome = false
    var addToHome: () -> Void = {}
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase

    var body: some View {
        List {
            if demo {
                Section {
                    Label("DEMO · No calendar is connected".tr, systemImage: "calendar.badge.exclamationmark")
                    Text("Leave demo mode to connect your calendar.".tr).foregroundStyle(.secondary)
                }
            } else if !enabled || store.state != .ready {
                Section {
                    Label("Your upcoming events".tr, systemImage: "calendar")
                        .font(.title2.weight(.semibold))
                    Text("Show the next 7 days from this iPad’s calendars on HomePad. Anyone looking at this screen can see event titles.".tr)
                        .foregroundStyle(.secondary)
                    if store.state == .connecting {
                        ProgressView("Connecting…".tr)
                        Button("Cancel".tr) { enabled = false; store.disconnect() }
                            .accessibilityIdentifier("cancelCalendarConnection")
                    } else {
                        connectionAction
                    }
                    if let error = store.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                }
            } else {
                Section("Next 7 days".tr) {
                    if store.events.isEmpty {
                        Label("Nothing in the next 7 days".tr, systemImage: "calendar.badge.checkmark")
                    }
                    ForEach(store.events) { event in
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.start.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)))
                                    .font(.subheadline.weight(.semibold))
                                Text(event.timeLabel).font(.subheadline).foregroundStyle(.secondary)
                            }.frame(minWidth: 120, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.headline)
                                Text(event.calendar).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 8)
                    }
                }
                Section {
                    if canAddToHome {
                        Button("Add calendar to Home".tr, action: addToHome).accessibilityIdentifier("addCalendarToHome")
                    }
                    Button("Refresh calendar".tr) { store.refresh() }.accessibilityIdentifier("refreshCalendar")
                }
            }
            if !demo {
                if enabled && store.state != .connecting {
                    Section {
                        Button("Hide calendar on HomePad".tr, role: .destructive) { enabled = false; store.disconnect() }
                            .accessibilityIdentifier("hideCalendar")
                    }
                }
                Section {
                    Text("HomePad only reads events. iPadOS calls this permission Full Access; HomePad never changes your calendars.".tr)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("agendaPage")
        .task { store.setDemo(demo); store.setEnabled(enabled); store.refresh() }
        .onChange(of: demo) { _, value in store.setDemo(value) }
        .onChange(of: enabled) { _, value in store.setEnabled(value) }
        .onChange(of: phase) { _, value in store.setActive(value == .active) }
    }

    @ViewBuilder private var connectionAction: some View {
        switch store.state {
        case .denied:
            Text("Calendar access is off. Allow Full Access in iPad Settings, then return here.".tr).foregroundStyle(.secondary)
            Button("Open iPad Settings".tr) { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                .accessibilityIdentifier("calendarSettings")
            Button("Try again".tr) { enabled = true; store.connect() }.accessibilityIdentifier("connectCalendar")
        case .restricted:
            Text("Calendar access is restricted by this iPad’s settings.".tr).foregroundStyle(.secondary)
        default:
            Button("Connect calendar".tr) { enabled = true; store.connect() }
                .accessibilityIdentifier("connectCalendar")
        }
    }
}
