import Foundation

struct StoryMemoryEntry: Equatable {
    let title: String
    let genre: String
    let premise: String
}

enum StoryMemory {
    static func entries(from projects: [Project]) -> [StoryMemoryEntry] {
        projects
            .filter { $0.status == .completed || !($0.bookProfile?.premise ?? "").isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                StoryMemoryEntry(
                    title: $0.title,
                    genre: $0.genre,
                    premise: $0.bookProfile?.premise ?? $0.storyBible?.plotPoints ?? ""
                )
            }
    }

    static func makeAvoidanceBrief(entries: [StoryMemoryEntry],
                                   selectedGenres: [String],
                                   limit: Int = 12) -> String {
        let relevant = entries.filter { entry in
            selectedGenres.isEmpty || selectedGenres.contains(entry.genre)
        }.prefix(limit)
        guard !relevant.isEmpty else {
            return "Bisher gibt es noch kein gespeichertes Story-Gedächtnis. Erfinde trotzdem eine eigenständige, nicht klischeehafte Geschichte."
        }

        let lines = relevant.map { entry in
            "- \(entry.title) [\(entry.genre)]: \(entry.premise.truncated(to: 220))"
        }.joined(separator: "\n")

        return """
        STORY-GEDÄCHTNIS: Diese bereits geschriebenen oder begonnenen Bücher nicht wiederholen, nicht variieren und nicht spiegeln.
        \(lines)

        Entwickle stattdessen neue Figuren, neue Konflikte, neue Schauplätze, neue zentrale Geheimnisse und eine andere emotionale Kernfrage.
        """
    }

    static func signature(title: String, genre: String, premise: String) -> String {
        normalizedTokens([title, genre, premise].joined(separator: " ")).joined(separator: " ")
    }

    static func isLikelyDuplicate(_ idea: ParsedIdea, existing entries: [StoryMemoryEntry]) -> Bool {
        let ideaTokens = Set(normalizedTokens("\(idea.title) \(idea.genre) \(idea.premise)"))
        guard !ideaTokens.isEmpty else { return false }

        return entries.contains { entry in
            let entryTokens = Set(normalizedTokens("\(entry.title) \(entry.genre) \(entry.premise)"))
            guard !entryTokens.isEmpty else { return false }
            let overlap = ideaTokens.intersection(entryTokens).count
            let union = ideaTokens.union(entryTokens).count
            let titleOverlap = normalized(entry.title).contains(normalized(idea.title))
                || normalized(idea.title).contains(normalized(entry.title))
            return titleOverlap || Double(overlap) / Double(union) >= 0.32
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9äöüß]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "eine", "einer", "einem", "einen", "ein", "der", "die", "das", "und", "oder",
            "mit", "gegen", "auf", "an", "im", "in", "am", "zu", "den", "dem", "des",
            "roman", "thriller", "krimi", "buch", "geschichte", "entdeckt", "kampft"
        ]
        return normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }
}
