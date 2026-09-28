import Foundation

public actor EmergencyCoordinator {
    private var operationalState: KeyBrakeOperationalState
    private let recoveryStore: RecoveryStore
    private let incidentStore: IncidentStore
    private let processController: ProcessControlling
    private let espanso: EspansoAdapter
    private let networkController: NetworkControlling
    private let privacyController: PrivacyController
    private let helper: HelperOperating
    private var targetDefinitions: [TargetDefinition]
    private let sharingController: SharingServiceController?
    private var latestIncident: IncidentRecord?
    private var activeMutationID: UUID?

    public init(
        recoveryStore: RecoveryStore,
        incidentStore: IncidentStore,
        processController: ProcessControlling,
        espanso: EspansoAdapter,
        networkController: NetworkControlling,
        privacyController: PrivacyController,
        helper: HelperOperating = UnavailableHelper(),
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
        self.helper = helper
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
            helper: helper,
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
        guard let mutationID = beginMutation() else {
            return await conflictIncident(action: "Stop Skynet Locally", detail: "Another KeyBrake state-changing operation is still in flight")
        }
        defer { endMutation(mutationID) }
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
        guard let mutationID = beginMutation() else {
            return await conflictIncident(action: "Stop Remote Access", detail: "Another KeyBrake state-changing operation is still in flight")
        }
        defer { endMutation(mutationID) }
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
            incident.steps.append(contentsOf: await performVerifiedLaunchdStops(for: target))
        }
        if snapshotReady {
            let unrecoverableFailures = incident.steps.filter {
                ($0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported)
                    && $0.subsystem != "network" && $0.subsystem != "sharing" && $0.subsystem != "recovery"
            }
            snapshot.failedSteps.append(contentsOf: unrecoverableFailures)
            snapshot.unresolvedSteps.append(contentsOf: unrecoverableFailures)
            do {
                try recoveryStore.save(snapshot)
            } catch {
                snapshotReady = false
                incident.steps.append(recoveryWriteFailure("Pre-isolation stop outcomes could not be journaled; network and sharing mutation skipped", error: error))
            }
        }
        if snapshotReady, let sharingController {
            for change in snapshot.sharingChanges {
                do {
                    try ensureProgressEntry(in: snapshot, subsystem: .sharing, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.supported)
                } catch {
                    snapshotReady = false
                    incident.steps.append(recoveryWriteFailure("Sharing recovery entry is missing or inconsistent; mutation skipped", error: error))
                    break
                }
                let live = await sharingController.captureChanges()
                let identity = sharingIdentity(for: change, in: live)
                guard identity.matches, let current = identity.change else {
                    let step = identityMismatchStep(subsystem: "sharing", id: change.id, name: change.displayName, identity: identity.description)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Sharing identity conflict could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                if !change.supported {
                    let disposition: RecoveryResourceDisposition = .unsupported
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: disposition, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Unsupported sharing state could not be journaled; further isolation skipped", error: error))
                        break
                    }
                    incident.steps.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "disabled" : "preserve recorded state", operationDescription: "Sharing service state is unsupported or unknown; no mutation was issued", outcome: .unsupported))
                    continue
                }

                guard change.supported, current.supported else {
                    let step = OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "isolate recorded state", operationDescription: "Sharing service state is unsupported or unknown; no mutation was issued", outcome: .unsupported)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unsupported, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Unsupported sharing state could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }
                guard current.originalEnabled == change.originalEnabled else {
                    let step = OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "disabled" : "remain disabled", observedPreState: current.originalEnabled ? "enabled" : "disabled", observedPostState: current.originalEnabled ? "enabled" : "disabled", operationDescription: "Sharing service changed after the recovery snapshot; no isolation mutation was issued", outcome: .conflict)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.originalEnabled, disposition: .conflict, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Sharing state conflict could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                if !change.originalEnabled {
                    let step = OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Sharing service was disabled before isolation", outcome: .alreadyInDesiredState)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: false, observedEnabled: false, disposition: .restored, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Pre-disabled sharing state could not be journaled; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                guard let adapter = sharingController.adapters.first(where: { $0.identifier == change.id }) else {
                    let step = OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "No sharing adapter is available for this recorded service", outcome: .unsupported)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unsupported, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Missing sharing adapter could not be journaled; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                let result = await adapter.disable(expectedState: SharingServiceState(enabled: current.originalEnabled, supported: current.supported))
                let postIdentity = sharingIdentity(for: change, in: await sharingController.captureChanges())
                let observed = postIdentity.matches ? postIdentity.change?.originalEnabled : nil
                let applied: Bool? = result.outcome == .succeeded && postIdentity.matches && observed == false ? false : nil
                let disposition: RecoveryResourceDisposition = applied == false ? .pending : (postIdentity.matches ? recoveryDisposition(for: result.outcome) : .identityMismatch)
                incident.steps.append(result)
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: applied, observedEnabled: observed, disposition: disposition, identityMatches: postIdentity.matches, observedIdentity: postIdentity.description)
                } catch {
                    snapshotReady = false
                    incident.steps.append(recoveryWriteFailure("Sharing applied state could not be persisted; further isolation skipped", error: error))
                    break
                }
                if !postIdentity.matches {
                    incident.steps.append(identityMismatchStep(subsystem: "sharing", id: change.id, name: change.displayName, identity: postIdentity.description))
                } else if result.outcome == .succeeded && observed != false {
                    incident.steps.append(observationFailureStep(subsystem: "sharing", id: change.id, name: change.displayName, observed: observed, expected: false))
                }
            }
        }
        if snapshotReady {
            for change in snapshot.networkChanges {
                do {
                    try ensureProgressEntry(in: snapshot, subsystem: .network, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.stateObservationKnown)
                } catch {
                    snapshotReady = false
                    incident.steps.append(recoveryWriteFailure("Network recovery entry is missing or inconsistent; mutation skipped", error: error))
                    break
                }
                let currentServices = await networkController.inventory()
                let identity = networkIdentity(for: change, in: currentServices)
                guard identity.matches, let current = identity.service else {
                    incident.steps.append(identityMismatchStep(subsystem: "network", id: change.id, name: change.displayName, identity: identity.description))
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Network identity conflict could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                guard change.stateObservationKnown, current.enabledObservationKnown else {
                    let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "isolate recorded state", operationDescription: "Original or current network state is unknown; no mutation was issued", outcome: .conflict)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unverified, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Unknown network state could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }
                guard current.enabled == change.originalEnabled else {
                    let state = current.enabled ? "enabled" : "disabled"
                    incident.steps.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "disabled" : "remain disabled", observedPreState: state, observedPostState: state, operationDescription: "Network state changed after the recovery snapshot; no isolation mutation was issued", outcome: .conflict))
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.enabled, disposition: .conflict, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Network state conflict could not be persisted; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                if !change.originalEnabled {
                    let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Network service was disabled before isolation", outcome: .alreadyInDesiredState)
                    incident.steps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: false, observedEnabled: false, disposition: .restored, identityMatches: true)
                    } catch {
                        snapshotReady = false
                        incident.steps.append(recoveryWriteFailure("Pre-disabled network state could not be journaled; further isolation skipped", error: error))
                        break
                    }
                    continue
                }

                let results = await networkController.isolate([change])
                let result = results.first(where: { $0.subsystem == "network" && $0.targetID == change.id })
                    ?? OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "disabled", operationDescription: "Network controller returned no result for the recorded service", outcome: .failed)
                let postIdentity = networkIdentity(for: change, in: await networkController.inventory())
                let observed = postIdentity.matches ? postIdentity.service?.enabled : nil
                let applied: Bool? = result.outcome == .succeeded && postIdentity.matches && observed == false ? false : nil
                let disposition: RecoveryResourceDisposition = applied == false ? .pending : (postIdentity.matches ? recoveryDisposition(for: result.outcome) : .identityMismatch)
                incident.steps.append(result)
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: applied, observedEnabled: observed, disposition: disposition, identityMatches: postIdentity.matches, observedIdentity: postIdentity.description)
                } catch {
                    snapshotReady = false
                    incident.steps.append(recoveryWriteFailure("Network applied state could not be persisted; further isolation skipped", error: error))
                    break
                }
                if !postIdentity.matches {
                    incident.steps.append(identityMismatchStep(subsystem: "network", id: change.id, name: change.displayName, identity: postIdentity.description))
                } else if result.outcome == .succeeded && observed != false {
                    incident.steps.append(observationFailureStep(subsystem: "network", id: change.id, name: change.displayName, observed: observed, expected: false))
                }
            }
        }

        if snapshotReady {
            snapshot.unresolvedSteps = unresolvedRecoverySteps(in: snapshot, latestSteps: incident.steps, includePendingResources: false)
            snapshot.updatedAt = Date()
            do {
                try recoveryStore.save(snapshot)
            } catch {
                snapshotReady = false
                incident.steps.append(recoveryWriteFailure("Final per-resource isolation progress could not be persisted", error: error))
            }
        }
        let failures = incident.steps.contains { $0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported }
        operationalState = failures || !snapshotReady ? .partiallyIsolated : .isolated
        incident.finalState = operationalState
        incident.updatedAt = Date()
        incident.completedAt = Date()
        incident.resolution = operationalState == .isolated ? "Network isolation completed and verified" : "Isolation partially completed; review the incident and recovery panel"
        await persist(&incident)
        return incident
    }

    public func revokeAppAccess(targetID: String, services: Set<TCCService>, bundleIdentifier: String, displayName: String) async -> IncidentRecord {
        guard let mutationID = beginMutation() else {
            return await conflictIncident(action: "Revoke App Access…", detail: "Another KeyBrake state-changing operation is still in flight")
        }
        defer { endMutation(mutationID) }
        guard let configuredTarget = targetDefinitions.first(where: { $0.id == targetID }),
              configuredTarget.bundleIdentifier == bundleIdentifier,
              TargetRegistry.canEnroll(configuredTarget, applicationBundleIdentifier: bundleIdentifier, executableURL: configuredTarget.executableURL) else {
            return await conflictIncident(action: "Revoke App Access…", detail: "The selected application's configured identity changed or is no longer eligible")
        }
        var incident = IncidentRecord(initiatingAction: "Revoke App Access…", originalState: operationalState)
        incident.steps.append(contentsOf: await privacyController.reset(PrivacyResetRequest(bundleIdentifier: bundleIdentifier, services: services), targetDisplayName: displayName))
        incident.finalState = operationalState
        incident.completedAt = Date()
        incident.updatedAt = Date()
        incident.resolution = "Selected TCC-managed privacy decisions were requested for reset; macOS may request permission again"
        await persist(&incident)
        return incident
    }

    public func resetKeyboardAccess(target: TargetDefinition) async -> IncidentRecord {
        guard let mutationID = beginMutation() else {
            return await conflictIncident(action: "Reset Keyboard Access", detail: "Another KeyBrake state-changing operation is still in flight")
        }
        defer { endMutation(mutationID) }
        guard let configuredTarget = targetDefinitions.first(where: { $0.id == target.id }),
              configuredTarget.bundleIdentifier == target.bundleIdentifier,
              configuredTarget.applicationURL == target.applicationURL,
              configuredTarget.executableURL == target.executableURL,
              let bundleIdentifier = configuredTarget.bundleIdentifier,
              !TargetRegistry.protectedIdentifiers.contains(target.id),
              !TargetRegistry.protectedIdentifiers.contains(bundleIdentifier),
              TargetRegistry.canEnroll(configuredTarget, applicationBundleIdentifier: bundleIdentifier, executableURL: configuredTarget.executableURL) else {
            return await conflictIncident(action: "Reset Keyboard Access", detail: "The selected application's configured identity changed, was removed, or is protected")
        }

        var incident = IncidentRecord(initiatingAction: "Reset Keyboard Access", originalState: operationalState)
        incident.steps.append(contentsOf: await privacyController.reset(
            .keyboardInput(bundleIdentifier: bundleIdentifier),
            targetDisplayName: configuredTarget.displayName
        ))
        incident.finalState = operationalState
        incident.completedAt = Date()
        incident.updatedAt = Date()
        incident.resolution = "Requested macOS to reset the selected application's Input Monitoring and Send Keystrokes / Input decisions; this does not stop the keyboard or prevent future permission prompts"
        await persist(&incident)
        return incident
    }

    public func restoreHumanControl(selection: RecoverySelection) async -> IncidentRecord {
        guard let mutationID = beginMutation() else {
            return await conflictIncident(action: "Restore Human Control", detail: "Another KeyBrake state-changing operation is still in flight")
        }
        defer { endMutation(mutationID) }
        guard operationalState == .isolated || operationalState == .partiallyIsolated || operationalState == .recoveryRequired else {
            return await conflictIncident(action: "Restore Human Control", detail: "No isolated state requires restoration")
        }
        guard selection.restoreNetwork || !selection.sharingServiceIDs.isEmpty || selection.restartEspanso else {
            return await conflictIncident(action: "Restore Human Control", detail: "The recovery selection contains no action")
        }
        guard !selection.retainVPNDisconnected || selection.restoreNetwork else {
            return await conflictIncident(action: "Restore Human Control", detail: "VPN retention requires the network restoration selection")
        }

        let stateBeforeRestore = operationalState
        var snapshot: RecoverySnapshot
        do {
            guard let loaded = try recoveryStore.load() else { throw KeyBrakeStorageError.missingRecovery }
            snapshot = loaded
        } catch {
            operationalState = .recoveryRequired
            var incident = IncidentRecord(initiatingAction: "Restore Human Control", originalState: stateBeforeRestore)
            incident.steps.append(recoveryWriteFailure("Recovery snapshot could not be loaded; no restore mutation was issued", error: error))
            incident.finalState = .recoveryRequired
            incident.completedAt = Date()
            incident.updatedAt = Date()
            incident.resolution = "Recovery remains required because its snapshot could not be loaded"
            await persist(&incident)
            return incident
        }

        guard recoverySnapshotJournalIsConsistent(snapshot) else {
            operationalState = .recoveryRequired
            var incident = IncidentRecord(initiatingAction: "Restore Human Control", originalState: stateBeforeRestore)
            incident.steps.append(OperationStepResult(
                subsystem: "recovery",
                targetID: "resource-journal",
                targetDisplayName: "Recovery resource journal",
                requestedState: "validated before restoration",
                operationDescription: "Recorded network, sharing, or per-resource progress entries are duplicated or disagree; no restoration mutation was issued",
                outcome: .conflict
            ))
            incident.finalState = .recoveryRequired
            incident.completedAt = Date()
            incident.updatedAt = Date()
            incident.resolution = "Recovery remains required because the stored resource journal is inconsistent"
            await persist(&incident)
            return incident
        }

        operationalState = .restoring
        var incident = IncidentRecord(initiatingAction: "Restore Human Control", originalState: stateBeforeRestore)
        var restoreSteps: [OperationStepResult] = []
        let networkResources = combinedNetworkChanges(in: snapshot)

        if selection.restoreNetwork {
            if networkResources.isEmpty {
                restoreSteps.append(OperationStepResult(subsystem: "recovery", targetID: "empty-resource-set-verified", targetDisplayName: "Recorded recovery resources", requestedState: "restore selected network state", operationDescription: "No network services were recorded for this recovery snapshot; no network mutation was issued", outcome: .alreadyInDesiredState))
            }
            for change in networkResources {
                do {
                    try ensureProgressEntry(in: snapshot, subsystem: .network, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.stateObservationKnown)
                } catch {
                    restoreSteps.append(recoveryWriteFailure("Network recovery entry is missing or inconsistent; restoration skipped", error: error))
                    break
                }
                let identity = networkIdentity(for: change, in: await networkController.inventory())
                guard identity.matches, let current = identity.service else {
                    let step = identityMismatchStep(subsystem: "network", id: change.id, name: change.displayName, identity: identity.description)
                    restoreSteps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Network identity conflict could not be persisted", error: error))
                        break
                    }
                    continue
                }
                guard change.stateObservationKnown, current.enabledObservationKnown else {
                    let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore recorded state", operationDescription: "Current network state is unknown; no restoration mutation was issued", outcome: .conflict)
                    restoreSteps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unverified, identityMatches: true)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Unknown network state could not be persisted", error: error))
                        break
                    }
                    continue
                }

                if change.isVPN {
                    if current.enabled == change.originalEnabled {
                        let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "leave connected as found" : "remain disconnected", observedPreState: current.enabled ? "connected" : "disconnected", observedPostState: current.enabled ? "connected" : "disconnected", operationDescription: "VPN already matches the recorded original state; KeyBrake issued no VPN connection command", outcome: .alreadyInDesiredState)
                        restoreSteps.append(step)
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.enabled, disposition: .restored, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("VPN original state could not be persisted", error: error))
                            break
                        }
                    } else if change.originalEnabled && !current.enabled && selection.retainVPNDisconnected && change.appliedEnabled == false && change.stateObservationKnown {
                        let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "remain disconnected", observedPreState: "disconnected", observedPostState: "disconnected", operationDescription: "VPN remains disconnected by explicit user choice; KeyBrake issued no reconnection command", outcome: .skipped)
                        restoreSteps.append(step)
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: false, disposition: .retained, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("Explicit VPN retention could not be persisted", error: error))
                            break
                        }
                    } else {
                        let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "restore original connection only by explicit system action" : "remain disconnected", observedPreState: current.enabled ? "connected" : "disconnected", observedPostState: current.enabled ? "connected" : "disconnected", operationDescription: change.originalEnabled && !current.enabled ? "VPN is disconnected; explicit confirmation and a verified applied-disconnected state are required to retain it; KeyBrake never reconnects VPNs" : "VPN differs from its recorded state; KeyBrake left it unchanged", outcome: .conflict)
                        restoreSteps.append(step)
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.enabled, disposition: .conflict, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("VPN state conflict could not be persisted", error: error))
                            break
                        }
                    }
                    continue
                }

                if current.enabled == change.originalEnabled {
                    let state = current.enabled ? "enabled" : "disabled"
                    restoreSteps.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: state, observedPreState: state, observedPostState: state, operationDescription: "Network service already matches its recorded original state; no mutation was issued", outcome: .alreadyInDesiredState))
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.enabled, disposition: .restored, identityMatches: true)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Network original state could not be persisted", error: error))
                        break
                    }
                    continue
                }
                guard change.originalEnabled, change.stateObservationKnown, change.appliedEnabled == false else {
                    let step = OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "enabled" : "disabled", observedPreState: "disabled", observedPostState: "disabled", operationDescription: "Recorded applied state is missing or does not match; network restoration skipped", outcome: .conflict)
                    restoreSteps.append(step)
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.enabled, disposition: .conflict, identityMatches: true)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Network applied-state conflict could not be persisted", error: error))
                        break
                    }
                    continue
                }

                let controllerResult = await networkController.restore([change]).first { $0.subsystem == "network" && $0.targetID == change.id }
                    ?? OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", operationDescription: "Network controller returned no restoration result", outcome: .failed)
                restoreSteps.append(controllerResult)
                let postIdentity = networkIdentity(for: change, in: await networkController.inventory())
                let observed = postIdentity.matches && postIdentity.service?.enabledObservationKnown == true ? postIdentity.service?.enabled : nil
                let disposition: RecoveryResourceDisposition = postIdentity.matches
                    ? resourceDisposition(observed: observed, original: change.originalEnabled, result: controllerResult.outcome)
                    : .identityMismatch
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: observed, disposition: disposition, identityMatches: postIdentity.matches, observedIdentity: postIdentity.description)
                } catch {
                    restoreSteps.append(recoveryWriteFailure("Network restoration observation could not be persisted", error: error))
                    break
                }
                if !postIdentity.matches {
                    restoreSteps.append(identityMismatchStep(subsystem: "network", id: change.id, name: change.displayName, identity: postIdentity.description))
                } else if observed != change.originalEnabled {
                    restoreSteps.append(observationFailureStep(subsystem: "network", id: change.id, name: change.displayName, observed: observed, expected: change.originalEnabled))
                }
            }
        }

        if !selection.sharingServiceIDs.isEmpty && !containsRecoveryWriteFailure(restoreSteps) {
            if snapshot.sharingChanges.isEmpty {
                restoreSteps.append(OperationStepResult(subsystem: "recovery", targetID: "empty-resource-set-verified", targetDisplayName: "Recorded recovery resources", requestedState: "restore selected sharing state", operationDescription: "No sharing services were recorded for this recovery snapshot; no sharing mutation was issued", outcome: .alreadyInDesiredState))
            } else {
                for selectedID in selection.sharingServiceIDs.sorted() where !snapshot.sharingChanges.contains(where: { $0.id == selectedID }) {
                    restoreSteps.append(OperationStepResult(subsystem: "sharing", targetID: selectedID, targetDisplayName: selectedID, requestedState: "restore recorded state", operationDescription: "The selected sharing service is not present in this recovery snapshot", outcome: .conflict))
                }
            }
            if let sharingController {
                for change in snapshot.sharingChanges where selection.sharingServiceIDs.contains(change.id) {
                    do {
                        try ensureProgressEntry(in: snapshot, subsystem: .sharing, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.supported)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Sharing recovery entry is missing or inconsistent; restoration skipped", error: error))
                        break
                    }
                    let identity = sharingIdentity(for: change, in: await sharingController.captureChanges())
                    guard identity.matches, let current = identity.change else {
                        restoreSteps.append(identityMismatchStep(subsystem: "sharing", id: change.id, name: change.displayName, identity: identity.description))
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("Sharing identity conflict could not be persisted", error: error))
                            break
                        }
                        continue
                    }
                    guard change.supported, current.supported else {
                        let disposition: RecoveryResourceDisposition = .unsupported
                        let step = OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "restore enabled state" : "remain disabled", operationDescription: "Sharing service is unsupported; KeyBrake issued no mutation", outcome: .unsupported)
                        restoreSteps.append(step)
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: disposition, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("Unsupported sharing state could not be persisted", error: error))
                            break
                        }
                        continue
                    }
                    if current.originalEnabled == change.originalEnabled {
                        let state = current.originalEnabled ? "enabled" : "disabled"
                        restoreSteps.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: state, observedPreState: state, observedPostState: state, operationDescription: "Sharing service already matches its recorded original state; no mutation was issued", outcome: .alreadyInDesiredState))
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.originalEnabled, disposition: .restored, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("Sharing original state could not be persisted", error: error))
                            break
                        }
                        continue
                    }
                    guard change.originalEnabled, change.appliedEnabled == false else {
                        restoreSteps.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: change.originalEnabled ? "enabled" : "disabled", observedPreState: current.originalEnabled ? "enabled" : "disabled", observedPostState: current.originalEnabled ? "enabled" : "disabled", operationDescription: "Recorded applied state is missing or does not match; sharing restoration skipped", outcome: .conflict))
                        do {
                            _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: current.originalEnabled, disposition: .conflict, identityMatches: true)
                        } catch {
                            restoreSteps.append(recoveryWriteFailure("Sharing applied-state conflict could not be persisted", error: error))
                            break
                        }
                        continue
                    }
                    let result = await sharingController.restore([change], selectedIDs: [change.id]).first { $0.subsystem == "sharing" && $0.targetID == change.id }
                        ?? OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "enabled", operationDescription: "Sharing controller returned no restoration result", outcome: .failed)
                    restoreSteps.append(result)
                    let postIdentity = sharingIdentity(for: change, in: await sharingController.captureChanges())
                    let observed = postIdentity.matches && postIdentity.change?.supported == true ? postIdentity.change?.originalEnabled : nil
                    let disposition: RecoveryResourceDisposition = postIdentity.matches
                        ? resourceDisposition(observed: observed, original: change.originalEnabled, result: result.outcome)
                        : .identityMismatch
                    do {
                        _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: observed, disposition: disposition, identityMatches: postIdentity.matches, observedIdentity: postIdentity.description)
                    } catch {
                        restoreSteps.append(recoveryWriteFailure("Sharing restoration observation could not be persisted", error: error))
                        break
                    }
                    if !postIdentity.matches {
                        restoreSteps.append(identityMismatchStep(subsystem: "sharing", id: change.id, name: change.displayName, identity: postIdentity.description))
                    } else if observed != change.originalEnabled {
                        restoreSteps.append(observationFailureStep(subsystem: "sharing", id: change.id, name: change.displayName, observed: observed, expected: change.originalEnabled))
                    }
                }
            } else {
                for change in snapshot.sharingChanges where selection.sharingServiceIDs.contains(change.id) {
                    restoreSteps.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "restore recorded state", operationDescription: "No sharing controller is available for the recorded service", outcome: .unsupported))
                }
            }
        }

        if selection.restartEspanso && !containsRecoveryWriteFailure(restoreSteps) {
            restoreSteps.append(await espanso.start())
        }
        if !containsRecoveryWriteFailure(restoreSteps) {
            let audit = await auditRecoveryResources(in: snapshot)
            snapshot = audit.snapshot
            restoreSteps.append(contentsOf: audit.steps)
        }
        incident.steps.append(contentsOf: restoreSteps)
        snapshot.completedSteps.append(contentsOf: restoreSteps.filter { $0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState || $0.outcome == .skipped })
        snapshot.failedSteps.append(contentsOf: restoreSteps.filter { $0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported })
        snapshot.unresolvedSteps = unresolvedRecoverySteps(in: snapshot, latestSteps: restoreSteps, includePendingResources: true)
        snapshot.updatedAt = Date()

        let originalReturnStateIsValid = snapshot.originalOperationalState == .normal || snapshot.originalOperationalState == .localAutomationStopped
        let resourcesResolved = recoveryResourcesResolved(in: snapshot)
        if !originalReturnStateIsValid {
            incident.steps.append(OperationStepResult(subsystem: "recovery", targetID: "originalOperationalState", targetDisplayName: "Recorded original state", requestedState: "normal or localAutomationStopped", observedPostState: snapshot.originalOperationalState.rawValue, operationDescription: "Snapshot original state is not a valid completed operational state; recovery remains required", outcome: .conflict))
            snapshot.unresolvedSteps.append(incident.steps.last!)
        }
        let fullyResolved = snapshot.unresolvedSteps.isEmpty && resourcesResolved && originalReturnStateIsValid

        do {
            try recoveryStore.save(snapshot)
        } catch {
            incident.steps.append(recoveryWriteFailure("Updated per-resource recovery state could not be persisted", error: error))
            operationalState = .recoveryRequired
            incident.finalState = operationalState
            incident.updatedAt = Date()
            incident.completedAt = Date()
            incident.resolution = "Recovery remains required because its latest observations could not be saved"
            await persist(&incident)
            return incident
        }

        guard fullyResolved else {
            operationalState = .recoveryRequired
            incident.finalState = operationalState
            incident.updatedAt = Date()
            incident.completedAt = Date()
            incident.resolution = "Recovery remains required until every selected resource has a verified final disposition"
            await persist(&incident)
            return incident
        }

        incident.finalState = .recoveryRequired
        incident.updatedAt = Date()
        incident.completedAt = Date()
        incident.resolution = "Recorded resources are verified; the final audit is saved before the recovery journal is cleared"
        do {
            try incidentStore.save(incident)
            latestIncident = incident
        } catch {
            let failure = recoveryWriteFailure("Final audit could not be saved; recovery journal retained", error: error)
            incident.steps.append(failure)
            snapshot.unresolvedSteps = [failure]
            try? recoveryStore.save(snapshot)
            operationalState = .recoveryRequired
            incident.finalState = operationalState
            incident.resolution = "Recovery remains required because the final audit could not be saved"
            await persist(&incident)
            return incident
        }

        do {
            try recoveryStore.clear()
        } catch {
            let failure = recoveryWriteFailure("Recovery journal could not be cleared after the final audit was saved", error: error)
            incident.steps.append(failure)
            snapshot.unresolvedSteps = [failure]
            try? recoveryStore.save(snapshot)
            operationalState = .recoveryRequired
            incident.finalState = operationalState
            incident.updatedAt = Date()
            incident.resolution = "Recovery remains required because the recovery journal could not be cleared"
            await persist(&incident)
            return incident
        }

        operationalState = snapshot.originalOperationalState
        incident.finalState = operationalState
        incident.updatedAt = Date()
        incident.resolution = "Recorded network and sharing states are resolved; remote-access apps remain stopped and KeyBrake never reconnects VPNs"
        do {
            try incidentStore.save(incident)
            latestIncident = incident
        } catch {
            let failure = recoveryWriteFailure("Final completion audit could not be saved after journal clear; recovery journal recreated", error: error)
            incident.steps.append(failure)
            snapshot.unresolvedSteps = [failure]
            try? recoveryStore.save(snapshot)
            operationalState = .recoveryRequired
            incident.finalState = operationalState
            incident.resolution = "Recovery remains required because the completion audit could not be saved"
            await persist(&incident)
        }
        return incident
    }

    private func networkIdentity(for change: NetworkChange, in services: [NetworkService]) -> (matches: Bool, service: NetworkService?, description: String) {
        let matchesByID = services.filter { $0.id == change.id }
        guard matchesByID.count == 1, let service = matchesByID.first else {
            let state = matchesByID.isEmpty ? "missing" : "duplicate-count-\(matchesByID.count)"
            return (false, nil, "\(state):\(change.id)")
        }
        let description = "\(service.id)|\(service.displayName)|\(service.device ?? "<no-device>")|\(service.kind.rawValue)"
        let matches = service.displayName == change.displayName
            && service.device == change.device
            && service.kind.rawValue == change.kind
            && (service.kind == .vpn) == change.isVPN
        return (matches, matches ? service : nil, description)
    }

    private func sharingIdentity(for change: SharingChange, in services: [SharingChange]) -> (matches: Bool, change: SharingChange?, description: String) {
        let matchesByID = services.filter { $0.id == change.id }
        guard matchesByID.count == 1, let service = matchesByID.first else {
            let state = matchesByID.isEmpty ? "missing" : "duplicate-count-\(matchesByID.count)"
            return (false, nil, "\(state):\(change.id)")
        }
        let description = "\(service.id)|\(service.displayName)|supported=\(service.supported)"
        let matches = service.displayName == change.displayName && service.supported == change.supported
        return (matches, matches ? service : nil, description)
    }

    private func recordProgress(
        in snapshot: inout RecoverySnapshot,
        subsystem: RecoveryResourceSubsystem,
        id: String,
        name: String,
        appliedEnabled: Bool?,
        observedEnabled: Bool?,
        disposition: RecoveryResourceDisposition,
        identityMatches: Bool?,
        observedIdentity: String? = nil
    ) throws -> RecoveryResourceProgressUpdateResult {
        let result = try recoveryStore.updateProgress(
            in: &snapshot,
            subsystem: subsystem,
            resourceID: id,
            expectedDisplayName: name,
            appliedEnabled: appliedEnabled,
            observedEnabled: observedEnabled,
            disposition: disposition,
            identityMatches: identityMatches,
            observedIdentity: observedIdentity
        )
        switch result {
        case .notFound:
            throw KeyBrakeStorageError.writeFailed("Recovery progress row is missing for \(subsystem.rawValue):\(id)")
        case .ambiguous:
            throw KeyBrakeStorageError.writeFailed("Recovery progress rows are duplicated for \(subsystem.rawValue):\(id)")
        default:
            return result
        }
    }

    private func ensureProgressEntry(
        in snapshot: RecoverySnapshot,
        subsystem: RecoveryResourceSubsystem,
        id: String,
        name: String,
        originalEnabled: Bool,
        originalStateKnown: Bool
    ) throws {
        let matches = snapshot.resourceProgress.filter { $0.subsystem == subsystem && $0.resourceID == id }
        guard matches.count == 1, let entry = matches.first,
              entry.displayName == name,
              entry.originalEnabled == originalEnabled,
              entry.originalStateKnown == originalStateKnown else {
            throw KeyBrakeStorageError.writeFailed("Recovery progress row is missing, duplicated, or inconsistent for \(subsystem.rawValue):\(id)")
        }
    }

    private func auditRecoveryResources(in source: RecoverySnapshot) async -> (snapshot: RecoverySnapshot, steps: [OperationStepResult]) {
        var snapshot = source
        var steps: [OperationStepResult] = []
        for change in combinedNetworkChanges(in: snapshot) {
            do {
                try ensureProgressEntry(in: snapshot, subsystem: .network, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.stateObservationKnown)
            } catch {
                steps.append(recoveryWriteFailure("Final network audit found a missing or inconsistent progress row", error: error))
                break
            }
            let identity = networkIdentity(for: change, in: await networkController.inventory())
            guard identity.matches, let service = identity.service else {
                steps.append(identityMismatchStep(subsystem: "network", id: change.id, name: change.displayName, identity: identity.description))
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                } catch {
                    steps.append(recoveryWriteFailure("Final network identity observation could not be persisted", error: error))
                    break
                }
                continue
            }
            guard change.stateObservationKnown, service.enabledObservationKnown else {
                steps.append(OperationStepResult(subsystem: "network", targetID: change.id, targetDisplayName: change.displayName, requestedState: "verify recorded state", operationDescription: "Final network state remains unknown; recovery stays pending", outcome: .conflict))
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unverified, identityMatches: true)
                } catch {
                    steps.append(recoveryWriteFailure("Final unknown network observation could not be persisted", error: error))
                    break
                }
                continue
            }
            let prior = snapshot.resourceProgress.first { $0.subsystem == .network && $0.resourceID == change.id }
            let disposition: RecoveryResourceDisposition
            if service.enabled == change.originalEnabled {
                disposition = .restored
            } else if change.isVPN && change.originalEnabled && !service.enabled && prior?.disposition == .retained && prior?.appliedEnabled == false {
                disposition = .retained
            } else if prior?.disposition == .restored || prior?.disposition == .retained {
                disposition = .conflict
            } else if let appliedEnabled = change.appliedEnabled, service.enabled == appliedEnabled {
                disposition = .pending
            } else {
                disposition = .conflict
            }
            do {
                _ = try recordProgress(in: &snapshot, subsystem: .network, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: service.enabled, disposition: disposition, identityMatches: true)
            } catch {
                steps.append(recoveryWriteFailure("Final network observation could not be persisted", error: error))
                break
            }
            if disposition == .conflict {
                steps.append(observationFailureStep(subsystem: "network", id: change.id, name: change.displayName, observed: service.enabled, expected: change.originalEnabled))
            }
        }
        if containsRecoveryWriteFailure(steps) { return (snapshot, steps) }
        guard let sharingController else {
            if !snapshot.sharingChanges.isEmpty {
                steps.append(OperationStepResult(subsystem: "sharing", targetID: "inventory", targetDisplayName: "Sharing services", requestedState: "verify recorded state", operationDescription: "No sharing controller is available for the final recovery audit", outcome: .unsupported))
            }
            return (snapshot, steps)
        }
        for change in snapshot.sharingChanges {
            do {
                try ensureProgressEntry(in: snapshot, subsystem: .sharing, id: change.id, name: change.displayName, originalEnabled: change.originalEnabled, originalStateKnown: change.supported)
            } catch {
                steps.append(recoveryWriteFailure("Final sharing audit found a missing or inconsistent progress row", error: error))
                break
            }
            let identity = sharingIdentity(for: change, in: await sharingController.captureChanges())
            guard identity.matches, let service = identity.change else {
                steps.append(identityMismatchStep(subsystem: "sharing", id: change.id, name: change.displayName, identity: identity.description))
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .identityMismatch, identityMatches: false, observedIdentity: identity.description)
                } catch {
                    steps.append(recoveryWriteFailure("Final sharing identity observation could not be persisted", error: error))
                    break
                }
                continue
            }
            guard change.supported, service.supported else {
                steps.append(OperationStepResult(subsystem: "sharing", targetID: change.id, targetDisplayName: change.displayName, requestedState: "verify recorded state", operationDescription: "Final sharing state is unsupported or unknown; recovery remains pending when the original service was enabled", outcome: .unsupported))
                do {
                    _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: nil, disposition: .unsupported, identityMatches: true)
                } catch {
                    steps.append(recoveryWriteFailure("Final unsupported sharing observation could not be persisted", error: error))
                    break
                }
                continue
            }
            let prior = snapshot.resourceProgress.first { $0.subsystem == .sharing && $0.resourceID == change.id }
            let disposition: RecoveryResourceDisposition
            if service.originalEnabled == change.originalEnabled {
                disposition = .restored
            } else if prior?.disposition == .restored || prior?.disposition == .retained {
                disposition = .conflict
            } else if let appliedEnabled = change.appliedEnabled, service.originalEnabled == appliedEnabled {
                disposition = .pending
            } else {
                disposition = .conflict
            }
            _ = prior
            do {
                _ = try recordProgress(in: &snapshot, subsystem: .sharing, id: change.id, name: change.displayName, appliedEnabled: nil, observedEnabled: service.originalEnabled, disposition: disposition, identityMatches: true)
            } catch {
                steps.append(recoveryWriteFailure("Final sharing observation could not be persisted", error: error))
                break
            }
            if disposition == .conflict {
                steps.append(observationFailureStep(subsystem: "sharing", id: change.id, name: change.displayName, observed: service.originalEnabled, expected: change.originalEnabled))
            }
        }
        return (snapshot, steps)
    }

    private func containsRecoveryWriteFailure(_ steps: [OperationStepResult]) -> Bool {
        steps.contains { $0.subsystem == "recovery" && $0.outcome == .failed }
    }

    private func recoveryDisposition(for outcome: OperationOutcome) -> RecoveryResourceDisposition {
        switch outcome {
        case .succeeded, .alreadyInDesiredState: return .pending
        case .failed: return .failed
        case .unsupported: return .unsupported
        case .conflict: return .conflict
        case .planned, .attempted, .skipped: return .unverified
        }
    }

    private func resourceDisposition(observed: Bool?, original: Bool, result: OperationOutcome) -> RecoveryResourceDisposition {
        guard let observed else { return result == .unsupported ? .unsupported : .unverified }
        if observed == original { return .restored }
        switch result {
        case .unsupported: return .unsupported
        case .conflict: return .conflict
        case .failed: return .failed
        case .planned, .attempted, .skipped, .succeeded, .alreadyInDesiredState: return .unverified
        }
    }

    private func combinedNetworkChanges(in snapshot: RecoverySnapshot) -> [NetworkChange] {
        var combined = snapshot.networkChanges
        let knownIDs = Set(combined.map(\.id))
        combined.append(contentsOf: snapshot.vpnConnections.filter { !knownIDs.contains($0.id) })
        return combined
    }

    private func recoverySnapshotJournalIsConsistent(_ snapshot: RecoverySnapshot) -> Bool {
        let networkIDs = snapshot.networkChanges.map(\.id)
        let vpnIDs = snapshot.vpnConnections.map(\.id)
        let sharingIDs = snapshot.sharingChanges.map(\.id)
        guard Set(networkIDs).count == networkIDs.count,
              Set(vpnIDs).count == vpnIDs.count,
              Set(sharingIDs).count == sharingIDs.count,
              snapshot.vpnConnections.allSatisfy(\.isVPN) else { return false }

        let networkByID = Dictionary(uniqueKeysWithValues: snapshot.networkChanges.map { ($0.id, $0) })
        for vpn in snapshot.vpnConnections {
            guard let network = networkByID[vpn.id] else { continue }
            guard network.isVPN,
                  network.displayName == vpn.displayName,
                  network.device == vpn.device,
                  network.originalEnabled == vpn.originalEnabled,
                  network.kind == vpn.kind,
                  network.stateObservationKnown == vpn.stateObservationKnown else { return false }
        }

        let resources = combinedNetworkChanges(in: snapshot)
        let resourceIDs = resources.map { "network:\($0.id)" } + sharingIDs.map { "sharing:\($0)" }
        let progressIDs = snapshot.resourceProgress.map(\.id)
        guard Set(resourceIDs).count == resourceIDs.count,
              Set(progressIDs).count == progressIDs.count,
              Set(progressIDs) == Set(resourceIDs) else { return false }

        let progressByID = Dictionary(uniqueKeysWithValues: snapshot.resourceProgress.map { ($0.id, $0) })
        for change in resources {
            guard let progress = progressByID["network:\(change.id)"],
                  progress.displayName == change.displayName,
                  progress.originalEnabled == change.originalEnabled,
                  progress.originalStateKnown == change.stateObservationKnown else { return false }
        }
        for change in snapshot.sharingChanges {
            guard let progress = progressByID["sharing:\(change.id)"],
                  progress.displayName == change.displayName,
                  progress.originalEnabled == change.originalEnabled,
                  progress.originalStateKnown == change.supported else { return false }
        }
        return true
    }

    private func recoveryResourcesResolved(in snapshot: RecoverySnapshot) -> Bool {
        guard recoverySnapshotJournalIsConsistent(snapshot) else { return false }
        let network = combinedNetworkChanges(in: snapshot)
        let keys = network.map { "network:\($0.id)" } + snapshot.sharingChanges.map { "sharing:\($0.id)" }
        guard Set(keys).count == keys.count else { return false }
        let progressKeys = snapshot.resourceProgress.map(\.id)
        guard Set(progressKeys).count == progressKeys.count, Set(progressKeys) == Set(keys) else {
            if keys.isEmpty {
                return snapshot.completedSteps.contains { $0.targetID == "empty-resource-set-verified" && $0.outcome == .alreadyInDesiredState }
            }
            return false
        }
        if keys.isEmpty {
            return snapshot.completedSteps.contains { $0.targetID == "empty-resource-set-verified" && $0.outcome == .alreadyInDesiredState }
        }
        let progress = Dictionary(uniqueKeysWithValues: snapshot.resourceProgress.map { ($0.id, $0) })
        for change in network {
            guard let entry = progress["network:\(change.id)"], entry.displayName == change.displayName,
                  entry.originalEnabled == change.originalEnabled, entry.originalStateKnown == change.stateObservationKnown else { return false }
            switch entry.disposition {
            case .restored:
                guard entry.identityMatches == true, entry.originalStateKnown, entry.observedEnabled == entry.originalEnabled else { return false }
            case .retained:
                guard change.isVPN, entry.identityMatches == true, entry.originalStateKnown, entry.originalEnabled,
                      entry.appliedEnabled == false, entry.observedEnabled == false else { return false }
            default:
                return false
            }
        }
        for change in snapshot.sharingChanges {
            guard let entry = progress["sharing:\(change.id)"], entry.displayName == change.displayName,
                  entry.originalEnabled == change.originalEnabled else { return false }
            if !change.supported && !change.originalEnabled && entry.disposition == .unsupported {
                guard entry.identityMatches == true, entry.observedEnabled == nil else { return false }
                continue
            }
            guard entry.disposition == .restored, entry.identityMatches == true, entry.originalStateKnown,
                  entry.observedEnabled == entry.originalEnabled else { return false }
        }
        return true
    }

    private func unresolvedRecoverySteps(
        in snapshot: RecoverySnapshot,
        latestSteps: [OperationStepResult],
        includePendingResources: Bool
    ) -> [OperationStepResult] {
        let resources = Dictionary(grouping: snapshot.resourceProgress, by: \.id)
        let resourceIDs = Set(resources.keys)
        let resolvedNonResourceKeys = Set(latestSteps.filter {
            $0.subsystem != "network" && $0.subsystem != "sharing"
                && ($0.outcome == .succeeded || $0.outcome == .alreadyInDesiredState)
        }.map { "\($0.subsystem):\($0.targetID)" })
        var unresolved = snapshot.unresolvedSteps.filter { step in
            if step.subsystem == "network" || step.subsystem == "sharing" {
                return !resourceIDs.contains("\(step.subsystem):\(step.targetID)")
            }
            return !resolvedNonResourceKeys.contains("\(step.subsystem):\(step.targetID)")
        }
        unresolved.append(contentsOf: latestSteps.filter {
            ($0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported)
                && $0.subsystem != "network" && $0.subsystem != "sharing"
        })
        let knownResources = Set(combinedNetworkChanges(in: snapshot).map { "network:\($0.id)" } + snapshot.sharingChanges.map { "sharing:\($0.id)" })
        unresolved.append(contentsOf: latestSteps.filter {
            ($0.outcome == .failed || $0.outcome == .conflict || $0.outcome == .unsupported)
                && ($0.subsystem == "network" || $0.subsystem == "sharing")
                && !knownResources.contains("\($0.subsystem):\($0.targetID)")
        })
        for entry in snapshot.resourceProgress {
            let isUnresolved: Bool
            switch entry.disposition {
            case .restored, .retained:
                isUnresolved = false
            case .unsupported where entry.subsystem == .sharing && !entry.originalEnabled:
                isUnresolved = false
            case .pending:
                isUnresolved = includePendingResources
            case .unsupported, .failed, .conflict, .unverified, .identityMismatch:
                isUnresolved = true
            }
            guard isUnresolved else { continue }
            let outcome: OperationOutcome
            switch entry.disposition {
            case .unsupported: outcome = .unsupported
            case .conflict, .identityMismatch: outcome = .conflict
            default: outcome = .failed
            }
            unresolved.append(OperationStepResult(
                subsystem: entry.subsystem.rawValue,
                targetID: entry.resourceID,
                targetDisplayName: entry.displayName,
                requestedState: entry.disposition == .pending ? "restore pending" : "resolve recorded state",
                observedPostState: entry.observedEnabled.map { $0 ? "enabled" : "disabled" },
                operationDescription: "Recovery disposition is \(entry.disposition.rawValue); current identity and state must be verified before the journal can clear",
                outcome: outcome
            ))
        }
        var seen = Set<String>()
        return unresolved.filter { seen.insert("\($0.subsystem):\($0.targetID):\($0.outcome.rawValue)").inserted }
    }

    private func identityMismatchStep(subsystem: String, id: String, name: String, identity: String) -> OperationStepResult {
        OperationStepResult(subsystem: subsystem, targetID: id, targetDisplayName: name, requestedState: "preserve recorded state", observedPostState: identity, operationDescription: "Current resource identity is missing, duplicated, or changed; no state was transferred to another resource", outcome: .conflict)
    }

    private func observationFailureStep(subsystem: String, id: String, name: String, observed: Bool?, expected: Bool) -> OperationStepResult {
        let state = observed.map { $0 ? "enabled" : "disabled" } ?? "unknown"
        return OperationStepResult(subsystem: subsystem, targetID: id, targetDisplayName: name, requestedState: expected ? "enabled" : "disabled", observedPostState: state, operationDescription: "Resource identity remained stable, but its verified final state did not match the requested state", outcome: .failed)
    }

    private func recoveryWriteFailure(_ description: String, error: Error) -> OperationStepResult {
        OperationStepResult(subsystem: "recovery", targetID: "CurrentRecovery.json", targetDisplayName: "Recovery snapshot", requestedState: "persist verified state", operationDescription: description, outcome: .failed, sanitizedStandardError: error.localizedDescription)
    }

    public func restartEspanso() async -> OperationStepResult {
        guard let mutationID = beginMutation() else {
            return OperationStepResult(subsystem: "coordinator", targetID: "espanso", targetDisplayName: "Espanso", requestedState: "restarted", operationDescription: "Another KeyBrake state-changing operation is still in flight", outcome: .conflict)
        }
        defer { endMutation(mutationID) }
        return await espanso.restart()
    }

    private func beginMutation() -> UUID? {
        guard activeMutationID == nil else { return nil }
        let mutationID = UUID()
        activeMutationID = mutationID
        return mutationID
    }

    private func endMutation(_ mutationID: UUID) {
        guard activeMutationID == mutationID else { return }
        activeMutationID = nil
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
            steps.append(contentsOf: await performVerifiedLaunchdStops(for: target))
        }
        return steps
    }

    private func performVerifiedLaunchdStops(for target: TargetDefinition) async -> [OperationStepResult] {
        let labels: [(domain: String, label: String)] =
            target.verifiedLaunchAgentLabels.sorted().map { ("gui", $0) }
            + target.verifiedLaunchDaemonLabels.sorted().map { ("system", $0) }
        guard !labels.isEmpty else { return [] }
        return await withTaskGroup(of: OperationStepResult.self, returning: [OperationStepResult].self) { group in
            for (domain, label) in labels {
                group.addTask {
                    let targetID = "\(target.id):\(domain)/\(label)"
                    guard let executablePath = target.executableURL?.path, !executablePath.isEmpty else {
                        return OperationStepResult(
                            subsystem: "launchd",
                            targetID: targetID,
                            targetDisplayName: target.displayName,
                            requestedState: "stopped",
                            operationDescription: "Verified launchd stop skipped because the target executable path is missing",
                            outcome: .unsupported
                        )
                    }
                    let helperStep = await self.helper.perform(.stopVerifiedLaunchdService(
                        domain: domain,
                        label: label,
                        expectedProgramPath: executablePath,
                        expectedSigningRequirement: target.codeSigningDesignatedRequirement
                    ))
                    return OperationStepResult(
                        subsystem: "launchd",
                        targetID: targetID,
                        targetDisplayName: target.displayName,
                        requestedState: "stopped",
                        observedPreState: helperStep.observedPreState,
                        observedPostState: helperStep.observedPostState,
                        operationDescription: helperStep.operationDescription,
                        outcome: helperStep.outcome,
                        terminationStatus: helperStep.terminationStatus,
                        sanitizedStandardError: helperStep.sanitizedStandardError,
                        startedAt: helperStep.startedAt,
                        finishedAt: helperStep.finishedAt
                    )
                }
            }
            var results: [OperationStepResult] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.targetID < $1.targetID }
        }
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
