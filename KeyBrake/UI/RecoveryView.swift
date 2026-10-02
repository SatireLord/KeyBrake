import KeyBrakeCore
import SwiftUI

// Greppable:
// canonical: keybrake-recovery-decision-surface
// aliases: recovery decision panel; mouse recovery; restore review
// forms: keybrake-recovery-decision-surface; Open Recovery Panel; Keep Isolation
// descriptors: recovery inventory; reversible restore; pending decision
// states: recovery-required; restoring; partially-restored; retained
// consumers: RecoveryPanelController; KeyBrakeViewModel; KeyBrakeCommandCenterView
// owner: RecoveryView
// QoL-002: the recovery state card reuses the shared state hierarchy so the decision panel explains status before actions.
// QoL-003: the recovery state card stays honest while launch hydration is incomplete by showing the shared checking state.
// QoL-009: state-changing recovery actions explain their busy disabled state while review actions remain available.
// QoL-042: the Recovery quit affordance follows the existing busy termination guard while Keep Isolation remains available.
// QoL-111: the recorded recovery inventory publishes stable parent and metric inspection anchors without changing its counts or recovery actions.
// QoL-112: the recovery busy-state guidance exposes a stable inspection anchor without changing its visible copy or busy gates.
// QoL-113: the recovery close-language guidance exposes a stable inspection anchor without changing panel-close or Keep Isolation semantics.
// QoL-114: the recovery action-boundary guidance exposes a stable inspection anchor without changing restore handlers or recovery scope.
// QoL-115: the recovery state-summary GroupBox is a containing inspection surface while preserving the existing state-summary identifier and visible copy.
// QoL-116: the recovery panel root exposes a stable inspection anchor without changing layout or recovery behavior.
// QoL-117: the recovery panel header exposes a stable combined inspection surface without changing visible copy or recovery routing.
// QoL-118: each recovery action combines its visible title and explanation into one inspectable accessibility surface without changing handlers or gates.
struct RecoveryView: View {
    @ObservedObject var model: KeyBrakeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                stateSummary
                recoveryInventory

                Text("Choose a bounded action. KeyBrake restores only state that it recorded and can still verify.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("keybrake.recovery.action-boundary")

                if model.isBusy {
                    Text("State-changing recovery actions are temporarily unavailable while KeyBrake completes the current operation. Review actions remain available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("keybrake.recovery.busy-guidance")
                }

                Divider()

                recoveryAction(
                    title: "Restore Network",
                    description: "Restore recorded network services that were enabled before KeyBrake isolated them.",
                    systemImage: "network",
                    identifier: "keybrake.recovery.restore-network",
                    prominent: true
                ) {
                    model.restoreNetworkOnly()
                }

                recoveryAction(
                    title: "Restore Previously Enabled Sharing Services",
                    description: "Restore only the sharing services that were enabled before KeyBrake changed them.",
                    systemImage: "person.2.badge.gearshape",
                    identifier: "keybrake.recovery.restore-sharing",
                    prominent: false
                ) {
                    model.restoreSharingOnly()
                }

                recoveryAction(
                    title: "Restart Espanso",
                    description: "Restart local input automation separately from network and sharing recovery.",
                    systemImage: "arrow.clockwise.circle",
                    identifier: "keybrake.recovery.restart-espanso",
                    prominent: false
                ) {
                    model.restartEspanso()
                }

                recoveryAction(
                    title: "Open Privacy & Security Settings",
                    description: "Review privacy permissions manually. KeyBrake never restores reset privacy grants automatically.",
                    systemImage: "lock.shield",
                    identifier: "keybrake.recovery.open-privacy-settings",
                    prominent: false,
                    disablesWhileBusy: false
                ) {
                    model.openPrivacySettings()
                }

                recoveryAction(
                    title: "Open Incident Log",
                    description: "Review the exact operation steps and outcomes recorded for this recovery decision.",
                    systemImage: "list.bullet.clipboard",
                    identifier: "keybrake.recovery.open-incident-log",
                    prominent: false,
                    disablesWhileBusy: false
                ) {
                    model.openIncidentLog()
                }

                Divider()

                HStack(spacing: 10) {
                    Button("Keep Isolation") { model.keepIsolation() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("keybrake.recovery.keep-isolation")
                        .help("Closes this panel while keeping the recovery decision pending")
                        .accessibilityHint("Closes this panel while keeping the recovery decision pending")

                    Button("Quit KeyBrake", role: .destructive) { model.requestQuit() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("keybrake.recovery.quit")
                        .help(recoveryQuitActionHint)
                        .accessibilityHint(recoveryQuitActionHint)
                        .disabled(model.isBusy)
                }

                Text("Closing this panel does not resolve the recovery decision.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("keybrake.recovery.close-language")
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 560)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("KeyBrake Recovery")
        .accessibilityIdentifier("keybrake.recovery.panel")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text("KeyBrake Recovery")
                    .font(.title2.weight(.semibold))
                Text("Review what changed, then choose exactly which state to restore.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("KeyBrake Recovery. Review what changed, then choose exactly which state to restore.")
        .accessibilityIdentifier("keybrake.recovery.header")
    }

    private var stateSummary: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: model.isRecoveryStatusKnown ? KeyBrakeStatusPresentation.symbol(for: model.operationalState) : "hourglass")
                    .font(.title2)
                    .foregroundStyle(
                        model.isRecoveryStatusKnown
                            ? KeyBrakeStatusPresentation.tint(for: model.operationalState)
                            : Color.secondary
                    )
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Current state")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.isRecoveryStatusKnown ? model.operationalState.displayTitle : "Checking Recovery Status")
                        .font(.headline)
                    Text(
                        model.isRecoveryStatusKnown
                            ? KeyBrakeStatusPresentation.detail(for: model.operationalState)
                            : "KeyBrake is confirming whether an unresolved recovery snapshot exists."
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Recovery stays available until the selected restoration steps are verified or you explicitly keep isolation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } label: {
            Label("Recovery status", systemImage: "exclamationmark.triangle.fill")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keybrake.recovery.state-summary")
    }

    @ViewBuilder
    private var recoveryInventory: some View {
        if let snapshot = model.unresolvedRecovery {
            GroupBox {
                HStack(spacing: 14) {
                    recoveryMetric(value: snapshot.networkChanges.count, label: "network", systemImage: "network", identifier: "keybrake.recovery.inventory.network")
                    recoveryMetric(value: snapshot.sharingChanges.count, label: "sharing", systemImage: "person.2.badge.gearshape", identifier: "keybrake.recovery.inventory.sharing")
                    recoveryMetric(value: snapshot.unresolvedSteps.count, label: "unresolved", systemImage: "exclamationmark.circle", identifier: "keybrake.recovery.inventory.unresolved")
                    recoveryMetric(value: snapshot.privacyResetRequests.count, label: "privacy review", systemImage: "lock.shield", identifier: "keybrake.recovery.inventory.privacy-review")
                }
            } label: {
                Text("Recorded recovery inventory")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Recorded recovery inventory: \(snapshot.networkChanges.count) network changes, \(snapshot.sharingChanges.count) sharing changes, \(snapshot.unresolvedSteps.count) unresolved steps, \(snapshot.privacyResetRequests.count) privacy reviews")
            .accessibilityIdentifier("keybrake.recovery.inventory")
        }
    }

    private func recoveryMetric(value: Int, label: String, systemImage: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("\(value)", systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func recoveryAction(
        title: String,
        description: String,
        systemImage: String,
        identifier: String,
        prominent: Bool,
        disablesWhileBusy: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if prominent {
                Button(action: action) {
                    recoveryActionLabel(title: title, description: description, systemImage: systemImage, prominent: prominent)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button(action: action) {
                    recoveryActionLabel(title: title, description: description, systemImage: systemImage, prominent: prominent)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityIdentifier(identifier)
        .help(recoveryActionHint(description: description, disablesWhileBusy: disablesWhileBusy))
        .accessibilityHint(recoveryActionHint(description: description, disablesWhileBusy: disablesWhileBusy))
        .disabled(disablesWhileBusy && model.isBusy)
    }

    private func recoveryActionHint(description: String, disablesWhileBusy: Bool) -> String {
        guard disablesWhileBusy && model.isBusy else { return description }
        return "Unavailable while KeyBrake completes the current operation."
    }

    private var recoveryQuitActionHint: String {
        model.isBusy
            ? "Unavailable while KeyBrake completes the current operation."
            : "Requests quit and keeps the unresolved recovery warning when required"
    }

    private func recoveryActionLabel(title: String, description: String, systemImage: String, prominent: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(prominent ? Color.white : Color.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(prominent ? Color.white.opacity(0.9) : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
