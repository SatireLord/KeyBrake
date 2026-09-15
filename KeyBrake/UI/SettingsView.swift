import AppKit
import KeyBrakeCore
import SwiftUI
import UniformTypeIdentifiers

// Greppable:
// canonical: keybrake-settings-destination
// aliases: target configuration; isolation policy; privacy reset settings
// forms: keybrake-settings-destination; Emergency Isolation; Privacy Reset Profile
// descriptors: configured targets; isolation profile; helper status
// states: ready; helper-unavailable; recovery-required
// consumers: KeyBrakeCommandCenterView; KeyBrakeMenuView; KeyBrakeViewModel
// owner: SettingsView
// QoL-001: the protection overview uses the shared state tint so the destination communicates status before controls.
// QoL-005: the recovery summary stays in a checking state until launch recovery hydration is complete.
// QoL-032: the network sandbox Settings section publishes a stable container anchor while preserving its scenario and host-boundary children.
// QoL-034: the network sandbox Settings section contains its status, scenario, and host-boundary children for deterministic inspection.
// QoL-036: the network sandbox Settings section repeats the immutable fixture inventory before disabled controls so both review surfaces expose the same simulated inputs.
// QoL-038: sandbox status, scenario, fixture inventory, and protection information stay readable while only host-bound settings sections inherit the sandbox disabled gate.
// QoL-039: empty Local Automation and Remote Access target lists explain their state before the existing enrollment controls.
// QoL-040: configured target rows expose the existing bundle identifier and recorded executable path so the identity boundary is reviewable before actions.
struct SettingsView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @State private var selectedPrivacyServices: Set<TCCService> = []
    @State private var selectedTargetID = ""
    @State private var errorMessage = ""

    private var accessTargets: [TargetDefinition] {
        model.configuredTargets.filter { $0.bundleIdentifier != nil }
    }

    private var appAccessResetActionHint: String {
        if model.isNetworkSandbox {
            return "Unavailable in the network sandbox; host privacy settings remain unchanged."
        }
        if selectedTargetID.isEmpty && selectedPrivacyServices.isEmpty {
            return "Choose an application and at least one privacy service before requesting an access reset."
        }
        if selectedTargetID.isEmpty {
            return "Choose an application before requesting an access reset."
        }
        if selectedPrivacyServices.isEmpty {
            return "Choose at least one privacy service before requesting an access reset."
        }
        return "Requests a reset for the selected macOS privacy services. KeyBrake does not edit the TCC database or restore grants automatically."
    }

    private var launchAtLoginActionHint: String {
        if model.isNetworkSandbox {
            return "Unavailable in the network sandbox; host launch-at-login registration remains unchanged."
        }
        if let launchAtLoginError = model.launchAtLoginError {
            return "Launch at Login could not be updated: \(launchAtLoginError)"
        }
        return model.launchAtLoginEnabled
            ? "Launch KeyBrake at login is enabled. Toggle to ask macOS to unregister it."
            : "Launch KeyBrake at login is disabled. Toggle to ask macOS to register it."
    }

    private var privilegedHelperActionHint: String {
        if model.isNetworkSandbox {
            return "Unavailable in the network sandbox; no helper registration request is sent to macOS."
        }
        if let privilegedHelperError = model.privilegedHelperError {
            return "The last privileged helper registration request failed: \(privilegedHelperError)"
        }
        switch model.privilegedHelperStatus {
        case "Enabled":
            return "The privileged helper is registered. Registering again asks macOS to refresh the registration."
        case "Approval required":
            return "macOS requires approval before the privileged helper can be used."
        case "Not registered":
            return "Requests macOS to register KeyBrake's privileged helper; macOS may require approval."
        case "Not found in app bundle":
            return "The helper is not present in this app bundle, so registration cannot proceed."
        case "Requires macOS 13+":
            return "Privileged helper registration requires macOS 13 or later."
        default:
            return "Requests macOS to register KeyBrake's privileged helper; macOS controls approval and authorization."
        }
    }

    private func isolationControlHint(effectDescription: String, enabled: Bool) -> String {
        if model.isNetworkSandbox {
            return "Unavailable in the network sandbox; fixture network state remains unchanged. \(effectDescription) is not applied during sandbox review."
        }
        let currentState = enabled ? "enabled" : "disabled"
        return "\(effectDescription). This setting is currently \(currentState) and is applied by the next Stop Remote Access operation."
    }

    private var builtInTargetIDs: Set<String> {
        Set(TargetRegistry.builtInLocalAutomation.map(\.id) + TargetRegistry.builtInRemoteAccess.map(\.id))
    }

    private var protectionStateTitle: String {
        model.isRecoveryStatusKnown ? model.operationalState.displayTitle : "Checking Recovery Status"
    }

    private var protectionStateDetail: String {
        model.isRecoveryStatusKnown
            ? KeyBrakeStatusPresentation.detail(for: model.operationalState)
            : "KeyBrake is confirming whether an unresolved recovery snapshot exists."
    }

    private var protectionStateSymbol: String {
        model.isRecoveryStatusKnown ? KeyBrakeStatusPresentation.symbol(for: model.operationalState) : "hourglass"
    }

    private var enabledIsolationControlCount: Int {
        [
            model.isolationPolicy.disableWiFi,
            model.isolationPolicy.disableEthernet,
            model.isolationPolicy.disconnectVPN,
            model.isolationPolicy.disableRemoteLogin,
            model.isolationPolicy.disableRemoteAppleEvents
        ].filter(\.self).count
    }

    private var configuredTargetsSummary: String {
        let count = model.configuredTargets.count
        return "\(count) configured \(count == 1 ? "target" : "targets")"
    }

    private var recoverySummaryTitle: String {
        guard model.isRecoveryStatusKnown else { return "Checking" }
        return model.hasRecovery ? "Decision pending" : "No decision pending"
    }

    private var recoverySummaryDetail: String {
        guard model.isRecoveryStatusKnown else {
            return "KeyBrake is confirming whether an unresolved recovery snapshot exists."
        }
        return model.hasRecovery
            ? "Use the recovery panel to choose the next action."
            : "KeyBrake has no unresolved recovery snapshot."
    }

    private var localAutomationTargets: [TargetDefinition] {
        model.configuredTargets.filter { $0.category == .localAutomation }
    }

    private var remoteAccessTargets: [TargetDefinition] {
        model.configuredTargets.filter { $0.category == .remoteAccess }
    }

    private var networkSandboxFixtureServices: [NetworkService] {
        guard let scenario = model.networkSandboxScenario else { return [] }
        return NetworkSandboxFixture.fixture(for: scenario).services
    }

    private func networkSandboxServiceSymbol(for kind: NetworkServiceKind) -> String {
        switch kind {
        case .wifi:
            return "wifi"
        case .vpn:
            return "lock.shield"
        case .loopback:
            return "arrow.triangle.2.circlepath"
        case .ethernet, .usbEthernet, .thunderbolt, .bridge, .other:
            return "network"
        }
    }

    private func networkSandboxServiceState(for service: NetworkService) -> String {
        let state = service.active ? "active" : (service.enabled ? "enabled" : "disabled")
        guard let device = service.device else { return state }
        return "\(state) · \(device)"
    }

    private var networkSandboxFixtureInventory: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fixture network inventory")
                .font(.caption.weight(.semibold))
            ForEach(networkSandboxFixtureServices) { service in
                HStack(spacing: 8) {
                    Label(service.displayName, systemImage: networkSandboxServiceSymbol(for: service.kind))
                    Spacer(minLength: 8)
                    Text(networkSandboxServiceState(for: service))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("keybrake.settings.network-sandbox-service.\(service.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keybrake.settings.network-sandbox-inventory")
    }

    var body: some View {
        Form {
            Section("Current protection state") {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(protectionStateTitle)
                                .font(.headline)
                            Text(protectionStateDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: protectionStateSymbol)
                            .foregroundStyle(
                                model.isRecoveryStatusKnown
                                    ? KeyBrakeStatusPresentation.tint(for: model.operationalState)
                                    : Color.secondary
                            )
                    }

                    Divider()

                    LabeledContent("Configured targets", value: configuredTargetsSummary)
                    LabeledContent(
                        "Isolation profile",
                        value: "\(enabledIsolationControlCount) of 5 controls enabled"
                    )
                    LabeledContent(
                        "Recovery",
                        value: recoverySummaryTitle
                    )
                    .help(recoverySummaryDetail)
                }
                .accessibilityIdentifier("keybrake.settings.overview")
            }

            if model.isNetworkSandbox {
                Section("Network sandbox") {
                    Label("Host operations disabled", systemImage: "shield.checkered")
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("keybrake.settings.network-sandbox-status")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scenario: \(model.networkSandboxScenario?.displayTitle ?? "Fixture simulation")")
                            .font(.subheadline.weight(.semibold))
                        Text(model.networkSandboxScenario?.displayDetail ?? "This run uses local Wi-Fi and VPN fixtures.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("keybrake.settings.network-sandbox-scenario")
                    networkSandboxFixtureInventory
                    Text("Settings changes, privacy requests, helper registration, and launch-at-login changes are unavailable; sandbox recovery state stays in a UUID-named temporary store.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("keybrake.settings.network-sandbox-host-boundary")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("keybrake.settings.network-sandbox-section")
            }

            Group {
            Section("General") {
                Toggle("Launch KeyBrake at Login", isOn: Binding(get: { model.launchAtLoginEnabled }, set: { model.setLaunchAtLogin($0) }))
                    .help(launchAtLoginActionHint)
                    .accessibilityHint(launchAtLoginActionHint)
                LabeledContent("Privileged Helper") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.privilegedHelperStatus)
                        Button("Register Privileged Helper") { model.registerPrivilegedHelper() }
                            .help(privilegedHelperActionHint)
                            .accessibilityHint(privilegedHelperActionHint)
                    }
                }
                if let privilegedHelperError = model.privilegedHelperError {
                    Text(privilegedHelperError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let launchAtLoginError = model.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Local Automation") {
                if localAutomationTargets.isEmpty {
                    targetListEmptyState(
                        title: "No local automation targets configured",
                        detail: "Add an application to include it in Stop Skynet Locally.",
                        identifier: "keybrake.settings.local-automation.empty"
                    )
                } else {
                    ForEach(localAutomationTargets) { target in
                        targetRow(target)
                    }
                }
                Button("Add Application…") { chooseApplication(category: .localAutomation) }
                Text("Added applications are matched by their exact bundle identifier and executable path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Remote Access") {
                if remoteAccessTargets.isEmpty {
                    targetListEmptyState(
                        title: "No remote access targets configured",
                        detail: "Add an application, then approve it before Stop Remote Access can include it.",
                        identifier: "keybrake.settings.remote-access.empty"
                    )
                } else {
                    ForEach(remoteAccessTargets) { target in
                        Toggle(isOn: Binding(
                            get: { model.configuredTargets.first(where: { $0.id == target.id })?.approvedByUser ?? false },
                            set: { model.setTargetApproval(targetID: target.id, approved: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.displayName)
                                targetIdentityDetails(for: target)
                            }
                        }
                        .help("Include this exact application in Stop Remote Access")
                        if !builtInTargetIDs.contains(target.id) {
                            Button("Remove \(target.displayName)", role: .destructive) { model.removeTarget(targetID: target.id) }
                        }
                    }
                }
                Button("Add Application…") { chooseApplication(category: .remoteAccess) }
                Text("Only targets you approve are stopped. KeyBrake never stops a target by name alone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Application Access") {
                Picker("Application", selection: $selectedTargetID) {
                    Text("Choose an application").tag("")
                    ForEach(accessTargets) { target in
                        Text(target.displayName).tag(target.id)
                    }
                }
                Text("This action requests a reset for selected macOS privacy services. It never edits the TCC database and never restores grants automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Revoke Selected Access") {
                    model.revokeAppAccess(targetID: selectedTargetID, services: selectedPrivacyServices)
                }
                .help(appAccessResetActionHint)
                .accessibilityHint(appAccessResetActionHint)
                .disabled(selectedTargetID.isEmpty || selectedPrivacyServices.isEmpty)
            }

            Section("Emergency Isolation") {
                Toggle("Disable Wi-Fi", isOn: policyBinding(\.disableWiFi))
                    .help(isolationControlHint(effectDescription: "Disables Wi-Fi interfaces", enabled: model.isolationPolicy.disableWiFi))
                    .accessibilityHint(isolationControlHint(effectDescription: "Disables Wi-Fi interfaces", enabled: model.isolationPolicy.disableWiFi))
                Toggle("Disable physical Ethernet", isOn: policyBinding(\.disableEthernet))
                    .help(isolationControlHint(effectDescription: "Disables physical Ethernet, USB Ethernet, and Thunderbolt interfaces", enabled: model.isolationPolicy.disableEthernet))
                    .accessibilityHint(isolationControlHint(effectDescription: "Disables physical Ethernet, USB Ethernet, and Thunderbolt interfaces", enabled: model.isolationPolicy.disableEthernet))
                Toggle("Disconnect VPNs", isOn: policyBinding(\.disconnectVPN))
                    .help(isolationControlHint(effectDescription: "Disconnects VPN services", enabled: model.isolationPolicy.disconnectVPN))
                    .accessibilityHint(isolationControlHint(effectDescription: "Disconnects VPN services", enabled: model.isolationPolicy.disconnectVPN))
                Toggle("Disable Remote Login", isOn: policyBinding(\.disableRemoteLogin))
                    .help(isolationControlHint(effectDescription: "Disables Remote Login sharing", enabled: model.isolationPolicy.disableRemoteLogin))
                    .accessibilityHint(isolationControlHint(effectDescription: "Disables Remote Login sharing", enabled: model.isolationPolicy.disableRemoteLogin))
                Toggle("Disable Remote Apple Events", isOn: policyBinding(\.disableRemoteAppleEvents))
                    .help(isolationControlHint(effectDescription: "Disables Remote Apple Events sharing", enabled: model.isolationPolicy.disableRemoteAppleEvents))
                    .accessibilityHint(isolationControlHint(effectDescription: "Disables Remote Apple Events sharing", enabled: model.isolationPolicy.disableRemoteAppleEvents))
                Text("Unsupported sharing capabilities are reported as unsupported and do not block independent network isolation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy Reset Profile") {
                ForEach(PrivacyServiceCatalog.descriptors) { descriptor in
                    Toggle(descriptor.displayName, isOn: Binding(
                        get: { selectedPrivacyServices.contains(descriptor.id) },
                        set: { selected in
                            if selected { selectedPrivacyServices.insert(descriptor.id) }
                            else { selectedPrivacyServices.remove(descriptor.id) }
                        }
                    ))
                }
            }

            Section("Recovery") {
                Text("After Stop Remote Access, KeyBrake always presents the recovery panel and keeps incident history until you clear resolved records from the incident log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
            .disabled(model.isNetworkSandbox)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if selectedTargetID.isEmpty { selectedTargetID = accessTargets.first?.id ?? "" }
        }
        .alert("KeyBrake", isPresented: Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private func targetRow(_ target: TargetDefinition) -> some View {
        LabeledContent(target.displayName) {
            VStack(alignment: .trailing, spacing: 2) {
                targetIdentityDetails(for: target)
                if !builtInTargetIDs.contains(target.id) {
                    Button("Remove", role: .destructive) { model.removeTarget(targetID: target.id) }
                }
            }
        }
    }

    private func targetListEmptyState(title: String, detail: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityIdentifier(identifier)
    }

    private func targetIdentityDetails(for target: TargetDefinition) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bundle ID: \(target.bundleIdentifier ?? "unavailable")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Executable: \(target.executableURL?.path ?? "path not recorded")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(targetIdentityAccessibilitySummary(for: target))
        .accessibilityIdentifier("keybrake.settings.target.\(target.id).identity")
    }

    private func targetIdentityAccessibilitySummary(for target: TargetDefinition) -> String {
        let bundleIdentifier = target.bundleIdentifier ?? "unavailable"
        let executablePath = target.executableURL?.path ?? "path not recorded"
        return "\(target.displayName), bundle identifier \(bundleIdentifier), executable \(executablePath)"
    }

    private func chooseApplication(category: TargetDefinition.Category) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let applicationURL = panel.url, let bundle = Bundle(url: applicationURL), let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }
        let targetID = "custom-\(bundleIdentifier.replacingOccurrences(of: ".", with: "-"))"
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
            approvedByUser: false,
            enabledForEmergencyStop: true,
            allowForcedTermination: true
        )
        guard TargetRegistry.canEnroll(target, applicationBundleIdentifier: bundleIdentifier, executableURL: bundle.executableURL) else {
            errorMessage = "KeyBrake rejected this application because it is protected or its identity could not be bounded safely."
            return
        }
        model.enrollTarget(target)
        selectedTargetID = target.id
    }

    private func policyBinding(_ keyPath: WritableKeyPath<EmergencyIsolationPolicy, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.isolationPolicy[keyPath: keyPath] },
            set: { value in
                var updated = model.isolationPolicy
                updated[keyPath: keyPath] = value
                model.updateIsolationPolicy(updated)
            }
        )
    }
}
