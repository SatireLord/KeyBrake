import Foundation
import KeyBrakeCore

public struct HelperAuthorization: Sendable {
    public let expectedBundleIdentifier: String
    public let expectedTeamIdentifier: String?
    public init(expectedBundleIdentifier: String = "org.realitygood.KeyBrake", expectedTeamIdentifier: String? = nil) {
        self.expectedBundleIdentifier = expectedBundleIdentifier
        self.expectedTeamIdentifier = expectedTeamIdentifier
    }

    public func accepts(bundleIdentifier: String, teamIdentifier: String?, command: HelperCommand) -> Bool {
        guard bundleIdentifier == expectedBundleIdentifier else { return false }
        if let expectedTeamIdentifier, teamIdentifier != expectedTeamIdentifier { return false }
        return HelperCommandValidator(applicationBundleIdentifier: expectedBundleIdentifier).validate(command)
    }
}
