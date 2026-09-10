import Foundation

public actor EmergencyCoordinator {
    private var operationalState: KeyBrakeOperationalState
    private let recoveryStore: RecoveryStore
    private let incidentStore: IncidentStore
    private let processController: ProcessControlling
    private let espanso: EspansoAdapter
    private let networkController: NetworkControlling
    private let privacyController: PrivacyController
    private var targetDefinitions: [TargetDefinition]
    private let sharingController: SharingServiceController?
    private var latestIncident: IncidentRecord?

    public init(
        recoveryStore: RecoveryStore,
        incidentStore: IncidentStore,
        processController: ProcessControlling,
        espanso: EspansoAdapter,
        networkController: NetworkControlling,
        privacyController: PrivacyController,
        targetDefinitions: [TargetDefinition] = TargetRegistry.builtInRemoteAccess,
        sharingController: SharingServiceController? = nil,
        initialState: KeyBrakeOperationalState = .normal
    ) {
        self.recoveryStore = recoveryStore
        self.incidentStore = incidentStore
        self.processController = processController
        self.espanso = espanso
        self.networkController = networkController
        self.privacyController = privacyController
        self.targetDefinitions = targetDefinitions
        self.sharingController = sharingController
        self.operationalState = initialState
    }

    public static func live() -> EmergencyCoordinator {
        let runner = ProcessCommandRunner()
        let helper = HelperXPCClient()
        let recoveryStore = RecoveryStore()
        let incidentStore = IncidentStore()
        let sharing = SharingServiceController(adapters: [
            SystemSharingServiceAdapter(identifier: "remote-login", displayName: "Remote Login", commandRunner: runner, helper: helper, getterArguments: ["-getremotelogin"], enableArguments: ["-setremotelogin", "on"], disableArguments: ["-setremotelogin", "off"]),
            SystemSharingServiceAdapter(identifier: "remote-apple-events", displayName: "Remote Apple Events", commandRunner: runner, helper: helper, getterArguments: ["-getremoteappleevents"], enableArguments: ["-setremoteappleevents", "on"], disableArguments: ["-setremoteappleevents", "off"])
        ])
        return EmergencyCoordinator(
            recoveryStore: recoveryStore,
            incidentStore: incidentStore,
            processController: SystemProcessController(),
            espanso: EspansoAdapter(commandRunner: runner),
            networkController: SystemNetworkController(commandRunner: runner, helper: helper),
            privacyController: PrivacyController(commandRunner: runner),
            sharingController: sharing
        )
    }

    public func state() -> KeyBrakeOperationalState { operationalState }
    public func latest() -> IncidentRecord? { latestIncident }
    public func configuredTargets() -> [TargetDefinition] { targetDefinitions }
    public func recoverySnapshot() -> RecoverySnapshot? { try? recoveryStore.load() }

    public func replaceTargetDefinitions(_ definitions: [TargetDefinition]) {
        targetDefinitions = definitions.filter { definition in
            TargetRegistry.canEnroll(definition, applicationBundleIdentifier: definition.bundleIdentifier, executableURL: definition.executableURL)
        }
    }

    public func setTargetApproval(targetID: String, approved: Bool) {
        guard let index = targetDefinitions.firstIndex(where: { $0.id == targetID }) else { return }
        targetDefinitions[index].approvedByUser = approved
        targetDefinitions[index].updatedAt = Date()
    }

    public func recoverUnresolvedStateAtLaunch() -> RecoverySnapshot? {
        do {
            let snapshot = try recoveryStore.load()
            if snapshot != nil { operationalState = .recoveryRequired }
            return snapshot
        } catch {
            operationalState = .recoveryRequired
            return nil
        }
    }

    public func stopSkynetLocally() async -> IncidentRecord {
        guard operationalState == .normal || operationalState == .localAutomationStopped else {
            return await conflictIncident(action: "Stop Skynet Locally", detail: "Local stop is not legal from \(operationalState.rawValue)")
        }
        let original = operationalState
        operationalState = .stoppingLocalAutomation
        var incident = IncidentRecord(initiatingAction: "Stop Skynet Locally", originalState: original)
        incident.steps.append(contentsOf: await performLocalStopSteps())
        operationalState = incident.steps.contains(where: { $0.outcome == .failed || $0.outcome == .conflict }) ? .recoveryRequired : .localAutomationStopped
        incident.finalState = operationalState
        incident.updatedAt = Date()
        incident.completedAt = Date()
        incident.resolution = operationalState == .localAutomationStopped ? "Local automation stopped and verified" : "Local automation stop requires review"
        await persist(&incident)
        return incident
    }

    public func stopRemoteAccess(policy: EmergencyIsolationPolicy = .standard) async -> IncidentRecord {
        guard operationalState == .normal || operationalState == .localAutomationStopped else {
            return await conflictIncident(action: "Stop Remote Access", detail: "Isolation is not legal from \(operationalState.rawValue)")
        }
        let original = operationalState
        operationalState = .isolating
        var incident = IncidentRecord(initiatingAction: "Stop Remote Access", originalState: original)
        let networkChanges = (await networkController.captureSnapshot()).filter { change in
            guard let kind = NetworkServiceKind(rawValue: change.kind) else { return true }
            return policy.permits(kind)
        }
        let sharingChanges = (await sharingController?.captureChanges() ?? []).filter {
            policy.permitsSharing(identifier: $0.id)
        }
        var snapshot = RecoverySnapshot(incidentID: incident.id, originalOperationalState: original, networkChanges: networkChanges, vpnConnections: networkChanges.filter(\.isVPN), sharingChanges: sharingChanges)
        do {
            try recoveryStore.save(snapshot)
            incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "persisted", observedPostState: "verified", operationDescription: "Atomic recovery snapshot persisted before system mutation", outcome: .succeeded))
        } catch {
            incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "persisted", operationDescription: "Recovery snapshot could not be written; reversible system mutation skipped", outcome: .failed, sanitizedStandardError: error.localizedDescription))
        }
        var snapshotReady = incident.steps.last?.outcome == .succeeded

        incident.steps.append(contentsOf: await performLocalStopSteps())
        for target in targetDefinitions where target.category == .remoteAccess && target.approvedByUser && target.enabledForEmergencyStop {
            let matches = processController.matchingProcesses(for: target)
            if matches.isEmpty {
                incident.steps.append(OperationStepResult(subsystem: "remoteAccess", targetID: target.id, targetDisplayName: target.displayName, requestedState: "stopped", operationDescription: "Approved target not running", outcome: .alreadyInDesiredState))
            } else {
                for process in matches {
                    let result = await processController.stop(process, allowForcedTermination: target.allowForcedTermination)
                    incident.steps.append(OperationStepResult(subsystem: "remoteAccess", targetID: target.id, targetDisplayName: target.displayName, requestedState: "stopped", observedPreState: "running", observedPostState: result.outcome == .succeeded ? "stopped" : "running", operationDescription: result.detail, outcome: result.outcome))
                }
            }
        }
        if snapshotReady {
            if let sharingController {
                var sharingSteps: [OperationStepResult] = []
                for change in snapshot.sharingChanges where change.originalEnabled && change.supported {
                    if let adapter = sharingController.adapters.first(where: { $0.identifier == change.id }) {
                        let step = await adapter.disable(expectedState: SharingServiceState(enabled: change.originalEnabled, supported: change.supported))
                        sharingSteps.append(step)
                        incident.steps.append(step)
                    }
                }
                applyIsolationResults(sharingSteps, to: &snapshot)
                do {
                    try recoveryStore.save(snapshot)
                } catch {
                    snapshotReady = false
                    incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "applied state persisted", operationDescription: "Sharing isolation completed but its applied state could not be journaled", outcome: .failed, sanitizedStandardError: error.localizedDescription))
                }
            }
            if snapshotReady {
                let networkSteps = await networkController.isolate(networkChanges)
                incident.steps.append(contentsOf: networkSteps)
                applyIsolationResults(networkSteps, to: &snapshot)
                do {
                    try recoveryStore.save(snapshot)
                } catch {
                    snapshotReady = false
                    incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "applied state persisted", operationDescription: "Network isolation completed but its applied state could not be journaled", outcome: .failed, sanitizedStandardError: error.localizedDescription))
                }
            }
        }
        let failures = incident.steps.filter { $0.outcome == .failed || $0.outcome == .conflict }
        operationalState = failures.isEmpty && snapshotReady ? .isolated : .partiallyIsolated
        incident.finalState = operationalState
        incident.updatedAt = Date()
        incident.completedAt = Date()
        incident.resolution = operationalState == .isolated ? "Network isolation completed and verified" : "Isolation partially completed; review the incident and recovery panel"
        await persist(&incident)
        return incident
    }

    public func revokeAppAccess(targetID: String, services: Set<TCCService>, bundleIdentifier: String, displayName: String) async -> IncidentRecord {
        var incident = IncidentRecord(initiatingAction: "Revoke App Access…", originalState: operationalState)
        incident.steps.append(contentsOf: await privacyController.reset(PrivacyResetRequest(bundleIdentifier: bundleIdentifier, services: services), targetDisplayName: displayName))
        incident.finalState = operationalState
        incident.completedAt = Date()
        incident.updatedAt = Date()
        incident.resolution = "Selected TCC-managed privacy decisions were requested for reset; macOS may request permission again"
        await persist(&incident)
        return incident
    }

    public func restoreHumanControl(selection: RecoverySelection) async -> IncidentRecord {
        guard operationalState == .isolated || operationalState == .partiallyIsolated || operationalState == .recoveryRequired else {
            return await conflictIncident(action: "Restore Human Control", detail: "No isolated state requires restoration")
        }
        operationalState = .restoring
        var incident = IncidentRecord(initiatingAction: "Restore Human Control", originalState: .restoring)
        do {
            guard var snapshot = try recoveryStore.load() else { throw KeyBrakeStorageError.missingRecovery }
            if selection.restoreNetwork { incident.steps.append(contentsOf: await networkController.restore(snapshot.networkChanges)) }
            if !selection.sharingServiceIDs.isEmpty, let sharingController {
                incident.steps.append(contentsOf: await sharingController.restore(snapshot.sharingChanges, selectedIDs: selection.sharingServiceIDs))
            }
            if selection.restartEspanso { incident.steps.append(await espanso.start()) }
            applyRestorationResults(incident.steps, to: &snapshot)
            snapshot.completedSteps.append(contentsOf: incident.steps.filter { $0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState || $0.outcome == .skipped })
            snapshot.failedSteps.append(contentsOf: incident.steps.filter { $0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported })
            snapshot.unresolvedSteps = unresolvedRecoverySteps(in: snapshot, latestSteps: incident.steps)
            snapshot.updatedAt = Date()
            if snapshot.unresolvedSteps.isEmpty {
                try recoveryStore.clear()
                operationalState = .normal
            } else {
                try recoveryStore.save(snapshot)
                operationalState = .recoveryRequired
            }
        } catch {
            incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "resolved", operationDescription: "Recovery remains available because the snapshot could not be completed", outcome: .failed, sanitizedStandardError: error.localizedDescription))
            operationalState = .recoveryRequired
        }
        incident.finalState = operationalState
        incident.updatedAt = Date()
        incident.completedAt = Date()
        incident.resolution = operationalState == .normal ? "Human control restored; remote-control apps remain stopped and VPN remains disconnected" : "Recovery remains required"
        await persist(&incident)
        return incident
    }

    private func unresolvedRecoverySteps(in snapshot: RecoverySnapshot, latestSteps: [OperationStepResult]) -> [OperationStepResult] {
        var unresolved = latestSteps.filter { $0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported }
        let restoredNetworkIDs = Set(latestSteps.filter { $0.subsystem == "network" && ($0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState) }.map(\.targetID))
        let restoredSharingIDs = Set(latestSteps.filter { $0.subsystem == "sharing" && ($0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState) }.map(\.targetID))
        for change in snapshot.networkChanges where change.originalEnabled && !restoredNetworkIDs.contains(change.id) {
            unresolved.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "pending restore", operationDescription: "Network service remains in the applied isolation state", outcome: .failed))
        }
        for change in snapshot.sharingChanges where change.originalEnabled && change.supported && !restoredSharingIDs.contains(change.id) {
            unresolved.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "pending restore", operationDescription: "Sharing service remains in the applied isolation state", outcome: .failed))
        }
        return unresolved
    }

    private func applyIsolationResults(_ steps: [OperationStepResult], to snapshot: inout RecoverySnapshot) {
        for step in steps where step.subsystem == "network" {
            guard let index = snapshot.networkChanges.firstIndex(where: { $0.id == step.targetID }) else { continue }
            switch step.outcome {
            case .succeeded, .alreadyInDesiredState, .skipped:
                snapshot.networkChanges[index].appliedEnabled = false
                snapshot.networkChanges[index].currentEnabled = false
            default:
                snapshot.networkChanges[index].currentEnabled = nil
            }
        }
        for step in steps where step.subsystem == "sharing" {
            guard let index = snapshot.sharingChanges.firstIndex(where: { $0.id == step.targetID }) else { continue }
            switch step.outcome {
            case .succeeded, .alreadyInDesiredState, .skipped:
                snapshot.sharingChanges[index].appliedEnabled = false
                snapshot.sharingChanges[index].currentEnabled = false
            default:
                snapshot.sharingChanges[index].currentEnabled = nil
            }
        }
        snapshot.vpnConnections = snapshot.networkChanges.filter(\.isVPN)
        snapshot.updatedAt = Date()
    }

    private func applyRestorationResults(_ steps: [OperationStepResult], to snapshot: inout RecoverySnapshot) {
        for step in steps where step.subsystem == "network" {
            guard let index = snapshot.networkChanges.firstIndex(where: { $0.id == step.targetID }) else { continue }
            switch step.outcome {
            case .skipped where snapshot.networkChanges[index].isVPN:
                snapshot.networkChanges[index].currentEnabled = false
                snapshot.networkChanges[index].appliedEnabled = false
            case .succeeded, .alreadyInDesiredState, .skipped:
                snapshot.networkChanges[index].currentEnabled = snapshot.networkChanges[index].originalEnabled
                snapshot.networkChanges[index].appliedEnabled = snapshot.networkChanges[index].originalEnabled
            case .conflict:
                snapshot.networkChanges[index].currentEnabled = step.observedPostState == "enabled" ? true : false
            default:
                break
            }
        }
        for step in steps where step.subsystem == "sharing" {
            guard let index = snapshot.sharingChanges.firstIndex(where: { $0.id == step.targetID }) else { continue }
            switch step.outcome {
            case .succeeded, .alreadyInDesiredState, .skipped:
                snapshot.sharingChanges[index].currentEnabled = snapshot.sharingChanges[index].originalEnabled
                snapshot.sharingChanges[index].appliedEnabled = snapshot.sharingChanges[index].originalEnabled
            case .conflict:
                snapshot.sharingChanges[index].currentEnabled = step.observedPostState == "enabled" ? true : false
            default:
                break
            }
        }
        snapshot.vpnConnections = snapshot.networkChanges.filter(\.isVPN)
        snapshot.updatedAt = Date()
    }

    public func restartEspanso() async -> OperationStepResult {
        await espanso.restart()
    }

    private func performLocalStopSteps() async -> [OperationStepResult] {
        var steps = await espanso.stop()
        for target in targetDefinitions where target.category == .localAutomation && target.enabledForEmergencyStop {
            let matches = processController.matchingProcesses(for: target)
            if matches.isEmpty {
                steps.append(OperationStepResult(subsystem: "localAutomation", targetID: target.id, targetDisplayName: target.displayName, requestedState: "stopped", operationDescription: "Target not running", outcome: .alreadyInDesiredState))
            } else {
                for process in matches {
                    let result = await processController.stop(process, allowForcedTermination: target.allowForcedTermination)
                    steps.append(OperationStepResult(subsystem: "localAutomation", targetID: target.id, targetDisplayName: target.displayName, requestedState: "stopped", observedPreState: "running", observedPostState: result.outcome == .succeeded ? "stopped" : "running", operationDescription: result.detail, outcome: result.outcome))
                }
            }
        }
        return steps
    }

    private func conflictIncident(action: String, detail: String) async -> IncidentRecord {
        var incident = IncidentRecord(initiatingAction: action, originalState: operationalState)
        incident.steps.append(OperationStepResult(subsystem: "coordinator", targetID: "state", targetDisplayName: "KeyBrake", requestedState: "legal transition", operationDescription: detail, outcome: .conflict))
        incident.finalState = operationalState
        incident.completedAt = Date()
        incident.updatedAt = Date()
        incident.resolution = "No state mutation performed"
        await persist(&incident)
        return incident
    }

    private func persist(_ incident: inout IncidentRecord) async {
        latestIncident = incident
        try? incidentStore.save(incident)
    }
}
