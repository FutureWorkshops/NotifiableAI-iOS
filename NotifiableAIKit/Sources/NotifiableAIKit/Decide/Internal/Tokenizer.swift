import Foundation

/// Approximate token estimator: `characters / 4`, rounded up.
///
/// Foundation Models exposes a post-call token count; the assembler uses this
/// approximation to prune the context block before the model is invoked.
struct Tokenizer: Sendable {
    static let `default` = Tokenizer()

    func estimate(_ text: String) -> Int {
        let count = text.count
        if count == 0 { return 0 }
        return (count + 3) / 4
    }
}
