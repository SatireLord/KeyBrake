import XCTest
@testable import KeyBrakeCore

final class NetworkControllerTests: XCTestCase {
    func testNetworkParserNormalizesNamesOrderAndKinds() {
        let names = NetworkServiceParser.serviceNames(from: "An asterisk denotes that a network service is disabled.\n*Wi-Fi\nUSB Ethernet\n")
        let order = NetworkServiceParser.serviceOrder(from: "(1) Wi-Fi\nHardware Port: Wi-Fi, Device: en0\n(2) Thunderbolt Bridge\nHardware Port: Thunderbolt Bridge, Device: bridge0\n")

        XCTAssertEqual(names, ["Wi-Fi", "USB Ethernet"])
        XCTAssertEqual(order, [
            ParsedNetworkService(displayName: "Wi-Fi", hardwarePort: "Wi-Fi", device: "en0"),
            ParsedNetworkService(displayName: "Thunderbolt Bridge", hardwarePort: "Thunderbolt Bridge", device: "bridge0")
        ])
        XCTAssertEqual(NetworkServiceParser.kind(displayName: "Wi-Fi", hardwarePort: "Wi-Fi", device: "en0"), .wifi)
        XCTAssertEqual(NetworkServiceParser.kind(displayName: "Thunderbolt Bridge", hardwarePort: "Thunderbolt Bridge", device: "bridge0"), .thunderbolt)
        XCTAssertEqual(NetworkServiceParser.stableID(for: "Wi-Fi"), "network-service-wi-fi")
    }

    func testIsolationPolicyFiltersRequestedSubsystems() {
        let policy = EmergencyIsolationPolicy(disableWiFi: false, disableEthernet: true, disconnectVPN: false, disableRemoteAppleEvents: false)

        XCTAssertFalse(policy.permits(.wifi))
        XCTAssertTrue(policy.permits(.ethernet))
        XCTAssertFalse(policy.permits(.vpn))
        XCTAssertTrue(policy.permitsSharing(identifier: "remote-login"))
        XCTAssertFalse(policy.permitsSharing(identifier: "remote-apple-events"))
    }

    func testFixturePreservesDisabledPreStateAndLeavesVPNDisconnected() async {
        let controller = FixtureNetworkController(services: [
            NetworkService(id: "wifi", displayName: "Wi-Fi", kind: .wifi, enabled: true, active: true),
            NetworkService(id: "ethernet", displayName: "USB Ethernet", kind: .usbEthernet, enabled: false, active: false),
            NetworkService(id: "vpn", displayName: "Work VPN", kind: .vpn, enabled: true, active: true)
        ])
        let snapshot = await controller.captureSnapshot()
        let isolation = await controller.isolate(snapshot)
        XCTAssertTrue(isolation.contains { $0.targetID == "wifi" && $0.outcome == .succeeded })
        XCTAssertTrue(isolation.contains { $0.targetID == "ethernet" && $0.outcome == .alreadyInDesiredState })
        let restoration = await controller.restore(snapshot)
        XCTAssertTrue(restoration.contains { $0.targetID == "vpn" && $0.operationDescription.contains("VPN remains disconnected") && $0.outcome == .skipped })
    }

    func testSystemNetworkIsolationUsesHelperAndVerifiesDisabledState() async {
        let runner = RecordingCommandRunner(results: [.success(commandResult(output: "Network service is disabled.\n"))])
        let helper = RecordingHelper()
        let controller = SystemNetworkController(commandRunner: runner, helper: helper)
        let changes = [NetworkChange(id: "network-service-wi-fi", displayName: "Wi-Fi", device: "en0", originalEnabled: true, kind: NetworkServiceKind.wifi.rawValue)]

        let results = await controller.isolate(changes)

        XCTAssertEqual(results.first?.outcome, .succeeded)
        XCTAssertEqual(helper.commands, [.setNetworkServiceEnabled(serviceID: "network-service-wi-fi", serviceName: "Wi-Fi", expectedDevice: "en0", enabled: false)])
        XCTAssertEqual(runner.calls.first?.request.arguments, ["-getnetworkserviceenabled", "Wi-Fi"])
    }

    func testSystemNetworkRestoreRequiresAppliedStateAndVerifiesEnabledState() async {
        let runner = RecordingCommandRunner(results: [
            .success(commandResult(output: "No\n")),
            .success(commandResult(output: "Yes\n"))
        ])
        let helper = RecordingHelper()
        let controller = SystemNetworkController(commandRunner: runner, helper: helper)
        let changes = [NetworkChange(id: "network-service-wi-fi", displayName: "Wi-Fi", device: "en0", originalEnabled: true, appliedEnabled: false, kind: NetworkServiceKind.wifi.rawValue)]

        let results = await controller.restore(changes)

        XCTAssertEqual(results.first?.outcome, .succeeded)
        XCTAssertEqual(helper.commands, [.setNetworkServiceEnabled(serviceID: "network-service-wi-fi", serviceName: "Wi-Fi", expectedDevice: "en0", enabled: true)])
        XCTAssertEqual(runner.calls.map { $0.request.arguments }, [
            ["-getnetworkserviceenabled", "Wi-Fi"],
            ["-getnetworkserviceenabled", "Wi-Fi"]
        ])
    }

    private func commandResult(output: String) -> CommandResult {
        CommandResult(terminationStatus: 0, standardOutput: Data(output.utf8), standardError: Data(), timedOut: false, startedAt: Date(), finishedAt: Date())
    }
}
