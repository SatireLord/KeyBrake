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
// canonical: keybrake-recovery-demo-route
// aliases: disposable recovery demo; staged recovery fixture; recovery launch argument
// forms: keybrake-recovery-demo; --keybrake-recovery-demo
// descriptors: temporary recovery store; no host mutation; command-center staging
// states: recovery-required; isolated; pending-decision
// consumers: KeyBrakeApp; WindowLaunchBridge; Agent Display
// owner: KeyBrakeLaunchConfiguration
@MainActor
private enum KeyBrakeLaunchConfiguration {
    static func makeViewModel() -> KeyBrakeViewModel {
        guard ProcessInfo.processInfo.arguments.contains(KeyBrakeLaunchArgument.recoveryDemo) else {
            return KeyBrakeViewModel()
        }

        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("KeyBrake-Recovery-Demo-\(UUID().uuidString)", isDirectory: true)
        let recoveryStore = RecoveryStore(rootDirectory: rootDirectory)
        let incidentStore = IncidentStore(rootDirectory: rootDirectory)
        let failedStep = OperationStepResult(
            subsystem: "network",
            targetID: "wifi",
            targetDisplayName: "Wi-Fi",
            requestedState: "enabled",
            observedPreState: "disabled",
            observedPostState: "disabled",
            operationDescription: "Recovery demonstration keeps the recorded Wi-Fi change pending until explicit restoration.",
            outcome: .failed
        )
        let snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .isolated,
            hostIdentifier: "KeyBrake staged recovery demonstration",
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
            ],
            sharingChanges: [
                SharingChange(id: "remote-login", displayName: "Remote Login", originalEnabled: true, appliedEnabled: false, currentEnabled: false, supported: true)
            ],
            privacyResetRequests: ["accessibility"],
            failedSteps: [failedStep],
            unresolvedSteps: [failedStep]
        )
        try? recoveryStore.save(snapshot)

        var incident = IncidentRecord(
            initiatingAction: "Stop Remote Access",
            originalState: .normal,
            finalState: .recoveryRequired,
            steps: [failedStep],
            resolution: "Recovery is pending review in the staged demonstration."
        )
        incident.completedAt = Date()
        try? incidentStore.save(incident)

        let safeRunner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(
            recoveryStore: recoveryStore,
            incidentStore: incidentStore,
            processController: SystemProcessController(),
            espanso: EspansoAdapter(commandRunner: safeRunner, executableCandidates: []),
            networkController: FixtureNetworkController(),
            privacyController: PrivacyController(commandRunner: safeRunner),
            helper: UnavailableHelper(),
            initialState: .recoveryRequired
        )
        return KeyBrakeViewModel(coordinator: coordinator, incidentStore: incidentStore)
    }
}

// Greppable:
// canonical: keybrake-destination-demo-routes
// aliases: incident-log staging; settings staging; destination launch argument
// forms: keybrake-incident-log; keybrake-settings; --keybrake-incident-log; --keybrake-settings
// descriptors: deterministic destination staging; Agent Display route
// states: incident-log; settings; command-center; recovery-demo
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
                appDelegate.attach(model: model)
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
        let shouldOpenCommandCenter = (launchArguments.contains(KeyBrakeLaunchArgument.commandCenter) || launchArguments.contains(KeyBrakeLaunchArgument.recoveryDemo))
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

private enum KeyBrakeLaunchArgument {
    static let commandCenter = "--keybrake-command-center"
    static let recoveryDemo = "--keybrake-recovery-demo"
    static let incidentLog = "--keybrake-incident-log"
    static let settings = "--keybrake-settings"
}
