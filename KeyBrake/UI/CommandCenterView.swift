import AppKit
import KeyBrakeCore
import SwiftUI

// Greppable:
// canonical: keybrake-command-center
// aliases: command center; safety dashboard; recovery dashboard; main control surface
// forms: keybrake-command-center; commandCenter; command-center
// descriptors: at-a-glance status; emergency actions; recovery routing; recent incident
// states: checking; ready; busy; recovery-required; empty; incident-present; degraded
// consumers: KeyBrakeApp; KeyBrakeMenuView; KeyBrakeViewModel
// owner: KeyBrakeCommandCenterView
// QoL-005: the Command Center header, state card, recovery card, and badge share the hydration-aware state boundary.
// QoL-010: Command Center state-changing controls explain their busy disabled state while review navigation remains available.
// QoL-011: Recent activity reuses the shared operational-state symbol and tint so the latest recorded outcome is scannable before its detail text.
// QoL-012: Empty recent activity exposes its visible no-record message as one stable accessibility surface.
// QoL-013: Current protection state combines its visible state, detail, and badge into one stable accessibility surface for fast orientation.
// QoL-014: Review navigation cards combine each visible destination and count into one stable accessibility surface.
// QoL-015: Command Center section headings combine their visible title and explanation and publish heading semantics.
// QoL-016: Command Center emergency actions combine their visible title and explanation into one stable actionable accessibility surface.
// QoL-017: Busy-state emergency-action guidance exposes one stable accessibility inspection anchor without changing its visible explanation or gate.
// QoL-018: Recovery decision orientation combines its visible title and explanation and hides only the decorative warning symbol.
// QoL-019: Recovery-card busy-state guidance exposes one stable accessibility inspection anchor without changing its visible explanation or gate.
// QoL-020: Recovery inventory exposes one stable accessibility inspection anchor without changing its live counts or combined label.
// QoL-021: Recovery card exposes one stable container-level accessibility inspection anchor without changing child surfaces or controls.
// QoL-022: Recovery metrics expose stable inspection anchors without changing their live summaries or the combined recovery-inventory surface.
// QoL-023: Recovery inventory contains its stable metric children so each existing summary remains inspectable without changing the parent label or visible layout.
// QoL-024: Recovery metric children speak their existing live summaries explicitly without changing their visible labels, identifiers, or parent grouping.
// QoL-025: Recovery metric children remain behind the containing inventory orientation during accessibility traversal without changing their visible labels, identifiers, or layout.
// QoL-026: The recovery-card container owns its stable accessibility identifier while preserving emergency-action ownership and all child surfaces.
// QoL-027: Network sandbox mode publishes its non-mutating boundary before controls so staged Wi-Fi and VPN exercise cannot be mistaken for host operations.
// QoL-028: Network sandbox mode identifies its connected or deterministic-failure fixture before its disabled host-operation boundary.
// QoL-029: Network sandbox scenario title and detail combine into one inspection surface without absorbing the host-operation boundary.
// QoL-030: Network sandbox banner contains its scenario and host-boundary surfaces so each stable inspection anchor remains independently reachable.
// QoL-031: Network sandbox host-operation boundary publishes its own inspection anchor in the containing banner.
// QoL-033: Network sandbox status text publishes an explicit active-state inspection anchor before scenario and boundary details.
// QoL-035: Network sandbox review lists each immutable fixture service before the host-operation boundary so Wi-Fi and VPN inputs are directly inspectable.
// QoL-110: Network sandbox inventory rows follow recorded recovery state after simulated operations and say unverified when the fixture outcome is unavailable.
struct KeyBrakeCommandCenterView: View {
    @ObservedObject var model: KeyBrakeViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if model.isNetworkSandbox {
                    networkSandboxBanner
                }
                statusCard
                Text(model.nextStepSentence)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("keybrake.command-center.next-step")
                if let helperFailureNotice = model.helperFailureNotice {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(helperFailureNotice)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Register Privileged Helper") {
                            model.openPrivilegedHelperSettings()
                        }
                        .accessibilityIdentifier("keybrake.command-center.open-privileged-helper")
                    }
                    .accessibilityIdentifier("keybrake.command-center.helper-not-approved")
                }
                Text("KeyBrake will not undo privacy grants, will not restart remote apps it stopped, and will not change anything it did not record.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("keybrake.command-center.limit")
                if model.isRecoveryStatusKnown && model.hasRecovery {
                    recoveryCard
                }
                emergencyActions
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

    private var networkSandboxBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "network")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Network sandbox active")
                    .font(.headline)
                    .accessibilityIdentifier("keybrake.command-center.network-sandbox-status")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scenario: \(model.networkSandboxScenario?.displayTitle ?? "Fixture simulation")")
                        .font(.subheadline.weight(.semibold))
                    Text(model.networkSandboxScenario?.displayDetail ?? "Wi-Fi and VPN are simulated with local fixtures.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("keybrake.command-center.network-sandbox-scenario")
                networkSandboxFixtureInventory
                Text("Host network, process, privacy, sharing, and user-settings persistence operations are disabled; sandbox recovery state stays in a UUID-named temporary store.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("keybrake.command-center.network-sandbox-host-boundary")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keybrake.command-center.network-sandbox-banner")
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
                .accessibilityIdentifier("keybrake.command-center.network-sandbox-service.\(service.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keybrake.command-center.network-sandbox-inventory")
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
        let initialState = service.active ? "active" : (service.enabled ? "enabled" : "disabled")
        guard let recordedRecoverySnapshot = model.unresolvedRecovery,
              let recordedNetworkChange = recordedRecoverySnapshot.networkChanges.first(where: { $0.id == service.id }) else {
            guard let device = service.device else { return initialState }
            return "\(initialState) · \(device)"
        }
        let recordedState = NetworkSandboxFixture.displayedServiceState(
            for: service,
            currentEnabled: recordedNetworkChange.currentEnabled
        )
        guard let device = service.device else { return recordedState }
        return "\(recordedState) · \(device)"
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
                    .accessibilityIdentifier("keybrake.command-center.emergency-actions.busy-guidance")
            }

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    model.stopSkynetLocally()
                } label: {
                    actionLabel(
                        title: KeyBrakeViewModel.stopLocalTypingAppsTitle,
                        description: "Stop approved local input automation without changing network or privacy settings.",
                        systemImage: "keyboard.badge.ellipsis"
                    )
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(KeyBrakeViewModel.stopSkynetLocallyDescriptor)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("keybrake.command-center.stop-local-automation")
                .accessibilityHint(commandCenterActionHint(description: "Stops approved local input automation without changing network or privacy settings", disablesWhileBusy: true))
                .disabled(model.isBusy || model.operationalState == .localAutomationStopped)

                if !model.isNetworkSandbox && !IsolationPlanPreview.affectsIsolation(for: model.isolationPolicy, approvedRemoteTargetNames: model.approvedRemoteTargetNames) {
                    Text("This plan changes nothing until you enable an isolation control or approve a remote application.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("keybrake.command-center.isolation-preview.empty")
                }
                ForEach(model.isolationPreviewLines) { line in
                    Text("\(line.title): \(line.detail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("keybrake.command-center.isolation-preview.\(line.id)")
                }

                Button {
                    model.requestStopRemoteAccess()
                } label: {
                    actionLabel(
                        title: model.isNetworkSandbox ? "Rehearse Isolation" : "Stop Remote Access",
                        description: model.isNetworkSandbox
                            ? "Run the fixture isolation plan. This does not change host network or sharing."
                            : "Confirm the isolation plan, save recovery state, then apply the selected profile.",
                        systemImage: "lock.shield"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
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
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Recovery decision required")
                            .font(.headline)
                        Text("A recovery snapshot is still available. Review the panel before you quit or consider the incident resolved.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("keybrake.command-center.recovery-decision-required")

                if let snapshot = model.unresolvedRecovery {
                    recoveryInventory(snapshot)
                }

                if model.isBusy {
                    Text("The recovery panel is temporarily unavailable while KeyBrake completes the current operation. Incident history and settings remain available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("keybrake.command-center.recovery-card.busy-guidance")
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
        .accessibilityIdentifier("keybrake.command-center.recovery-card")
    }

    private func recoveryInventory(_ snapshot: RecoverySnapshot) -> some View {
        let networkSummary = recoveryMetricDescription(snapshot.networkChanges.count, singular: "network change", plural: "network changes")
        let sharingSummary = recoveryMetricDescription(snapshot.sharingChanges.count, singular: "sharing change", plural: "sharing changes")
        let unresolvedSummary = recoveryMetricDescription(snapshot.unresolvedSteps.count, singular: "unresolved step", plural: "unresolved steps")

        return HStack(spacing: 14) {
            recoveryMetric(
                summary: networkSummary,
                systemImage: "network",
                accessibilityIdentifier: "keybrake.command-center.recovery-metric.network"
            )
            recoveryMetric(
                summary: sharingSummary,
                systemImage: "person.2.badge.gearshape",
                accessibilityIdentifier: "keybrake.command-center.recovery-metric.sharing"
            )
            recoveryMetric(
                summary: unresolvedSummary,
                systemImage: "exclamationmark.circle",
                accessibilityIdentifier: "keybrake.command-center.recovery-metric.unresolved"
            )
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recovery inventory: \(networkSummary), \(sharingSummary), \(unresolvedSummary)")
        .accessibilityIdentifier("keybrake.command-center.recovery-inventory")
    }

    private func recoveryMetricDescription(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }

    private func recoveryMetric(
        summary: String,
        systemImage: String,
        accessibilityIdentifier: String
    ) -> some View {
        Label {
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
        }
        .accessibilityLabel(summary)
        .accessibilitySortPriority(-1)
        .accessibilityIdentifier(accessibilityIdentifier)
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
                        if let helperFailureNotice = model.helperFailureNotice(for: incident) {
                            Text(helperFailureNotice)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open Register Privileged Helper") {
                                model.openPrivilegedHelperSettings()
                            }
                            .accessibilityIdentifier("keybrake.command-center.recent-activity.open-privileged-helper")
                        }
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
