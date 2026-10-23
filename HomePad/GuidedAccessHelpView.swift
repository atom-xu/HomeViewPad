import SwiftUI
import UIKit

struct GuidedAccessHelpView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var guidedAccessRunning = UIAccessibility.isGuidedAccessEnabled

    var body: some View {
        Form {
            Section {
                Text("Optional: keep HomePad open as a dedicated display. Set this up yourself in iPad Settings.".tr)
                    .font(.callout)
                LabeledContent("Guided Access".tr, value: guidedAccessRunning ? "Running".tr : "Not running".tr)
                    .accessibilityIdentifier("guidedAccessStatus")
            }
            Section("Setup".tr) {
                Text("1. In iPad Settings → Accessibility → Guided Access, turn it on and set an exit passcode.".tr)
                Text("2. Reopen HomePad, triple-click the top or Home button, then Start. Keep Touch and Motion enabled.".tr)
                Text("3. For continuous display, optionally set Guided Access → Display Auto-Lock to Never. Triple-click again and authenticate to exit.".tr)
                Link("Apple setup guide".tr, destination: URL(string: "https://support.apple.com/guide/ipad/ipada16d1374/ipados")!)
                    .accessibilityIdentifier("guidedAccessHelp")
            }
        }.navigationTitle("Dedicated iPad".tr).accessibilityIdentifier("guidedAccessHelpPage")
            .onAppear { guidedAccessRunning = UIAccessibility.isGuidedAccessEnabled }
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.guidedAccessStatusDidChangeNotification)) { _ in
                guidedAccessRunning = UIAccessibility.isGuidedAccessEnabled
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { guidedAccessRunning = UIAccessibility.isGuidedAccessEnabled }
            }
    }
}
