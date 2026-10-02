import XCTest
@testable import KeyBrakeCore

final class FeatureContractTests: XCTestCase {
    func testRequiredMenuActionsAndStatesRemainPresent() throws {
        let contract = FeatureContract.fallback
        XCTAssertEqual(contract.schemaVersion, 1)
        for action in ["Stop Skynet Locally", "Stop Remote Access", "Revoke App Access…", "Restore Human Control", "Restart Espanso", "Open Incident Log", "Open Command Center", "Settings…", "Quit KeyBrake"] {
            XCTAssertTrue(contract.requiredMenuActions.contains(action), action)
        }
        XCTAssertEqual(Set(contract.requiredOperationalStates), Set(KeyBrakeOperationalState.allCases.map(\.rawValue)))
    }

    func testForbiddenClaimsAndRecoveryRulesRemainProtected() {
        let contract = FeatureContract.fallback
        XCTAssertTrue(contract.forbiddenClaims.contains("System Safe"))
        XCTAssertTrue(contract.forbiddenClaims.contains("All Remote Access Eliminated"))
        XCTAssertTrue(contract.recoveryRules.contains("restoreOnlyChangesMadeByKeyBrake"))
        XCTAssertTrue(contract.recoveryRules.contains("neverAutomaticallyRestoreTCCGrants"))
        XCTAssertTrue(contract.recoveryRules.contains("neverAutomaticallyRestartRemoteControlApps"))
        XCTAssertTrue(contract.recoveryRules.contains("neverReconnectVPNAutomatically"))
        XCTAssertTrue(contract.protectedTargets.contains("com.apple.WindowServer"))
        XCTAssertTrue(contract.protectedTargets.contains("kernel_task"))
    }

    func testBundledFeatureContractMatchesFallback() throws {
        let bundled = try FeatureContract.load(from: Self.bundledContractURL)
        XCTAssertEqual(bundled, FeatureContract.fallback)
    }

    func testCurrentLoadsBundledJSONAndFallsBackWhenMissing() throws {
        XCTAssertEqual(FeatureContract.current(resourceURL: Self.bundledContractURL), FeatureContract.fallback)
        XCTAssertEqual(FeatureContract.current(resourceURL: nil), FeatureContract.fallback)
        XCTAssertEqual(
            FeatureContract.current(resourceURL: URL(fileURLWithPath: "/tmp/keybrake-missing-contract.json")),
            FeatureContract.fallback
        )
    }

    private static var bundledContractURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/KeyBrakeFeatureContract.json")
    }
}

final class KeyBrakeProductSurfaceTests: XCTestCase {
    func testIsolationPreviewFollowsPolicyAndLabelsSandbox() {
        let disabledWiFi = EmergencyIsolationPolicy(
            disableWiFi: false,
            disableEthernet: true,
            disconnectVPN: true,
            disableRemoteLogin: false,
            disableRemoteAppleEvents: true
        )
        let lines = IsolationPlanPreview.lines(for: disabledWiFi, sandbox: true)
        XCTAssertEqual(lines.map(\.id), ["wifi", "ethernet", "vpn", "remote-login", "remote-apple-events", "sandbox"])
        XCTAssertTrue(lines[0].detail.contains("Leave Wi-Fi unchanged"))
        XCTAssertTrue(lines[3].detail.contains("Leave Remote Login unchanged"))
        XCTAssertTrue(lines[5].detail.contains("does not change host"))
    }

    func testConflictDetailsExposeOriginalAppliedAndCurrent() {
        let progress = RecoveryResourceProgress(
            subsystem: .network,
            resourceID: "wifi",
            displayName: "Wi-Fi",
            originalEnabled: true,
            appliedEnabled: false,
            observedEnabled: true,
            disposition: .conflict
        )
        let snapshot = RecoverySnapshot(
            incidentID: UUID(),
            originalOperationalState: .recoveryRequired,
            networkChanges: [
                NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, kind: NetworkServiceKind.wifi.rawValue),
            ],
            resourceProgress: [progress]
        )
        let details = snapshot.conflictDetails
        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details[0].original, "enabled")
        XCTAssertEqual(details[0].applied, "disabled")
        XCTAssertEqual(details[0].current, "enabled")
    }

    func testIncidentExportRoundTripsMetadataOnly() throws {
        let incident = IncidentRecord(
            initiatingAction: "Stop Remote Access",
            originalState: .normal,
            finalState: .recoveryRequired,
            steps: [],
            resolution: "review required"
        )
        let data = try KeyBrakeIncidentExport.jsonData(from: [incident])
        let decoded = try JSONDecoder().decode([IncidentRecord].self, from: data)
        XCTAssertEqual(decoded, [incident])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("password"))
        XCTAssertFalse(text.contains("tcc.db"))
    }
}
