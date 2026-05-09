import SwiftUI
import NotifiableAIKit

struct ContentView: View {
    @EnvironmentObject var harness: TestHarness

    var body: some View {
        TabView {
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gear") }

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
                    LabeledTextField(label: "Base URL", text: $harness.baseURLString, keyboard: .URL)
                    LabeledTextField(label: "Device Write Key", text: $harness.deviceWriteKey, secure: true)
                }

                Section("Device") {
                    LabeledTextField(label: "Push Token", text: $harness.pushToken)
                    Picker("Push Type", selection: $harness.pushType) {
                        ForEach(PushType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    LabeledTextField(label: "App Version", text: $harness.appVersion)
                    LabeledTextField(label: "Locale", text: $harness.locale)
                    LabeledTextField(label: "Device Secret", text: $harness.deviceSecret, secure: true)
                    HStack {
                        Button("Register", action: harness.registerDevice)
                            .buttonStyle(.borderedProminent)
                        Button("Update", action: harness.updateDevice)
                        Button("Delete", role: .destructive, action: harness.deleteDevice)
                    }
                }

                Section("Live Activity") {
                    LabeledTextField(label: "Activity ID", text: $harness.activityId)
                    VStack(alignment: .leading) {
                        Text("Content State (JSON)").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $harness.contentStateJSON)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 60)
                    }
                    HStack {
                        Button("Start", action: harness.startLiveActivity)
                            .buttonStyle(.borderedProminent)
                        Button("End", role: .destructive, action: harness.endLiveActivity)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
    #if os(iOS)
    var keyboard: UIKeyboardType = .default
    #else
    var keyboard: Int = 0
    #endif

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
            #if os(iOS)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
        }
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
