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
