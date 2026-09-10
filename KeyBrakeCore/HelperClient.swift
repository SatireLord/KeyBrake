import Foundation
import Security

public struct HelperCallerIdentity: Sendable, Equatable {
    public let bundleIdentifier: String
    public let teamIdentifier: String?

    public init(bundleIdentifier: String, teamIdentifier: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
    }
}

public enum HelperAudit {
    public static func callerIdentity(auditToken: Data) -> HelperCallerIdentity? {
        guard !auditToken.isEmpty else { return nil }
        let attributes = [kSecGuestAttributeAudit: auditToken] as CFDictionary
        return callerIdentity(attributes: attributes)
    }

    public static func callerIdentity(processIdentifier: pid_t) -> HelperCallerIdentity? {
        guard processIdentifier > 0 else { return nil }
        let attributes = [kSecGuestAttributePid: NSNumber(value: processIdentifier)] as CFDictionary
        return callerIdentity(attributes: attributes)
    }

    private static func callerIdentity(attributes: CFDictionary) -> HelperCallerIdentity? {
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any],
              let bundleIdentifier = info[kSecCodeInfoIdentifier as String] as? String else { return nil }
        let teamIdentifier = info[kSecCodeInfoTeamIdentifier as String] as? String
        return HelperCallerIdentity(bundleIdentifier: bundleIdentifier, teamIdentifier: teamIdentifier)
    }
}

@objc(HelperXPCProtocol)
public protocol HelperXPCProtocol {
    func performCommand(_ payload: Data, withReply reply: @escaping @Sendable (Data?) -> Void)
}

public enum HelperXPCCodec {
    public static func encode(_ command: HelperCommand) throws -> Data {
        try JSONEncoder().encode(command)
    }

    public static func decodeCommand(_ data: Data) throws -> HelperCommand {
        try JSONDecoder().decode(HelperCommand.self, from: data)
    }

    public static func encode(_ result: OperationStepResult) throws -> Data {
        try JSONEncoder().encode(result)
    }

    public static func decodeResult(_ data: Data) throws -> OperationStepResult {
        try JSONDecoder().decode(OperationStepResult.self, from: data)
    }
}

public enum HelperCommand: Codable, Sendable, Equatable {
    case setNetworkServiceEnabled(serviceID: String, serviceName: String, expectedDevice: String?, enabled: Bool)
    case setWiFiPower(device: String, enabled: Bool)
    case setInterfaceUp(device: String, enabled: Bool)
    case stopVPN(serviceID: String, serviceName: String)
    case setRemoteLoginEnabled(Bool)
    case setRemoteAppleEventsEnabled(Bool)
    case stopVerifiedLaunchdService(domain: String, label: String, expectedProgramPath: String, expectedSigningRequirement: String?)
    case queryMutationStatus(operationID: UUID)
}

public struct HelperCommandValidator: Sendable {
    public let applicationBundleIdentifier: String
    public let allowedExecutables: Set<String>

    public init(applicationBundleIdentifier: String = "org.realitygood.KeyBrake", allowedExecutables: Set<String> = ["/usr/sbin/networksetup", "/usr/sbin/scutil", "/usr/sbin/systemsetup", "/bin/launchctl", "/sbin/ifconfig"]) {
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.allowedExecutables = allowedExecutables
    }

    public func validate(_ command: HelperCommand) -> Bool {
        switch command {
        case .setNetworkServiceEnabled(let serviceID, let serviceName, let expectedDevice, _):
            return validIdentifier(serviceID) && validName(serviceName) && (expectedDevice == nil || validName(expectedDevice!))
        case .setWiFiPower(let device, _), .setInterfaceUp(let device, _):
            return validDevice(device)
        case .stopVPN(let serviceID, let serviceName):
            return validIdentifier(serviceID) && validName(serviceName)
        case .setRemoteLoginEnabled, .setRemoteAppleEventsEnabled, .queryMutationStatus:
            return true
        case .stopVerifiedLaunchdService(let domain, let label, let expectedProgramPath, _):
            return (domain == "gui" || domain == "system") && validLaunchdLabel(label) && absolutePath(expectedProgramPath)
        }
    }

    private func validIdentifier(_ value: String) -> Bool { !value.isEmpty && value.count <= 200 && !value.contains(where: { $0.isWhitespace || $0 == ";" || $0 == "|" || $0 == "&" }) }
    private func validName(_ value: String) -> Bool { !value.isEmpty && value.count <= 200 && !value.contains(where: { $0 == "\n" || $0 == "\r" }) }
    private func validDevice(_ value: String) -> Bool { value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil }
    private func validLaunchdLabel(_ value: String) -> Bool { validIdentifier(value) && !value.hasPrefix("com.apple.") && !value.localizedCaseInsensitiveContains("keybrake") }
    private func absolutePath(_ value: String) -> Bool { value.hasPrefix("/") && !value.contains("..") && !value.contains(where: { $0 == ";" || $0 == "|" || $0 == "&" }) }
}

public enum HelperAvailability: String, Sendable, Codable {
    case ready
    case approvalRequired
    case unavailable
    case error
}

public protocol HelperOperating: Sendable {
    var availability: HelperAvailability { get }
    func perform(_ command: HelperCommand) async -> OperationStepResult
}

public struct UnavailableHelper: HelperOperating {
    public let availability: HelperAvailability = .unavailable
    public init() {}
    public func perform(_ command: HelperCommand) async -> OperationStepResult {
        OperationStepResult(subsystem: "helper", targetID: "privileged-helper", targetDisplayName: "Privileged Helper", requestedState: "perform", operationDescription: "Helper is unavailable; operation skipped", outcome: .unsupported)
    }
}

public enum HelperDaemonRegistration {
    public static let plistName = "org.realitygood.KeyBrake.Helper.plist"
    public static let machServiceName = "org.realitygood.KeyBrake.Helper"
}

public final class HelperXPCClient: HelperOperating, @unchecked Sendable {
    private static let requestTimeout: TimeInterval = 5
    private let availabilityLock = NSLock()
    private var currentAvailability: HelperAvailability
    private let connection: NSXPCConnection

    public var availability: HelperAvailability {
        availabilityLock.lock()
        defer { availabilityLock.unlock() }
        return currentAvailability
    }

    public init(machServiceName: String = HelperDaemonRegistration.machServiceName) {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        self.currentAvailability = .approvalRequired
        connection.resume()
        self.connection = connection
        connection.interruptionHandler = { [weak self] in self?.setAvailability(.approvalRequired) }
        connection.invalidationHandler = { [weak self] in self?.setAvailability(.unavailable) }
    }

    public func perform(_ command: HelperCommand) async -> OperationStepResult {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in }) as? HelperXPCProtocol else {
            setAvailability(.unavailable)
            return OperationStepResult(subsystem: "helper", targetID: "privileged-helper", targetDisplayName: "Privileged Helper", requestedState: "perform", operationDescription: "Helper XPC proxy unavailable", outcome: .failed)
        }
        return await performRemote(command, proxy: proxy)
    }

    private func performRemote(_ command: HelperCommand, proxy: HelperXPCProtocol) async -> OperationStepResult {
        await withCheckedContinuation { continuation in
            let gate = HelperReplyGate()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.requestTimeout) { [weak self, gate] in
                guard gate.claim() else { return }
                self?.setAvailability(.unavailable)
                continuation.resume(returning: OperationStepResult(
                    subsystem: "helper",
                    targetID: "privileged-helper",
                    targetDisplayName: "Privileged Helper",
                    requestedState: "perform",
                    operationDescription: "Helper XPC request timed out",
                    outcome: .failed
                ))
            }
            do {
                let payload = try HelperXPCCodec.encode(command)
                proxy.performCommand(payload) { [weak self, gate] data in
                    guard gate.claim() else { return }
                    guard let data, let result = try? HelperXPCCodec.decodeResult(data) else {
                        self?.setAvailability(.error)
                        continuation.resume(returning: OperationStepResult(subsystem: "helper", targetID: "privileged-helper", targetDisplayName: "Privileged Helper", requestedState: "perform", operationDescription: "Helper returned no decodable result", outcome: .failed))
                        return
                    }
                    self?.setAvailability(.ready)
                    continuation.resume(returning: result)
                }
            } catch {
                guard gate.claim() else { return }
                self.setAvailability(.error)
                continuation.resume(returning: OperationStepResult(subsystem: "helper", targetID: "privileged-helper", targetDisplayName: "Privileged Helper", requestedState: "perform", operationDescription: error.localizedDescription, outcome: .failed))
            }
        }
    }

    private func setAvailability(_ value: HelperAvailability) {
        availabilityLock.lock()
        currentAvailability = value
        availabilityLock.unlock()
    }
}

private final class HelperReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasReplied = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasReplied else { return false }
        hasReplied = true
        return true
    }
}

public final class RecordingHelper: HelperOperating, @unchecked Sendable {
    public let availability: HelperAvailability
    private let lock = NSLock()
    private var recordedCommands: [HelperCommand] = []

    public init(availability: HelperAvailability = .ready) {
        self.availability = availability
    }

    public var commands: [HelperCommand] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCommands
    }

    public func perform(_ command: HelperCommand) async -> OperationStepResult {
        appendRecorded(command)
        guard availability == .ready else {
            return OperationStepResult(subsystem: "helper", targetID: "privileged-helper", targetDisplayName: "Privileged Helper", requestedState: "perform", operationDescription: "Recording helper unavailable", outcome: .unsupported)
        }
        return OperationStepResult(subsystem: "helper", targetID: "recording-helper", targetDisplayName: "Privileged Helper", requestedState: "applied", operationDescription: "Recording helper accepted command", outcome: .succeeded)
    }

    private func appendRecorded(_ command: HelperCommand) {
        lock.lock()
        recordedCommands.append(command)
        lock.unlock()
    }
}
