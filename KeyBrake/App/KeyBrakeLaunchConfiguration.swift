import Foundation
import KeyBrakeCore

// Greppable:
// canonical: keybrake-recovery-demo-route
// aliases: disposable recovery demo; staged recovery fixture; recovery launch argument
// forms: keybrake-recovery-demo; --keybrake-recovery-demo
// descriptors: temporary recovery store; no host mutation; command-center staging
// states: recovery-required; isolated; pending-decision
// consumers: KeyBrakeApp; WindowLaunchBridge; Agent Display
// owner: KeyBrakeLaunchConfiguration
@MainActor
enum KeyBrakeLaunchConfiguration {
    static func makeViewModel(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        commandRunner: RecordingCommandRunner = RecordingCommandRunner(),
        settingsDefaults: UserDefaults = .standard
    ) -> KeyBrakeViewModel {
        let launchArguments = arguments
        if let networkSandboxScenario = networkSandboxScenario(from: launchArguments) {
            return makeNetworkSandboxViewModel(
                for: networkSandboxScenario,
                commandRunner: commandRunner,
                settingsDefaults: settingsDefaults
            )
        }
        guard launchArguments.contains(KeyBrakeLaunchArgument.recoveryDemo) else {
            return KeyBrakeViewModel(settingsDefaults: settingsDefaults)
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

        let safeRunner = commandRunner
        let demoTargets = [
            TargetDefinition(
                id: "demo-remote-access",
                displayName: "Demo Remote Access App",
                category: .remoteAccess,
                bundleIdentifier: "com.example.keybrake-demo.remote-access",
                approvedByUser: true,
                allowForcedTermination: false
            )
        ]
        let coordinator = EmergencyCoordinator(
            recoveryStore: recoveryStore,
            incidentStore: incidentStore,
            processController: KeyBrakeRecoveryDemoProcessController(),
            espanso: EspansoAdapter(commandRunner: safeRunner, executableCandidates: []),
            networkController: FixtureNetworkController(),
            privacyController: PrivacyController(commandRunner: safeRunner),
            helper: UnavailableHelper(),
            targetDefinitions: demoTargets,
            sharingController: SharingServiceController(adapters: [
                KeyBrakeRecoveryDemoSharingAdapter(identifier: "remote-login", displayName: "Remote Login", enabled: false),
                KeyBrakeRecoveryDemoSharingAdapter(identifier: "remote-apple-events", displayName: "Remote Apple Events", enabled: false)
            ]),
            initialState: .recoveryRequired
        )
        return KeyBrakeViewModel(
            coordinator: coordinator,
            incidentStore: incidentStore,
            initialIsolationPolicy: .standard,
            isRecoveryDemo: true,
            configuredTargetsOverride: demoTargets,
            demoStoreRootDirectory: rootDirectory,
            settingsDefaults: settingsDefaults
        )
    }

    private static func networkSandboxScenario(from launchArguments: [String]) -> NetworkSandboxScenario? {
        if launchArguments.contains(KeyBrakeLaunchArgument.networkSandboxFailure) {
            return .isolationFailure
        }
        if launchArguments.contains(KeyBrakeLaunchArgument.networkSandbox) {
            return .connected
        }
        return nil
    }

    private static func makeNetworkSandboxViewModel(
        for scenario: NetworkSandboxScenario,
        commandRunner: RecordingCommandRunner,
        settingsDefaults: UserDefaults
    ) -> KeyBrakeViewModel {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "KeyBrake-Network-Sandbox-\(scenario.rawValue)-\(UUID().uuidString)",
            isDirectory: true
        )
        let recoveryStore = RecoveryStore(rootDirectory: rootDirectory)
        let incidentStore = IncidentStore(rootDirectory: rootDirectory)
        let fixture = NetworkSandboxFixture.fixture(for: scenario)
        let coordinator = EmergencyCoordinator(
            recoveryStore: recoveryStore,
            incidentStore: incidentStore,
            processController: KeyBrakeNetworkSandboxProcessController(),
            espanso: EspansoAdapter(commandRunner: commandRunner, executableCandidates: []),
            networkController: fixture.makeController(),
            privacyController: PrivacyController(commandRunner: commandRunner),
            helper: UnavailableHelper(),
            initialState: .normal
        )
        return KeyBrakeViewModel(
            coordinator: coordinator,
            incidentStore: incidentStore,
            initialIsolationPolicy: .standard,
            networkSandboxScenario: scenario,
            isNetworkSandbox: true,
            demoStoreRootDirectory: rootDirectory,
            settingsDefaults: settingsDefaults
        )
    }
}

private struct KeyBrakeNetworkSandboxProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] {
        []
    }

    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult {
        ProcessTargetResult(
            targetID: identity.bundleIdentifier ?? "network-sandbox-process",
            displayName: identity.bundleIdentifier ?? "Network sandbox process",
            identity: identity,
            outcome: .unsupported,
            detail: "Network sandbox does not inspect or terminate host processes"
        )
    }
}

private struct KeyBrakeRecoveryDemoProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] { [] }

    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult {
        ProcessTargetResult(
            targetID: identity.bundleIdentifier ?? "recovery-demo-process",
            displayName: identity.bundleIdentifier ?? "Recovery demo process",
            identity: identity,
            outcome: .unsupported,
            detail: "Recovery demonstration does not inspect or terminate host processes"
        )
    }
}

private actor KeyBrakeRecoveryDemoSharingAdapter: SharingServiceAdapter {
    let identifier: String
    let displayName: String
    private var enabled: Bool

    init(identifier: String, displayName: String, enabled: Bool) {
        self.identifier = identifier
        self.displayName = displayName
        self.enabled = enabled
    }

    func detect() async -> SharingServiceCapability {
        SharingServiceCapability(id: identifier, displayName: displayName, supported: true, enabled: enabled)
    }

    func disable(expectedState: SharingServiceState) async -> OperationStepResult {
        guard expectedState.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Recovery demonstration fixture is unsupported", outcome: .unsupported)
        }
        enabled = false
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", observedPreState: expectedState.enabled ? "enabled" : "disabled", observedPostState: "disabled", operationDescription: "Recovery demonstration changed only its in-memory sharing fixture", outcome: expectedState.enabled ? .succeeded : .alreadyInDesiredState)
    }

    func restore(originalState: SharingServiceState, appliedState: SharingServiceState) async -> OperationStepResult {
        guard originalState.supported, appliedState.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "restore", operationDescription: "Recovery demonstration fixture is unsupported", outcome: .unsupported)
        }
        guard enabled == appliedState.enabled else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "restore", observedPreState: enabled ? "enabled" : "disabled", observedPostState: enabled ? "enabled" : "disabled", operationDescription: "Recovery demonstration fixture changed after isolation", outcome: .conflict)
        }
        enabled = originalState.enabled
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: originalState.enabled ? "enabled" : "disabled", observedPreState: appliedState.enabled ? "enabled" : "disabled", observedPostState: enabled ? "enabled" : "disabled", operationDescription: "Recovery demonstration changed only its in-memory sharing fixture", outcome: .succeeded)
    }
}

enum KeyBrakeLaunchArgument {
    static let commandCenter = "--keybrake-command-center"
    static let recoveryDemo = "--keybrake-recovery-demo"
    static let networkSandbox = "--keybrake-network-sandbox"
    static let networkSandboxFailure = "--keybrake-network-sandbox-failure"
    static let incidentLog = "--keybrake-incident-log"
    static let settings = "--keybrake-settings"
}
