import Foundation

/// Conservative, deterministic checks for model-written revisions.
/// Ambiguous style remains an editorial decision; objectively lost facts do not.
enum RevisionSafety {
    enum BlindWinner: Equatable {
        case first
        case second
        case equal
        case invalid
    }

    private static let negations: Set<String> = [
        "nicht", "nie", "niemals", "kein", "keine", "keinen", "keinem",
        "keiner", "keines", "nichts", "niemand", "nirgends", "weder",
        "ohne", "kaum",
    ]

    private static let pastForms: Set<String> = [
        "war", "waren", "hatte", "hatten", "ging", "gingen", "kam", "kamen",
        "sah", "sahen", "stand", "standen", "lag", "lagen", "nahm", "nahmen",
        "saß", "saßen", "hielt", "hielten", "fiel", "fielen", "rief", "riefen",
        "schrieb", "schrieben", "zog", "zogen", "trug", "trugen", "sprach",
        "sprachen", "wusste", "wussten", "dachte", "dachten", "fand", "fanden",
        "blieb", "blieben", "wartete",
    ]

    private static let presentForms: Set<String> = [
        "ist", "sind", "hat", "haben", "geht", "gehen", "kommt", "kommen",
        "sieht", "sehen", "steht", "stehen", "liegt", "liegen", "nimmt", "nehmen",
        "sitzt", "sitzen", "hält", "halten", "fällt", "fallen", "ruft", "rufen",
        "schreibt", "schreiben", "zieht", "ziehen", "trägt", "tragen", "spricht",
        "sprechen", "weiß", "wissen", "denkt", "denken", "findet", "finden",
        "bleibt", "bleiben", "wartet",
    ]

    private static let firstPerson: Set<String> = [
        "ich", "mich", "mir", "mein", "meine", "meinen", "meinem", "meiner",
    ]
    private static let thirdPerson: Set<String> = [
        "er", "sie", "ihn", "ihm", "ihr", "seine", "seinen", "seinem", "seiner",
    ]
    private static let genericCapitalized: Set<String> = [
        "Der", "Die", "Das", "Ein", "Eine", "Und", "Aber", "Dann", "Als", "Wenn",
        "Weil", "Doch", "Noch", "Nur", "Im", "In", "An", "Auf", "Am", "Mit",
        "Von", "Zu", "Bei", "Für", "Nach", "Vor", "Aus", "Über", "Unter",
        "Sein", "Seine", "Ihr", "Ihre", "Nichts", "Niemand",
    ]
    private static let genericThings: Set<String> = [
        "Augenblick", "Dinge", "Ende", "Fall", "Frage", "Grund", "Hand", "Leute",
        "Moment", "Sache", "Seite", "Stelle", "Stunde", "Teil", "Welt", "Zeit",
        "Jahr", "Tag", "Nacht", "Mensch", "Spuren",
    ]

    static func issues(source: String, candidate: String) -> [String] {
        guard !source.isEmpty, !candidate.isEmpty else {
            return ["Die Revision ist leer."]
        }
        var result: [String] = []

        let sourceNumbers = numberTokens(in: source)
        let missingNumbers = sourceNumbers.subtracting(numberTokens(in: candidate))
        if !missingNumbers.isEmpty {
            result.append("Zahl fehlt: \(missingNumbers.sorted().joined(separator: ", ")).")
        }

        if negationCount(in: candidate) < negationCount(in: source) {
            result.append("Eine Verneinung ist verschwunden.")
        }

        let sourceQuotes = quoteCount(in: source)
        let candidateQuotes = quoteCount(in: candidate)
        if sourceQuotes != candidateQuotes || !candidateQuotes.isMultiple(of: 2) {
            result.append("Anführungszeichen wurden verändert oder beschädigt.")
        }

        let sourceTense = dominantTense(in: source)
        let candidateTense = dominantTense(in: candidate)
        if let sourceTense, let candidateTense, sourceTense != candidateTense {
            result.append("Erzählzeit wechselt von \(sourceTense) zu \(candidateTense).")
        }

        let sourcePerspective = dominantPerspective(in: source)
        let candidatePerspective = dominantPerspective(in: candidate)
        if let sourcePerspective, let candidatePerspective,
           sourcePerspective != candidatePerspective {
            result.append(
                "Perspektive wechselt von \(sourcePerspective) zu \(candidatePerspective)."
            )
        }

        let sourceThings = capitalizedContentWords(in: source)
        if sourceThings.count >= 3 {
            let candidateFolded = candidate.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            )
            let missing = sourceThings.filter { word in
                let stem = String(word.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).prefix(5))
                return stem.count >= 5 && !candidateFolded.contains(stem)
            }
            if missing.count >= 2,
               Double(missing.count) / Double(sourceThings.count) > 0.33 {
                result.append(
                    "Inhaltselemente gestrichen: \(missing.sorted().prefix(4).joined(separator: ", "))."
                )
            }
        }

        return result
    }

    static func parseBlindWinner(_ response: String) -> BlindWinner {
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .uppercased()
        if normalized == "A" || normalized == "FASSUNG A" || normalized == "BESSER: A" {
            return .first
        }
        if normalized == "B" || normalized == "FASSUNG B" || normalized == "BESSER: B" {
            return .second
        }
        if normalized == "GLEICH" || normalized == "GLEICHWERTIG" {
            return .equal
        }
        return .invalid
    }

    static func candidateClearlyWins(originalFirst: BlindWinner,
                                     candidateFirst: BlindWinner) -> Bool {
        originalFirst == .second && candidateFirst == .first
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static func numberTokens(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d+(?:[.,:]\d+)?\b"#) else {
            return []
        }
        let ns = text as NSString
        return Set(regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) })
    }

    private static func negationCount(in text: String) -> Int {
        words(in: text).filter(negations.contains).count
    }

    private static func quoteCount(in text: String) -> Int {
        let quoteCharacters = CharacterSet(charactersIn: "\"«»‹›„“‘’")
        return text.unicodeScalars.filter { quoteCharacters.contains($0) }.count
    }

    private static func dominantTense(in text: String) -> String? {
        let tokens = words(in: text)
        let past = tokens.filter(pastForms.contains).count
        let present = tokens.filter(presentForms.contains).count
        if past > present { return "Vergangenheit" }
        if present > past { return "Gegenwart" }
        return nil
    }

    private static func dominantPerspective(in text: String) -> String? {
        let tokens = words(in: text)
        let first = tokens.filter(firstPerson.contains).count
        let third = tokens.filter(thirdPerson.contains).count
        if first > 0, third == 0 { return "Ich" }
        if third > 0, first == 0 { return "Er/Sie" }
        return nil
    }

    private static func capitalizedContentWords(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\b[A-ZÄÖÜ][a-zäöüß]{3,}\b"#) else {
            return []
        }
        let ns = text as NSString
        return Set(regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
            .filter { !genericCapitalized.contains($0) && !genericThings.contains($0) })
    }
}
