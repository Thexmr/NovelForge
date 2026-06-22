import Foundation

enum AutonomousContentQuality {
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
        return scenes.allSatisfy { scene in
            scene.goal.wordCount >= 5
                && scene.obstacle.wordCount >= 3
                && scene.turn.wordCount >= 3
                && !isGenericPlaceholder(scene.goal)
        }
    }

    static func acceptsDraftScene(_ text: String, targetWords: Int) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        guard !containsMetaRequest(cleaned) else { return false }
        let minimum = max(80, Int(Double(targetWords) * 0.55))
        return cleaned.wordCount >= minimum
    }

    static func isGenericPlaceholder(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.isEmpty { return true }
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
        return patterns.contains { normalized == $0 || normalized.hasPrefix($0) }
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
        "- hindernis:", "- wendung"
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
        return t
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
        "etwas in ihr", "etwas in ihm", "etwas in ihrem inneren", "etwas regte sich in ihr",
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

    /// Altertümliche/„mittelalterliche“, geschwollene Wörter, die moderne Profi-Prosa
    /// NICHT verwendet. Schon wenige Treffer lassen einen Text antiquiert klingen.
    static let archaicTellPhrases: [String] = [
        "alsbald", "fürwahr", "sintemal", "weiland", "dünkte", "dünkt ", "wohlan",
        "antlitz", "jüngling", "die maid", "junge maid", "das weib", "ein weib",
        "holde ", "holder ", "es begab sich", "begab sich", "allerorten", "allzumal",
        "ingleichen", "sodann", "auf dass", "des nachts", "ein jeglich", "geziemt",
        "gewahrte", "hub an", "sann nach", "zur stund"
    ]

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

    /// Weiches Gate: Klingt die Szene maschinell ODER altertümlich (für ihre Länge)?
    /// Löst beim Schreiben höchstens EINE Neufassung aus; verwirft nie Inhalt.
    static func soundsLikeAI(_ text: String) -> Bool {
        let words = text.wordCount
        guard words >= 150 else { return false }
        // Schon zwei altertümliche Marker lassen den Text sofort antiquiert wirken.
        if archaicTellCount(text) >= 2 { return true }
        let threshold = max(2, words / 300)
        return aiTellCount(text) >= threshold
    }
}
