import Foundation

public struct PrivacyResetRequest: Sendable, Equatable {
    public let bundleIdentifier: String
    public let services: Set<TCCService>
    public init(bundleIdentifier: String, services: Set<TCCService>) { self.bundleIdentifier = bundleIdentifier; self.services = services }
}

public struct PrivacyController: Sendable {
    private let commandRunner: CommandRunning
    private let operatingSystemMajorVersion: Int

    public init(
        commandRunner: CommandRunning,
        operatingSystemMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) {
        self.commandRunner = commandRunner
        self.operatingSystemMajorVersion = operatingSystemMajorVersion
    }

    public func reset(_ request: PrivacyResetRequest, targetDisplayName: String) async -> [OperationStepResult] {
        guard !request.bundleIdentifier.isEmpty, !request.bundleIdentifier.contains(" "), request.bundleIdentifier != "org.realitygood.KeyBrake" else {
            return [OperationStepResult(subsystem: "privacy", targetID: request.bundleIdentifier, targetDisplayName: targetDisplayName, requestedState: "reset selected decisions", operationDescription: "Refused invalid or self-targeted bundle identifier", outcome: .conflict)]
        }
        return await withTaskGroup(of: OperationStepResult.self, returning: [OperationStepResult].self) { group in
            for service in request.services {
                group.addTask { await reset(service: service, bundleIdentifier: request.bundleIdentifier, targetDisplayName: targetDisplayName) }
            }
            var results: [OperationStepResult] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.targetID < $1.targetID }
        }
    }

    private func reset(service: TCCService, bundleIdentifier: String, targetDisplayName: String) async -> OperationStepResult {
        let start = Date()
        guard let descriptor = PrivacyServiceCatalog.descriptors.first(where: { $0.id == service }) else {
            return OperationStepResult(
                subsystem: "privacy",
                targetID: service.rawValue,
                targetDisplayName: targetDisplayName,
                requestedState: "reset",
                operationDescription: "Privacy service is outside KeyBrake's supported allowlist",
                outcome: .unsupported,
                startedAt: start,
                finishedAt: Date()
            )
        }
        guard operatingSystemMajorVersion >= descriptor.minimumMajorVersion else {
            return OperationStepResult(
                subsystem: "privacy",
                targetID: service.rawValue,
                targetDisplayName: targetDisplayName,
                requestedState: "reset",
                operationDescription: "Privacy service requires macOS \(descriptor.minimumMajorVersion) or newer",
                outcome: .unsupported,
                startedAt: start,
                finishedAt: Date()
            )
        }
        do {
            let result = try await commandRunner.run(CommandRequest(executableURL: URL(fileURLWithPath: "/usr/bin/tccutil"), arguments: ["reset", service.rawValue, bundleIdentifier]))
            return OperationStepResult(subsystem: "privacy", targetID: service.rawValue, targetDisplayName: targetDisplayName, requestedState: "reset", operationDescription: "Reset TCC-managed privacy decision for \(bundleIdentifier)", outcome: result.terminationStatus == 0 ? .succeeded : .failed, terminationStatus: result.terminationStatus, sanitizedStandardError: result.sanitizedStandardError, startedAt: start, finishedAt: result.finishedAt)
        } catch {
            return OperationStepResult(subsystem: "privacy", targetID: service.rawValue, targetDisplayName: targetDisplayName, requestedState: "reset", operationDescription: "tccutil invocation failed", outcome: .failed, sanitizedStandardError: error.localizedDescription, startedAt: start, finishedAt: Date())
        }
    }
}
