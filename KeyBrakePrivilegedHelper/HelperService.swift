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

    public func perform(_ command: HelperCommand, caller: HelperCallerIdentity) async -> OperationStepResult {
        guard authorization.accepts(caller: caller, command: command) else {
            return OperationStepResult(subsystem: "helper", targetID: "authorization", targetDisplayName: "Privileged Helper", requestedState: "authorized", operationDescription: "Rejected command for caller \(caller.bundleIdentifier)", outcome: .conflict)
        }
        return await execute(command)
    }

    public func perform(_ command: HelperCommand) async -> OperationStepResult {
        await execute(command)
    }

    private func execute(_ command: HelperCommand) async -> OperationStepResult {
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

final class HelperXPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard let caller = HelperAudit.callerIdentity(processIdentifier: newConnection.processIdentifier) else { return false }
        let handler = HelperXPCConnectionHandler(service: service, caller: caller)
        newConnection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        newConnection.exportedObject = handler
        newConnection.resume()
        return true
    }
}

final class HelperXPCConnectionHandler: NSObject, HelperXPCProtocol, @unchecked Sendable {
    private let service: HelperService
    private let caller: HelperCallerIdentity

    init(service: HelperService, caller: HelperCallerIdentity) {
        self.service = service
        self.caller = caller
    }

    func performCommand(_ payload: Data, withReply reply: @escaping (Data?) -> Void) {
        let replyBox = HelperReplyBox(reply)
        Task {
            do {
                let command = try HelperXPCCodec.decodeCommand(payload)
                let result = await service.perform(command, caller: caller)
                replyBox.send(try HelperXPCCodec.encode(result))
            } catch {
                replyBox.send(nil)
            }
        }
    }
}

private final class HelperReplyBox: @unchecked Sendable {
    private let reply: (Data?) -> Void

    init(_ reply: @escaping (Data?) -> Void) {
        self.reply = reply
    }

    func send(_ data: Data?) {
        reply(data)
    }
}

enum HelperBootstrap {
    static func runListener() {
        let delegate = HelperXPCListenerDelegate()
        let listener = NSXPCListener(machServiceName: HelperDaemonRegistration.machServiceName)
        listener.delegate = delegate
        listener.resume()
        RunLoop.main.run()
    }
}
