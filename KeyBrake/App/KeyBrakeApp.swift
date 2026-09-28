import Foundation
import KeyBrakeCore
import SwiftUI

@main
struct KeyBrakeApp: App {
    @NSApplicationDelegateAdaptor(KeyBrakeAppDelegate.self) private var appDelegate
    @StateObject private var model = KeyBrakeLaunchConfiguration.makeViewModel()

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

// Greppable:
// canonical: keybrake-destination-demo-routes
// aliases: incident-log staging; settings staging; destination launch argument
// forms: keybrake-incident-log; keybrake-settings; keybrake-network-sandbox; keybrake-network-sandbox-failure; --keybrake-incident-log; --keybrake-settings
// descriptors: deterministic destination staging; Agent Display route
// states: incident-log; settings; command-center; recovery-demo; network-sandbox
// consumers: WindowLaunchBridge; Agent Display
// owner: KeyBrakeLaunchArgument
// QoL-006: the menu-bar extra label uses the same hydration-aware status symbol as the compact status row.
private struct WindowLaunchBridge: View {
    @ObservedObject var model: KeyBrakeViewModel
    let appDelegate: KeyBrakeAppDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenLaunchRequestedCommandCenter = false

    private var hydrationAwareApplicationSymbol: String {
        model.isRecoveryStatusKnown
            ? KeyBrakeStatusPresentation.symbol(for: model.operationalState)
            : "hourglass"
    }

    var body: some View {
        Label("KeyBrake", systemImage: hydrationAwareApplicationSymbol)
            .onAppear {
                appDelegate.attach(model: model, openSettingsWindow: { openWindow(id: "settings") })
                openCommandCenterIfRequested()
            }
            .onReceive(model.$isShowingRecoveryPanel.removeDuplicates()) { show in
                Task { @MainActor in
                    if show {
                        appDelegate.presentRecoveryPanel(model: model)
                    } else {
                        appDelegate.hideRecoveryPanel()
                    }
                }
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
        let launchArguments = ProcessInfo.processInfo.arguments
        let shouldOpenIncidentLog = launchArguments.contains(KeyBrakeLaunchArgument.incidentLog)
        let shouldOpenSettings = launchArguments.contains(KeyBrakeLaunchArgument.settings)
        let shouldOpenCommandCenter = (launchArguments.contains(KeyBrakeLaunchArgument.commandCenter)
            || launchArguments.contains(KeyBrakeLaunchArgument.recoveryDemo)
            || launchArguments.contains(KeyBrakeLaunchArgument.networkSandbox)
            || launchArguments.contains(KeyBrakeLaunchArgument.networkSandboxFailure))
            && !shouldOpenIncidentLog
            && !shouldOpenSettings
        guard !didOpenLaunchRequestedCommandCenter, shouldOpenCommandCenter || shouldOpenIncidentLog || shouldOpenSettings else { return }
        didOpenLaunchRequestedCommandCenter = true
        Task { @MainActor in
            if shouldOpenIncidentLog {
                openWindow(id: "incidents")
                return
            }
            if shouldOpenSettings {
                openWindow(id: "settings")
                return
            }
            openWindow(id: "command-center")
            guard launchArguments.contains(KeyBrakeLaunchArgument.recoveryDemo) else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            appDelegate.presentRecoveryPanel(model: model)
        }
    }
}
