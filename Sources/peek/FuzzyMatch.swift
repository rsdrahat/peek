import Foundation

/// Tiny subsequence-based fuzzy matcher tuned for file paths.
///
/// Returns `nil` when the query characters don't appear in order inside the
/// candidate; otherwise returns a score where higher = better. Scoring rules:
///
/// - Strong bonus for matching the very first character of the candidate
///   (prefix hits dominate).
/// - Bonus for matching at the start of a path component / word — i.e.
///   directly after `/`, `_`, `-`, `.`, or whitespace. This makes
///   "rdme" beat "ame" when looking for "README.md".
/// - Cumulative bonus for runs of contiguous matches; "auth" beats
///   "a___u___t___h" even on the same candidate.
/// - Small per-gap penalty so fewer-skip matches edge out scattered ones.
/// - Small length penalty so short candidates win ties.
///
/// The algorithm is greedy left-to-right, which means it sometimes commits
/// to an earlier match position when a later one would have scored higher.
/// In practice that's rare for query lengths typed in a palette and the
/// simplicity is worth it. Revisit if real queries reveal mis-rankings.
enum FuzzyMatch {
    static func score(query: String, in candidate: String) -> Double? {
        if query.isEmpty { return 0 }
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        guard !c.isEmpty else { return nil }

        var qi = 0
        var lastMatch: Int? = nil
        var contiguous: Double = 0
        var total: Double = 0

        for (i, ch) in c.enumerated() {
            guard qi < q.count else { break }
            guard ch == q[qi] else { continue }

            var bonus: Double = 1
            if i == 0 {
                bonus += 8
            } else {
                let prev = c[i - 1]
                if prev == "/" || prev == "_" || prev == "-" || prev == "." || prev == " " {
                    bonus += 3
                }
            }

            if let last = lastMatch, i == last + 1 {
                contiguous += 2
                bonus += contiguous
            } else {
                contiguous = 0
            }

            if let last = lastMatch {
                let gap = Double(i - last - 1)
                bonus -= gap * 0.2
            }

            total += bonus
            lastMatch = i
            qi += 1
        }

        guard qi == q.count else { return nil }

        // Strong bonus when the query appears verbatim as a contiguous
        // substring (case-insensitive). Pulls "auth" → "auth.md" decisively
        // ahead of scattered-subsequence matches like "a_u_t_h.md".
        if candidate.range(of: query, options: .caseInsensitive) != nil {
            total += 15
        }

        total -= Double(c.count) * 0.01
        return total
    }
}
