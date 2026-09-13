import XCTest
@testable import KeyBrakeCore

final class FeatureContractTests: XCTestCase {
    func testRequiredMenuActionsAndStatesRemainPresent() throws {
        let contract = FeatureContract.fallback
        XCTAssertEqual(contract.schemaVersion, 1)
        for action in ["Stop Skynet Locally", "Stop Remote Access", "Revoke App Access…", "Restore Human Control", "Restart Espanso", "Open Incident Log", "Settings…", "Quit KeyBrake"] {
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
