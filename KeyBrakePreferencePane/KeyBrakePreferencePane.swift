// Greppable: KEYBRAKE_SYSTEM_SETTINGS_PREFERENCE_PANE
import AppKit
import PreferencePanes
import SwiftUI

@objc(KeyBrakeSettingsPane)
public final class KeyBrakeSettingsPane: NSPreferencePane {
    public override func loadMainView() -> NSView {
        let view = NSHostingView(rootView: KeyBrakePreferencePaneContent())
        view.setFrameSize(NSSize(width: 560, height: 300))
        mainView = view
        return view
    }
}

private struct KeyBrakePreferencePaneContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("KeyBrake", systemImage: "keyboard")
                .font(.largeTitle.weight(.semibold))

            Text("Keyboard access settings")
                .font(.title2)

            Text("Open KeyBrake to choose an app and manage its keyboard access.")
                .foregroundStyle(.secondary)

            Text("This pane does not change macOS Keyboard Accessibility settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 300, alignment: .leading)
    }
}
