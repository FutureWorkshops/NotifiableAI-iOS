import Testing
import Foundation
@testable import NotifiableAIKit

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
    let client = NotifiableAIClient(baseURL: URL(string: "https://example.test")!)
    await #expect(throws: NotifiableAIError.self) {
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
    #expect(NotifiableAI.defaultBaseURL.absoluteString == "https://notifiableai.fws.io")
}

@Test func inMemoryStorageRoundTrip() {
    let s = InMemoryStorage()
    s.setString("v", forKey: "k")
    #expect(s.string(forKey: "k") == "v")
    s.setString(nil, forKey: "k")
    #expect(s.string(forKey: "k") == nil)
}

// MARK: - NotifiableAI namespace (serialized — global config + shared URLProtocol handler)

@Suite(.serialized)
struct NotifiableAINamespaceTests {

    @Test func updateBeforeRegisterThrowsDeviceNotRegistered() async {
        StubURLProtocol.handler = { _ in okJSON(200, [:]) } // never reached
        NotifiableAI.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "k",
            storage: InMemoryStorage(),
            session: stubbedSession()
        )
        await #expect(throws: NotifiableAIError.self) {
            _ = try await NotifiableAI.update(pushToken: "tok")
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
        NotifiableAI.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "the_key",
            storage: storage,
            session: stubbedSession()
        )
        let response = try await NotifiableAI.register(pushToken: "abc")
        #expect(response.id == 42)
        #expect(response.deviceSecret == "sek_xyz")
        #expect(NotifiableAI.deviceSecret == "sek_xyz")
        #expect(NotifiableAI.deviceId == 42)
    }

    @Test func unregisterClearsPersistedState() async throws {
        let storage = InMemoryStorage()
        storage.setString("sek_xyz", forKey: NotifiableAI.Keys.deviceSecret)
        storage.setString("42", forKey: NotifiableAI.Keys.deviceId)
        StubURLProtocol.handler = { req in
            #expect(req.httpMethod == "DELETE")
            #expect(req.value(forHTTPHeaderField: "X-Device-Secret") == "sek_xyz")
            let response = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        NotifiableAI.configure(
            baseURL: URL(string: "https://example.test")!,
            apiKey: "the_key",
            storage: storage,
            session: stubbedSession()
        )
        try await NotifiableAI.unregister(pushToken: "abc")
        #expect(NotifiableAI.deviceSecret == nil)
        #expect(NotifiableAI.deviceId == nil)
    }
}
