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
// QoL-041: the App Access menu entry names its Settings destination because its existing action opens Settings rather than revoking access immediately.
// QoL-043: busy-disabled menu actions explain their temporary unavailability while preserving each existing handler and gate.
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
            .accessibilityHint("Opens the at-a-glance KeyBrake status and action surface")
        Divider()
        Button {
            model.stopSkynetLocally()
        } label: {
            Label("Stop Skynet Locally", systemImage: "keyboard.badge.ellipsis")
        }
            .help(stopSkynetLocallyActionHint)
            .accessibilityHint(stopSkynetLocallyActionHint)
            .disabled(model.isBusy || model.operationalState == .localAutomationStopped)
        Button {
            model.stopRemoteAccess()
        } label: {
            Label("Stop Remote Access", systemImage: "lock.shield")
        }
            .help(stopRemoteAccessActionHint)
            .accessibilityHint(stopRemoteAccessActionHint)
            .disabled(model.isBusy)
        Button {
            openWindow(id: "settings")
        } label: {
            Label("Open App Access Settings…", systemImage: "hand.raised.slash")
        }
            .help(appAccessSettingsActionHint)
            .accessibilityHint(appAccessSettingsActionHint)
            .disabled(model.isBusy)
        Divider()
        Button {
            model.isShowingRecoveryPanel = true
        } label: {
            Label("Restore Human Control", systemImage: "arrow.uturn.backward.circle")
        }
            .help(recoveryActionDetail)
            .accessibilityHint(recoveryActionDetail)
            .accessibilityIdentifier("keybrake.menu.restore-human-control")
            .disabled(!model.hasRecovery || model.isBusy)
        Button {
            model.restartEspanso()
        } label: {
            Label("Restart Espanso", systemImage: "arrow.clockwise.circle")
        }
            .help(restartEspansoActionHint)
            .accessibilityHint(restartEspansoActionHint)
            .disabled(model.isBusy)
        Button {
            openWindow(id: "incidents")
        } label: {
            Label("Open Incident Log", systemImage: "list.bullet.clipboard")
        }
            .help("Open recorded operation outcomes and recovery history")
            .accessibilityHint("Opens the Incident Log to review recorded actions and outcomes")
        Divider()
        Button {
            openWindow(id: "settings")
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
            .help("Review approved targets, recovery policy, and sandbox status")
            .accessibilityHint("Opens Settings to review targets, policy, and sandbox status")
        Button {
            model.requestQuit()
        } label: {
            Label("Quit KeyBrake", systemImage: "power")
        }
        .help(quitActionHint)
        .accessibilityHint(quitActionHint)
    }

    private var quitActionHint: String {
        guard model.isRecoveryStatusKnown else {
            return "Unavailable until KeyBrake confirms whether unresolved recovery exists."
        }
        if model.isBusy {
            return "Unavailable until the current state-changing operation finishes."
        }
        return model.hasRecovery
            ? "Opens the recovery decision before quitting so recorded changes can be restored or kept isolated."
            : "Quits KeyBrake because no unresolved recovery snapshot is pending."
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

    private var stopSkynetLocallyActionHint: String {
        if model.isBusy {
            return busyMenuActionHint
        }
        if model.operationalState == .localAutomationStopped {
            return "Local input automation is already stopped."
        }
        return "Stops approved local input automation without changing network or privacy settings."
    }

    private var stopRemoteAccessActionHint: String {
        model.isBusy
            ? busyMenuActionHint
            : "Saves recovery state before applying the selected isolation profile."
    }

    private var restartEspansoActionHint: String {
        model.isBusy
            ? busyMenuActionHint
            : "Restarts local input automation without changing network or privacy settings."
    }

    private var appAccessSettingsActionHint: String {
        model.isBusy
            ? busyMenuActionHint
            : "Opens Settings so you can review or change application access."
    }

    private var busyMenuActionHint: String {
        "Unavailable while KeyBrake completes the current operation."
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
