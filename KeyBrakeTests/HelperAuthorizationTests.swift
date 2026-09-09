import XCTest
@testable import KeyBrakeCore

final class HelperAuthorizationTests: XCTestCase {
    func testTypedHelperValidatorRejectsProtectedLaunchdAndRelativePaths() {
        let validator = HelperCommandValidator()
        XCTAssertFalse(validator.validate(.stopVerifiedLaunchdService(domain: "system", label: "com.apple.sshd", expectedProgramPath: "/usr/libexec/sshd", expectedSigningRequirement: nil)))
        XCTAssertFalse(validator.validate(.stopVerifiedLaunchdService(domain: "system", label: "com.example.agent", expectedProgramPath: "usr/local/bin/agent", expectedSigningRequirement: nil)))
        XCTAssertTrue(validator.validate(.setNetworkServiceEnabled(serviceID: "service-1", serviceName: "USB Ethernet", expectedDevice: "en7", enabled: false)))
    }
}
