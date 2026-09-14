import XCTest
@testable import KeyBrakeCore

private struct FixtureProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] { [] }
    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult { ProcessTargetResult(targetID: "fixture", displayName: "Fixture", identity: identity, outcome: .succeeded, detail: "fixture") }
}

final class EmergencyCoordinatorTests: XCTestCase {
    func testTerminationGateFailsClosedBeforeHydrationAndDuringTransactions() {
        XCTAssertTrue(KeyBrakeTerminationGate.blocksTermination(state: .normal, launchRecoveryCheckCompleted: false, recoveryRequired: false, immediateQuitApproved: false))

        for state in [KeyBrakeOperationalState.stoppingLocalAutomation, .isolating, .restoring] {
            XCTAssertTrue(KeyBrakeTerminationGate.blocksTermination(state: state, launchRecoveryCheckCompleted: true, recoveryRequired: false, immediateQuitApproved: false))
            XCTAssertTrue(KeyBrakeTerminationGate.blocksTermination(state: state, launchRecoveryCheckCompleted: true, recoveryRequired: false, immediateQuitApproved: true))
        }

        XCTAssertFalse(KeyBrakeTerminationGate.blocksTermination(state: .normal, launchRecoveryCheckCompleted: true, recoveryRequired: false, immediateQuitApproved: false))
        XCTAssertFalse(KeyBrakeTerminationGate.blocksTermination(state: .isolated, launchRecoveryCheckCompleted: true, recoveryRequired: true, immediateQuitApproved: true))
        XCTAssertTrue(KeyBrakeTerminationGate.blocksTermination(state: .isolated, launchRecoveryCheckCompleted: true, recoveryRequired: true, immediateQuitApproved: false))
    }

    func testProcessIdentityRequiresExactBundleExecutableAndLaunchDate() {
        let launchDate = Date(timeIntervalSince1970: 1_725_000_000)
        let executableURL = URL(fileURLWithPath: "/Applications/Example Agent.app/Contents/MacOS/Example Agent")
        let identity = ProcessIdentity(
            processIdentifier: 42,
            bundleIdentifier: "com.example.agent",
            executableURL: executableURL,
            effectiveUserIdentifier: 501,
            launchDate: launchDate
        )

        XCTAssertTrue(identity.matches(bundleIdentifier: "com.example.agent", executableURL: executableURL, launchDate: launchDate))
        XCTAssertFalse(identity.matches(bundleIdentifier: "com.example.other", executableURL: executableURL, launchDate: launchDate))
        XCTAssertFalse(identity.matches(bundleIdentifier: "com.example.agent", executableURL: URL(fileURLWithPath: "/Applications/Other Agent.app/Contents/MacOS/Other Agent"), launchDate: launchDate))
        XCTAssertFalse(identity.matches(bundleIdentifier: "com.example.agent", executableURL: executableURL, launchDate: launchDate.addingTimeInterval(1)))
    }

    func testStopRemoteAccessPersistsBeforeNetworkMutationAndPublishesIsolation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: runner))
        let incident = await coordinator.stopRemoteAccess()
        XCTAssertEqual(incident.finalState, .isolated)
        XCTAssertTrue(incident.steps.contains { $0.targetID == "CurrentRecovery.json" && $0.outcome == .succeeded })
        let snapshot = try RecoveryStore(rootDirectory: root).load()
        XCTAssertEqual(snapshot?.networkChanges.first?.appliedEnabled, false)
        XCTAssertEqual(snapshot?.networkChanges.first?.currentEnabled, false)
    }

    func testIsolationPolicyPreventsUnrequestedNetworkMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: runner))

        let incident = await coordinator.stopRemoteAccess(policy: EmergencyIsolationPolicy(disableWiFi: false))
        let snapshot = try RecoveryStore(rootDirectory: root).load()

        XCTAssertEqual(incident.finalState, .isolated)
        XCTAssertEqual(snapshot?.networkChanges, [])
    }

    func testIllegalRepeatedRestoreIsRecordedAsConflict() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: FixtureNetworkController(), privacyController: PrivacyController(commandRunner: runner))
        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        XCTAssertEqual(incident.steps.first?.outcome, .conflict)
    }

    func testRestoreKeepsVpnDisconnectedInTheRetainedRecoverySnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let network = FixtureNetworkController(services: [NetworkService(id: "vpn", displayName: "Work VPN", kind: .vpn, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: runner))

        _ = await coordinator.stopRemoteAccess()
        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let snapshot = try RecoveryStore(rootDirectory: root).load()

        XCTAssertEqual(incident.finalState, .recoveryRequired)
        XCTAssertEqual(snapshot?.networkChanges.first?.appliedEnabled, false)
        XCTAssertEqual(snapshot?.networkChanges.first?.currentEnabled, false)
        XCTAssertTrue(snapshot?.unresolvedSteps.contains { $0.targetID == "vpn" } == true)
    }

    func testTargetApprovalChangesTheCoordinatorConfiguration() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: FixtureNetworkController(), privacyController: PrivacyController(commandRunner: runner))
        await coordinator.setTargetApproval(targetID: "anydesk", approved: true)
        let target = await coordinator.configuredTargets().first { $0.id == "anydesk" }
        XCTAssertTrue(target?.approvedByUser == true)
    }

    func testStopRemoteAccessRoutesVerifiedLaunchdLabelsThroughHelper() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let helper = RecordingHelper()
        let target = TargetDefinition(
            id: "custom-agent",
            displayName: "Custom Agent",
            category: .remoteAccess,
            executableURL: URL(fileURLWithPath: "/Applications/Custom Agent.app/Contents/MacOS/Custom Agent"),
            approvedByUser: true,
            verifiedLaunchAgentLabels: ["com.example.agent"]
        )
        let coordinator = EmergencyCoordinator(
            recoveryStore: RecoveryStore(rootDirectory: root),
            incidentStore: IncidentStore(rootDirectory: root),
            processController: FixtureProcessController(),
            espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []),
            networkController: FixtureNetworkController(),
            privacyController: PrivacyController(commandRunner: RecordingCommandRunner()),
            helper: helper,
            targetDefinitions: [target]
        )

        let incident = await coordinator.stopRemoteAccess()

        XCTAssertEqual(helper.commands, [
            .stopVerifiedLaunchdService(
                domain: "gui",
                label: "com.example.agent",
                expectedProgramPath: "/Applications/Custom Agent.app/Contents/MacOS/Custom Agent",
                expectedSigningRequirement: nil
            )
        ])
        XCTAssertTrue(incident.steps.contains { $0.subsystem == "launchd" && $0.targetID == "custom-agent:gui/com.example.agent" && $0.outcome == .succeeded })
    }
}
