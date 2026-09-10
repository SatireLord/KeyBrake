import KeyBrakeCore
import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("KeyBrake Recovery", systemImage: "shield.lefthalf.filled")
                .font(.title2.weight(.semibold))
            Text("Current state: \(stateText)")
                .font(.headline)
            Text("KeyBrake can restore network and sharing state that KeyBrake changed. macOS requires you to grant reset privacy permissions again; KeyBrake cannot silently restore those grants.")
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
            Button("Open Incident Log") { openWindow(id: "incidents") }
            Divider()
            HStack {
                Button("Keep Isolation") { dismiss() }
                Button("Quit KeyBrake") { NSApplication.shared.terminate(nil) }
            }
            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 470)
    }

    private var stateText: String {
        switch model.operationalState {
        case .isolated: return "Network Isolated"
        case .partiallyIsolated: return "Partial Isolation"
        case .recoveryRequired: return "Recovery Required"
        default: return model.operationalState.rawValue
        }
    }
}
