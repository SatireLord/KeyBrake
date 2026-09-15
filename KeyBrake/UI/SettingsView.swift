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
struct SettingsView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @State private var selectedPrivacyServices: Set<TCCService> = []
    @State private var selectedTargetID = ""
    @State private var errorMessage = ""

    private var accessTargets: [TargetDefinition] {
        model.configuredTargets.filter { $0.bundleIdentifier != nil }
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
                LabeledContent("Privileged Helper") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.privilegedHelperStatus)
                        Button("Register Privileged Helper") { model.registerPrivilegedHelper() }
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
                ForEach(model.configuredTargets.filter { $0.category == .localAutomation }) { target in
                    targetRow(target)
                }
                Button("Add Application…") { chooseApplication(category: .localAutomation) }
                Text("Added applications are matched by their exact bundle identifier and executable path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Remote Access") {
                ForEach(model.configuredTargets.filter { $0.category == .remoteAccess }) { target in
                    Toggle(isOn: Binding(
                        get: { model.configuredTargets.first(where: { $0.id == target.id })?.approvedByUser ?? false },
                        set: { model.setTargetApproval(targetID: target.id, approved: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.displayName)
                            Text(target.bundleIdentifier ?? "Bundle identifier unavailable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("Include this exact application in Stop Remote Access")
                    if !builtInTargetIDs.contains(target.id) {
                        Button("Remove \(target.displayName)", role: .destructive) { model.removeTarget(targetID: target.id) }
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
                .disabled(selectedTargetID.isEmpty || selectedPrivacyServices.isEmpty)
            }

            Section("Emergency Isolation") {
                Toggle("Disable Wi-Fi", isOn: policyBinding(\.disableWiFi))
                Toggle("Disable physical Ethernet", isOn: policyBinding(\.disableEthernet))
                Toggle("Disconnect VPNs", isOn: policyBinding(\.disconnectVPN))
                Toggle("Disable Remote Login", isOn: policyBinding(\.disableRemoteLogin))
                Toggle("Disable Remote Apple Events", isOn: policyBinding(\.disableRemoteAppleEvents))
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
                Text(target.bundleIdentifier ?? "Bundle identifier unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !builtInTargetIDs.contains(target.id) {
                    Button("Remove", role: .destructive) { model.removeTarget(targetID: target.id) }
                }
            }
        }
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
