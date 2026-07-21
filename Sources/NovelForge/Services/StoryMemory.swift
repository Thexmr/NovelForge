import Foundation

struct StoryMemoryEntry: Equatable {
    let title: String
    let genre: String
    let premise: String
    let structure: String

    init(title: String, genre: String, premise: String, structure: String = "") {
        self.title = title
        self.genre = genre
        self.premise = premise
        self.structure = structure
    }
}

enum StoryMemory {
    static func makeLanguageAvoidanceBrief(projects: [Project], excluding projectID: UUID,
                                           maxResults: Int = 12) -> String {
        var bookCounts: [String: Int] = [:]
        for project in projects where project.id != projectID {
            var seen = Set<String>()
            for chapter in (project.chapters ?? []) {
                let text = chapter.bestText ?? ""
                guard !text.isEmpty else { continue }
                let sample = String(text.prefix(1_800)) + " " + String(text.suffix(600))
                let words = sample.lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).map(String.init)
                guard words.count >= 6 else { continue }
                for index in 0...(words.count - 6) {
                    let gramWords = Array(words[index..<(index + 6)])
                    guard gramWords.contains(where: { $0.count >= 7 }) else { continue }
                    let gram = gramWords.joined(separator: " ")
                    guard gram.count >= 28 else { continue }
                    seen.insert(gram)
                }
            }
            for phrase in seen { bookCounts[phrase, default: 0] += 1 }
        }

        let repeated = bookCounts.filter { $0.value >= 2 }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .prefix(maxResults).map(\.key)
        guard !repeated.isEmpty else { return "" }
        return """
        KATALOGWEIT BEREITS WIEDERHOLTE FORMULIERUNGEN (in diesem Buch nicht verwenden):
        \(repeated.map { "- \($0)" }.joined(separator: "\n"))
        Formuliere Gesten, Übergänge und Reaktionen eigenständig aus der konkreten Situation.
        """
    }

    static func entries(from projects: [Project]) -> [StoryMemoryEntry] {
        projects
            .filter { $0.status == .completed || !($0.bookProfile?.premise ?? "").isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                StoryMemoryEntry(
                    title: $0.title,
                    genre: $0.genre,
                    premise: $0.bookProfile?.premise ?? $0.storyBible?.plotPoints ?? "",
                    structure: $0.storyBible?.plotPoints ?? ""
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
            let structure = entry.structure.trimmingCharacters(in: .whitespacesAndNewlines)
            return "- \(entry.title) [\(entry.genre)]: \(entry.premise.truncated(to: 180))"
                + (structure.isEmpty ? "" : " | Aufbau: \(structure.truncated(to: 120))")
        }.joined(separator: "\n")

        return """
        STORY-GEDÄCHTNIS: Diese bereits geschriebenen oder begonnenen Bücher nicht wiederholen, nicht variieren und nicht spiegeln.
        \(lines)

        Entwickle stattdessen ein anderes Kernproblem, andere Konfliktmechanik oder Methode,
        andere Figuren/Zielgruppe, andere Schauplätze/Beispiele und eine deutlich andere Struktur.
        """
    }

    static func signature(title: String, genre: String, premise: String) -> String {
        normalizedTokens([title, genre, premise].joined(separator: " ")).joined(separator: " ")
    }

    static func isLikelyDuplicate(_ idea: ParsedIdea, existing entries: [StoryMemoryEntry]) -> Bool {
        let ideaTokens = Set(normalizedTokens("\(idea.title) \(idea.genre) \(idea.premise)"))
        guard !ideaTokens.isEmpty else { return false }

        let matchingPatternCount = entries.filter {
            titlePattern($0.title) == titlePattern(idea.title) && !titlePattern(idea.title).isEmpty
        }.count
        if matchingPatternCount >= 2 { return true }

        let ideaPattern = premisePattern(idea.premise)
        if !ideaPattern.isEmpty {
            let similarPatterns = entries.filter {
                $0.genre == idea.genre && premisePattern($0.premise) == ideaPattern
            }
            if similarPatterns.count >= 2 { return true }
        }

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

    private static func titlePattern(_ title: String) -> String {
        let words = normalized(title).split(separator: " ").map(String.init)
        guard let first = words.first else { return "" }
        let formulaStarts: Set<String> = ["ich", "du", "wenn", "bevor", "warum", "niemand", "kein", "keine"]
        if formulaStarts.contains(first) { return "start:\(first)" }
        if words.count >= 2, ["das", "die", "der"].contains(first) {
            return "article:\(words[1])"
        }
        return ""
    }

    private static func premisePattern(_ premise: String) -> String {
        let text = normalized(premise)
        let patterns: [(String, [String])] = [
            ("return-secret", ["kehrt", "ruckkehr", "heimat", "geheimnis"]),
            ("inheritance-second-chance", ["erbe", "erbt", "zweite chance", "frist"]),
            ("missing-person-investigation", ["verschwunden", "vermisst", "spurensuche", "sucht"]),
            ("forced-proximity", ["wohnung", "zusammen", "gezwungen", "fremde"]),
            ("reader-habit", ["routine", "gewohnheit", "alltag", "schritte"]),
            ("reader-productivity", ["produktiv", "aufgaben", "planung", "fokus"]),
            ("reader-communication", ["gesprach", "kommunikation", "zuhoren", "konflikt"]),
            ("reader-money", ["finanz", "geld", "invest", "budget"])
        ]
        return patterns.first { _, markers in
            markers.filter(text.contains).count >= 2
        }?.0 ?? ""
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
