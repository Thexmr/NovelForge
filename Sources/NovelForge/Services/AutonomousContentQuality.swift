import Foundation

struct ProseClarityAssessment {
    let vagueReferences: Int
    let hypotheticalComparisons: Int
    let filterReactions: Int
    let vagueReferenceLimit: Int
    let hypotheticalComparisonLimit: Int
    let filterReactionLimit: Int

    var isAcceptable: Bool {
        vagueReferences <= vagueReferenceLimit
            && hypotheticalComparisons <= hypotheticalComparisonLimit
            && filterReactions <= filterReactionLimit
            && vagueReferences + hypotheticalComparisons + filterReactions
                <= vagueReferenceLimit + hypotheticalComparisonLimit + filterReactionLimit
    }
}

enum SceneFittingSizing {
    static func minimumSourceRatio(sourceWords: Int, targetWords: Int) -> Double {
        guard sourceWords > 0, targetWords > 0 else { return 0.50 }
        guard Double(sourceWords) > Double(targetWords) * 1.25 else { return 0.50 }
        let lowerTargetRatio = Double(targetWords) * 0.75 / Double(sourceWords)
        return min(0.50, max(0.25, lowerTargetRatio * 0.90))
    }
}

enum AutonomousContentQuality {
    private static let kinshipTerms = [
        "vater", "mutter", "schwester", "bruder", "tante", "onkel", "nichte", "neffe",
        "tochter", "sohn", "ehefrau", "ehemann", "großmutter", "grossmutter", "großvater",
        "grossvater"
    ]
    private static let deathTerms = [
        "tod", "tot", "verstorben", "starb", "gestorben", "erhangte", "suizid", "umgebracht"
    ]

    static func safeFictionScene(number: Int, chapterTitle: String, chapterGoal: String,
                                 chapterConflict: String, perspective: String) -> PlannedScene {
        let ziel = chapterGoal.isEmpty ? "das Kapitelziel" : chapterGoal
        let conflict = chapterConflict.isEmpty
            ? "Ein bereits etablierter Widerstand erschwert den nächsten Schritt"
            : chapterConflict

        // WARUM DIESE BEATS SO GEBAUT SIND: Der frühere Fallback gab JEDER Szene dasselbe
        // Kapitelziel als Szenenziel („Clara findet das Foto…"). Der Schreiber führte das
        // Ziel dann in jeder Szene aus – im Testbuch fand die Heldin dasselbe Foto drei-
        // bis viermal, das Telefon klingelte dreimal. Ein Plan, der dreimal dasselbe sagt,
        // erzeugt dreimal dieselbe Szene.
        //
        // Jetzt beschreibt jede Szene eine ANDERE dramaturgische Funktion (Einstieg,
        // Komplikation, Zuspitzung, Wende). Das Kapitelziel wird als Richtung genannt,
        // aber KEINE Szene wiederholt die Handlung einer früheren – das steht ausdrücklich
        // in jedem Beat.
        let beats: [(String, String, String)] = [
            (
                "EINSTIEG: Die Perspektivfigur betritt die Ausgangslage und unternimmt den ERSTEN konkreten Schritt in Richtung: \(ziel). Etabliere Ort, Stimmung und den Auslöser der Handlung.",
                "\(conflict). Der erste Versuch stößt sofort an eine Grenze.",
                "Ein erster Handlungsimpuls ist gesetzt – die Szene endet mit einer offenen Spannung, NICHT mit dem Erreichen des Kapitelziels."
            ),
            (
                "KOMPLIKATION: Ausgehend vom Ende der vorigen Szene ein NEUER, anderer Vorstoß. Zeige eine Handlung, die in Szene 1 noch NICHT vorkam – keine Wiederholung von Fund, Anruf oder Entdeckung von zuvor.",
                "\(conflict). Ein zusätzliches, konkretes Hindernis verschärft die Lage.",
                "Die Figur trifft eine Entscheidung, die neue Folgen auslöst und die Handlung vorantreibt."
            ),
            (
                "ZUSPITZUNG: Die Folgen der vorigen Szenen zwingen die Figur zu einem Schritt mit sichtbarem Einsatz oder Verzicht. Nichts bereits Gezeigtes wird erneut aufgerollt.",
                "\(conflict). Der Preis des Weitergehens wird deutlich.",
                "Ein Wendepunkt verändert die Lage spürbar – die Szene hebt die Spannung, statt zum Anfang zurückzukehren."
            ),
            (
                "WENDE UND ÜBERGANG: Eine Entscheidung oder Enthüllung bringt das Kapitel zu seinem Höhepunkt und öffnet die Tür zum nächsten. Fasse NICHTS aus früheren Szenen noch einmal aus.",
                "\(conflict). Die Entscheidung fordert eine unmittelbare persönliche Konsequenz.",
                "Die Konsequenz führt kausal in das folgende Kapitel – ohne neue Vorgeschichte zu erfinden und ohne eine frühere Szene zu wiederholen."
            )
        ]
        let beat = beats[(max(1, number) - 1) % beats.count]
        return PlannedScene(number: number, perspective: perspective,
                            location: "", time: "fortlaufend",
                            goal: beat.0, obstacle: beat.1, turn: beat.2)
    }

    static func hasScenePlanGenreDrift(_ text: String, genre: String, canon: String) -> Bool {
        !scenePlanGenreDriftMarkers(text, genre: genre, canon: canon).isEmpty
    }

    /// Besteht der Plan nur aus den generischen Notfall-Beats?
    ///
    /// Gemessen an Buch 7: Ein Drittel aller Szenen bekam Ziele wie „KOMPLIKATION:
    /// ein NEUER, anderer Vorstoß" und bei allen vier Szenen eines Kapitels dasselbe
    /// Hindernis. Der Draft Writer hat damit keinerlei Unterscheidungsmerkmal und
    /// erzählt dasselbe Ereignis mehrfach. Diese Doppler sind später durch KEINE
    /// Reparatur behebbar – eine Szene wurde achtmal neu geschrieben und blieb ein
    /// Doppler, weil ihr Plan mit dem der Nachbarszene identisch war. Deshalb gilt
    /// ein solcher Plan als unbrauchbar und wird neu angefordert.
    static func istGenerischerSzenenplan(_ planned: [PlannedScene]) -> Bool {
        guard planned.count >= 2 else { return false }
        let marken = ["einstieg:", "komplikation:", "zuspitzung:", "wende und übergang",
                      "wende und ubergang"]
        let generisch = planned.filter { szene in
            let ziel = szene.goal.folding(options: [.diacriticInsensitive], locale: .current)
                .lowercased()
            return marken.contains { ziel.hasPrefix($0) || ziel.contains($0) }
        }.count
        // Mehrheit generisch → unbrauchbar.
        if generisch * 2 > planned.count { return true }
        // Oder: alle Szenen teilen sich wörtlich dasselbe Hindernis.
        let hindernisse = Set(planned.map {
            $0.obstacle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })
        return hindernisse.count == 1 && planned.count >= 3
    }

    static func scenePlanGenreDriftMarkers(_ text: String, genre: String,
                                           canon: String) -> [String] {
        let normalizedGenre = canonNormalized(genre)
        guard !normalizedGenre.contains("horror"),
              !normalizedGenre.contains("mystery"),
              !normalizedGenre.contains("thriller"),
              !normalizedGenre.contains("krimi") else { return [] }
        let established = canonNormalized(canon)
        // Nur was der Kandidat NEU einführt, ist Abdrift. Was der etablierte Text
        // bereits enthält, darf eine Fortsetzung aufgreifen.
        //
        // Gemessen an Buch 7: Kapitel 1, Szene 3 enthält „eine flüchtige Gestalt"
        // vor dem Fenster. Der established-Abgleich galt bisher NUR für die
        // `driftMarkers`-Liste am Ende – die fest verdrahteten Regeln darüber
        // prüften ihn nie. Jede Reparatur, die diese Szene korrekt fortführte,
        // schlug deshalb zwangsläufig als „bedrohliche Gestalt" an und konnte nie
        // angenommen werden: ein Patt, das sich nicht auflösen lässt.
        let imKandidaten = genreDriftRuleHits(in: canonNormalized(text))
        guard !imKandidaten.isEmpty else { return [] }
        let imEtablierten = Set(genreDriftRuleHits(in: established))
        return imKandidaten.filter { !imEtablierten.contains($0) }.sorted()
    }

    /// Wendet den Regelsatz auf EINEN Text an. Getrennt, damit derselbe Satz auch auf
    /// den etablierten Text angewendet werden kann – sonst zählt Bestehendes als neu.
    private static func genreDriftRuleHits(in candidate: String) -> [String] {
        var matches: [String] = []
        if candidate.contains("schatten"),
           candidate.contains("waldrand") || candidate.contains("zwischen den baumen") {
            matches.append("Schatten am Waldrand/zwischen den Bäumen")
        }
        if candidate.contains("beobacht"),
           candidate.contains("waldrand") || candidate.contains("heimlich") {
            matches.append("heimliche Beobachtung/am Waldrand")
        }
        if containsStandaloneMarker("gestalt", in: candidate),
           ["waldrand", "vor dem fenster", "hinter dem fenster", "gestalt im schatten", "verfolg"]
            .contains(where: candidate.contains) {
            matches.append("bedrohliche Gestalt")
        }
        if containsStandaloneMarker("axt", in: candidate)
            || containsStandaloneMarker("beil", in: candidate) {
            if ["wie eine waffe", "drohte", "bedrohte", "erhob", "schwang", "griff an",
                "zwischen den baumen", "trat hervor", "waldrand"]
                .contains(where: candidate.contains) {
                matches.append("Axt/Beil als Bedrohung")
            }
        }
        if candidate.contains("jemand"),
           ["wahrend sie schlief", "wahrend sie geschlafen", "hereingelegt", "war im haus",
            "abdruck eines kopfes", "nicht der ihre", "wer hier gewesen", "vorhange zuruckgezogen"]
            .contains(where: candidate.contains) {
            matches.append("unbekannte Person im Haus")
        }
        if candidate.contains("hinter der tur") && candidate.contains("unter dem bett") {
            matches.append("Eindringlings-/Horrorinszenierung")
        }
        if candidate.contains("das haus"),
           ["haus atmete", "atmete nicht", "schien zu warten", "als wurde es warten"]
            .contains(where: candidate.contains) {
            matches.append("bedrohlich vermenschlichtes Haus")
        }
        if ["haustur offen stand", "tur stand offen", "tur wieder offen"]
            .contains(where: candidate.contains),
           ["obwohl", "nachdem", "niemand", "von selbst", "unerklart"]
            .contains(where: candidate.contains) {
            matches.append("unerklärlich offene Tür")
        }
        let driftMarkers = [
            "menschliche silhouette", "gestalt am waldrand",
            "geruch nach verwesung", "verwesung", "einbrecher", "geistererscheinung",
            "stimme flustert", "stimme flusterte", "ein schatten bewegte sich",
            "wie eine waffe", "kein tier",
            "bemerkt nicht den forster", "beobachtet sie vom waldrand",
            "sie beobachten mich", "nicht jeder hier freut sich", "schatten zwischen den baumen",
            "schlussel, der nicht",
            "einzelnen schlussel", "fremden schlussel", "unbekannten schlussel",
            "frischer abdruck", "frische mulde", "wer hier gewesen war"
        ]
        // Kein established-Abgleich mehr an dieser Stelle: Er gilt jetzt zentral in
        // scenePlanGenreDriftMarkers für ALLE Regeln, nicht nur für diese Liste.
        matches.append(contentsOf: driftMarkers.filter {
            containsStandaloneMarker($0, in: candidate)
        })
        return Array(Set(matches)).sorted()
    }

    private static func containsStandaloneMarker(_ marker: String, in text: String) -> Bool {
        if marker.contains(" ") || marker.contains(",") { return text.contains(marker) }
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: marker) + #"\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    static func summaryIntroducesUnsupportedSpecifics(_ summary: String,
                                                       evidence: String) -> Bool {
        let candidate = canonNormalized(summary)
        let source = canonNormalized(evidence)
        let riskStems = [
            "eltern", "mutter", "schwester", "bruder", "tante", "onkel", "kind",
            "schwanger", "verstorben", "gestorben", "starb", "tod", "ermordet",
            "uberwacht", "heimlich", "mysterios", "waffe", "suizid", "erhangt"
        ]
        return riskStems.contains { stem in
            candidate.contains(stem) && !source.contains(stem)
        }
    }

    static func unexpectedCharacterNames(in text: String, allowedContext: String,
                                         characterNames: [String]) -> [String] {
        let candidate = canonNormalized(text)
        let allowed = canonNormalized(allowedContext)
        return characterNames.filter { name in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            let appears = candidate.contains(normalized) || candidate.contains(first)
            let isAllowed = allowed.contains(normalized) || allowed.contains(first)
            return appears && !isAllowed
        }
    }

    static func unexpectedStoryArtifacts(in text: String, allowedContext: String) -> [String] {
        let candidate = canonNormalized(text)
        let allowed = canonNormalized(allowedContext)
        let artifacts = [
            (#"\bbrief[\p{L}-]*"#, "Brief"), (#"\bfoto[\p{L}-]*"#, "Foto"),
            (#"\btagebuch[\p{L}-]*"#, "Tagebuch"), (#"\bnotizbuch[\p{L}-]*"#, "Notizbuch"),
            (#"\bzettel[\p{L}-]*"#, "Zettel"), (#"\bnotiz(?:en)?\b"#, "Notiz"),
            (#"\bring(?:s)?\b"#, "Ring"), (#"\bultraschall[\p{L}-]*"#, "Ultraschallbild"),
            (#"\bkaufvertrag[\p{L}-]*"#, "Kaufvertrag")
        ]
        return artifacts.compactMap { pattern, label in
            let appears = candidate.range(of: pattern, options: .regularExpression) != nil
            let isAllowed = allowed.range(of: pattern, options: .regularExpression) != nil
            return appears && !isAllowed ? label : nil
        }
    }

    static func removingScenePlanViolations(from text: String,
                                            characterNames: [String],
                                            artifactLabels: [String]) -> String {
        let normalizedNames = characterNames.flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        }
        let artifactPatterns: [String: String] = [
            "Brief": #"\bbrief[\p{L}-]*"#,
            "Foto": #"\bfoto[\p{L}-]*"#,
            "Tagebuch": #"\btagebuch[\p{L}-]*"#,
            "Notizbuch": #"\bnotizbuch[\p{L}-]*"#,
            "Zettel": #"\bzettel[\p{L}-]*"#,
            "Notiz": #"\bnotiz(?:en)?\b"#,
            "Ring": #"\bring(?:s)?\b"#,
            "Ultraschallbild": #"\bultraschall[\p{L}-]*"#,
            "Kaufvertrag": #"\bkaufvertrag[\p{L}-]*"#
        ]
        let activePatterns = artifactLabels.compactMap { artifactPatterns[$0] }
        var kept: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) {
            substring, _, _, _ in
            guard let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sentence.isEmpty else { return }
            let normalized = canonNormalized(sentence)
            let hasName = normalizedNames.contains { containsStandaloneMarker($0, in: normalized) }
            let hasArtifact = activePatterns.contains {
                normalized.range(of: $0, options: .regularExpression) != nil
            }
            if !hasName && !hasArtifact { kept.append(sentence) }
        }
        return kept.joined(separator: " ")
    }

    /// Blocks newly assigned family relationships before they can enter a plan or manuscript.
    /// The guard is intentionally narrow: it only judges explicit kinship claims for known names.
    static func unsupportedCanonClaims(in candidate: String, canon: String,
                                       characterNames: [String]) -> [String] {
        let canonClauses = relationshipClauses(in: canon)
        let aliases = Array(Set(characterNames.flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        })).sorted { $0.count > $1.count }

        return relationshipClauses(in: candidate).compactMap { original, normalized in
            let mentioned = aliases.filter { normalized.contains($0) }
            guard !mentioned.isEmpty else { return nil }

            if let term = kinshipTerms.first(where: { containsWordStem($0, in: normalized) }) {
                let directPossessors = aliases.filter {
                    hasDirectKinshipClaim(possessor: $0, term: term, in: normalized)
                }
                let supported: Bool
                if !directPossessors.isEmpty {
                    supported = directPossessors.allSatisfy { possessor in
                        canonClauses.contains { _, clause in
                            hasDirectKinshipClaim(possessor: possessor, term: term, in: clause)
                        }
                    }
                } else {
                    let propertyClaim = normalized.contains("haus") || normalized.contains("erb")
                    supported = canonClauses.contains { _, clause in
                        containsWordStem(term, in: clause)
                            && mentioned.allSatisfy { clause.contains($0) }
                            && (!propertyClaim || clause.contains("haus") || clause.contains("erb"))
                    }
                }
                if !supported { return original }
            }

            let deathSubjects = aliases.filter { hasDirectDeathClaim(subject: $0, in: normalized) }
            if !deathSubjects.isEmpty {
                let supported = deathSubjects.allSatisfy { subject in
                    canonClauses.contains { _, clause in
                        hasDirectDeathClaim(subject: subject, in: clause)
                    }
                }
                if !supported { return original }
            }
            return nil
        }
    }

    static func groundedRelationships(_ candidate: String, canon: String,
                                      characterNames: [String], subject: String = "") -> String {
        candidate.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { clause in
                let claim = subject.isEmpty ? clause : "\(subject) ist \(clause)"
                return !clause.isEmpty
                    && kinshipTerms.contains(where: { containsWordStem($0, in: canonNormalized(clause)) })
                    && unsupportedCanonClaims(
                        in: claim, canon: canon, characterNames: characterNames
                    ).isEmpty
            }
            .joined(separator: "; ")
    }

    private static func relationshipClauses(in text: String) -> [(String, String)] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ($0, canonNormalized($0)) }
    }

    private static func canonNormalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func containsWordStem(_ term: String, in text: String) -> Bool {
        text.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: term) + #"(?:s|es|e|en|er)?\b"#,
                   options: .regularExpression) != nil
    }

    private static func hasDirectKinshipClaim(possessor: String, term: String,
                                               in text: String) -> Bool {
        let escapedPossessor = NSRegularExpression.escapedPattern(for: possessor)
        let escapedTerm = NSRegularExpression.escapedPattern(for: term)
        let pattern = #"\b"# + escapedPossessor
            + #"(?:s|['’])?\s+(?:[\p{L}-]+\s+){0,2}"#
            + escapedTerm + #"(?:s|es|e|en|er)?\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func hasDirectDeathClaim(subject: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: subject)
        let death = deathTerms.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let possessive = #"\b"# + escaped + #"(?:s|['’])\s+(?:[\p{L}-]+\s+)?(?:"#
            + death + #")[\p{L}-]*\b"#
        let subjectVerb = #"\b"# + escaped + #"\s+(?:[\p{L}-]+\s+){0,2}(?:"#
            + death + #")[\p{L}-]*\b"#
        let deathOf = #"\b(?:"# + death + #")[\p{L}-]*\s+(?:von\s+)?(?:[\p{L}-]+\s+){0,2}"#
            + escaped + #"\b"#
        return [possessive, subjectVerb, deathOf].contains {
            text.range(of: $0, options: .regularExpression) != nil
        }
    }

    static func hasUsableIdea(_ idea: ParsedIdea?) -> Bool {
        guard let idea else { return false }
        let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let premise = idea.premise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 4, premise.wordCount >= 10 else { return false }
        return !isGenericPlaceholder(title)
            && !isOccupationalTitleCliche(title)
            && !containsMetaRequest(premise)
    }

    /// Heuristische Klickstärke/„Viralität" eines Titels für die Auto-Produktion:
    /// bevorzugt kurze, klangstarke, neugierig machende Titel (gut als Amazon-KDP-
    /// Thumbnail lesbar), bestraft generische und Berufs-/Ort-Klischee-Titel.
    /// Reine Heuristik – kein Netzwerkaufruf, deterministisch.
    static func titleViralityScore(_ rawTitle: String) -> Int {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return 0 }
        if isGenericPlaceholder(title) { return 0 }

        var score = 50
        let words = title.split(separator: " ").count
        switch words {            // Wortzahl-Sweetspot 2–5 (im Suchergebnis sofort lesbar)
        case 2...5: score += 25
        case 1, 6: score += 8
        default: score -= 12      // 7+ Wörter: zu lang fürs Thumbnail
        }
        switch title.count {      // kurze Titel = besser sichtbar
        case ...28: score += 15
        case 29...40: score += 6
        default: score -= 10
        }
        if isOccupationalTitleCliche(title) { score -= 40 }

        let lower = title.lowercased()
        let curiosityWords = ["niemand", "nie", "letzte", "letzter", "letztes", "bevor", "wenn",
                              "warum", "was", "kein", "keiner", "still", "schweigen", "lüge",
                              "geheimnis", "schatten", "blut", "nacht", "tod", "verloren",
                              "vergiss", "sag", "bleib", "komm",
                              // Romance/Sehnsucht (größter KDP-Markt)
                              "küss", "berühr", "versprich", "gehörst", "mein", "dein",
                              "sehnsucht", "verboten", "verbotene", "zwischen uns", "ansieht",
                              "begehr", "herz", "haut", "näher", "fremder"]
        if curiosityWords.contains(where: { lower.contains($0) }) { score += 14 }
        if lower.contains(" und ") || lower.contains(" oder ") || title.contains(",") { score += 6 }
        if lower.contains("dich") || lower.contains("dir") || lower.contains(" du ") { score += 6 }

        // POLARISIERUNG: Titel mit Tabu-/Anschuldigungs-/Dilemma-Ladung lösen sofort eine
        // Reaktion aus und werden geklickt – gefällige Titel werden überscrollt.
        let polarizingWords = ["schuld", "verrat", "betrog", "belog", "rache", "sünde", "hass",
                               "hasse", "monster", "teufel", "verboten", "gehörst", "niemals",
                               "gestehe", "geständnis", "beichte", "stahl", "zerstör", "feind",
                               "ehemann", "witwe", "affäre", "bett"]
        if polarizingWords.contains(where: { lower.contains($0) }) { score += 12 }
        // Ich-/Du-Konfrontation („Ich habe …", „Du hast …") = Geständnis/Anschuldigung.
        if lower.hasPrefix("ich ") || lower.hasPrefix("du ") { score += 6 }

        return max(0, score)
    }

    /// Endet das Kapitel ohne Sog? (Rein deterministisch – erkennt ruhige Beschreibungs-
    /// Enden ohne Frage, Zuspitzung oder kurzen Schlag.) Wird für Nicht-Schlusskapitel
    /// in die Revision eingespeist: „Kapitelende schärfen".
    static func hasWeakChapterEnding(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.wordCount >= 120 else { return false } // Kurztexte nicht beurteilen
        let tail = String(trimmed.suffix(400))
        // Frage oder abgebrochene Rede im Schluss = Sog vorhanden.
        if tail.contains("?") { return false }
        if tail.hasSuffix("…") || tail.hasSuffix("–") || tail.hasSuffix("-") { return false }
        // Letzten Satz isolieren (nach dem letzten Satzende davor).
        let sentences = tail.components(separatedBy: CharacterSet(charactersIn: ".!…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let last = sentences.last else { return true }
        // Kurzer Schlusssatz (≤ 8 Wörter) = bewusster Schlag/Punch → stark.
        if last.wordCount <= 8 { return false }
        // Endet in wörtlicher Rede → meist Zuspitzung/Drohung → stark.
        if tail.hasSuffix("\"") || tail.hasSuffix("“") || tail.hasSuffix("«") || tail.hasSuffix("»") { return false }
        return true
    }

    /// Wählt aus der Antwort des viralen Titel-Prompts (KANDIDATEN + BESTER) den stärksten
    /// brauchbaren Titel. Bevorzugt die Modell-Wahl, fällt sonst auf den höchstbewerteten Kandidaten.
    static func chooseViralTitle(from response: String, genre: String) -> String {
        var best = ""
        var candidates: [String] = []
        for raw in response.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.lowercased().hasPrefix("bester"), let colon = line.firstIndex(of: ":") {
                best = cleanTitleLine(String(line[line.index(after: colon)...]))
            } else if line.range(of: #"^\d+[\)\.\-:]"#, options: .regularExpression) != nil {
                let t = cleanTitleLine(line.replacingOccurrences(of: #"^\d+[\)\.\-:]\s*"#, with: "", options: .regularExpression))
                if !t.isEmpty { candidates.append(t) }
            }
        }
        if isUsableTitle(best, genre: genre) { return best }
        let usable = candidates.filter { isUsableTitle($0, genre: genre) }
        let score: (String) -> Int = BookContentType.infer(from: genre) == .nonfiction
            ? nonfictionTitleScore
            : titleViralityScore
        if let top = usable.max(by: { score($0) < score($1) }) { return top }
        return best.isEmpty ? (candidates.first ?? "") : best
    }

    private static func cleanTitleLine(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'„“”»«*-–—_.").union(.whitespacesAndNewlines))
    }

    /// Ist der Titel durch das GESCHRIEBENE Buch gedeckt?
    ///
    /// Modelle erfinden gern klangvolle Titel mit Begriffen, die im Buch gar nicht
    /// vorkommen („Der Drachenthron" für einen Krimi). Solche Titel enttäuschen Leser
    /// nach dem Klick – und enttäuschte Leser sind auf Amazon teurer als ein
    /// unspektakulärer Titel. Deshalb muss mindestens ein inhaltstragendes Wort des
    /// Titels wirklich im Manuskript stehen.
    static func titleIsCoveredByBook(_ title: String, chapters: [String]) -> Bool {
        let stoppwoerter: Set<String> = ["der", "die", "das", "ein", "eine", "und", "oder",
                                         "von", "dem", "den", "des", "im", "in", "auf", "mit", "für"]
        let woerter = title.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 4 && !stoppwoerter.contains($0) }
        guard !woerter.isEmpty else { return true }   // reine Funktionswörter: nichts zu prüfen
        let text = chapters.joined(separator: " ").lowercased()
        return woerter.contains { text.contains($0) }
    }

    /// Brauchbar als gewählter Titel (Länge ok, kein Platzhalter/Berufsklischee/Genre-Label).
    static func isUsableTitle(_ title: String, genre: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = t.split(separator: " ").count
        return t.count >= 4 && words >= 1 && words <= 7 && !isWeakTitle(t, genre: genre)
    }

    /// Schwacher Titel, der ersetzt werden soll: Platzhalter, Berufsklischee oder reines Genre-Label.
    static func isWeakTitle(_ title: String, genre: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if isGenericPlaceholder(t) || isOccupationalTitleCliche(t) { return true }
        if CopyrightChecker.isInfringingTitle(t) { return true } // kein geschützter Werk-/Reihentitel

        let low = t.lowercased()
        let genreLabels = ["liebesroman", "erotik-roman", "erotikroman", "erotik", "thriller", "krimi",
                           "roman", "dark romance", "romance", "fantasy", "new adult", "romantasy"]
        let nonfictionLabels = BookContentType.nonfictionGenres.map { $0.lowercased() }
        return genreLabels.contains(low) || nonfictionLabels.contains(low) || low == genre.lowercased()
    }

    private static func nonfictionTitleScore(_ title: String) -> Int {
        let words = title.split(whereSeparator: \.isWhitespace).count
        var score = 70
        if (2...6).contains(words) { score += 16 }
        if title.contains(":") { score += 6 }
        let lower = title.lowercased()
        if ["garantiert", "mühelos", "sofort reich", "für immer", "wunder"].contains(where: lower.contains) {
            score -= 50
        }
        if lower.hasPrefix("ich ") || lower.hasPrefix("du ") { score -= 8 }
        return max(0, score)
    }

    static func hasUsableChapterPlan(_ chapters: [PlannedChapter]) -> Bool {
        guard chapters.count >= 3 else { return false }
        return chapters.allSatisfy { chapter in
            !isGenericPlaceholder(chapter.title)
                && !isGenericPlaceholder(chapter.goal)
                && chapter.goal.wordCount >= 5
                && chapter.conflict.wordCount >= 3
        }
    }

    static func hasUsableScenePlan(_ scenes: [PlannedScene], expectedCount: Int) -> Bool {
        guard scenes.count >= expectedCount else { return false }
        let requiredScenes = Array(scenes.prefix(expectedCount))
        return requiredScenes.allSatisfy { scene in
            !scene.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !scene.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && scene.goal.wordCount >= 5
                && scene.obstacle.wordCount >= 3
                && scene.turn.wordCount >= 3
                && !isGenericPlaceholder(scene.goal)
                && !isGenericPlaceholder(scene.obstacle)
                && !isGenericPlaceholder(scene.turn)
        }
    }

    static func acceptsDraftScene(_ text: String, targetWords: Int) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        guard !containsMetaRequest(cleaned) else { return false }
        guard hasCompleteSentenceEnding(cleaned) else { return false }
        guard !PublicContentGuard.disclosureViolation(in: cleaned) else { return false }
        let minimum = max(80, Int(Double(targetWords) * 0.55))
        let maximum = max(minimum, Int(Double(targetWords) * 1.25))
        return cleaned.wordCount >= minimum && cleaned.wordCount <= maximum
    }

    static func isWithinWordTarget(_ text: String, targetWords: Int,
                                   lowerRatio: Double = 0.75,
                                   upperRatio: Double = 1.25) -> Bool {
        guard targetWords > 0 else { return !text.isEmpty }
        let count = text.wordCount
        return count >= Int(Double(targetWords) * lowerRatio)
            && count <= Int(Double(targetWords) * upperRatio)
    }

    static func isGenericPlaceholder(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.isEmpty { return true }
        if normalized == "titel" || normalized == "neues buch" || normalized == "unbenannt" { return true }
        if normalized.range(of: #"^kapitel\s+\d+$"#, options: .regularExpression) != nil {
            return true
        }
        let patterns = [
            "roman-roman",
            "setze den plot konsequent fort",
            "führe das kapitelziel weiter",
            "vertiefe das kapitelziel",
            "nächstes buch",
            "untitled"
        ]
        if patterns.contains(where: { normalized == $0 || normalized.hasPrefix($0) }) { return true }
        let hollowPlanningPhrases = [
            "bringt die hauptfigur durch",
            "blockiert das unmittelbare vorankommen",
            "eine neue wendung verschiebt die lage",
            "enthüllt eine information, die das kräfteverhältnis",
            "lässt einen rückschlag den einsatz",
            "einstieg: die perspektivfigur",
            "komplikation: ausgehend vom ende",
            "zuspitzung: die folgen der vorigen szenen",
            "wende und übergang: eine entscheidung oder enthüllung"
        ]
        return hollowPlanningPhrases.contains(where: normalized.contains)
    }

    /// Verhindert Auto-Buchtitel nach schwachen Berufs-Hooks wie
    /// "Die Imkerin von Ulrichstein" oder "Das Schweigen der Imkerin".
    /// Berufe dürfen in der Geschichte vorkommen, aber nicht als austauschbarer
    /// Titel-Hook die komplette Idee tragen.
    static func isOccupationalTitleCliche(_ title: String) -> Bool {
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }

        let occupationalWords = [
            "imkerin", "imker", "kassiererin", "kassierer", "bäckerin", "bäcker",
            "lehrerin", "lehrer", "ärztin", "arzt", "pflegerin", "pfleger",
            "polizistin", "polizist", "anwältin", "anwalt", "journalistin", "journalist",
            "floristin", "florist", "bibliothekarin", "bibliothekar",
            "buchhändlerin", "buchhändler", "friseurin", "friseur", "sekretärin",
            "sekretär", "köchin", "koch", "architektin", "architekt",
            "ingenieurin", "ingenieur", "forscherin", "forscher", "maklerin",
            "makler", "verkäuferin", "verkäufer", "fahrerin", "fahrer",
            "taxifahrerin", "taxifahrer", "gärtnerin", "gärtner", "wirtin", "wirt"
        ]
        let locationConnectors = [" von ", " aus ", " in ", " am ", " an der ", " im "]
        let genericGenitiveHooks = [
            "geheimnis", "schweigen", "lüge", "wahrheit", "versprechen", "tagebuch",
            "brief", "erbe", "schatten", "lied", "haus", "leben", "liebe",
            "winter", "sommer", "nacht", "stimme", "spur", "rückkehr"
        ]

        let hasArticlePrefix = normalized.hasPrefix("die ") || normalized.hasPrefix("der ")
            || normalized.hasPrefix("das ") || normalized.hasPrefix("eine ")
            || normalized.hasPrefix("ein ")
        guard hasArticlePrefix else {
            return false
        }

        for word in occupationalWords {
            guard normalized.range(of: #"\b\#(word)\b"#, options: .regularExpression) != nil else {
                continue
            }
            if normalized.range(of: #"^(die|der|das|eine|ein)\s+\#(word)\b"#, options: .regularExpression) != nil {
                return true
            }
            if locationConnectors.contains(where: normalized.contains) {
                return true
            }
            let usesGenericGenitiveHook = genericGenitiveHooks.contains { hook in
                normalized.range(of: #"\b\#(hook)\b"#, options: .regularExpression) != nil
            }
            if usesGenericGenitiveHook
                && normalized.range(of: #"\b(der|des|einer|eines)\s+\#(word)\b"#,
                                    options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    static func containsMetaRequest(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let patterns = [
            "bitte füge",
            "bitte gib",
            "fehlt in deiner",
            "nicht übermittelt",
            "nicht im prompt enthalten",
            "keine szene bereitgestellt",
            "szene fehlt",
            "szenentext fehlt",
            "muss noch ausgeschrieben werden",
            "im manuskript neu erzeugen",
            "geplanter inhalt:",
            "ich kann die szene leider nicht schreiben",
            "ich benötige noch",
            "fehlende angaben",
            "als sprachmodell",
            "als ki-modell",
            "kann ich nicht schreiben",
            "kann ich nicht erstellen",
            "kann ich nicht verfassen",
            "kann ich nicht generieren",
            "kann ich nicht beantworten",
            "kann ich dieser anfrage nicht"
        ]
        if patterns.contains(where: { normalized.contains($0) }) { return true }
        // "als ki" nur als eigenständiges Wort – sonst matcht es "als Kind",
        // "als Kino" usw. und verwirft korrekte Romantexte.
        return normalized.range(of: #"\bals ki\b"#, options: .regularExpression) != nil
    }

    /// Unverwechselbare Instruktions-Fragmente aus den Prompts. Tauchen sie im
    /// generierten Text auf, hat das Modell eine Anweisung in die Prosa kopiert.
    static let promptInstructionMarkers = [
        "knüpfe nahtlos daran an",
        "knüpfe daran an",
        "setze die szene unmittelbar fort",
        "ohne das geschehene zu wiederholen",
        "wörtliches ende der vorherigen szene",
        "bisherige handlung",
        "letzte szenen im detail",
        "bisherige kapitel",
        "genre-handwerk",
        "verbotene floskeln",
        "sog-techniken",
        "keine überschriften",
        "keine meta-kommentare",
        "meta-kommentar",
        "langform-pflicht",
        "schreibe ausschließlich auf",
        "schreibe die szene",
        "schreibe szene",
        "der erste satz ist der wichtigste",
        "erste szene des buches",
        "letzte szene des buches",
        "beginne mitten in der bewegung",
        "zeigen statt behaupten",
        "dialog mit subtext",
        "bestseller-standard",
        "gib ausschließlich den fertigen prosatext",
        "übernimm niemals anweisungen",
        "hinweise aus diesem auftrag",
        "fertigen prosatext der szene",
        "zielumfang"
    ]

    /// Teilmenge der Marker, die GELÖSCHT werden dürfen: nur eindeutige
    /// Anweisungs-Fragmente, die in echter Belletristik praktisch nie vorkommen.
    /// Mehrdeutige Marker (z.B. „schreibe die szene", „bisherige handlung",
    /// „der erste satz ist der wichtigste") lösen weiterhin eine Neufassung aus
    /// (via `promptInstructionMarkers`), werden aber NICHT satzweise gelöscht –
    /// sonst verschwänden legitime Dialog-/Erzählsätze und der Lesefluss bräche.
    static let deletableInstructionMarkers = [
        "knüpfe nahtlos daran an",
        "knüpfe daran an",
        "setze die szene unmittelbar fort",
        "ohne das geschehene zu wiederholen",
        "wörtliches ende der vorherigen szene",
        "letzte szenen im detail",
        "genre-handwerk",
        "verbotene floskeln",
        "sog-techniken",
        "keine überschriften",
        "keine meta-kommentare",
        "langform-pflicht",
        "gib ausschließlich den fertigen prosatext",
        "übernimm niemals anweisungen",
        "hinweise aus diesem auftrag",
        "fertigen prosatext der szene",
        "bestseller-standard",
        "zielumfang"
    ]

    /// Prompt-Labels, die als eigene Zeile auftauchen, wenn das Modell die
    /// Szenen-Vorgabe abschreibt.
    static let promptLabelPrefixes = [
        "stil:", "stilregeln:", "kapitelziel:", "sprache:", "tonalität:",
        "perspektive:", "erzählperspektive:", "zeitform:", "ort:", "zeit:",
        "ziel:", "hindernis:", "wendung am ende:", "wendung:", "figuren:",
        "szene:", "thema:", "zielumfang:", "zielwörter:", "zielwortzahl:",
        "genre:", "tonalität:", "kapitel:", "- ort:", "- zeit:", "- ziel:",
        "- hindernis:", "- wendung", "verdichtete fassung", "überarbeitete fassung",
        "ueberarbeitete fassung", "endfassung"
    ]

    /// Hat das Modell eine Prompt-Anweisung/-Label in die Prosa durchsickern lassen?
    /// Wird beim Schreiben genutzt, um eine betroffene Szene NEU zu generieren.
    static func containsPromptArtifacts(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if promptInstructionMarkers.contains(where: { lowered.contains($0) }) { return true }
        for line in text.components(separatedBy: .newlines) {
            let l = line.trimmingCharacters(in: .whitespaces).lowercased()
            if promptLabelPrefixes.contains(where: { l.hasPrefix($0) }) { return true }
        }
        return false
    }

    /// Entfernt durchgesickerte Prompt-Anweisungen/-Labels aus generierter Prosa –
    /// SATZGENAU, damit auch ein mitten im Absatz eingebetteter Anweisungssatz
    /// verschwindet, ohne die umgebende Erzählung zu beschädigen. Reine Label-Zeilen
    /// (z.B. „Ort: Bäckerei") werden komplett entfernt. Das darf NIE im Buch landen.
    /// Entfernt eine vom Modell vorangestellte ÜBERSCHRIFT aus dem Szenentext.
    ///
    /// Der Auftrag lautet „Schreibe diese Szene als vollständige Endfassung neu" – viele
    /// Modelle setzen daraufhin eine Kopfzeile davor: „Kapitel 34, Szene 2 – Endfassung".
    /// An einem fertigen Buch gemessen betraf das 39 von 184 Szenen, also über ein
    /// Fünftel des Manuskripts. Ohne diese Reinigung stehen die Zeilen im gedruckten Buch.
    ///
    /// Entfernt werden nur ERSTE Zeilen, die eindeutig eine Arbeitsangabe sind – ein
    /// echter Kapiteltitel oder ein Prosa-Anfang bleibt unangetastet.
    /// Erzwingt die kanonischen Figurennamen aus der Story Bible.
    ///
    /// Das szenenweise erzeugte Manuskript vertauscht Nachnamen zwischen Figuren – ein
    /// klassischer LLM-Fehler. Am frisch produzierten Buch „Sie hat mich geküsst, bevor
    /// sie starb" nachgewiesen: Der Held heißt in der Story Bible „Jonas Brenner", im
    /// Text stand aber 2× „Jonas Hartmann" – „Hartmann" ist der Nachname der Figur Lina.
    /// Die Konsistenzprüfung meldete das als KRITISCH („zwei Personen oder
    /// Namensinkonsistenz?") und das Buch fiel zu Recht durch.
    ///
    /// Diese Korrektur ist streng begrenzt und dadurch sicher: Ersetzt wird nur
    /// „Vorname FremderNachname", wobei der FremderNachname NACHWEISLICH einer ANDEREN
    /// Figur gehört. Ein Vorname mit unbekanntem Nachnamen bleibt unangetastet, ebenso
    /// Geschwister mit gleichem Nachnamen (Clara/Mira/Niko Voss).
    ///
    /// - Parameter namen: kanonische vollständige Namen aus der Story Bible.
    static func enforcingNameCanon(_ text: String, namen: [String]) -> (text: String, korrekturen: [String]) {
        // Vorname → richtiger Nachname; Menge aller bekannten Nachnamen.
        var vorZuNach: [String: String] = [:]
        var nachnamen = Set<String>()
        let anreden: Set<String> = ["herr", "frau", "dr", "dr.", "prof", "prof.", "sir", "lady", "miss", "mr", "mrs"]
        for name in namen {
            let teile = name.split(separator: " ").map(String.init)
            guard teile.count >= 2 else { continue }
            let vor = teile[0], nach = teile[teile.count - 1]
            guard vor.count >= 3, nach.count >= 3, !anreden.contains(vor.lowercased()) else { continue }
            vorZuNach[vor] = nach
            nachnamen.insert(nach)
        }
        guard !vorZuNach.isEmpty else { return (text, []) }

        var ergebnis = text
        var korrekturen: [String] = []
        for (vor, richtig) in vorZuNach {
            for falsch in nachnamen where falsch != richtig {
                // Nur echte Vertauschung: „Vorname FremderNachname" → „Vorname RichtigerNachname".
                let muster = "\\b" + NSRegularExpression.escapedPattern(for: vor)
                    + "\\s+" + NSRegularExpression.escapedPattern(for: falsch) + "\\b"
                guard let re = try? NSRegularExpression(pattern: muster) else { continue }
                let bereich = NSRange(ergebnis.startIndex..., in: ergebnis)
                let treffer = re.numberOfMatches(in: ergebnis, range: bereich)
                guard treffer > 0 else { continue }
                ergebnis = re.stringByReplacingMatches(
                    in: ergebnis, range: bereich,
                    withTemplate: NSRegularExpression.escapedTemplate(for: "\(vor) \(richtig)"))
                korrekturen.append("\(vor) \(falsch)→\(vor) \(richtig) (\(treffer)×)")
            }
        }
        return (ergebnis, korrekturen)
    }

    /// Setzt deutsche Anführungszeichen richtig und räumt Satzzeichen-Doppler auf.
    ///
    /// Im ausgelieferten Buch nachgezählt: 3573 Zitate wurden mit dem typografischen „
    /// geöffnet, aber nur 2648 korrekt mit “ geschlossen – **967 endeten mit dem geraden
    /// Schreibmaschinen-Zeichen "**. Im gedruckten Buch und im E-Book sieht man das sofort.
    /// Dazu drei doppelte Satzpunkte („… nahm Lena das Metall des Rings wahr..").
    ///
    /// Die Umwandlung ist ortsabhängig: Ein gerades Zeichen VOR einem Buchstaben öffnet
    /// (wird „), eines NACH einem Buchstaben oder Satzzeichen schließt (wird “). Genau so
    /// setzt es ein Setzer auch.
    static func fixingTypography(_ text: String) -> String {
        var ergebnis = ""
        ergebnis.reserveCapacity(text.count)
        let zeichen = Array(text)
        for (i, c) in zeichen.enumerated() {
            guard c == "\"" else { ergebnis.append(c); continue }
            // Was steht davor, was danach?
            let davor = i > 0 ? zeichen[i - 1] : " "
            let danach = i + 1 < zeichen.count ? zeichen[i + 1] : " "
            let schliesst = davor.isLetter || davor.isNumber
                || ".,!?;:…".contains(davor) || davor == "\u{201C}"
            let oeffnet = danach.isLetter || danach.isNumber || danach == "\u{201E}"
            if schliesst {
                ergebnis.append("\u{201C}")           // “
            } else if oeffnet {
                ergebnis.append("\u{201E}")           // „
            } else {
                ergebnis.append("\u{201C}")           // im Zweifel schließen
            }
        }
        // Doppelte Satzpunkte, die keine Auslassung sind.
        while let r = ergebnis.range(of: "(?<![.])\\.\\.(?!\\.)", options: .regularExpression) {
            ergebnis.replaceSubrange(r, with: ".")
        }
        // Leerzeichen vor Satzzeichen – aber NICHT vor Auslassungspunkten: Dort gehört
        // im Deutschen ein Leerzeichen hin, wenn ein ganzes Wort ausgelassen ist
        // („Drei Punkte bleiben … erhalten"). Der erste Wurf zog das zusammen.
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]+([,;:!?])", with: "$1", options: .regularExpression)
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]+\\.(?![.\\s])", with: ".", options: .regularExpression)
        // Mehrfache Leerzeichen innerhalb einer Zeile.
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        return ergebnis
    }

    /// Entfernt Arbeitsmarken ÜBERALL im Text – nicht nur in der ersten Zeile.
    ///
    /// WARUM DAS NÖTIG IST: Im ausgelieferten Buch „Das letzte Streichholz" standen
    /// 85 Arbeitsmarken mitten in der Prosa, verteilt über 21 von 46 Kapiteln:
    ///
    ///     KAPITEL 10, SZENE 1, VERSUCH 2/2
    ///     Kapitel 4, Szene 1 – Endfassung
    ///     KAPITZEL 36, SZENE 2, VERSUCH 1/2
    ///     ABSATZ:
    ///
    /// Diese Zeilen wurden mit dem EPUB zu Amazon hochgeladen. `strippingSceneHeading`
    /// half dagegen nicht: Es sieht nur die ERSTE Zeile an, wird nur an einer von mehreren
    /// Erzeugungsstellen aufgerufen, und sein Muster `^kapitel\s*\d+` greift beim
    /// Tippfehler „KAPITZEL" nicht.
    ///
    /// Diese Funktion arbeitet zeilenweise über den ganzen Text und ist gegen genau solche
    /// Verdreher tolerant. Sie entfernt NUR Zeilen, die als reine Arbeitsmarke erkennbar
    /// sind – kurz, ohne Satzschluss, mit Stellen- oder Fassungsangabe. Ein Prosasatz, der
    /// zufällig „Kapitel" enthält („Sie las das Kapitel zweimal."), bleibt stehen.
    /// - Parameter buchtitel: Steht der Buchtitel als eigene Zeile am Kapitelanfang, ist
    ///   das ebenfalls ein Erzeugungsrest. Im ausgelieferten Buch stand „Das letzte
    ///   Streichholz" als erste Zeile von Kapitel 1 – mitten im Prosatext, direkt vor dem
    ///   ersten Satz. Ein Satz, der den Titel beiläufig ENTHÄLT, bleibt unangetastet;
    ///   entfernt wird nur eine Zeile, die aus nichts anderem besteht.
    static func strippingProductionMarkers(_ text: String, buchtitel: String = "") -> String {
        let zeilen = text.components(separatedBy: .newlines)
        let titelNorm = buchtitel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var behalten: [String] = []
        var nurLeerzeilenBisher = true
        for zeile in zeilen {
            let roh = zeile.trimmingCharacters(in: .whitespacesAndNewlines)
            // Titelzeile nur am Anfang entfernen – später im Text könnte sie Absicht sein
            // (etwa ein Buch, das im Buch vorkommt).
            if nurLeerzeilenBisher, !titelNorm.isEmpty, roh.lowercased() == titelNorm { continue }
            if !roh.isEmpty { nurLeerzeilenBisher = false }
            if istArbeitsmarke(zeile) { continue }
            behalten.append(zeile)
        }
        // Durch entfernte Zeilen entstandene Dreifach-Leerzeilen wieder zusammenziehen.
        var ergebnis = behalten.joined(separator: "\n")
        while ergebnis.contains("\n\n\n") {
            ergebnis = ergebnis.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return ergebnis.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Einheitlicher letzter Filter für jeden Text, der in Datenbank oder Export landet.
    /// Zentralisiert die bisher auf mehrere Produktionsphasen verteilte Bereinigung.
    static func cleaningStoredBookText(_ text: String, bookTitle: String = "") -> String {
        fixingTypography(
            strippingProductionMarkers(
                humanizeProse(
                    strippingInlineFormatting(
                        strippingPromptArtifacts(text)
                    )
                ),
                buchtitel: bookTitle
            )
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ist diese Zeile eine reine Arbeitsmarke der Produktion?
    static func istArbeitsmarke(_ zeile: String) -> Bool {
        let roh = zeile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roh.isEmpty, roh.count <= 90 else { return false }
        // Ohne Satzzeichen am Ende (Prosa endet auf . ! ? " ' – Marken nicht).
        let endetWieProsa = roh.hasSuffix(".") || roh.hasSuffix("!") || roh.hasSuffix("?")
            || roh.hasSuffix("\u{201C}") || roh.hasSuffix("\u{201D}") || roh.hasSuffix("\"")
        let niedrig = roh.lowercased()

        // „VERSUCH 2/2", „VERSUCH 1 ABSATZ:" – eindeutig, auch mit Satzzeichen.
        if niedrig.range(of: "versuch\\s*\\d+\\s*(/\\s*\\d+)?", options: .regularExpression) != nil {
            return true
        }
        if niedrig.range(of: "^absatz\\s*:", options: .regularExpression) != nil { return true }

        // Stellenangabe: „kapitel 4, szene 1" – tolerant gegen Verdreher wie „kapitzel".
        // \p{L}{0,2} lässt bis zu zwei eingeschobene Buchstaben zu.
        let nenntStelle = niedrig.range(
            of: "kapit\\p{L}{0,3}\\s*\\d+\\s*[,.\\-–]?\\s*szene\\s*\\d+",
            options: .regularExpression) != nil
        let nenntFassung = niedrig.contains("endfassung") || niedrig.contains("rohfassung")
            || niedrig.contains("fassung:") || niedrig.contains("überarbeitet")
        if nenntStelle || nenntFassung { return !endetWieProsa || nenntStelle }

        // Alleinstehende Szenenangabe ohne Prosa-Satzschluss.
        if !endetWieProsa,
           niedrig.range(of: "^(kapit\\p{L}{0,3}|szene)\\s*\\d+", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func strippingSceneHeading(_ text: String) -> String {
        var zeilen = text.components(separatedBy: .newlines)
        // Führende Leerzeilen weg.
        while let erste = zeilen.first, erste.trimmingCharacters(in: .whitespaces).isEmpty {
            zeilen.removeFirst()
        }
        guard let kopf = zeilen.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !kopf.isEmpty else { return text }

        // Eine Arbeitsüberschrift ist kurz und nennt Kapitel/Szene oder eine Fassung.
        let niedrig = kopf.lowercased()
        let nenntStelle = niedrig.range(of: "^(kapitel|szene)\\s*\\d+", options: .regularExpression) != nil
            || niedrig.range(of: "\\bszene\\s*\\d+", options: .regularExpression) != nil
        let nenntFassung = niedrig.contains("endfassung") || niedrig.contains("überarbeitet")
            || niedrig.contains("rohfassung") || niedrig.contains("fassung:")
        let istKurz = kopf.count <= 80

        guard istKurz, nenntStelle || nenntFassung else { return text }

        zeilen.removeFirst()
        while let erste = zeilen.first, erste.trimmingCharacters(in: .whitespaces).isEmpty {
            zeilen.removeFirst()
        }
        let rest = zeilen.joined(separator: "\n")
        // Sicherheitsnetz: Wenn danach fast nichts übrig bleibt, war es doch keine
        // Überschrift – dann lieber den Originaltext behalten.
        return rest.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 ? rest : text
    }

    static func strippingPromptArtifacts(_ text: String) -> String {
        var keptLines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if trimmed.isEmpty { keptLines.append(line); continue }
            // Ganze Label-/Vorgabe-Zeile entfernen.
            if promptLabelPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
            // Innerhalb der Zeile nur die Anweisungs-SÄTZE entfernen.
            let cleaned = removingInstructionSentences(from: line)
            if !cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
                keptLines.append(cleaned)
            }
        }
        var result = keptLines.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Entfernt durchgesickerte Markdown-Auszeichnung aus der Prosa: **fett**,
    /// *kursiv*, _kursiv_ sowie übrig gebliebene Einzel-Sternchen und Emojis.
    /// Reine Szenentrenner-Zeilen („***" / „* * *") bleiben erhalten, weil der
    /// Export sie als Szenenwechsel erkennt. So verschwinden die „komischen
    /// Sterne" mitten im Satz aus Anzeige UND Export – auch bei alten Büchern.
    static func strippingInlineFormatting(_ text: String) -> String {
        let cleanedLines = text.components(separatedBy: "\n").map { line -> String in
            let compact = line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
            if compact == "***" { return line } // Szenentrenner unangetastet lassen
            var l = line
            l = l.replacingOccurrences(of: #"\*\*([^*\n]+?)\*\*"#, with: "$1", options: .regularExpression)
            l = l.replacingOccurrences(of: #"\*([^*\n]+?)\*"#, with: "$1", options: .regularExpression)
            l = l.replacingOccurrences(of: #"(?<![\p{L}\p{N}])_([^_\n]+?)_(?![\p{L}\p{N}])"#,
                                       with: "$1", options: .regularExpression)
            // Übrig gebliebene Einzel-Sterne in einer Prosazeile entfernen (nie legitim).
            l = l.replacingOccurrences(of: "*", with: "")
            // Emojis/Bildzeichen haben in einem Roman nichts verloren. Skalar-basiert
            // und deterministisch (keine ICU-Eigenheiten bei Emoji-Blöcken).
            l.removeAll { (ch: Character) in
                ch.unicodeScalars.contains { s in
                    let v = s.value
                    return (0x1F000...0x1FFFF).contains(v) || (0x2600...0x27BF).contains(v)
                        || (0x2300...0x23FF).contains(v) || (0xFE00...0xFE0F).contains(v) || v == 0x200D
                }
            }
            return l
        }
        // Doppelte Leerzeichen, die durch das Entfernen entstehen können, glätten.
        return cleanedLines.joined(separator: "\n")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }

    /// Macht die Prosa „menschlicher": entfernt Gedankenstriche (—, – als
    /// Stilmittel), die ein typisches KI-Erkennungsmerkmal sind, und ersetzt sie
    /// durch natürliche Interpunktion. Zahlenbereiche (z.B. „12–13") bleiben
    /// unangetastet. Räumt anschließend doppelte Satzzeichen/Leerzeichen auf.
    static func humanizeProse(_ text: String) -> String {
        var t = text
        // En-Dash als Gedankenstrich (zwischen Wörtern) → Komma.
        // Zahlenbereiche wie „12–13" bleiben unangetastet (verlangen Buchstaben).
        t = t.replacingOccurrences(
            of: "(?<=\\p{L})\\s*–\\s*(?=\\p{L})", with: ", ", options: .regularExpression)
        // Em-Dash ist nie ein Zahlenbereich → immer durch Komma ersetzen.
        t = t.replacingOccurrences(of: "\\s*—\\s*", with: ", ", options: .regularExpression)
        // Aufräumen: Leerzeichen vor Satzzeichen, doppelte Kommas, führende Kommas,
        // doppelte Leerzeichen.
        t = t.replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?m)^\\s*,\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        // Modell-Echo entfernen: am Kapitelanfang verdreifacht sich oft der erste Satz.
        t = collapsingImmediateRepeats(t)
        return t
    }

    /// Entfernt unmittelbar wiederholte identische Absätze/Zeilen (häufiges Modell-Artefakt:
    /// der erste Satz eines Kapitels steht 2–3× hintereinander) sowie einen sofort doppelten
    /// Satz innerhalb einer Zeile. Durch anderen Text GETRENNTE Wiederholungen (stilistische
    /// Anaphern) bleiben unangetastet – nur direkte Dubletten werden eingeklappt.
    static func collapsingImmediateRepeats(_ text: String) -> String {
        // 1) Aufeinanderfolgende identische, nicht-leere Zeilen → eine.
        var deduped: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty,
               let last = deduped.last,
               last.trimmingCharacters(in: .whitespaces) == trimmed {
                continue
            }
            deduped.append(line)
        }
        // 2) Unmittelbar wiederholte Sätze innerhalb jeder Zeile einklappen. Der frühere
        // Regex mit Rückreferenz konnte auf längerer Prosa exponentiell zurückspringen
        // und den Produktionsprozess minutenlang bei 100 % CPU festhalten.
        return deduped
            .map(collapseImmediateSentenceRepeats)
            .joined(separator: "\n")
    }

    private static func collapseImmediateSentenceRepeats(in line: String) -> String {
        let characters = Array(line)
        let sentenceEndings = Set<Character>([".", "!", "?", "…"])
        let closingQuotes = Set<Character>(["\"", "”", "“", "’", "'", "»", "›"])
        var output = ""
        var previousSentence: String?
        var segmentStart = 0
        var index = 0

        while index < characters.count {
            guard sentenceEndings.contains(characters[index]) else {
                index += 1
                continue
            }

            var segmentEnd = index + 1
            while segmentEnd < characters.count,
                  closingQuotes.contains(characters[segmentEnd]) {
                segmentEnd += 1
            }
            let segment = String(characters[segmentStart..<segmentEnd])
            let normalized = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSignificant = normalized.count >= 12
            if !isSignificant || normalized != previousSentence {
                output += segment
            }
            previousSentence = isSignificant ? normalized : nil
            segmentStart = segmentEnd
            index = segmentEnd
        }

        if segmentStart < characters.count {
            output += String(characters[segmentStart...])
        }
        return output
    }

    /// Entfernt eine erste Textzeile/einen ersten Satz, der die Kapitelüberschrift wörtlich
    /// wiederholt (Modell-Artefakt: der Titel erscheint sonst doppelt – als Überschrift UND
    /// als erster Satz des Kapitels). Greift auch bei bereits erzeugten Büchern beim Re-Export.
    static func strippingLeadingTitleEcho(_ text: String, title: String) -> String {
        let normTitle = normalizedTitleKey(title)
        guard normTitle.count >= 8 else { return text }
        var lines = text.components(separatedBy: "\n")
        guard let idx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return text }
        let line = lines[idx].trimmingCharacters(in: .whitespaces)
        let sentenceEnd = line.firstIndex(where: { ".!?…".contains($0) })
        let firstSentence = sentenceEnd.map { String(line[...$0]) } ?? line
        guard normalizedTitleKey(firstSentence) == normTitle else { return text }
        var rest = ""
        if let e = sentenceEnd, line.index(after: e) < line.endIndex {
            rest = String(line[line.index(after: e)...]).trimmingCharacters(in: .whitespaces)
        }
        if rest.isEmpty { lines.remove(at: idx) } else { lines[idx] = rest }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTitleKey(_ s: String) -> String {
        let trimChars = CharacterSet(charactersIn: " \n\t.!?:;-\u{2014}\u{2013}\u{201E}\u{201C}\u{201D}\"'\u{00BB}\u{00AB}")
        return s.lowercased().trimmingCharacters(in: trimChars)
    }

    private static func removingInstructionSentences(from line: String) -> String {
        let lower = line.lowercased()
        // NUR eindeutige Marker löschen – mehrdeutige würden legitime Prosa fressen.
        guard deletableInstructionMarkers.contains(where: { lower.contains($0) }) else {
            return line // kein eindeutiges Anweisungs-Fragment → Zeile unverändert lassen
        }
        var kept: [String] = []
        line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: [.bySentences, .localized]) { sub, _, _, _ in
            guard let sub else { return }
            let s = sub.lowercased()
            if !deletableInstructionMarkers.contains(where: { s.contains($0) }) {
                kept.append(sub)
            }
        }
        let rebuilt = kept.joined()
        // Falls die Satzsegmentierung nichts trennen konnte, die ganze Zeile verwerfen.
        return rebuilt.trimmingCharacters(in: .whitespaces).isEmpty ? "" : rebuilt
    }

    // MARK: - KI-Erkennung (Anti-Detektor)

    /// Kuratierte Denylist hochsignifikanter deutscher KI-Floskeln (überwiegend
    /// Mehrwort-Phrasen, damit echte Prosa nicht fälschlich markiert wird).
    /// Quelle: synthetisiertes Experten-Korpus. Dient dem weichen Neufassungs-Gate
    /// beim Schreiben – NICHT zum mechanischen Löschen (das beschädigte Prosa).
    static let aiTellPhrases: [String] = [
        "ein schauer lief", "lief ihr über den rücken", "lief ihm über den rücken",
        "die zeit schien stillzustehen", "die zeit stand still", "die welt schien stillzustehen",
        "nichts würde mehr sein wie zuvor", "nichts war mehr wie zuvor", "nichts würde je wieder so sein",
        "ein lächeln umspielte", "ein lächeln huschte über", "ein schatten huschte über ihr gesicht",
        "ein wissendes lächeln", "ihr herz machte einen satz", "ihr herz schlug bis zum hals",
        "sein herz schlug bis zum hals", "das herz schlug ihr bis zum hals", "ihr herz schlug schneller",
        "ihr herz hämmerte", "ihr herz pochte wild", "ihr herz setzte einen schlag aus",
        "ein kloß bildete sich", "ein kloß in ihrem hals", "ein kloß steckte ihr im hals",
        "ein knoten in ihrem magen", "die luft war zum schneiden", "ein teil von ihr", "ein teil von ihm",
        "ein gefühl von", "ein gefühl der", "ein gefühl überkam sie", "eine mischung aus", "ein gemisch aus",
        "ein hauch von", "ein anflug von", "ein schwall von", "eine welle der", "eine welle von", "eine welle aus",
        "etwas in ihr", "etwas in ihm", "etwas in ihrem inneren", "in ihr begann etwas",
        "in ihm begann etwas", "etwas regte sich in ihr",
        "etwas regte sich in ihm", "etwas in ihr zerbrach", "in diesem moment", "in diesem augenblick",
        "für einen moment", "für einen augenblick", "einen moment lang", "einen augenblick lang",
        "einen herzschlag lang", "einen wimpernschlag lang", "sie atmete tief durch", "er atmete tief durch",
        "sie holte tief luft", "ihr atem stockte", "ihr stockte der atem", "der atem stockte ihr",
        "ihre augen weiteten sich", "ihre kehle schnürte sich zu", "ihre kehle wurde eng",
        "ihr magen zog sich zusammen", "sein magen krampfte", "sie schluckte schwer",
        "sie ballte die hände zu fäusten", "kaum merklich", "kaum wahrnehmbar", "kaum spürbar",
        "ein kalter schauer", "ein eiskalter schauer lief", "gänsehaut breitete sich aus",
        "machte sich breit", "breitete sich in ihr aus", "breitete sich in ihm aus", "durchfuhr sie",
        "durchfuhr ihn", "durchströmte sie", "durchströmte ihn", "überkam sie", "überkam ihn",
        "überrollte sie", "überrollte ihn", "stieg in ihr auf", "stieg in ihm auf", "wusch über sie hinweg",
        "wut stieg in ihr auf", "wut stieg in ihm auf", "wut kochte in ihm hoch", "panik stieg in ihr auf",
        "angst kroch in ihr hoch", "kroch in ihr hoch", "trauer überkam sie", "verzweiflung überrollte ihn",
        "es war, als ob", "es war, als würde", "es fühlte sich an, als", "als würde die zeit",
        "als wäre die welt", "in diesem moment verstand sie", "in diesem moment verstand er",
        "in diesem augenblick begriff sie", "in diesem augenblick verstand sie", "und so begriff sie",
        "und so begriff er", "und so wurde ihr klar", "sie wusste in diesem moment", "ihr wurde klar",
        "es wurde ihr bewusst", "stille breitete sich aus", "stille senkte sich über",
        "schweigen breitete sich aus", "eine bedrückende stille", "ein moment, der alles veränderte",
        "ein moment, den sie nie vergessen würde", "mehr als worte je könnten", "tief in ihrem inneren",
        "tief in ihrem innersten", "tief in seinem inneren", "in ihrem innersten", "sondern vielmehr",
        "auf gewisse weise", "auf seltsame weise", "auf unerklärliche weise", "wie aus dem nichts",
        "ein zeichen ihrer unsicherheit", "ein zeichen seiner nervosität", "verriet ihre nervosität",
        "nicht benennen konnte", "nicht benennen wollte", "nicht in worte fassen",
        "das sie nicht benennen", "das er nicht benennen",
        // Aus der Diagnose echter Bücher ergänzt (Mehrwort-Floskeln; abstrakte
        // Leitsubstantive wie Kontrolle/Nähe bewusst NICHT hier, sondern im Prompt
        // frequenzbegrenzt, sonst würden sie gute Prosa fälschlich markieren).
        "als hätte jemand", "als ob jemand", "als hätte man", "wie ein krankheitsbild",
        "wie in trance", "wie betäubt", "wie ferngesteuert", "wie von selbst",
        "etwas zog sich in ihr zusammen", "etwas brach in ihr", "etwas verschob sich zwischen ihnen",
        "ein gefühl, das sie nicht einordnen konnte", "ein gefühl, das sie nicht kannte",
        "sie konnte es nicht in worte fassen", "sie hätte es nicht erklären können",
        "irgendetwas an ihm", "irgendetwas an ihr", "ein stich von eifersucht", "ein stich von schuld",
        "ein knoten im magen", "ihr herz zog sich zusammen", "eine seltsame vertrautheit",
        "merkwürdig vertraut", "ein wohliges kribbeln", "ein kribbeln im bauch",
        "schmetterlinge im bauch", "tausend schmetterlinge", "still und reglos", "leer und kalt",
        "fremd und vertraut zugleich", "roh und ehrlich", "zart und zerbrechlich",
        "klar und unmissverständlich", "müde und ausgelaugt", "nah und doch fern",
        "ihre blicke trafen sich", "ihre blicke begegneten sich", "die luft zwischen ihnen knisterte",
        "es knisterte zwischen ihnen", "die anziehung zwischen ihnen war greifbar",
        "die spannung zwischen ihnen war greifbar", "ein magnetischer sog",
        "sein blick bohrte sich in ihren", "sein blick durchbohrte sie", "die stille war ohrenbetäubend",
        "die dunkelheit legte sich wie ein mantel", "ein lächeln, das ihre augen nicht erreichte",
        "ein lächeln, das seine augen nicht erreichte", "die welt um sie herum verschwand",
        "alles andere verblasste", "beinahe zärtlich", "fast schon zärtlich",
        "für den bruchteil einer sekunde", "den bruchteil einer sekunde lang",
        // Aus dem Repetition-Scan echter Bücher: verbatim überstrapazierte Standard-Beats,
        // die den Lesefluss zerstören (z.B. „öffnete den Mund, schloss ihn" 36x, „drehte
        // sich nicht um" 86x, „…", sagte sie. Keine Frage." 27x in einem einzigen Buch).
        "öffnete den mund, schloss ihn", "den mund, schloss ihn wieder", "drehte sich nicht um",
        "sagte sie. keine frage", "sagte er. keine frage",
        "etwas, das sie nicht sehen konnte", "etwas, das sie nicht deuten konnte",
        "etwas, das sie nicht lesen konnte",
        "unweigerlich", "zweifellos", "gleichsam", "nichtsdestotrotz",
        // Weitere überstrapazierte Cliché-/KI-Wendungen (aus Lesproben echter KI-Romane)
        "ihr atem stockte", "sein atem stockte", "der atem stockte", "sie hielt den atem an",
        "ihr herz raste", "ihr herz hämmerte", "ihr herz pochte", "ein kloß im hals",
        "jede faser ihres körpers", "mit jeder faser", "die zeit stand still",
        "die zeit schien stillzustehen", "alles in ihr schrie", "eine welle der",
        "wie ein offenes buch", "achterbahn der gefühle", "ein wirbelsturm der gefühle"
    ]

    /// Zählt die Treffer aus `aiTellPhrases` im Text (Gesamtvorkommen).
    static func aiTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in aiTellPhrases {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    static func aiTellMatches(in text: String, maxResults: Int = 20) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in aiTellPhrases where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    static func draftQualityPenalty(_ text: String) -> Int {
        let clarity = clarityAssessment(text)
        return aiTellCount(text) * 10
            + circumlocutionCount(text) * 3
            + jargonTellCount(text) * 15
            + archaicTellCount(text) * 15
            + clarity.vagueReferences * 5
            + clarity.hypotheticalComparisons * 4
            + clarity.filterReactions * 3
            + (containsPromptArtifacts(text) || containsMetaRequest(text) ? 100 : 0)
            + (isLikelyTruncated(text) ? 100 : 0)
    }

    /// Altertümliche/„mittelalterliche“, geschwollene Wörter, die moderne Profi-Prosa
    /// NICHT verwendet. Schon wenige Treffer lassen einen Text antiquiert klingen.
    static let archaicTellPhrases: [String] = [
        "alsbald", "fürwahr", "sintemal", "weiland", "dünkte", "dünkt ", "wohlan",
        "antlitz", "jüngling", "die maid", "junge maid", "das weib", "ein weib",
        "holde ", "holder ", "es begab sich", "begab sich", "allerorten", "allzumal",
        "ingleichen", "sodann", "auf dass", "des nachts", "ein jeglich", "geziemt",
        "gewahrte", "hub an", "sann nach", "zur stund"
    ]

    /// Akademisches Fachvokabular/Bildungswörter, die normale Leser nicht kennen und
    /// die in Unterhaltungsromanen nichts verloren haben (Dave-Feedback: „Mediävistiker"
    /// sagt niemand). Bewusst nur EINDEUTIG seltene Wörter – keine False Positives.
    static let jargonTellPhrases: [String] = [
        "mediävist", "komparatist", "kartographisch", "kartografisch", "diaphan",
        "ephemer", "evozier", "konzedier", "proliferier", "habilitand", "hermeneut",
        "ontolog", "epistemolog", "palimpsest", "apokryph", "äquidistant",
        "dichotom", "paradigmat", "narratolog", "semiot", "diskursiv"
    ]

    /// Umschreibungs-Marker: Benennungs-Vermeidung, Korrekturfiguren und Ins-Ungefähre-
    /// Vergleiche. Einzeln legitim – GEHÄUFT machen sie den Text kryptisch und der Leser
    /// versteht die Geschichte nicht mehr (Dave-Feedback zu echten Buchauszügen).
    static let circumlocutionMarkers: [String] = [
        "das, was", "etwas, das", "etwas, dass", "so etwas wie", "eine art ",
        ", sondern", "als ob es", "wie etwas, das", "nicht benennen", "kein wort dafür",
        "etwas härterem als", "etwas anderem als", "aus etwas, das"
    ]

    static let vagueReferenceMarkers: [String] = [
        "etwas, das", "etwas in ihr", "etwas in ihm", "irgendetwas",
        "nicht benennen", "nicht einordnen", "nicht deuten", "nicht erklären konnte",
        "konnte nicht sagen", "was er nicht aussprach",
        "was sie nicht aussprach", "ohne zu wissen warum", "ohne zu wissen, warum",
        "eine art ", "so etwas wie"
    ]

    static let hypotheticalComparisonMarkers: [String] = [
        "als würde", "als hätte", "als wäre", "als ob", "als wollte", "als könnte", "als müsste",
        "als sollte", "als gehöre", "als fürchte"
    ]

    static let filterReactionMarkers: [String] = [
        "sie spürte", "er spürte", "sie bemerkte", "er bemerkte",
        "sie fühlte", "er fühlte", "sie wusste nicht", "er wusste nicht",
        "ihr wurde klar", "ihm wurde klar", "sie konnte nicht verstehen",
        "er konnte nicht verstehen"
    ]

    static func clarityAssessment(_ text: String) -> ProseClarityAssessment {
        let words = max(1, text.wordCount)
        return ProseClarityAssessment(
            vagueReferences: phraseOccurrenceCount(in: text, phrases: vagueReferenceMarkers),
            hypotheticalComparisons: phraseOccurrenceCount(
                in: text, phrases: hypotheticalComparisonMarkers),
            filterReactions: phraseOccurrenceCount(in: text, phrases: filterReactionMarkers),
            vagueReferenceLimit: max(1, words / 300),
            hypotheticalComparisonLimit: max(2, words / 220),
            filterReactionLimit: max(2, words / 250)
        )
    }

    static func clarityRepairPhrases(in text: String, maxResults: Int = 30) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in vagueReferenceMarkers
            + hypotheticalComparisonMarkers
            + filterReactionMarkers where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    private static func phraseOccurrenceCount(in text: String, phrases: [String]) -> Int {
        let lower = text.lowercased()
        var count = 0
        for phrase in phrases {
            var searchRange = lower.startIndex..<lower.endIndex
            while let match = lower.range(of: phrase, range: searchRange) {
                count += 1
                searchRange = match.upperBound..<lower.endIndex
            }
        }
        return count
    }

    /// Zählt Umschreibungs-Marker (Gesamtvorkommen).
    static func circumlocutionCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in circumlocutionMarkers {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    static func circumlocutionMatches(in text: String, maxResults: Int = 20) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in circumlocutionMarkers where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    /// Zählt Fachvokabular-Marker (Gesamtvorkommen).
    static func jargonTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in jargonTellPhrases {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    /// Zählt altertümliche Marker (Gesamtvorkommen).
    static func archaicTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in archaicTellPhrases {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    // MARK: - Stilticks (Frequenz-Übernutzung, an der Leser KI-Prosa erkennen)

    /// Deterministische Frequenz-Prüfung auf stilistische Ticks, die einzeln legitim
    /// sind, aber gehäuft sofort nach KI klingen. Aus der Diagnose echter Produktionen:
    /// „Nicht …“-Satzanfänge (die LLM-Rhetorik „Nicht X. Sondern Y.“) standen 365× in
    /// einem einzigen Buch; dazu Körper-Beat-Lexeme (schlucken/Atem/hämmern) und
    /// Adverb-Krücken (leise/langsam/fast). Liefert konkrete, prompt-taugliche
    /// Anweisungen. WEICHES Signal: fließt in Neufassungs-Hinweise ein, wirft NIE
    /// und blockiert NIE die Freigabe (Anti-Hänger-Regel).
    static func styleTicViolations(in text: String) -> [String] {
        let words = text.wordCount
        guard words >= 200 else { return [] }
        var violations: [String] = []

        // 1) „Nicht …“ als Satzanfang: budgetiert auf ~1 je 350 Wörter.
        var nichtStarts = 0
        for raw in text.components(separatedBy: CharacterSet(charactersIn: ".!?…\n")) {
            let s = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t„“”»«‚'\""))
            if s.hasPrefix("Nicht ") || s.hasPrefix("Kein ") || s.hasPrefix("Keine ") {
                nichtStarts += 1
            }
        }
        // Kalibriert an 184 echten Szenen (Trip-Rate ~20%): nur klar auffällige
        // Szenen lösen die eine zusätzliche Neufassung aus, nicht jede zweite.
        let nichtBudget = max(4, words / 150)
        if nichtStarts > nichtBudget {
            violations.append("„Nicht/Kein …“-Satzanfänge: \(nichtStarts)× (erlaubt \(nichtBudget)). Formuliere positiv, was IST – die Verneinungs-Rhetorik „Nicht X. Sondern Y.“ höchstens einmal.")
        }

        // 2) Körper-Beat-Lexeme: zusammen budgetiert auf ~1 je 300 Wörter.
        let lower = text.lowercased()
        let beatLexemes = ["schluckte", "atemzug", "hämmerte", "stockte", "zog sich zusammen",
                           "krampfte", "kribbelte", "zitterte", "bebte"]
        var beatCounts: [(String, Int)] = []
        var beatTotal = 0
        for lex in beatLexemes {
            let c = lower.components(separatedBy: lex).count - 1
            if c > 0 { beatCounts.append((lex, c)); beatTotal += c }
        }
        let beatBudget = max(3, words / 200)
        if beatTotal > beatBudget {
            let list = beatCounts.sorted { $0.1 > $1.1 }.prefix(4).map { "\($0.0) \($0.1)×" }.joined(separator: ", ")
            violations.append("Körpersignal-Beats gehäuft (\(beatTotal)×, erlaubt \(beatBudget)): \(list). Ersetze durch konkrete Handlung, Blickrichtung, Objekt oder Dialog – nicht durch ein anderes Körpersignal.")
        }

        // 3) Adverb-Krücken: zusammen budgetiert auf ~1 je 200 Wörter.
        let crutches = ["leise", "langsam", "plötzlich", "einfach", "irgendwie"]
        var crutchTotal = 0
        var crutchCounts: [(String, Int)] = []
        for c in crutches {
            let n = lower.components(separatedBy: c).count - 1
            if n > 0 { crutchCounts.append((c, n)); crutchTotal += n }
        }
        let crutchBudget = max(5, words / 120)
        if crutchTotal > crutchBudget {
            let list = crutchCounts.sorted { $0.1 > $1.1 }.prefix(3).map { "\($0.0) \($0.1)×" }.joined(separator: ", ")
            violations.append("Adverb-Krücken gehäuft (\(crutchTotal)×, erlaubt \(crutchBudget)): \(list). Zeige das Tempo/die Lautstärke über die Handlung selbst.")
        }
        return violations
    }

    /// Weiches Gate: Klingt die Szene maschinell ODER altertümlich (für ihre Länge)?
    /// Löst beim Schreiben höchstens EINE Neufassung aus; verwirft nie Inhalt.
    static func soundsLikeAI(_ text: String) -> Bool {
        let words = text.wordCount
        guard words >= 150 else { return false }
        // Schon zwei altertümliche Marker lassen den Text sofort antiquiert wirken.
        if archaicTellCount(text) >= 2 { return true }
        // Zwei akademische Fachwörter machen den Text für normale Leser unzugänglich.
        if jargonTellCount(text) >= 2 { return true }
        // Gehäufte Umschreibungen (Benennungs-Vermeidung, Korrekturfiguren) machen die
        // Geschichte unverständlich – dichteabhängig, damit lange Kapitel nicht über
        // legitime Einzelvorkommen stolpern.
        if circumlocutionCount(text) >= max(4, words / 220) { return true }
        let threshold = max(2, words / 300)
        return aiTellCount(text) >= threshold
    }

    // MARK: - Buchweite Wiederholungen (N-Gramm-Scan)

    /// Redebegleiter/Allerwelts-Phrasen, die naturgemäß oft vorkommen und KEINE
    /// Wiederholungs-Befunde sind.
    private static let ngramStopPhrases: Set<String> = [
        "sagte er und sah sie", "sagte sie und sah ihn",
        "sah sie an und sagte", "sah ihn an und sagte",
        "es war nicht das erste", "zum ersten mal seit langem"
    ]

    /// Findet Formulierungen (4-6-Wort-N-Gramme), die in mehreren VERSCHIEDENEN Kapiteln
    /// wiederkehren – die Lieblingsfloskeln des Modells, an denen Leser KI-Prosa erkennen.
    /// Rein deterministisch, kein Modell-Call. Liefert die auffälligsten zuerst.
    static func overusedPhrases(inChapters chapters: [String], minChapters: Int = 3,
                                maxResults: Int = 12) -> [String] {
        guard chapters.count >= minChapters else { return [] }
        // Pro Kapitel zählt jedes N-Gramm nur EINMAL – uns interessiert die
        // KAPITEL-übergreifende Wiederkehr, nicht die Dichte innerhalb eines Kapitels.
        var chapterCounts: [String: Int] = [:]
        var firstSpelling: [String: String] = [:]
        for chapter in chapters {
            let words = chapter
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            guard words.count >= 6 else { continue }
            var seenInChapter = Set<String>()
            for n in 4...6 {
                guard words.count >= n else { continue }
                for start in 0...(words.count - n) {
                    let gramWords = Array(words[start..<(start + n)])
                    let raw = gramWords.joined(separator: " ")
                    let key = String(raw.lowercased()
                        .filter { !",.;:!?…„“”»«\"'()".contains($0) })
                    // Nur „inhaltige" Gramme: mindestens ein Wort > 5 Zeichen,
                    // sonst matcht man nur Funktionswort-Ketten („und dann sah sie").
                    guard key.count >= 18,
                          gramWords.contains(where: { $0.count > 5 }),
                          !ngramStopPhrases.contains(key),
                          !seenInChapter.contains(key) else { continue }
                    seenInChapter.insert(key)
                    chapterCounts[key, default: 0] += 1
                    if firstSpelling[key] == nil { firstSpelling[key] = raw }
                }
            }
        }
        // Auffälligste zuerst; Teil-Gramme bereits gemeldeter Formulierungen unterdrücken.
        let hits = chapterCounts.filter { $0.value >= minChapters }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
        var results: [String] = []
        for (key, _) in hits {
            guard results.count < maxResults else { break }
            let spelled = firstSpelling[key] ?? key
            if !results.contains(where: { $0.lowercased().contains(key) || key.contains($0.lowercased()) }) {
                results.append(spelled)
            }
        }
        return results
    }

    /// Exakte längere Satzduplikate sind in erzählender Prosa und Sachtext ein starkes
    /// Zeichen für Copy-/Template-Artefakte. Kurze Alltagssätze werden bewusst ignoriert.
    static func repeatedSentences(inChapters chapters: [String],
                                  minimumOccurrences: Int = 3,
                                  maxResults: Int = 10) -> [String] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for chapter in chapters {
            // Auch an Zeilenumbrüchen trennen: Dialogzeilen enden oft ohne Satzzeichen
            // („…Text“\n\nNächster Satz.“), sonst zöge der Umbruch in den „Satz" hinein
            // und der Treffer ließe sich später absatzweise nicht wiederfinden.
            let rawSentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?…\n"))
            for raw in rawSentences {
                let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { continue }
                let key = sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard key.count >= 26 else { continue }
                counts[key, default: 0] += 1
                if spelling[key] == nil { spelling[key] = sentence }
            }
        }
        return counts.filter { $0.value >= minimumOccurrences }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .prefix(maxResults)
            .map { spelling[$0.key] ?? $0.key }
    }

    /// Wie `repeatedSentences`, aber mit Häufigkeit UND Wortzahl je Satz. Grundlage
    /// für die abgestufte, professionelle Freigabe: nicht jede Wiederholung wiegt
    /// gleich schwer.
    static func repeatedSentenceStats(inChapters chapters: [String],
                                      minimumOccurrences: Int = 3
    ) -> [(sentence: String, occurrences: Int, words: Int)] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for chapter in chapters {
            let rawSentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?…\n"))
            for raw in rawSentences {
                let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { continue }
                let key = sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard key.count >= 26 else { continue }
                counts[key, default: 0] += 1
                if spelling[key] == nil { spelling[key] = sentence }
            }
        }
        return counts.filter { $0.value >= minimumOccurrences }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .map { (spelling[$0.key] ?? $0.key, $0.value, (spelling[$0.key] ?? $0.key).wordCount) }
    }

    /// Wiederholungen, die eine Veröffentlichung wirklich blockieren (professioneller
    /// Maßstab): EGREGIÖSE Fälle. Ein Roman darf ein paar kurze, wiederkehrende Beats
    /// haben – aber KEINE distinktiven längeren Sätze wortgleich mehrfach und KEINEN
    /// Satz, der geradezu gehämmert wird. Diese Liste bestimmt sowohl die Freigabe als
    /// auch, was die Schlussreparatur gezielt entfernt (so konvergiert sie, statt kurze
    /// Beats endlos gegeneinander auszutauschen).
    ///
    /// Berücksichtigt zusätzlich, WO ein Satz wiederkehrt: Eine Wiederholung innerhalb
    /// EINES Kapitels ist meist ein bewusstes Stilmittel (Refrain, Echo), eine über das
    /// halbe Buch verteilte dagegen ein Textbaustein-Fehler. Ohne diese Unterscheidung
    /// wurden literarisch gewollte Wiederholungen fälschlich als Mangel gemeldet – und
    /// die Schlussreparatur tauschte sie sinnlos gegeneinander aus.
    static func blockingRepeatedSentences(inChapters chapters: [String]) -> [String] {
        func chapterIndices(containing sentence: String) -> [Int] {
            chapters.indices.filter { chapters[$0].localizedCaseInsensitiveContains(sentence) }
        }
        return repeatedSentenceStats(inChapters: chapters, minimumOccurrences: 2).compactMap { stat in
            let indices = chapterIndices(containing: stat.sentence)
            if indices.count <= 1 { return nil }                       // Stilmittel im selben Kapitel
            if indices.count == 2, let first = indices.first, let last = indices.last,
               last - first <= 1, stat.words <= 8 { return nil }       // kurzes Leitmotiv nebenan
            let isDistinctive = stat.words >= 7 && stat.occurrences >= 2
            let isHammered = stat.occurrences >= 5
            return (isDistinctive || isHammered) ? stat.sentence : nil
        }
    }

    /// Findet längere Sätze eines neuen Entwurfs, die im bisherigen Manuskript
    /// bereits wörtlich vorkommen. Anders als der buchweite Report meldet diese
    /// Prüfung nur Kollisionen, die der neue Text tatsächlich einführt.
    static func repeatedSentenceCollisions(candidate: String,
                                           priorTexts: [String],
                                           maxResults: Int = 12) -> [String] {
        let priorRecords = priorTexts.flatMap { significantSentenceRecords(in: $0) }
        let priorKeys = Set(priorRecords.map(\.key))
        // Wortfolgen der bisherigen Sätze – Grundlage für die Erkennung von
        // Fast-Wiederholungen (siehe `istFastGleich`).
        let priorTrigramme = priorRecords.map { wortTrigramme($0.spelling) }

        var seenInCandidate = Set<String>()
        var seenTrigramme: [Set<[String]>] = []
        var collisions: [String] = []

        for record in significantSentenceRecords(in: candidate) {
            let exaktSchonDa = priorKeys.contains(record.key)
            let exaktImKandidaten = !seenInCandidate.insert(record.key).inserted
            let eigene = wortTrigramme(record.spelling)
            // NEU: auch fast gleiche Sätze zählen, nicht nur wortgleiche.
            let fastSchonDa = !exaktSchonDa && priorTrigramme.contains { istFastGleich(eigene, $0) }
            let fastImKandidaten = !exaktImKandidaten && seenTrigramme.contains { istFastGleich(eigene, $0) }
            seenTrigramme.append(eigene)

            guard exaktSchonDa || exaktImKandidaten || fastSchonDa || fastImKandidaten else { continue }
            guard !collisions.contains(where: {
                normalizedSentenceKey($0) == record.key
            }) else { continue }
            collisions.append(record.spelling)
            if collisions.count >= maxResults { break }
        }
        return collisions
    }

    /// Anteil der Kandidaten-Sätze, die bereits erzählte Sätze (fast) wortgleich
    /// wiederholen – der deterministische „Dieselbe Szene noch einmal"-Detektor.
    ///
    /// WARUM: `repeatedSentenceCollisions` meldet nur die ersten 12 Einzelsätze und
    /// dient als Gate. Eine komplett neu erzählte Szene in leicht anderen Worten
    /// fällt damit nicht auf, obwohl sie inhaltlich eine Wiederholung ist. Der
    /// ANTEIL dagegen steigt bei einer echten Nacherzählung sprunghaft (30 % und
    /// mehr der Sätze sind Fast-Dubletten), während normale Folge-Szenen unter
    /// ~10 % bleiben (Rückverweise, wiederkehrende Formulierungen).
    static func retellingOverlap(candidate: String, priorTexts: [String]) -> Double {
        let candidateRecords = significantSentenceRecords(in: candidate)
        guard !candidateRecords.isEmpty else { return 0 }
        let priorRecords = priorTexts.flatMap { significantSentenceRecords(in: $0) }
        guard !priorRecords.isEmpty else { return 0 }
        let priorKeys = Set(priorRecords.map(\.key))
        let priorTrigramme = priorRecords.map { wortTrigramme($0.spelling) }
        var hits = 0
        for record in candidateRecords {
            let exact = priorKeys.contains(record.key)
            let eigene = wortTrigramme(record.spelling)
            if exact || priorTrigramme.contains(where: { istFastGleich(eigene, $0) }) {
                hits += 1
            }
        }
        return Double(hits) / Double(candidateRecords.count)
    }

    /// Ab diesem Anteil fast gleicher Sätze gilt eine Szene als Nacherzählung.
    static let retellingOverlapLimit = 0.30

    /// Anteil, ab dem zwei Sätze als dieselbe Formulierung gelten.
    ///
    /// Am fertigen Buch „Das letzte Streichholz" kalibriert: Bei 0,5 werden 63 Stellen in
    /// 31 Kapiteln getroffen, und jede einzelne davon ist eine echte Doppelung – etwa
    /// „Die ölige Pfütze im Eingangsbereich glänzte noch immer" gegen „Die ölige Pfütze
    /// im Flur glänzte noch immer". Niedriger angesetzt beginnt die Prüfung, normale
    /// Prosa zu beanstanden; höher lässt sie die Hälfte der Fälle durch.
    static let fastGleichSchwelle = 0.5

    /// Sind zwei Sätze dieselbe Formulierung mit ausgetauschten Wörtern?
    ///
    /// WARUM DAS GEBRAUCHT WIRD: Die Prüfung verglich vorher nur auf WORTGLEICHHEIT
    /// (normalisierter Satzschlüssel). Am fertigen Buch nachgemessen: 384 Satzpaare in
    /// benachbarten Szenen waren einander zu mindestens 62 % ähnlich – davon aber nur
    /// ACHT wortgleich. Die anderen 376 rutschten durch:
    ///
    ///     „Sie kniete sich hin, berührte die matte Oberfläche mit den Fingerspitzen."
    ///     „Sie bückte sich, berührte die Körner mit den Fingerspitzen."
    ///
    ///     „Die Treppe knarrte unter ihren Stiefeln wie morsche Knochen."
    ///     „Die Dielen knarrten unter ihren Stiefeln."
    ///     „Die Dielen stöhnten unter ihrem Gewicht."
    ///
    /// Genau solche Variationen derselben Satzschablone lassen einen Text maschinell
    /// wirken – jede Szene erzählt die vorige mit anderen Wörtern noch einmal. Der
    /// Erzeugungs-Prompt verbietet Wiederholungen ausdrücklich („ohne das Geschehene zu
    /// wiederholen"); das Modell hält sich nicht daran. Wirksam ist nur die Prüfung
    /// danach.
    ///
    /// Verglichen werden Wort-Dreiergruppen: Sie erfassen die Satzkonstruktion, nicht
    /// bloß den Wortschatz. Zwei Sätze über dasselbe Thema mit anderem Bau fallen nicht
    /// auf, dieselbe Konstruktion mit getauschten Wörtern schon.
    static func istFastGleich(_ a: Set<[String]>, _ b: Set<[String]>) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        let gemeinsam = a.intersection(b).count
        return Double(gemeinsam) / Double(min(a.count, b.count)) >= fastGleichSchwelle
    }

    /// Wort-Dreiergruppen eines Satzes, normalisiert (klein, ohne Diakritika/Satzzeichen).
    static func wortTrigramme(_ satz: String) -> Set<[String]> {
        let worte = satz
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard worte.count >= 3 else { return [] }
        var ergebnis = Set<[String]>()
        for i in 0...(worte.count - 3) {
            ergebnis.insert(Array(worte[i..<(i + 3)]))
        }
        return ergebnis
    }

    // MARK: - Spannungskurve (D2)

    /// Ein Punkt auf der Spannungskurve: Einsatz-Stufe (1–10) und ggf. eine
    /// dramaturgische Marke (HOOK, MIDPOINT-WENDE, DUNKLE NACHT, HÖHEPUNKT, AUFLÖSUNG).
    struct TensionAnchor {
        let kapitel: Int
        let stufe: Int
        let marke: String
    }

    /// SPANNUNGSKURVE: Der bisherige Planungs-Prompt sagte nur „Tempo variieren" –
    /// ob die EINSÄTZE über 40 Kapitel wirklich steigen, blieb dem Modell überlassen.
    /// Ergebnis: die klassische monotone Mitte, in der Kapitel 15 sich anfühlt wie
    /// Kapitel 8. Diese Kurve macht die Eskalation verbindlich und messbar:
    ///
    /// - Start bei 2/10 (Hook muss soghaft sein, aber Luft nach oben lassen)
    /// - leicht überlineare Steigung (pow 1.15) bis 10/10 – spätere Kapitel eskalieren
    ///   SCHNELLER, wie es Bestseller tun
    /// - MIDPOINT-WENDE (~50 %): Spielregeln ändern sich, Stufe springt auf ≥ 8
    /// - DUNKLE NACHT (~78 %): größter Verlust kurz vor dem Finale
    /// - HÖHEPUNKT (vorletztes Kapitel): 10/10, unvermeidliche Konfrontation
    /// - AUFLÖSUNG (letztes Kapitel): Auszahlung, bewusst ruhig (3/10)
    ///
    /// Wichtig: Die Kurve beschreibt EINSÄTZE, nicht Tempo – ruhige, tiefe Kapitel
    /// bleiben erlaubt, solange das, was auf dem Spiel steht, nie kleiner wird.
    static func spannungskurve(chapterCount n: Int) -> [TensionAnchor] {
        guard n > 0 else { return [] }
        let midpoint = max(2, n / 2)
        let darkNight = max(midpoint + 1, Int((Double(n) * 0.78).rounded()))
        let climax = max(1, n - 1)
        return (1...n).map { k in
            let progress = Double(k - 1) / Double(max(n - 1, 1))
            var stufe = 2 + Int((8.0 * pow(progress, 1.15)).rounded())
            var marke = ""
            if k == 1 { marke = "HOOK"; stufe = min(stufe, 3) }
            if n >= 6 && k == midpoint { marke = "MIDPOINT-WENDE"; stufe = max(stufe, 8) }
            if n >= 8 && k == darkNight && darkNight != climax { marke = "DUNKLE NACHT"; stufe = max(stufe, 8) }
            if n >= 2 && k == climax { marke = "HÖHEPUNKT"; stufe = 10 }
            if n >= 2 && k == n { marke = "AUFLÖSUNG"; stufe = 3 }
            return TensionAnchor(kapitel: k, stufe: stufe, marke: marke)
        }.reducingMonotonicity(untilChapter: climax)
    }

    /// Kompakte Textform der Kurve für Prompts („K1:2·HOOK, K2:2, …").
    static func spannungskurvenBrief(chapterCount: Int) -> String {
        spannungskurve(chapterCount: chapterCount).map { anchor in
            anchor.marke.isEmpty
                ? "K\(anchor.kapitel):\(anchor.stufe)"
                : "K\(anchor.kapitel):\(anchor.stufe)·\(anchor.marke)"
        }.joined(separator: ", ")
    }

    /// Stufe und Marke für ein konkretes Kapitel (0-basierter Index, wie er im
    /// Schreibloop verwendet wird).
    static func spannungsStufe(chapterIndex: Int, chapterCount: Int) -> TensionAnchor {
        let kurve = spannungskurve(chapterCount: chapterCount)
        guard chapterIndex >= 0, chapterIndex < kurve.count else {
            return TensionAnchor(kapitel: chapterIndex + 1, stufe: 5, marke: "")
        }
        return kurve[chapterIndex]
    }

    /// Konkrete Schreibanweisung zur Marke – was DIESES Kapitel dramaturgisch leisten muss.
    static func dramaturgieHinweis(marke: String) -> String {
        switch marke {
        case "HOOK":
            return "Erste Seite mitten im Konflikt, kein Welt-Erklären: ein konkretes Problem, eine Figur unter Druck, eine Frage, die der Leser beantwortet haben will."
        case "MIDPOINT-WENDE":
            return "Hier ändern sich die SPIELREGELN: eine enthüllte Wahrheit, ein Verrat, eine neue Allianz oder ein Verlust, der den bisherigen Plan der Hauptfigur zerstört – danach ist nichts mehr wie vorher."
        case "DUNKLE NACHT":
            return "Der größte Verlust des Buches: scheinbare Niederlage, gebrochene Beziehung oder verlorene Hoffnung. Die Hauptfigur steht am Tiefpunkt – und genau daraus wächst die Entscheidung fürs Finale."
        case "HÖHEPUNKT":
            return "Die unvermeidliche Konfrontation: ALLES steht auf dem Spiel, keine Zurückhaltung, keine neuen Erklärungen – nur Entscheidung und Konsequenz."
        case "AUFLÖSUNG":
            return "Echte Auszahlung statt neuer Eskalation: lose Fäden schließen, emotionale Wahrheit der Veränderung zeigen, ein Bild finden, das den Anfang spiegelt."
        default:
            return "Die Einsätze müssen über dem Niveau der früheren Kapitel liegen – Tempo-Atempause ja, kleiner werdende Einsätze nie."
        }
    }

    /// Filtert den Fakten-Ledger auf die Zeilen, die für DIESE Szene relevant sind.
    ///
    /// WARUM: Der Ledger wurde bisher vollständig in JEDEN Szenen-Prompt injiziert.
    /// Bei einem 40-Kapitel-Buch sind das schnell 100+ Zeilen Fakten zu Figuren und
    /// Orten, die in der aktuellen Szene gar nicht vorkommen – der Prompt wird
    /// länger, die Aufmerksamkeit des Modells für die wirklich wichtigen Fakten
    /// sinkt (und die Tokenkosten steigen). Relevanz heißt hier: Die Faktenzeile
    /// teilt mindestens ein bedeutendes Wort (≥4 Buchstaben) mit dem Szenenkontext
    /// (Kapitelziel, Szenenziel, Hindernis, Ort, auftretende Figuren, jüngste Handlung).
    /// Sicherheitsnetz: Bleiben zu wenige Zeilen übrig, wird der volle Ledger
    /// (gedeckelt) verwendet – lieber ein Fakt zu viel als einer zu wenig.
    static func relevantFacts(ledger: String, context: String, maxLines: Int = 40) -> String {
        let lines = ledger.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 8 else { return lines.joined(separator: "\n") }

        let contextWords = Set(
            context.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
        )
        guard !contextWords.isEmpty else {
            return lines.prefix(maxLines).joined(separator: "\n")
        }

        let relevant = lines.filter { line in
            line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .contains { $0.count >= 4 && contextWords.contains($0) }
        }
        // Zu aggressiv gefiltert? Dann lieber den (gedeckelten) vollen Ledger.
        guard relevant.count >= 3 else {
            return lines.prefix(maxLines).joined(separator: "\n")
        }
        return relevant.prefix(maxLines).joined(separator: "\n")
    }

    /// Parst die Antwort des Figurenstand-Prompts (`PromptFactory.characterStateUpdate`)
    /// in `Name → Stand`. Nur Zeilen, deren Name einer bekannten Figur entspricht,
    /// werden übernommen – so können weder Halluzinations-Figuren noch Freitext
    /// das Register vergiften. Der Vergleich ist diakritik- und groß/klein-tolerant,
    /// weil das Modell Namen gelegentlich leicht anders schreibt.
    static func parseCharacterStateLines(_ antwort: String, knownNames: [String]) -> [String: String] {
        func norm(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t-•*"))
        }
        var ergebnis: [String: String] = [:]
        for rawLine in antwort.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let namePart = norm(String(line[..<colon]))
            let stand = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            guard !stand.isEmpty else { continue }
            guard let kanonName = knownNames.first(where: {
                let kanon = norm($0)
                // Voller Name oder eindeutiger Vorname (verhindert „Jonas" vs. „Jonas Hartmann"-Duplikate).
                return kanon == namePart || kanon.split(separator: " ").first.map(String.init) == namePart
            }) else { continue }
            // Zeilen hart deckeln: Der Stand wird in jeden folgenden Szenen-Prompt
            // injiziert – ein ausufernder Eintrag fräße das Kontextbudget.
            ergebnis[kanonName] = stand.truncated(to: 220)
        }
        return ergebnis
    }

    /// Ergebnis der Golden-Eval (siehe PromptFactory.goldenEval): numerische Noten
    /// je Dimension, Gesamtnote, Freigabe-Urteil und konkrete Schwächen.
    struct GoldenEval {
        var noten: [(name: String, wert: Int)] = []
        var gesamt: Int?
        var gesamtBegruendung = ""
        var freigabe: Bool?
        var schwaechen: [String] = []
    }

    /// Parst die Golden-Eval-Antwort. Tolerant gegenüber Formatwacklern (fehlende
    /// Begründung, „Note: 7" statt „7", URTEIL in Kleinbuchstaben), aber strikt bei
    /// den Notenwerten: Nur ganze Zahlen 1–10 zählen, alles andere wird ignoriert,
    /// damit ein ausuferndes Modell keine Phantom-Noten erzeugt.
    static func parseGoldenEval(_ antwort: String) -> GoldenEval {
        var eval = GoldenEval()
        for rawLine in antwort.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let schluessel = String(line[..<colon])
                .trimmingCharacters(in: .whitespaces).uppercased()
            let rest = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)

            if schluessel.hasPrefix("URTEIL") {
                eval.freigabe = rest.uppercased().hasPrefix("FREIGABE")
                continue
            }
            if schluessel.hasPrefix("SCHWÄCHE") || schluessel.hasPrefix("SCHWACHE") {
                if !rest.isEmpty, eval.schwaechen.count < 3 {
                    eval.schwaechen.append(rest.truncated(to: 300))
                }
                continue
            }
            // Notenzeile: Zahl am Anfang (optional „Note:" davor), Begründung nach „—".
            var zahlText = rest
            if let noteRange = zahlText.range(of: "—") {
                zahlText = String(zahlText[..<noteRange.lowerBound])
            } else if let noteRange = zahlText.range(of: " - ") {
                zahlText = String(zahlText[..<noteRange.lowerBound])
            }
            zahlText = zahlText.replacingOccurrences(of: "Note", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard let wert = Int(zahlText.split(separator: " ").first.map(String.init) ?? zahlText),
                  (1...10).contains(wert) else { continue }
            let begruendung: String
            if let dash = rest.range(of: "—") ?? rest.range(of: " - ") {
                begruendung = String(rest[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                begruendung = ""
            }
            if schluessel.hasPrefix("GESAMT") {
                eval.gesamt = wert
                eval.gesamtBegruendung = begruendung
            } else {
                eval.noten.append((name: schluessel, wert: wert))
            }
        }
        return eval
    }

    /// Ein vom Stiltick-Judge gefundenes Muster (siehe PromptFactory.styleTicJudge).
    struct StyleTicVerdict {
        let muster: String
        let beleg: String
        let anweisung: String
    }

    /// Parst TICK-Zeilen des Stiltick-Judges. Strikt beim Format (vier Felder mit
    /// „|" getrennt), damit Kommentarzeilen des Modells nicht als Befund durchrutschen;
    /// tolerant bei Leerzeichen und Aufzählungszeichen am Zeilenanfang.
    static func parseStyleTicVerdicts(_ antwort: String, maxVerdicts: Int = 5) -> [StyleTicVerdict] {
        parseVerdictLines(antwort, tag: "TICK", maxVerdicts: maxVerdicts)
    }

    /// Parst STIMME-Zeilen des Figurenstimmen-Audits (gleiches Zeilenformat wie TICK,
    /// andere Prüffrage – siehe PromptFactory.dialogueVoiceAudit).
    static func parseDialogueVoiceVerdicts(_ antwort: String, maxVerdicts: Int = 4) -> [StyleTicVerdict] {
        parseVerdictLines(antwort, tag: "STIMME", maxVerdicts: maxVerdicts)
    }

    /// Hat das Kapitel genug wörtliche Rede, dass sich ein Stimmen-Audit lohnt?
    /// Unter ~6 Rede-Einsätzen gibt es keine belastbare Vergleichsbasis – der
    /// Audit-Call wäre Kosten ohne Aussage.
    static func hatNennenswertenDialog(_ text: String) -> Bool {
        let anfuehrungen = text.components(separatedBy: "„").count - 1
        let guillemets = text.components(separatedBy: "»").count - 1
        return anfuehrungen + guillemets >= 6
    }

    /// Urteil eines simulierten Beta-Lesers (siehe PromptFactory.betaReaderPass).
    struct BetaReaderVerdict {
        let persona: String
        let sterne: Int
        let problem: String
        let anweisung: String
    }

    /// Parst PERSONA-Zeilen des Beta-Leser-Passes. Nur Zeilen mit gültiger
    /// Sternezahl (1–5) zählen; „keins"/„-"-Platzhalter werden als sauber gewertet.
    /// Zurückgegeben werden ALLE geparsten Urteile (auch 4–5 Sterne) – die
    /// Filterung auf handlungsbedürftige Befunde ist Aufgabe des Aufrufers.
    static func parseBetaReaderVerdicts(_ antwort: String) -> [BetaReaderVerdict] {
        antwort.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix("PERSONA|") else { return nil }
            let felder = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard felder.count >= 5 else { return nil }
            let persona = felder[1]
            guard !persona.isEmpty,
                  let sterne = Int(felder[2]), (1...5).contains(sterne) else { return nil }
            return BetaReaderVerdict(persona: persona.truncated(to: 40),
                                     sterne: sterne,
                                     problem: felder[3].truncated(to: 240),
                                     anweisung: felder[4].truncated(to: 240))
        }
    }

    /// Gemeinsamer Zeilenparser für Judge-Antworten im Format
    /// `TAG|Feld1|Feld2|Feld3`. Strikt beim Tag und der Feldzahl, damit
    /// Kommentarzeilen des Modells nicht als Befund durchrutschen; tolerant bei
    /// Leerzeichen und Aufzählungszeichen am Zeilenanfang.
    private static func parseVerdictLines(_ antwort: String, tag: String,
                                          maxVerdicts: Int) -> [StyleTicVerdict] {
        antwort.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix(tag + "|") else { return nil }
            let felder = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard felder.count >= 4 else { return nil }
            let muster = felder[1], anweisung = felder[3]
            guard !muster.isEmpty, !anweisung.isEmpty else { return nil }
            return StyleTicVerdict(muster: muster.truncated(to: 120),
                                   beleg: felder[2].truncated(to: 160),
                                   anweisung: anweisung.truncated(to: 220))
        }.prefix(maxVerdicts).map { $0 }
    }

    /// Findet Szenenpläne, deren Beats einander inhaltlich wiederholen.
    ///
    /// WARUM: Die Wurzel der doppelt erzählten Szenen liegt im PLAN, nicht in der
    /// Prosa – bekamen zwei Szenen desselben Plan-Beat („ein neuer Vorstoß"), MUSSTE
    /// der Draft Writer dasselbe Ereignis zweimal erzählen, und keine spätere
    /// Reparatur konnte das beheben (gemessen: acht erfolgreiche Neufassungen, acht
    /// Doppler). Bisher prüfte `istGenerischerSzenenplan` nur abstrakte Standard-
    /// Formulierungen; ein Plan kann aber auch mit konkret klingenden, einander
    /// gleichenden Beats durchkommen. Verglichen wird die kombinierte Beat-Signatur
    /// (Ziel + Hindernis + Wendung) paarweise via Wort-Trigrammen – derselbe
    /// Mechanismus, der sich bei der Satz-Doppler-Erkennung bewährt hat.
    ///
    /// Rückgabe: lesbare Beschreibungen der Doppler-Paare (für Ablehnungsgrund und
    /// Neuplanungshinweis), leer bei einem diversen Plan.
    static func duplicatedSceneBeats(_ planned: [PlannedScene]) -> [String] {
        guard planned.count > 1 else { return [] }
        let signaturen = planned.map { szene in
            wortTrigramme("\(szene.goal) \(szene.obstacle) \(szene.turn)")
        }
        var doppler: [String] = []
        for i in 0..<planned.count {
            for j in (i + 1)..<planned.count {
                guard istFastGleich(signaturen[i], signaturen[j]) else { continue }
                let beschreibung = "Szene \(planned[i].number) und Szene \(planned[j].number) erzählen denselben Beat"
                if !doppler.contains(beschreibung) { doppler.append(beschreibung) }
            }
        }
        return doppler
    }

    private static func significantSentenceRecords(in text: String) -> [(key: String, spelling: String)] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?…\n")).compactMap { raw in
            let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { return nil }
            let key = normalizedSentenceKey(sentence)
            guard key.count >= 26 else { return nil }
            return (key, sentence)
        }
    }

    private static func normalizedSentenceKey(_ sentence: String) -> String {
        sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#,
                                  with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func nonfictionPracticalCoverage(_ chapters: [String]) -> Double {
        guard !chapters.isEmpty else { return 0 }
        let markers = ["beispiel", "übung", "checkliste", "nächster schritt",
                       "so gehst du", "in der praxis", "reflexion", "aufgabe"]
        let useful = chapters.filter { chapter in
            let normalized = chapter.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return markers.contains(where: normalized.contains)
        }.count
        return Double(useful) / Double(chapters.count)
    }

    static func satisfiesNonfictionSectionContract(_ text: String,
                                                   sectionKind: String,
                                                   takeaway: String) -> Bool {
        let expected = "\(sectionKind) \(takeaway)"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let candidate = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if expected.contains("checkliste") { return candidate.contains("checkliste") }
        if expected.contains("ubung") || expected.contains("aufgabe") {
            return candidate.contains("ubung") || candidate.contains("aufgabe")
        }
        if expected.contains("beispiel") { return candidate.contains("beispiel") }
        return true
    }

    // MARK: - Romance-Eskalation (Beziehungstemperatur)

    /// Romance-artige Genres, deren Kernversprechen eine ESKALIERENDE Beziehung ist.
    static func isRomanceGenre(_ genre: String) -> Bool {
        let g = genre.lowercased()
        return ["romance", "liebe", "romantasy", "erotik", "new adult"].contains { g.contains($0) }
    }

    /// Zielwert der Beziehungstemperatur (2–10) für ein Kapitel: steigt linear über das
    /// Buch. Gibt dem „Slow Burn" eine messbare Leiter – gegen das bekannte
    /// „Dark Romance liest sich als kühler Thriller"-Problem (No Burn).
    static func romanceHeatTarget(chapterIndex: Int, chapterCount: Int) -> Int {
        guard chapterCount > 1 else { return 6 }
        let fraction = Double(chapterIndex) / Double(chapterCount - 1)
        return min(10, max(2, 2 + Int((fraction * 8.0).rounded())))
    }

    // MARK: - Rewrite-Abnahme (Revision/Korrektorat)

    static func hasCompleteSentenceEnding(_ text: String) -> Bool {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let closingCharacters = CharacterSet(charactersIn: "\"'“”„«»’)]}")
        trimmed = trimmed.trimmingCharacters(in: closingCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return false }
        return ".!?…".contains(last)
    }

    static func finishReasonIndicatesTruncation(_ finishReason: String?) -> Bool {
        guard let reason = finishReason?.lowercased() else { return false }
        return ["length", "max_token", "token_limit", "max_output", "incomplete"]
            .contains { reason.contains($0) }
    }

    static func isLikelyTruncated(_ text: String, finishReason: String? = nil) -> Bool {
        finishReasonIndicatesTruncation(finishReason) || !hasCompleteSentenceEnding(text)
    }

    /// Schneidet nur das technisch unvollständige Satzfragment am Ende ab. Bereits
    /// abgeschlossene Sätze bleiben bytegenau erhalten und bilden den Fortsetzungspunkt.
    static func safePrefixBeforeTruncation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !hasCompleteSentenceEnding(trimmed) else { return trimmed }
        guard let boundary = trimmed.lastIndex(where: { ".!?…".contains($0) }) else { return "" }
        return String(trimmed[...boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Verbindet eine Modell-Fortsetzung ohne den häufig wiederholten letzten Absatz/Satz.
    static func mergingContinuation(base: String, continuation: String) -> String {
        let left = base.trimmingCharacters(in: .whitespacesAndNewlines)
        var right = continuation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }

        let lastParagraph = left.components(separatedBy: "\n\n").last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sentenceParts = left.components(separatedBy: CharacterSet(charactersIn: ".!?…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lastSentenceStem = sentenceParts.last ?? ""
        let candidates = [lastParagraph, lastSentenceStem]
            .filter { $0.count >= 24 }
            .sorted { $0.count > $1.count }
        for repeated in candidates where right.hasPrefix(repeated) {
            right.removeFirst(repeated.count)
            right = String(right.drop(while: \.isWhitespace))
            let leftoverClosers = CharacterSet(charactersIn: ".!?…)]}”’»")
            while let first = right.unicodeScalars.first, leftoverClosers.contains(first) {
                right.removeFirst()
            }
            right = String(right.drop(while: \.isWhitespace))
            break
        }
        return right.isEmpty ? left : left + "\n\n" + right
    }

    /// Prüft, ob eine Überarbeitung als Ersatz für die Quelle akzeptiert werden darf.
    /// Vorher genügten 50% der Wortzahl – ein bei maxTokens ABGESCHNITTENES Kapitel
    /// (endet mitten im Satz, Szenentrenner fehlen) wurde stillschweigend übernommen
    /// und landete halbiert beim Leser.
    static func isAcceptableRewrite(source: String, candidate: String,
                                    minRatio: Double = 0.8,
                                    maxRatio: Double? = nil,
                                    finishReason: String? = nil) -> Bool {
        let sourceWords = source.wordCount
        let candidateWords = candidate.wordCount
        guard sourceWords > 0 else { return !candidate.isEmpty }
        guard Double(candidateWords) >= Double(sourceWords) * minRatio else { return false }
        // Obergrenze: Eine Politur/Reparatur darf ein Kapitel NICHT aufblähen. Ohne
        // dieses Limit vervielfachten die ganz-Kapitel-Umschreibungen die Länge (z.B.
        // 873 → 2.344 Wörter) und machten die sonst zielgenaue Rohfassung kaputt.
        if let maxRatio, Double(candidateWords) > Double(sourceWords) * maxRatio { return false }
        guard !isLikelyTruncated(candidate, finishReason: finishReason) else { return false }
        // Szenentrenner müssen erhalten bleiben (beide Prompts fordern es; verlorene
        // Trenner zerstören die Szenenwechsel im Export).
        let sourceSeparators = source.components(separatedBy: "***").count - 1
        let candidateSeparators = candidate.components(separatedBy: "***").count - 1
        if sourceSeparators > 0, candidateSeparators < sourceSeparators { return false }
        return true
    }
}

private extension Array where Element == AutonomousContentQuality.TensionAnchor {
    /// Erzwingt nicht-fallende Einsatz-Stufen bis zum Höhepunkt. Die Basis-Kurve
    /// steigt von selbst, aber erzwungene Anker-Sprünge (z. B. MIDPOINT auf ≥ 8)
    /// ließen das Folgekapitel wieder auf den Basiswert abfallen – genau das
    /// „Einsatz-Loch", das die Kurve verhindern soll. Nach dem Höhepunkt bleibt
    /// die AUFLÖSUNG bewusst unberührt (sie darf fallen).
    func reducingMonotonicity(untilChapter climax: Int) -> [Element] {
        var ergebnis: [Element] = []
        ergebnis.reserveCapacity(count)
        for anchor in self {
            if let vorher = ergebnis.last, anchor.kapitel <= climax,
               anchor.stufe < vorher.stufe {
                ergebnis.append(AutonomousContentQuality.TensionAnchor(
                    kapitel: anchor.kapitel, stufe: vorher.stufe, marke: anchor.marke))
            } else {
                ergebnis.append(anchor)
            }
        }
        return ergebnis
    }
}
