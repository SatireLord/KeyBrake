import XCTest
@testable import KeyBrakeCore

final class NetworkControllerTests: XCTestCase {
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
}
