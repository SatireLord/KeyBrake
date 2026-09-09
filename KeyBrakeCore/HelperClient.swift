import Foundation

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
