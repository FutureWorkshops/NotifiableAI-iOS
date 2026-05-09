import Foundation
import Combine
import NotifiableAIKit

@MainActor
final class TestHarness: ObservableObject {
    struct LogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let kind: Kind
        let message: String

        enum Kind: String { case info, request, success, failure }
    }

    // Connection
    @Published var baseURLString: String = UserDefaults.standard.string(forKey: "baseURL") ?? "https://notifiableai-staging-840e1798d5e1.herokuapp.com"
    @Published var deviceWriteKey: String = UserDefaults.standard.string(forKey: "deviceWriteKey") ?? ""

    // Device
    @Published var pushToken: String = UserDefaults.standard.string(forKey: "pushToken") ?? ""
    @Published var pushType: PushType = .alert
    @Published var appVersion: String = "1.0.0"
    @Published var locale: String = Locale.current.identifier
    @Published var deviceSecret: String = UserDefaults.standard.string(forKey: "deviceSecret") ?? ""

    // Live activity
    @Published var activityId: String = ""

    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var inFlight: Int = 0

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .pushTokenAvailable, object: nil, queue: .main) { [weak self] note in
            guard let self, let token = note.userInfo?["token"] as? String else { return }
            Task { @MainActor in
                self.pushToken = token
                self.append(.info, "APNs token received: \(token)")
                self.persist()
            }
        })
        observers.append(center.addObserver(forName: .pushRegistrationFailed, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            let err = (note.userInfo?["error"] as? String) ?? "unknown"
            Task { @MainActor in
                self.append(.failure, "Push registration failed: \(err)")
            }
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func persist() {
        let d = UserDefaults.standard
        d.set(baseURLString, forKey: "baseURL")
        d.set(deviceWriteKey, forKey: "deviceWriteKey")
        d.set(pushToken, forKey: "pushToken")
        d.set(deviceSecret, forKey: "deviceSecret")
    }

    func clearLog() { log.removeAll() }

    private func client() throws -> NotifiableAIClient {
        guard let url = URL(string: baseURLString), url.scheme != nil else {
            throw NotifiableAIError.invalidResponse
        }
        return NotifiableAIClient(
            baseURL: url,
            deviceWriteKey: deviceWriteKey.isEmpty ? nil : deviceWriteKey
        )
    }

    private func append(_ kind: LogEntry.Kind, _ message: String) {
        log.append(LogEntry(timestamp: Date(), kind: kind, message: message))
    }

    private func run(_ name: String, _ work: @escaping () async throws -> String) {
        persist()
        append(.request, name)
        inFlight += 1
        Task {
            do {
                let result = try await work()
                append(.success, "\(name) ✓ — \(result)")
            } catch {
                append(.failure, "\(name) ✗ — \(error)")
            }
            inFlight -= 1
        }
    }

    // MARK: - Actions

    func registerDevice() {
        run("Register device") { [self] in
            let c = try client()
            let resp = try await c.registerDevice(
                pushToken: pushToken,
                pushType: pushType,
                appVersion: appVersion.isEmpty ? nil : appVersion,
                locale: locale.isEmpty ? nil : locale
            )
            if let secret = resp.deviceSecret {
                self.deviceSecret = secret
                self.persist()
            }
            return "id=\(resp.id) secret=\(resp.deviceSecret ?? "—")"
        }
    }

    func updateDevice() {
        run("Update device") { [self] in
            let c = try client()
            let resp = try await c.updateDevice(
                pushToken: pushToken,
                deviceSecret: deviceSecret,
                pushType: pushType,
                appVersion: appVersion.isEmpty ? nil : appVersion,
                locale: locale.isEmpty ? nil : locale
            )
            return "id=\(resp.id) lastSeen=\(resp.lastSeenAt.map { "\($0)" } ?? "—")"
        }
    }

    func deleteDevice() {
        run("Delete device") { [self] in
            let c = try client()
            try await c.deleteDevice(pushToken: pushToken, deviceSecret: deviceSecret)
            return "204"
        }
    }

    func registerLiveActivity() {
        run("Register live activity") { [self] in
            let c = try client()
            let resp = try await c.registerLiveActivity(
                activityId: activityId,
                pushToken: pushToken
            )
            if let secret = resp.deviceSecret {
                self.deviceSecret = secret
                self.persist()
            }
            return "id=\(resp.id) activity=\(resp.activityId)"
        }
    }

    func endLiveActivity() {
        run("End live activity") { [self] in
            let c = try client()
            try await c.endLiveActivity(activityId: activityId, deviceSecret: deviceSecret)
            return "204"
        }
    }

}
