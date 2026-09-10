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
        case .stopVerifiedLaunchdService(let domain, let label, let expectedProgramPath, let expectedSigningRequirement):
            return await stopVerifiedLaunchdService(
                domain: domain,
                label: label,
                expectedProgramPath: expectedProgramPath,
                expectedSigningRequirement: expectedSigningRequirement
            )
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

    private func stopVerifiedLaunchdService(
        domain: String,
        label: String,
        expectedProgramPath: String,
        expectedSigningRequirement: String?
    ) async -> OperationStepResult {
        let qualifiedLabel = "\(domain)/\(label)"
        let startedAt = Date()
        do {
            let before = try await runner.run(CommandRequest(
                executableURL: URL(fileURLWithPath: "/bin/launchctl"),
                arguments: ["print", qualifiedLabel],
                timeout: .seconds(5),
                outputLimitBytes: 16 * 1024
            ))
            guard before.terminationStatus == 0 else {
                return launchdResult(
                    targetID: label,
                    requestedState: "verified and stopped",
                    operationDescription: "launchd service could not be inspected before stopping",
                    outcome: .failed,
                    terminationStatus: before.terminationStatus,
                    sanitizedStandardError: before.sanitizedStandardError,
                    startedAt: startedAt,
                    finishedAt: before.finishedAt
                )
            }
            let beforeOutput = combinedOutput(before)
            guard declaresProgramPath(beforeOutput, expectedProgramPath: expectedProgramPath) else {
                return launchdResult(
                    targetID: label,
                    requestedState: "verified and stopped",
                    operationDescription: "launchd service path did not match the approved executable",
                    outcome: .conflict,
                    observedPreState: "identity mismatch",
                    observedPostState: "unchanged",
                    startedAt: startedAt,
                    finishedAt: before.finishedAt
                )
            }
            if let expectedSigningRequirement, !expectedSigningRequirement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let signing = try await runner.run(CommandRequest(
                    executableURL: URL(fileURLWithPath: "/usr/bin/codesign"),
                    arguments: ["-d", "-r-", "--", expectedProgramPath],
                    timeout: .seconds(5),
                    outputLimitBytes: 16 * 1024
                ))
                guard signing.terminationStatus == 0,
                      signingRequirement(from: combinedOutput(signing)) == normalizedSigningRequirement(expectedSigningRequirement) else {
                    return launchdResult(
                        targetID: label,
                        requestedState: "verified and stopped",
                        operationDescription: "launchd service signing requirement did not match the approved identity",
                        outcome: .conflict,
                        observedPreState: "identity mismatch",
                        observedPostState: "unchanged",
                        terminationStatus: signing.terminationStatus,
                        sanitizedStandardError: signing.sanitizedStandardError,
                        startedAt: startedAt,
                        finishedAt: signing.finishedAt
                    )
                }
            }
            guard launchdServiceIsRunning(beforeOutput) else {
                return launchdResult(
                    targetID: label,
                    requestedState: "stopped",
                    operationDescription: "Verified launchd service was already stopped",
                    outcome: .alreadyInDesiredState,
                    observedPreState: "stopped",
                    observedPostState: "stopped",
                    startedAt: startedAt,
                    finishedAt: before.finishedAt
                )
            }
            let kill = try await runner.run(CommandRequest(
                executableURL: URL(fileURLWithPath: "/bin/launchctl"),
                arguments: ["kill", "SIGTERM", qualifiedLabel],
                timeout: .seconds(5),
                outputLimitBytes: 16 * 1024
            ))
            guard kill.terminationStatus == 0 else {
                return launchdResult(
                    targetID: label,
                    requestedState: "stopped",
                    operationDescription: "Verified launchd service stop command failed",
                    outcome: .failed,
                    observedPreState: "running",
                    observedPostState: "running",
                    terminationStatus: kill.terminationStatus,
                    sanitizedStandardError: kill.sanitizedStandardError,
                    startedAt: startedAt,
                    finishedAt: kill.finishedAt
                )
            }
            let after = try await runner.run(CommandRequest(
                executableURL: URL(fileURLWithPath: "/bin/launchctl"),
                arguments: ["print", qualifiedLabel],
                timeout: .seconds(5),
                outputLimitBytes: 16 * 1024
            ))
            if after.terminationStatus == 0 && launchdServiceIsRunning(combinedOutput(after)) {
                return launchdResult(
                    targetID: label,
                    requestedState: "stopped",
                    operationDescription: "Verified launchd service respawned or remained running after stop",
                    outcome: .conflict,
                    observedPreState: "running",
                    observedPostState: "running",
                    terminationStatus: after.terminationStatus,
                    sanitizedStandardError: after.sanitizedStandardError,
                    startedAt: startedAt,
                    finishedAt: after.finishedAt
                )
            }
            return launchdResult(
                targetID: label,
                requestedState: "stopped",
                operationDescription: "Verified launchd service stopped without an observed respawn",
                outcome: .succeeded,
                observedPreState: "running",
                observedPostState: "stopped",
                terminationStatus: kill.terminationStatus,
                sanitizedStandardError: after.sanitizedStandardError,
                startedAt: startedAt,
                finishedAt: after.finishedAt
            )
        } catch {
            return launchdResult(
                targetID: label,
                requestedState: "stopped",
                operationDescription: "Verified launchd service stop failed before post-state proof",
                outcome: .failed,
                observedPreState: "unknown",
                observedPostState: "unknown",
                sanitizedStandardError: error.localizedDescription,
                startedAt: startedAt,
                finishedAt: Date()
            )
        }
    }

    private func launchdResult(
        targetID: String,
        requestedState: String,
        operationDescription: String,
        outcome: OperationOutcome,
        observedPreState: String? = nil,
        observedPostState: String? = nil,
        terminationStatus: Int32? = nil,
        sanitizedStandardError: String? = nil,
        startedAt: Date,
        finishedAt: Date
    ) -> OperationStepResult {
        OperationStepResult(
            subsystem: "helper",
            targetID: targetID,
            targetDisplayName: targetID,
            requestedState: requestedState,
            observedPreState: observedPreState,
            observedPostState: observedPostState,
            operationDescription: operationDescription,
            outcome: outcome,
            terminationStatus: terminationStatus,
            sanitizedStandardError: sanitizedStandardError,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    private func combinedOutput(_ result: CommandResult) -> String {
        [
            String(decoding: result.standardOutput, as: UTF8.self),
            String(decoding: result.standardError, as: UTF8.self)
        ].joined(separator: "\n")
    }

    private func declaresProgramPath(_ output: String, expectedProgramPath: String) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return ["path = ", "program = "].contains { line == $0 + expectedProgramPath }
        }
    }

    private func launchdServiceIsRunning(_ output: String) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "state = running" { return true }
            guard line.hasPrefix("pid = ") else { return false }
            return Int32(line.dropFirst("pid = ".count)) ?? 0 > 0
        }
    }

    private func signingRequirement(from output: String) -> String? {
        output.split(whereSeparator: { $0.isNewline }).compactMap { rawLine -> String? in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let range = line.range(of: "designated =>") else { return nil }
            return line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        }.first
    }

    private func normalizedSigningRequirement(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "designated =>") else { return trimmed }
        return trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
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
