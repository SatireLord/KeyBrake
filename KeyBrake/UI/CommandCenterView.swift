import AppKit
import KeyBrakeCore
import SwiftUI

// Greppable:
// canonical: keybrake-command-center
// aliases: command center; safety dashboard; recovery dashboard; main control surface
// forms: keybrake-command-center; commandCenter; command-center
// descriptors: at-a-glance status; emergency actions; recovery routing; recent incident
// states: checking; ready; busy; recovery-required; empty; incident-present; degraded
// consumers: KeyBrakeApp; KeyBrakeMenuView; KeyBrakeViewModel; Agent Display
// owner: KeyBrakeCommandCenterView
struct KeyBrakeCommandCenterView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusCard
                emergencyActions
                if model.hasRecovery {
                    recoveryCard
                }
                recentIncidentCard
                secondaryActions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("KeyBrake Command Center")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: KeyBrakeStatusPresentation.symbol(for: model.operationalState))
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(KeyBrakeStatusPresentation.tint(for: model.operationalState))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("KeyBrake Command Center")
                    .font(.largeTitle.weight(.bold))
                Text("See the current state, choose a bounded action, and keep recovery decisions visible.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
        }
    }

    private var statusCard: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: KeyBrakeStatusPresentation.symbol(for: model.operationalState))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(KeyBrakeStatusPresentation.tint(for: model.operationalState))
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.isRecoveryStatusKnown ? model.operationalState.displayTitle : "Checking Recovery Status")
                        .font(.title3.weight(.semibold))
                    Text(model.isRecoveryStatusKnown ? KeyBrakeStatusPresentation.detail(for: model.operationalState) : "KeyBrake is confirming whether an unresolved recovery snapshot exists.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
                statusBadge
            }
        } label: {
            Text("Current protection state")
        }
    }

    private var emergencyActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                title: "Emergency actions",
                subtitle: "Use the smallest action that matches the situation. KeyBrake records and verifies each operation."
            )

            HStack(alignment: .top, spacing: 12) {
                Button {
                    model.stopSkynetLocally()
                } label: {
                    actionLabel(
                        title: "Stop Skynet Locally",
                        description: "Stop approved local input automation without changing network or privacy settings.",
                        systemImage: "keyboard.badge.ellipsis"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || model.operationalState == .localAutomationStopped)

                Button {
                    model.stopRemoteAccess()
                } label: {
                    actionLabel(
                        title: "Stop Remote Access",
                        description: "Save recovery state first, then apply the selected isolation profile.",
                        systemImage: "lock.shield"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.isBusy)
            }
        }
    }

    private var recoveryCard: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Recovery decision required")
                        .font(.headline)
                    Text("A recovery snapshot is still available. Review the panel before you quit or consider the incident resolved.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Open Recovery Panel") {
                    model.isShowingRecoveryPanel = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(model.isBusy)
            }
        }
    }

    private var recentIncidentCard: some View {
        GroupBox {
            if let incident = model.latestIncident {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(incident.initiatingAction)
                            .font(.headline)
                        Spacer()
                        Text(incident.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(incident.resolution)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(
                        "\(incident.steps.count) recorded \(incident.steps.count == 1 ? "step" : "steps")",
                        systemImage: "checklist"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No incidents recorded")
                            .font(.headline)
                        Text("KeyBrake will keep the next operation and its outcome here.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Text("Recent activity")
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            Button {
                openWindow(id: "incidents")
            } label: {
                Label("Incident Log", systemImage: "list.bullet.clipboard")
            }
            .buttonStyle(.bordered)

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 12)
            Text("Mouse-operated recovery")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !model.isRecoveryStatusKnown {
            Label("Checking", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        } else if model.isBusy {
            Label("In progress", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
        } else if model.hasRecovery {
            Label("Action required", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        } else {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func sectionHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func actionLabel(title: String, description: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// Greppable:
// canonical: keybrake-status-presentation
// aliases: status hierarchy; state badge; state explanation
// forms: keybrake-status-presentation; statusBadge; status-description
// descriptors: state icon; state tint; user-facing state detail
// states: normal; stopping; isolating; isolated; partial; restoring; recovery-required
// consumers: KeyBrakeCommandCenterView; KeyBrakeMenuView
// owner: KeyBrakeStatusPresentation
enum KeyBrakeStatusPresentation {
    static func symbol(for state: KeyBrakeOperationalState) -> String {
        switch state {
        case .normal:
            return "checkmark.shield"
        case .stoppingLocalAutomation:
            return "arrow.triangle.2.circlepath"
        case .localAutomationStopped:
            return "pause.circle"
        case .isolating:
            return "lock.rotation"
        case .isolated:
            return "lock.shield.fill"
        case .partiallyIsolated:
            return "exclamationmark.shield"
        case .restoring:
            return "arrow.uturn.backward.circle"
        case .recoveryRequired:
            return "exclamationmark.triangle"
        }
    }

    static func detail(for state: KeyBrakeOperationalState) -> String {
        switch state {
        case .normal:
            return "No KeyBrake recovery work is pending."
        case .stoppingLocalAutomation:
            return "KeyBrake is stopping approved local automation. Keep KeyBrake open until the operation completes."
        case .localAutomationStopped:
            return "Approved local automation is stopped. Network controls are unchanged."
        case .isolating:
            return "KeyBrake is applying the selected network and sharing isolation profile."
        case .isolated:
            return "Selected network and sharing changes are isolated and require a recovery decision."
        case .partiallyIsolated:
            return "Some isolation steps need review before recovery can be considered complete."
        case .restoring:
            return "KeyBrake is comparing and restoring only changes it previously applied."
        case .recoveryRequired:
            return "A recovery snapshot needs your decision. Review the available actions before quitting."
        }
    }

    static func tint(for state: KeyBrakeOperationalState) -> Color {
        switch state {
        case .normal:
            return .green
        case .stoppingLocalAutomation, .isolating, .restoring:
            return .blue
        case .localAutomationStopped:
            return .indigo
        case .isolated, .partiallyIsolated:
            return .orange
        case .recoveryRequired:
            return .red
        }
    }
}
