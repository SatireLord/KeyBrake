import XCTest
@testable import KeyBrakeCore

private struct FixtureProcessController: ProcessControlling {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] { [] }
    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult { ProcessTargetResult(targetID: "fixture", displayName: "Fixture", identity: identity, outcome: .succeeded, detail: "fixture") }
}

final class EmergencyCoordinatorTests: XCTestCase {
    func testStopRemoteAccessPersistsBeforeNetworkMutationAndPublishesIsolation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let network = FixtureNetworkController(services: [NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true)])
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: network, privacyController: PrivacyController(commandRunner: runner))
        let incident = await coordinator.stopRemoteAccess()
        XCTAssertEqual(incident.finalState, .isolated)
        XCTAssertTrue(incident.steps.contains { $0.targetID == "CurrentRecovery.json" && $0.outcome == .succeeded })
        XCTAssertNotNil(try RecoveryStore(rootDirectory: root).load())
    }

    func testIllegalRepeatedRestoreIsRecordedAsConflict() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = RecordingCommandRunner()
        let coordinator = EmergencyCoordinator(recoveryStore: RecoveryStore(rootDirectory: root), incidentStore: IncidentStore(rootDirectory: root), processController: FixtureProcessController(), espanso: EspansoAdapter(commandRunner: runner, executableCandidates: []), networkController: FixtureNetworkController(), privacyController: PrivacyController(commandRunner: runner))
        let incident = await coordinator.restoreHumanControl(selection: RecoverySelection(restoreNetwork: true))
        XCTAssertEqual(incident.steps.first?.outcome, .conflict)
    }
}
