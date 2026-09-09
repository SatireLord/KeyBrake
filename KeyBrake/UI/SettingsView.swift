import KeyBrakeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @State private var launchAtLogin = false
    @State private var disableWiFi = true
    @State private var disableEthernet = true
    @State private var disconnectVPN = true
    @State private var disableRemoteLogin = true
    @State private var selectedPrivacyServices: Set<TCCService> = []

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch KeyBrake at Login", isOn: $launchAtLogin)
                LabeledContent("Privileged Helper") { Text("Approval required until a signed helper is installed").foregroundStyle(.secondary) }
            }
            Section("Local Automation") {
                LabeledContent("Espanso") { Text("Built-in approved definition; user configuration is never edited") }
                Button("Add Application…") { }
            }
            Section("Remote Access") {
                ForEach(TargetRegistry.builtInRemoteAccess) { target in
                    LabeledContent(target.displayName) { Text("Detected candidate · approval required").foregroundStyle(.secondary) }
                }
                Button("Add Application…") { }
            }
            Section("Emergency Isolation") {
                Toggle("Disable Wi-Fi", isOn: $disableWiFi)
                Toggle("Disable physical Ethernet", isOn: $disableEthernet)
                Toggle("Disconnect VPNs", isOn: $disconnectVPN)
                Toggle("Disable Remote Login", isOn: $disableRemoteLogin)
                Text("Unsupported sharing capabilities are reported as unsupported and do not block independent network isolation.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy Reset Profile") {
                Text("KeyBrake resets selected TCC-managed privacy decisions only for an explicitly selected application. macOS may ask for permission again; grants are never silently restored.")
                    .font(.caption)
                ForEach(PrivacyServiceCatalog.descriptors) { descriptor in
                    Toggle(descriptor.displayName, isOn: Binding(get: { selectedPrivacyServices.contains(descriptor.id) }, set: { selected in if selected { selectedPrivacyServices.insert(descriptor.id) } else { selectedPrivacyServices.remove(descriptor.id) } }))
                }
            }
            Section("Recovery") {
                Toggle("Open recovery panel after isolation", isOn: .constant(true))
                Toggle("Preserve incident history", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
