import AppKit
import Darwin
import Foundation

public struct ProcessIdentity: Codable, Sendable, Equatable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let executableURL: URL?
    public let effectiveUserIdentifier: UInt32
    public let launchDate: Date?

    public init(processIdentifier: Int32, bundleIdentifier: String?, executableURL: URL?, effectiveUserIdentifier: UInt32 = getuid(), launchDate: Date? = nil) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.executableURL = executableURL
        self.effectiveUserIdentifier = effectiveUserIdentifier
        self.launchDate = launchDate
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
                  let expectedBundleIdentifier = target.bundleIdentifier,
                  expectedBundleIdentifier == bundleIdentifier else { return nil }
            if let expectedExecutable = target.executableURL, expectedExecutable != application.executableURL {
                return nil
            }
            guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: bundleIdentifier, executableURL: application.executableURL) else { return nil }
            return ProcessIdentity(processIdentifier: application.processIdentifier, bundleIdentifier: bundleIdentifier, executableURL: application.executableURL, launchDate: application.launchDate)
        }
    }

    public func stop(_ identity: ProcessIdentity, allowForcedTermination: Bool) async -> ProcessTargetResult {
        guard !TargetRegistry.protectedIdentifiers.contains(identity.bundleIdentifier ?? "") else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "protected", displayName: identity.bundleIdentifier ?? "Protected process", identity: identity, outcome: .conflict, detail: "Protected process rejected")
        }
        guard let application = NSRunningApplication(processIdentifier: identity.processIdentifier), sameIdentity(application, identity: identity) else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Unknown process", identity: identity, outcome: .conflict, detail: "Process identity changed before termination")
        }
        if !application.isTerminated {
            _ = application.terminate()
            for _ in 0..<40 where !application.isTerminated { try? await Task.sleep(for: .milliseconds(50)) }
        }
        if application.isTerminated {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .succeeded, detail: "Graceful termination verified")
        }
        guard allowForcedTermination else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .failed, detail: "Graceful termination failed and forced termination is not approved")
        }
        guard let current = NSRunningApplication(processIdentifier: identity.processIdentifier), sameIdentity(current, identity: identity) else {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: .conflict, detail: "PID identity changed before escalation")
        }
        _ = kill(identity.processIdentifier, SIGKILL)
        for _ in 0..<20 where NSRunningApplication(processIdentifier: identity.processIdentifier) != nil {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let outcome: OperationOutcome = NSRunningApplication(processIdentifier: identity.processIdentifier) == nil ? .succeeded : .failed
        if outcome == .succeeded, let replacement = respawnedProcess(for: identity) {
            return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: replacement, outcome: .conflict, detail: "Target respawned as PID \(replacement.processIdentifier)")
        }
        return ProcessTargetResult(targetID: identity.bundleIdentifier ?? "unknown", displayName: identity.bundleIdentifier ?? "Process", identity: identity, outcome: outcome, detail: outcome == .succeeded ? "Forced termination verified" : "Process remains active")
    }

    private func sameIdentity(_ application: NSRunningApplication, identity: ProcessIdentity) -> Bool {
        guard application.bundleIdentifier == identity.bundleIdentifier,
              application.executableURL == identity.executableURL else { return false }
        guard let expectedLaunchDate = identity.launchDate else { return true }
        return application.launchDate == expectedLaunchDate
    }

    private func respawnedProcess(for identity: ProcessIdentity) -> ProcessIdentity? {
        for application in NSWorkspace.shared.runningApplications {
            guard application.processIdentifier != identity.processIdentifier,
                  application.bundleIdentifier == identity.bundleIdentifier,
                  application.executableURL == identity.executableURL else { continue }
            return ProcessIdentity(processIdentifier: application.processIdentifier, bundleIdentifier: application.bundleIdentifier, executableURL: application.executableURL, launchDate: application.launchDate)
        }
        return nil
    }
}
