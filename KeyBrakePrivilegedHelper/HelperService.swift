import Foundation
import KeyBrakeCore

public final class HelperService: HelperOperating, @unchecked Sendable {
    public let availability: HelperAvailability = .ready
    private let authorization: HelperAuthorization
    private let runner: CommandRunning

    public init(authorization: HelperAuthorization = HelperAuthorization(), runner: CommandRunning = ProcessCommandRunner()) {
        self.authorization = authorization
        self.runner = runner
    }

    public func perform(_ command: HelperCommand) async -> OperationStepResult {
        guard authorization.accepts(bundleIdentifier: authorization.expectedBundleIdentifier, teamIdentifier: authorization.expectedTeamIdentifier, command: command) else {
            return OperationStepResult(subsystem: "helper", targetID: "authorization", targetDisplayName: "Privileged Helper", requestedState: "authorized", operationDescription: "Rejected command at the typed authorization boundary", outcome: .conflict)
        }
        switch command {
        case .setNetworkServiceEnabled(_, let serviceName, _, let enabled):
            return await run(arguments: ["-setnetworkserviceenabled", serviceName, enabled ? "on" : "off"], executable: "/usr/sbin/networksetup", targetID: serviceName, description: "Set network service enabled state")
        case .setWiFiPower(let device, let enabled):
            return await run(arguments: ["-setairportpower", device, enabled ? "on" : "off"], executable: "/usr/sbin/networksetup", targetID: device, description: "Set Wi-Fi power state")
        case .setInterfaceUp(let device, let enabled):
            return await run(arguments: [device, enabled ? "up" : "down"], executable: "/sbin/ifconfig", targetID: device, description: "Set interface flags")
        case .stopVPN(_, let serviceName):
            return await run(arguments: ["--nc", "stop", serviceName], executable: "/usr/sbin/scutil", targetID: serviceName, description: "Disconnect VPN")
        case .setRemoteLoginEnabled(let enabled):
            return await run(arguments: ["-setremotelogin", enabled ? "on" : "off"], executable: "/usr/sbin/systemsetup", targetID: "remote-login", description: "Set Remote Login")
        case .setRemoteAppleEventsEnabled(let enabled):
            return await run(arguments: ["-setremoteappleevents", enabled ? "on" : "off"], executable: "/usr/sbin/systemsetup", targetID: "remote-apple-events", description: "Set Remote Apple Events")
        case .stopVerifiedLaunchdService(let domain, let label, _, _):
            return await run(arguments: ["kill", "SIGTERM", "\(domain)/\(label)"], executable: "/bin/launchctl", targetID: label, description: "Stop verified launchd service")
        case .queryMutationStatus(let operationID):
            return OperationStepResult(subsystem: "helper", targetID: operationID.uuidString, targetDisplayName: "Privileged Helper", requestedState: "query", operationDescription: "No mutation queue is active", outcome: .alreadyInDesiredState)
        }
    }

    private func run(arguments: [String], executable: String, targetID: String, description: String) async -> OperationStepResult {
        do {
            let result = try await runner.run(CommandRequest(executableURL: URL(fileURLWithPath: executable), arguments: arguments))
            return OperationStepResult(subsystem: "helper", targetID: targetID, targetDisplayName: targetID, requestedState: "applied", operationDescription: description, outcome: result.terminationStatus == 0 ? .succeeded : .failed, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: result.startedAt, finishedAt: result.finishedAt)
        } catch {
            return OperationStepResult(subsystem: "helper", targetID: targetID, targetDisplayName: targetID, requestedState: "applied", operationDescription: description, outcome: .failed, sanitizedStandardError: error.localizedDescription)
        }
    }
}
