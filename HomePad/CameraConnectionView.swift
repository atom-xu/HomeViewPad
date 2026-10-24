import SwiftUI
import HomeKit
import UIKit

struct CameraConnectionView: View {
    @ObservedObject var home: HomeStore
    @Binding var selection: HMAccessory?

    var body: some View {
        Group {
            if home.demo { CameraSheet(accessory: nil, demo: true) }
            else if home.selectedHomeID == nil {
                VStack(spacing: 20) {
                    ContentUnavailableView("Connect your home first".tr, systemImage: "house", description: Text("Cameras come from the Apple Home household you select.".tr))
                    if home.status == .loading { ProgressView("Finding your home…".tr) }
                    else {
                        Button("Connect Apple Home".tr) { home.connect() }.buttonStyle(.borderedProminent)
                    }
                    if home.status == .denied {
                        Button("Open iPad Settings".tr) { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                    }
                }.padding(28)
            } else if home.cameras.isEmpty {
                VStack(spacing: 20) {
                    ContentUnavailableView("No compatible cameras".tr, systemImage: "video.slash", description: Text("Add a compatible camera in Apple Home, then refresh here.".tr))
                    Text(home.homeName).font(.headline)
                    Button("Refresh cameras".tr) { home.refresh() }.buttonStyle(.borderedProminent).accessibilityIdentifier("refreshCameras")
                    Text("Viewing a home camera uses Home access, not this iPad’s front camera.".tr).font(.footnote).foregroundStyle(.secondary)
                }.padding(28)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(home.homeName).font(.headline)
                        Picker("Camera".tr, selection: $selection) {
                            Text("Choose a camera".tr).tag(Optional<HMAccessory>.none)
                            ForEach(home.cameras, id: \.uniqueIdentifier) { Text($0.name).tag(Optional($0)) }
                        }.pickerStyle(.menu).accessibilityIdentifier("connectedCameraPicker")
                        Spacer()
                        Button("Refresh".tr) { home.refresh() }
                    }.padding()
                    if let selection { CameraSheet(accessory: selection, demo: false).id(selection.uniqueIdentifier) }
                    else {
                        ContentUnavailableView("Choose a camera".tr, systemImage: "video", description: Text("Choose a camera to start live view.".tr))
                    }
                }
            }
        }
        .accessibilityIdentifier("cameraConnection")
        .onAppear { resolveSelection() }
        .onChange(of: home.cameras.map(\.uniqueIdentifier)) { _, _ in resolveSelection() }
    }

    private func resolveSelection() {
        if let selection, !home.cameras.contains(where: { $0.uniqueIdentifier == selection.uniqueIdentifier }) { self.selection = nil }
    }
}

/// A landscape camera cell stays in its row. It never uses a sample image for
/// a missing feed and captures neither the iPad camera nor microphone.
struct SidebarCameraCard: View {
    let accessory: HMAccessory?
    @ObservedObject var snapshots: CameraSnapshotStore
    let title: String
    let demo: Bool
    let active: Bool
    let width: CGFloat
    let height: CGFloat
    let open: () -> Void
    @State private var consumerID = UUID()
    @State private var registeredCameraID: UUID?
    @State private var onScreen = false
    private var status: String {
        if demo { return "Demo · no live feed".tr }
        guard let accessory else { return "Choose a camera".tr }
        guard accessory.isReachable else { return "Camera offline".tr }
        guard active else { return "Camera paused".tr }
        return snapshots.message(for: accessory.uniqueIdentifier).tr
    }

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .bottomLeading) {
                if let id = accessory?.uniqueIdentifier, let snapshot = snapshots.snapshot(for: id), !demo {
                    Color.black
                    HomeCameraView(snapshot: snapshot).aspectRatio(16 / 9, contentMode: .fit).frame(width: width, height: height)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.fill").font(.system(size: 38))
                        Text(status)
                            .font(.subheadline).multilineTextAlignment(.center).lineLimit(3)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).lineLimit(1)
                    if let id = accessory?.uniqueIdentifier, snapshots.snapshot(for: id) != nil, !demo {
                        Text(status).font(.caption).lineLimit(2)
                    }
                }.padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accessory.flatMap { snapshots.snapshot(for: $0.uniqueIdentifier) } != nil && !demo ? .black.opacity(0.5) : .clear)
            }.frame(width: width, height: height).contentShape(Rectangle()).clipShape(RoundedRectangle(cornerRadius: 30))
                .modifier(GlassSurface(radius: 30))
        }.buttonStyle(.plain).accessibilityLabel(title)
            .accessibilityValue(status)
            .background {
                GeometryReader { geometry in
                    let visible = geometry.frame(in: .global).intersects(UIScreen.main.bounds)
                    Color.clear.onAppear { updateVisibility(visible) }
                        .onChange(of: visible) { _, value in updateVisibility(value) }
                }
            }
            .onAppear(perform: updateSnapshot).onDisappear { onScreen = false; releaseSnapshot() }
            .onChange(of: active) { _, _ in updateSnapshot() }
            .onChange(of: accessory?.uniqueIdentifier) { _, _ in updateSnapshot() }
            .onChange(of: accessory?.isReachable) { _, _ in updateSnapshot() }
            .onChange(of: demo) { _, _ in updateSnapshot() }
            .onChange(of: snapshots.allowed) { _, _ in updateSnapshot() }
    }

    private func updateVisibility(_ value: Bool) { onScreen = value; updateSnapshot() }
    private func releaseSnapshot() {
        if let registeredCameraID {
            snapshots.setVisible(cameraID: registeredCameraID, profile: nil, consumerID: consumerID, visible: false)
            self.registeredCameraID = nil
        }
    }
    private func updateSnapshot() {
        guard active, onScreen, !demo, let accessory, accessory.isReachable else { releaseSnapshot(); return }
        if registeredCameraID != accessory.uniqueIdentifier { releaseSnapshot() }
        snapshots.setVisible(cameraID: accessory.uniqueIdentifier, profile: accessory.cameraProfiles?.first, consumerID: consumerID, visible: true)
        registeredCameraID = accessory.uniqueIdentifier
    }
}
