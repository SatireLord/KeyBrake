import KeyBrakeCore
import SwiftUI

struct KeyBrakeMenuView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("KeyBrake").font(.headline)
        Divider()
        Label(statusText, systemImage: statusSymbol)
            .accessibilityLabel("Current KeyBrake state: \(statusText)")
        Divider()
        Button("Stop Skynet Locally") { model.stopSkynetLocally() }
            .disabled(model.isBusy || model.operationalState == .localAutomationStopped)
        Button("Stop Remote Access") { model.stopRemoteAccess() }
            .disabled(model.isBusy)
        Button("Revoke App Access…") { openWindow(id: "settings"); model.isShowingSettings = true }
            .disabled(model.isBusy)
        Divider()
        Button("Restore Human Control") { openWindow(id: "recovery") }
            .disabled(!model.hasRecovery || model.isBusy)
        Button("Restart Espanso") { model.restartEspanso() }
            .disabled(model.isBusy)
        Button("Open Incident Log") { openWindow(id: "incidents") }
        Divider()
        Button("Settings…") { openWindow(id: "settings") }
        Button("Quit KeyBrake") { requestQuit() }
    }

    private var statusText: String {
        switch model.operationalState {
        case .normal: return "Normal Input"
        case .stoppingLocalAutomation: return "Stopping Local Automation"
        case .localAutomationStopped: return "Local Automation Stopped"
        case .isolating: return "Isolating Network"
        case .isolated: return "Network Isolated"
        case .partiallyIsolated: return "Partial Isolation"
        case .restoring: return "Restoring Human Control"
        case .recoveryRequired: return "Recovery Required"
        }
    }

    private var statusSymbol: String {
        model.operationalState == .normal ? "checkmark.circle" : "exclamationmark.triangle"
    }

    private func requestQuit() {
        guard model.hasRecovery else { NSApplication.shared.terminate(nil); return }
        let alert = NSAlert()
        alert.messageText = "Recovery is still required"
        alert.informativeText = "KeyBrake changed system state that has not been fully resolved. Choose a mouse-operated action."
        alert.addButton(withTitle: "Restore Network")
        alert.addButton(withTitle: "Keep Isolation and Quit")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: model.restoreHumanControl()
        case .alertSecondButtonReturn: NSApplication.shared.terminate(nil)
        default: break
        }
    }
}
