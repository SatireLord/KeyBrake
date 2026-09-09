import KeyBrakeCore
import SwiftUI

struct RecoveryView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var restoreSharing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("KeyBrake Recovery", systemImage: "shield.lefthalf.filled")
                .font(.title2.weight(.semibold))
            Text("Current state: \(stateText)")
                .font(.headline)
            Text("KeyBrake can restore network and sharing state that KeyBrake changed. macOS requires you to grant reset privacy permissions again; KeyBrake cannot silently restore those grants.")
                .foregroundStyle(.secondary)
            Divider()
            Button("Restore Network") { model.restoreHumanControl() }
                .buttonStyle(.borderedProminent)
            Button("Restore Previously Enabled Sharing Services") {
                restoreSharing = true
                model.restoreHumanControl(restoreSharing: true)
            }
            Button("Restart Espanso") { model.restartEspanso() }
            Button("Open Privacy & Security Settings") { model.openPrivacySettings() }
            Button("Open Incident Log") { openWindow(id: "incidents") }
            Divider()
            HStack {
                Button("Keep Isolation") { }
                Button("Quit KeyBrake") { NSApplication.shared.terminate(nil) }
            }
            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 470)
        .onChange(of: model.operationalState) { _, state in
            if state == .normal { restoreSharing = false }
        }
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
