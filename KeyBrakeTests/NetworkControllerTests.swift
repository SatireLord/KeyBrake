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
        let appliedSnapshot = snapshot.map { change -> NetworkChange in
            var applied = change
            if isolation.contains(where: { $0.targetID == change.id && ($0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState) }) {
                applied.appliedEnabled = false
                applied.currentEnabled = false
            }
            return applied
        }
        let restoration = await controller.restore(appliedSnapshot)
        XCTAssertTrue(restoration.contains { $0.targetID == "vpn" && $0.operationDescription.contains("VPN remains unchanged") && $0.outcome == .skipped })
        let restoredVPN = await controller.inventory().first { $0.id == "vpn" }
        XCTAssertEqual(restoredVPN?.enabled, false)
    }

    func testNetworkSandboxConnectedFixtureModelsWiFiVPNAndLoopbackBoundary() async {
        let fixture = NetworkSandboxFixture.fixture(for: .connected)
        let controller = fixture.makeController()
        let services = await controller.inventory()

        XCTAssertEqual(fixture.scenario, .connected)
        XCTAssertFalse(fixture.failIsolation)
        XCTAssertEqual(services.map(\.displayName), ["Wi-Fi", "USB Ethernet", "Work VPN", "Loopback"])
        XCTAssertEqual(services.first(where: { $0.kind == .wifi })?.device, "en0")
        XCTAssertEqual(services.first(where: { $0.kind == .vpn })?.active, true)
        XCTAssertEqual(services.first(where: { $0.isLoopback })?.device, "lo0")
        let snapshot = await controller.captureSnapshot()
        XCTAssertEqual(snapshot.count, 3)
    }

    func testNetworkSandboxConnectedFixtureIsolatesAndRestoresExplicitly() async {
        let controller = NetworkSandboxFixture.connected.makeController()
        let snapshot = await controller.captureSnapshot()

        let isolation = await controller.isolate(snapshot)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-wi-fi" })?.outcome, .succeeded)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-usb-ethernet" })?.outcome, .alreadyInDesiredState)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-work-vpn" })?.outcome, .succeeded)

        let appliedChanges = snapshot.map { change -> NetworkChange in
            var updated = change
            let isolationResult = isolation.first { $0.subsystem == "network" && $0.targetID == change.id }
            if isolationResult?.outcome == .succeeded || isolationResult?.outcome == .alreadyInDesiredState {
                updated.appliedEnabled = false
                updated.currentEnabled = false
            }
            return updated
        }
        let restoration = await controller.restore(appliedChanges)
        XCTAssertEqual(restoration.first(where: { $0.targetID == "network-service-wi-fi" })?.outcome, .succeeded)
        XCTAssertEqual(restoration.first(where: { $0.targetID == "network-service-work-vpn" })?.outcome, .skipped)
        XCTAssertTrue(restoration.first(where: { $0.targetID == "network-service-work-vpn" })?.operationDescription.contains("VPN remains unchanged") == true)
        let restoredVPN = await controller.inventory().first { $0.id == "network-service-work-vpn" }
        XCTAssertEqual(restoredVPN?.enabled, false)
    }

    func testNetworkSandboxFailureFixtureReportsDeterministicWiFiAndVPNFailures() async {
        let fixture = NetworkSandboxFixture.fixture(for: .isolationFailure)
        let controller = fixture.makeController()
        let snapshot = await controller.captureSnapshot()

        let isolation = await controller.isolate(snapshot)
        XCTAssertTrue(fixture.failIsolation)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-wi-fi" })?.outcome, .failed)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-work-vpn" })?.outcome, .failed)
        XCTAssertEqual(isolation.first(where: { $0.targetID == "network-service-usb-ethernet" })?.outcome, .alreadyInDesiredState)
    }

    func testNetworkSandboxScenarioNamesConnectedAndFailureProfiles() {
        XCTAssertEqual(NetworkSandboxScenario.connected.displayTitle, "Connected fixture")
        XCTAssertEqual(NetworkSandboxScenario.isolationFailure.displayTitle, "Isolation failure fixture")
        XCTAssertTrue(NetworkSandboxScenario.connected.displayDetail.contains("enabled Wi-Fi"))
        XCTAssertTrue(NetworkSandboxScenario.isolationFailure.displayDetail.contains("isolation failures"))
    }

    func testNetworkSandboxPresentationUsesRecordedState() {
        let wifi = NetworkService(id: "wifi", displayName: "Wi-Fi", device: "en0", kind: .wifi, enabled: true, active: true)
        let vpn = NetworkService(id: "vpn", displayName: "Work VPN", kind: .vpn, enabled: true, active: true)

        XCTAssertEqual(NetworkSandboxFixture.displayedServiceState(for: wifi, currentEnabled: false), "disabled")
        XCTAssertEqual(NetworkSandboxFixture.displayedServiceState(for: vpn, currentEnabled: false), "disconnected")
        XCTAssertEqual(NetworkSandboxFixture.displayedServiceState(for: vpn, currentEnabled: true), "connected")
        XCTAssertEqual(NetworkSandboxFixture.displayedServiceState(for: wifi, currentEnabled: nil), "unverified")
    }

    func testSystemNetworkIsolationUsesHelperAndVerifiesDisabledState() async {
        let runner = RecordingCommandRunner(results: [
            .success(commandResult(output: "Yes\n")),
            .success(commandResult(output: "No\n"))
        ])
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
