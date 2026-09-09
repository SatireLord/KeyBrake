import AppKit
import Darwin
import Foundation

public struct ProcessIdentity: Codable, Sendable, Equatable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let executableURL: URL?
    public let effectiveUserIdentifier: UInt32

    public init(processIdentifier: Int32, bundleIdentifier: String?, executableURL: URL?, effectiveUserIdentifier: UInt32 = getuid()) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.executableURL = executableURL
        self.effectiveUserIdentifier = effectiveUserIdentifier
    }
}

public struct ProcessTargetResult: Sendable, Equatable {
    public let targetID: String
    public let displayName: String
    public let identity: ProcessIdentity?
    public let outcome: OperationOutcome
    public let detail: String

    public init(targetID: String, displayName: String, identity: ProcessIdentity?, outcome: OperationOutcome, detail: String) {
        self.targetID = targetID
        self.displayName = displayName
        self.identity = identity
        self.outcome = outcome
        self.detail = detail
    }
}

public protocol ProcessControlling: Sendable {
    func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity]
    func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult
}

public final class SystemProcessController: ProcessControlling, @unchecked Sendable {
    public init() {}

    public func matchingProcesses(for target: TargetDefinition) -> [ProcessIdentity] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard let bundleIdentifier = application.bundleIdentifier,
                  target.bundleIdentifier == bundleIdentifier || target.bundleIdentifier == nil else { return nil }
            guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: bundleIdentifier, executableURL: application.executableURL) else { return nil }
            return ProcessIdentity(processIdentifier: application.processIdentifier, bundleIdentifier: bundleIdentifier, executableURL: application.executableURL)
        }
    }

    public func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult {
        guard !TargetRegistry.protectedIdentifiers.contains(identity.bundleIdentifier ?? "") else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "protected", displayName: identity.bundleIdentifier ?? "Protected process", identity: identity, outcome: .conflict, detail: "Protected process rejected")
        }
        guard let application = NSRunningApplication(processIdentifier: identity.processIdentifier),
              application.bundleIdentifier == identity.bundleIdentifier,
              application.executableURL == identity.executableURL else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Unknown process", identity: identity, outcome: .conflict, detail: "Process identity changed before termination")
        }
        if !application.isTerminated {
            _ = application.terminate()
            for _ in 0..<20 where !application.isTerminated { try? await Task.sleep(for: .milliseconds(50)) }
        }
        if application.isTerminated {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .succeeded, detail: "Graceful termination verified")
        }
        guard allowForcedTermination else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .failed, detail: "Graceful termination failed and forced termination is not approved")
        }
        guard let current = NSRunningApplication(processIdentifier: identity.processIdentifier), current.bundleIdentifier == identity.bundleIdentifier, current.executableURL == identity.executableURL else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .conflict, detail: "PID identity changed before escalation")
        }
        _ = kill(identity.processIdentifier, SIGKILL)
        try? await Task.sleep(for: .milliseconds(100))
        let outcome: OperationOutcome = NSRunningApplication(processIdentifier: identity.processIdentifier) == nil ? .succeeded : .failed
        return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: outcome, detail: outcome == .succeeded ? "Forced termination verified" : "Process remains active")
    }
}
