import Foundation
import ChotkiCore

extension Rule {
    /// The person recorded on the rule takes precedence over today's Settings.
    /// Clearing or changing a spiritual father cannot rewrite an old rule.
    func suggestedByLabel(currentFather: String) -> String? {
        guard givenByPriest == true else { return nil }
        let saved = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !saved.isEmpty && saved != "the library" { return "Suggested by \(saved)" }
        let current = currentFather.trimmingCharacters(in: .whitespacesAndNewlines)
        return current.isEmpty ? "Suggested by a priest or spiritual father" : "Suggested by \(current)"
    }
}
