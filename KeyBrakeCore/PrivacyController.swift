import Foundation

public enum PrivacyResetScope: String, Sendable, Equatable {
    case selectedServices
    case keyboardInput
}

public struct PrivacyResetRequest: Sendable, Equatable {
    public let bundleIdentifier: String
    public let services: Set<TCCService>
    public let scope: PrivacyResetScope

    public init(bundleIdentifier: String, services: Set<TCCService>) {
        self.init(bundleIdentifier: bundleIdentifier, services: services, scope: .selectedServices)
    }

    public static func keyboardInput(bundleIdentifier: String) -> PrivacyResetRequest {
        PrivacyResetRequest(
            bundleIdentifier: bundleIdentifier,
            services: [.inputMonitoring, .postEvent],
            scope: .keyboardInput
        )
    }

    private init(bundleIdentifier: String, services: Set<TCCService>, scope: PrivacyResetScope) {
        self.bundleIdentifier = bundleIdentifier
        self.services = services
        self.scope = scope
    }

    fileprivate var effectiveServices: Set<TCCService> {
        scope == .keyboardInput ? [.inputMonitoring, .postEvent] : services
    }
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
        guard Self.isValidBundleIdentifier(request.bundleIdentifier) else {
            return [Self.rejectedIdentityResult(request, targetDisplayName: targetDisplayName, detail: "Refused malformed bundle identifier")]
        }
        guard !Self.isProtectedBundleIdentifier(request.bundleIdentifier) else {
            return [Self.rejectedIdentityResult(request, targetDisplayName: targetDisplayName, detail: "Refused KeyBrake or system-protected bundle identifier")]
        }
        return await withTaskGroup(of: OperationStepResult.self, returning: [OperationStepResult].self) { group in
            for service in request.effectiveServices {
                group.addTask { await reset(service: service, bundleIdentifier: request.bundleIdentifier, targetDisplayName: targetDisplayName) }
            }
            var results: [OperationStepResult] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.targetID < $1.targetID }
        }
    }

    private static func rejectedIdentityResult(
        _ request: PrivacyResetRequest,
        targetDisplayName: String,
        detail: String
    ) -> OperationStepResult {
        OperationStepResult(
            subsystem: "privacy",
            targetID: request.bundleIdentifier,
            targetDisplayName: targetDisplayName,
            requestedState: "reset selected decisions",
            operationDescription: detail,
            outcome: .conflict
        )
    }

    private static func isValidBundleIdentifier(_ identifier: String) -> Bool {
        guard identifier == identifier.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2 else { return false }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        for component in components {
            guard let first = component.unicodeScalars.first,
                  let last = component.unicodeScalars.last,
                  allowed.contains(first), first != "-",
                  allowed.contains(last), last != "-",
                  component.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        }
        return true
    }

    private static func isProtectedBundleIdentifier(_ identifier: String) -> Bool {
        let normalized = identifier.lowercased()
        return TargetRegistry.protectedIdentifiers.contains { $0.lowercased() == normalized }
            || normalized == "com.apple"
            || normalized.hasPrefix("com.apple.")
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
            let succeeded = result.terminationStatus == 0 && !result.timedOut
            return OperationStepResult(
                subsystem: "privacy",
                targetID: service.rawValue,
                targetDisplayName: targetDisplayName,
                requestedState: "reset",
                operationDescription: result.timedOut ? "tccutil invocation timed out" : "Reset TCC-managed privacy decision for \(bundleIdentifier)",
                outcome: succeeded ? .succeeded : .failed,
                terminationStatus: result.terminationStatus,
                sanitizedStandardError: result.sanitizedStandardError,
                startedAt: start,
                finishedAt: result.finishedAt
            )
        } catch {
            return OperationStepResult(subsystem: "privacy", targetID: service.rawValue, targetDisplayName: targetDisplayName, requestedState: "reset", operationDescription: "tccutil invocation failed", outcome: .failed, sanitizedStandardError: error.localizedDescription, startedAt: start, finishedAt: Date())
        }
    }
}
