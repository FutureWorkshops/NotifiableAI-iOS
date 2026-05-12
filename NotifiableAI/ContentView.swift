import SwiftUI
import UIKit
import NotifiableAIKit

struct ContentView: View {
    @EnvironmentObject var harness: TestHarness

    var body: some View {
        TabView {
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gear") }

            CandidatesTab()
                .tabItem { Label("Candidates", systemImage: "sparkles") }

            LogTab()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .badge(harness.log.isEmpty ? 0 : harness.log.count)
        }
    }
}

private struct SettingsTab: View {
    @EnvironmentObject var harness: TestHarness

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledTextField(label: "Base URL", text: $harness.baseURLString, clearable: true, keyboard: .URL)
                    LabeledTextField(label: "Device Write Key", text: $harness.deviceWriteKey, secure: true, clearable: true)
                }

                Section("Device") {
                    LabeledReadOnlyField(label: "APNs Environment", value: NotifiableAI.apnsEnvironment.rawValue)
                    LabeledReadOnlyField(label: "Push Token", value: harness.pushToken)
                    Picker("Push Type", selection: $harness.pushType) {
                        ForEach(PushType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    LabeledTextField(label: "App Version", text: $harness.appVersion)
                    LabeledTextField(label: "Locale", text: $harness.locale)
                    LabeledReadOnlyField(label: "Device Secret", value: harness.deviceSecret)
                    HStack {
                        Button("Register", action: harness.registerDevice)
                            .buttonStyle(.borderedProminent)
                        Button("Update", action: harness.updateDevice)
                        Button("Delete", role: .destructive, action: harness.deleteDevice)
                    }
                }

                Section {
                    LabeledTextField(label: "Activity ID", text: $harness.activityId)
                    HStack {
                        Button("Register", action: harness.registerLiveActivity)
                            .buttonStyle(.borderedProminent)
                        Button("End", role: .destructive, action: harness.endLiveActivity)
                    }
                } header: {
                    Text("Live Activity")
                } footer: {
                    Text("ActivityKit sets the initial ContentState locally. Updates are server-pushed via APNs — the server never receives content from the client.")
                }
            }
            .navigationTitle("Settings")
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
}

private struct LogTab: View {
    @EnvironmentObject var harness: TestHarness

    var body: some View {
        NavigationStack {
            Group {
                if harness.log.isEmpty {
                    ContentUnavailableView("No activity yet", systemImage: "list.bullet.rectangle", description: Text("Run a request from the Settings tab."))
                } else {
                    List {
                        ForEach(harness.log.reversed()) { entry in
                            LogRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if harness.inFlight > 0 {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Clear", action: harness.clearLog)
                        .disabled(harness.log.isEmpty)
                }
            }
        }
    }
}

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var secure: Bool = false
    var clearable: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .multilineTextAlignment(.trailing)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if clearable && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear \(label)")
            }
        }
    }
}

private struct LabeledReadOnlyField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if value.isEmpty {
                Text("—").foregroundStyle(.tertiary)
            } else {
                Text(value)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: 220, alignment: .trailing)
                Button {
                    copy(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .imageScale(.small)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy \(label)")
            }
        }
    }

    private func copy(_ s: String) {
        UIPasteboard.general.string = s
    }
}

private struct LogRow: View {
    let entry: TestHarness.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var icon: String {
        switch entry.kind {
        case .info: "info.circle"
        case .request: "arrow.up.circle"
        case .success: "checkmark.circle"
        case .failure: "xmark.octagon"
        }
    }

    private var color: Color {
        switch entry.kind {
        case .info: .secondary
        case .request: .blue
        case .success: .green
        case .failure: .red
        }
    }
}

#Preview {
    ContentView().environmentObject(TestHarness())
}
