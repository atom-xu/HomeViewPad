import SwiftUI

struct AccessoryAdjustmentView: View {
    @ObservedObject var home: HomeStore
    let id: UUID
    private var values: [HomeTile] { HomeAccessoryPresentation.details(for: id, in: home.tiles) }
    var body: some View {
        Form {
            if let tile = home.tiles.first(where: { $0.id == id }) {
                Section(home.demo ? tile.name.tr : tile.name) {
                    Label(home.demo ? tile.room.tr : tile.room, systemImage: tile.symbol)
                    Text(tile.reachable ? tile.value.tr : "Offline".tr).accessibilityIdentifier("accessoryDetailState")
                    if let power = values.first(where: { $0.kind == .power }) {
                        Button((power.isOn ? "Turn off" : "Turn on").tr) { home.toggle(power) }
                            .disabled(!power.writable || !power.reachable || home.busy.contains(power.id))
                            .accessibilityIdentifier("accessoryDetailPower")
                    }
                }
                ForEach(values.filter { $0.kind.adjustable }) { value in AccessoryValueControl(home: home, tile: value) }
                let readings = values.filter { $0.kind != .power && !$0.kind.adjustable }
                if !readings.isEmpty {
                    Section("Status".tr) {
                        ForEach(readings) { value in LabeledContent(value.kind.title, value: value.value.tr) }
                    }
                }
                if values.allSatisfy({ !$0.kind.adjustable }) {
                    Text("Only the controls supported by this accessory appear here.".tr).font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("This accessory is unavailable. Close this panel and refresh your home.".tr)
            }
            if let error = home.error { Section("HomeKit response".tr) { Text(error).foregroundStyle(.red) } }
        }.foregroundStyle(.primary).accessibilityIdentifier("accessoryDetails")
    }
}

private struct AccessoryValueControl: View {
    @ObservedObject var home: HomeStore
    let tile: HomeTile
    @State private var requestedValue: Double?
    var body: some View {
        Section(tile.kind.title) {
            if let bounds = tile.adjustment, let current = tile.number {
                LabeledContent("Current".tr, value: tile.kind.formatted(current))
                Slider(value: Binding(get: { requestedValue ?? current }, set: { requestedValue = $0 }),
                       in: bounds.minimum...bounds.maximum, step: bounds.step)
                    .disabled(!tile.writable || !tile.reachable || home.busy.contains(tile.id))
                    .accessibilityLabel(tile.kind.title).accessibilityValue(tile.kind.formatted(requestedValue ?? current))
                    .accessibilityIdentifier("adjustment-\(tile.kind)")
                Text(L10n.format("Set to %@", tile.kind.formatted(requestedValue ?? current)))
                Button("Apply to accessory".tr) { home.adjust(tile.id, to: requestedValue ?? current) }
                    .disabled(!tile.writable || !tile.reachable || home.busy.contains(tile.id) || requestedValue == nil || !bounds.accepts(requestedValue ?? current))
                    .accessibilityIdentifier("applyAdjustment-\(tile.kind)")
                if home.busy.contains(tile.id) { ProgressView("Updating accessory…".tr) }
            } else { Text(tile.reachable ? tile.value.tr : "Offline".tr) }
        }
    }
}
