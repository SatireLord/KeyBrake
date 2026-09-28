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
    private let helper: HelperOperating
    private let getterArguments: [String]
    private let enableArguments: [String]
    private let disableArguments: [String]

    public init(identifier: String, displayName: String, commandRunner: CommandRunning, helper: HelperOperating = UnavailableHelper(), getterArguments: [String], enableArguments: [String], disableArguments: [String]) {
        self.identifier = identifier
        self.displayName = displayName
        self.commandRunner = commandRunner
        self.helper = helper
        self.getterArguments = getterArguments
        self.enableArguments = enableArguments
        self.disableArguments = disableArguments
    }

    private func helperCommand(enabled: Bool) -> HelperCommand? {
        switch identifier {
        case "remote-login": return .setRemoteLoginEnabled(enabled)
        case "remote-apple-events": return .setRemoteAppleEventsEnabled(enabled)
        default: return nil
        }
    }

    public func detect() async -> SharingServiceCapability {
        guard let result = try? await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/sbin/systemsetup"), arguments: getterArguments)) else {
            return SharingServiceCapability(id: identifier, displayName: displayName, supported: false, enabled: false)
        }
        let text = String(decoding: result.standardOutput, as: UTF8.self)
        let state = Self.parseEnabledState(text)
        return SharingServiceCapability(id: identifier, displayName: displayName, supported: result.terminationStatus == 0 && !result.timedOut && state != nil, enabled: state ?? false)
    }

    static func parseEnabledState(_ output: String) -> Bool? {
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !line.isEmpty else { continue }
            let state = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? line
            if state == "on" || state == "enabled" { return true }
            if state == "off" || state == "disabled" { return false }
        }
        return nil
    }

    public func disable(expectedState: SharingServiceState) async -> OperationStepResult {
        guard expectedState.supported else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Capability unsupported on this macOS version", outcome: .unsupported) }
        let current = await detect()
        guard current.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "Sharing capability became unavailable before isolation", outcome: .unsupported)
        }
        guard current.enabled == expectedState.enabled else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", observedPreState: current.enabled ? "enabled" : "disabled", observedPostState: current.enabled ? "enabled" : "disabled", operationDescription: "Sharing state changed before isolation; no mutation was issued", outcome: .conflict)
        }
        let start = Date()
        guard let command = helperCommand(enabled: false) else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", operationDescription: "No helper command mapping for sharing service", outcome: .unsupported, startedAt: start, finishedAt: Date())
        }
        let helperStep = await helper.perform(command)
        let verified = helperStep.outcome == .succeeded ? await detect() : nil
        let outcome: OperationOutcome = helperStep.outcome == .succeeded && verified?.supported == true && verified?.enabled == false ? .succeeded : (helperStep.outcome == .unsupported ? .unsupported : .failed)
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "disabled", observedPreState: expectedState.enabled ? "enabled" : "disabled", observedPostState: outcome == .succeeded ? "disabled" : "unknown", operationDescription: helperStep.operationDescription, outcome: outcome, terminationStatus: helperStep.terminationStatus, sanitizedStandardError: helperStep.sanitizedStandardError, startedAt: start, finishedAt: helperStep.finishedAt)
    }

    public func restore(originalState: SharingServiceState, appliedState: SharingServiceState) async -> OperationStepResult {
        guard originalState.supported && appliedState.supported else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "restore", operationDescription: "Capability unsupported", outcome: .unsupported) }
        guard originalState.enabled else { return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "remain disabled", operationDescription: "Sharing service was disabled before isolation", outcome: .alreadyInDesiredState) }
        let current = await detect()
        guard current.supported else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", operationDescription: "Sharing capability became unavailable before restoration", outcome: .unsupported)
        }
        if current.enabled != appliedState.enabled {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", observedPreState: current.enabled ? "enabled" : "disabled", observedPostState: current.enabled ? "enabled" : "disabled", operationDescription: "Sharing service changed after KeyBrake applied isolation; restore skipped", outcome: .conflict)
        }
        guard let command = helperCommand(enabled: true) else {
            return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", operationDescription: "No helper command mapping for sharing service", outcome: .unsupported)
        }
        let helperStep = await helper.perform(command)
        let verified = helperStep.outcome == .succeeded ? await detect() : nil
        let outcome: OperationOutcome = helperStep.outcome == .succeeded && verified?.supported == true && verified?.enabled == true ? .succeeded : (helperStep.outcome == .unsupported ? .unsupported : .failed)
        return OperationStepResult(subsystem: "sharing", targetID: identifier, targetDisplayName: displayName, requestedState: "enabled", operationDescription: helperStep.operationDescription, outcome: outcome, terminationStatus: helperStep.terminationStatus, sanitizedStandardError: helperStep.sanitizedStandardError)
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
            guard let appliedEnabled = change.appliedEnabled else {
                results.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore", operationDescription: "Recovery snapshot has no applied state; restore skipped", outcome: .conflict))
                continue
            }
            results.append(await adapter.restore(originalState: SharingServiceState(enabled: change.originalEnabled, supported: change.supported), appliedState: SharingServiceState(enabled: appliedEnabled, supported: change.supported)))
        }
        return results
    }
}
