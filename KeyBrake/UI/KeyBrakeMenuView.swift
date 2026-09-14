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
// QoL-001: menu actions carry stable visual symbols while their existing targets, labels, and disabled-state rules remain unchanged.
struct KeyBrakeMenuView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("KeyBrake", systemImage: "checkmark.shield")
            .font(.headline)
        Divider()
        Label(statusText, systemImage: statusSymbol)
            .accessibilityLabel("Current KeyBrake state: \(statusText)")
            .help(KeyBrakeStatusPresentation.detail(for: model.operationalState))
        Button {
            openWindow(id: "command-center")
        } label: {
            Label("Open Command Center", systemImage: "rectangle.3.group")
        }
            .help("Open the at-a-glance KeyBrake status and action surface")
        Divider()
        Button {
            model.stopSkynetLocally()
        } label: {
            Label("Stop Skynet Locally", systemImage: "keyboard.badge.ellipsis")
        }
            .disabled(model.isBusy || model.operationalState == .localAutomationStopped)
        Button {
            model.stopRemoteAccess()
        } label: {
            Label("Stop Remote Access", systemImage: "lock.shield")
        }
            .disabled(model.isBusy)
        Button {
            openWindow(id: "settings")
        } label: {
            Label("Revoke App Access…", systemImage: "hand.raised.slash")
        }
            .disabled(model.isBusy)
        Divider()
        Button {
            model.isShowingRecoveryPanel = true
        } label: {
            Label("Restore Human Control", systemImage: "arrow.uturn.backward.circle")
        }
            .disabled(!model.hasRecovery || model.isBusy)
        Button {
            model.restartEspanso()
        } label: {
            Label("Restart Espanso", systemImage: "arrow.clockwise.circle")
        }
            .disabled(model.isBusy)
        Button {
            openWindow(id: "incidents")
        } label: {
            Label("Open Incident Log", systemImage: "list.bullet.clipboard")
        }
        Divider()
        Button {
            openWindow(id: "settings")
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        Button {
            model.requestQuit()
        } label: {
            Label("Quit KeyBrake", systemImage: "power")
        }
    }

    private var statusText: String {
        model.isRecoveryStatusKnown ? model.operationalState.displayTitle : "Checking Recovery Status"
    }

    private var statusSymbol: String {
        model.isRecoveryStatusKnown ? KeyBrakeStatusPresentation.symbol(for: model.operationalState) : "hourglass"
    }
}
