import Foundation

public enum NetworkServiceKind: String, Codable, Sendable {
    case wifi
    case ethernet
    case usbEthernet
    case thunderbolt
    case vpn
    case bridge
    case other
    case loopback
}

public struct NetworkService: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let device: String?
    public let kind: NetworkServiceKind
    public let enabled: Bool
    public let active: Bool
    public let isLoopback: Bool

    public init(id: String, displayName: String, device: String? = nil, kind: NetworkServiceKind, enabled: Bool, active: Bool, isLoopback: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.device = device
        self.kind = kind
        self.enabled = enabled
        self.active = active
        self.isLoopback = isLoopback
    }
}

public protocol NetworkControlling: Sendable {
    func inventory() async -> [NetworkService]
    func captureSnapshot() async -> [NetworkChange]
    func isolate(_ changes: [NetworkChange]) async -> [OperationStepResult]
    func restore(_ changes: [NetworkChange]) async -> [OperationStepResult]
}

public final class SystemNetworkController: NetworkControlling, @unchecked Sendable {
    private let commandRunner: CommandRunning

    public init(commandRunner: CommandRunning) { self.commandRunner = commandRunner }

    public func inventory() async -> [NetworkService] {
        let serviceNames = await command(arguments: ["-listallnetworkservices"], executable: "/usr/sbin/networksetup")
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.hasPrefix("An asterisk") && !$0.isEmpty }
        var services: [NetworkService] = []
        for (index, name) in serviceNames.enumerated() {
            let kind: NetworkServiceKind = name.localizedCaseInsensitiveContains("wi-fi") || name.localizedCaseInsensitiveContains("wifi") ? .wifi : name.localizedCaseInsensitiveContains("ethernet") ? .ethernet : name.localizedCaseInsensitiveContains("vpn") ? .vpn : .other
            let enabled = await enabledState(for: name) ?? false
            let details = await command(arguments: ["-getinfo", name], executable: "/usr/sbin/networksetup").lowercased()
            let active = details.contains("ip address:") && !details.contains("<none>") && !details.contains("none")
            services.append(NetworkService(id: "service-\(index)-\(name)", displayName: name, kind: kind, enabled: enabled, active: active, isLoopback: false))
        }
        return services
    }

    public func captureSnapshot() async -> [NetworkChange] {
        await inventory().filter { !$0.isLoopback }.map { service in
            NetworkChange(id: service.id, displayName: service.displayName, device: service.device, originalEnabled: service.enabled, kind: service.kind.rawValue, isVPN: service.kind == .vpn)
        }
    }

    public func isolate(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes where change.originalEnabled && !change.isVPN {
            let start = Date()
            let result = await run(arguments: ["-setnetworkserviceenabled", change.displayName, "off"], executable: "/usr/sbin/networksetup")
            let verifiedDisabled = await enabledState(for: change.displayName) == false
            let outcome: OperationOutcome = result.terminationStatus == 0 && verifiedDisabled ? .succeeded : .failed
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: "enabled", observedPostState: outcome == .succeeded ? "disabled" : "unknown", operationDescription: "Disable network service", outcome: outcome, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: start, finishedAt: result.finishedAt))
        }
        for change in changes where change.originalEnabled && change.isVPN {
            let start = Date()
            let result = await run(arguments: ["--nc", "stop", change.displayName], executable: "/usr/sbin/scutil")
            let status = await command(arguments: ["--nc", "status", change.displayName], executable: "/usr/sbin/scutil").lowercased()
            let outcome: OperationOutcome = result.terminationStatus == 0 && (status.contains("disconnected") || status.contains("invalid") || status.isEmpty) ? .succeeded : .failed
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disconnected", observedPreState: "connected", observedPostState: outcome == .succeeded ? "disconnected" : "unknown", operationDescription: "Disconnect VPN", outcome: outcome, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: start, finishedAt: result.finishedAt))
        }
        return results
    }

    public func restore(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes where !change.isVPN {
            guard change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Preserve disabled pre-state", outcome: .alreadyInDesiredState))
                continue
            }
            let start = Date()
            let result = await run(arguments: ["-setnetworkserviceenabled", change.displayName, "on"], executable: "/usr/sbin/networksetup")
            let verifiedEnabled = await enabledState(for: change.displayName) == true
            let outcome: OperationOutcome = result.terminationStatus == 0 && verifiedEnabled ? .succeeded : .failed
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", observedPreState: "disabled", observedPostState: outcome == .succeeded ? "enabled" : "unknown", operationDescription: "Restore network service", outcome: outcome, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: start, finishedAt: result.finishedAt))
        }
        for change in changes where change.isVPN {
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", observedPreState: "connected", observedPostState: "disconnected", operationDescription: "VPN remains disconnected until explicit user action", outcome: .skipped))
        }
        return results
    }

    private func run(arguments: [String], executable: String) async -> CommandResult {
        do {
            return try await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: executable), arguments: arguments))
        } catch {
            return CommandResult(terminationStatus: 1, standardOutput: Data(), standardError: Data(error.localizedDescription.utf8), timedOut: false, startedAt: Date(), finishedAt: Date())
        }
    }

    private func command(arguments: [String], executable: String) async -> String {
        let result = await run(arguments: arguments, executable: executable)
        return String(decoding: result.standardOutput, as: UTF8.self)
    }

    private func enabledState(for serviceName: String) async -> Bool? {
        let result = await run(arguments: ["-getnetworkserviceenabled", serviceName], executable: "/usr/sbin/networksetup")
        guard result.terminationStatus == 0 else { return nil }
        let output = String(decoding: result.standardOutput, as: UTF8.self).lowercased()
        if output.contains("yes") || output.contains("enabled") { return true }
        if output.contains("no") || output.contains("disabled") { return false }
        return nil
    }
}

public struct FixtureNetworkController: NetworkControlling, Sendable {
    public var services: [NetworkService]
    public var failIsolation: Bool

    public init(services: [NetworkService] = [], failIsolation: Bool = false) {
        self.services = services
        self.failIsolation = failIsolation
    }

    public func inventory() async -> [NetworkService] { services }
    public func captureSnapshot() async -> [NetworkChange] {
        services.filter { !$0.isLoopback }.map { NetworkChange(id: $0.id, displayName: $0.displayName, device: $0.device, originalEnabled: $0.enabled, kind: $0.kind.rawValue, isVPN: $0.kind == .vpn) }
    }
    public func isolate(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        changes.map { change in
            OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: change.originalEnabled ? "enabled" : "disabled", observedPostState: failIsolation ? "enabled" : "disabled", operationDescription: "Fixture network isolation", outcome: change.originalEnabled ? (failIsolation ? .failed : .succeeded) : .alreadyInDesiredState)
        }
    }
    public func restore(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        changes.map { change in
            if change.isVPN {
                return OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", observedPreState: "connected", observedPostState: "disconnected", operationDescription: "VPN remains disconnected until explicit user action", outcome: .skipped)
            }
            return OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "enabled" : "disabled", observedPreState: "disabled", observedPostState: change.originalEnabled ? "enabled" : "disabled", operationDescription: "Fixture network restoration", outcome: .succeeded)
        }
    }
}
