import SwiftUI

struct AccessoryAdjustmentView: View {
    @ObservedObject var home: HomeStore
    let id: UUID
    @State private var requestedValue: Double?
    var body: some View {
        Form {
            if let tile = home.tiles.first(where: { $0.id == id }), let bounds = tile.adjustment, let current = tile.number {
                Section(tile.name) {
                    Text("\(tile.room) · \(tile.value)")
                    Stepper(value: Binding(get: { requestedValue ?? current }, set: { requestedValue = $0 }), in: bounds.minimum...bounds.maximum, step: bounds.step) {
                        Text("Set to \(tile.kind.formatted(requestedValue ?? current))")
                    }.disabled(!tile.writable || home.busy.contains(id))
                    Button("Apply to accessory") { home.adjust(id, to: requestedValue ?? current) }
                        .disabled(!tile.writable || home.busy.contains(id) || requestedValue == nil || !bounds.accepts(requestedValue ?? current))
                    if home.busy.contains(id) { ProgressView("Updating accessory…") }
                    Text("Allowed range: \(tile.kind.formatted(bounds.minimum)) – \(tile.kind.formatted(bounds.maximum)). Current status updates after the accessory responds.").font(.footnote)
                }
            } else {
                Text("This accessory is unavailable. Close this panel and refresh your home.")
            }
            if let error = home.error { Section("HomeKit response") { Text(error).foregroundStyle(.red) } }
        }.foregroundStyle(.primary)
    }
}
