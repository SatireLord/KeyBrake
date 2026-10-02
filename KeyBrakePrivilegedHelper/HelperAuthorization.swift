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

    public func accepts(auditToken: Data, command: HelperCommand) -> Bool {
        guard let caller = HelperAudit.callerIdentity(auditToken: auditToken) else { return false }
        return accepts(bundleIdentifier: caller.bundleIdentifier, teamIdentifier: caller.teamIdentifier, command: command)
    }

    public func accepts(caller: HelperCallerIdentity, command: HelperCommand) -> Bool {
        accepts(bundleIdentifier: caller.bundleIdentifier, teamIdentifier: caller.teamIdentifier, command: command)
    }
}
