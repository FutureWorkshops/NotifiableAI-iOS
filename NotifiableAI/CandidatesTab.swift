import SwiftUI
import NotifiableKit

struct CandidatesTab: View {
    @EnvironmentObject var harness: TestHarness

    var body: some View {
        NavigationStack {
            Form {
                engineSection
                preferencesSection
                candidateSection
                actionsSection
            }
            .navigationTitle("Candidates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if harness.inFlight > 0 {
                        ProgressView()
                    }
                }
            }
        }
    }

    private var engineSection: some View {
        Section {
            HStack {
                Text("Domain").foregroundStyle(.secondary)
                Spacer()
                TextField("", text: $harness.intelligenceDomain)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Stepper(value: $harness.tokenBudget, in: 100...2_000, step: 50) {
                HStack {
                    Text("Token budget").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(harness.tokenBudget)").monospacedDigit()
                }
            }
        } header: {
            Text("Engine")
        } footer: {
            Text("On-device decisioning via Foundation Models. Requires Apple Intelligence enabled.")
        }
    }

    private var preferencesSection: some View {
        Section {
            ForEach($harness.preferenceDrafts) { $draft in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Key", text: $draft.key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Picker("", selection: $draft.confidence) {
                            Text("Explicit").tag(NotifiableDecide.Confidence.explicit)
                            Text("Inferred").tag(NotifiableDecide.Confidence.inferred)
                            Text("Decayed").tag(NotifiableDecide.Confidence.decayed)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    TextField("Value", text: $draft.value)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.footnote, design: .monospaced))
                }
            }
            .onDelete { idx in
                harness.preferenceDrafts.remove(atOffsets: idx)
            }
            Button {
                harness.preferenceDrafts.append(PreferenceDraft())
            } label: {
                Label("Add preference", systemImage: "plus.circle")
            }
        } header: {
            Text("Preferences")
        } footer: {
            Text("Demo only supports string-valued preferences. The kit's PreferenceValue also supports lists, numbers, booleans, ranges and time windows.")
        }
    }

    private var candidateSection: some View {
        Section {
            HStack {
                Text("ID").foregroundStyle(.secondary)
                Spacer()
                TextField("", text: $harness.candidate.id)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("Type").foregroundStyle(.secondary)
                Spacer()
                TextField("", text: $harness.candidate.type)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("Subject").foregroundStyle(.secondary)
                Spacer()
                TextField("", text: $harness.candidate.subject)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            DatePicker("Occurs at", selection: $harness.candidate.occursAt)
            VStack(alignment: .leading) {
                HStack {
                    Text("Significance").foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", harness.candidate.significance))
                        .monospacedDigit()
                }
                Slider(value: $harness.candidate.significance, in: 0...1)
            }
            HStack {
                TextField("Attr key", text: $harness.candidate.attributeKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Attr value", text: $harness.candidate.attributeValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .font(.system(.footnote, design: .monospaced))
        } header: {
            Text("Candidate event")
        } footer: {
            Text("A single candidate per Decide call. The kit's API takes [CandidateEvent].")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                harness.decide()
            } label: {
                Label("Decide", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } footer: {
            Text("Result appears on the Log tab.")
        }
    }
}

#Preview {
    CandidatesTab().environmentObject(TestHarness())
}
