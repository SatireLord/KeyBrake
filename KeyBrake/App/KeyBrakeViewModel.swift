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
    @Published private(set) var privilegedHelperStatus = "Not registered"
    @Published private(set) var privilegedHelperError: String?
    @Published var isolationPolicy: EmergencyIsolationPolicy
    @Published var isShowingRecoveryPanel = false
    @Published var isShowingIncidentLog = false
    @Published var isShowingSettings = false
    private var allowImmediateQuit = false

    let coordinator: EmergencyCoordinator
    let incidentStore: IncidentStore

    private static let configuredTargetsDefaultsKey = "KeyBrake.configuredTargets.v1"
    private static let isolationPolicyDefaultsKey = "KeyBrake.isolationPolicy.v1"

    init(coordinator: EmergencyCoordinator = .live(), incidentStore: IncidentStore = IncidentStore()) {
        self.coordinator = coordinator
        self.incidentStore = incidentStore
        self.configuredTargets = Self.loadConfiguredTargets()
        self.isolationPolicy = Self.loadIsolationPolicy()
        self.launchAtLoginEnabled = Self.readLaunchAtLoginStatus()
        self.privilegedHelperStatus = Self.readPrivilegedHelperStatus()
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
        if unresolvedRecovery != nil || [.isolated, .partiallyIsolated, .recoveryRequired].contains(operationalState) {
            isShowingRecoveryPanel = true
        }
    }

    func stopSkynetLocally() {
        guard !isBusy else { return }
        operationalState = .stoppingLocalAutomation
        Task {
            let incident = await coordinator.stopSkynetLocally()
            await apply(incident: incident)
        }
    }

    func stopRemoteAccess() {
        guard !isBusy else { return }
        operationalState = .isolating
        Task {
            let incident = await coordinator.stopRemoteAccess(policy: isolationPolicy)
            await apply(incident: incident)
            await MainActor.run { self.isShowingRecoveryPanel = true }
        }
    }

    func restoreHumanControl(restoreSharing: Bool = false) {
        guard !isBusy else { return }
        operationalState = .restoring
        Task {
            let selection = RecoverySelection(restoreNetwork: !restoreSharing, sharingServiceIDs: restoreSharing ? ["remote-login", "remote-apple-events"] : [], restartEspanso: false)
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func keepIsolation() {
        isShowingRecoveryPanel = false
    }

    var shouldAllowImmediateQuit: Bool { allowImmediateQuit }

    func requestQuit() {
        if allowImmediateQuit || !hasRecovery {
            NSApplication.shared.terminate(nil)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Recovery is still required"
        alert.informativeText = "KeyBrake changed system state that has not been fully resolved. Choose a mouse-operated action."
        alert.addButton(withTitle: "Restore Network")
        alert.addButton(withTitle: "Keep Isolation and Quit")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            restoreHumanControl()
        case .alertSecondButtonReturn:
            allowImmediateQuit = true
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }

    func restoreNetworkOnly() {
        guard !isBusy else { return }
        operationalState = .restoring
        Task {
            let selection = RecoverySelection(restoreNetwork: true, sharingServiceIDs: [], restartEspanso: false)
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func restoreSharingOnly() {
        guard !isBusy else { return }
        operationalState = .restoring
        Task {
            let selection = RecoverySelection(restoreNetwork: false, sharingServiceIDs: ["remote-login", "remote-apple-events"], restartEspanso: false)
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func restartEspanso() {
        guard !isBusy else { return }
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

    func updateIsolationPolicy(_ policy: EmergencyIsolationPolicy) {
        isolationPolicy = policy
        guard let data = try? JSONEncoder().encode(policy) else { return }
        UserDefaults.standard.set(data, forKey: Self.isolationPolicyDefaultsKey)
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

    func registerPrivilegedHelper() {
        guard #available(macOS 13.0, *) else {
            privilegedHelperError = "Privileged helper registration requires macOS 13 or later."
            return
        }
        do {
            try SMAppService.daemon(plistName: HelperDaemonRegistration.plistName).register()
            privilegedHelperStatus = Self.readPrivilegedHelperStatus()
            privilegedHelperError = nil
        } catch {
            privilegedHelperStatus = Self.readPrivilegedHelperStatus()
            privilegedHelperError = error.localizedDescription
        }
    }

    func refreshPrivilegedHelperStatus() {
        privilegedHelperStatus = Self.readPrivilegedHelperStatus()
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
        let recovery = await coordinator.recoverySnapshot()
        await MainActor.run {
            self.latestIncident = incident
            self.operationalState = incident.finalState
            self.incidents = (try? self.incidentStore.list()) ?? []
            self.unresolvedRecovery = recovery
        }
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

    private static func loadIsolationPolicy() -> EmergencyIsolationPolicy {
        guard let data = UserDefaults.standard.data(forKey: isolationPolicyDefaultsKey),
              let policy = try? JSONDecoder().decode(EmergencyIsolationPolicy.self, from: data) else {
            return .standard
        }
        return policy
    }

    private static func readLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private static func readPrivilegedHelperStatus() -> String {
        if #available(macOS 13.0, *) {
            switch SMAppService.daemon(plistName: HelperDaemonRegistration.plistName).status {
            case .enabled: return "Enabled"
            case .requiresApproval: return "Approval required"
            case .notRegistered: return "Not registered"
            case .notFound: return "Not found in app bundle"
            @unknown default: return "Unknown"
            }
        }
        return "Requires macOS 13+"
    }
}
