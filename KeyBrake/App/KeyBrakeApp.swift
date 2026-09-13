import SwiftUI

@main
struct KeyBrakeApp: App {
    @NSApplicationDelegateAdaptor(KeyBrakeAppDelegate.self) private var appDelegate
    @StateObject private var model = KeyBrakeViewModel()

    var body: some Scene {
        MenuBarExtra {
            KeyBrakeMenuView(model: model)
                .onAppear { appDelegate.attach(model: model) }
        } label: {
            Label("KeyBrake", systemImage: model.operationalState == .normal ? "shield" : "exclamationmark.shield")
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: model.isShowingRecoveryPanel) { _, show in
            Task { @MainActor in
                if show {
                    appDelegate.presentRecoveryPanel(model: model)
                } else {
                    appDelegate.hideRecoveryPanel()
                }
            }
        }

        Window("KeyBrake Settings", id: "settings") {
            SettingsView(model: model)
                .frame(width: 620, height: 560)
                .onAppear { appDelegate.attach(model: model) }
        }
        .defaultSize(width: 620, height: 560)

        Window("Incident Log", id: "incidents") {
            IncidentLogView(model: model)
                .frame(minWidth: 680, minHeight: 460)
        }

        Window("KeyBrake Recovery", id: "recovery") {
            RecoveryView(model: model)
        }
    }
}
