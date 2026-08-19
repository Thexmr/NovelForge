import Foundation

/// Eine einzige verbindliche Freigabe für fertige Bücher und öffentliche Exporte.
enum PublicationReadiness {
    static let minimumBookWordRatio = 0.80
    static let maximumBookWordRatio = 1.30
    static let maximumChapterWordRatio = ChapterRevisionSizing.maximumTargetRatio

    private struct ChapterSnapshot {
        let chapter: Chapter
        let text: String
        let wordCount: Int
    }

    private struct CachedAnalysis {
        let fingerprint: Int
        let exportIssues: [String]
        let completionIssues: [String]
    }

    private struct JobIdentity: Hashable {
        let phase: String
        let agentName: String
        let chapterNumber: Int?
        let sceneNumber: Int?
    }

    @MainActor private static var uiCache: [UUID: CachedAnalysis] = [:]

    static func validateForExport(project: Project) throws {
        let issues = exportBlockingIssues(project: project)
        guard issues.isEmpty else {
            throw AIError.systemError("Export blockiert: \(issues.joined(separator: " "))")
        }
    }

    static func validateForCompletion(project: Project) throws {
        let issues = completionBlockingIssues(project: project)
        guard issues.isEmpty else {
            throw AIError.systemError("Buch noch nicht fertig: \(issues.joined(separator: " "))")
        }
    }

    static func exportBlockingIssues(project: Project) -> [String] {
        exportBlockingIssues(project: project, snapshots: chapterSnapshots(project))
    }

    static func completionBlockingIssues(project: Project) -> [String] {
        completionBlockingIssues(project: project, snapshots: chapterSnapshots(project))
    }

    /// UI-Variante für Dashboard und Statuspanels. Sie vermeidet wiederholte
    /// Volltext-Scans bei jedem SwiftUI-Render. Abschluss und Export verwenden
    /// weiterhin immer die ungecachten Prüfungen oben.
    @MainActor
    static func cachedCompletionBlockingIssues(project: Project) -> [String] {
        cachedAnalysis(project: project).completionIssues
    }

    @MainActor
    static func cachedExportBlockingIssues(project: Project) -> [String] {
        cachedAnalysis(project: project).exportIssues
    }

    private static func exportBlockingIssues(project: Project,
                                             snapshots: [ChapterSnapshot]) -> [String] {
        guard !snapshots.isEmpty else { return ["Keine Kapitel vorhanden."] }

        var issues: [String] = []
        var empty: [Int] = []
        var truncated: [Int] = []
        var contaminated: [Int] = []
        var sourceReview: [Int] = []
        var definiteSpelling: [(chapter: Int, examples: [String])] = []
        var brokenDialogue: [Int] = []
        var publicIssues = PublicContentGuard.blockingIssues(
            project: project,
            includeChapters: false
        )

        for snapshot in snapshots {
            let chapterNumber = snapshot.chapter.chapterNumber
            if snapshot.text.isEmpty {
                empty.append(chapterNumber)
                continue
            }
            if !AutonomousContentQuality.hasCompleteSentenceEnding(snapshot.text) {
                truncated.append(chapterNumber)
            }
            if AutonomousContentQuality.containsMetaRequest(snapshot.text)
                || AutonomousContentQuality.containsPromptArtifacts(snapshot.text) {
                contaminated.append(chapterNumber)
            }
            let spellingIssues = SpellCheckService.eindeutigeFehler(
                in: snapshot.chapter.title + "\n" + snapshot.text
            )
            if !spellingIssues.isEmpty {
                definiteSpelling.append((chapterNumber, Array(spellingIssues.prefix(3))))
            }
            if !AutonomousContentQuality.brokenDialogueTypography(in: snapshot.text).isEmpty {
                brokenDialogue.append(chapterNumber)
            }
            if project.isNonfiction && NonfictionSafety.requiresSourceReview(snapshot.text) {
                sourceReview.append(chapterNumber)
            }
            if PublicContentGuard.disclosureViolation(in: snapshot.text) {
                publicIssues.append("Kapitel \(chapterNumber)")
            }
        }

        if !empty.isEmpty {
            issues.append("Leere Kapitel: \(numberList(empty)).")
        }
        if !truncated.isEmpty {
            issues.append("Abgeschnittene Kapitelenden: \(numberList(truncated)).")
        }
        if !contaminated.isEmpty {
            issues.append("Produktions- oder Platzhaltertext in Kapiteln: \(numberList(contaminated)).")
        }
        if !sourceReview.isEmpty {
            issues.append("Quellenprüfung noch offen in Kapiteln: \(numberList(sourceReview)).")
        }
        if !definiteSpelling.isEmpty {
            let chapters = definiteSpelling.map(\.chapter)
            let examples = definiteSpelling.flatMap(\.examples).prefix(4).joined(separator: ", ")
            issues.append(
                "Eindeutige Rechtschreibfehler in Kapiteln \(numberList(chapters)): \(examples)."
            )
        }
        if !brokenDialogue.isEmpty {
            issues.append(
                "Beschädigte Dialogtypografie in Kapiteln: \(numberList(brokenDialogue))."
            )
        }

        if !publicIssues.isEmpty {
            issues.append("Produktionshinweise in: \(publicIssues.joined(separator: ", ")).")
        }

        if !project.isNonfiction {
            let bibleNames = (project.storyBible?.characters ?? []).map(\.name)
            let canonText = [
                project.bookProfile?.premise ?? "",
                project.bookProfile?.logline ?? "",
                project.bookProfile?.synopsis ?? "",
                project.storyBible?.plotPoints ?? ""
            ].filter { !$0.isEmpty }.joined(separator: "\n")
            let required = CharacterCanonAudit.personNames(in: canonText)
            let missing = CharacterCanonAudit.missingRequiredNames(
                required: required, candidateNames: bibleNames
            )
            if !missing.isEmpty {
                issues.append(
                    "Figurenbibel widerspricht Praemisse oder Plot; fehlend: "
                        + missing.joined(separator: ", ") + "."
                )
            }

            let knownParts = Set(bibleNames.flatMap(CharacterCanonAudit.nameParts))
            let locationParts = Set((project.storyBible?.locations ?? []).flatMap {
                CharacterCanonAudit.nameParts($0.name)
            })
            let manuscriptParts = CharacterCanonAudit.actingCharacterNameParts(
                narrativeTexts: snapshots.map(\.text), minimumOccurrences: 2
            )
            let manuscriptPlaces = CharacterCanonAudit.catalogPlaceNameParts(
                narrativeTexts: snapshots.map(\.text), minimumOccurrences: 1
            )
            let unexpected = manuscriptParts.filter { part in
                !knownParts.contains(part)
                    && !locationParts.contains(part)
                    && !manuscriptPlaces.contains(part)
                    && !(part.hasSuffix("s") && knownParts.contains(String(part.dropLast())))
            }.sorted()
            if !unexpected.isEmpty {
                issues.append(
                    "Wiederholt auftretende Figuren ohne Eintrag in der Story Bible: "
                        + unexpected.prefix(8).joined(separator: ", ") + "."
                )
            }
        }
        return issues
    }

    private static func completionBlockingIssues(project: Project,
                                                 snapshots: [ChapterSnapshot],
                                                 exportIssues: [String]? = nil) -> [String] {
        var issues = exportIssues ?? exportBlockingIssues(project: project, snapshots: snapshots)
        guard !snapshots.isEmpty else { return issues }
        let chapters = snapshots.map(\.chapter)
        let texts = snapshots.map(\.text)

        if AutonomousContentQuality.isWeakTitle(project.title, genre: project.genre) {
            issues.append("Buchtitel ist ein Platzhalter, Genre-Label oder bekanntes Schablonenmuster.")
        }

        // Längere Sätze dürfen im fertigen Manuskript nicht wortgleich erneut auftauchen.
        // Kurze Dialog- und Alltagsbeats bleiben erlaubt, solange sie nicht gehämmert werden.
        //
        // ES MUSS DIESELBE FUNKTION SEIN, DIE AUCH DIE REPARATUR VERWENDET.
        // Vorher stand hier eine eigene Filterzeile (words >= 7 && occurrences >= 2).
        // Der Reparaturschritt räumt aber nach `blockingRepeatedSentences` auf, und die
        // Funktion verschont bewusst zwei Fälle: denselben Satz zweimal INNERHALB eines
        // Kapitels (Stilmittel) und kurze Sätze in BENACHBARTEN Kapiteln (Leitmotiv).
        // Diese Prüfung kannte die Ausnahmen nicht und blockierte trotzdem.
        //
        // Ergebnis war ein Patt, das sich nicht auflösen kann: Die Reparatur fand nichts
        // zu tun und kehrte sofort zurück, die Abnahme blieb rot. Gemessen an einem
        // fertigen Buch: 329 Runden, 3 h 51 min, kein einziger Modellaufruf, "0 von 1
        // behoben". Die 9 beanstandeten Sätze lagen fast alle in genau diesen Ausnahmen
        // (Kapitel 1↔1, 22↔23, 24↔25, 25↔26) – Sätze wie "Lena blieb stehen, die Hand
        // an der Klinke", je zweimal in 100.000 Wörtern.
        //
        // Was die Abnahme blockiert, muss die Reparatur auch beheben können.
        let seriousRepeats = AutonomousContentQuality.blockingRepeatedSentences(inChapters: texts)
        if !seriousRepeats.isEmpty {
            issues.append("Mehrfach wiederholte ganze Sätze gefunden (\(seriousRepeats.count)); Revision erforderlich.")
        }
        // STIL ALS FREIGABE-KRITERIUM.
        //
        // Bis hierher wurde Stil zwar gemessen, aber nie erzwungen: Auf Szenen-Ebene
        // gibt jeder Stilblocker ab Versuch 2 frei (Anti-Hänger-Regel, richtig so), und
        // buchweit gab es gar kein Kriterium. Ergebnis, gemessen an einem
        // ausgelieferten Buch mit aktiven Prüfungen: 7,5 Bilder je 1000 Wörter bei
        // erlaubten 2,5, dazu 203 Antithesen.
        //
        // DIE SCHWELLEN SIND GEMESSEN, NICHT GESCHÄTZT.
        //
        // Grundlage: 13 gemeinfreie deutsche Romane und Novellen, 1.119.025 Wörter,
        // menschengeschrieben (Schnitzler, Ganghofer, Norbert Jacques, Karl May,
        // Thea von Harbou, Thomas Mann u. a.; alle Autoren mind. 70 Jahre verstorben).
        // Einzelwerte in `Tests/Fixtures/referenz-kennzahlen.json`.
        //
        //   Bilder je 1000 Wörter   Median 2,5 · p75 3,8 · p90 5,3 · Maximum 6,9
        //   Filterwörter je 1000 W. Median 0,3 · p90 0,4 · Maximum 0,5
        //
        // Bilder: Die Referenzwerte oben beschreiben, was üblich IST – nicht, was hier
        // gewollt ist. Vorgabe des Autors ist bewusst kargere Prosa als bei den
        // Klassikern: höchstens EIN Bild je zehn Druckseiten (0,4 je 1000 Wörter).
        //
        // Drei Stufen, absichtlich gestaffelt:
        //   Ziel im Draft-Prompt   0,4 je 1000  (Prävention, kostet nichts)
        //   Satz-Chirurgie ab      0,8 je 1000  (räumt Häufungen ab, nicht Einzelbilder)
        //   Freigabe blockiert ab  5,5 je 1000  (dieser Wert)
        //
        // Die Freigabe MUSS über dem Chirurgie-Schwellwert liegen, sonst kann die
        // Reparatur ihr eigenes Gate nie erreichen – das war das 329-Runden-Patt.
        //
        // WARUM HIER 4,0 UND NICHT 1,0 STEHT. Der Wert stand auf 1,0 und war damit
        // strenger als JEDER der 13 Referenzromane: Der niedrigste liegt bei 1,4
        // (Buddenbrooks 1,6). Ein Gate, das Thomas Mann ablehnt, lehnt jedes Buch ab.
        // Gemessen an 34 fertigen Titeln dieses Programms (5,9 Mio. Wörter,
        // `Scripts/BuchScanProbe.swift`): Spanne 2,8–7,8, Mittel 4,8. Kein einziges
        // hätte abgeschlossen werden können – die Produktion wäre in der Endabnahme
        // stehengeblieben, und zwar ohne erreichbaren Ausweg.
        //
        // Das ist genau das Muster, an dem dieses Projekt zweimal gescheitert ist: ein
        // Grenzwert, der aus dem gewünschten ZIEL abgeleitet wurde statt aus dem, was
        // ein gutes Buch erreicht.
        //
        // WARUM NICHT 4,0. Der erste Korrekturversuch stand auf 4,0 und hätte 24 der 34
        // Titel geblockt – auch solche innerhalb des professionellen Bandes (Referenz
        // p75 3,8, p90 5,3). Ein Gate darf nicht die Ästhetik durchsetzen; das ist die
        // Aufgabe des Prompts. Es darf nur die Katastrophe abfangen. Sonst greift genau
        // die Reparatur, von der Regel 4 sagt, dass sie den Text schlechter macht.
        //
        // Deshalb 5,5: knapp über p90 der Referenz (5,3), unter deren Maximum (6,9).
        // Das blockiert 7 der 34 Titel – die Bilderflut mit 7,8 und das ausgelieferte
        // Buch mit 7,5 –, lässt aber jeden Roman durch, den ein Lektor akzeptieren
        // würde. Das Ziel bleibt unverändert bei 0,4 und steht im Draft-Prompt, wo es
        // die Prosa formt, ohne etwas zu blockieren.
        //
        // Filterwörter: vorher stand hier 2,0 – das VIERFACHE des gemessenen Maximums,
        // das Gate hätte nie ausgelöst. Jetzt 1,0, also doppelter Sicherheitsabstand
        // zum schlechtesten Referenzwert.
        //
        // Ein alter, fortgesetzter Titel wird über die Stall-Erkennung pausiert statt
        // endlos repariert – die Freigabe kann also nie zum Patt werden.
        let stil = AutonomousContentQuality.stilKennzahlen(inChapters: texts)
        if stil.bilder > 5.5 {
            issues.append(String(
                format: "Bilderflut im Manuskript (%.1f je 1000 Wörter, Freigabe bis 5,5; "
                    + "Ziel im Schreibprompt: ein Bild je zehn Seiten).", stil.bilder))
        }
        if stil.filter > 1.0 {
            issues.append(String(
                format: "Zu viele Filterwörter im Manuskript (%.1f je 1000 Wörter, erlaubt 1,0; "
                    + "Median guter Romane: 0,3).", stil.filter))
        }

        let repeatedPhrases = AutonomousContentQuality.blockingRepeatedPhrases(
            inChapters: texts
        )
        if !repeatedPhrases.isEmpty {
            let examples = repeatedPhrases.prefix(3).joined(separator: " | ")
            issues.append(
                "Überstrapazierte Formulierungen im Manuskript (\(repeatedPhrases.count)): "
                    + examples + "."
            )
        }

        // Ein einzelnes Wegdrehen oder Augen-Schliessen ist normale Prosa. Die Freigabe
        // blockiert erst sichtbar gehämmerte Reaktionsformeln über das ganze Buch hinweg.
        // Der Reparaturpfad verwendet dieselben Treffer und arbeitet absatzweise, damit
        // das Gate keine neue Endlosschleife oder eine Kapitel-Neufassung erzwingt.
        let formulaicReactions = AutonomousContentQuality.blockingFormulaicReactionPhrases(
            inChapters: texts
        )
        if !formulaicReactions.isEmpty {
            issues.append(
                "Mechanisch wiederholte Reaktionsformeln im Manuskript: "
                    + formulaicReactions.prefix(4).joined(separator: " | ") + "."
            )
        }

        if !project.isNonfiction {
            let characters = project.storyBible?.characters ?? []
            let explicitProtagonists = characters.filter {
                let role = $0.role.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()
                return role.contains("protagon") || role.contains("hauptfigur")
            }.map(\.name)
            let protagonistNames = explicitProtagonists.isEmpty
                ? Array(characters.map(\.name).prefix(1))
                : explicitProtagonists
            if let firstText = texts.first {
                let openingIssues = AutonomousContentQuality.finalOpeningIssues(
                    in: firstText,
                    protagonistNames: protagonistNames
                )
                if !openingIssues.isEmpty {
                    issues.append(
                        "Romananfang nicht freigabefaehig: "
                            + openingIssues.prefix(3).joined(separator: " ")
                    )
                }
            }

            // Ein sauber exportierbares Manuskript ist noch kein lesenswertes Buch.
            // Jeder ausgeschriebene Abschnitt muss daher das Kapitellektorat bestehen:
            // Prosa, konkrete Szenen, Sog/Weiterentwicklung und Dialog dürfen nicht
            // nur im Durchschnitt gut aussehen, während einzelne Kapitel still stehen.
            let weakEditorialChapters = snapshots.compactMap { snapshot -> (Int, ChapterEditorialScorecard)? in
                let card = ChapterEditorialScorecard.evaluate(chapter: snapshot.chapter)
                return card.verdict == .ready ? nil : (snapshot.chapter.chapterNumber, card)
            }
            if !weakEditorialChapters.isEmpty {
                let details = weakEditorialChapters.prefix(4).map { number, card in
                    "K\(number): Sog \(Int((card.momentum * 100).rounded())) %, Gesamt \(Int((card.overall * 100).rounded())) %"
                }.joined(separator: "; ")
                issues.append(
                    "Kapitellektorat nicht freigabefaehig – Szenenziel, Widerstand, Wendung und Folge sind in mindestens einem Kapitel zu schwach: \(details)."
                )
            }

            let nameOveruse = AutonomousContentQuality.characterNameOveruseFindings(
                inChapters: texts,
                characterNames: characters.map(\.name)
            )
            if !nameOveruse.isEmpty {
                let examples = nameOveruse.prefix(4).map {
                    "\($0.characterName) in Kapitel \(chapters[$0.chapterIndex].chapterNumber)"
                }.joined(separator: ", ")
                issues.append(
                    "Figurenname in kurzen Absaetzen zu oft wiederholt: \(examples)."
                )
            }

            if let tense = project.bookProfile?.tense,
               !tense.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let tenseBreaks = snapshots.filter {
                    !AutonomousContentQuality.narrativeTenseIssuesAcrossSections(
                        in: $0.text, expectedTense: tense
                    ).isEmpty
                }.map { $0.chapter.chapterNumber }
                if !tenseBreaks.isEmpty {
                    issues.append(
                        "Zeitform im Erzaehltext gebrochen in Kapiteln: "
                            + numberList(tenseBreaks) + "."
                    )
                }
            }

            let aiLikeChapters = snapshots.filter {
                AutonomousContentQuality.soundsLikeAI($0.text)
            }.map { $0.chapter.chapterNumber }
            if !aiLikeChapters.isEmpty {
                issues.append(
                    "Maschinell oder formelhaft wirkende Endfassung in Kapiteln: "
                        + numberList(aiLikeChapters) + "."
                )
            }

            let antiGlaetteChapters = snapshots.filter {
                !AutonomousContentQuality.antiGlaetteFindings(in: $0.text).isEmpty
            }.map { $0.chapter.chapterNumber }
            if !antiGlaetteChapters.isEmpty {
                issues.append(
                    "Übererklärende oder künstlich gerundete Endfassung in Kapiteln: "
                        + numberList(antiGlaetteChapters)
                        + ". Sichtbare Handlung nicht nachträglich deuten und keine Erkenntnis-Haken behaupten."
                )
            }
        }

        if project.isNonfiction {
            let practicalCoverage = AutonomousContentQuality.nonfictionPracticalCoverage(texts)
            if practicalCoverage < 0.50 {
                issues.append("Zu wenige Sachbuchkapitel enthalten Beispiele, Übungen, Checklisten oder konkrete Anwendung (\(Int((practicalCoverage * 100).rounded()))%).")
            }
            let bundle = NonfictionResearchService.decodeManifest(
                project.bookProfile?.sourceManifest ?? ""
            )
            let highRisk = NonfictionSafety.isHighRisk(
                genre: project.genre, premise: project.bookProfile?.premise ?? ""
            )
            let minimumSources = highRisk ? 4 : 2
            if (bundle?.sources.count ?? 0) < minimumSources {
                issues.append("Quellenbasis unvollständig: mindestens \(minimumSources) nachvollziehbare Quellen erforderlich.")
            }
            if minimumSources >= 4 && bundle?.hasScholarlySource != true {
                issues.append("Hochrisiko-Sachbuch benötigt mindestens eine fachliche, medizinische oder offizielle Quelle.")
            }
            let sourceCount = bundle?.sources.count ?? 0
            let invalidCitations = texts.flatMap {
                NonfictionSafety.invalidCitationNumbers(in: $0, sourceCount: sourceCount)
            }
            if !invalidCitations.isEmpty {
                issues.append("Ungültige Quellenverweise im Manuskript: \(Array(Set(invalidCitations)).sorted().map { "Q\($0)" }.joined(separator: ", ")).")
            }
            if highRisk {
                let citedChapters = texts.filter { !NonfictionSafety.citationNumbers(in: $0).isEmpty }.count
                let coverage = texts.isEmpty ? 0 : Double(citedChapters) / Double(texts.count)
                if coverage < 0.50 {
                    issues.append("Hochrisiko-Sachbuch belegt zu wenige Kapitel mit Quellenverweisen (\(Int((coverage * 100).rounded()))%).")
                }
            }
        }

        let unfinished = chapters.filter {
            normalizedText($0.finalText).isEmpty || $0.status != .finalized
        }.map(\.chapterNumber)
        if !unfinished.isEmpty {
            issues.append("Nicht finalisierte Kapitel: \(numberList(unfinished)).")
        }

        let duplicateNumbers = Dictionary(grouping: chapters, by: \.chapterNumber)
            .filter { $0.value.count > 1 }.keys.sorted()
        if !duplicateNumbers.isEmpty {
            issues.append("Doppelte Kapitelnummern: \(numberList(duplicateNumbers)).")
        }

        let oversized = snapshots.filter { snapshot in
            guard snapshot.chapter.targetWordCount > 0 else { return false }
            return Double(snapshot.wordCount)
                > Double(snapshot.chapter.targetWordCount) * maximumChapterWordRatio
        }.map { $0.chapter.chapterNumber }
        if !oversized.isEmpty {
            issues.append("Kapitel deutlich über Zielumfang: \(numberList(oversized)).")
        }

        if project.targetWordCount > 0 {
            let ratio = Double(snapshots.reduce(0) { $0 + $1.wordCount })
                / Double(project.targetWordCount)
            if ratio < minimumBookWordRatio || ratio > maximumBookWordRatio {
                issues.append("Gesamtumfang bei \(Int((ratio * 100).rounded()))% des Ziels (erlaubt 80–130%).")
            }
        }

        if project.imprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Impressum fehlt.")
        }
        if project.authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Autorprofil fehlt.")
        }

        if let profile = project.bookProfile {
            var missingMetadata: [String] = []
            if profile.kdpTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingMetadata.append("Titel")
            }
            if profile.kdpDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingMetadata.append("Verkaufstext")
            }
            if profile.kdpKeywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingMetadata.append("Keywords")
            }
            if profile.kdpCategories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                missingMetadata.append("Kategorien")
            }
            if !missingMetadata.isEmpty {
                issues.append("KDP-Metadaten fehlen: \(missingMetadata.joined(separator: ", ")).")
            }
        } else {
            issues.append("Buchprofil und KDP-Metadaten fehlen.")
        }

        let jobs = project.pipelineJobs ?? []
        let completedDates = latestCompletedDates(in: jobs)
        let active = unresolvedJobs(in: jobs, completedDates: completedDates) { $0.status != .failed }
        // Kapitel, die inzwischen finalisiert und nicht leer sind. Ein alter Fehlversuch
        // (z.B. aus einem früheren, fehlerhaften Build) für ein solches Kapitel darf die
        // Freigabe NICHT dauerhaft blockieren – die Szene wurde später erfolgreich geschrieben,
        // beim Fortsetzen aber übersprungen, ohne einen neuen „completed"-Job derselben Identität
        // zu erzeugen. Ohne diese Bereinigung scheitert ein fertiges Buch endlos an Altlasten.
        let finalizedChapters = Set(
            chapters
                .filter { $0.status == .finalized && !normalizedText($0.finalText).isEmpty }
                .map(\.chapterNumber)
        )
        let failed = unresolvedJobs(in: jobs, completedDates: completedDates) { $0.status == .failed }
            .filter(isBlockingJob)
            .filter { job in
                guard let chapterNumber = job.chapterNumber else { return true }
                return !finalizedChapters.contains(chapterNumber)
            }
        if !active.isEmpty {
            issues.append("Noch offene Pipeline-Jobs: \(active.count).")
        }
        if !failed.isEmpty {
            issues.append("Nicht erfolgreich wiederholte Fehler-Jobs: \(failed.count).")
        }

        let unresolvedReports = (project.qualityReports ?? []).filter { report in
            QualityReleasePolicy.isBlockingReport(
                autoFixed: report.autoFixed,
                severity: report.severity
            )
        }
        if !unresolvedReports.isEmpty {
            let critical = unresolvedReports.filter { $0.severity == .critical }.count
            let errors = unresolvedReports.filter { $0.severity == .error }.count
            issues.append("Offene Qualitätsbefunde: \(critical) kritisch, \(errors) Fehler.")
        }

        return issues
    }

    private static func chapterSnapshots(_ project: Project) -> [ChapterSnapshot] {
        sortedChapters(project).map { chapter in
            let text = normalizedText(chapter.bestText)
            return ChapterSnapshot(chapter: chapter, text: text, wordCount: text.wordCount)
        }
    }

    @MainActor
    private static func cachedAnalysis(project: Project) -> CachedAnalysis {
        let fingerprint = uiFingerprint(project)
        if let cached = uiCache[project.id], cached.fingerprint == fingerprint {
            return cached
        }

        let snapshots = chapterSnapshots(project)
        let exportIssues = exportBlockingIssues(project: project, snapshots: snapshots)
        let completionIssues = completionBlockingIssues(
            project: project,
            snapshots: snapshots,
            exportIssues: exportIssues
        )
        let analysis = CachedAnalysis(
            fingerprint: fingerprint,
            exportIssues: exportIssues,
            completionIssues: completionIssues
        )

        // Der Cache hält nur Strings/IDs, trotzdem bleibt er für jahrelange
        // Dauerproduktion bewusst begrenzt.
        if uiCache.count >= 256, uiCache[project.id] == nil {
            uiCache.removeAll(keepingCapacity: true)
        }
        uiCache[project.id] = analysis
        return analysis
    }

    @MainActor
    private static func uiFingerprint(_ project: Project) -> Int {
        var hasher = Hasher()
        hasher.combine(project.id)
        hasher.combine(project.updatedAt)
        hasher.combine(project.status.rawValue)
        hasher.combine(project.targetWordCount)
        hasher.combine(project.imprint)
        hasher.combine(project.authorBio)

        if let profile = project.bookProfile {
            hasher.combine(profile.kdpTitle)
            hasher.combine(profile.kdpSubtitle)
            hasher.combine(profile.kdpDescription)
            hasher.combine(profile.kdpKeywords)
            hasher.combine(profile.kdpCategories)
            hasher.combine(profile.coverPrompts)
        } else {
            hasher.combine(false)
        }

        let chapters = project.chapters ?? []
        hasher.combine(chapters.count)
        for chapter in chapters {
            hasher.combine(chapter.id)
            hasher.combine(chapter.updatedAt)
            hasher.combine(chapter.status.rawValue)
            hasher.combine(chapter.actualWordCount)
            hasher.combine(chapter.targetWordCount)
        }

        let jobs = project.pipelineJobs ?? []
        hasher.combine(jobs.count)
        for job in jobs {
            hasher.combine(job.id)
            hasher.combine(job.status.rawValue)
            hasher.combine(job.createdAt)
            hasher.combine(job.endTime)
            hasher.combine(job.errorCount)
        }

        let reports = project.qualityReports ?? []
        hasher.combine(reports.count)
        for report in reports {
            hasher.combine(report.id)
            hasher.combine(report.createdAt)
            hasher.combine(report.severity.rawValue)
            hasher.combine(report.autoFixed)
        }
        return hasher.finalize()
    }

    private static func sortedChapters(_ project: Project) -> [Chapter] {
        (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private static func normalizedText(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func numberList<S: Sequence>(_ numbers: S) -> String where S.Element == Int {
        numbers.map(String.init).joined(separator: ", ")
    }

    private static func unresolvedJobs(
        in jobs: [PipelineJob],
        completedDates: [JobIdentity: Date],
        matching predicate: (PipelineJob) -> Bool
    ) -> [PipelineJob] {
        // .paused zählt bewusst NICHT als offen: Ein pausierter Job ist unterbrochene
        // Arbeit ohne Besitzer – er wird nie von selbst „completed" und blockierte die
        // Freigabe dauerhaft (Buchhaltung ≠ Inhalt; fehlende Inhalte fangen die
        // Inhalts-Gates ab: leere Kapitel, abgeschnittene Enden, Platzhalter).
        let openStatuses: Set<JobStatus> = [.waiting, .running, .writing, .checking, .revising, .retrying]
        return jobs.filter { job in
            guard predicate(job), job.status == .failed || openStatuses.contains(job.status) else { return false }
            return completedDates[jobIdentity(job)].map { $0 <= job.createdAt } ?? true
        }
    }

    private static func latestCompletedDates(in jobs: [PipelineJob]) -> [JobIdentity: Date] {
        var dates: [JobIdentity: Date] = [:]
        for job in jobs where job.status == .completed {
            let identity = jobIdentity(job)
            if dates[identity].map({ $0 < job.createdAt }) ?? true {
                dates[identity] = job.createdAt
            }
        }
        return dates
    }

    private static func jobIdentity(_ job: PipelineJob) -> JobIdentity {
        JobIdentity(
            phase: job.phase.rawValue,
            agentName: job.agentName,
            chapterNumber: job.chapterNumber,
            sceneNumber: job.sceneNumber
        )
    }

    private static func isBlockingJob(_ job: PipelineJob) -> Bool {
        // Zusammenfassungen dienen nur dem Langzeitkontext. Ist eine davon ausgefallen,
        // bleibt der eigentliche Szenentext vollständig und darf die Freigabe bestimmen.
        job.agentName != AgentName.summarizer
    }

}
