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

        if !publicIssues.isEmpty {
            issues.append("Produktionshinweise in: \(publicIssues.joined(separator: ", ")).")
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

        // Professioneller, aber erreichbarer Maßstab: Ein Roman darf ein paar kurze,
        // wiederkehrende Beats enthalten (menschlich normal). Blockierend sind nur
        // Längere Sätze dürfen im fertigen Manuskript nicht wortgleich erneut auftauchen.
        // Kurze Dialog- und Alltagsbeats bleiben erlaubt, solange sie nicht gehämmert werden.
        let repeatStats = AutonomousContentQuality.repeatedSentenceStats(
            inChapters: texts,
            minimumOccurrences: 2
        )
        let seriousRepeats = repeatStats.filter {
            ($0.words >= 7 && $0.occurrences >= 2) || $0.occurrences >= 5
        }
        if !seriousRepeats.isEmpty {
            issues.append("Mehrfach wiederholte ganze Sätze gefunden (\(seriousRepeats.count)); Revision erforderlich.")
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
