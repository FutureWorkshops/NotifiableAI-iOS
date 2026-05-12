import Foundation

/// Escapes a string for safe interpolation inside XML element text or
/// attribute values, and strips C0 control characters (except `\t`, `\n`,
/// `\r`) that the XML 1.0 spec forbids.
enum XMLEscaper {
    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&apos;")
            default:
                if scalar.value < 0x20 && scalar != "\t" && scalar != "\n" && scalar != "\r" {
                    // Strip illegal C0 control characters.
                    continue
                }
                if scalar == "\u{7F}" {
                    continue
                }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
