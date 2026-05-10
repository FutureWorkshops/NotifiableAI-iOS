import Foundation

/// Which APNs gateway the device push token in this build is valid for.
///
/// Push tokens are environment-specific: a token issued in
/// `.development` only routes through `api.sandbox.push.apple.com`, and
/// a `.production` token only through `api.push.apple.com`. Send the
/// wrong pair and the push is silently dropped, so it's worth telling
/// the server which one it has.
public enum APNSEnvironment: String, Sendable, Codable {
    case development
    case production
    /// The build was distributed via the App Store (no embedded profile)
    /// or otherwise yielded a profile we couldn't read. Treat as production
    /// for token-routing decisions; surface it for debugging.
    case unknown
}

extension NotifiableAI {
    /// The APNs environment this build was signed for, derived from the
    /// embedded mobileprovision file.
    ///
    /// - Simulator: always `.development`. Push registration doesn't
    ///   actually work in the simulator, so this is effectively N/A.
    /// - App Store distribution: no embedded profile is present;
    ///   returns `.production`.
    /// - Development / Ad Hoc / TestFlight: parsed from the embedded
    ///   profile's `aps-environment` entitlement.
    public static var apnsEnvironment: APNSEnvironment {
        #if targetEnvironment(simulator)
        return .development
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return .production
        }
        return APNSEnvironmentParser.parse(provisioningProfile: data)
        #endif
    }
}

/// Helper that pulls `Entitlements.aps-environment` out of a CMS-wrapped
/// `.mobileprovision` blob. Exposed at file-scope (not nested) so tests can
/// drive it directly with sample data.
enum APNSEnvironmentParser {
    static func parse(provisioningProfile data: Data) -> APNSEnvironment {
        // The file is a PKCS7 envelope around a plist. Rather than pull in
        // Security framework's CMS APIs, locate the inline plist by the well-
        // known XML markers. This matches the technique every shipping app
        // I've seen uses for this question.
        // ISO Latin 1 is byte-for-byte over 0x00–0xFF, so binary DER bytes
        // outside the inner plist won't fail decoding.
        guard let text = String(data: data, encoding: .isoLatin1) else { return .unknown }
        guard let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>") else { return .unknown }
        let plistText = String(text[start.lowerBound..<end.upperBound])
        guard let plistData = plistText.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let raw = entitlements["aps-environment"] as? String,
              let env = APNSEnvironment(rawValue: raw) else {
            return .unknown
        }
        return env
    }
}
