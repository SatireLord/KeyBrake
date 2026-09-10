import XCTest
@testable import KeyBrakeCore

final class HelperAuthorizationTests: XCTestCase {
    func testTypedHelperValidatorRejectsProtectedLaunchdAndRelativePaths() {
        let validator = HelperCommandValidator()
        XCTAssertFalse(validator.validate(.stopVerifiedLaunchdService(domain: "system", label: "com.apple.sshd", expectedProgramPath: "/usr/libexec/sshd", expectedSigningRequirement: nil)))
        XCTAssertFalse(validator.validate(.stopVerifiedLaunchdService(domain: "system", label: "com.example.agent", expectedProgramPath: "usr/local/bin/agent", expectedSigningRequirement: nil)))
        XCTAssertTrue(validator.validate(.setNetworkServiceEnabled(serviceID: "service-1", serviceName: "USB Ethernet", expectedDevice: "en7", enabled: false)))
    }

    func testHelperCommandCarriesLaunchdIdentityExpectations() {
        let command = HelperCommand.stopVerifiedLaunchdService(
            domain: "gui",
            label: "com.example.agent",
            expectedProgramPath: "/Applications/Agent.app/Contents/MacOS/Agent",
            expectedSigningRequirement: "anchor apple generic"
        )
        XCTAssertTrue(HelperCommandValidator().validate(command))
    }

    func testHelperXPCCodecRoundTripsCommandAndResult() throws {
        let command = HelperCommand.setNetworkServiceEnabled(serviceID: "wifi", serviceName: "Wi-Fi", expectedDevice: nil, enabled: false)
        let payload = try HelperXPCCodec.encode(command)
        let decoded = try HelperXPCCodec.decodeCommand(payload)
        XCTAssertEqual(decoded, command)
        let step = OperationStepResult(subsystem: "helper", targetID: "wifi", targetDisplayName: "Wi-Fi", requestedState: "applied", operationDescription: "test", outcome: .succeeded)
        let encodedResult = try HelperXPCCodec.encode(step)
        let decodedResult = try HelperXPCCodec.decodeResult(encodedResult)
        XCTAssertEqual(decodedResult.outcome, .succeeded)
    }

    func testSharingStateParserRequiresAnExplicitState() {
        XCTAssertEqual(SystemSharingServiceAdapter.parseEnabledState("Remote Login: On\n"), true)
        XCTAssertEqual(SystemSharingServiceAdapter.parseEnabledState("Remote Login: Off\n"), false)
        XCTAssertNil(SystemSharingServiceAdapter.parseEnabledState("Remote Login: Unknown\n"))
    }

    func testNetworkControllerRoutesIsolationThroughHelper() async {
        let helper = RecordingHelper()
        let controller = SystemNetworkController(commandRunner: RecordingCommandRunner(), helper: helper)
        let changes = [NetworkChange(id: "wifi", displayName: "Wi-Fi", originalEnabled: true, kind: NetworkServiceKind.wifi.rawValue)]
        _ = await controller.isolate(changes)
        XCTAssertEqual(helper.commands.count, 1)
        XCTAssertEqual(helper.commands.first, .setNetworkServiceEnabled(serviceID: "wifi", serviceName: "Wi-Fi", expectedDevice: nil, enabled: false))
    }

    func testSharingAdapterRoutesDisableAndRestoreThroughHelperAndVerifiesBothStates() async {
        let runner = RecordingCommandRunner(results: [
            .success(commandResult(output: "Remote Login: Off\n")),
            .success(commandResult(output: "Remote Login: Off\n")),
            .success(commandResult(output: "Remote Login: On\n"))
        ])
        let helper = RecordingHelper()
        let adapter = SystemSharingServiceAdapter(
            identifier: "remote-login",
            displayName: "Remote Login",
            commandRunner: runner,
            helper: helper,
            getterArguments: ["-getremotelogin"],
            enableArguments: ["-setremotelogin", "on"],
            disableArguments: ["-setremotelogin", "off"]
        )

        let disabled = await adapter.disable(expectedState: SharingServiceState(enabled: true, supported: true))
        let restored = await adapter.restore(
            originalState: SharingServiceState(enabled: true, supported: true),
            appliedState: SharingServiceState(enabled: false, supported: true)
        )

        XCTAssertEqual(disabled.outcome, .succeeded)
        XCTAssertEqual(restored.outcome, .succeeded)
        XCTAssertEqual(helper.commands, [.setRemoteLoginEnabled(false), .setRemoteLoginEnabled(true)])
        XCTAssertEqual(runner.calls.count, 3)
        XCTAssertTrue(runner.calls.allSatisfy { $0.request.arguments == ["-getremotelogin"] })
    }

    func testSharingAdapterRefusesRestoreAfterExternalStateChange() async {
        let runner = RecordingCommandRunner(results: [.success(commandResult(output: "Remote Login: On\n"))])
        let helper = RecordingHelper()
        let adapter = SystemSharingServiceAdapter(
            identifier: "remote-login",
            displayName: "Remote Login",
            commandRunner: runner,
            helper: helper,
            getterArguments: ["-getremotelogin"],
            enableArguments: ["-setremotelogin", "on"],
            disableArguments: ["-setremotelogin", "off"]
        )

        let result = await adapter.restore(
            originalState: SharingServiceState(enabled: true, supported: true),
            appliedState: SharingServiceState(enabled: false, supported: true)
        )

        XCTAssertEqual(result.outcome, .conflict)
        XCTAssertTrue(helper.commands.isEmpty)
    }

    private func commandResult(output: String) -> CommandResult {
        CommandResult(terminationStatus: 0, standardOutput: Data(output.utf8), standardError: Data(), timedOut: false, startedAt: Date(), finishedAt: Date())
    }
}
