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
            WindowLaunchBridge(model: model, appDelegate: appDelegate)
                .onAppear { appDelegate.attach(model: model) }
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
        .defaultSize(width: 760, height: 620)

        Window("KeyBrake Command Center", id: "command-center") {
            KeyBrakeCommandCenterView(model: model)
                .onAppear { appDelegate.attach(model: model) }
        }
        .defaultSize(width: 760, height: 620)
    }
}

private struct WindowLaunchBridge: View {
    @ObservedObject var model: KeyBrakeViewModel
    let appDelegate: KeyBrakeAppDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenLaunchRequestedCommandCenter = false

    var body: some View {
        Label("KeyBrake", systemImage: model.operationalState == .normal ? "shield" : "exclamationmark.shield")
            .onAppear {
                appDelegate.attach(model: model)
                openCommandCenterIfRequested()
            }
            .onChange(of: model.isShowingIncidentLog) { _, show in
                if show {
                    openWindow(id: "incidents")
                    model.isShowingIncidentLog = false
                }
            }
            .onChange(of: model.isShowingSettings) { _, show in
                if show {
                    openWindow(id: "settings")
                    model.isShowingSettings = false
                }
            }
    }

    private func openCommandCenterIfRequested() {
        guard !didOpenLaunchRequestedCommandCenter,
              ProcessInfo.processInfo.arguments.contains(KeyBrakeLaunchArgument.commandCenter) else { return }
        didOpenLaunchRequestedCommandCenter = true
        Task { @MainActor in
            openWindow(id: "command-center")
        }
    }
}

private enum KeyBrakeLaunchArgument {
    static let commandCenter = "--keybrake-command-center"
}
