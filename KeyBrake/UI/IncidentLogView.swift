import KeyBrakeCore
import SwiftUI

// Greppable:
// canonical: keybrake-incident-log-destination
// aliases: incident history; operation record; outcome log
// forms: keybrake-incident-log-destination; Incident Log; Clear Resolved History
// descriptors: recorded outcomes; pending recovery; empty incident state
// states: empty; incident-present; recovery-required
// consumers: KeyBrakeCommandCenterView; KeyBrakeMenuView; KeyBrakeViewModel
// owner: IncidentLogView
// QoL-001: clear-history availability follows recorded resolved outcomes; storage mutation remains owned by KeyBrakeViewModel.clearResolvedHistory.
// QoL-005: the recovery summary stays in a checking state until launch recovery hydration is complete.
// QoL-037: recorded incidents expose status, exact update timing, step outcomes, and persisted UUID inspection anchors without changing storage or recovery behavior.
struct IncidentLogView: View {
    @ObservedObject var model: KeyBrakeViewModel

    private var incidentCountTitle: String {
        let count = model.incidents.count
        return "\(count) recorded \(count == 1 ? "incident" : "incidents")"
    }

    private var resolvedIncidentCount: Int {
        model.incidents.reduce(into: 0) { count, incident in
            if incident.finalState == .normal {
                count += 1
            }
        }
    }

    private var resolvedHistoryAvailabilityDetail: String {
        switch resolvedIncidentCount {
        case 0:
            return "No resolved records are available to clear."
        case 1:
            return "1 resolved record can be cleared from this view."
        default:
            return "\(resolvedIncidentCount) resolved records can be cleared from this view."
        }
    }

    private var recoveryStatusTitle: String {
        guard model.isRecoveryStatusKnown else { return "Checking Recovery Status" }
        return model.hasRecovery ? "Recovery decision pending" : "No recovery decision pending"
    }

    private var recoveryStatusDetail: String {
        guard model.isRecoveryStatusKnown else {
            return "KeyBrake is confirming whether an unresolved recovery snapshot exists."
        }
        return model.hasRecovery
            ? "Use the recovery panel to choose the next action."
            : "KeyBrake has no unresolved recovery snapshot."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("Incident Log").font(.title2.weight(.semibold))
                Spacer()
                Button("Export Incidents…") {
                    model.exportIncidents()
                }
                .accessibilityIdentifier("keybrake.incident-log.export")
                .help("Writes operation metadata to a JSON file. Credentials and TCC contents are not included.")
                .disabled(model.incidents.isEmpty)
                Button("Clear Resolved History…") {
                    model.clearResolvedHistory()
                }
                .accessibilityIdentifier("keybrake.incident-log.clear-resolved-history")
                .accessibilityHint("Removes only incident records that ended in the normal state.")
                .accessibilityValue("\(resolvedIncidentCount) resolved \(resolvedIncidentCount == 1 ? "record" : "records") available to clear")
                .help(resolvedHistoryAvailabilityDetail)
                .disabled(resolvedIncidentCount == 0)
            }
            Text("The log records observable actions and outcomes. It does not make a conclusion about compromise.")
                .foregroundStyle(.secondary)

            HStack(spacing: 18) {
                summaryItem(title: incidentCountTitle, detail: "Observable operation records")
                Divider()
                    .frame(height: 34)
                summaryItem(title: recoveryStatusTitle, detail: recoveryStatusDetail)
            }
            .accessibilityIdentifier("keybrake.incident-log.summary")

            Text(resolvedHistoryAvailabilityDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.incidents.isEmpty {
                emptyState
            } else {
                List(model.incidents) { incident in
                    incidentRow(incident)
                }
                .accessibilityIdentifier("keybrake.incident-log.list")
            }
        }
        .padding()
    }

    private func incidentRow(_ incident: IncidentRecord) -> some View {
        DisclosureGroup {
            if incident.steps.isEmpty {
                Text("No operation steps were recorded for this entry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("keybrake.incident-log.entry.\(incident.id.uuidString).empty")
            } else {
                ForEach(incident.steps) { step in
                    incidentStep(step, incidentID: incident.id)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: KeyBrakeStatusPresentation.symbol(for: incident.finalState))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KeyBrakeStatusPresentation.tint(for: incident.finalState))
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(incident.initiatingAction)
                            .font(.headline)
                        Spacer(minLength: 8)
                        HStack(spacing: 5) {
                            Text(incident.updatedAt, style: .date)
                            Text("·")
                            Text(incident.updatedAt, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Text(incident.finalState.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KeyBrakeStatusPresentation.tint(for: incident.finalState))
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(incident.steps.count) recorded \(incident.steps.count == 1 ? "step" : "steps")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(incident.resolution)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("keybrake.incident-log.entry.\(incident.id.uuidString)")
            .accessibilityHint("Expands to show the recorded operation steps")
        }
    }

    private func incidentStep(_ step: OperationStepResult, incidentID: UUID) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: operationOutcomeSymbol(for: step.outcome))
                .foregroundStyle(operationOutcomeTint(for: step.outcome))
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.targetDisplayName)
                        .font(.callout.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(step.outcome.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(operationOutcomeTint(for: step.outcome))
                }

                Text(step.operationDescription)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                if let observedPreState = step.observedPreState, let observedPostState = step.observedPostState {
                    Text("Observed: \(observedPreState) → \(observedPostState)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let observedPostState = step.observedPostState {
                    Text("Observed: \(observedPostState)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("keybrake.incident-log.entry.\(incidentID.uuidString).step.\(step.id.uuidString)")
    }

    private func operationOutcomeSymbol(for outcome: OperationOutcome) -> String {
        switch outcome {
        case .planned:
            return "circle.dotted"
        case .attempted:
            return "arrow.right.circle"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .skipped:
            return "forward.end"
        case .unsupported:
            return "questionmark.circle"
        case .conflict:
            return "exclamationmark.triangle.fill"
        case .alreadyInDesiredState:
            return "checkmark.circle"
        }
    }

    private func operationOutcomeTint(for outcome: OperationOutcome) -> Color {
        switch outcome {
        case .succeeded, .alreadyInDesiredState:
            return .green
        case .failed, .conflict:
            return .red
        case .unsupported:
            return .orange
        case .skipped:
            return .secondary
        case .planned, .attempted:
            return .blue
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No incidents recorded")
                .font(.headline)
            Text("KeyBrake will show observable actions and outcomes here after an emergency operation.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("keybrake.incident-log.empty-state")
    }

    private func summaryItem(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
