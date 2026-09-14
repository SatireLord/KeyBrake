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
        Button("Revoke App Access…") { openWindow(id: "settings") }
            .disabled(model.isBusy)
        Divider()
        Button("Restore Human Control") { model.isShowingRecoveryPanel = true }
            .disabled(!model.hasRecovery || model.isBusy)
        Button("Restart Espanso") { model.restartEspanso() }
            .disabled(model.isBusy)
        Button("Open Incident Log") { openWindow(id: "incidents") }
        Divider()
        Button("Settings…") { openWindow(id: "settings") }
        Button("Quit KeyBrake") { model.requestQuit() }
    }

    private var statusText: String {
        model.operationalState.displayTitle
    }

    private var statusSymbol: String {
        model.operationalState == .normal ? "checkmark.circle" : "exclamationmark.triangle"
    }
}
