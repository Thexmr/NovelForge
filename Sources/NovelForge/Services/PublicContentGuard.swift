import Foundation

/// Verhindert, dass Produktions- oder Modellhinweise in kunden sichtbaren Dateien landen.
enum PublicContentGuard {
    static func validate(project: Project) throws {
        let issues = blockingIssues(project: project)
        guard issues.isEmpty else {
            throw AIError.systemError(
                "Export blockiert: Produktionshinweis in \(issues.joined(separator: ", ")). " +
                "Bitte den betroffenen Text prüfen und bereinigen."
            )
        }
    }

    static func blockingIssues(project: Project, includeChapters: Bool = true) -> [String] {
        var fields: [(label: String, text: String)] = [
            ("Buchtitel", project.title),
            ("Autorprofil", project.authorBio),
            ("Impressum", project.imprint)
        ]

        if let profile = project.bookProfile {
            fields.append(contentsOf: [
                ("KDP-Titel", profile.kdpTitle),
                ("KDP-Untertitel", profile.kdpSubtitle),
                ("KDP-Beschreibung", profile.kdpDescription),
                ("KDP-Keywords", profile.kdpKeywords),
                ("KDP-Kategorien", profile.kdpCategories),
                ("Cover-Prompts", profile.coverPrompts)
            ])
        }

        var issues = fields.compactMap { disclosureViolation(in: $0.text) ? $0.label : nil }
        // Urheberrecht/Marken in den KUNDENSICHTBAREN METADATEN. Hier ist jeder
        // Treffer ein echtes Problem: „Für Fans von Twilight" in der Beschreibung
        // oder „Harry Potter" im Titel ist bei KDP ein Ablehnungs-/Sperrgrund.
        // In der PROSA dagegen kann eine Erwähnung legitim sein (Figur spricht
        // über einen Film) – dort bleibt es bei der Meldung im Originalitäts-
        // Check, der Export wird nicht blockiert.
        issues += fields.compactMap { copyrightViolation(in: $0.text) ? "\($0.label) (Urheberrechts-/Marken-Risiko)" : nil }
        issues += fields.compactMap { songLyricRisk(in: $0.text) ? "\($0.label) (mögliches Songtext-Zitat)" : nil }

        if includeChapters {
            issues += (project.chapters ?? []).compactMap { chapter in
                guard let text = chapter.bestText else { return nil }
                return disclosureViolation(in: text) ? "Kapitel \(chapter.chapterNumber)" : nil
            }
            // Wörtliche Songtext-Zitate sind strikt geschützt (keine Fair-Use-Annahme)
            // und gehören in KEIN Buch – deshalb hier blockierend, nicht nur gemeldet.
            // WICHTIG: auf rawBestText prüfen, nicht auf bestText – die Bereinigung
            // entfernt Zeilen mit Notenzeichen (♪) stillschweigend; ein Blick erst
            // nach der Bereinigung sähe das Zitat nie.
            issues += (project.chapters ?? []).compactMap { chapter in
                guard let text = chapter.rawBestText else { return nil }
                return songLyricRisk(in: text) ? "Kapitel \(chapter.chapterNumber) (mögliches Songtext-Zitat)" : nil
            }
        }

        return issues
    }

    static func disclosureViolation(in text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return disclosurePatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// Urheberrechts-/Marken-Risiko in kundensichtbaren Texten (geschützte Werktitel,
    /// Figuren, Welten, lebende Bestseller-Autoren als Stil-Vorlage „schreibe wie …").
    ///
    /// Bisher prüfte der Guard nur auf KI-/Produktionshinweise: Eine KDP-Beschreibung
    /// „für Fans von Bridgerton" oder ein Titel mit „Hogwarts" passierte die
    /// Exportfreigabe unbeanstandet – genau die Stellen, an denen Amazon zuerst hinsieht.
    /// Die Begriffe kommen aus CopyrightChecker.forbiddenTerms (eine Quelle), werden
    /// hier aber mit WORTGRENZEN gesucht: Sonst feuerte „marvel" in „marvelled at"
    /// oder „Outlander" als gewöhnliches Wort – und legitimer Text wäre blockiert.
    static func copyrightViolation(in text: String) -> Bool {
        let lowered = text.lowercased()
        return CopyrightChecker.forbiddenTerms.contains { term in
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
            return lowered.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Mögliche wörtliche Songtext-/Gedicht-Zitate (Notenzeichen, „Songtext"/„Liedtext").
    /// Reale Liedtexte sind strikt urheberrechtlich geschützt.
    static func songLyricRisk(in text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("songtext") || lowered.contains("liedtext") { return true }
        return text.range(of: #"[♪🎵🎶]"#, options: .regularExpression) != nil
    }

    private static let disclosurePatterns = [
        #"(?s)\b(?:dieses|das)\s+(?:buch|werk|manuskript|kapitel|text|inhalt)\b.{0,120}\b(?:ki|künstlich(?:e|er|en|em|es)\s+intelligenz|ai)\b.{0,120}\b(?:erstellt|generiert|geschrieben|produziert|unterstützt)\b"#,
        #"(?s)\b(?:mit|mithilfe|unter\s+einsatz|mit\s+unterstützung)\s+(?:von\s+)?(?:ki|künstlich(?:e|er|en|em|es)\s+intelligenz|ai)\b.{0,80}\b(?:erstellt|generiert|geschrieben|produziert)\b"#,
        #"\b(?:ai[- ]generated|ki[- ]generiert(?:e|er|en|em|es)?|generated\s+(?:by|with)\s+ai)\b"#,
        #"\b(?:ki[- ]unterstützung|ki[- ]offenlegung)\b"#,
        #"\bals\s+(?:ki|sprachmodell|language\s+model)\b"#,
        #"\bich\s+bin\s+(?:ein|eine)\s+(?:ki|sprachmodell|language\s+model)\b"#,
        // Modell-/Anbieter-Namen haben in BUCHTEXT niemals etwas verloren. Bewusst
        // nur unmissverständliche Namen: „Claude" oder „Kimi" sind auch Personennamen
        // und würden legitime Prosa blockieren.
        #"\b(?:chatgpt|openai|anthropic)\b"#,
        #"\bnovelforge\b"#
    ]
}
