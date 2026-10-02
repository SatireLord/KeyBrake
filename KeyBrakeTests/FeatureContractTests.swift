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
        XCTAssertEqual(lines.map(\.id), ["wifi", "ethernet", "vpn", "remote-login", "remote-apple-events", "remote-targets", "sandbox"])
        XCTAssertTrue(lines[0].detail.contains("Leave Wi-Fi unchanged"))
        XCTAssertTrue(lines[3].detail.contains("Leave Remote Login unchanged"))
        XCTAssertTrue(lines[6].detail.contains("does not change host"))
        let named = IsolationPlanPreview.lines(for: .standard, sandbox: false, approvedRemoteTargetNames: ["Screen Sharing"])
        XCTAssertTrue(named.contains { $0.id == "remote-targets" && $0.detail.contains("Screen Sharing") })
        XCTAssertFalse(IsolationPlanPreview.affectsIsolation(
            for: EmergencyIsolationPolicy(disableWiFi: false, disableEthernet: false, disconnectVPN: false, disableRemoteLogin: false, disableRemoteAppleEvents: false),
            approvedRemoteTargetNames: []
        ))
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

    func testBlastRadiusPartialStopAndSessionWarningStaySpecific() {
        XCTAssertEqual(KeyBrakeStopExplanation.localBlastRadius(names: ["Espanso", "Espanso"]), "Will stop: Espanso.")
        XCTAssertEqual(KeyBrakeStopExplanation.localBlastRadius(names: []), "No local typing apps are set to stop.")
        let changing = IsolationPlanPreview.changingTitles(for: .standard, sandbox: false, approvedRemoteTargetNames: ["AnyDesk"])
        XCTAssertTrue(changing.contains("Wi-Fi"))
        XCTAssertTrue(changing.contains("Remote applications"))
        XCTAssertFalse(changing.contains("Fixture rehearsal"))
        let idle = EmergencyIsolationPolicy(disableWiFi: false, disableEthernet: false, disconnectVPN: false, disableRemoteLogin: false, disableRemoteAppleEvents: false)
        XCTAssertEqual(KeyBrakeStopExplanation.remoteBlastRadius(changingTitles: IsolationPlanPreview.changingTitles(for: idle, sandbox: false)), "This isolation plan changes nothing.")
        let notice = KeyBrakeRemoteSessionNotice.notice(loginHosts: ["192.0.2.10"], screenSharingConnected: true)
        XCTAssertEqual(notice?.warningSentence, "You are connected through Screen Sharing and Remote Login from 192.0.2.10. Stop Remote Access can disconnect this session.")
        XCTAssertNil(KeyBrakeRemoteSessionNotice.notice(loginHosts: ["  "], screenSharingConnected: false))
        let incident = IncidentRecord(
            initiatingAction: "Stop Remote Access",
            originalState: .normal,
            finalState: .partiallyIsolated,
            steps: [
                OperationStepResult(subsystem: "network", targetID: "wifi", targetDisplayName: "Wi-Fi", requestedState: "disabled", observedPostState: "disabled", operationDescription: "disabled", outcome: .succeeded),
                OperationStepResult(subsystem: "sharing", targetID: "remote-login", targetDisplayName: "Remote Login", requestedState: "disabled", operationDescription: "helper unavailable", outcome: .failed),
            ]
        )
        XCTAssertEqual(
            KeyBrakeStopExplanation.partialStopSummary(state: .partiallyIsolated, incident: incident),
            "Changed: Wi-Fi. Stayed as it was: Remote Login."
        )
        let since = Date(timeIntervalSinceNow: -120)
        let stillOff = KeyBrakeStopExplanation.stillOffSentence(names: ["Wi-Fi"], since: since, now: Date())
        XCTAssertTrue(stillOff.contains("Still off: Wi-Fi."))
        XCTAssertTrue(stillOff.contains("Off for 2 minutes."))
        XCTAssertEqual(KeyBrakeHelperRegistrationCopy.buttonTitle(signing: .unsignedOrAdHoc), KeyBrakeHelperRegistrationCopy.unsignedSentence)
        XCTAssertFalse(KeyBrakeHelperRegistrationCopy.canRegister(signing: .unsignedOrAdHoc))
        XCTAssertTrue(KeyBrakeHelperRegistrationCopy.canRegister(signing: .developerID))
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
