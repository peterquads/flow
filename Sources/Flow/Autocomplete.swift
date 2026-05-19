import Foundation

enum Autocomplete {
    private static func tokens(_ s: String) -> [String] {
        s.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    static func suggestions(for query: String, from historyMRU: [String], limit: Int = 5) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let qTokens = tokens(q)
        guard !qTokens.isEmpty else { return [] }
        let qSet = Set(qTokens)
        let lastQ = qTokens.last!

        struct Scored { let name: String; let score: Double; let mruIndex: Int }
        var scored: [Scored] = []
        for (idx, name) in historyMRU.enumerated() {
            let cTokens = tokens(name)
            guard !cTokens.isEmpty else { continue }
            let cSet = Set(cTokens)
            let overlap = Double(qSet.intersection(cSet).count) / Double(qSet.count)
            let prefixBonus = cTokens.contains(where: { $0.hasPrefix(lastQ) }) ? 0.3 : 0.0
            let containsBonus = name.lowercased().contains(q.lowercased()) ? 0.2 : 0.0
            let score = 0.7 * overlap + prefixBonus + containsBonus
            if score > 0.2 {
                scored.append(Scored(name: name, score: score, mruIndex: idx))
            }
        }
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.mruIndex < b.mruIndex
        }
        var seen = Set<String>()
        var out: [String] = []
        for s in scored where !seen.contains(s.name.lowercased()) {
            seen.insert(s.name.lowercased())
            out.append(s.name)
            if out.count == limit { break }
        }
        return out
    }
}
