import KeyBrakeCore
import SwiftUI

struct IncidentLogView: View {
    @ObservedObject var model: KeyBrakeViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Incident Log").font(.title2.weight(.semibold))
                Spacer()
                Button("Clear Resolved History…") { model.clearResolvedHistory() }
            }
            Text("The log records observable actions and outcomes. It does not make a conclusion about compromise.")
                .foregroundStyle(.secondary)
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
        }
        .padding()
    }
}
