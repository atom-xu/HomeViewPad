import SwiftUI

struct StandbyDisplayView: View {
    @ObservedObject var coordinator: DisplayCoordinator
    var demoDate: Date? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var clockColor: Color {
        coordinator.nightActive ? Color(red: 0.65, green: 0.19, blue: 0.08) : Color.white.opacity(0.82)
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let date = demoDate ?? context.date
                Button { coordinator.noteInteraction() } label: {
                    VStack(spacing: 24) {
                        HStack(spacing: 8) {
                            Image(systemName: coordinator.nightActive ? "moon.stars" : "ipad.landscape")
                            Text("Standby display".tr)
                            if demoDate != nil {
                                Text("DEMO".tr).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                                    .overlay(Capsule().stroke(clockColor.opacity(0.5)))
                                    .accessibilityIdentifier("standbyDemoBadge")
                            }
                        }.font(.title3).foregroundStyle(clockColor.opacity(0.8))
                        Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().locale(L10n.locale))
                            .font(.system(size: min(geometry.size.width * 0.23, geometry.size.height * 0.43, 300), weight: .ultraLight, design: .rounded))
                            .monospacedDigit().minimumScaleFactor(0.3).lineLimit(1)
                            .foregroundStyle(clockColor)
                            .accessibilityIdentifier("standbyClock")
                        Text(date, format: .dateTime.weekday(.wide).month(.wide).day().locale(L10n.locale))
                            .font(dynamicTypeSize.isAccessibilitySize ? .body : .title2)
                            .multilineTextAlignment(.center).foregroundStyle(clockColor.opacity(0.8))
                        Text("Tap anywhere to wake".tr).font(.footnote).foregroundStyle(clockColor.opacity(0.6))
                    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Wake display".tr)
                    .accessibilityValue((demoDate != nil ? "DEMO".tr + " · " : "") + date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().locale(L10n.locale)))
                    .accessibilityIdentifier("standbyWake")
            }
        }.background(Color.black.opacity(coordinator.nightActive ? 0.74 : 0.32)).ignoresSafeArea()
            .accessibilityElement(children: .contain).accessibilityIdentifier("standbyDisplay")
            .accessibilityAction(named: "Wake display".tr) { coordinator.noteInteraction() }
    }
}
