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

    func testKeyboardInputRequestHasFixedTwoServiceScope() async {
        let runner = RecordingCommandRunner(results: [
            .success(commandResult(status: 0, timedOut: false)),
            .success(commandResult(status: 0, timedOut: false))
        ])
        let request = PrivacyResetRequest.keyboardInput(bundleIdentifier: "com.example.fixture")
        let results = await PrivacyController(commandRunner: runner).reset(request, targetDisplayName: "Fixture")

        XCTAssertEqual(request.scope, .keyboardInput)
        XCTAssertEqual(request.services, [.inputMonitoring, .postEvent])
        XCTAssertEqual(Set(runner.calls.map(\.request.arguments)), Set([
            ["reset", "ListenEvent", "com.example.fixture"],
            ["reset", "PostEvent", "com.example.fixture"]
        ]))
        XCTAssertEqual(Set(results.map(\.outcome)), [.succeeded])
    }

    func testPrivacyControllerRejectsMalformedBundleIdentifiers() async {
        let runner = RecordingCommandRunner()
        let controller = PrivacyController(commandRunner: runner)
        let malformed = [
            "",
            "com",
            ".com.example",
            "com..example",
            "com.example.",
            " com.example.fixture",
            "com.example.fixture ",
            "com.example.fixture_name",
            "com.example/fixture",
            "com.example.fixture\n"
        ]

        for bundleIdentifier in malformed {
            let results = await controller.reset(
                PrivacyResetRequest(bundleIdentifier: bundleIdentifier, services: [.inputMonitoring]),
                targetDisplayName: "Fixture"
            )
            XCTAssertEqual(results.first?.outcome, .conflict, bundleIdentifier.debugDescription)
        }
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testPrivacyControllerRejectsSystemAndProtectedBundleIdentifiers() async {
        let runner = RecordingCommandRunner()
        let controller = PrivacyController(commandRunner: runner)
        let protected = [
            "org.realitygood.KeyBrake",
            "org.realitygood.keybrake",
            "com.apple",
            "com.apple.dock",
            "com.apple.Safari"
        ]

        for bundleIdentifier in protected {
            let results = await controller.reset(
                PrivacyResetRequest(bundleIdentifier: bundleIdentifier, services: [.inputMonitoring]),
                targetDisplayName: "Protected"
            )
            XCTAssertEqual(results.first?.outcome, .conflict, bundleIdentifier)
        }
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

    func testPrivacyControllerPreservesPerServiceFailuresAndFailsTimedOutZeroExit() async {
        let runner = ServiceMappedCommandRunner(resultsByService: [
            "Camera": commandResult(status: 7, timedOut: false),
            "ListenEvent": commandResult(status: 0, timedOut: false),
            "PostEvent": commandResult(status: 0, timedOut: true)
        ])
        let request = PrivacyResetRequest(bundleIdentifier: "com.example.fixture", services: [.camera, .inputMonitoring, .postEvent])
        let results = await PrivacyController(commandRunner: runner).reset(request, targetDisplayName: "Fixture")
        let resultsByService = Dictionary(uniqueKeysWithValues: results.map { ($0.targetID, $0) })

        XCTAssertEqual(resultsByService["Camera"]?.outcome, .failed)
        XCTAssertEqual(resultsByService["ListenEvent"]?.outcome, .succeeded)
        XCTAssertEqual(resultsByService["PostEvent"]?.outcome, .failed)
        XCTAssertEqual(resultsByService["PostEvent"]?.terminationStatus, 0)
        XCTAssertEqual(resultsByService["PostEvent"]?.operationDescription, "tccutil invocation timed out")
        let calls = await runner.calls()
        XCTAssertEqual(calls.count, 3)
    }
}

private actor ServiceMappedCommandRunner: CommandRunning {
    private let resultsByService: [String: CommandResult]
    private var recordedRequests: [CommandRequest] = []

    init(resultsByService: [String: CommandResult]) {
        self.resultsByService = resultsByService
    }

    func run(_ request: CommandRequest) async throws -> CommandResult {
        recordedRequests.append(request)
        guard request.arguments.count == 3,
              let result = resultsByService[request.arguments[1]] else {
            throw CommandRunnerError.launchFailed("No service-specific fixture result exists")
        }
        return result
    }

    func calls() -> [CommandRequest] { recordedRequests }
}

private func commandResult(status: Int32, timedOut: Bool) -> CommandResult {
    CommandResult(
        terminationStatus: status,
        standardOutput: Data(),
        standardError: Data(),
        timedOut: timedOut,
        startedAt: Date(),
        finishedAt: Date()
    )
}
