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

    public var isStateChanging: Bool {
        switch self {
        case .stoppingLocalAutomation, .isolating, .restoring:
            return true
        case .normal, .localAutomationStopped, .isolated, .partiallyIsolated, .recoveryRequired:
            return false
        }
    }

    public var requiresRecoveryDecision: Bool {
        switch self {
        case .isolated, .partiallyIsolated, .recoveryRequired:
            return true
        case .normal, .stoppingLocalAutomation, .localAutomationStopped, .isolating, .restoring:
            return false
        }
    }
}

// Greppable:
// canonical: keybrake-termination-gate
// aliases: emergency quit guard; fail-closed startup recovery; transaction quit guard
// forms: keybrake-termination-gate; terminationGate; launch-recovery-gate
// descriptors: application termination policy; emergency transaction; recovery hydration
// states: waiting; transaction-active; recovery-required; clear-to-terminate
// consumers: KeyBrakeViewModel; KeyBrakeAppDelegate; EmergencyCoordinatorTests
// owner: KeyBrakeTerminationGate
public enum KeyBrakeTerminationGate {
    public static func blocksTermination(
        state: KeyBrakeOperationalState,
        launchRecoveryCheckCompleted: Bool,
        recoveryRequired: Bool,
        immediateQuitApproved: Bool
    ) -> Bool {
        guard launchRecoveryCheckCompleted, !state.isStateChanging else {
            return true
        }
        if immediateQuitApproved {
            return false
        }
        return recoveryRequired || state.requiresRecoveryDecision
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
    public let retainVPNDisconnected: Bool

    public init(
        restoreNetwork: Bool,
        sharingServiceIDs: Set<String> = [],
        restartEspanso: Bool = false,
        retainVPNDisconnected: Bool = false
    ) {
        self.restoreNetwork = restoreNetwork
        self.sharingServiceIDs = sharingServiceIDs
        self.restartEspanso = restartEspanso
        self.retainVPNDisconnected = retainVPNDisconnected
    }

    private enum CodingKeys: String, CodingKey {
        case restoreNetwork
        case sharingServiceIDs
        case restartEspanso
        case retainVPNDisconnected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        restoreNetwork = try container.decode(Bool.self, forKey: .restoreNetwork)
        sharingServiceIDs = try container.decode(Set<String>.self, forKey: .sharingServiceIDs)
        restartEspanso = try container.decode(Bool.self, forKey: .restartEspanso)
        retainVPNDisconnected = try container.decodeIfPresent(Bool.self, forKey: .retainVPNDisconnected) ?? false
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
    public let stateObservationKnown: Bool

    public init(id: String, displayName: String, device: String? = nil, originalEnabled: Bool, appliedEnabled: Bool? = nil, currentEnabled: Bool? = nil, kind: String, isVPN: Bool = false, stateObservationKnown: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.device = device
        self.originalEnabled = originalEnabled
        self.appliedEnabled = appliedEnabled
        self.currentEnabled = currentEnabled
        self.kind = kind
        self.isVPN = isVPN
        self.stateObservationKnown = stateObservationKnown
    }

    private enum CodingKeys: String, CodingKey { case id, displayName, device, originalEnabled, appliedEnabled, currentEnabled, kind, isVPN, stateObservationKnown }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        device = try container.decodeIfPresent(String.self, forKey: .device)
        originalEnabled = try container.decode(Bool.self, forKey: .originalEnabled)
        appliedEnabled = try container.decodeIfPresent(Bool.self, forKey: .appliedEnabled)
        currentEnabled = try container.decodeIfPresent(Bool.self, forKey: .currentEnabled)
        kind = try container.decode(String.self, forKey: .kind)
        isVPN = try container.decodeIfPresent(Bool.self, forKey: .isVPN) ?? (kind == NetworkServiceKind.vpn.rawValue)
        stateObservationKnown = try container.decodeIfPresent(Bool.self, forKey: .stateObservationKnown) ?? false
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

public enum RecoveryResourceSubsystem: String, Codable, Sendable, CaseIterable {
    case network
    case sharing
}

public enum RecoveryResourceDisposition: String, Codable, Sendable, CaseIterable {
    case pending
    case restored
    case retained
    case failed
    case conflict
    case unsupported
    case unverified
    case identityMismatch
}

public enum RecoveryResourceProgressUpdateResult: Sendable, Equatable {
    case updated
    case notFound
    case ambiguous
    case identityMismatch
    case identityUnverified
    case observationUnknown
    case appliedStateMismatch
    case observedStateMismatch
}

public struct RecoveryResourceProgress: Codable, Sendable, Equatable, Identifiable {
    public let subsystem: RecoveryResourceSubsystem
    public let resourceID: String
    public let displayName: String
    public let originalEnabled: Bool
    public let originalStateKnown: Bool
    public var appliedEnabled: Bool?
    public var observedEnabled: Bool?
    public var disposition: RecoveryResourceDisposition
    public var identityMatches: Bool?
    public var observedIdentity: String?

    public var id: String { "\(subsystem.rawValue):\(resourceID)" }

    public init(
        subsystem: RecoveryResourceSubsystem,
        resourceID: String,
        displayName: String,
        originalEnabled: Bool,
        originalStateKnown: Bool = true,
        appliedEnabled: Bool? = nil,
        observedEnabled: Bool? = nil,
        disposition: RecoveryResourceDisposition = .pending,
        identityMatches: Bool? = nil,
        observedIdentity: String? = nil
    ) {
        self.subsystem = subsystem
        self.resourceID = resourceID
        self.displayName = displayName
        self.originalEnabled = originalEnabled
        self.originalStateKnown = originalStateKnown
        self.appliedEnabled = appliedEnabled
        self.observedEnabled = observedEnabled
        self.disposition = disposition
        self.identityMatches = identityMatches
        self.observedIdentity = observedIdentity
    }

    private enum CodingKeys: String, CodingKey {
        case subsystem, resourceID, displayName, originalEnabled, originalStateKnown
        case appliedEnabled, observedEnabled, disposition, identityMatches, observedIdentity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subsystem = try container.decode(RecoveryResourceSubsystem.self, forKey: .subsystem)
        resourceID = try container.decode(String.self, forKey: .resourceID)
        displayName = try container.decode(String.self, forKey: .displayName)
        originalEnabled = try container.decode(Bool.self, forKey: .originalEnabled)
        originalStateKnown = try container.decodeIfPresent(Bool.self, forKey: .originalStateKnown) ?? false
        appliedEnabled = try container.decodeIfPresent(Bool.self, forKey: .appliedEnabled)
        observedEnabled = try container.decodeIfPresent(Bool.self, forKey: .observedEnabled)
        disposition = try container.decode(RecoveryResourceDisposition.self, forKey: .disposition)
        identityMatches = try container.decodeIfPresent(Bool.self, forKey: .identityMatches)
        observedIdentity = try container.decodeIfPresent(String.self, forKey: .observedIdentity)
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
    public var resourceProgress: [RecoveryResourceProgress]
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
        resourceProgress: [RecoveryResourceProgress]? = nil,
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
        self.resourceProgress = resourceProgress ?? Self.initialResourceProgress(networkChanges: networkChanges, vpnConnections: vpnConnections, sharingChanges: sharingChanges)
        self.privacyResetRequests = privacyResetRequests
        self.completedSteps = completedSteps
        self.failedSteps = failedSteps
        self.unresolvedSteps = unresolvedSteps
    }

    @discardableResult
    public mutating func updateProgress(
        subsystem: RecoveryResourceSubsystem,
        resourceID: String,
        expectedDisplayName: String,
        appliedEnabled: Bool? = nil,
        observedEnabled: Bool?,
        disposition: RecoveryResourceDisposition,
        identityMatches: Bool? = nil,
        observedIdentity: String? = nil
    ) -> RecoveryResourceProgressUpdateResult {
        let indices = resourceProgress.indices.filter {
            resourceProgress[$0].subsystem == subsystem && resourceProgress[$0].resourceID == resourceID
        }
        guard !indices.isEmpty else { return .notFound }
        guard indices.count == 1, let index = indices.first else { return .ambiguous }

        if resourceProgress[index].displayName != expectedDisplayName || identityMatches == false {
            resourceProgress[index].identityMatches = false
            resourceProgress[index].observedIdentity = observedIdentity
            resourceProgress[index].observedEnabled = nil
            resourceProgress[index].disposition = .identityMismatch
            synchronizeLegacyResource(at: index)
            return .identityMismatch
        }
        if resourceProgress[index].identityMatches == false && identityMatches != true {
            if let observedIdentity {
                resourceProgress[index].observedIdentity = observedIdentity
            }
            resourceProgress[index].observedEnabled = nil
            resourceProgress[index].disposition = .identityMismatch
            synchronizeLegacyResource(at: index)
            return .identityMismatch
        }
        if let identityMatches {
            resourceProgress[index].identityMatches = identityMatches
        }
        if identityMatches == true {
            resourceProgress[index].observedIdentity = nil
        } else if let observedIdentity {
            resourceProgress[index].observedIdentity = observedIdentity
        }
        if let appliedEnabled,
           let historicalAppliedState = resourceProgress[index].appliedEnabled,
           historicalAppliedState != appliedEnabled {
            resourceProgress[index].observedEnabled = observedEnabled
            resourceProgress[index].disposition = .conflict
            synchronizeLegacyResource(at: index)
            return .appliedStateMismatch
        }
        if let appliedEnabled {
            resourceProgress[index].appliedEnabled = appliedEnabled
        }
        resourceProgress[index].observedEnabled = observedEnabled

        if disposition == .restored || disposition == .retained {
            guard identityMatches == true else {
                resourceProgress[index].disposition = .unverified
                synchronizeLegacyResource(at: index)
                return .identityUnverified
            }
            guard let observedEnabled else {
                resourceProgress[index].disposition = .unverified
                synchronizeLegacyResource(at: index)
                return .observationUnknown
            }
            guard resourceProgress[index].originalStateKnown else {
                resourceProgress[index].disposition = .unverified
                synchronizeLegacyResource(at: index)
                return .observationUnknown
            }
            if disposition == .restored && observedEnabled != resourceProgress[index].originalEnabled {
                resourceProgress[index].disposition = .conflict
                synchronizeLegacyResource(at: index)
                return .observedStateMismatch
            }
            if disposition == .retained {
                guard resourceProgress[index].originalStateKnown, resourceProgress[index].originalEnabled else {
                    resourceProgress[index].disposition = .unverified
                    synchronizeLegacyResource(at: index)
                    return .observationUnknown
                }
                guard let historicalAppliedState = resourceProgress[index].appliedEnabled else {
                    resourceProgress[index].disposition = .unverified
                    synchronizeLegacyResource(at: index)
                    return .observationUnknown
                }
                guard observedEnabled == historicalAppliedState else {
                    resourceProgress[index].disposition = .conflict
                    synchronizeLegacyResource(at: index)
                    return .observedStateMismatch
                }
            }
        }

        resourceProgress[index].disposition = disposition
        synchronizeLegacyResource(at: index)
        return .updated
    }

    private mutating func synchronizeLegacyResource(at index: Int) {
        let progress = resourceProgress[index]
        switch progress.subsystem {
        case .network:
            if let legacyIndex = networkChanges.firstIndex(where: { $0.id == progress.resourceID }) {
                networkChanges[legacyIndex].appliedEnabled = progress.appliedEnabled
                networkChanges[legacyIndex].currentEnabled = progress.observedEnabled
                let updatedChange = networkChanges[legacyIndex]
                if updatedChange.isVPN {
                    if let vpnIndex = vpnConnections.firstIndex(where: { $0.id == progress.resourceID }) {
                        vpnConnections[vpnIndex].appliedEnabled = progress.appliedEnabled
                        vpnConnections[vpnIndex].currentEnabled = progress.observedEnabled
                    } else {
                        vpnConnections.append(updatedChange)
                    }
                }
            } else if let vpnIndex = vpnConnections.firstIndex(where: { $0.id == progress.resourceID }) {
                vpnConnections[vpnIndex].appliedEnabled = progress.appliedEnabled
                vpnConnections[vpnIndex].currentEnabled = progress.observedEnabled
            }
        case .sharing:
            if let legacyIndex = sharingChanges.firstIndex(where: { $0.id == progress.resourceID }) {
                sharingChanges[legacyIndex].appliedEnabled = progress.appliedEnabled
                sharingChanges[legacyIndex].currentEnabled = progress.observedEnabled
            }
        }
    }

    private static func initialResourceProgress(
        networkChanges: [NetworkChange],
        vpnConnections: [NetworkChange],
        sharingChanges: [SharingChange]
    ) -> [RecoveryResourceProgress] {
        var progress = networkChanges.map {
            RecoveryResourceProgress(
                subsystem: .network,
                resourceID: $0.id,
                displayName: $0.displayName,
                originalEnabled: $0.originalEnabled,
                originalStateKnown: $0.stateObservationKnown,
                appliedEnabled: $0.appliedEnabled,
                observedEnabled: $0.currentEnabled
            )
        }
        let knownNetworkIDs = Set(networkChanges.map(\.id))
        progress.append(contentsOf: vpnConnections.filter { !knownNetworkIDs.contains($0.id) }.map {
            RecoveryResourceProgress(
                subsystem: .network,
                resourceID: $0.id,
                displayName: $0.displayName,
                originalEnabled: $0.originalEnabled,
                originalStateKnown: $0.stateObservationKnown,
                appliedEnabled: $0.appliedEnabled,
                observedEnabled: $0.currentEnabled
            )
        })
        progress.append(contentsOf: sharingChanges.map {
            RecoveryResourceProgress(
                subsystem: .sharing,
                resourceID: $0.id,
                displayName: $0.displayName,
                originalEnabled: $0.originalEnabled,
                originalStateKnown: $0.supported,
                appliedEnabled: $0.appliedEnabled,
                observedEnabled: $0.currentEnabled
            )
        })
        return progress
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case incidentID
        case createdAt
        case updatedAt
        case hostIdentifier
        case bootSessionIdentifier
        case originalOperationalState
        case localAutomationTargets
        case remoteAccessTargets
        case networkChanges
        case vpnConnections
        case sharingChanges
        case resourceProgress
        case privacyResetRequests
        case completedSteps
        case failedSteps
        case unresolvedSteps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        incidentID = try container.decode(UUID.self, forKey: .incidentID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        hostIdentifier = try container.decode(String.self, forKey: .hostIdentifier)
        bootSessionIdentifier = try container.decodeIfPresent(String.self, forKey: .bootSessionIdentifier)
        originalOperationalState = try container.decode(KeyBrakeOperationalState.self, forKey: .originalOperationalState)
        localAutomationTargets = try container.decode([String: Bool].self, forKey: .localAutomationTargets)
        remoteAccessTargets = try container.decode([String: Bool].self, forKey: .remoteAccessTargets)
        let decodedNetworkChanges = try container.decode([NetworkChange].self, forKey: .networkChanges)
        let decodedVPNConnections = try container.decode([NetworkChange].self, forKey: .vpnConnections)
        let decodedSharingChanges = try container.decode([SharingChange].self, forKey: .sharingChanges)
        networkChanges = decodedNetworkChanges
        vpnConnections = decodedVPNConnections
        sharingChanges = decodedSharingChanges
        if let decodedProgress = try container.decodeIfPresent([RecoveryResourceProgress].self, forKey: .resourceProgress) {
            resourceProgress = decodedProgress.map { progress in
                let originalStateKnown: Bool
                switch progress.subsystem {
                case .network:
                    originalStateKnown = (decodedNetworkChanges.first { $0.id == progress.resourceID }
                        ?? decodedVPNConnections.first { $0.id == progress.resourceID })?.stateObservationKnown ?? progress.originalStateKnown
                case .sharing:
                    originalStateKnown = decodedSharingChanges.first { $0.id == progress.resourceID }?.supported ?? progress.originalStateKnown
                }
                return RecoveryResourceProgress(
                    subsystem: progress.subsystem,
                    resourceID: progress.resourceID,
                    displayName: progress.displayName,
                    originalEnabled: progress.originalEnabled,
                    originalStateKnown: originalStateKnown,
                    appliedEnabled: progress.appliedEnabled,
                    observedEnabled: progress.observedEnabled,
                    disposition: progress.disposition,
                    identityMatches: progress.identityMatches,
                    observedIdentity: progress.observedIdentity
                )
            }
        } else {
            resourceProgress = Self.initialResourceProgress(networkChanges: decodedNetworkChanges, vpnConnections: decodedVPNConnections, sharingChanges: decodedSharingChanges)
        }
        privacyResetRequests = try container.decode([String].self, forKey: .privacyResetRequests)
        completedSteps = try container.decode([OperationStepResult].self, forKey: .completedSteps)
        failedSteps = try container.decode([OperationStepResult].self, forKey: .failedSteps)
        unresolvedSteps = try container.decode([OperationStepResult].self, forKey: .unresolvedSteps)
    }

    public var conflictDetails: [RecoveryConflictDetail] {
        resourceProgress.compactMap { progress in
            guard progress.disposition == .conflict || progress.disposition == .identityMismatch else {
                return nil
            }
            let vpn = (networkChanges + vpnConnections).contains { $0.id == progress.resourceID && $0.isVPN }
            return RecoveryConflictDetail(
                id: progress.id,
                name: progress.displayName,
                original: Self.stateLabel(progress.originalEnabled, known: progress.originalStateKnown, vpn: vpn),
                applied: Self.stateLabel(progress.appliedEnabled, known: progress.appliedEnabled != nil, vpn: vpn),
                current: progress.disposition == .identityMismatch
                    ? (progress.observedIdentity ?? "identity changed")
                    : Self.stateLabel(progress.observedEnabled, known: progress.observedEnabled != nil, vpn: vpn)
            )
        }
    }

    private static func stateLabel(_ value: Bool?, known: Bool, vpn: Bool) -> String {
        guard known, let value else { return "not recorded" }
        if vpn {
            return value ? "connected" : "disconnected"
        }
        return value ? "enabled" : "disabled"
    }
}

public struct IsolationPreviewLine: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public enum IsolationPlanPreview {
    public static func lines(
        for policy: EmergencyIsolationPolicy,
        sandbox: Bool,
        approvedRemoteTargetNames: [String] = []
    ) -> [IsolationPreviewLine] {
        let remoteDetail: String
        if approvedRemoteTargetNames.isEmpty {
            remoteDetail = "No approved remote-access applications will be stopped."
        } else {
            remoteDetail = "Stop approved remote-access applications: \(approvedRemoteTargetNames.joined(separator: ", "))."
        }
        var lines = [
            IsolationPreviewLine(
                id: "wifi",
                title: "Wi-Fi",
                detail: policy.disableWiFi
                    ? "Disable Wi-Fi services that are enabled when isolation starts. Loopback stays active."
                    : "Leave Wi-Fi unchanged."
            ),
            IsolationPreviewLine(
                id: "ethernet",
                title: "Ethernet",
                detail: policy.disableEthernet
                    ? "Disable physical Ethernet services that are enabled when isolation starts."
                    : "Leave physical Ethernet unchanged."
            ),
            IsolationPreviewLine(
                id: "vpn",
                title: "VPN",
                detail: policy.disconnectVPN
                    ? "Disconnect selected VPNs. KeyBrake does not reconnect them during restore."
                    : "Leave VPN connections unchanged."
            ),
            IsolationPreviewLine(
                id: "remote-login",
                title: "Remote Login",
                detail: policy.disableRemoteLogin
                    ? "Disable Remote Login when it is enabled."
                    : "Leave Remote Login unchanged."
            ),
            IsolationPreviewLine(
                id: "remote-apple-events",
                title: "Remote Apple Events",
                detail: policy.disableRemoteAppleEvents
                    ? "Disable Remote Apple Events when they are enabled."
                    : "Leave Remote Apple Events unchanged."
            ),
            IsolationPreviewLine(id: "remote-targets", title: "Remote applications", detail: remoteDetail),
        ]
        if sandbox {
            lines.append(
                IsolationPreviewLine(
                    id: "sandbox",
                    title: "Fixture rehearsal",
                    detail: "This run uses the network sandbox. It does not change host Wi-Fi, VPN, sharing, or privacy settings."
                )
            )
        }
        return lines
    }

    public static func affectsIsolation(
        for policy: EmergencyIsolationPolicy,
        approvedRemoteTargetNames: [String]
    ) -> Bool {
        policy.disableWiFi
            || policy.disableEthernet
            || policy.disconnectVPN
            || policy.disableRemoteLogin
            || policy.disableRemoteAppleEvents
            || !approvedRemoteTargetNames.isEmpty
    }

    public static func confirmationText(
        for policy: EmergencyIsolationPolicy,
        sandbox: Bool,
        approvedRemoteTargetNames: [String] = []
    ) -> String {
        var text = lines(for: policy, sandbox: sandbox, approvedRemoteTargetNames: approvedRemoteTargetNames)
            .map { "\($0.title): \($0.detail)" }
            .joined(separator: "\n")
        if !sandbox && !affectsIsolation(for: policy, approvedRemoteTargetNames: approvedRemoteTargetNames) {
            text += "\nThis plan does not change network, sharing, or approved remote applications."
        }
        return text
    }

    public static func changingTitles(
        for policy: EmergencyIsolationPolicy,
        sandbox: Bool,
        approvedRemoteTargetNames: [String] = []
    ) -> [String] {
        lines(for: policy, sandbox: sandbox, approvedRemoteTargetNames: approvedRemoteTargetNames)
            .filter { line in
                line.id != "sandbox"
                    && !line.detail.hasPrefix("Leave")
                    && !line.detail.hasPrefix("No approved")
            }
            .map(\.title)
    }
}

public struct KeyBrakeRemoteSessionNotice: Equatable, Sendable {
    public let sessionNames: [String]

    public init(sessionNames: [String]) {
        self.sessionNames = sessionNames
    }

    public var warningSentence: String {
        "You are connected through \(sessionNames.joined(separator: " and ")). Stop Remote Access can disconnect this session."
    }

    public static func notice(loginHosts: [String], screenSharingConnected: Bool) -> KeyBrakeRemoteSessionNotice? {
        var names: [String] = []
        if screenSharingConnected {
            names.append("Screen Sharing")
        }
        let hosts = loginHosts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let host = hosts.first {
            names.append("Remote Login from \(host)")
        }
        guard !names.isEmpty else { return nil }
        return KeyBrakeRemoteSessionNotice(sessionNames: names)
    }
}

public enum KeyBrakeBuildSigning: Equatable, Sendable {
    case developerID
    case otherSigned
    case unsignedOrAdHoc
}

public enum KeyBrakeHelperRegistrationCopy {
    public static let unsignedSentence = "Network and sharing changes wait for a signed install."

    public static func buttonTitle(signing: KeyBrakeBuildSigning) -> String {
        switch signing {
        case .developerID, .otherSigned:
            return "Register Privileged Helper"
        case .unsignedOrAdHoc:
            return unsignedSentence
        }
    }

    public static func canRegister(signing: KeyBrakeBuildSigning) -> Bool {
        signing != .unsignedOrAdHoc
    }
}

public enum KeyBrakeStopExplanation {
    public static func localBlastRadius(names: [String]) -> String {
        let unique = Array(Set(names)).sorted()
        if unique.isEmpty {
            return "No local typing apps are set to stop."
        }
        return "Will stop: \(unique.joined(separator: ", "))."
    }

    public static func remoteBlastRadius(changingTitles: [String]) -> String {
        if changingTitles.isEmpty {
            return "This isolation plan changes nothing."
        }
        return "Will change: \(changingTitles.joined(separator: ", "))."
    }

    public static func partialStopSummary(state: KeyBrakeOperationalState, incident: IncidentRecord?) -> String? {
        guard state == .partiallyIsolated, let incident else { return nil }
        let changed = uniqueNames(incident.steps.filter { $0.outcome == .succeeded }.map(\.targetDisplayName))
        let stayed = uniqueNames(incident.steps.filter {
            $0.outcome == .failed || $0.outcome == .unsupported || $0.outcome == .conflict || $0.outcome == .skipped
        }.map(\.targetDisplayName))
        var parts: [String] = []
        if !changed.isEmpty {
            parts.append("Changed: \(changed.joined(separator: ", ")).")
        }
        if !stayed.isEmpty {
            parts.append("Stayed as it was: \(stayed.joined(separator: ", ")).")
        }
        if parts.isEmpty {
            return "Some changes did not finish. Open the incident log for the recorded steps."
        }
        return parts.joined(separator: " ")
    }

    public static func stillOffSentence(names: [String], since: Date?, now: Date = Date()) -> String {
        let unique = Array(Set(names)).sorted()
        let duration = since.map { agePhrase(from: $0, now: now) }
        if unique.isEmpty {
            return duration.map { "Recovery is still pending. \($0)" } ?? "Recovery is still pending."
        }
        let list = "Still off: \(unique.joined(separator: ", "))."
        return duration.map { "\(list) \($0)" } ?? list
    }

    private static func uniqueNames(_ names: [String]) -> [String] {
        Array(Set(names)).sorted()
    }

    private static func agePhrase(from start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 {
            return "Off for less than a minute."
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "Off for \(minutes) \(minutes == 1 ? "minute" : "minutes")."
        }
        let hours = minutes / 60
        if hours < 48 {
            return "Off for \(hours) \(hours == 1 ? "hour" : "hours")."
        }
        let days = hours / 24
        return "Off for \(days) \(days == 1 ? "day" : "days")."
    }
}

public struct RecoveryConflictDetail: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let original: String
    public let applied: String
    public let current: String

    public init(id: String, name: String, original: String, applied: String, current: String) {
        self.id = id
        self.name = name
        self.original = original
        self.applied = applied
        self.current = current
    }
}

public enum KeyBrakeIncidentExport {
    public static func jsonData(from incidents: [IncidentRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(incidents)
    }
}
