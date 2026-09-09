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
}
