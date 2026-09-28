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
    public let enabledObservationKnown: Bool
    public let active: Bool
    public let isLoopback: Bool

    public init(id: String, displayName: String, device: String? = nil, kind: NetworkServiceKind, enabled: Bool, enabledObservationKnown: Bool = true, active: Bool, isLoopback: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.device = device
        self.kind = kind
        self.enabled = enabled
        self.enabledObservationKnown = enabledObservationKnown
        self.active = active
        self.isLoopback = isLoopback
    }

    private enum CodingKeys: String, CodingKey { case id, displayName, device, kind, enabled, enabledObservationKnown, active, isLoopback }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        device = try container.decodeIfPresent(String.self, forKey: .device)
        kind = try container.decode(NetworkServiceKind.self, forKey: .kind)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        enabledObservationKnown = try container.decodeIfPresent(Bool.self, forKey: .enabledObservationKnown) ?? false
        active = try container.decode(Bool.self, forKey: .active)
        isLoopback = try container.decodeIfPresent(Bool.self, forKey: .isLoopback) ?? (kind == .loopback)
    }
}

public struct ParsedNetworkService: Sendable, Equatable {
    public let displayName: String
    public let hardwarePort: String?
    public let device: String?

    public init(displayName: String, hardwarePort: String? = nil, device: String? = nil) {
        self.displayName = displayName
        self.hardwarePort = hardwarePort
        self.device = device
    }
}

public enum NetworkServiceParser {
    public static func serviceNames(from output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let folded = line.lowercased()
            guard !line.isEmpty,
                  !folded.hasPrefix("an asterisk"),
                  !folded.hasPrefix("networksetup:") else { return nil }
            let unmarked = line.first == "*" ? String(line.dropFirst()) : line
            let name = unmarked.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
    }

    public static func serviceOrder(from output: String) -> [ParsedNetworkService] {
        var parsed: [ParsedNetworkService] = []
        var currentName: String?
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = line.range(of: #"^\(\d+\)\s*(.+)$"#, options: .regularExpression) {
                currentName = String(line[match]).replacingOccurrences(of: #"^\(\d+\)\s*"#, with: "", options: .regularExpression)
                continue
            }
            guard let activeName = currentName, line.localizedCaseInsensitiveContains("Device:") else { continue }
            let hardwarePort = line
                .components(separatedBy: ",")
                .first(where: { $0.localizedCaseInsensitiveContains("Hardware Port:") })?
                .components(separatedBy: ":")
                .dropFirst()
                .joined(separator: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let device = line
                .components(separatedBy: "Device:")
                .dropFirst()
                .joined(separator: "Device:")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            parsed.append(ParsedNetworkService(displayName: activeName, hardwarePort: hardwarePort, device: device.isEmpty ? nil : device))
            currentName = nil
        }
        return parsed
    }

    public static func stableID(for displayName: String) -> String {
        let slug = displayName.lowercased().unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }.joined().replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "network-service-\(slug.isEmpty ? "unknown" : slug)"
    }

    public static func kind(displayName: String, hardwarePort: String? = nil, device: String? = nil) -> NetworkServiceKind {
        let text = [displayName, hardwarePort ?? "", device ?? ""].joined(separator: " ").lowercased()
        if text.contains("vpn") { return .vpn }
        if text.contains("loopback") || device == "lo0" { return .loopback }
        if text.contains("wi-fi") || text.contains("wifi") || text.contains("wlan") { return .wifi }
        if text.contains("thunderbolt") { return .thunderbolt }
        if text.contains("usb") && text.contains("ethernet") { return .usbEthernet }
        if text.contains("ethernet") { return .ethernet }
        if text.contains("bridge") { return .bridge }
        return .other
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
    private let helper: HelperOperating

    public init(commandRunner: CommandRunning, helper: HelperOperating = UnavailableHelper()) {
        self.commandRunner = commandRunner
        self.helper = helper
    }

    public func inventory() async -> [NetworkService] {
        let serviceNames = NetworkServiceParser.serviceNames(from: await command(arguments: ["-listallnetworkservices"], executable: "/usr/sbin/networksetup"))
        let order = NetworkServiceParser.serviceOrder(from: await command(arguments: ["-listnetworkserviceorder"], executable: "/usr/sbin/networksetup"))
        var services: [NetworkService] = []
        for name in serviceNames {
            let metadata = order.first { $0.displayName == name }
            let kind = NetworkServiceParser.kind(displayName: name, hardwarePort: metadata?.hardwarePort, device: metadata?.device)
            let observedEnabled: Bool?
            if kind == .vpn {
                observedEnabled = await vpnConnected(for: name)
            } else {
                observedEnabled = await enabledState(for: name)
            }
            let enabled = observedEnabled ?? false
            let details = await command(arguments: ["-getinfo", name], executable: "/usr/sbin/networksetup").lowercased()
            let active = kind == .vpn ? enabled : details.contains("ip address:") && !details.contains("<none>") && !details.contains("none")
            services.append(NetworkService(id: NetworkServiceParser.stableID(for: name), displayName: name, device: metadata?.device, kind: kind, enabled: enabled, enabledObservationKnown: observedEnabled != nil, active: active, isLoopback: kind == .loopback))
        }
        return services
    }

    public func captureSnapshot() async -> [NetworkChange] {
        (await inventory()).filter { !$0.isLoopback }.map { service in
            NetworkChange(id: service.id, displayName: service.displayName, device: service.device, originalEnabled: service.enabled, kind: service.kind.rawValue, isVPN: service.kind == .vpn, stateObservationKnown: service.enabledObservationKnown)
        }
    }

    public func isolate(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes where !change.isVPN {
            guard change.stateObservationKnown else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "Original network state was not observed; isolation skipped", outcome: .conflict))
                continue
            }
            guard change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Network service was disabled before isolation", outcome: .alreadyInDesiredState))
                continue
            }
            guard await enabledState(for: change.displayName) == change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "Network state changed or became unverified before isolation", outcome: .conflict))
                continue
            }
            let start = Date()
            let helperStep = await helper.perform(.setNetworkServiceEnabled(serviceID: change.id, serviceName: change.displayName, expectedDevice: change.device, enabled: false))
            let verifiedDisabled = await enabledState(for: change.displayName) == false
            let outcome: OperationOutcome = helperStep.outcome == .succeeded && verifiedDisabled ? .succeeded : (helperStep.outcome == .unsupported ? .unsupported : .failed)
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: "enabled", observedPostState: outcome == .succeeded ? "disabled" : "unknown", operationDescription: helperStep.operationDescription, outcome: outcome, terminationStatus: helperStep.terminationStatus, sanitizedStandardError: helperStep.sanitizedStandardError, startedAt: start, finishedAt: helperStep.finishedAt))
        }
        for change in changes where change.isVPN {
            guard change.stateObservationKnown else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disconnected", operationDescription: "Original VPN connection state was not observed; isolation skipped", outcome: .conflict))
                continue
            }
            guard change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", observedPreState: "disconnected", observedPostState: "disconnected", operationDescription: "VPN was disconnected before isolation", outcome: .alreadyInDesiredState))
                continue
            }
            guard await vpnConnected(for: change.displayName) == change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disconnected", operationDescription: "VPN state changed or became unverified before isolation", outcome: .conflict))
                continue
            }
            let start = Date()
            let helperStep = await helper.perform(.stopVPN(serviceID: change.id, serviceName: change.displayName))
            let verified = await vpnConnected(for: change.displayName) == false
            let outcome: OperationOutcome = helperStep.outcome == .succeeded && verified ? .succeeded : (helperStep.outcome == .unsupported ? .unsupported : .failed)
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disconnected", observedPreState: "connected", observedPostState: outcome == .succeeded ? "disconnected" : "unknown", operationDescription: helperStep.operationDescription, outcome: outcome, terminationStatus: helperStep.terminationStatus, sanitizedStandardError: helperStep.sanitizedStandardError, startedAt: start, finishedAt: helperStep.finishedAt))
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
            guard let appliedEnabled = change.appliedEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", operationDescription: "Recovery snapshot has no applied state; restore skipped", outcome: .conflict))
                continue
            }
            if await enabledState(for: change.displayName) != appliedEnabled {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", operationDescription: "Network service changed after KeyBrake applied isolation; restore skipped", outcome: .conflict))
                continue
            }
            let start = Date()
            let helperStep = await helper.perform(.setNetworkServiceEnabled(serviceID: change.id, serviceName: change.displayName, expectedDevice: change.device, enabled: true))
            let verifiedEnabled = await enabledState(for: change.displayName) == true
            let outcome: OperationOutcome = helperStep.outcome == .succeeded && verifiedEnabled ? .succeeded : (helperStep.outcome == .unsupported ? .unsupported : .failed)
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", observedPreState: "disabled", observedPostState: outcome == .succeeded ? "enabled" : "unknown", operationDescription: helperStep.operationDescription, outcome: outcome, terminationStatus: helperStep.terminationStatus, sanitizedStandardError: helperStep.sanitizedStandardError, startedAt: start, finishedAt: helperStep.finishedAt))
        }
        for change in changes where change.isVPN {
            guard let appliedEnabled = change.appliedEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", operationDescription: "Recovery snapshot has no applied VPN state; restore skipped", outcome: .conflict))
                continue
            }
            if await vpnConnected(for: change.displayName) != appliedEnabled {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", operationDescription: "VPN state changed after KeyBrake applied isolation; restore skipped", outcome: .conflict))
                continue
            }
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

    private func vpnConnected(for serviceName: String) async -> Bool? {
        let result = await run(arguments: ["--nc", "status", serviceName], executable: "/usr/sbin/scutil")
        guard result.terminationStatus == 0 else { return nil }
        let output = String(decoding: result.standardOutput, as: UTF8.self).lowercased()
        if output.contains("disconnected") || output.contains("invalid") { return false }
        if output.contains("connected") && !output.contains("disconnected") { return true }
        return nil
    }
}

// Greppable:
// canonical: keybrake-network-sandbox-fixture
// aliases: fixture Wi-Fi VPN; non-mutating network sandbox; simulated network state
// forms: --keybrake-network-sandbox; --keybrake-network-sandbox-failure
// descriptors: deterministic Wi-Fi and VPN observations; fixture isolation; explicit restore boundary
// states: connected; isolation-failure; isolated; restore-pending
// consumers: KeyBrakeLaunchConfiguration; NetworkControllerTests; Agent Display
// owner: NetworkSandboxFixture
// QoL-110: sandbox inventory rows use recorded post-operation state so simulated Wi-Fi and VPN outcomes remain truthful without changing host operations.
public enum NetworkSandboxScenario: String, Codable, CaseIterable, Sendable {
    case connected
    case isolationFailure

    public var displayTitle: String {
        switch self {
        case .connected:
            return "Connected fixture"
        case .isolationFailure:
            return "Isolation failure fixture"
        }
    }

    public var displayDetail: String {
        switch self {
        case .connected:
            return "Simulates enabled Wi-Fi and Work VPN, disabled USB Ethernet, and active loopback."
        case .isolationFailure:
            return "Simulates Wi-Fi and VPN isolation failures while leaving host network state untouched."
        }
    }
}

public struct NetworkSandboxFixture: Equatable, Sendable {
    public let scenario: NetworkSandboxScenario
    public let services: [NetworkService]
    public let failIsolation: Bool

    public init(scenario: NetworkSandboxScenario, services: [NetworkService], failIsolation: Bool) {
        self.scenario = scenario
        self.services = services
        self.failIsolation = failIsolation
    }

    public static let connected = NetworkSandboxFixture(
        scenario: .connected,
        services: [
            NetworkService(id: "network-service-wi-fi", displayName: "Wi-Fi", device: "en0", kind: .wifi, enabled: true, active: true),
            NetworkService(id: "network-service-usb-ethernet", displayName: "USB Ethernet", device: "en5", kind: .usbEthernet, enabled: false, active: false),
            NetworkService(id: "network-service-work-vpn", displayName: "Work VPN", kind: .vpn, enabled: true, active: true),
            NetworkService(id: "network-service-loopback", displayName: "Loopback", device: "lo0", kind: .loopback, enabled: true, active: true, isLoopback: true)
        ],
        failIsolation: false
    )

    public static let isolationFailure = NetworkSandboxFixture(
        scenario: .isolationFailure,
        services: connected.services,
        failIsolation: true
    )

    public static func fixture(for scenario: NetworkSandboxScenario) -> NetworkSandboxFixture {
        switch scenario {
        case .connected:
            return .connected
        case .isolationFailure:
            return .isolationFailure
        }
    }

    public static func displayedServiceState(for service: NetworkService, currentEnabled: Bool?) -> String {
        guard let currentEnabled else { return "unverified" }
        if service.kind == .vpn {
            return currentEnabled ? "connected" : "disconnected"
        }
        return currentEnabled ? "enabled" : "disabled"
    }

    public func makeController() -> FixtureNetworkController {
        FixtureNetworkController(services: services, failIsolation: failIsolation)
    }
}

public actor FixtureNetworkController: NetworkControlling {
    private var services: [NetworkService]
    public let failIsolation: Bool

    public init(services: [NetworkService] = [], failIsolation: Bool = false) {
        self.services = services
        self.failIsolation = failIsolation
    }

    public func inventory() async -> [NetworkService] { services }
    public func captureSnapshot() async -> [NetworkChange] {
        services.filter { !$0.isLoopback }.map {
            NetworkChange(
                id: $0.id,
                displayName: $0.displayName,
                device: $0.device,
                originalEnabled: $0.enabled,
                kind: $0.kind.rawValue,
                isVPN: $0.kind == .vpn,
                stateObservationKnown: $0.enabledObservationKnown
            )
        }
    }
    public func isolate(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes {
            guard let index = services.firstIndex(where: { $0.id == change.id }),
                  services.filter({ $0.id == change.id }).count == 1,
                  services[index].displayName == change.displayName,
                  services[index].device == change.device,
                  services[index].kind.rawValue == change.kind,
                  (services[index].kind == .vpn) == change.isVPN else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "Fixture identity changed before isolation", outcome: .conflict))
                continue
            }
            let current = services[index]
            guard change.stateObservationKnown, current.enabledObservationKnown else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "Fixture network state is unknown; isolation skipped", outcome: .conflict))
                continue
            }
            guard current.enabled == change.originalEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: current.enabled ? "enabled" : "disabled", observedPostState: current.enabled ? "enabled" : "disabled", operationDescription: "Fixture state changed before isolation", outcome: .conflict))
                continue
            }
            if !change.originalEnabled {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Fixture network isolation", outcome: .alreadyInDesiredState))
            } else if failIsolation {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: "enabled", observedPostState: "enabled", operationDescription: "Fixture network isolation failure", outcome: .failed))
            } else {
                services[index] = NetworkService(id: current.id, displayName: current.displayName, device: current.device, kind: current.kind, enabled: false, enabledObservationKnown: current.enabledObservationKnown, active: false, isLoopback: current.isLoopback)
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", observedPreState: "enabled", observedPostState: "disabled", operationDescription: "Fixture network isolation", outcome: .succeeded))
            }
        }
        return results
    }
    public func restore(_ changes: [NetworkChange]) async -> [OperationStepResult] {
        var results: [OperationStepResult] = []
        for change in changes {
            guard let index = services.firstIndex(where: { $0.id == change.id }),
                  services.filter({ $0.id == change.id }).count == 1,
                  services[index].displayName == change.displayName,
                  services[index].device == change.device,
                  services[index].kind.rawValue == change.kind,
                  (services[index].kind == .vpn) == change.isVPN else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore", operationDescription: "Fixture identity changed before restoration", outcome: .conflict))
                continue
            }
            let current = services[index]
            guard change.stateObservationKnown, current.enabledObservationKnown else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore", operationDescription: "Fixture network state is unknown; restoration skipped", outcome: .conflict))
                continue
            }
            if change.isVPN {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", observedPreState: current.enabled ? "connected" : "disconnected", observedPostState: current.enabled ? "connected" : "disconnected", operationDescription: "VPN remains unchanged until explicit user action", outcome: current.enabled ? .conflict : .skipped))
                continue
            }
            guard let appliedEnabled = change.appliedEnabled, current.enabled == appliedEnabled else {
                results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "enabled" : "disabled", observedPreState: current.enabled ? "enabled" : "disabled", observedPostState: current.enabled ? "enabled" : "disabled", operationDescription: "Fixture state changed after isolation; restoration skipped", outcome: .conflict))
                continue
            }
            if current.enabled != change.originalEnabled {
                services[index] = NetworkService(id: current.id, displayName: current.displayName, device: current.device, kind: current.kind, enabled: change.originalEnabled, enabledObservationKnown: current.enabledObservationKnown, active: change.originalEnabled, isLoopback: current.isLoopback)
            }
            results.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "enabled" : "disabled", observedPreState: current.enabled ? "enabled" : "disabled", observedPostState: change.originalEnabled ? "enabled" : "disabled", operationDescription: "Fixture network restoration", outcome: current.enabled == change.originalEnabled ? .alreadyInDesiredState : .succeeded))
        }
        return results
    }
}
