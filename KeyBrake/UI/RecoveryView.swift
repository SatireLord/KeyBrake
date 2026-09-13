import KeyBrakeCore
import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("KeyBrake Recovery", systemImage: "shield.lefthalf.filled")
                .font(.title2.weight(.semibold))
            Text("Current state: \(model.operationalState.displayTitle)")
                .font(.headline)
            Text("KeyBrake can restore network and sharing state that KeyBrake changed. Privacy grants that were reset must be granted again in System Settings; KeyBrake never restores those grants automatically.")
                .foregroundStyle(.secondary)
            Divider()
            Button("Restore Network") { model.restoreNetworkOnly() }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
            Button("Restore Previously Enabled Sharing Services") {
                model.restoreSharingOnly()
            }
            .disabled(model.isBusy)
            Button("Restart Espanso") { model.restartEspanso() }
                .disabled(model.isBusy)
            Button("Open Privacy & Security Settings") { model.openPrivacySettings() }
            Button("Open Incident Log") {
                openWindow(id: "incidents")
            }
            Divider()
            HStack {
                Button("Keep Isolation") { model.keepIsolation() }
                Button("Quit KeyBrake") { model.requestQuit() }
            }
            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 470)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("KeyBrake Recovery")
    }
}
