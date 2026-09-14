import KeyBrakeCore
import SwiftUI

// Greppable:
// canonical: keybrake-menu-command-routing
// aliases: menu-bar command menu; emergency menu; compact failsafe menu
// forms: keybrake-menu-command-routing; Open Command Center
// descriptors: menu fallback; command-center entry point; status row
// states: checking; ready; busy; recovery-required
// consumers: KeyBrakeApp; KeyBrakeCommandCenterView; KeyBrakeViewModel
// owner: KeyBrakeMenuView
struct KeyBrakeMenuView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("KeyBrake").font(.headline)
        Divider()
        Label(statusText, systemImage: statusSymbol)
            .accessibilityLabel("Current KeyBrake state: \(statusText)")
            .help(KeyBrakeStatusPresentation.detail(for: model.operationalState))
        Button("Open Command Center") { openWindow(id: "command-center") }
            .help("Open the at-a-glance KeyBrake status and action surface")
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
        model.isRecoveryStatusKnown ? model.operationalState.displayTitle : "Checking Recovery Status"
    }

    private var statusSymbol: String {
        model.isRecoveryStatusKnown ? KeyBrakeStatusPresentation.symbol(for: model.operationalState) : "hourglass"
    }
}
