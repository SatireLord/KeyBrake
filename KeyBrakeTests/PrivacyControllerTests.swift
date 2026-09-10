import XCTest
@testable import KeyBrakeCore

final class PrivacyControllerTests: XCTestCase {
    func testPrivacyResetUsesServiceAndBundleIdentifier() async {
        let runner = RecordingCommandRunner()
        let controller = PrivacyController(commandRunner: runner)
        let results = await controller.reset(PrivacyResetRequest(bundleIdentifier: "com.example.fixture", services: [.inputMonitoring, .postEvent]), targetDisplayName: "Fixture")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(runner.calls.map(\.request.arguments)), Set([["reset", "ListenEvent", "com.example.fixture"], ["reset", "PostEvent", "com.example.fixture"]]))
    }

    func testPrivacyControllerRejectsKeyBrakeSelfTarget() async {
        let runner = RecordingCommandRunner()
        let controller = PrivacyController(commandRunner: runner)
        let result = await controller.reset(PrivacyResetRequest(bundleIdentifier: "org.realitygood.KeyBrake", services: [.all]), targetDisplayName: "KeyBrake")
        XCTAssertEqual(result.first?.outcome, .conflict)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testPrivacyControllerEnforcesCatalogMinimumMajorVersion() async {
        let runner = RecordingCommandRunner()
        let controller = PrivacyController(commandRunner: runner, operatingSystemMajorVersion: 13)
        let result = await controller.reset(PrivacyResetRequest(bundleIdentifier: "com.example.fixture", services: [.inputMonitoring]), targetDisplayName: "Fixture")

        XCTAssertEqual(result.first?.outcome, .unsupported)
        XCTAssertEqual(result.first?.operationDescription, "Privacy service requires macOS 14 or newer")
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testPrivacyControllerRejectsEnumCasesOutsideCatalogAllowlist() async {
        let runner = RecordingCommandRunner(results: [
            .success(CommandResult(terminationStatus: 0, standardOutput: Data(), standardError: Data(), timedOut: false, startedAt: Date(), finishedAt: Date()))
        ])
        let controller = PrivacyController(commandRunner: runner, operatingSystemMajorVersion: 99)
        let result = await controller.reset(PrivacyResetRequest(bundleIdentifier: "com.example.fixture", services: [.camera, .externalCameraMedia]), targetDisplayName: "Fixture")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map(\.outcome)), [.succeeded, .unsupported])
        XCTAssertEqual(runner.calls.map(\.request.arguments), [["reset", "Camera", "com.example.fixture"]])
    }
}
