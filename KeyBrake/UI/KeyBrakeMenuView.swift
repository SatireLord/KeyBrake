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
// QoL-004: the menu status label and its help text share the same hydration-aware state explanation.
// QoL-007: the menu header uses the same hydration-aware symbol as the adjacent status row.
// QoL-008: the recovery affordance explains its hydration, busy, and no-snapshot disabled states without changing its gate.
struct KeyBrakeMenuView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("KeyBrake", systemImage: statusSymbol)
            .font(.headline)
        Divider()
        Label(statusText, systemImage: statusSymbol)
            .accessibilityLabel("Current KeyBrake state: \(statusText)")
            .help(statusDetail)
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
            .help(recoveryActionDetail)
            .accessibilityHint(recoveryActionDetail)
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

    private var statusDetail: String {
        model.isRecoveryStatusKnown
            ? KeyBrakeStatusPresentation.detail(for: model.operationalState)
            : "KeyBrake is confirming whether an unresolved recovery snapshot exists."
    }

    private var recoveryActionDetail: String {
        guard model.isRecoveryStatusKnown else {
            return "KeyBrake is checking whether an unresolved recovery snapshot exists."
        }
        if model.isBusy {
            return "KeyBrake is completing the current operation. Keep KeyBrake open until it completes."
        }
        return model.hasRecovery
            ? "Open the recovery panel to choose how to restore the recorded changes."
            : "No unresolved recovery snapshot is available."
    }
}
