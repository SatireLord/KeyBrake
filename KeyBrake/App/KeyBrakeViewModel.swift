import Foundation
import AppKit
import KeyBrakeCore
import Security
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

struct FirstRunSlotState: Equatable {
    var displayName: String?
    var skipped = false

    var isSettled: Bool { displayName != nil || skipped }

    var statusText: String {
        if let displayName { return displayName }
        if skipped { return "Skipped" }
        return "Not chosen"
    }
}

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
    @Published private(set) var recoveryNotificationStatus = "Not requested"
    @Published private(set) var recoveryStoreHydrationSucceeded = false
    @Published var isolationPolicy: EmergencyIsolationPolicy
    @Published var isShowingRecoveryPanel = false
    @Published var isShowingIncidentLog = false
    @Published var isShowingSettings = false
    @Published var isShowingFirstRun = false
    @Published var firstRunLocalSlot = FirstRunSlotState()
    @Published var firstRunRemoteSlot = FirstRunSlotState()
    @Published private(set) var keyboardSettingsNavigationRequest: UUID?
    @Published private(set) var privilegedHelperRevealRequest: UUID?
    @Published private(set) var remoteSessionWarning: String?
    let buildSigning: KeyBrakeBuildSigning
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
    static let firstRunDefaultsKey = "KeyBrake.didCompleteFirstRunGuidance.v1"
    static let helperNotApprovedSentence = "The helper is not approved. Open Settings and use Register Privileged Helper."
    static let stopLocalTypingAppsTitle = "Stop Local Typing Apps"
    static let restoreRecordedChangesTitle = "Restore Recorded Changes"
    static let stopSkynetLocallyDescriptor = "Stop Skynet Locally"
    static let restoreHumanControlDescriptor = "Restore Human Control"
    private var didPostRecoveryNotification = false

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
        self.buildSigning = isReadOnlyDemo ? .otherSigned : KeyBrakeCodeSignature.current()
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
            postRecoveryNotificationIfNeeded()
        } else {
            presentFirstRunIfNeeded()
        }
    }

    var approvedRemoteTargetNames: [String] {
        configuredTargets
            .filter { $0.category == .remoteAccess && $0.approvedByUser && $0.enabledForEmergencyStop }
            .map(\.displayName)
            .sorted()
    }

    var isolationPreviewLines: [IsolationPreviewLine] {
        IsolationPlanPreview.lines(
            for: isolationPolicy,
            sandbox: isNetworkSandbox,
            approvedRemoteTargetNames: approvedRemoteTargetNames
        )
    }

    func requestStopRemoteAccess() {
        guard !isBusy else { return }
        let alert = NSAlert()
        let changesSomething = IsolationPlanPreview.affectsIsolation(
            for: isolationPolicy,
            approvedRemoteTargetNames: approvedRemoteTargetNames
        )
        if !isNetworkSandbox && !changesSomething {
            alert.messageText = "This isolation plan changes nothing"
            alert.informativeText = IsolationPlanPreview.confirmationText(
                for: isolationPolicy,
                sandbox: false,
                approvedRemoteTargetNames: approvedRemoteTargetNames
            )
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        alert.messageText = isNetworkSandbox ? "Rehearse this isolation plan?" : "Apply this isolation plan?"
        var confirmation = IsolationPlanPreview.confirmationText(
            for: isolationPolicy,
            sandbox: isNetworkSandbox,
            approvedRemoteTargetNames: approvedRemoteTargetNames
        )
        if let warning = KeyBrakeRemoteSessionProbe.currentNotice()?.warningSentence {
            remoteSessionWarning = warning
            confirmation += "\n\n\(warning)"
        }
        alert.informativeText = confirmation
        alert.addButton(withTitle: isNetworkSandbox ? "Rehearse Isolation" : "Stop Remote Access")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        stopRemoteAccess()
    }

    func exportIncidents() {
        exportIncidentRecords(incidents, suggestedName: "KeyBrake-incidents.json")
    }

    func exportIncident(_ incident: IncidentRecord) {
        exportIncidentRecords([incident], suggestedName: "KeyBrake-incident.json")
    }

    private func exportIncidentRecords(_ records: [IncidentRecord], suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = suggestedName
        panel.message = "Exports operation metadata only. KeyBrake does not store credentials, TCC contents, or documents."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try KeyBrakeIncidentExport.jsonData(from: records)
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.messageText = "KeyBrake could not export incidents"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func presentFirstRunIfNeeded() {
        guard !isReadOnlyDemo else { return }
        guard !settingsDefaults.bool(forKey: Self.firstRunDefaultsKey) else { return }
        if firstRunLocalSlot.displayName == nil {
            firstRunLocalSlot.displayName = configuredTargets.last { $0.id.hasPrefix("custom-localAutomation-") }?.displayName
        }
        if firstRunRemoteSlot.displayName == nil {
            firstRunRemoteSlot.displayName = configuredTargets.last { $0.id.hasPrefix("custom-remoteAccess-") }?.displayName
        }
        isShowingFirstRun = true
    }

    func skipFirstRunSlot(_ category: TargetDefinition.Category) {
        switch category {
        case .localAutomation:
            guard firstRunLocalSlot.displayName == nil else { return }
            firstRunLocalSlot.skipped = true
        case .remoteAccess:
            guard firstRunRemoteSlot.displayName == nil else { return }
            firstRunRemoteSlot.skipped = true
        }
    }

    func chooseFirstRunApplication(_ category: TargetDefinition.Category) {
        let before = Set(configuredTargets.map(\.id))
        let approvedByUser = category == .remoteAccess
        guard enrollApplicationFromPanel(category: category, approvedByUser: approvedByUser) else { return }
        let addedName = configuredTargets.last { !before.contains($0.id) && $0.category == category }?.displayName
        switch category {
        case .localAutomation:
            firstRunLocalSlot.displayName = addedName
            firstRunLocalSlot.skipped = false
        case .remoteAccess:
            firstRunRemoteSlot.displayName = addedName
            firstRunRemoteSlot.skipped = false
        }
    }

    @discardableResult
    func finishFirstRunSitting() -> Bool {
        guard firstRunLocalSlot.isSettled, firstRunRemoteSlot.isSettled else { return false }
        settingsDefaults.set(true, forKey: Self.firstRunDefaultsKey)
        isShowingFirstRun = false
        return true
    }

    func dismissFirstRunForNow() {
        settingsDefaults.set(true, forKey: Self.firstRunDefaultsKey)
        isShowingFirstRun = false
    }

    private func postRecoveryNotificationIfNeeded() {
        guard !isReadOnlyDemo, !didPostRecoveryNotification else { return }
        didPostRecoveryNotification = true
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            Task { @MainActor in
                self.recoveryNotificationStatus = granted ? "Local alert requested" : "Notification permission denied"
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = "KeyBrake recovery is still pending"
                content.body = "Open KeyBrake and choose a mouse-operated recovery action. Closing the panel does not resolve the decision."
                let request = UNNotificationRequest(identifier: "keybrake.recovery-pending", content: content, trigger: nil)
                center.add(request)
            }
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
        alert.messageText = "Restore what KeyBrake changed?"
        alert.informativeText = quitRestoreConfirmationText
        alert.addButton(withTitle: "Restore Network")
        alert.addButton(withTitle: "Keep Isolation and Quit")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            restoreNetworkOnly(confirmVPN: false)
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

    func restoreNetworkOnly(confirmVPN: Bool = true) {
        guard !isBusy else { return }
        let retainVPNDisconnected = confirmVPN ? confirmVPNRemainsDisconnectedIfNeeded() : hasPreviouslyConnectedVPN
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

    var localStopBlastRadius: String {
        let names = configuredTargets
            .filter { $0.category == .localAutomation && $0.enabledForEmergencyStop }
            .map(\.displayName)
        return KeyBrakeStopExplanation.localBlastRadius(names: names)
    }

    var remoteStopBlastRadius: String {
        KeyBrakeStopExplanation.remoteBlastRadius(
            changingTitles: IsolationPlanPreview.changingTitles(
                for: isolationPolicy,
                sandbox: isNetworkSandbox,
                approvedRemoteTargetNames: approvedRemoteTargetNames
            )
        )
    }

    var partialStopSummary: String? {
        KeyBrakeStopExplanation.partialStopSummary(state: operationalState, incident: latestIncident)
    }

    var recoveryStillOffText: String? {
        guard isRecoveryStatusKnown, hasRecovery else { return nil }
        let networkNames = disabledRecordedNames(in: (unresolvedRecovery?.networkChanges ?? []).filter { !$0.isVPN })
        let sharingNames = disabledRecordedNames(in: unresolvedRecovery?.sharingChanges ?? [])
        return KeyBrakeStopExplanation.stillOffSentence(
            names: networkNames + sharingNames,
            since: unresolvedRecovery?.createdAt
        )
    }

    var showsEspansoRestart: Bool {
        Self.showsEspansoRestart(targets: configuredTargets, espansoInstalled: EspansoAdapter.isInstalled())
    }

    var helperRegistrationButtonTitle: String {
        KeyBrakeHelperRegistrationCopy.buttonTitle(signing: buildSigning)
    }

    var canRegisterPrivilegedHelper: Bool {
        KeyBrakeHelperRegistrationCopy.canRegister(signing: buildSigning) && !isReadOnlyDemo
    }

    func refreshRemoteSessionWarning() {
        remoteSessionWarning = KeyBrakeRemoteSessionProbe.currentNotice()?.warningSentence
    }

    func openPracticeIsolation() {
        guard !isReadOnlyDemo else { return }
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [KeyBrakeLaunchArgument.networkSandbox]
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                guard let error else { return }
                Task { @MainActor in
                    self.showTerminationBlockedAlert(
                        messageText: "KeyBrake could not open practice mode",
                        informativeText: error.localizedDescription
                    )
                }
            }
            return
        }
        guard let executableURL = Bundle.main.executableURL else {
            showTerminationBlockedAlert(
                messageText: "KeyBrake could not open practice mode",
                informativeText: "The current executable path is unavailable."
            )
            return
        }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [KeyBrakeLaunchArgument.networkSandbox]
        do {
            try process.run()
        } catch {
            showTerminationBlockedAlert(
                messageText: "KeyBrake could not open practice mode",
                informativeText: error.localizedDescription
            )
        }
    }

    static func showsEspansoRestart(targets: [TargetDefinition], espansoInstalled: Bool) -> Bool {
        espansoInstalled && targets.contains { $0.id == "espanso" && $0.category == .localAutomation && $0.enabledForEmergencyStop }
    }

    var networkRestoreLine: String {
        let names = disabledRecordedNames(in: unresolvedRecovery?.networkChanges ?? [])
        if names.isEmpty {
            return "Restore recorded network services that were enabled before KeyBrake isolated them."
        }
        return "Turns \(names.joined(separator: ", ")) back on."
    }

    var sharingRestoreLine: String {
        let names = disabledRecordedNames(in: unresolvedRecovery?.sharingChanges ?? [])
        if names.isEmpty {
            return "Restore only the sharing services that were enabled before KeyBrake changed them."
        }
        return "Turns \(names.joined(separator: ", ")) back on."
    }

    var quitRestoreConfirmationText: String {
        let networkNames = disabledRecordedNames(in: (unresolvedRecovery?.networkChanges ?? []).filter { !$0.isVPN })
        let turnOn = networkNames.isEmpty
            ? "No recorded network service turns back on."
            : "Turns \(networkNames.joined(separator: ", ")) back on."
        var lines = [turnOn]
        let vpnNames = disabledRecordedNames(in: unresolvedRecovery?.vpnConnections ?? [])
        let networkVPNNames = disabledRecordedNames(in: (unresolvedRecovery?.networkChanges ?? []).filter(\.isVPN))
        let disconnectedVPNs = Array(Set(vpnNames + networkVPNNames)).sorted()
        if disconnectedVPNs.isEmpty {
            if hasPreviouslyConnectedVPN {
                lines.append("A VPN KeyBrake disconnected stays disconnected. KeyBrake will not reconnect it.")
            }
        } else {
            lines.append("\(disconnectedVPNs.joined(separator: ", ")) stays disconnected. KeyBrake will not reconnect a VPN.")
        }
        lines.append("Sharing stays as it is until you restore it from the recovery panel.")
        return lines.joined(separator: " ")
    }

    var menuBarStatusWord: String {
        Self.menuBarStatusWord(known: isRecoveryStatusKnown, hasRecovery: hasRecovery, state: operationalState)
    }

    var nextStepSentence: String {
        Self.nextStepSentence(known: isRecoveryStatusKnown, busy: isBusy, hasRecovery: hasRecovery)
    }

    var helperFailureNotice: String? {
        Self.helperFailureNotice(helperStatus: privilegedHelperStatus, incident: latestIncident, readOnlyDemo: isReadOnlyDemo)
    }

    func helperFailureNotice(for incident: IncidentRecord) -> String? {
        Self.helperFailureNotice(helperStatus: privilegedHelperStatus, incident: incident, readOnlyDemo: isReadOnlyDemo)
    }

    func openPrivilegedHelperSettings() {
        privilegedHelperRevealRequest = UUID()
        isShowingSettings = true
    }

    static func menuBarStatusWord(known: Bool, hasRecovery: Bool, state: KeyBrakeOperationalState) -> String {
        guard known else { return "Checking" }
        switch state {
        case .stoppingLocalAutomation:
            return "Stopping"
        case .isolating:
            return "Isolating"
        case .restoring:
            return "Restoring"
        case .localAutomationStopped, .normal, .isolated, .partiallyIsolated, .recoveryRequired:
            break
        }
        if hasRecovery || state.requiresRecoveryDecision { return "Recovery" }
        switch state {
        case .localAutomationStopped:
            return "Stopped"
        case .isolated, .partiallyIsolated, .recoveryRequired:
            return "Recovery"
        case .normal, .stoppingLocalAutomation, .isolating, .restoring:
            return "Ready"
        }
    }

    static func nextStepSentence(known: Bool, busy: Bool, hasRecovery: Bool) -> String {
        guard known, !busy else { return "Wait." }
        return hasRecovery ? "Open recovery." : "Stop something."
    }

    static func helperFailureNotice(helperStatus: String, incident: IncidentRecord?, readOnlyDemo: Bool) -> String? {
        guard !readOnlyDemo, helperStatus != "Enabled", let incident else { return nil }
        let helperBlockedChange = incident.steps.contains { step in
            (step.subsystem == "network" || step.subsystem == "sharing" || step.subsystem == "helper")
                && (step.outcome == .failed || step.outcome == .unsupported)
        }
        return helperBlockedChange ? helperNotApprovedSentence : nil
    }

    var pendingChangeSummary: String {
        guard let snapshot = unresolvedRecovery else { return "recorded changes are still waiting." }
        var names = disabledRecordedNames(in: snapshot.networkChanges)
        names.append(contentsOf: disabledRecordedNames(in: snapshot.vpnConnections).map { "\($0) disconnected" })
        names.append(contentsOf: disabledRecordedNames(in: snapshot.sharingChanges))
        if names.isEmpty { return "recorded changes are still waiting." }
        return names.joined(separator: ", ") + "."
    }

    private func disabledRecordedNames(in changes: [NetworkChange]) -> [String] {
        changes.filter { $0.originalEnabled && $0.currentEnabled == false }.map(\.displayName)
    }

    private func disabledRecordedNames(in changes: [SharingChange]) -> [String] {
        changes.filter { $0.originalEnabled && $0.currentEnabled == false }.map(\.displayName)
    }

    @discardableResult
    private func enrollApplicationFromPanel(category: TargetDefinition.Category, approvedByUser: Bool) -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = category == .localAutomation
            ? "Choose one local typing application."
            : "Choose one remote-access application. KeyBrake will approve it for Stop Remote Access."
        guard panel.runModal() == .OK, let applicationURL = panel.url, let bundle = Bundle(url: applicationURL), let bundleIdentifier = bundle.bundleIdentifier else {
            return false
        }
        let targetID = "custom-\(category.rawValue)-\(bundleIdentifier.replacingOccurrences(of: ".", with: "-"))"
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? applicationURL.deletingPathExtension().lastPathComponent
        let target = TargetDefinition(
            id: targetID,
            displayName: displayName,
            category: category,
            bundleIdentifier: bundleIdentifier,
            applicationURL: applicationURL,
            executableURL: bundle.executableURL,
            approvedByUser: approvedByUser,
            enabledForEmergencyStop: true,
            allowForcedTermination: true
        )
        guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: bundleIdentifier, executableURL: bundle.executableURL) else {
            showTerminationBlockedAlert(
                messageText: "KeyBrake did not add \(displayName)",
                informativeText: "This application is protected, or its identity could not be checked."
            )
            return false
        }
        guard !configuredTargets.contains(where: { $0.id == targetID }) else {
            showTerminationBlockedAlert(
                messageText: "\(displayName) is already configured",
                informativeText: "Choose a different application for this step."
            )
            return false
        }
        enrollTarget(target)
        if approvedByUser {
            setTargetApproval(targetID: target.id, approved: true)
        }
        return configuredTargets.contains { $0.id == targetID }
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
        guard canRegisterPrivilegedHelper else { return }
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
        let alert = NSAlert()
        alert.messageText = "Clear resolved incident history?"
        alert.informativeText = "KeyBrake removes only records whose final state is normal. Unresolved recovery snapshots stay in place."
        alert.addButton(withTitle: "Clear Resolved History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
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

enum KeyBrakeCodeSignature {
    static func current() -> KeyBrakeBuildSigning {
        guard let url = Bundle.main.executableURL else { return .unsignedOrAdHoc }
        return classify(url: url)
    }

    static func classify(url: URL) -> KeyBrakeBuildSigning {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess, let staticCode else {
            return .unsignedOrAdHoc
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let information = information as? [String: Any] else {
            return .unsignedOrAdHoc
        }
        let flags = (information[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0
        let adhocSignatureFlag: UInt32 = 0x0002
        if flags & adhocSignatureFlag != 0 {
            return .unsignedOrAdHoc
        }
        if let certificates = information[kSecCodeInfoCertificates as String] as? [SecCertificate] {
            for certificate in certificates {
                let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? ""
                if summary.contains("Developer ID Application") {
                    return .developerID
                }
            }
            if !certificates.isEmpty {
                return .otherSigned
            }
        }
        return .unsignedOrAdHoc
    }
}
