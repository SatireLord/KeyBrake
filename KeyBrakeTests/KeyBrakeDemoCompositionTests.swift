import XCTest
import KeyBrakeCore
#if SWIFT_PACKAGE
@testable import KeyBrake
#endif

@MainActor
final class KeyBrakeDemoCompositionTests: XCTestCase {
    func testRecoveryDemoUsesTemporaryStoresAndBlocksSettingsAndKeyboardMutations() async throws {
        let hostSettingsBefore = StandardSettingsDefaultsSnapshot()
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sentinelTarget = customTarget(id: "demo-settings-sentinel")
        let sentinelTargetsData = try JSONEncoder().encode([sentinelTarget])
        let sentinelPolicyData = try JSONEncoder().encode(EmergencyIsolationPolicy(disableWiFi: false))
        defaults.set(sentinelTargetsData, forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey)
        defaults.set(sentinelPolicyData, forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey)

        let commandRunner = RecordingCommandRunner()
        let model = KeyBrakeLaunchConfiguration.makeViewModel(
            arguments: ["KeyBrake", KeyBrakeLaunchArgument.recoveryDemo],
            commandRunner: commandRunner,
            settingsDefaults: defaults
        )
        let demoRoot = model.incidentStore.rootDirectory.standardizedFileURL
        defer { model.cleanupDemoStore() }
        try await waitForRecoveryCheck(model)

        XCTAssertTrue(model.isRecoveryDemo)
        XCTAssertTrue(model.isReadOnlyDemo)
        XCTAssertEqual(model.operationalState, .recoveryRequired)
        XCTAssertTrue(model.configuredTargets.contains { $0.id == "demo-remote-access" })
        XCTAssertFalse(model.configuredTargets.contains { $0.id == sentinelTarget.id })
        XCTAssertEqual(model.isolationPolicy, .standard)
        XCTAssertFalse(model.launchAtLoginEnabled)
        XCTAssertEqual(model.privilegedHelperStatus, "Disabled in demo mode")
        XCTAssertEqual(demoRoot.deletingLastPathComponent(), FileManager.default.temporaryDirectory.standardizedFileURL)
        XCTAssertTrue(demoRoot.lastPathComponent.hasPrefix("KeyBrake-Recovery-Demo-"))

        model.setTargetApproval(targetID: "demo-remote-access", approved: false)
        model.enrollTarget(sentinelTarget)
        model.removeTarget(targetID: "demo-remote-access")
        model.updateIsolationPolicy(EmergencyIsolationPolicy(disableWiFi: false))
        model.refreshPrivilegedHelperStatus()
        model.resetKeyboardAccess(targetID: "demo-remote-access")
        model.revokeAppAccess(targetID: "demo-remote-access", services: [.inputMonitoring])
        model.restoreHumanControl(restoreSharing: true)
        try await waitForIdle(model)

        XCTAssertEqual(defaults.data(forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey), sentinelTargetsData)
        XCTAssertEqual(defaults.data(forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey), sentinelPolicyData)
        hostSettingsBefore.assertUnchanged()
        XCTAssertEqual(model.privilegedHelperStatus, "Disabled in demo mode")
        XCTAssertTrue(commandRunner.calls.isEmpty)
        XCTAssertTrue(model.latestIncident?.steps.contains {
            $0.targetID == "remote-login" && $0.operationDescription.contains("changed only its in-memory sharing fixture")
        } == true)

        model.cleanupDemoStore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: demoRoot.path))
    }

    func testNetworkSandboxUsesTemporaryFixtureNetworkAndLeavesStandardSettingsUntouched() async throws {
        let hostSettingsBefore = StandardSettingsDefaultsSnapshot()
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sentinelTarget = customTarget(id: "sandbox-settings-sentinel")
        let sentinelTargetsData = try JSONEncoder().encode([sentinelTarget])
        let sentinelPolicyData = try JSONEncoder().encode(EmergencyIsolationPolicy(disableEthernet: false))
        defaults.set(sentinelTargetsData, forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey)
        defaults.set(sentinelPolicyData, forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey)

        let commandRunner = RecordingCommandRunner()
        let model = KeyBrakeLaunchConfiguration.makeViewModel(
            arguments: ["KeyBrake", KeyBrakeLaunchArgument.networkSandbox],
            commandRunner: commandRunner,
            settingsDefaults: defaults
        )
        let demoRoot = model.incidentStore.rootDirectory.standardizedFileURL
        defer { model.cleanupDemoStore() }
        try await waitForRecoveryCheck(model)

        XCTAssertTrue(model.isNetworkSandbox)
        XCTAssertEqual(model.networkSandboxScenario, .connected)
        XCTAssertTrue(model.isReadOnlyDemo)
        XCTAssertFalse(model.configuredTargets.contains { $0.id == sentinelTarget.id })
        XCTAssertEqual(model.isolationPolicy, .standard)
        XCTAssertFalse(model.launchAtLoginEnabled)
        XCTAssertEqual(model.privilegedHelperStatus, "Disabled in demo mode")
        XCTAssertEqual(demoRoot.deletingLastPathComponent(), FileManager.default.temporaryDirectory.standardizedFileURL)
        XCTAssertTrue(demoRoot.lastPathComponent.hasPrefix("KeyBrake-Network-Sandbox-connected-"))

        model.enrollTarget(sentinelTarget)
        model.updateIsolationPolicy(EmergencyIsolationPolicy(disableEthernet: false))
        model.resetKeyboardAccess(targetID: model.configuredTargets[0].id)
        model.revokeAppAccess(targetID: model.configuredTargets[0].id, services: [.inputMonitoring])
        model.stopRemoteAccess()
        try await waitForIdle(model)

        XCTAssertEqual(defaults.data(forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey), sentinelTargetsData)
        XCTAssertEqual(defaults.data(forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey), sentinelPolicyData)
        hostSettingsBefore.assertUnchanged()
        XCTAssertTrue(commandRunner.calls.isEmpty)
        let recordedRecovery = try RecoveryStore(rootDirectory: demoRoot).load()
        XCTAssertEqual(recordedRecovery?.networkChanges.count, 3)
        XCTAssertTrue(recordedRecovery?.networkChanges.allSatisfy { $0.id.hasPrefix("network-service-") } == true)

        model.cleanupDemoStore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: demoRoot.path))
    }

    func testFirstRunSittingSkipsWithoutAddingAnotherApp() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("KeyBrake-FirstRun-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(
            recoveryStore: RecoveryStore(rootDirectory: root),
            incidentStore: IncidentStore(rootDirectory: root),
            processController: DemoFixtureProcessController(),
            espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []),
            networkController: FixtureNetworkController(),
            privacyController: PrivacyController(commandRunner: runner)
        )
        let model = KeyBrakeViewModel(
            coordinator: coordinator,
            incidentStore: IncidentStore(rootDirectory: root),
            settingsDefaults: defaults
        )
        try await waitForRecoveryCheck(model)
        let targetCount = model.configuredTargets.count
        XCTAssertTrue(model.isShowingFirstRun)
        XCTAssertEqual(model.firstRunLocalSlot.statusText, "Not chosen")
        XCTAssertFalse(model.finishFirstRunSitting())
        XCTAssertFalse(defaults.bool(forKey: KeyBrakeViewModel.firstRunDefaultsKey))
        model.skipFirstRunSlot(.localAutomation)
        XCTAssertEqual(model.firstRunLocalSlot.statusText, "Skipped")
        XCTAssertFalse(model.finishFirstRunSitting())
        model.skipFirstRunSlot(.remoteAccess)
        XCTAssertEqual(model.firstRunRemoteSlot.statusText, "Skipped")
        XCTAssertTrue(model.finishFirstRunSitting())
        XCTAssertFalse(model.isShowingFirstRun)
        XCTAssertEqual(model.configuredTargets.count, targetCount)
        await model.refresh()
        try await waitForRecoveryCheck(model)
        XCTAssertFalse(model.isShowingFirstRun)
    }

    func testQuitConfirmationListsRestoreTargetsWithoutASecondVPNQuestion() async throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("KeyBrake-QuitRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let wifi = NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
        let vpn = NetworkChange(id: "vpn", displayName: "Work VPN", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "vpn", isVPN: true)
        let snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .recoveryRequired,
            networkChanges: [wifi, vpn],
            vpnConnections: []
        )
        try RecoveryStore(rootDirectory: root).save(snapshot)
        let runner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(
            recoveryStore: RecoveryStore(rootDirectory: root),
            incidentStore: IncidentStore(rootDirectory: root),
            processController: DemoFixtureProcessController(),
            espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []),
            networkController: FixtureNetworkController(services: [
                NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: false, active: false),
                NetworkService(id: "vpn", displayName: "Work VPN", kind: .vpn, enabled: false, active: false),
            ]),
            privacyController: PrivacyController(commandRunner: runner),
            initialState: .recoveryRequired
        )
        let model = KeyBrakeViewModel(
            coordinator: coordinator,
            incidentStore: IncidentStore(rootDirectory: root),
            isRecoveryDemo: true,
            settingsDefaults: defaults
        )
        try await waitForRecoveryCheck(model)
        XCTAssertTrue(model.quitRestoreConfirmationText.contains("Turns Wi-Fi back on."))
        XCTAssertTrue(model.quitRestoreConfirmationText.contains("Work VPN stays disconnected."))
        XCTAssertFalse(model.quitRestoreConfirmationText.contains("Turns Wi-Fi, Work VPN"))
        model.restoreNetworkOnly(confirmVPN: false)
        try await waitForIdle(model)
        XCTAssertEqual(model.latestIncident?.initiatingAction, "Restore Human Control")
    }

    func testMenuGuidanceAndHelperFailureCopy() {
        XCTAssertEqual(KeyBrakeViewModel.menuBarStatusWord(known: false, hasRecovery: false, state: .normal), "Checking")
        XCTAssertEqual(KeyBrakeViewModel.menuBarStatusWord(known: true, hasRecovery: false, state: .stoppingLocalAutomation), "Stopping")
        XCTAssertEqual(KeyBrakeViewModel.menuBarStatusWord(known: true, hasRecovery: false, state: .isolating), "Isolating")
        XCTAssertEqual(KeyBrakeViewModel.menuBarStatusWord(known: true, hasRecovery: false, state: .normal), "Ready")
        XCTAssertEqual(KeyBrakeViewModel.menuBarStatusWord(known: true, hasRecovery: true, state: .normal), "Recovery")
        XCTAssertEqual(KeyBrakeViewModel.nextStepSentence(known: false, busy: false, hasRecovery: false), "Wait.")
        XCTAssertEqual(KeyBrakeViewModel.nextStepSentence(known: true, busy: true, hasRecovery: false), "Wait.")
        XCTAssertEqual(KeyBrakeViewModel.nextStepSentence(known: true, busy: false, hasRecovery: true), "Open recovery.")
        XCTAssertEqual(KeyBrakeViewModel.nextStepSentence(known: true, busy: false, hasRecovery: false), "Stop something.")
        let blocked = IncidentRecord(
            initiatingAction: "Stop Remote Access",
            originalState: .normal,
            finalState: .recoveryRequired,
            steps: [
                OperationStepResult(
                    subsystem: "network",
                    targetID: "wifi",
                    targetDisplayName: "Wi-Fi",
                    requestedState: "disabled",
                    operationDescription: "Helper is unavailable; operation skipped",
                    outcome: .unsupported
                ),
            ]
        )
        XCTAssertEqual(
            KeyBrakeViewModel.helperFailureNotice(helperStatus: "Approval required", incident: blocked, readOnlyDemo: false),
            KeyBrakeViewModel.helperNotApprovedSentence
        )
        XCTAssertNil(KeyBrakeViewModel.helperFailureNotice(helperStatus: "Enabled", incident: blocked, readOnlyDemo: false))
        XCTAssertNil(KeyBrakeViewModel.helperFailureNotice(helperStatus: "Approval required", incident: blocked, readOnlyDemo: true))
    }

    private func waitForRecoveryCheck(_ model: KeyBrakeViewModel) async throws {
        for _ in 0..<100 {
            if model.isRecoveryStatusKnown { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("The disposable demo recovery store did not finish loading.")
    }

    private func waitForIdle(_ model: KeyBrakeViewModel) async throws {
        for _ in 0..<100 {
            if !model.operationInFlight { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("The fixture-backed demo operation did not settle.")
    }

    private func customTarget(id: String) -> TargetDefinition {
        TargetDefinition(
            id: id,
            displayName: "Settings Sentinel",
            category: .remoteAccess,
            bundleIdentifier: "com.example.\(id)",
            approvedByUser: true,
            allowForcedTermination: false
        )
    }

    private func isolatedDefaults() throws -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "KeyBrakeDemoCompositionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.setPersistentDomain([:], forName: suiteName)
        return (suiteName, defaults)
    }
}

private struct DemoFixtureProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] { [] }
    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult {
        ProcessTargetResult(targetID: "fixture", displayName: "Fixture", identity: identity, outcome: .succeeded, detail: "fixture")
    }
}

@MainActor
private struct StandardSettingsDefaultsSnapshot {
    private let targets: Data?
    private let policy: Data?

    init(defaults: UserDefaults = .standard) {
        self.targets = defaults.data(forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey)
        self.policy = defaults.data(forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey)
    }

    func assertUnchanged(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(UserDefaults.standard.data(forKey: KeyBrakeViewModel.configuredTargetsDefaultsKey), targets, file: file, line: line)
        XCTAssertEqual(UserDefaults.standard.data(forKey: KeyBrakeViewModel.isolationPolicyDefaultsKey), policy, file: file, line: line)
    }
}
