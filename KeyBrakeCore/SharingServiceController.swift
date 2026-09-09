import Foundation

public struct SharingServiceCapability: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let supported: Bool
    public let enabled: Bool

    public init(id: String, displayName: String, supported: Bool, enabled: Bool) {
        self.id = id
        self.displayName = displayName
        self.supported = supported
        self.enabled = enabled
    }
}

public protocol SharingServiceAdapter: Sendable {
    var identifier: String { get }
    var displayName: String { get }
    func detect() async -> SharingServiceCapability
    func disable(expectedState: SharingServiceState) async -> OperationStepResult
    func restore(originalState: SharingServiceState, appliedState: SharingServiceState) async -> OperationStepResult
}

public struct SharingServiceState: Sendable, Equatable, Codable {
    public let enabled: Bool
    public let supported: Bool
    public init(enabled: Bool, supported: Bool) { self.enabled = enabled; self.supported = supported }
}

public struct SystemSharingServiceAdapter: SharingServiceAdapter {
    public let identifier: String
    public let displayName: String
    private let commandRunner: CommandRunning
    private let arguments: [String]

    public init(identifier: String, displayName: String, commandRunner: CommandRunning, arguments: [String]) {
        self.identifier = identifier
        self.displayName = displayName
        self.commandRunner = commandRunner
        self.arguments = arguments
    }

    public func detect() async -> SharingServiceCapability {
        guard let result = try? await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/sbin/systemsetup"), arguments: arguments)) else {
            return SharingServiceCapability(id: identifier, displayName: displayName, supported: false, enabled: false)
        }
        let text = String(decoding: result.standardOutput, as: UTF8.self).lowercased()
        return SharingServiceCapability(id: identifier, displayName: displayName, supported: result.terminationStatus == 0, enabled: text.contains("on") || text.contains("enabled"))
    }

    public func disable(expectedState: SharingServiceState) async -> OperationStepResult {
        guard expectedState.supported else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Capability unsupported on this macOS version", outcome: .unsupported) }
        let start = Date()
        let result = try? await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/sbin/systemsetup"), arguments: arguments + ["off"]))
        let status = result?.terminationStatus ?? 1
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", observedPreState: expectedState.enabled ? "enabled" : "disabled", observedPostState: status == 0 ? "disabled" : "unknown", operationDescription: "Disable supported sharing service", outcome: status == 0 ? .succeeded : .failed, terminationStatus: status, sanitizedStandardError: result?.sanitizedStandardError, startedAt: start, finishedAt: result?.finishedAt ?? Date())
    }

    public func restore(originalState: SharingServiceState, appliedState: SharingServiceState) async -> OperationStepResult {
        guard originalState.supported && appliedState.supported else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "restore", operationDescription: "Capability unsupported", outcome: .unsupported) }
        guard originalState.enabled else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "remain disabled", operationDescription: "Sharing service was disabled before isolation", outcome: .alreadyInDesiredState) }
        let result = try? await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/sbin/systemsetup"), arguments: arguments + ["on"]))
        let status = result?.terminationStatus ?? 1
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", operationDescription: "Explicitly restore previously enabled sharing service", outcome: status == 0 ? .succeeded : .failed, terminationStatus: status, sanitizedStandardError: result?.sanitizedStandardError)
    }
}

public struct SharingServiceController: Sendable {
    public let adapters: [any SharingServiceAdapter]
    public init(adapters: [any SharingServiceAdapter]) { self.adapters = adapters }

    public func captureChanges() async -> [SharingChange] {
        await withTaskGroup(of: SharingChange?.self, returning: [SharingChange].self) { group in
            for adapter in adapters {
                group.addTask {
                    let capability = await adapter.detect()
                    return SharingChange(id: capability.id, displayName: capability.displayName, originalEnabled: capability.enabled, supported: capability.supported)
                }
            }
            var changes: [SharingChange] = []
            for await change in group { if let change { changes.append(change) } }
            return changes.sorted { $0.id < $1.id }
        }
    }

    public func restore(_ changes: [SharingChange], selectedIDs: Set<String>) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes where selectedIDs.contains(change.id) {
            guard let adapter = adapters.first(where: { $0.identifier == change.id }) else {
                results.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore", operationDescription: "No adapter is available for this service", outcome: .unsupported))
                continue
            }
            results.append(await adapter.restore(originalState: SharingServiceState(enabled: change.originalEnabled, supported: change.supported), appliedState: SharingServiceState(enabled: change.appliedEnabled == false, supported: change.supported)))
        }
        return results
    }
}
