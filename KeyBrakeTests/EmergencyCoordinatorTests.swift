import XCTest
@testable import KeyBrakeCore

private struct FixtureProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] { [] }
    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult { ProcessTargetResult(targetID: "fixture", displayName: "Fixture", identity: identity, outcome: .succeeded, detail: "fixture") }
}

private final class UnreadableRecoveryFileManager: FileManager, @unchecked Sendable {
    private let unreadablePath: String

    init(unreadablePath: String) {
        self.unreadablePath = unreadablePath
        super.init()
    }

    override func fileExists(atPath path: String) -> Bool {
        path == unreadablePath ? false : super.fileExists(atPath: path)
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        guard path == unreadablePath else { return try super.attributesOfItem(atPath: path) }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
    }
}

private actor FixtureSharingAdapter: SharingServiceAdapter {
    nonisolated let identifier: String
    nonisolated let displayName: String
    private var enabled: Bool

    init(identifier: String, displayName: String, enabled: Bool, supported: Bool = true) {
        self.identifier = identifier
        self.displayName = displayName
        self.enabled = enabled
        self.supported = supported
    }

    nonisolated let supported: Bool

    func detect() async -> SharingServiceCapability {
        SharingServiceCapability(id: identifier, displayName: displayName, supported: supported, enabled: enabled)
    }

    func disable(expectedState: SharingServiceState) async -> OperationStepResult {
        guard supported, expectedState.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Fixture sharing service unsupported", outcome: .unsupported)
        }
        guard enabled == expectedState.enabled else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Fixture sharing state changed before isolation", outcome: .conflict)
        }
        enabled = false
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", observedPreState: "enabled", observedPostState: "disabled", operationDescription: "Fixture sharing isolation", outcome: .succeeded)
    }

    func restore(originalState: SharingServiceState, appliedState: SharingServiceState) async -> OperationStepResult {
        guard supported, originalState.supported, appliedState.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "restore", operationDescription: "Fixture sharing service unsupported", outcome: .unsupported)
        }
        guard enabled == appliedState.enabled else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", operationDescription: "Fixture sharing state changed after isolation", outcome: .conflict)
        }
        enabled = originalState.enabled
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", observedPostState: "enabled", operationDescription: "Fixture sharing restoration", outcome: .succeeded)
    }
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

    func testPrivacyResetsAreRejectedBeforeRecoveryStoreHydration() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let coordinator = makePrivacyTestCoordinator(rootDirectory: root, runner: runner)

        let verifiedBeforeHydration = await coordinator.hasVerifiedRecoveryStoreHydration()
        let appAccessIncident = await coordinator.revokeAppAccess(
            targetID: "fixture-app",
            services: [.inputMonitoring],
            bundleIdentifier: "com.example.fixture",
            displayName: "Fixture App"
        )
        let keyboardIncident = await coordinator.resetKeyboardAccess(target: privacyTestTarget())

        XCTAssertFalse(verifiedBeforeHydration)
        XCTAssertEqual(appAccessIncident.steps.first?.outcome, .conflict)
        XCTAssertEqual(keyboardIncident.steps.first?.outcome, .conflict)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testPrivacyResetsAreRejectedWhenRecoverySnapshotDecodeFails() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: root)
        let corruptSnapshot = Data("not a recovery snapshot".utf8)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try corruptSnapshot.write(to: store.recoveryURL)
        let runner = RecordingCommandRunner()
        let coordinator = makePrivacyTestCoordinator(rootDirectory: root, runner: runner)

        let hydratedSnapshot = await coordinator.recoverUnresolvedStateAtLaunch()
        let verifiedAfterFailure = await coordinator.hasVerifiedRecoveryStoreHydration()
        let stateAfterFailure = await coordinator.state()
        let appAccessIncident = await coordinator.revokeAppAccess(
            targetID: "fixture-app",
            services: [.inputMonitoring],
            bundleIdentifier: "com.example.fixture",
            displayName: "Fixture App"
        )
        let keyboardIncident = await coordinator.resetKeyboardAccess(target: privacyTestTarget())

        XCTAssertNil(hydratedSnapshot)
        XCTAssertFalse(verifiedAfterFailure)
        XCTAssertEqual(stateAfterFailure, .recoveryRequired)
        XCTAssertEqual(appAccessIncident.steps.first?.outcome, .conflict)
        XCTAssertEqual(keyboardIncident.steps.first?.outcome, .conflict)
        XCTAssertTrue(runner.calls.isEmpty)
        XCTAssertEqual(try Data(contentsOf: store.recoveryURL), corruptSnapshot)
    }

    func testPrivacyResetsAreRejectedWhenRecoverySnapshotIsUnreadable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let readableStore = RecoveryStore(rootDirectory: root)
        let pendingSnapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .normal,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
            ]
        )
        try readableStore.save(pendingSnapshot)
        let unreadableFileManager = UnreadableRecoveryFileManager(unreadablePath: readableStore.recoveryURL.path)
        let runner = RecordingCommandRunner()
        let coordinator = makePrivacyTestCoordinator(
            rootDirectory: root,
            runner: runner,
            recoveryFileManager: unreadableFileManager
        )

        let hydratedSnapshot = await coordinator.recoverUnresolvedStateAtLaunch()
        let hydrationVerified = await coordinator.hasVerifiedRecoveryStoreHydration()
        let reset = await coordinator.resetKeyboardAccess(target: privacyTestTarget())

        XCTAssertFalse(unreadableFileManager.fileExists(atPath: readableStore.recoveryURL.path))
        XCTAssertNil(hydratedSnapshot)
        XCTAssertFalse(hydrationVerified)
        XCTAssertEqual(reset.steps.first?.outcome, .conflict)
        XCTAssertTrue(runner.calls.isEmpty)
        XCTAssertEqual(try RecoveryStore(rootDirectory: root).load(), pendingSnapshot)
    }

    func testSuccessfulEmptyAndPendingRecoveryHydrationPermitPrivacyResets() async throws {
        let emptyRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let emptyCoordinator = makePrivacyTestCoordinator(rootDirectory: emptyRoot, runner: RecordingCommandRunner())

        let emptySnapshot = await emptyCoordinator.recoverUnresolvedStateAtLaunch()
        let emptyStoreVerified = await emptyCoordinator.hasVerifiedRecoveryStoreHydration()

        XCTAssertNil(emptySnapshot)
        XCTAssertTrue(emptyStoreVerified)

        let pendingRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pendingStore = RecoveryStore(rootDirectory: pendingRoot)
        try pendingStore.save(RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .normal,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: "wifi")
            ]
        ))
        let runner = RecordingCommandRunner()
        let pendingCoordinator = makePrivacyTestCoordinator(rootDirectory: pendingRoot, runner: runner)

        let pendingSnapshot = await pendingCoordinator.recoverUnresolvedStateAtLaunch()
        let pendingStoreVerified = await pendingCoordinator.hasVerifiedRecoveryStoreHydration()
        let pendingState = await pendingCoordinator.state()
        _ = await pendingCoordinator.revokeAppAccess(
            targetID: "fixture-app",
            services: [.inputMonitoring],
            bundleIdentifier: "com.example.fixture",
            displayName: "Fixture App"
        )
        _ = await pendingCoordinator.resetKeyboardAccess(target: privacyTestTarget())

        XCTAssertNotNil(pendingSnapshot)
        XCTAssertTrue(pendingStoreVerified)
        XCTAssertEqual(pendingState, .recoveryRequired)
        XCTAssertEqual(Set(runner.calls.map { $0.request.arguments }), Set([
            ["reset", "ListenEvent", "com.example.fixture"],
            ["reset", "PostEvent", "com.example.fixture"]
        ]))
        XCTAssertEqual(runner.calls.count, 3)
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

    func testExplicitVPNRetentionIsVerifiedAndDoesNotReconnectTheVPN() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let network = FixtureNetworkController(services: [NetworkService(id: "vpn", displayName: "Work VPN", kind: .vpn, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()))

        _ = await coordinator.stopRemoteAccess()
        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true, retainVPNDisconnected: true))
        let vpn = await network.inventory().first

        XCTAssertEqual(incident.finalState, .normal)
        XCTAssertEqual(vpn?.enabled, false)
        XCTAssertEqual(vpn?.enabledObservationKnown, true)
        XCTAssertTrue(incident.steps.contains { $0.targetID == "vpn" && $0.outcome == .skipped && $0.operationDescription.contains("no reconnection command") })
        XCTAssertNil(try RecoveryStore(rootDirectory: root).load())
    }

    func testUnknownNetworkStateStaysUnknownAndIsNeverConvertedToDisabled() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: false, enabledObservationKnown: false, active: false)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()))

        let isolation = await coordinator.stopRemoteAccess()
        let afterIsolation = try XCTUnwrap(RecoveryStore(rootDirectory: root).load()?.resourceProgress.first)
        let restoration = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let afterRestore = try XCTUnwrap(RecoveryStore(rootDirectory: root).load()?.resourceProgress.first)
        let live = await network.inventory().first

        XCTAssertEqual(isolation.finalState, .partiallyIsolated)
        XCTAssertFalse(afterIsolation.originalStateKnown)
        XCTAssertNil(afterIsolation.observedEnabled)
        XCTAssertEqual(afterIsolation.disposition, .unverified)
        XCTAssertEqual(restoration.finalState, .recoveryRequired)
        XCTAssertFalse(afterRestore.originalStateKnown)
        XCTAssertNil(afterRestore.observedEnabled)
        XCTAssertEqual(afterRestore.disposition, .unverified)
        XCTAssertEqual(live?.enabled, false)
        XCTAssertFalse(live?.enabledObservationKnown ?? true)
    }

    func testStagedNetworkAndSharingRestoreKeepsTheUnselectedResourcePending() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true)])
        let sharingAdapter = FixtureSharingAdapter(identifier: "remote-login", displayName: "Remote Login", enabled: true)
        let sharing = SharingServiceController(adapters: [sharingAdapter])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()), sharingController: sharing)

        let isolated = await coordinator.stopRemoteAccess()
        XCTAssertEqual(isolated.finalState, .isolated)

        let networkRestore = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let pendingSnapshot = try XCTUnwrap(RecoveryStore(rootDirectory: root).load())
        let networkProgress = pendingSnapshot.resourceProgress.first { $0.resourceID == "wifi" }
        let sharingProgress = pendingSnapshot.resourceProgress.first { $0.resourceID == "remote-login" }
        XCTAssertEqual(networkRestore.finalState, .recoveryRequired)
        XCTAssertEqual(networkProgress?.appliedEnabled, false)
        XCTAssertEqual(networkProgress?.observedEnabled, true)
        XCTAssertEqual(networkProgress?.disposition, .restored)
        XCTAssertEqual(sharingProgress?.appliedEnabled, false)
        XCTAssertEqual(sharingProgress?.observedEnabled, false)
        XCTAssertEqual(sharingProgress?.disposition, .pending)

        let sharingRestore = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: false, sharingServiceIDs: ["remote-login"]))
        let liveSharing = await sharingAdapter.detect()
        let liveNetwork = await network.inventory().first
        XCTAssertEqual(sharingRestore.finalState, .normal)
        XCTAssertTrue(liveSharing.enabled)
        XCTAssertTrue(liveNetwork?.enabled == true)
        XCTAssertNil(try RecoveryStore(rootDirectory: root).load())
    }

    func testEmptyProgressArrayCannotClearARecordedNetworkRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: root)
        let snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .normal,
            networkChanges: [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: NetworkServiceKind.wifi.rawValue)],
            resourceProgress: []
        )
        try store.save(snapshot)
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: false, active: false)])
        let coordinator = EmergencyCoordinator(recoveryStore: store, incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()), initialState: .recoveryRequired)

        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let live = await network.inventory().first

        XCTAssertEqual(incident.finalState, .recoveryRequired)
        XCTAssertEqual(live?.enabled, false)
        XCTAssertNotNil(try store.load())
    }

    func testConflictingDuplicateVPNJournalCannotRestoreOrClearRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: root)
        try store.save(RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .normal,
            networkChanges: [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: NetworkServiceKind.wifi.rawValue)],
            vpnConnections: [NetworkChange(id: "wifi", displayName: "Work VPN", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: NetworkServiceKind.vpn.rawValue, isVPN: true)]
        ))
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: false, active: false)])
        let coordinator = EmergencyCoordinator(recoveryStore: store, incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()), initialState: .recoveryRequired)

        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let live = await network.inventory().first

        XCTAssertEqual(incident.finalState, .recoveryRequired)
        XCTAssertTrue(incident.steps.contains { $0.targetID == "resource-journal" && $0.outcome == .conflict })
        XCTAssertEqual(live?.enabled, false)
        XCTAssertNotNil(try store.load())
    }

    func testFinalAuditWriteFailureRetainsTheRecoverySnapshot() async throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let blockedIncidentRoot = temporary.appendingPathComponent("not-a-directory")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        try Data("file blocks directory creation".utf8).write(to: blockedIncidentRoot)
        let recoveryRoot = temporary.appendingPathComponent("Recovery", isDirectory: true)
        let store = RecoveryStore(rootDirectory: recoveryRoot)
        try store.save(RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .normal,
            networkChanges: [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: true, kind: NetworkServiceKind.wifi.rawValue)]
        ))
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: store, incidentStore: IncidentStore(rootDirectory: blockedIncidentRoot), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()), initialState: .recoveryRequired)

        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))

        XCTAssertEqual(incident.finalState, .recoveryRequired)
        XCTAssertTrue(incident.steps.contains { $0.subsystem == "recovery" && $0.operationDescription.contains("Final audit could not be saved") })
        XCTAssertNotNil(try store.load())
        let live = await network.inventory().first
        XCTAssertEqual(live?.enabled, true)
    }

    func testRestorationReturnsToRecordedPreIsolationOperationalState() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RecoveryStore(rootDirectory: root)
        try store.save(RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .localAutomationStopped,
            networkChanges: [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, appliedEnabled: false, currentEnabled: false, kind: NetworkServiceKind.wifi.rawValue)]
        ))
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: false, active: false)])
        let coordinator = EmergencyCoordinator(recoveryStore: store, incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: RecordingCommandRunner(), executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: RecordingCommandRunner()), initialState: .recoveryRequired)

        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        let finalState = await coordinator.state()

        XCTAssertEqual(incident.finalState, .localAutomationStopped)
        XCTAssertEqual(finalState, .localAutomationStopped)
        XCTAssertNil(try store.load())
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

private func makePrivacyTestCoordinator(
    rootDirectory: URL,
    runner: RecordingCommandRunner,
    recoveryFileManager: FileManager = .default
) -> EmergencyCoordinator {
    EmergencyCoordinator(
        recoveryStore: RecoveryStore(rootDirectory: rootDirectory, fileManager: recoveryFileManager),
        incidentStore: IncidentStore(rootDirectory: rootDirectory),
        processController: FixtureProcessController(),
        espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []),
        networkController: FixtureNetworkController(),
        privacyController: PrivacyController(commandRunner: runner),
        targetDefinitions: [privacyTestTarget()]
    )
}

private func privacyTestTarget() -> TargetDefinition {
    TargetDefinition(
        id: "fixture-app",
        displayName: "Fixture App",
        category: .remoteAccess,
        bundleIdentifier: "com.example.fixture"
    )
}
