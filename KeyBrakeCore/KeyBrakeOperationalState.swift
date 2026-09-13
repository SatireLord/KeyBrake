import Foundation

public enum KeyBrakeOperationalState: String, Codable, Sendable, CaseIterable {
    case normal
    case stoppingLocalAutomation
    case localAutomationStopped
    case isolating
    case isolated
    case partiallyIsolated
    case restoring
    case recoveryRequired

    public var displayTitle: String {
        switch self {
        case .normal: return "Normal Input"
        case .stoppingLocalAutomation: return "Stopping Local Automation"
        case .localAutomationStopped: return "Local Automation Stopped"
        case .isolating: return "Isolating Network"
        case .isolated: return "Network Isolated"
        case .partiallyIsolated: return "Partial Isolation"
        case .restoring: return "Restoring Human Control"
        case .recoveryRequired: return "Recovery Required"
        }
    }
}

public enum OperationOutcome: String, Codable, Sendable, CaseIterable {
    case planned
    case attempted
    case succeeded
    case failed
    case skipped
    case unsupported
    case conflict
    case alreadyInDesiredState

    public var displayTitle: String {
        switch self {
        case .planned: return "Planned"
        case .attempted: return "Attempted"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        case .unsupported: return "Unsupported"
        case .conflict: return "Conflict"
        case .alreadyInDesiredState: return "Already in desired state"
        }
    }
}

public struct OperationStepResult: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let subsystem: String
    public let targetID: String
    public let targetDisplayName: String
    public let requestedState: String
    public let observedPreState: String?
    public let observedPostState: String?
    public let operationDescription: String
    public let outcome: OperationOutcome
    public let terminationStatus: Int32?
    public let sanitizedStandardError: String?
    public let startedAt: Date
    public let finishedAt: Date

    public init(
        id: UUID = UUID(),
        subsystem: String,
        targetID: String,
        targetDisplayName: String,
        requestedState: String,
        observedPreState: String? = nil,
        observedPostState: String? = nil,
        operationDescription: String,
        outcome: OperationOutcome,
        terminationStatus: Int32? = nil,
        sanitizedStandardError: String? = nil,
        startedAt: Date = Date(),
        finishedAt: Date = Date()
    ) {
        self.id = id
        self.subsystem = subsystem
        self.targetID = targetID
        self.targetDisplayName = targetDisplayName
        self.requestedState = requestedState
        self.observedPreState = observedPreState
        self.observedPostState = observedPostState
        self.operationDescription = operationDescription
        self.outcome = outcome
        self.terminationStatus = terminationStatus
        self.sanitizedStandardError = sanitizedStandardError
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct IncidentRecord: Identifiable, Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let id: UUID
    public let initiatingAction: String
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var originalState: KeyBrakeOperationalState
    public var finalState: KeyBrakeOperationalState
    public var steps: [OperationStepResult]
    public var resolution: String

    public init(
        schemaVersion: Int = 1,
        id: UUID = UUID(),
        initiatingAction: String,
        originalState: KeyBrakeOperationalState,
        finalState: KeyBrakeOperationalState? = nil,
        steps: [OperationStepResult] = [],
        resolution: String = "in progress",
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.initiatingAction = initiatingAction
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.completedAt = nil
        self.originalState = originalState
        self.finalState = finalState ?? originalState
        self.steps = steps
        self.resolution = resolution
    }
}

public struct RecoverySelection: Codable, Sendable, Equatable {
    public let restoreNetwork: Bool
    public let sharingServiceIDs: Set<String>
    public let restartEspanso: Bool

    public init(restoreNetwork: Bool, sharingServiceIDs: Set<String> = [], restartEspanso: Bool = false) {
        self.restoreNetwork = restoreNetwork
        self.sharingServiceIDs = sharingServiceIDs
        self.restartEspanso = restartEspanso
    }
}

public struct EmergencyIsolationPolicy: Codable, Sendable, Equatable {
    public var disableWiFi: Bool
    public var disableEthernet: Bool
    public var disconnectVPN: Bool
    public var disableRemoteLogin: Bool
    public var disableRemoteAppleEvents: Bool

    public init(
        disableWiFi: Bool = true,
        disableEthernet: Bool = true,
        disconnectVPN: Bool = true,
        disableRemoteLogin: Bool = true,
        disableRemoteAppleEvents: Bool = true
    ) {
        self.disableWiFi = disableWiFi
        self.disableEthernet = disableEthernet
        self.disconnectVPN = disconnectVPN
        self.disableRemoteLogin = disableRemoteLogin
        self.disableRemoteAppleEvents = disableRemoteAppleEvents
    }

    public static let standard = EmergencyIsolationPolicy()

    public func permits(_ kind: NetworkServiceKind) -> Bool {
        switch kind {
        case .wifi:
            return disableWiFi
        case .ethernet, .usbEthernet, .thunderbolt:
            return disableEthernet
        case .vpn:
            return disconnectVPN
        case .loopback:
            return false
        case .bridge, .other:
            return true
        }
    }

    public func permitsSharing(identifier: String) -> Bool {
        switch identifier {
        case "remote-login":
            return disableRemoteLogin
        case "remote-apple-events":
            return disableRemoteAppleEvents
        default:
            return false
        }
    }
}

public struct TargetDefinition: Identifiable, Codable, Sendable, Equatable {
    public enum Category: String, Codable, Sendable {
        case localAutomation
        case remoteAccess
    }

    public let id: String
    public var displayName: String
    public var category: Category
    public var bundleIdentifier: String?
    public var applicationURL: URL?
    public var executableURL: URL?
    public var codeSigningTeamIdentifier: String?
    public var codeSigningDesignatedRequirement: String?
    public var approvedByUser: Bool
    public var enabledForEmergencyStop: Bool
    public var allowForcedTermination: Bool
    public var approvedPrivacyServices: Set<TCCService>
    public var verifiedLaunchAgentLabels: Set<String>
    public var verifiedLaunchDaemonLabels: Set<String>
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        category: Category,
        bundleIdentifier: String? = nil,
        applicationURL: URL? = nil,
        executableURL: URL? = nil,
        approvedByUser: Bool = false,
        enabledForEmergencyStop: Bool = true,
        allowForcedTermination: Bool = false,
        approvedPrivacyServices: Set<TCCService> = [],
        verifiedLaunchAgentLabels: Set<String> = [],
        verifiedLaunchDaemonLabels: Set<String> = []
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
        self.executableURL = executableURL
        self.codeSigningTeamIdentifier = nil
        self.codeSigningDesignatedRequirement = nil
        self.approvedByUser = approvedByUser
        self.enabledForEmergencyStop = enabledForEmergencyStop
        self.allowForcedTermination = allowForcedTermination
        self.approvedPrivacyServices = approvedPrivacyServices
        self.verifiedLaunchAgentLabels = verifiedLaunchAgentLabels
        self.verifiedLaunchDaemonLabels = verifiedLaunchDaemonLabels
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public struct NetworkChange: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let device: String?
    public let originalEnabled: Bool
    public var appliedEnabled: Bool?
    public var currentEnabled: Bool?
    public let kind: String
    public let isVPN: Bool

    public init(id: String, displayName: String, device: String? = nil, originalEnabled: Bool, appliedEnabled: Bool? = nil, currentEnabled: Bool? = nil, kind: String, isVPN: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.device = device
        self.originalEnabled = originalEnabled
        self.appliedEnabled = appliedEnabled
        self.currentEnabled = currentEnabled
        self.kind = kind
        self.isVPN = isVPN
    }
}

public struct SharingChange: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let originalEnabled: Bool
    public var appliedEnabled: Bool?
    public var currentEnabled: Bool?
    public let supported: Bool

    public init(id: String, displayName: String, originalEnabled: Bool, appliedEnabled: Bool? = nil, currentEnabled: Bool? = nil, supported: Bool) {
        self.id = id
        self.displayName = displayName
        self.originalEnabled = originalEnabled
        self.appliedEnabled = appliedEnabled
        self.currentEnabled = currentEnabled
        self.supported = supported
    }
}

public struct RecoverySnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let incidentID: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public let hostIdentifier: String
    public let bootSessionIdentifier: String?
    public let originalOperationalState: KeyBrakeOperationalState
    public let localAutomationTargets: [String: Bool]
    public let remoteAccessTargets: [String: Bool]
    public var networkChanges: [NetworkChange]
    public var vpnConnections: [NetworkChange]
    public var sharingChanges: [SharingChange]
    public var privacyResetRequests: [String]
    public var completedSteps: [OperationStepResult]
    public var failedSteps: [OperationStepResult]
    public var unresolvedSteps: [OperationStepResult]

    public init(
        incidentID: UUID,
        originalOperationalState: KeyBrakeOperationalState,
        hostIdentifier: String = Host.current().localizedName ?? "unknown-host",
        bootSessionIdentifier: String? = nil,
        localAutomationTargets: [String: Bool] = [:],
        remoteAccessTargets: [String: Bool] = [:],
        networkChanges: [NetworkChange] = [],
        vpnConnections: [NetworkChange] = [],
        sharingChanges: [SharingChange] = [],
        privacyResetRequests: [String] = [],
        completedSteps: [OperationStepResult] = [],
        failedSteps: [OperationStepResult] = [],
        unresolvedSteps: [OperationStepResult] = [],
        createdAt: Date = Date()
    ) {
        self.schemaVersion = 1
        self.incidentID = incidentID
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.hostIdentifier = hostIdentifier
        self.bootSessionIdentifier = bootSessionIdentifier
        self.originalOperationalState = originalOperationalState
        self.localAutomationTargets = localAutomationTargets
        self.remoteAccessTargets = remoteAccessTargets
        self.networkChanges = networkChanges
        self.vpnConnections = vpnConnections
        self.sharingChanges = sharingChanges
        self.privacyResetRequests = privacyResetRequests
        self.completedSteps = completedSteps
        self.failedSteps = failedSteps
        self.unresolvedSteps = unresolvedSteps
    }
}
