import Foundation
import AppKit
import KeyBrakeCore
import ServiceManagement
import SwiftUI

@MainActor
final class KeyBrakeViewModel: ObservableObject {
    @Published private(set) var operationalState: KeyBrakeOperationalState = .normal
    @Published private(set) var latestIncident: IncidentRecord?
    @Published private(set) var unresolvedRecovery: RecoverySnapshot?
    @Published private(set) var incidents: [IncidentRecord] = []
    @Published private(set) var configuredTargets: [TargetDefinition]
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginError: String?
    @Published var isShowingRecoveryPanel = false
    @Published var isShowingIncidentLog = false
    @Published var isShowingSettings = false

    let coordinator: EmergencyCoordinator
    let incidentStore: IncidentStore

    private static let configuredTargetsDefaultsKey = "KeyBrake.configuredTargets.v1"

    init(coordinator: EmergencyCoordinator = .live(), incidentStore: IncidentStore = IncidentStore()) {
        self.coordinator = coordinator
        self.incidentStore = incidentStore
        self.configuredTargets = Self.loadConfiguredTargets()
        self.launchAtLoginEnabled = Self.readLaunchAtLoginStatus()
        Task {
            await coordinator.replaceTargetDefinitions(self.configuredTargets)
            await refresh()
        }
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

    func setTargetApproval(targetID: String, approved: Bool) {
        guard let index = configuredTargets.firstIndex(where: { $0.id == targetID }) else { return }
        configuredTargets[index].approvedByUser = approved
        configuredTargets[index].updatedAt = Date()
        saveConfiguredTargets()
        Task { await coordinator.setTargetApproval(targetID: targetID, approved: approved) }
    }

    func enrollTarget(_ target: TargetDefinition) {
        guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: target.bundleIdentifier, executableURL: target.executableURL), !configuredTargets.contains(where: { $0.id == target.id }) else { return }
        configuredTargets.append(target)
        saveConfiguredTargets()
        Task { await coordinator.replaceTargetDefinitions(configuredTargets) }
    }

    func removeTarget(targetID: String) {
        let builtInIDs = Set(TargetRegistry.builtInLocalAutomation.map(\.id) + TargetRegistry.builtInRemoteAccess.map(\.id))
        guard !builtInIDs.contains(targetID) else { return }
        configuredTargets.removeAll { $0.id == targetID }
        saveConfiguredTargets()
        Task { await coordinator.replaceTargetDefinitions(configuredTargets) }
    }

    func revokeAppAccess(targetID: String, services: Set<TCCService>) {
        guard let target = configuredTargets.first(where: { $0.id == targetID }), let bundleIdentifier = target.bundleIdentifier else { return }
        Task {
            let incident = await coordinator.revokeAppAccess(targetID: targetID, services: services, bundleIdentifier: bundleIdentifier, displayName: target.displayName)
            await apply(incident: incident)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            launchAtLoginError = "Launch at Login requires macOS 13 or later."
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginEnabled = Self.readLaunchAtLoginStatus()
            launchAtLoginError = error.localizedDescription
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

    private func saveConfiguredTargets() {
        guard let data = try? JSONEncoder().encode(configuredTargets) else { return }
        UserDefaults.standard.set(data, forKey: Self.configuredTargetsDefaultsKey)
    }

    private static func loadConfiguredTargets() -> [TargetDefinition] {
        let builtIns = TargetRegistry.builtInLocalAutomation + TargetRegistry.builtInRemoteAccess
        guard let data = UserDefaults.standard.data(forKey: configuredTargetsDefaultsKey), let stored = try? JSONDecoder().decode([TargetDefinition].self, from: data) else {
            return builtIns
        }
        let storedByID = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        var merged = builtIns.map { builtIn in
            guard let saved = storedByID[builtIn.id] else { return builtIn }
            var result = builtIn
            result.approvedByUser = saved.approvedByUser
            result.enabledForEmergencyStop = saved.enabledForEmergencyStop
            result.approvedPrivacyServices = saved.approvedPrivacyServices
            result.updatedAt = saved.updatedAt
            return result
        }
        let builtInIDs = Set(builtIns.map(\.id))
        merged.append(contentsOf: stored.filter { !builtInIDs.contains($0.id) })
        return merged
    }

    private static func readLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
