import Foundation
import AppKit
import KeyBrakeCore
import SwiftUI

@MainActor
final class KeyBrakeViewModel: ObservableObject {
    @Published private(set) var operationalState: KeyBrakeOperationalState = .normal
    @Published private(set) var latestIncident: IncidentRecord?
    @Published private(set) var unresolvedRecovery: RecoverySnapshot?
    @Published private(set) var incidents: [IncidentRecord] = []
    @Published var isShowingRecoveryPanel = false
    @Published var isShowingIncidentLog = false
    @Published var isShowingSettings = false

    let coordinator: EmergencyCoordinator
    let incidentStore: IncidentStore

    init(coordinator: EmergencyCoordinator = .live(), incidentStore: IncidentStore = IncidentStore()) {
        self.coordinator = coordinator
        self.incidentStore = incidentStore
        Task { await refresh() }
    }

    var isBusy: Bool {
        [.stoppingLocalAutomation, .isolating, .restoring].contains(operationalState)
    }

    var hasRecovery: Bool {
        unresolvedRecovery != nil || [.isolated, .partiallyIsolated, .recoveryRequired].contains(operationalState)
    }

    func refresh() async {
        unresolvedRecovery = await coordinator.recoverUnresolvedStateAtLaunch()
        operationalState = await coordinator.state()
        latestIncident = await coordinator.latest()
        incidents = (try? incidentStore.list()) ?? []
        if unresolvedRecovery != nil { isShowingRecoveryPanel = true }
    }

    func stopSkynetLocally() {
        Task {
            let incident = await coordinator.stopSkynetLocally()
            await apply(incident: incident)
        }
    }

    func stopRemoteAccess() {
        Task {
            let incident = await coordinator.stopRemoteAccess()
            await apply(incident: incident)
            await MainActor.run { self.isShowingRecoveryPanel = true }
        }
    }

    func restoreHumanControl(restoreSharing: Bool = false) {
        Task {
            let selection = RecoverySelection(restoreNetwork: true, sharingServiceIDs: restoreSharing ? ["remote-login", "remote-apple-events"] : [])
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func restartEspanso() {
        Task {
            let step = await coordinator.restartEspanso()
            let incident = IncidentRecord(initiatingAction: "Restart Espanso", originalState: operationalState, finalState: operationalState, steps: [step], resolution: step.outcome == .succeeded ? "Espanso restart verified" : "Espanso restart requires review")
            try? incidentStore.save(incident)
            await refresh()
        }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else { return }
        NSWorkspace.shared.open(url)
    }

    func clearResolvedHistory() {
        try? incidentStore.clearResolvedHistory()
        incidents = (try? incidentStore.list()) ?? []
    }

    private func apply(incident: IncidentRecord) async {
        await MainActor.run {
            self.latestIncident = incident
            self.operationalState = incident.finalState
            self.incidents = (try? self.incidentStore.list()) ?? []
            self.unresolvedRecovery = (try? self.coordinatorRecovery())
        }
    }

    private func coordinatorRecovery() throws -> RecoverySnapshot? {
        try RecoveryStore().load()
    }
}
