import Foundation

public struct NotifiableAIClient: Sendable {
    public let baseURL: URL
    public var deviceWriteKey: String?
    public var session: URLSession

    public init(
        baseURL: URL,
        deviceWriteKey: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.deviceWriteKey = deviceWriteKey
        self.session = session
    }

    // MARK: - Devices

    public func registerDevice(
        pushToken: String,
        pushType: PushType = .alert,
        appVersion: String? = nil,
        locale: String? = nil,
        apnsEnvironment: APNSEnvironment? = nil
    ) async throws -> DeviceResponse {
        let body: [String: Any?] = [
            "push_token": pushToken,
            "push_type": pushType.rawValue,
            "app_version": appVersion,
            "locale": locale,
            "apns_environment": apnsEnvironment?.rawValue
        ]
        return try await send(
            method: "POST",
            path: "/api/v1/devices",
            body: body.compactMapValues { $0 }
        )
    }

    public func updateDevice(
        pushToken: String,
        deviceSecret: String,
        pushType: PushType? = nil,
        appVersion: String? = nil,
        locale: String? = nil
    ) async throws -> DeviceResponse {
        let body: [String: Any?] = [
            "push_type": pushType?.rawValue,
            "app_version": appVersion,
            "locale": locale
        ]
        return try await send(
            method: "PATCH",
            path: "/api/v1/devices/\(pathEscape(pushToken))",
            body: body.compactMapValues { $0 },
            extraHeaders: ["X-Device-Secret": deviceSecret]
        )
    }

    public func deleteDevice(pushToken: String, deviceSecret: String) async throws {
        let _: EmptyResponse = try await send(
            method: "DELETE",
            path: "/api/v1/devices/\(pathEscape(pushToken))",
            body: nil,
            extraHeaders: ["X-Device-Secret": deviceSecret],
            allowEmpty: true
        )
    }

    // MARK: - Live Activities

    /// Register a Live Activity with the server.
    ///
    /// The server stores only the metadata it needs to push updates to the activity;
    /// it does not accept the activity's content state. The initial `ContentState`
    /// is set locally by ActivityKit on the device, and subsequent updates are
    /// pushed by your backend through APNs.
    public func registerLiveActivity(
        activityId: String,
        pushToken: String,
        appVersion: String? = nil,
        locale: String? = nil
    ) async throws -> LiveActivityResponse {
        var body: [String: Any] = [
            "activity_id": activityId,
            "push_token": pushToken
        ]
        if let appVersion { body["app_version"] = appVersion }
        if let locale { body["locale"] = locale }
        return try await send(
            method: "POST",
            path: "/api/v1/live_activities",
            body: body
        )
    }

    public func endLiveActivity(activityId: String, deviceSecret: String) async throws {
        let _: EmptyResponse = try await send(
            method: "DELETE",
            path: "/api/v1/live_activities/\(pathEscape(activityId))",
            body: nil,
            extraHeaders: ["X-Device-Secret": deviceSecret],
            allowEmpty: true
        )
    }

    // MARK: - Internals

    private func send<T: Decodable>(
        method: String,
        path: String,
        body: [String: Any]?,
        extraHeaders: [String: String] = [:],
        allowEmpty: Bool = false
    ) async throws -> T {
        guard let token = deviceWriteKey, !token.isEmpty else {
            throw NotifiableAIError.missingAPIKey("device_write")
        }

        let url = baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in extraHeaders { request.setValue(v, forHTTPHeaderField: k) }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NotifiableAIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw NotifiableAIError.http(status: http.statusCode, message: message)
        }

        if allowEmpty, data.isEmpty || http.statusCode == 204 {
            return EmptyResponse() as! T
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NotifiableAIError.decoding(error)
        }
    }

    private func pathEscape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    private struct ErrorBody: Decodable { let error: String? }
}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
