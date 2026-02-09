import Foundation

public struct PhraseStore: Sendable {
    public var phrases: [Phrase]

    public init(phrases: [Phrase]) {
        self.phrases = phrases
    }

    public static func loadJSON(from url: URL) throws -> PhraseStore {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let phrases = try decoder.decode([Phrase].self, from: data)
        return PhraseStore(phrases: phrases)
    }

    /// Case-insensitive prefix match for MVP (fast and predictable).
    ///
    /// In the UI layer, the query is what the user typed after '.' (>=1 char).
    public func search(_ query: String, limit: Int = 10) -> [Phrase] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        let qLower = q.lowercased()

        // Score: exact match (0), prefix match (1), substring match (2). Smaller is better.
        // This gives a reasonable dropdown ordering without heavy fuzzy deps.
        func score(_ phrase: Phrase) -> Int? {
            let t = phrase.trigger.lowercased()
            if t == qLower { return 0 }
            if t.hasPrefix(qLower) { return 1 }
            if t.contains(qLower) { return 2 }
            return nil
        }

        return phrases
            .compactMap { p -> (Phrase, Int)? in
                guard let s = score(p) else { return nil }
                return (p, s)
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                return a.0.trigger.count < b.0.trigger.count
            }
            .prefix(limit)
            .map { $0.0 }
    }
}
