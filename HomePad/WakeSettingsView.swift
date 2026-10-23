import SwiftUI
import UIKit
import AVFoundation

struct WakeSettingsView: View {
    @ObservedObject var coordinator: DisplayCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Form {
            Section {
                Text("Tap the standby screen to return to HomePad. You can also enable the options below.".tr)
                    .font(.callout)
            }
            Section("Move iPad".tr) {
                Toggle("Move iPad to return".tr, isOn: Binding(get: { coordinator.motionWake }, set: coordinator.setMotionWake))
                    .disabled(!coordinator.motionAvailable && !coordinator.motionWake).accessibilityIdentifier("motionWake")
                if !coordinator.motionAvailable {
                    Text("Motion sensors are unavailable on this device.".tr).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("A face comes into view".tr) {
                Toggle("Use the front camera to return".tr, isOn: Binding(get: { coordinator.faceWake }, set: coordinator.setFaceWake))
                    .disabled(!coordinator.faceAvailable && !coordinator.faceWake).accessibilityIdentifier("faceWake")
                Text("The front camera detects a face without identifying anyone. No images are saved or sent.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
                if !coordinator.faceAvailable {
                    Text("Front camera detection is unavailable on this device.".tr).font(.footnote).foregroundStyle(.secondary)
                } else if cameraAuthorization == .denied || cameraAuthorization == .restricted {
                    Text("Camera access is off. Change it in iPad Settings.".tr)
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(action: openPermissionSettings) {
                        rowLabel("Camera permission settings".tr)
                    }.buttonStyle(.plain).accessibilityIdentifier("facePermissionSettings")
                } else if cameraAuthorization == .notDetermined {
                    Text("Turn this on to ask for camera access.".tr).font(.footnote).foregroundStyle(.secondary)
                }
                if coordinator.faceWake {
                    Text("Optional: also use the camera on other HomePad pages. A person in view delays standby; Auto-Lock still follows your display setting. The camera indicator stays visible; menus and the background pause detection. No identity recognition, recordings, saved images or uploads. Turn this off at any time.".tr)
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("faceForegroundConsentDisclosure")
                    Toggle("Also detect faces on other pages".tr, isOn: Binding(get: { coordinator.faceForegroundConsent }, set: coordinator.setFaceForegroundConsent))
                        .disabled(!coordinator.faceAvailable && !coordinator.faceForegroundConsent).accessibilityIdentifier("faceForegroundConsent")
                    if !coordinator.faceForegroundConsent {
                        Text("Without continuous detection, the camera runs only in standby. A person remaining in view may see standby start and wake again.".tr)
                            .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("faceStandbyOnlyDisclosure")
                    }
                }
            }
            Section {
                DisclosureGroup {
                    Toggle("Use supported proximity sensor".tr, isOn: Binding(get: { coordinator.proximityWake }, set: coordinator.setProximityWake))
                        .accessibilityIdentifier("proximityWake")
                    Text(coordinator.proximityStatus).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("proximityStatus")
                    Text("Only devices exposing a proximity sensor can use it. Uncovering that sensor returns to the app. Generic infrared sensing is not available through public iPad APIs.".tr)
                        .font(.footnote).foregroundStyle(.secondary)
                } label: {
                    Text("More wake options".tr).accessibilityIdentifier("wakeMoreOptions")
                }
                DisclosureGroup {
                    Text(coordinator.motionStatus).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("motionStatus")
                    Text(coordinator.faceStatus).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("faceStatus")
                } label: {
                    Text("Detection status".tr).accessibilityIdentifier("wakeDetectionStatus")
                }
            }
            Section {
                Text("Wake detection restores this app's display only; it cannot unlock or wake a system-locked iPad.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Return from standby".tr).accessibilityIdentifier("wakeSettingsPage")
            .onAppear(perform: refreshPermission)
            .onChange(of: coordinator.faceStatus) { _, _ in refreshPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshPermission() }
            }
    }

    private func refreshPermission() {
        cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func openPermissionSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
}
