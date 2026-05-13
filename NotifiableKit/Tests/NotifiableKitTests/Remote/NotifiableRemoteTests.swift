import Testing
import Foundation
@testable import NotifiableKit

// MARK: - Test stub for URLProtocol

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubbedSession() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: cfg)
}

private extension URLRequest {
    /// Drains httpBodyStream into a Data, since URLProtocol turns httpBody into a stream.
    var bodyData: Data {
        if let data = httpBody { return data }
        guard let stream = httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buf, maxLength: buf.count)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}

private func okJSON(_ status: Int = 201, _ object: [String: Any]) -> (HTTPURLResponse, Data) {
    let data = try! JSONSerialization.data(withJSONObject: object)
    let response = HTTPURLResponse(
        url: URL(string: "https://example.test")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    return (response, data)
}

// MARK: - Standalone tests

@Test func missingDeviceWriteKeyThrows() async {
    let client = NotifiableRemoteClient(baseURL: URL(string: "https://example.test")!)
    await #expect(throws: NotifiableRemoteError.self) {
        _ = try await client.registerDevice(pushToken: "abc")
    }
}

@Test(arguments: [
    ("development", APNSEnvironment.development),
    ("production", APNSEnvironment.production)
])
func parsesAPSEnvironmentFromProvisioningProfile(raw: String, expected: APNSEnvironment) {
    let blob = makeProvisioningProfile(apsEnvironment: raw)
    #expect(APNSEnvironmentParser.parse(provisioningProfile: blob) == expected)
}

@Test func returnsUnknownForGarbageProvisioningProfile() {
    #expect(APNSEnvironmentParser.parse(provisioningProfile: Data([0xff, 0xfe, 0xfd])) == .unknown)
}

@Test func returnsUnknownWhenApsEntitlementMissing() {
    let blob = makeProvisioningProfile(extraXML: "")  // no aps-environment
    #expect(APNSEnvironmentParser.parse(provisioningProfile: blob) == .unknown)
}

private func makeProvisioningProfile(apsEnvironment: String? = nil, extraXML: String? = nil) -> Data {
    let entitlement: String
    if let apsEnvironment {
        entitlement = "<key>aps-environment</key><string>\(apsEnvironment)</string>"
    } else {
        entitlement = extraXML ?? ""
    }
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Entitlements</key>
        <dict>
            \(entitlement)
        </dict>
    </dict>
    </plist>
    """
    // Wrap in pretend CMS envelope bytes — the parser scans for <?xml...</plist>.
    var data = Data([0x30, 0x82, 0x00, 0x00]) // bogus DER prefix
    data.append(plist.data(using: .ascii)!)
    data.append(Data([0x00, 0x01, 0x02])) // bogus DER suffix
    return data
}

@Test func defaultBaseURLIsProduction() {
    #expect(NotifiableRemote.defaultBaseURL.absoluteString == "https://notifiableai.fws.io")
}

@Test func inMemoryStorageRoundTrip() {
    let s = InMemoryStorage()
    s.setString("v", forKey: "k")
    #expect(s.string(forKey: "k") == "v")
    s.setString(nil, forKey: "k")
    #expect(s.string(forKey: "k") == nil)
}

// MARK: - NotifiableRemote namespace (serialized — global config + shared URLProtocol handler)

@Suite(.serialized)
struct NotifiableRemoteNamespaceTests {

    @Test func updateBeforeRegisterThrowsDeviceNotRegistered() async {
        StubURLProtocol.handler = { _ in okJSON(200, [:]) } // never reached
        NotifiableRemote.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "k",
            storage: InMemoryStorage(),
            session: stubbedSession()
        )
        await #expect(throws: NotifiableRemoteError.self) {
            _ = try await NotifiableRemote.update(pushToken: "tok")
        }
    }

    @Test func registerPersistsDeviceSecretAndId() async throws {
        let storage = InMemoryStorage()
        StubURLProtocol.handler = { req in
            #expect(req.httpMethod == "POST")
            #expect(req.url?.path == "/api/v1/devices")
            #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer the_key")
            return okJSON(201, [
                "id": 42,
                "push_token": "abc",
                "device_secret": "sek_xyz"
            ])
        }
        NotifiableRemote.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "the_key",
            storage: storage,
            session: stubbedSession()
        )
        let response = try await NotifiableRemote.register(pushToken: "abc")
        #expect(response.id == 42)
        #expect(response.deviceSecret == "sek_xyz")
        #expect(NotifiableRemote.deviceSecret == "sek_xyz")
        #expect(NotifiableRemote.deviceId == 42)
    }

    @Test func registerSendsApnsEnvironmentInPayload() async throws {
        StubURLProtocol.handler = { req in
            let json = try! JSONSerialization.jsonObject(with: req.bodyData) as! [String: Any]
            #expect(json["apns_environment"] as? String == "production")
            #expect(json["push_token"] as? String == "tok")
            return okJSON(201, ["id": 1, "push_token": "tok", "device_secret": "s"])
        }
        NotifiableRemote.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "the_key",
            storage: InMemoryStorage(),
            session: stubbedSession()
        )
        _ = try await NotifiableRemote.register(pushToken: "tok", apnsEnvironment: .production)
    }

    @Test func unregisterClearsPersistedState() async throws {
        let storage = InMemoryStorage()
        storage.setString("sek_xyz", forKey: NotifiableRemote.Keys.deviceSecret)
        storage.setString("42", forKey: NotifiableRemote.Keys.deviceId)
        StubURLProtocol.handler = { req in
            #expect(req.httpMethod == "DELETE")
            #expect(req.value(forHTTPHeaderField: "X-Device-Secret") == "sek_xyz")
            let response = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        NotifiableRemote.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "the_key",
            storage: storage,
            session: stubbedSession()
        )
        try await NotifiableRemote.unregister(pushToken: "abc")
        #expect(NotifiableRemote.deviceSecret == nil)
        #expect(NotifiableRemote.deviceId == nil)
    }
}
