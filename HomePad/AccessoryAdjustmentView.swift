import SwiftUI
import HomeKit

/// Controls use only advertised capabilities. HomeStore owns writes and read-back.
struct AccessoryAdjustmentView: View {
    @ObservedObject var home: HomeStore
    let id: UUID
    private var values: [HomeTile] { HomeAccessoryPresentation.details(for: id, in: home.tiles) }
    var body: some View {
        ScrollView {
            if let tile = home.tiles.first(where: { $0.id == id }) {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(home.demo ? tile.name.tr : tile.name).font(.title.bold())
                            Text(home.demo ? tile.room.tr : tile.room).font(.title3).foregroundStyle(.secondary)
                            Text(tile.reachable ? tile.value.tr : "Offline".tr)
                                .font(.headline).foregroundStyle(tile.needsAttention ? Color.orange : .white)
                                .accessibilityIdentifier("accessoryDetailState")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if let power = home.quickToggle(for: tile) {
                            Button { home.toggle(power) } label: {
                                ZStack {
                                    Circle().fill(power.isOn ? Color.yellow : .white.opacity(0.12))
                                    if home.busy.contains(power.id) { ProgressView().tint(power.isOn ? .black : .white) }
                                    else { Image(systemName: tile.displaySymbol).font(.system(size: 30)).foregroundStyle(power.isOn ? .black : .white) }
                                }.frame(width: 64, height: 64)
                            }.buttonStyle(.plain).disabled(!home.canToggle(power))
                                .accessibilityLabel((power.isOn ? "Turn off" : "Turn on").tr)
                                .accessibilityValue(power.value.tr).accessibilityIdentifier("accessoryDetailPower")
                        } else {
                            Image(systemName: tile.displaySymbol).font(.system(size: 42, weight: .regular))
                                .foregroundStyle(tile.needsAttention ? Color.orange : .white)
                                .frame(width: 64, height: 64).accessibilityHidden(true)
                        }
                    }
                    ForEach(values.filter { $0.control == .range }) { value in
                        AccessoryValueControl(home: home, tile: value)
                    }
                    ForEach(values.filter { $0.control == .choice || $0.control == .command }) { value in
                        AccessoryOptionControl(home: home, tile: value)
                    }
                    ForEach(values.filter { $0.control == .toggle && $0.id != home.quickToggle(for: tile)?.id }) { value in
                        Toggle(isOn: Binding(get: { value.isOn }, set: { _ in home.toggle(value) })) {
                            Text(value.controlTitle)
                        }.tint(.yellow).disabled(!home.canToggle(value))
                            .accessibilityIdentifier("accessoryToggle-\(value.characteristicType ?? value.id.uuidString)")
                    }
                    VStack(spacing: 0) {
                        ForEach(values.filter { $0.control == .readOnly }) { value in
                            LabeledContent(value.controlTitle, value: value.value.tr)
                                .font(.body).padding(.vertical, 12)
                                .foregroundStyle(value.needsAttention ? Color.orange : .white)
                                .accessibilityIdentifier("accessoryReading-\(value.characteristicType ?? value.id.uuidString)")
                            if value.id != values.last?.id { Divider().overlay(.white.opacity(0.08)) }
                        }
                    }
                    if let error = home.error {
                        Text(error).foregroundStyle(.orange).accessibilityIdentifier("accessoryWriteError")
                    }
                    if let notice = home.notice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("accessoryCommandNotice")
                    }
                    if !home.demo {
                        Button("Refresh status".tr) { home.refresh() }.buttonStyle(.bordered)
                            .accessibilityIdentifier("accessoryRefresh")
                    }
                }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            } else {
                Text("This accessory is unavailable. Close this panel and refresh your home.".tr).padding(32)
            }
        }.foregroundStyle(.white)
            .background { Color.black.opacity(0.28).ignoresSafeArea() }
            .accessibilityElement(children: .contain).accessibilityIdentifier("accessoryDetails")
    }
}

private struct AccessoryOptionControl: View {
    @ObservedObject var home: HomeStore
    let tile: HomeTile
    @Environment(\.dynamicTypeSize) private var typeSize
    private var enabled: Bool { tile.writable && tile.reachable && !home.busy.contains(tile.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tile.control != .command || tile.options.count != 1 {
                Text(tile.controlTitle).font(.headline).foregroundStyle(.secondary)
            }
            if tile.options.isEmpty {
                Text(tile.value.tr).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: typeSize.isAccessibilitySize || tile.options.count == 1 ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                    ForEach(tile.options) { option in
                        let selected = tile.control != .command && tile.number == option.value
                        Button { home.setValue(tile.id, to: option.value) } label: {
                            HStack(spacing: 8) {
                                Text(option.title.tr).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                if selected { Image(systemName: "checkmark").font(.body.weight(.semibold)) }
                            }.padding(16).frame(maxWidth: .infinity, minHeight: 56)
                                .background(selected ? Color.white.opacity(0.22) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).disabled(!enabled || !tile.accepts(option.value))
                            .accessibilityValue(selected ? "Selected".tr : "")
                            .accessibilityIdentifier("accessoryOption-\(tile.characteristicType ?? tile.id.uuidString)-\(String(format: "%g", option.value))")
                    }
                }
            }
            if home.busy.contains(tile.id) { ProgressView("Updating accessory…".tr).tint(.white) }
        }.accessibilityElement(children: .contain)
    }
}

private struct AccessoryValueControl: View {
    @ObservedObject var home: HomeStore
    let tile: HomeTile
    @State private var draft: Double?
    @State private var submitted: Double?
    private var enabled: Bool { tile.writable && tile.reachable && !home.busy.contains(tile.id) }
    private var current: Double { tile.number ?? 0 }
    private var value: Double { draft ?? current }
    private var controlID: String { [.setting, .measurement, .state, .information, .event].contains(tile.kind) ? (tile.characteristicType ?? tile.id.uuidString) : String(describing: tile.kind) }

    var body: some View {
        VStack(spacing: 14) {
            Text(tile.controlTitle).font(.headline).foregroundStyle(.secondary)
            if let bounds = tile.adjustment, tile.number != nil {
                if tile.kind == .brightness || tile.characteristicType == HMCharacteristicTypeTargetPosition { brightness(bounds) }
                else {
                    Text(tile.formatted(value)).font(.system(size: 36, weight: .medium)).monospacedDigit()
                    HStack(spacing: 18) {
                        stepButton(increase: false, bounds: bounds)
                        Slider(value: Binding(get: { value }, set: { draft = bounds.snapped($0) }),
                               in: bounds.minimum...bounds.maximum, step: bounds.step,
                               onEditingChanged: { if !$0 { commit() } })
                            .tint(tile.kind == .colorTemperature ? .orange : .white)
                            .disabled(!enabled).accessibilityLabel(tile.controlTitle)
                            .accessibilityValue(tile.formatted(value))
                            .accessibilityIdentifier("adjustment-\(controlID)")
                        stepButton(increase: true, bounds: bounds)
                    }.padding(18).background(.white.opacity(0.08), in: Capsule())
                }
                if home.busy.contains(tile.id) { ProgressView("Updating accessory…".tr).tint(.white) }
                else if submitted != nil && draft != nil {
                    Button("Try again".tr) { commit() }.accessibilityIdentifier("retryAdjustment-\(controlID)")
                }
            } else { Text(tile.reachable ? tile.value.tr : "Offline".tr) }
        }
        .onChange(of: tile.number) { _, new in
            if let submitted, let new, abs(submitted - new) < 0.00001 { draft = nil; self.submitted = nil }
            else if submitted == nil { draft = nil }
        }
        .onChange(of: tile.reachable) { _, available in if !available { draft = nil; submitted = nil } }
        .onChange(of: tile.writable) { _, writable in if !writable { draft = nil; submitted = nil } }
    }

    private func commit() {
        guard enabled, let draft, let bounds = tile.adjustment else { return }
        let target = bounds.snapped(draft)
        guard abs(target - current) > 0.00001 else { self.draft = nil; submitted = nil; return }
        submitted = target
        home.adjust(tile.id, to: target)
    }
    private func stepButton(increase: Bool, bounds: HomeAdjustment) -> some View {
        Button {
            draft = bounds.snapped(value + (increase ? bounds.step : -bounds.step)); commit()
        } label: { Image(systemName: increase ? "plus" : "minus").font(.title3).frame(width: 44, height: 44) }
            .buttonStyle(.plain).disabled(!enabled || (increase ? value >= bounds.maximum : value <= bounds.minimum))
            .accessibilityLabel(L10n.format(increase ? "Increase %@" : "Decrease %@", tile.controlTitle))
    }
    private func brightness(_ bounds: HomeAdjustment) -> some View {
        let fraction = min(1, max(0, (value - bounds.minimum) / (bounds.maximum - bounds.minimum)))
        return VStack(spacing: 12) {
            Text(tile.formatted(value)).font(.system(size: 46, weight: .medium)).monospacedDigit()
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 36).fill(.white.opacity(0.12))
                    Rectangle().fill(.white).frame(height: geometry.size.height * fraction)
                    Image(systemName: tile.kind == .brightness ? "sun.max.fill" : tile.displaySymbol).font(.system(size: 32))
                        .foregroundStyle(fraction > 0.22 ? .black.opacity(0.65) : .white)
                        .frame(maxWidth: .infinity).padding(.bottom, 28)
                }.clipShape(RoundedRectangle(cornerRadius: 36)).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { event in
                            guard enabled else { return }
                            let progress = min(1, max(0, 1 - event.location.y / max(1, geometry.size.height)))
                            draft = bounds.snapped(bounds.minimum + Double(progress) * (bounds.maximum - bounds.minimum))
                        }.onEnded { _ in commit() })
                    .accessibilityElement(children: .ignore).accessibilityLabel(tile.controlTitle)
                    .accessibilityValue(tile.formatted(value))
                    .accessibilityAdjustableAction { direction in
                        guard enabled else { return }
                        draft = bounds.snapped(value + (direction == .increment ? bounds.step : -bounds.step)); commit()
                    }
                    .accessibilityIdentifier(tile.kind == .brightness ? "adjustment-brightness" : "adjustment-\(tile.characteristicType ?? "value")")
                    .opacity(tile.reachable ? 1 : 0.4)
            }.frame(width: 150, height: 240)
        }
    }
}
