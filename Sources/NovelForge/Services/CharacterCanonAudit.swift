import Foundation
import NaturalLanguage

/// Deterministic person-name extraction and canon checks shared by concept,
/// structure, catalog memory and publication readiness.
enum CharacterCanonAudit {
    private struct TaggedWord {
        let text: String
        let range: Range<String.Index>
        let isPerson: Bool
        let isPlace: Bool
        let isNoun: Bool
        let isAdjective: Bool
    }

    private static let nonNameWords: Set<String> = [
        "als", "also", "am", "an", "anfang", "abend", "aber", "alle", "alles", "atem",
        "augen", "auto", "autor", "autorin", "beide", "boot", "buch", "bruder", "chef", "chefin",
        "dann", "das", "dass", "display", "doch", "draussen",
        "dein", "deine", "deinen", "deiner", "der", "die", "dies", "diese", "dieser",
        "dort", "du", "euer", "eure", "ein", "eine", "einer", "einem", "einen", "ende",
        "er", "erkennen", "es",
        "angst", "antagonist", "eifersucht", "familie", "frau", "freund", "freundin",
        "gegenspieler", "gestern", "hass", "heute", "herr", "hoffnung",
        "hier", "ihr", "ihre", "ihren", "ihrer", "ihres", "im", "in", "ja", "jahr",
        "hauptfigur", "investor", "jacke", "jahre", "jugendliebe", "junge", "kapitel", "kehle",
        "kein", "keine", "keinem", "keinen", "keiner", "keines", "kind",
        "lehrer", "lehrerin", "liebe", "mann", "magen", "mensch", "menschen",
        "misstrauen", "morgen", "mutter", "neid",
        "mein", "meine", "meinen", "meiner", "meer", "nachmittag", "nacht", "nicht", "norden",
        "nachbarin", "netz", "notar", "osten", "papa", "papier", "plot", "professor", "protagonist", "roman", "schlaf", "wald",
        "scham", "schwager", "schwagerin", "schwester", "schuld", "sein", "seine",
        "seinen", "seiner", "sehnsucht", "sie", "sohn", "später", "sturz",
        "tag", "taucher", "thema", "tochter", "uns", "unser", "unsere", "vater", "verschollene",
        "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag",
        "eins", "zwei", "drei", "vier", "fuenf", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "uhr",
        "las", "trauer", "vergangenheit", "vor", "vormittag", "westen", "woche",
        "wut", "zeit", "zum", "zurück"
    ]

    private static let determiners: Set<String> = [
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einer", "einen",
        "einem", "sein", "seine", "seinen", "seiner", "ihr", "ihre", "ihren", "ihrer"
    ]

    private static let placePrepositions: Set<String> = [
        "am", "ans", "aus", "bei", "durch", "hinter", "im", "in", "ins", "nahe",
        "nach", "neben", "ueber", "unter", "vom", "vor", "zwischen", "zum", "zur"
    ]

    private static let personActionVerbs: Set<String> = [
        "antwortete", "bat", "dachte", "erwiderte", "fragte", "ging", "griff", "hob",
        "kam", "legte", "lachte", "nickte", "rief", "sagte", "sah", "schrieb",
        "schuettelte", "schwieg", "setzte", "sprach", "stand", "trat", "wusste",
        "zeigte", "zog"
    ]

    private static let personSpeechVerbs: Set<String> = [
        "antwortete", "bat", "erwiderte", "fragte", "rief", "sagte", "sprach"
    ]

    /// Szenen brauchen Identitaet und aktuellen Zustand, aber keine staendig
    /// wiederholte Aussehens- oder Catchphrase-Checkliste. Genau diese Felder wurden
    /// in alten Manuskripten zu maschinellen Refrains (Narbe, Mantel, Naegel,
    /// "ehrlich gesagt"). Die vollstaendige Figurenbibel bleibt unveraendert; nur der
    /// eigentliche Prosakontext wird auf handlungsrelevanten Kanon reduziert.
    static func draftingCharacterSummary(_ characters: [CharacterProfile]) -> String {
        let lines = characters.prefix(8).map { character -> String in
            var parts = ["\(character.name) (\(character.role))"]
            if !character.age.isEmpty { parts.append(character.age) }
            if !character.occupation.isEmpty { parts.append(character.occupation) }
            if !character.goal.isEmpty { parts.append("Ziel: \(character.goal)") }
            // Das innere Brauchen MUSS mit in den Schreibkontext, sonst bleibt es eine
            // Datenbankspalte. Ausdrücklich als unbewusst markiert: Die Figur darf es
            // nicht aussprechen – sonst erklärt der Text sein eigenes Thema.
            if !character.development.isEmpty {
                parts.append("Braucht insgeheim (UNBEWUSST – nie aussprechen, nur im Handeln sichtbar): \(character.development)")
            }
            if !character.fear.isEmpty { parts.append("Angst: \(character.fear)") }
            if !character.weakness.isEmpty { parts.append("Schwaeche: \(character.weakness)") }
            if !character.relationships.isEmpty {
                parts.append("Beziehungen: \(character.relationships)")
            }
            if let stateRange = character.importantFacts.range(of: "[STAND K") {
                let state = character.importantFacts[stateRange.lowerBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !state.isEmpty { parts.append(String(state)) }
            }
            return parts.joined(separator: ", ")
        }
        guard !lines.isEmpty else { return "" }
        return """
        FIGURENIDENTITAET UND AKTUELLER STAND:
        \(lines.joined(separator: "\n"))
        Aussehen und Sprachmarotten sind absichtlich keine Szenen-Checkliste. Erwaehne sie nur,
        wenn die konkrete Handlung sie zwingend braucht; erfinde keine wiederkehrende Geste,
        Requisite, Catchphrase oder Dialoganrede als Erkennungszeichen.
        """
    }

    static func personNames(in text: String) -> [String] {
        let words = taggedWords(in: text)
        guard !words.isEmpty else { return [] }

        var result: [String] = []
        var current: [TaggedWord] = []

        func flush() {
            guard !current.isEmpty else { return }
            let value = current.enumerated().map { index, word in
                if let base = possessiveBase(for: word, in: words) { return base }
                if let wordIndex = words.firstIndex(where: { $0.range == word.range }),
                   isPossessiveNameBeforeNoun(word, at: wordIndex, in: words, source: text) {
                    return String(word.text.dropLast())
                }
                // "Lina Kesslers Schwester": Wenn der vollstaendige Name nur in
                // dieser Genitivform vorkommt, existiert kein separates "Kessler",
                // an dem `possessiveBase` ihn erkennen koennte. Beim letzten Teil eines
                // mehrteiligen Personennamens ist das abschliessende s der Genitivmarker.
                if current.count >= 2, index == current.count - 1,
                   word.text.count >= 5, word.text.lowercased().hasSuffix("s"),
                   let wordIndex = words.firstIndex(where: { $0.range == word.range }),
                   words.indices.contains(wordIndex + 1),
                   (words[wordIndex + 1].isNoun || words[wordIndex + 1].isAdjective) {
                    return String(word.text.dropLast())
                }
                return word.text
            }.joined(separator: " ")
            if !result.contains(where: { normalized($0) == normalized(value) }) {
                result.append(value)
            }
            current.removeAll(keepingCapacity: true)
        }

        for (index, word) in words.enumerated() {
            let accepted = isPlausibleNameWord(word, at: index, in: words)

            if accepted {
                // "Henning Ostwald ... als Ostwald Livs Handy ortet": NaturalLanguage
                // markiert Ostwald und Livs als zwei direkt benachbarte Personenteile.
                // Ohne diese Grenze entstand daraus die Scheinfamilie "Ostwald Liv".
                // Ein bereits als Teil eines Vollnamens bekannter einzelner Nachname
                // beendet deshalb die aktuelle Person, bevor ein Genitivname beginnt.
                if current.count == 1,
                   isPossessiveNameBeforeNoun(word, at: index, in: words, source: text),
                   result.contains(where: { knownName in
                       let knownParts = nameParts(knownName)
                       return knownParts.count >= 2
                           && knownParts.contains(normalized(current[0].text))
                   }) {
                    flush()
                }
                if let last = current.last {
                    let gap = text[last.range.upperBound..<word.range.lowerBound]
                    if gap.contains(where: { !$0.isWhitespace }) { flush() }
                }
                current.append(word)
            } else {
                flush()
            }
        }
        flush()
        return result.filter { name in
            let parts = nameParts(name)
            guard !parts.isEmpty else { return false }
            guard parts.count == 1, let only = parts.first else { return true }
            return !result.contains { other in
                other != name && nameParts(other).count > 1 && nameParts(other).contains(only)
            }
        }
    }

    private static func isPossessiveNameBeforeNoun(_ word: TaggedWord, at index: Int,
                                                    in words: [TaggedWord],
                                                    source: String) -> Bool {
        guard word.text.first?.isUppercase == true,
              word.text.count >= 4,
              word.text.lowercased().hasSuffix("s"),
              words.indices.contains(index + 1) else { return false }
        let gap = source[word.range.upperBound..<words[index + 1].range.lowerBound]
        // Names that already end in s form the German genitive with an apostrophe:
        // "Jonas' Bruder" / "Jonas’ Bruder". The s belongs to the name.
        guard !gap.contains("'") && !gap.contains("’") else { return false }
        let next = words[index + 1]
        // "Jonas Weyer" is a full name, not a genitive followed by a noun.
        // Role nouns such as "Maras Freundin" remain eligible.
        if next.isPerson && !nonNameWords.contains(normalized(next.text)) { return false }
        return next.isNoun || next.isAdjective
    }

    /// Includes every Story-Bible name and names proven by repeated person-name
    /// occurrences in stored prose. Repetition suppresses NaturalLanguage false positives.
    static func catalogNameParts(bibleNames: [String], narrativeTexts: [String],
                                 minimumOccurrences: Int = 2) -> Set<String> {
        var result = Set(bibleNames.flatMap(nameParts))
        var counts: [String: Int] = [:]
        var placeCounts: [String: Int] = [:]

        for text in narrativeTexts where !text.isEmpty {
            let words = taggedWords(in: text)
            for (index, word) in words.enumerated() {
                if word.isPlace || isPlaceContext(at: index, in: words) {
                    placeCounts[normalized(word.text), default: 0] += 1
                }
            }
            for (index, word) in words.enumerated()
                where isPlausibleNameWord(word, at: index, in: words) {
                let candidate = possessiveBase(for: word, in: words) ?? normalized(word.text)
                counts[candidate, default: 0] += 1
            }
        }

        for (name, count) in counts
            where count >= max(1, minimumOccurrences)
                && (placeCounts[name] ?? 0) < count {
            result.insert(name)
        }
        return result
    }

    static func catalogPlaceNameParts(narrativeTexts: [String],
                                      minimumOccurrences: Int = 2) -> Set<String> {
        var counts: [String: Int] = [:]
        for text in narrativeTexts where !text.isEmpty {
            let words = taggedWords(in: text)
            for (index, word) in words.enumerated()
                where word.isPlace || isPlaceContext(at: index, in: words) {
                let value = normalized(word.text)
                guard value.count >= 3, word.text.first?.isUppercase == true else { continue }
                counts[value, default: 0] += 1
            }
        }
        return Set(counts.compactMap { name, count in
            count >= max(1, minimumOccurrences) ? name : nil
        })
    }

    private static func isPlausibleActingNameWord(_ word: TaggedWord, at index: Int,
                                                   in words: [TaggedWord],
                                                   recognizedPersonParts: Set<String>) -> Bool {
        let value = normalized(word.text)
        guard recognizedPersonParts.contains(value),
              value.count >= 3, !nonNameWords.contains(value),
              word.text.first?.isUppercase == true else { return false }
        let letters = word.text.filter(\.isLetter)
        guard !(letters.count > 1 && letters == letters.uppercased()),
              !isPlaceContext(at: index, in: words) else { return false }
        // Ein Personenname steht in erzaehlender Prosa normalerweise ohne Artikel.
        // Diese Abgrenzung entfernt Subjekte wie "der Atem", "das Auto" oder
        // "das Display", selbst wenn direkt danach ein Handlungsverb folgt.
        let previous = index > 0 ? normalized(words[index - 1].text) : ""
        guard !determiners.contains(previous) else { return false }
        return true
    }

    /// High-confidence manuscript people: a person-tagged name must repeatedly stand
    /// directly beside a speech or action verb. This is intentionally stricter than
    /// catalog memory so places misclassified by NaturalLanguage cannot block export.
    static func actingCharacterNameParts(narrativeTexts: [String],
                                         minimumOccurrences: Int = 2) -> Set<String> {
        var counts: [String: Int] = [:]
        var actions: [String: Set<String>] = [:]
        // Ueber das gesamte Manuskript sammeln: NLTagger erkennt seltene Namen oft
        // erst bei der zweiten oder dritten Verwendung. Die spaeter erkannte Person
        // legitimiert dann auch ihre frueheren Vorkommen, nicht jedoch beliebige Nomen.
        let recognizedPersonParts = Set(narrativeTexts.flatMap { text in
            taggedWords(in: text).filter(\.isPerson).map { normalized($0.text) }
        })
        for text in narrativeTexts where !text.isEmpty {
            let words = taggedWords(in: text)
            func adjacentVerb(from index: Int, to neighborIndex: Int) -> String {
                guard words.indices.contains(index), words.indices.contains(neighborIndex) else {
                    return ""
                }
                let left = words[min(index, neighborIndex)]
                let right = words[max(index, neighborIndex)]
                let gap = text[left.range.upperBound..<right.range.lowerBound]
                guard gap.allSatisfy(\.isWhitespace) else { return "" }
                return normalized(words[neighborIndex].text)
            }
            for (index, word) in words.enumerated()
                where isPlausibleActingNameWord(
                    word, at: index, in: words,
                    recognizedPersonParts: recognizedPersonParts
                ) {
                let previous = adjacentVerb(from: index, to: index - 1)
                let next = adjacentVerb(from: index, to: index + 1)
                guard personActionVerbs.contains(previous) || personActionVerbs.contains(next)
                else { continue }
                let value = possessiveBase(for: word, in: words) ?? normalized(word.text)
                counts[value, default: 0] += 1
                let verb = personActionVerbs.contains(previous) ? previous : next
                actions[value, default: []].insert(verb)
            }
        }
        return Set(counts.compactMap { name, count in
            let verbs = actions[name] ?? []
            let personLikeAction = verbs.count >= 2 || !verbs.isDisjoint(with: personSpeechVerbs)
            return count >= max(1, minimumOccurrences) && personLikeAction ? name : nil
        })
    }

    static func unexpectedActingCharacterParts(in text: String,
                                               allowedNames: [String]) -> [String] {
        let allowed = Set(allowedNames.flatMap(nameParts))
        return actingCharacterNameParts(
            narrativeTexts: [text], minimumOccurrences: 1
        ).subtracting(allowed).sorted()
    }

    /// Personennamen muessen nicht erst mehrfach neben einem Sprechverb stehen, um in
    /// einer einzelnen Szene Schaden anzurichten. Fuer frische Entwuerfe verwenden wir
    /// deshalb die breitere Personenerkennung und vergleichen sie mit der Positivliste
    /// der fuer diese Szene erlaubten Figuren.
    static func unexpectedMentionedPersonParts(in text: String,
                                               allowedNames: [String]) -> [String] {
        let allowed = Set(allowedNames.flatMap(nameParts))
        var mentioned = Set(personNames(in: text).flatMap(nameParts))

        // NLTagger kann bei "Linda Keitum" nur den bereits bekannten Nachnamen als
        // Person markieren. Dann verschwände der erfundene Vorname in der erlaubten
        // Teilemenge. Vollnamen mit einem kanonischen Nachnamen werden deshalb
        // zusätzlich direkt verglichen.
        let allowedBySurname: [String: Set<String>] = Dictionary(
            grouping: allowedNames.compactMap { name -> (String, String)? in
                let parts = nameParts(name)
                guard parts.count >= 2, let first = parts.first, let last = parts.last else {
                    return nil
                }
                return (last, first)
            }, by: { $0.0 }
        ).mapValues { Set($0.map(\.1)) }
        if let regex = try? NSRegularExpression(
            pattern: #"\b\p{Lu}[\p{L}'’-]{2,}\s+\p{Lu}[\p{L}'’-]{2,}\b"#
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                guard let swiftRange = Range(match.range, in: text) else { continue }
                let parts = nameParts(String(text[swiftRange]))
                guard parts.count >= 2, let first = parts.first, let last = parts.last,
                      let allowedFirstNames = allowedBySurname[last],
                      !allowedFirstNames.contains(first) else { continue }
                mentioned.insert(first)
            }
        }
        return mentioned.subtracting(allowed).sorted()
    }

    /// Returns concept people whose name parts are absent from the generated ensemble.
    /// A concept may mention only a first name while a profile contains the full name.
    static func missingRequiredNames(required: [String], candidateNames: [String]) -> [String] {
        let candidatePartsByName = candidateNames.map(nameParts)
        let requiredPartsByName = required.map { (name: $0, parts: nameParts($0)) }
        return required.filter { requiredName in
            let parts = nameParts(requiredName)
            guard !parts.isEmpty else { return false }
            let effectiveParts = parts.map { part -> String in
                guard part.count >= 4, part.hasSuffix("s") else { return part }
                let base = String(part.dropLast())
                // Nur als Genitiv behandeln, wenn dieselbe Grundform an anderer
                // Stelle der bereits extrahierten Pflichtliste vorkommt. So wird
                // "Mara Keitum" + "Maras Versuch" zu einer Figur, waehrend ein
                // echter Einzelname wie "Jonas" nicht zu "Jona" gekuerzt wird.
                let baseIsRequiredElsewhere = requiredPartsByName.contains { entry in
                    normalized(entry.name) != normalized(requiredName)
                        && entry.parts.contains(base)
                }
                return baseIsRequiredElsewhere ? base : part
            }
            // Ein kanonischer Vollname muss in EINEM Profil vorkommen. Die alte
            // Mengenpruefung liess "Isolde Lindqvist" + "Alois Keitum" gemeinsam
            // faelschlich als Profil "Isolde Keitum" durchgehen.
            return !candidatePartsByName.contains { candidateParts in
                Set(effectiveParts).isSubset(of: Set(candidateParts))
            }
        }
    }

    /// Verhindert zwei versehentlich gleich benannte Figuren im selben Buch. Eine
    /// ausdrueckliche Gleichnamigkeit im Primaerkanon bleibt erlaubt.
    static func duplicateGivenNameConflicts(in names: [String],
                                            requiredNames: [String]) -> [String] {
        func givenName(_ name: String) -> String? {
            nameParts(name).first
        }
        var candidateCounts: [String: Int] = [:]
        for name in names {
            if let first = givenName(name) { candidateCounts[first, default: 0] += 1 }
        }
        var requiredCounts: [String: Int] = [:]
        for name in requiredNames where nameParts(name).count >= 2 {
            if let first = givenName(name) { requiredCounts[first, default: 0] += 1 }
        }
        return candidateCounts.compactMap { first, count in
            count > 1 && (requiredCounts[first] ?? 0) < count
                ? names.first(where: { givenName($0) == first })?
                    .split(whereSeparator: { !$0.isLetter }).first.map(String.init)
                : nil
        }.sorted()
    }

    /// Jede nicht bereits kanonische Figur muss aus dem deterministisch vergebenen,
    /// katalogweit freien Namenssatz stammen. So kann das Modell keine Lieblingsnamen
    /// wie Liv, Mira oder Voss als Nebenfigur einschmuggeln.
    static func unauthorizedSupplementaryNames(candidateNames: [String],
                                               requiredNames: [String],
                                               assignedSupplementaryNames: [String]) -> [String] {
        let requiredParts = requiredNames.map(nameParts)
        let assigned = Set(assignedSupplementaryNames.map(normalized))
        return candidateNames.filter { candidate in
            let parts = Set(nameParts(candidate))
            let matchesCanon = requiredParts.contains { required in
                !required.isEmpty && Set(required).isSubset(of: parts)
            }
            return !matchesCanon && !assigned.contains(normalized(candidate))
        }
    }

    /// Vor dem ersten Prosasatz duerfen frei erfundene Zusatznamen gefahrlos auf den
    /// bereits katalogweit reservierten Pool abgebildet werden. Primaerkanon und bereits
    /// korrekt verwendete Poolnamen werden dabei nie angefasst. Reicht der Pool nicht fuer
    /// eine vollstaendige Abbildung, gibt die Funktion `nil` statt einer Teilreparatur zurueck.
    static func supplementaryNameReplacements(
        candidateNames: [String],
        requiredNames: [String],
        assignedSupplementaryNames: [String]
    ) -> [String: String]? {
        var unauthorized: [String] = []
        for name in unauthorizedSupplementaryNames(
            candidateNames: candidateNames,
            requiredNames: requiredNames,
            assignedSupplementaryNames: assignedSupplementaryNames
        ) where !unauthorized.contains(where: { normalized($0) == normalized(name) }) {
            unauthorized.append(name)
        }
        guard !unauthorized.isEmpty else { return [:] }

        let candidateExact = Set(candidateNames.map(normalized))
        let requiredExact = Set(requiredNames.map(normalized))
        let available = assignedSupplementaryNames.filter { assigned in
            let value = normalized(assigned)
            return !candidateExact.contains(value) && !requiredExact.contains(value)
        }
        guard available.count >= unauthorized.count else { return nil }
        return Dictionary(uniqueKeysWithValues: zip(unauthorized, available))
    }

    static func missingRelationshipTargets(subject: String, relationships: String,
                                           characterNames: [String]) -> [String] {
        let source = normalized(relationships)
        return characterNames.filter { name in
            guard normalized(name) != normalized(subject) else { return false }
            let full = normalized(name)
            let first = nameParts(name).first ?? full
            let fullPattern = #"\b"# + NSRegularExpression.escapedPattern(for: full) + #"\b"#
            let firstPattern = #"\b"# + NSRegularExpression.escapedPattern(for: first) + #"\b"#
            return source.range(of: fullPattern, options: .regularExpression) == nil
                && source.range(of: firstPattern, options: .regularExpression) == nil
        }
    }

    static func relationshipGraphIssues(relationshipsBySubject: [String: String],
                                        characterNames: [String]) -> [String] {
        guard characterNames.count >= 2 else { return [] }
        var adjacency = Dictionary(uniqueKeysWithValues: characterNames.map { ($0, Set<String>()) })

        func mentions(_ target: String, in relationships: String) -> Bool {
            let source = normalized(relationships)
            let full = normalized(target)
            let first = nameParts(target).first ?? full
            for value in [full, first] where !value.isEmpty {
                let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: value) + #"\b"#
                if source.range(of: pattern, options: .regularExpression) != nil { return true }
            }
            return false
        }

        for subject in characterNames {
            let relationships = relationshipsBySubject[subject] ?? ""
            for target in characterNames where target != subject
                && mentions(target, in: relationships) {
                adjacency[subject, default: []].insert(target)
                adjacency[target, default: []].insert(subject)
            }
        }

        var issues = adjacency.compactMap { name, targets in
            targets.isEmpty ? "\(name) ohne kanonische Beziehung" : nil
        }.sorted()
        if let start = characterNames.first {
            var visited: Set<String> = [start]
            var pending = [start]
            while let current = pending.popLast() {
                for neighbor in adjacency[current] ?? [] where visited.insert(neighbor).inserted {
                    pending.append(neighbor)
                }
            }
            let disconnected = characterNames.filter { !visited.contains($0) }
            if !disconnected.isEmpty {
                issues.append("getrennte Figurengruppe: " + disconnected.joined(separator: ", "))
            }
        }
        return issues
    }

    static func relationshipRetryFeedback(missingTargets: [String],
                                          unexpectedParts: [String]) -> [String] {
        var details: [String] = []
        if !missingTargets.isEmpty {
            details.append("fehlende Kernfiguren: " + missingTargets.joined(separator: ", "))
        }
        if !unexpectedParts.isEmpty {
            // Abgelehnte Namen nie in den naechsten Modell-Prompt kopieren. Sonst
            // lernt der Wiederholungsversuch genau den Namen, den er entfernen soll.
            details.append("nicht kanonische Namensreferenz entfernen")
        }
        return details
    }

    /// Konzept und Plot duerfen Namen nur bewahren, nie vergeben. Neue Namen werden
    /// erst im Figuren-Agenten aus dem katalogweit freien Pool zugewiesen. Besonders
    /// wichtig ist der exakte Vergleich: Aus dem Seed-Namen "Mara" darf nicht
    /// "Mara Brenner" werden, weil der neue Nachname sonst zum Primaerkanon aufsteigt.
    static func nameIntegrityIssues(allowedNames: [String], candidateText: String,
                                    forbiddenNames: Set<String>) -> [String] {
        let allowedExact = Set(allowedNames.map(normalized))
        let allowedParts = Set(allowedNames.flatMap(nameParts))
        let forbidden = Set(forbiddenNames.map(normalized))
        var issues: [String] = []
        for candidate in personNames(in: candidateText) {
            let exact = normalized(candidate)
            let parts = Set(nameParts(candidate))
            guard !exact.isEmpty, !allowedExact.contains(exact) else { continue }
            if !parts.isDisjoint(with: forbidden.subtracting(allowedParts)) {
                issues.append("katalogweit gesperrter Name neu eingefuehrt: \(candidate)")
            } else {
                issues.append("nicht vorgegebener oder veraenderter Personenname: \(candidate)")
            }
        }
        return Array(Set(issues)).sorted()
    }

    static func isLocationCharacterRole(_ role: String) -> Bool {
        let folded = normalized(role)
        return ["schauplatz", "location", "ort", "landschaft", "gebaeude"].contains {
            folded.contains($0)
        }
    }

    static func isNonPersonCharacterRole(_ role: String) -> Bool {
        if isLocationCharacterRole(role) { return true }
        let folded = normalized(role)
        let nonPersonMarkers = [
            "symbolische figur", "symbolische anwesenheit", "symbolfigur",
            "gegenstand", "requisite", "motiv", "abstraktion"
        ]
        return nonPersonMarkers.contains(where: folded.contains)
    }

    /// Erkennt einen Altfehler aus frueheren Figurenparsern: Aus
    /// "Ostwald ortet Livs Handy" wurde ein Profil "Ostwald Livs". Wenn Ostwald
    /// zugleich ein echter Elternteil ist und dessen Beziehung bereits die kanonische
    /// Tochter nennt, ist die Aliasabbildung eindeutig und kann ohne Modell repariert
    /// werden.
    static func legacyPossessiveAliasReplacements(
        characterNames: [String], relationshipsByName: [String: String]
    ) -> [String: String] {
        var replacements: [String: String] = [:]
        for malformed in characterNames {
            let rawParts = malformed.split(whereSeparator: { !$0.isLetter }).map(String.init)
            guard rawParts.count == 2,
                  rawParts[1].count >= 4,
                  rawParts[1].lowercased().hasSuffix("s") else { continue }
            let parentSurname = normalized(rawParts[0])
            let staleAlias = String(rawParts[1].dropLast())
            guard nameParts(staleAlias).count == 1 else { continue }

            let matchingParents = characterNames.filter { candidate in
                let parts = nameParts(candidate)
                return parts.count >= 2 && parts.last == parentSurname
            }
            let canonical = matchingParents.compactMap { parent -> String? in
                guard let relationship = relationshipsByName[parent],
                      ["tochter", "sohn", "kind"].contains(where: {
                          normalized(relationship).contains($0)
                      }),
                      let relatedLabel = relationship.split(separator: ":", maxSplits: 1)
                        .first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
                else { return nil }
                return characterNames.first(where: {
                    normalized($0) == normalized(relatedLabel) && $0 != malformed
                })
            }.first
            guard let canonical else { continue }
            replacements[staleAlias] = canonical
        }
        return replacements
    }

    /// Applies one coherent rename to every canon source. Full names are replaced first,
    /// followed by matching first/last-name aliases. Placeholders prevent replacement chains.
    static func replacingNames(in text: String, replacements: [String: String]) -> String {
        guard !text.isEmpty, !replacements.isEmpty else { return text }
        var aliases: [(old: String, new: String)] = []
        for (oldName, newName) in replacements {
            let oldParts = oldName.split(whereSeparator: { !$0.isLetter }).map(String.init)
            let newParts = newName.split(whereSeparator: { !$0.isLetter }).map(String.init)
            aliases.append((oldName, newName))
            if !oldName.lowercased().hasSuffix("s") {
                aliases.append((oldName + "s", newName + "s"))
            }
            let possessiveNew = newName.lowercased().hasSuffix("s")
                ? newName + "'" : newName + "s"
            aliases.append((oldName + "'", possessiveNew))
            if oldParts.count == newParts.count {
                aliases.append(contentsOf: zip(oldParts, newParts).map { ($0.0, $0.1) })
            }
        }
        aliases.sort { $0.old.count > $1.old.count }

        var seen = Set<String>()
        aliases = aliases.filter {
            let exactVariant = $0.old.folding(
                options: [.diacriticInsensitive, .caseInsensitive], locale: .current
            ).lowercased()
            return seen.insert(exactVariant).inserted
        }
        var result = text
        var placeholders: [(String, String)] = []
        for (index, alias) in aliases.enumerated() where !alias.old.isEmpty {
            let placeholder = "\u{F000}NFNAME\(index)\u{F001}"
            let escaped = NSRegularExpression.escapedPattern(for: alias.old)
            let pattern = "(?<!\\p{L})\(escaped)(?!\\p{L})"
            guard let regex = try? NSRegularExpression(
                pattern: pattern, options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result, options: [], range: range, withTemplate: placeholder
            )
            placeholders.append((placeholder, alias.new))
        }
        for (placeholder, replacement) in placeholders {
            result = result.replacingOccurrences(of: placeholder, with: replacement)
        }
        return result
    }

    static func nameParts(_ name: String) -> [String] {
        name.split(whereSeparator: { !$0.isLetter })
            .map { normalized(String($0)) }
            .filter { $0.count >= 3 && !nonNameWords.contains($0) }
    }

    private static let roleAliases: [(key: String, display: String, markers: [String])] = [
        ("protagonist", "Hauptfigur", ["protagonist", "hauptfigur"]),
        ("antagonist", "Gegenspieler", ["antagonist", "gegenspieler"]),
        ("schwester", "Schwester", ["schwester"]),
        ("bruder", "Bruder", ["bruder"]),
        ("mutter", "Mutter", ["mutter", "mama"]),
        ("vater", "Vater", ["vater", "papa"]),
        ("tochter", "Tochter", ["tochter"]),
        ("sohn", "Sohn", ["sohn"]),
        ("jugendliebe", "Jugendliebe", ["jugendliebe"]),
        ("partner", "Partner", ["partner", "ehemann", "ehefrau"]),
        ("freund", "Freund", ["freund", "freundin"]),
        ("mentor", "Mentor", ["mentor"]),
        ("kollege", "Kollege", ["kollege", "kollegin"])
    ]

    private static func roleLabels(in text: String) -> Set<String> {
        let value = normalized(text)
        return Set(roleAliases.compactMap { alias in
            alias.markers.contains(where: value.contains) ? alias.key : nil
        })
    }

    private static func expandedRoleLabels(role: String, relationships: String,
                                           canon: String) -> Set<String> {
        var labels = roleLabels(in: role + "\n" + relationships)
        let identityGroups = canon.components(
            separatedBy: CharacterSet(charactersIn: ".!?;\n")
        ).compactMap { clause -> Set<String>? in
            let words = normalized(clause)
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            guard let copula = words.firstIndex(of: "ist") else { return nil }
            let left = roleLabels(in: words[..<copula].joined(separator: " "))
            let right = roleLabels(in: words[words.index(after: copula)...].joined(separator: " "))
            let group = left.union(right)
            return !left.isEmpty && !right.isEmpty && group.count >= 2 ? group : nil
        }
        var changed = true
        while changed {
            changed = false
            for group in identityGroups where !labels.isDisjoint(with: group) {
                let expanded = labels.union(group)
                if expanded != labels {
                    labels = expanded
                    changed = true
                }
            }
        }
        return labels
    }

    /// Resolves relational scene-plan references (for example "die Schwester") to
    /// the canonical profile whose plot role is explicitly equated with that relation.
    static func canonicalNamesReferenced(in context: String, names: [String],
                                         rolesByName: [String: String],
                                         relationshipsByName: [String: String],
                                         canon: String) -> [String] {
        let normalizedContext = normalized(context)
        let contextRoles = roleLabels(in: context)
        return names.filter { name in
            let parts = nameParts(name)
            let directlyNamed = parts.contains { part in
                normalizedContext.range(
                    of: #"\b"# + NSRegularExpression.escapedPattern(for: part) + #"\b"#,
                    options: .regularExpression
                ) != nil
            }
            if directlyNamed { return true }
            let labels = expandedRoleLabels(
                role: rolesByName[name] ?? "",
                relationships: relationshipsByName[name] ?? "",
                canon: canon
            )
            return !labels.isDisjoint(with: contextRoles)
        }
    }

    static func roleIdentityContract(names: [String], rolesByName: [String: String],
                                     relationshipsByName: [String: String],
                                     canon: String) -> String {
        let lines = names.compactMap { name -> String? in
            let labels = expandedRoleLabels(
                role: rolesByName[name] ?? "",
                relationships: relationshipsByName[name] ?? "",
                canon: canon
            )
            guard !labels.isEmpty else { return nil }
            let display = roleAliases.compactMap { alias in
                labels.contains(alias.key) ? alias.display : nil
            }
            return "- \(name): " + display.joined(separator: ", ")
        }
        guard !lines.isEmpty else { return "" }
        return """
        KANONISCHE ROLLENIDENTITAET (relationale Rollen niemals umbenennen):
        \(lines.joined(separator: "\n"))
        Wenn ein Szenenplan nur eine Rolle nennt, ist damit exakt die hier zugeordnete Figur gemeint.
        """
    }

    static func canonicalPerspectiveName(_ candidate: String,
                                         names: [String],
                                         rolesByName: [String: String]) -> String? {
        guard !names.isEmpty else { return nil }
        let wanted = normalized(candidate)
        let exactMatches = names.filter { normalized($0) == wanted }
        if exactMatches.count == 1 { return exactMatches[0] }
        let firstMatches = names.filter { nameParts($0).first == wanted }
        if firstMatches.count == 1 { return firstMatches[0] }

        if let protagonist = names.first(where: { name in
            let role = normalized(rolesByName[name] ?? "")
            return role.contains("protagon") || role.contains("hauptfigur")
        }) {
            return protagonist
        }
        return names.first
    }

    private static func taggedWords(in text: String) -> [TaggedWord] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        var words: [TaggedWord] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let tag = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType).0
            let lexical = tagger.tag(
                at: range.lowerBound, unit: .word, scheme: .lexicalClass
            ).0
            var token = String(text[range])
            // NaturalLanguage tokenizes the German possessive "Jonas'" as "Jona"
            // plus the untagged suffix "s'". Reattach that s before canon checks.
            let trailing = String(text[range.upperBound...].prefix(2))
            if trailing == "s'" || trailing == "s’" {
                token += "s"
            }
            words.append(TaggedWord(
                text: token, range: range,
                isPerson: tag == .personalName, isPlace: tag == .placeName,
                isNoun: lexical == .noun, isAdjective: lexical == .adjective
            ))
            return true
        }
        return words
    }

    private static func isPlausibleNameWord(_ word: TaggedWord, at index: Int,
                                            in words: [TaggedWord]) -> Bool {
        let value = normalized(word.text)
        guard word.isPerson, value.count >= 3, !nonNameWords.contains(value),
              word.text.first?.isUppercase == true else { return false }
        let letters = word.text.filter(\.isLetter)
        if letters.count > 1 && letters == letters.uppercased() { return false }

        let previous = index > 0 ? normalized(words[index - 1].text) : ""
        let nextIsPerson = words.indices.contains(index + 1) && words[index + 1].isPerson
        // NaturalLanguage markiert Berufs-/Rollenwoerter in "der Taucher Tjark" oft
        // ebenfalls als Person. Das erste Glied nach einem Artikel ist dort kein Name.
        if determiners.contains(previous), nextIsPerson { return false }
        if index > 0, possessiveBase(for: words[index - 1], in: words) != nil {
            return false
        }
        return true
    }

    private static func possessiveBase(for word: TaggedWord, in words: [TaggedWord]) -> String? {
        let value = normalized(word.text)
        guard value.count >= 4, value.hasSuffix("s") else { return nil }
        let base = String(value.dropLast())
        guard base.count >= 3 else { return nil }
        return words.contains { other in
            other.isPerson && normalized(other.text) == base
        } ? base : nil
    }

    private static func isPlaceContext(at index: Int, in words: [TaggedWord]) -> Bool {
        guard index > 0, words.indices.contains(index) else { return false }
        return placePrepositions.contains(normalized(words[index - 1].text))
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: CharacterSet.letters.inverted)
    }
}
