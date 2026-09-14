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
struct IncidentLogView: View {
    @ObservedObject var model: KeyBrakeViewModel

    private var incidentCountTitle: String {
        let count = model.incidents.count
        return "\(count) recorded \(count == 1 ? "incident" : "incidents")"
    }

    private var recoveryStatusTitle: String {
        model.hasRecovery ? "Recovery decision pending" : "No recovery decision pending"
    }

    private var recoveryStatusDetail: String {
        model.hasRecovery
            ? "Use the recovery panel to choose the next action."
            : "KeyBrake has no unresolved recovery snapshot."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("Incident Log").font(.title2.weight(.semibold))
                Spacer()
                Button("Clear Resolved History…") {
                    model.clearResolvedHistory()
                }
                .accessibilityIdentifier("keybrake.incident-log.clear-resolved-history")
                .accessibilityHint("Removes only incident records that ended in the normal state.")
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

            if model.incidents.isEmpty {
                emptyState
            } else {
                List(model.incidents) { incident in
                    DisclosureGroup {
                        ForEach(incident.steps) { step in
                            Text("\(step.targetDisplayName): \(step.operationDescription) [\(step.outcome.displayTitle)]")
                                .font(.callout)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(incident.initiatingAction).font(.headline)
                            Text("\(incident.finalState.displayTitle) · \(incident.resolution)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("keybrake.incident-log.list")
            }
        }
        .padding()
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
