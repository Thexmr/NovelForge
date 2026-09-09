import Foundation

/// Schneller, vollständig lokaler Vorlektor für Buchprosa.
///
/// Der Dienst schreibt keine Geschichte. Er übernimmt die deterministischen Arbeiten,
/// für die ein Cloud-Modell langsam und unnötig teuer wäre: sichere Normalisierung,
/// eindeutige Rechtschreibkorrekturen, Wiederholungsabgleich und die Auswahl der wenigen
/// Absätze, die wirklich sprachliches Verständnis benötigen. Dadurch bleibt unveränderte
/// Prosa unangetastet und mehrere Reparaturstellen können in einem Modellaufruf gebündelt
/// werden.
enum LocalEditorialAssistant {

    struct OpeningRevisionState {
        private(set) var text: String
        private(set) var issues: [String]

        init(text: String, issues: [String]) {
            self.text = text
            self.issues = issues
        }

        @discardableResult
        mutating func consider(text candidate: String, issues candidateIssues: [String],
                               canAdvance: Bool) -> Bool {
            guard canAdvance, !candidate.isEmpty,
                  candidateIssues.count <= issues.count else { return false }
            // Feedback always describes the exact text sent to the next repair.
            text = candidate
            issues = candidateIssues
            return true
        }
    }

    static let openingReviewType = "Romananfang-Endabnahme"

    struct ParagraphTarget {
        let number: Int
        let paragraphIndex: Int
        let text: String
        let reasons: [String]

        var issueCount: Int { reasons.count }
    }

    struct Dossier {
        let text: String
        let paragraphTargets: [ParagraphTarget]
        let sentenceFindings: [(satz: String, grund: String)]
        let repeatedSentences: [String]
        let openingIssues: [String]
        let dialogueIssues: [String]
        let localCorrectionCount: Int

        var needsCloudRepair: Bool {
            !paragraphTargets.isEmpty || !repeatedSentences.isEmpty
                || !openingIssues.isEmpty || !dialogueIssues.isEmpty
        }
    }

    static func inspect(
        _ source: String,
        priorTexts: [String] = [],
        protagonistNames: [String] = [],
        isOpening: Bool = false,
        maximumParagraphs: Int = 12
    ) -> Dossier {
        var text = source
        var localCorrections = 0

        func apply(_ transform: (String) -> String) {
            let candidate = transform(text)
            if candidate != text { localCorrections += 1 }
            text = candidate
        }

        apply(AutonomousContentQuality.strippingSceneHeading)
        apply(AutonomousContentQuality.strippingPromptArtifacts)
        apply(AutonomousContentQuality.strippingInlineFormatting)
        apply(AutonomousContentQuality.humanizeProse)
        apply(SpellCheckService.korrigiereEindeutigeFehler)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let repeated = AutonomousContentQuality.repeatedSentenceCollisions(
            candidate: text,
            priorTexts: priorTexts
        )
        let opening = isOpening
            ? AutonomousContentQuality.finalOpeningIssues(
                in: text,
                protagonistNames: protagonistNames
            )
            : []
        let dialogue = AutonomousContentQuality.brokenDialogueTypography(in: text)
            + AutonomousContentQuality.dialogOhneAnfuehrungszeichen(in: text)
        let sentenceFindings = AutonomousContentQuality.reparierbareStilSaetze(
            in: text,
            hoechstens: 16
        )

        let paragraphs = text.components(separatedBy: "\n\n")
        var targets: [(index: Int, reasons: [String])] = []

        for index in paragraphs.indices {
            let paragraph = paragraphs[index]
            guard paragraph.wordCount >= 8 else { continue }
            var reasons = Set<String>()

            let phrases = AutonomousContentQuality.aiTellMatches(in: paragraph)
                + AutonomousContentQuality.circumlocutionMatches(in: paragraph)
                + AutonomousContentQuality.clarityRepairPhrases(in: paragraph)
            if !phrases.isEmpty {
                reasons.insert("formelhafte oder unnötig umständliche Wendung: "
                    + Array(Set(phrases)).sorted().prefix(3).joined(separator: ", "))
            }
            let smoothing = AutonomousContentQuality.antiGlaetteFindings(in: paragraph)
            for finding in smoothing.prefix(3) {
                reasons.insert("\(finding.grund): \(finding.satz.truncated(to: 150))")
            }
            if AutonomousContentQuality.jargonTellCount(paragraph) > 0 {
                reasons.insert("unnötig akademisches oder schweres Vokabular")
            }
            if AutonomousContentQuality.archaicTellCount(paragraph) > 0 {
                reasons.insert("veraltete oder gestelzte Sprache")
            }
            for finding in sentenceFindings where paragraph.contains(finding.satz) {
                reasons.insert(finding.grund)
            }
            for collision in repeated where paragraph.range(
                of: collision,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil {
                reasons.insert("wortgleicher Satz aus einem früheren Text")
            }
            if isOpening, index <= 2, !opening.isEmpty {
                reasons.insert("Romananfang: " + opening.prefix(2).joined(separator: " "))
            }
            if dialogue.contains(where: { paragraph.contains($0) }) {
                reasons.insert("beschädigte oder unmarkierte Dialogtypografie")
            }

            if !reasons.isEmpty {
                targets.append((index, reasons.sorted()))
            }
        }

        let selected = targets
            .sorted {
                if $0.reasons.count != $1.reasons.count {
                    return $0.reasons.count > $1.reasons.count
                }
                return $0.index < $1.index
            }
            .prefix(max(0, maximumParagraphs))
            .enumerated()
            .map { offset, item in
                ParagraphTarget(
                    number: offset + 1,
                    paragraphIndex: item.index,
                    text: paragraphs[item.index],
                    reasons: item.reasons
                )
            }

        return Dossier(
            text: text,
            paragraphTargets: selected,
            sentenceFindings: sentenceFindings,
            repeatedSentences: repeated,
            openingIssues: opening,
            dialogueIssues: dialogue,
            localCorrectionCount: localCorrections
        )
    }

    static func batchRepairPrompt(
        targets: [ParagraphTarget],
        chapterNumber: Int,
        chapterTitle: String
    ) -> String {
        let blocks = targets.map { target in
            let reasons = target.reasons.map { "- \($0)" }.joined(separator: "\n")
            return """
            ABSATZ \(target.number) – BEFUNDE:
            \(reasons)
            BEGINN_\(target.number)
            \(target.text)
            ENDE_\(target.number)
            """
        }.joined(separator: "\n\n")

        return """
        Überarbeite nur die markierten Absätze aus Kapitel \(chapterNumber)
        („\(chapterTitle)“). Entferne ausschließlich die jeweils genannten Befunde.
        Bewahre Ereignisse, Fakten, Namen, Verneinungen, Dialogbedeutung, Perspektive,
        Zeitform und Reihenfolge. Schreibe modern, konkret und so klar, dass ein
        durchschnittlicher 15-jähriger Leser ohne Nachschlagen folgen kann. Erfinde
        keine Figur, kein Objekt, keine Erinnerung und keine neue Handlung.

        Antworte für jeden bearbeiteten Absatz exakt in diesem Format:
        BEGINN_N
        vollständiger Ersatzabsatz
        ENDE_N

        Keine Vorrede, keine Markdown-Zeichen, keine ausgelassenen Absatzteile.

        \(blocks)
        """
    }

    /// Eine wortgleiche Formulierung ist reparierbar und darf eine inhaltlich bessere
    /// Zwischenfassung nicht zurück auf den alten Ausgangstext setzen. Kanon-,
    /// Vollständigkeits- oder Sicherheitsfehler bleiben dagegen absolute Sperren.
    static func allowsIntermediateOpeningProgress(
        structuralIssues: [String],
        sentenceCollisions: [String]
    ) -> Bool {
        structuralIssues.isEmpty && !sentenceCollisions.isEmpty
    }

    static func openingRequiresCanonicalRebuild(
        _ text: String,
        protagonistNames: [String]
    ) -> Bool {
        guard !protagonistNames.isEmpty else { return false }
        let sample = text.split(whereSeparator: { $0.isWhitespace })
            .prefix(350).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return !protagonistNames.contains { fullName in
            let normalized = fullName.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased()
            let firstName = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return sample.range(
                of: "(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: firstName)
                    + "(?![\\p{L}])",
                options: .regularExpression
            ) != nil
        }
    }

    static func shouldKeepBestOpeningCandidate(
        sourceIssueCount: Int,
        candidateIssueCount: Int,
        structurallySafe: Bool,
        blindComparisonWon: Bool,
        sourceCanonicallyInvalid: Bool = false,
        candidateCanonicallyValid: Bool = true
    ) -> Bool {
        guard structurallySafe, candidateCanonicallyValid else { return false }
        if sourceCanonicallyInvalid {
            // Ein Alttext mit falscher Perspektivfigur ist kein gueltiger stilistischer
            // Referenztext. Der sichere, korrigierte Neuaufbau darf bei gleicher oder
            // geringerer Restfehlerzahl nicht wieder gegen ihn ausgetauscht werden.
            return candidateIssueCount <= sourceIssueCount
        }
        return blindComparisonWon && candidateIssueCount < sourceIssueCount
    }

    /// Freie Erklärungen oder unvollständige Marker werden bewusst ignoriert. Eine
    /// misslungene Bündelantwort darf niemals einen korrekten Originalabsatz löschen.
    static func parseBatchReplacements(
        _ response: String,
        targets: [ParagraphTarget]
    ) -> [Int: String] {
        let targetByNumber = Dictionary(uniqueKeysWithValues: targets.map { ($0.number, $0) })
        let pattern = #"BEGINN_(\d+)\s*\n([\s\S]*?)\n\s*ENDE_\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let ns = response as NSString
        var replacements: [Int: String] = [:]

        for match in regex.matches(
            in: response,
            range: NSRange(location: 0, length: ns.length)
        ) {
            guard match.numberOfRanges == 3,
                  let numberRange = Range(match.range(at: 1), in: response),
                  let textRange = Range(match.range(at: 2), in: response),
                  let number = Int(response[numberRange]),
                  let target = targetByNumber[number],
                  replacements[target.paragraphIndex] == nil else { continue }

            let candidate = AutonomousContentQuality.humanizeProse(
                AutonomousContentQuality.strippingInlineFormatting(
                    AutonomousContentQuality.strippingPromptArtifacts(
                        String(response[textRange])
                    )
                )
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.wordCount >= 3,
                  !candidate.contains("BEGINN_"),
                  !candidate.contains("ENDE_") else { continue }
            replacements[target.paragraphIndex] = candidate
        }
        return replacements
    }
}
