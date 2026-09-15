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
// QoL-005: the Command Center header, state card, recovery card, and badge share the hydration-aware state boundary.
// QoL-010: Command Center state-changing controls explain their busy disabled state while review navigation remains available.
// QoL-011: Recent activity reuses the shared operational-state symbol and tint so the latest recorded outcome is scannable before its detail text.
// QoL-012: Empty recent activity exposes its visible no-record message as one stable accessibility surface.
// QoL-013: Current protection state combines its visible state, detail, and badge into one stable accessibility surface for fast orientation.
// QoL-014: Review navigation cards combine each visible destination and count into one stable accessibility surface.
struct KeyBrakeCommandCenterView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusCard
                emergencyActions
                if model.isRecoveryStatusKnown && model.hasRecovery {
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

    private var hydrationAwareStatusSymbol: String {
        model.isRecoveryStatusKnown
            ? KeyBrakeStatusPresentation.symbol(for: model.operationalState)
            : "hourglass"
    }

    private var hydrationAwareStatusTint: Color {
        model.isRecoveryStatusKnown
            ? KeyBrakeStatusPresentation.tint(for: model.operationalState)
            : Color.secondary
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: hydrationAwareStatusSymbol)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(hydrationAwareStatusTint)
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
                Image(systemName: hydrationAwareStatusSymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(hydrationAwareStatusTint)
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

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
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("keybrake.command-center.current-protection-state")
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

            if model.isBusy {
                Text("Emergency actions are temporarily unavailable while KeyBrake completes the current operation. Review status or incident history while you wait.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("keybrake.command-center.stop-local-automation")
                .accessibilityHint(commandCenterActionHint(description: "Stops approved local input automation without changing network or privacy settings", disablesWhileBusy: true))
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("keybrake.command-center.stop-remote-access")
                .accessibilityHint(commandCenterActionHint(description: "Saves recovery state before applying the selected isolation profile", disablesWhileBusy: true))
                .disabled(model.isBusy)
            }
        }
    }

    private var recoveryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
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
                }

                if let snapshot = model.unresolvedRecovery {
                    recoveryInventory(snapshot)
                }

                if model.isBusy {
                    Text("The recovery panel is temporarily unavailable while KeyBrake completes the current operation. Incident history and settings remain available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Open Recovery Panel") {
                    model.isShowingRecoveryPanel = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("keybrake.command-center.open-recovery-panel")
                .accessibilityHint(commandCenterActionHint(description: "Opens the mouse-operated recovery decision panel", disablesWhileBusy: true))
                .disabled(model.isBusy)
            }
        }
    }

    private func recoveryInventory(_ snapshot: RecoverySnapshot) -> some View {
        let networkSummary = recoveryMetricDescription(snapshot.networkChanges.count, singular: "network change", plural: "network changes")
        let sharingSummary = recoveryMetricDescription(snapshot.sharingChanges.count, singular: "sharing change", plural: "sharing changes")
        let unresolvedSummary = recoveryMetricDescription(snapshot.unresolvedSteps.count, singular: "unresolved step", plural: "unresolved steps")

        return HStack(spacing: 14) {
            recoveryMetric(summary: networkSummary, systemImage: "network")
            recoveryMetric(summary: sharingSummary, systemImage: "person.2.badge.gearshape")
            recoveryMetric(summary: unresolvedSummary, systemImage: "exclamationmark.circle")
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery inventory: \(networkSummary), \(sharingSummary), \(unresolvedSummary)")
    }

    private func recoveryMetricDescription(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    private func recoveryMetric(summary: String, systemImage: String) -> some View {
        Label {
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
        }
    }

    private var recentIncidentCard: some View {
        GroupBox {
            if let incident = model.latestIncident {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: KeyBrakeStatusPresentation.symbol(for: incident.finalState))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(KeyBrakeStatusPresentation.tint(for: incident.finalState))
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(incident.initiatingAction)
                                .font(.headline)
                            Spacer()
                            Text(incident.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(incident.finalState.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KeyBrakeStatusPresentation.tint(for: incident.finalState))
                        Text(incident.resolution)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(
                            "\(incident.steps.count) recorded \(incident.steps.count == 1 ? "step" : "steps")",
                            systemImage: "checklist"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recent activity: \(incident.initiatingAction), \(incident.finalState.displayTitle), \(incident.resolution), \(incident.steps.count) recorded \(incident.steps.count == 1 ? "step" : "steps")")
                .accessibilityIdentifier("keybrake.command-center.recent-activity")
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recent activity: No incidents recorded. KeyBrake will keep the next operation and its outcome here.")
                .accessibilityIdentifier("keybrake.command-center.recent-activity.empty")
            }
        } label: {
            Text("Recent activity")
        }
    }

    private var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(
                title: "Review and configure",
                subtitle: "Inspect recorded outcomes or adjust approved targets and isolation policy."
            )

            HStack(spacing: 10) {
                Button {
                    openWindow(id: "incidents")
                } label: {
                    navigationLabel(
                        title: "Incident Log",
                        detail: "\(model.incidents.count) recorded \(model.incidents.count == 1 ? "incident" : "incidents")",
                        systemImage: "list.bullet.clipboard"
                    )
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("keybrake.command-center.open-incident-log")
                .accessibilityHint("Opens the recorded incident history")

                Button {
                    openWindow(id: "settings")
                } label: {
                    navigationLabel(
                        title: "Settings",
                        detail: "\(model.configuredTargets.count) configured \(model.configuredTargets.count == 1 ? "target" : "targets")",
                        systemImage: "gearshape"
                    )
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("keybrake.command-center.open-settings")
                .accessibilityHint("Opens approved targets and isolation policy settings")
            }

            Text("Mouse-operated recovery remains available from the menu and recovery panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func commandCenterActionHint(description: String, disablesWhileBusy: Bool) -> String {
        guard disablesWhileBusy && model.isBusy else { return description }
        return "Unavailable while KeyBrake completes the current operation."
    }

    private func navigationLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }

// Greppable:
// canonical: keybrake-command-center-navigation
// aliases: review and configure; incident history; target settings
// forms: keybrake-command-center-navigation; Incident Log; Settings
// descriptors: navigation cards; recorded incident count; configured target count
// states: empty; incident-present; targets-configured; recovery-required
// consumers: KeyBrakeCommandCenterView; IncidentLogView; SettingsView; WindowLaunchBridge
// owner: KeyBrakeCommandCenterView.secondaryActions
// boundary: navigation-only; emergency and recovery handlers remain unchanged
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
