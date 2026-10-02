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
    @Published private(set) var operationInFlight = false
    @Published private(set) var recoveryStoreHydrationSucceeded = false
    @Published var isolationPolicy: EmergencyIsolationPolicy
    @Published var isShowingRecoveryPanel = false
    @Published var isShowingIncidentLog = false
    @Published var isShowingSettings = false
    @Published private(set) var keyboardSettingsNavigationRequest: UUID?
    private var allowImmediateQuit = false
    private var launchRecoveryCheckCompleted = false

    let coordinator: EmergencyCoordinator
    let incidentStore: IncidentStore
    let featureContract: FeatureContract
    private let settingsDefaults: UserDefaults
    let isNetworkSandbox: Bool
    let isRecoveryDemo: Bool
    let networkSandboxScenario: NetworkSandboxScenario?
    private let demoStoreRootDirectory: URL?

    static let configuredTargetsDefaultsKey = "KeyBrake.configuredTargets.v1"
    static let isolationPolicyDefaultsKey = "KeyBrake.isolationPolicy.v1"

    init(
        coordinator: EmergencyCoordinator = .live(),
        incidentStore: IncidentStore = IncidentStore(),
        initialIsolationPolicy: EmergencyIsolationPolicy? = nil,
        networkSandboxScenario: NetworkSandboxScenario? = nil,
        isNetworkSandbox: Bool = false,
        isRecoveryDemo: Bool = false,
        configuredTargetsOverride: [TargetDefinition]? = nil,
        demoStoreRootDirectory: URL? = nil,
        settingsDefaults: UserDefaults = .standard
    ) {
        self.coordinator = coordinator
        self.incidentStore = incidentStore
        self.featureContract = FeatureContract.current()
        self.settingsDefaults = settingsDefaults
        self.isNetworkSandbox = isNetworkSandbox
        self.isRecoveryDemo = isRecoveryDemo
        self.demoStoreRootDirectory = (isNetworkSandbox || isRecoveryDemo) ? demoStoreRootDirectory : nil
        self.networkSandboxScenario = isNetworkSandbox ? networkSandboxScenario : nil
        let isReadOnlyDemo = isNetworkSandbox || isRecoveryDemo
        self.configuredTargets = configuredTargetsOverride ?? (isReadOnlyDemo ? TargetRegistry.builtInRemoteAccess : Self.loadConfiguredTargets(from: settingsDefaults))
        self.isolationPolicy = initialIsolationPolicy ?? (isReadOnlyDemo ? .standard : Self.loadIsolationPolicy(from: settingsDefaults))
        self.launchAtLoginEnabled = isReadOnlyDemo ? false : Self.readLaunchAtLoginStatus()
        self.privilegedHelperStatus = isReadOnlyDemo ? "Disabled in demo mode" : Self.readPrivilegedHelperStatus()
        Task {
            await coordinator.replaceTargetDefinitions(self.configuredTargets)
            await refresh()
        }
    }

    var isBusy: Bool {
        operationalState.isStateChanging || operationInFlight
    }

    var isReadOnlyDemo: Bool {
        isNetworkSandbox || isRecoveryDemo
    }

    var isRecoveryStatusKnown: Bool {
        launchRecoveryCheckCompleted
    }

    var hasVerifiedRecoveryStoreHydration: Bool {
        recoveryStoreHydrationSucceeded
    }

    var canRequestPrivacyReset: Bool {
        !isReadOnlyDemo && launchRecoveryCheckCompleted && recoveryStoreHydrationSucceeded && !isBusy
    }

    var hasRecovery: Bool {
        unresolvedRecovery != nil || operationalState.requiresRecoveryDecision
    }

    var shouldInterceptTermination: Bool {
        operationInFlight || KeyBrakeTerminationGate.blocksTermination(
            state: operationalState,
            launchRecoveryCheckCompleted: launchRecoveryCheckCompleted,
            recoveryRequired: hasRecovery,
            immediateQuitApproved: allowImmediateQuit
        )
    }

    func refresh() async {
        launchRecoveryCheckCompleted = false
        recoveryStoreHydrationSucceeded = false
        let recovery = await coordinator.recoverUnresolvedStateAtLaunch()
        let hydrationSucceeded = await coordinator.hasVerifiedRecoveryStoreHydration()
        let state = await coordinator.state()
        let storedIncidents = (try? incidentStore.list()) ?? []
        let incident = await coordinator.latest() ?? storedIncidents.first
        unresolvedRecovery = recovery
        operationalState = state
        recoveryStoreHydrationSucceeded = hydrationSucceeded
        latestIncident = incident
        incidents = storedIncidents
        launchRecoveryCheckCompleted = true
        if hasRecovery {
            isShowingRecoveryPanel = true
        }
    }

    func stopSkynetLocally() {
        guard !isBusy else { return }
        operationInFlight = true
        operationalState = .stoppingLocalAutomation
        Task {
            defer { operationInFlight = false }
            let incident = await coordinator.stopSkynetLocally()
            await apply(incident: incident)
        }
    }

    func stopRemoteAccess() {
        guard !isBusy else { return }
        operationInFlight = true
        operationalState = .isolating
        Task {
            defer { operationInFlight = false }
            let incident = await coordinator.stopRemoteAccess(policy: isolationPolicy)
            await apply(incident: incident)
            await MainActor.run { self.isShowingRecoveryPanel = true }
        }
    }

    func restoreHumanControl(restoreSharing: Bool = false) {
        guard !isBusy else { return }
        let retainVPNDisconnected = !restoreSharing && confirmVPNRemainsDisconnectedIfNeeded()
        guard restoreSharing || !hasPreviouslyConnectedVPN || retainVPNDisconnected else { return }
        operationInFlight = true
        operationalState = .restoring
        Task {
            defer { operationInFlight = false }
            let selection = RecoverySelection(
                restoreNetwork: !restoreSharing,
                sharingServiceIDs: restoreSharing ? ["remote-login", "remote-apple-events"] : [],
                restartEspanso: false,
                retainVPNDisconnected: retainVPNDisconnected
            )
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func keepIsolation() {
        isShowingRecoveryPanel = false
    }

    func openIncidentLog() {
        isShowingIncidentLog = true
    }

    func openSettings() {
        isShowingSettings = true
    }

    func openKeyboardSettingsFromSystemSettings() {
        keyboardSettingsNavigationRequest = UUID()
    }

    func requestQuit() {
        guard launchRecoveryCheckCompleted else {
            showTerminationBlockedAlert(
                messageText: "Recovery status is still loading",
                informativeText: "KeyBrake cannot quit until it confirms whether unresolved recovery exists."
            )
            return
        }
        guard !isBusy else {
            showTerminationBlockedAlert(
                messageText: "KeyBrake is completing an emergency action",
                informativeText: "Quit is unavailable until the current state-changing operation finishes."
            )
            return
        }
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

    private func showTerminationBlockedAlert(messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private var hasPreviouslyConnectedVPN: Bool {
        guard let unresolvedRecovery else { return false }
        let network = unresolvedRecovery.networkChanges + unresolvedRecovery.vpnConnections.filter { vpn in
            !unresolvedRecovery.networkChanges.contains(where: { $0.id == vpn.id })
        }
        return network.contains(where: { $0.isVPN && $0.originalEnabled })
    }

    private func confirmVPNRemainsDisconnectedIfNeeded() -> Bool {
        guard hasPreviouslyConnectedVPN else { return false }
        let alert = NSAlert()
        alert.messageText = "Restore the network and leave VPNs as-is?"
        alert.informativeText = "KeyBrake will not connect or disconnect a VPN during restoration. A VPN already reconnected by you stays connected; a VPN still disconnected by KeyBrake stays disconnected only when macOS confirms that state."
        alert.addButton(withTitle: "Restore Network, Leave VPN As-Is")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func restoreNetworkOnly() {
        guard !isBusy else { return }
        let retainVPNDisconnected = confirmVPNRemainsDisconnectedIfNeeded()
        guard !hasPreviouslyConnectedVPN || retainVPNDisconnected else { return }
        operationInFlight = true
        operationalState = .restoring
        Task {
            defer { operationInFlight = false }
            let selection = RecoverySelection(
                restoreNetwork: true,
                sharingServiceIDs: [],
                restartEspanso: false,
                retainVPNDisconnected: retainVPNDisconnected
            )
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func restoreSharingOnly() {
        guard !isBusy else { return }
        operationInFlight = true
        operationalState = .restoring
        Task {
            defer { operationInFlight = false }
            let selection = RecoverySelection(restoreNetwork: false, sharingServiceIDs: ["remote-login", "remote-apple-events"], restartEspanso: false)
            let incident = await coordinator.restoreHumanControl(selection: selection)
            await apply(incident: incident)
        }
    }

    func restartEspanso() {
        guard !isBusy else { return }
        operationInFlight = true
        Task {
            defer { operationInFlight = false }
            let step = await coordinator.restartEspanso()
            let incident = IncidentRecord(initiatingAction: "Restart Espanso", originalState: operationalState, finalState: operationalState, steps: [step], resolution: step.outcome == .succeeded ? "Espanso restart verified" : "Espanso restart requires review")
            try? incidentStore.save(incident)
            await refresh()
        }
    }

    func setTargetApproval(targetID: String, approved: Bool) {
        guard !isReadOnlyDemo else { return }
        guard let index = configuredTargets.firstIndex(where: { $0.id == targetID }) else { return }
        configuredTargets[index].approvedByUser = approved
        configuredTargets[index].updatedAt = Date()
        saveConfiguredTargets()
        Task { await coordinator.setTargetApproval(targetID: targetID, approved: approved) }
    }

    func updateIsolationPolicy(_ policy: EmergencyIsolationPolicy) {
        guard !isReadOnlyDemo else { return }
        isolationPolicy = policy
        guard let data = try? JSONEncoder().encode(policy) else { return }
        settingsDefaults.set(data, forKey: Self.isolationPolicyDefaultsKey)
    }

    func enrollTarget(_ target: TargetDefinition) {
        guard !isReadOnlyDemo else { return }
        guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: target.bundleIdentifier, executableURL: target.executableURL), !configuredTargets.contains(where: { $0.id == target.id }) else { return }
        configuredTargets.append(target)
        saveConfiguredTargets()
        Task { await coordinator.replaceTargetDefinitions(configuredTargets) }
    }

    func removeTarget(targetID: String) {
        guard !isReadOnlyDemo else { return }
        let builtInIDs = Set(TargetRegistry.builtInLocalAutomation.map(\.id) + TargetRegistry.builtInRemoteAccess.map(\.id))
        guard !builtInIDs.contains(targetID) else { return }
        configuredTargets.removeAll { $0.id == targetID }
        saveConfiguredTargets()
        Task { await coordinator.replaceTargetDefinitions(configuredTargets) }
    }

    func revokeAppAccess(targetID: String, services: Set<TCCService>) {
        guard canRequestPrivacyReset else { return }
        guard let target = configuredTargets.first(where: { $0.id == targetID }), let bundleIdentifier = target.bundleIdentifier else { return }
        operationInFlight = true
        Task {
            defer { operationInFlight = false }
            await coordinator.replaceTargetDefinitions(configuredTargets)
            let incident = await coordinator.revokeAppAccess(targetID: targetID, services: services, bundleIdentifier: bundleIdentifier, displayName: target.displayName)
            await apply(incident: incident)
        }
    }

    func resetKeyboardAccess(targetID: String) {
        guard canRequestPrivacyReset else { return }
        guard let selectedTarget = configuredTargets.first(where: { $0.id == targetID }) else { return }
        let currentTargets = Self.loadConfiguredTargets(from: settingsDefaults)
        guard let target = currentTargets.first(where: { $0.id == targetID }),
              target.bundleIdentifier == selectedTarget.bundleIdentifier,
              target.applicationURL == selectedTarget.applicationURL,
              target.executableURL == selectedTarget.executableURL,
              let bundleIdentifier = target.bundleIdentifier,
              TargetRegistry.canEnroll(target, applicationBundleIdentifier: bundleIdentifier, executableURL: target.executableURL) else { return }
        configuredTargets = currentTargets
        operationInFlight = true
        Task {
            defer { operationInFlight = false }
            await coordinator.replaceTargetDefinitions(currentTargets)
            let incident = await coordinator.resetKeyboardAccess(target: target)
            await apply(incident: incident)
        }
    }

    func registerPrivilegedHelper() {
        guard !isReadOnlyDemo else { return }
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
        guard !isReadOnlyDemo else { return }
        privilegedHelperStatus = Self.readPrivilegedHelperStatus()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isReadOnlyDemo else { return }
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
        guard !isReadOnlyDemo else { return }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else { return }
        NSWorkspace.shared.open(url)
    }

    func clearResolvedHistory() {
        try? incidentStore.clearResolvedHistory()
        incidents = (try? incidentStore.list()) ?? []
    }

    func cleanupDemoStore() {
        guard let root = demoStoreRootDirectory else { return }
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        let normalizedRoot = root.standardizedFileURL
        let directoryName = normalizedRoot.lastPathComponent
        let belongsToRecoveryDemo = isRecoveryDemo && directoryName.hasPrefix("KeyBrake-Recovery-Demo-")
        let belongsToNetworkSandbox = isNetworkSandbox
            && networkSandboxScenario.map { directoryName.hasPrefix("KeyBrake-Network-Sandbox-\($0.rawValue)-") } == true
        guard normalizedRoot.deletingLastPathComponent() == temporaryRoot,
              belongsToRecoveryDemo || belongsToNetworkSandbox else { return }
        try? FileManager.default.removeItem(at: normalizedRoot)
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
        settingsDefaults.set(data, forKey: Self.configuredTargetsDefaultsKey)
    }

    private static func loadConfiguredTargets(from defaults: UserDefaults) -> [TargetDefinition] {
        let builtIns = TargetRegistry.builtInLocalAutomation + TargetRegistry.builtInRemoteAccess
        guard let data = defaults.data(forKey: configuredTargetsDefaultsKey), let stored = try? JSONDecoder().decode([TargetDefinition].self, from: data) else {
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

    private static func loadIsolationPolicy(from defaults: UserDefaults) -> EmergencyIsolationPolicy {
        guard let data = defaults.data(forKey: isolationPolicyDefaultsKey),
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
