import AppKit
import KeyBrakeCore
import SwiftUI
import UniformTypeIdentifiers

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

    var body: some View {
        Form {
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
