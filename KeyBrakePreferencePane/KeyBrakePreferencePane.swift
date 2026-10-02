import AppKit
import PreferencePanes
import SwiftUI

@objc(KeyBrakeSettingsPane)
public final class KeyBrakeSettingsPane: NSPreferencePane {
    public override func loadMainView() -> NSView {
        let view = MainActor.assumeIsolated {
            let view = NSHostingView(rootView: KeyBrakePreferencePaneContent())
            view.setFrameSize(NSSize(width: 560, height: 360))
            return view
        }
        mainView = view
        return view
    }
}

@MainActor
private struct KeyBrakePreferencePaneContent: View {
    @State private var launcher = KeyBrakeAppLauncher()
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("KeyBrake", systemImage: "keyboard")
                .font(.largeTitle.weight(.semibold))

            Text("Keyboard access settings")
                .font(.title2)

            Text("Open KeyBrake to choose a configured application and manage its keyboard access.")
                .foregroundStyle(.secondary)

            Button("Open Keyboard Settings", action: openKeyboardSettings)
                .accessibilityIdentifier("keybrake.preference-pane.open-keyboard-settings")

            Text("This opens KeyBrake Settings only. It does not select an application or reset permissions, and this pane does not change macOS Keyboard Accessibility settings.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusIsError ? Color.red : Color.secondary)
                    .accessibilityIdentifier("keybrake.preference-pane.open-status")
            }
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 360, alignment: .leading)
    }

    private func openKeyboardSettings() {
        statusIsError = false
        statusMessage = "Opening KeyBrake Keyboard Settings…"
        launcher.openKeyboardSettings { outcome in
            switch outcome {
            case .opened:
                statusMessage = "KeyBrake Settings opened at Keyboard. No application was selected and no permissions were changed."
            case let .failed(failure):
                statusIsError = true
                statusMessage = failureMessage(for: failure)
            }
        }
    }

    private func failureMessage(for failure: KeyBrakeSystemSettingsHandoff.Failure) -> String {
        switch failure {
        case .missingHostBundleIdentifier:
            return "KeyBrake is not configured for this pane. Reinstall the matching KeyBrake app and pane."
        case .applicationNotRegistered:
            return "KeyBrake could not be found. Install one registered copy of KeyBrake, then try again."
        case .multipleRegisteredApplications:
            return "Multiple registered KeyBrake copies were found. Remove the duplicate copy, then try again."
        case .keyboardRouteNotRegistered:
            return "The installed KeyBrake copy cannot open the keyboard settings link. Update KeyBrake, then try again."
        case .multipleRunningApplications:
            return "Multiple KeyBrake copies are running. Quit the duplicate copies, then try again."
        case .runningApplicationLocationUnavailable:
            return "The running KeyBrake copy could not be identified. Quit it and try again."
        case .differentApplicationIsRunning:
            return "A different KeyBrake copy is running. Quit that copy, then try again."
        case .duplicateInvocation:
            return "A KeyBrake Settings request is already opening. Try again once the current request finishes."
        case let .launchFailed(reason):
            return reason.isEmpty
                ? "macOS could not open the KeyBrake Settings request. Try again."
                : "KeyBrake could not be opened: \(reason)"
        }
    }
}
