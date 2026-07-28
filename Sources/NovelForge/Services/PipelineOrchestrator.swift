import Foundation
import SwiftData
import SwiftUI

/// Einstellungen für die Dauerproduktion (Unlimited-Modus):
/// Die Pipeline erfindet selbst Buchideen und produziert Buch für Buch,
/// bis gestoppt wird oder die maximale Anzahl erreicht ist.
struct UnlimitedSettings {
    var authorName: String
    var language: String
    var selectedGenres: [String]
    var style: String          // "Zufällig" = pro Buch zufällig aus dem Pool
    var pageCount: Int
    var maxBooks: Int          // 0 = unbegrenzt
    var parallelBooks: Int     // 1...10 parallel laufende Bücher
    var formats: [String]
    var imprint: String
    var authorBio: String
    /// Optionale eigene Ideen des Autors (eine pro Eintrag), die in die Bücher
    /// einfließen. Leer = die Auto-Produktion erfindet alles selbst.
    var ideaSeeds: [String]
    /// Nach App-Neustart passende pausierte/fehlgeschlagene Bücher zuerst
    /// idempotent fertigstellen, bevor neue Projekte angelegt werden.
    var resumeInterruptedBooks: Bool

    static let randomToken = "Zufällig"
    static let genrePool = [
        // Spannung / Krimi
        "Thriller", "Psychothriller", "Spionagethriller", "Justizthriller", "Politthriller",
        "Wirtschaftsthriller", "Medizinthriller", "Ökothriller", "Krimi", "Regionalkrimi",
        "Historischer Krimi", "Cozy Mystery", "Mystery", "Whodunit", "Noir",
        // Roman / Gegenwart / Literarisch
        "Roman", "Gegenwartsliteratur", "Gesellschaftsroman", "Familiensaga", "Heimatroman",
        "Coming-of-Age", "Entwicklungsroman", "Feel-Good-Roman", "Tragikomödie", "Satire",
        "Magischer Realismus",
        // Liebe / Romance
        "Liebesroman", "Romance", "Romantasy", "Romantic Suspense", "Paranormal Romance",
        "Enemies-to-Lovers", "Slow Burn", "Chick-Lit", "Erotik", "Dark Romance", "New Adult",
        // Fantasy / Science Fiction
        "Fantasy", "High Fantasy", "Dark Fantasy", "Cozy Fantasy", "Grimdark", "Urban Fantasy",
        "Mythologie", "Science Fiction", "Space Opera", "Cyberpunk", "Dystopie",
        "Postapokalyptisch", "Zeitreise", "Steampunk",
        // Horror
        "Horror", "Gothic Horror", "Psychologischer Horror",
        // Historisch / Abenteuer
        "Historischer Roman", "Mittelalter-Saga", "Weltkriegsroman", "Western", "Abenteuer",
        "Survival", "Seeabenteuer",
        // Jung
        "Jugendbuch", "Fantasy-Jugendbuch", "Kinderbuch", "Märchen",
        // Romance-Tropes (KDP)
        "Romantische Komödie", "Second Chance Romance", "Forbidden Romance", "Fake Dating",
        "Friends to Lovers", "Grumpy/Sunshine", "Small-Town Romance", "Sports Romance",
        "Mafia Romance", "Bodyguard Romance", "Workplace Romance", "Holiday Romance",
        "Reverse Harem", "Why Choose", "Billionaire Romance", "Single Parent Romance",
        "Marriage of Convenience", "Frauenroman", "Liebesdrama",
        // Fantasy / SF erweitert
        "Epic Fantasy", "Sword & Sorcery", "LitRPG", "Progression Fantasy", "Portal-Fantasy",
        "Götter & Mythen", "Military Science Fiction", "Hard Science Fiction", "Solarpunk",
        "Biopunk", "Alternate History", "Dark Academia", "Vampirroman", "Werwolf/Shifter",
        "Hexen", "Geister & Spuk",
        // Spannung erweitert
        "Domestic Thriller", "Psychologischer Suspense", "Spionage", "Heist/Raubzug",
        "Serienkiller-Thriller", "Gerichtsdrama", "Agententhriller", "Techno-Thriller",
        // Horror / Komödie / Sonstiges
        "Splatterpunk", "Creature-Horror", "Folk Horror", "Komödie", "Schwarze Komödie",
        "Climate Fiction", "Familiendrama", "Generationenroman", "Roadtrip-Roman",
        "Künstlerroman", "Briefroman"] + BookContentType.nonfictionGenres
    static let stylePool = ["düster", "literarisch", "dialogstark", "humorvoll", "episch",
                            "emotional", "sinnlich", "schnell erzählt", "minimalistisch",
                            "atmosphärisch", "actionreich", "psychologisch"]

    init(authorName: String, language: String, genre: String, style: String,
         pageCount: Int, maxBooks: Int,
         parallelBooks: Int = 1, formats: [String],
         imprint: String = "", authorBio: String = "",
         resumeInterruptedBooks: Bool = true) {
        self.init(authorName: authorName, language: language,
                  selectedGenres: genre == Self.randomToken ? [] : [genre],
                  style: style, pageCount: pageCount, maxBooks: maxBooks,
                  parallelBooks: parallelBooks, formats: formats,
                  imprint: imprint, authorBio: authorBio,
                  resumeInterruptedBooks: resumeInterruptedBooks)
    }

    init(authorName: String, language: String, selectedGenres: [String], style: String,
         pageCount: Int, maxBooks: Int,
         parallelBooks: Int = 1, formats: [String],
         imprint: String, authorBio: String, ideaSeeds: [String] = [],
         resumeInterruptedBooks: Bool = true) {
        self.authorName = authorName
        self.language = language
        self.selectedGenres = selectedGenres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.style = style
        self.pageCount = min(max(pageCount, AppConstants.minPageCount), AppConstants.maxPageCount)
        self.maxBooks = maxBooks
        self.parallelBooks = min(max(parallelBooks, 1), 10)
        self.formats = formats
        self.imprint = imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.authorBio = authorBio.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ideaSeeds = ideaSeeds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.resumeInterruptedBooks = resumeInterruptedBooks
    }

    /// Liefert die nächste Autoren-Idee (rotierend), die in dieses Buch einfließt –
    /// oder nil, wenn keine eigenen Ideen hinterlegt sind.
    func ideaForBook(at index: Int) -> String? {
        guard !ideaSeeds.isEmpty else { return nil }
        return ideaSeeds[max(0, index) % ideaSeeds.count]
    }

    var targetWordCount: Int {
        pageCount * AppConstants.wordsPerPage
    }

    var effectiveGenres: [String] {
        selectedGenres.isEmpty ? Self.genrePool : selectedGenres
    }

    func genreForBook(at index: Int) -> String {
        let genres = effectiveGenres
        guard !genres.isEmpty else { return "Roman" }
        return genres[max(0, index) % genres.count]
    }

    func launchSlots(completedBooks: Int, activeBooks: Int) -> Int {
        let availableWorkers = max(0, parallelBooks - activeBooks)
        guard maxBooks > 0 else { return availableWorkers }
        let remainingBooks = max(0, maxBooks - completedBooks - activeBooks)
        return min(availableWorkers, remainingBooks)
    }
}

enum UnlimitedRecoveryPolicy {
    static func shouldRecover(project: Project,
                              settings: UnlimitedSettings,
                              provider: AIProvider) -> Bool {
        guard settings.resumeInterruptedBooks else { return false }
        switch project.status {
        case .created, .completed:
            return false
        default:
            break
        }

        let projectAuthor = project.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedAuthor = settings.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard projectAuthor.localizedCaseInsensitiveCompare(selectedAuthor) == .orderedSame else {
            return false
        }
        guard project.language.localizedCaseInsensitiveCompare(settings.language) == .orderedSame else {
            return false
        }
        return project.preferredProviderRaw == provider.rawValue
    }
}

/// Steuert die komplette autonome Buchproduktion.
///
/// Alle Phasen sind idempotent: bereits erledigte Arbeit (vorhandene Kapitel,
/// geschriebene Szenen, überarbeitete/korrigierte Kapitel) wird übersprungen.
/// Dadurch kann eine pausierte oder fehlgeschlagene Produktion jederzeit
/// fortgesetzt werden, ohne Kosten doppelt zu verursachen.
@MainActor
final class PipelineOrchestrator: ObservableObject {
    static let shared = PipelineOrchestrator()

    private enum StopMode {
        case none, pause, cancel
    }

    // MARK: - Veröffentlichter Zustand für die UI

    @Published var currentProject: Project?
    @Published var currentPhase: PipelinePhase = .projectSetup
    @Published var progress: Double = 0.0
    @Published var estimatedTimeRemaining: String = ""
    @Published var currentAgent: String = ""
    @Published var currentChapter: Int = 0
    @Published var currentScene: Int = 0
    @Published var isRunning: Bool = false
    @Published var lastError: String?
    @Published var totalScenes: Int = 0
    @Published var completedScenes: Int = 0
    @Published var totalTokensUsed: Int = 0
    @Published var estimatedCostUSD: Double = 0
    @Published var isUnlimitedMode: Bool = false
    @Published var unlimitedBooksCompleted: Int = 0
    @Published var currentBookElapsed: String = ""
    @Published var currentBookEstimatedTotal: String = ""
    /// Laufzeit der finalen Qualitätsreparatur/Selbstkorrektur (über alle
    /// Runden hinweg). Leer, solange keine Reparatur läuft.
    @Published var repairElapsed: String = ""
    /// Fortschritt der Reparatur: wie viele Freigabe-Punkte anfänglich offen waren
    /// (Basislinie) und wie viele davon noch offen sind. Erlaubt eine echte
    /// „noch N Punkte / X % erledigt"-Anzeige statt nur einer laufenden Uhr.
    @Published private(set) var repairIssuesTotal: Int = 0
    @Published private(set) var repairIssuesRemaining: Int = 0
    /// Geschätzte Restdauer der Reparatur (aus Fortschrittsrate). Leer, solange
    /// noch keine belastbare Schätzung möglich ist.
    @Published var repairEtaText: String = ""
    @Published var averageBookDuration: String = ""
    @Published var lastBookDuration: String = ""
    @Published var activeUnlimitedBooks: Int = 0
    @Published var parallelUnlimitedBooks: Int = 1
    /// Live-Status aller parallel laufenden Buch-Worker (für die UI).
    @Published var workerStatuses: [UnlimitedWorkerStatus] = []
    /// Projekte, an denen gerade aktiv produziert wird (auch von parallelen
    /// Workern). Diese dürfen nicht gelöscht oder doppelt gestartet werden.
    @Published var activeProjectIDs: Set<UUID> = []

    // MARK: - Intern

    private var modelContext: ModelContext?
    private var sceneTimes: [TimeInterval] = []
    private var backgroundTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var currentJob: PipelineJob?
    private var stopMode: StopMode = .none
    private var usedTitles: Set<String> = []
    private var unlimitedRunID = ""
    private var completedBookDurations: [TimeInterval] = []
    private var currentBookStartedAt: Date?
    /// Startzeitpunkt der finalen Reparaturphase. Bleibt über automatische
    /// Selbstkorrektur-Runden hinweg gesetzt, damit die angezeigte Reparaturzeit
    /// die gesamte Selbstheilung umfasst. `@Published`, damit die UI daraus einen
    /// sekundengenau tickenden Timer rendern kann.
    @Published private(set) var repairStartedAt: Date?
    /// Das Ganz-Kapitel-Repair-Audit der Endabnahme läuft höchstens einmal pro
    /// Produktionslauf (wird in finish() zurückgesetzt) – wiederholte Kapitel-
    /// Neufassungen erzeugen sonst laufend neue Satzdoppler (Divergenz).
    private var readinessRepairAuditDone = false
    private var unlimitedConsecutiveFailures = 0
    private let gateway = ProviderGateway.shared
    /// Bei parallelen Buch-Workern: der Haupt-Orchestrator (UI-Zustand, Titel-Register).
    private weak var parentOrchestrator: PipelineOrchestrator?
    /// Eindeutige Kennung dieses Workers für die Status-Anzeige.
    private let workerID = UUID()

    private struct UnlimitedBookOutcome {
        var completed: Bool
        var cancelled: Bool
        var title: String
        var duration: TimeInterval
        var error: Error?
        var message: String
    }

    /// Sichtbarer Zustand eines parallelen Buch-Workers.
    struct UnlimitedWorkerStatus: Identifiable, Equatable {
        let id: UUID
        var title: String
        var phase: PipelinePhase
        var agent: String
        var progress: Double
        var completedScenes: Int
        var totalScenes: Int
    }

    // MARK: - Titel-Register & Aktiv-Verwaltung (geteilt zwischen Workern)

    /// Prüft und reserviert einen Buchtitel zentral – bei parallelen Workern
    /// über den Haupt-Orchestrator, damit keine doppelten Titel entstehen.
    /// Schlüssel des dauerhaften Titel-Verzeichnisses.
    ///
    /// Es reicht NICHT, vergebene Titel nur im Arbeitsspeicher oder in der
    /// Projektdatenbank zu führen: Der Speicher ist nach einem Neustart leer, und
    /// ausgelieferte Bücher werden aus der Datenbank entfernt. Auch der Abgleich mit
    /// dem Ausgabeordner trägt nicht – der lässt sich umstellen, und die älteren
    /// Bücher liegen dann woanders. Genau daran ist es gescheitert: dieselben
    /// Ersatztitel wurden immer wieder vergeben.
    static let usedTitlesDefaultsKey = "novelforge.usedTitles"

    /// Alle jemals vergebenen Titel, klein geschrieben.
    private func persistedUsedTitles() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.usedTitlesDefaultsKey) ?? [])
    }

    private func persistUsedTitle(_ key: String) {
        var alle = persistedUsedTitles()
        guard !alle.contains(key) else { return }
        alle.insert(key)
        // Nach oben begrenzt, damit die Liste nicht unbegrenzt wächst.
        let liste = Array(alle.suffix(5000))
        UserDefaults.standard.set(liste, forKey: Self.usedTitlesDefaultsKey)
    }

    private func claimTitle(_ title: String) -> Bool {
        if let parent = parentOrchestrator { return parent.claimTitle(title) }
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !usedTitles.contains(key), !persistedUsedTitles().contains(key) else { return false }
        usedTitles.insert(key)
        persistUsedTitle(key)
        return true
    }

    private func markProjectActive(_ project: Project) {
        if let parent = parentOrchestrator {
            parent.markProjectActive(project)
        } else {
            activeProjectIDs.insert(project.id)
        }
    }

    private func markProjectInactive(_ project: Project?) {
        guard let project else { return }
        if let parent = parentOrchestrator {
            parent.markProjectInactive(project)
        } else {
            activeProjectIDs.remove(project.id)
        }
    }

    /// Meldet den eigenen Zustand an den Haupt-Orchestrator (Parallel-Modus).
    private func publishWorkerStatus() {
        guard let parent = parentOrchestrator else { return }
        let status = UnlimitedWorkerStatus(
            id: workerID,
            title: currentProject?.title ?? "Ideenfindung …",
            phase: currentPhase,
            agent: currentAgent,
            progress: progress,
            completedScenes: completedScenes,
            totalScenes: totalScenes
        )
        if let index = parent.workerStatuses.firstIndex(where: { $0.id == workerID }) {
            parent.workerStatuses[index] = status
        } else {
            parent.workerStatuses.append(status)
        }
    }

    private func retireWorkerStatus() {
        parentOrchestrator?.workerStatuses.removeAll { $0.id == workerID }
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Lektor-Chat (Korrekturen & Wünsche nach Fertigstellung)

    /// Verarbeitet eine Chat-Nachricht zum Buch. Ist ein Kapitel gewählt, wird es
    /// exakt nach dem Wunsch überarbeitet und gespeichert; sonst wird die Frage
    /// bzw. der Wunsch beantwortet. Gibt die Antwort des Lektors zurück.
    func processEditorMessage(_ text: String, project: Project, chapter: Chapter?) async -> String {
        let config = ProviderSettingsStore.configuration(for: project)
        let model = config.defaultModel ?? config.provider.suggestedModels.first ?? ""
        let chapters = sortedChapters(project)
        let bookContext = "Titel: \(project.title)\nGenre: \(project.genre)\nKapitel:\n"
            + chapters.map { "  \($0.chapterNumber). \($0.title)" }.joined(separator: "\n")

        do {
            if let chapter, let current = chapter.bestText, !current.isEmpty {
                let request = GenerationRequest(
                    prompt: PromptFactory.editorRevise(instruction: text, chapterTitle: chapter.title,
                                                       language: project.language,
                                                       currentText: current.truncated(to: 28000)),
                    systemPrompt: "Du bist ein erfahrener Lektor und Überarbeiter. Du setzt Autorenwünsche präzise um.",
                    model: model, provider: config.provider, maxTokens: 8000, temperature: 0.6
                )
                let response = try await gateway.generateText(request: request, configuration: config)
                // Während des Aufrufs könnten Kapitel/Projekt gelöscht/neu geplant worden
                // sein → Zugriff auf ein gelöschtes SwiftData-Objekt würde abstürzen.
                guard chapter.modelContext != nil, project.modelContext != nil else {
                    return "Das Kapitel ist nicht mehr verfügbar (es wurde gelöscht oder neu geplant)."
                }
                let revised = AutonomousContentQuality.humanizeProse(
                    AutonomousContentQuality.strippingInlineFormatting(
                        AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                guard AutonomousContentQuality.isAcceptableRewrite(
                          source: current,
                          candidate: revised,
                          minRatio: 0.33,
                          finishReason: response.finishReason),
                      !AutonomousContentQuality.containsMetaRequest(revised),
                      !PublicContentGuard.disclosureViolation(in: revised),
                      ContentSafetyFilter.isSafe(revised) else {
                    return "Die Überarbeitung kam unvollständig zurück. Formuliere den Wunsch gern konkreter oder versuch es noch einmal."
                }
                chapter.finalText = revised
                chapter.actualWordCount = revised.wordCount
                chapter.updatedAt = Date()
                project.updatedAt = Date()
                // Speicherfehler ehrlich melden, statt fälschlich Erfolg zu signalisieren.
                do {
                    try modelContext?.save()
                } catch {
                    return "Die Überarbeitung ist fertig, aber das Speichern ist fehlgeschlagen, die Änderung wurde NICHT gesichert: \(error.localizedDescription). Bitte versuch es noch einmal."
                }
                return "Erledigt: Kapitel \(chapter.chapterNumber) „\(chapter.title)“ wurde nach deinem Wunsch überarbeitet (\(revised.wordCount) Wörter). Du siehst es im Manuskript."
            } else {
                let request = GenerationRequest(
                    prompt: PromptFactory.editorChat(instruction: text, bookContext: bookContext),
                    systemPrompt: "Du bist der Lektor dieses Buches und hilfst dem Autor freundlich und konkret.",
                    model: model, provider: config.provider, maxTokens: 1200, temperature: 0.7
                )
                let response = try await gateway.generateText(request: request, configuration: config)
                let reply = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return reply.isEmpty ? "Dazu habe ich gerade keine Antwort. Formuliere es bitte anders." : reply
            }
        } catch {
            let message = (error as? AIError)?.errorDescription ?? error.localizedDescription
            return "Fehler bei der Lektor-Anfrage: \(message)"
        }
    }

    /// Prüft ein fertiges Buch auf echte Inkonsistenzen und repariert nur die
    /// betroffenen Kapitel. Breite Gesamtbefunde werden als Report gespeichert,
    /// aber nicht blind über das ganze Manuskript rewritten.
    func repairBookAfterProofreading(project: Project) async -> String {
        guard !isRunning else {
            return "Gerade läuft bereits eine Produktion oder Reparatur. Bitte warte, bis sie fertig ist."
        }
        guard project.modelContext != nil else {
            return "Dieses Projekt ist nicht mehr verfügbar."
        }

        let previousStatus = project.status
        let config = ProviderSettingsStore.configuration(for: project)
        isRunning = true
        stopMode = .none
        currentProject = project
        currentPhase = .manuscriptRevision
        currentAgent = AgentName.repairEditor
        lastError = nil
        progress = max(project.status.progressFraction, PipelinePhase.manuscriptRevision.weight)
        markProjectActive(project)
        ProductionSleepManager.shared.acquire(for: self)
        startHeartbeat()

        do {
            let result = try await runRepairWorkflow(project: project, config: config)
            project.status = previousStatus
            project.updatedAt = Date()
            modelContext?.saveOrLog()
            finish()
            return result
        } catch is CancellationError {
            project.status = previousStatus
            handleStop(project: project)
            return "Die Nachbearbeitung wurde pausiert."
        } catch {
            if let job = currentJob, job.status == .running {
                failJob(job, error: error)
            }
            project.status = previousStatus
            lastError = (error as? AIError)?.errorDescription ?? error.localizedDescription
            finish()
            return "Fehler bei der Nachbearbeitung: \(lastError ?? error.localizedDescription)"
        }
    }

    // MARK: - Veröffentlichungs-Pipeline (Nachveredelung fertiger Bücher)

    /// Baustein: erzeugt die KDP-Verkaufstexte (viraler Titel, Untertitel, Verkaufstext,
    /// Keywords, Kategorien) und schreibt sie ins BookProfile. Ohne Running-State-Verwaltung.
    /// Verdichtet den TATSÄCHLICH geschriebenen Handlungsbogen aus den Kapitel-Zusammenfassungen,
    /// damit Titel/Klappentext zum echten Inhalt passen – nicht nur zum geplanten Konzept (das oft
    /// vom fertigen Buch abweicht). Fällt auf das Konzept zurück, solange noch keine Szenen existieren.
    private func actualStorySynopsis(for project: Project, fallback: String) -> String {
        let chapters = (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
        let lines = chapters.compactMap { chapter -> String? in
            let scenes = (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }
            let summary = scenes.compactMap { $0.summary }.filter { !$0.isEmpty }.joined(separator: " ")
            return summary.isEmpty ? nil : "Kap. \(chapter.chapterNumber): \(summary)"
        }
        return lines.isEmpty ? fallback : lines.joined(separator: "\n")
    }

    private func produceKDPMetadata(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile else { return }
        let job = beginJob(agent: AgentName.kdpFormatter, phase: .kdpFormatting, project: project)
        do {
            let response = try await generate(
                prompt: PromptFactory.kdpMetadata(
                    title: project.title, author: project.authorName,
                    authorBio: project.authorBio,
                    genre: project.genre, audience: profile.targetAudience,
                    synopsis: actualStorySynopsis(for: project, fallback: profile.synopsis ?? profile.premise),
                    language: project.language, tropes: project.tropes,
                    spiceLevel: project.spiceLevel
                ),
                system: "Du bist ein erfahrener Buchmarketing-Texter für Amazon KDP. Deine Produktbeschreibungen verkaufen.",
                maxTokens: 1200, temperature: 0.7, config: config
            )
            let raw = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else {
                throw AIError.systemError("Leere Antwort vom Modell – KDP-Texte nicht überschrieben.")
            }
            let parsed = KDPMetadataParser.parse(raw)
            // Nur nicht-leere Felder übernehmen, damit eine schwache Antwort gute Daten nicht löscht.
            if !parsed.keywords.isEmpty { profile.kdpKeywords = parsed.keywords }
            if !parsed.categories.isEmpty { profile.kdpCategories = parsed.categories }
            if !parsed.salesTitle.isEmpty { profile.kdpTitle = parsed.salesTitle }
            if !parsed.subtitle.isEmpty { profile.kdpSubtitle = parsed.subtitle }

            // Verkaufstext-Veredelung: EINE Runde mit Plausibilitäts-Gate (Re-Polish degradiert sonst).
            var blurb = parsed.salesDescription.isEmpty ? raw : parsed.salesDescription
            let polishTitle = profile.kdpTitle.isEmpty ? project.title : profile.kdpTitle
            do {
                let polish = try await generate(
                    prompt: PromptFactory.kdpBlurbPolish(
                        blurb: blurb, title: polishTitle, genre: project.genre,
                        audience: profile.targetAudience, language: project.language),
                    system: "Du bist ein Spitzen-Texter für Amazon-KDP-Klappentexte.",
                    maxTokens: 700, temperature: 0.6, config: config
                )
                let improved = polish.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if improved.count >= 80 && improved.count <= 2400
                    && !improved.lowercased().contains("als ki") {
                    blurb = improved
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Veredelung übersprungen – Basistext behalten (nicht fatal).
            }
            if !blurb.isEmpty { profile.kdpDescription = blurb }
            completeJob(job, result: blurb, tokens: response.tokensUsed ?? 0)
        } catch {
            if job.status == .running { failJob(job, error: error) }
            throw error
        }
    }

    /// Baustein: erzeugt 3 fertige, kopierbare Cover-Bild-Prompts (ChatGPT/DALL·E),
    /// zugeschnitten auf dieses Buch, und legt sie im BookProfile + als Cover-Prompt.txt ab.
    private func produceCoverPrompts(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile else { return }
        let job = beginJob(agent: AgentName.coverDesigner, phase: .export, project: project)
        do {
            let signals = [
                "Logline: \(profile.logline ?? "")",
                "Prämisse: \(profile.premise)",
                "Thema: \(profile.theme)",
                "Tonalität: \(profile.tonality)",
                "Zielgruppe: \(profile.targetAudience)",
                "KDP-Beschreibung: \(profile.kdpDescription)"
            ].joined(separator: "\n")
            let response = try await generate(
                prompt: PromptFactory.coverImagePrompts(
                    title: project.title, author: project.authorName,
                    genre: project.genre, subgenre: project.subgenre ?? "",
                    language: project.language,
                    mood: project.styleProfile,
                    storySignals: String(signals.prefix(2400))
                ),
                system: "Du bist Art-Director für Bestseller-Buchcover und schreibst präzise, einfügefertige Bild-Prompts.",
                maxTokens: 1100, temperature: 0.8, config: config
            )
            let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw AIError.systemError("Leere Antwort vom Modell – Cover-Prompts nicht überschrieben.")
            }
            profile.coverPrompts = text
            _ = try? CoverDesignService.writePrompt(text, for: project)
            completeJob(job, result: text, tokens: response.tokensUsed ?? 0)
        } catch {
            if job.status == .running { failJob(job, error: error) }
            throw error
        }
    }

    /// Generischer On-Demand-Marketing-Schritt (Running-State, Guards, Fehlerbehandlung).
    private func runMarketingStep(project: Project, agent: String, phase: PipelinePhase,
                                  okMessage: String, errPrefix: String,
                                  _ work: (ProviderConfiguration) async throws -> Void) async -> String {
        guard !isRunning else {
            return "Gerade läuft bereits eine Produktion oder Reparatur. Bitte warte, bis sie fertig ist."
        }
        guard project.modelContext != nil else {
            return "Dieses Projekt ist nicht mehr verfügbar."
        }
        guard project.bookProfile != nil else {
            return "Für dieses Buch gibt es noch kein Konzept – erst Buch erstellen."
        }

        let previousStatus = project.status
        let config = ProviderSettingsStore.configuration(for: project)
        isRunning = true
        stopMode = .none
        currentProject = project
        currentPhase = phase
        currentAgent = agent
        lastError = nil
        markProjectActive(project)
        startHeartbeat()
        do {
            try await work(config)
            project.status = previousStatus
            project.updatedAt = Date()
            modelContext?.saveOrLog()
            finish()
            return okMessage
        } catch is CancellationError {
            project.status = previousStatus
            handleStop(project: project)
            return "Die Generierung wurde pausiert."
        } catch {
            project.status = previousStatus
            lastError = (error as? AIError)?.errorDescription ?? error.localizedDescription
            finish()
            let hint = (error as? AIError)?.recoverySuggestion.map { " \($0)" } ?? ""
            return "\(errPrefix): \(lastError ?? error.localizedDescription)\(hint)"
        }
    }

    /// Erzeugt bzw. erneuert die Amazon-KDP-Verkaufstexte auf Knopfdruck.
    func generateKDPSalesSheet(project: Project) async -> String {
        await runMarketingStep(project: project, agent: AgentName.kdpFormatter, phase: .kdpFormatting,
                               okMessage: "KDP-Verkaufstexte aktualisiert.",
                               errPrefix: "Fehler beim Generieren der KDP-Verkaufstexte") { config in
            try await self.produceKDPMetadata(project: project, config: config)
        }
    }

    /// Erzeugt bzw. erneuert die Cover-Bild-Prompts auf Knopfdruck.
    func generateCoverPrompts(project: Project) async -> String {
        await runMarketingStep(project: project, agent: AgentName.coverDesigner, phase: .export,
                               okMessage: "Cover-Prompts aktualisiert.",
                               errPrefix: "Fehler beim Generieren der Cover-Prompts") { config in
            try await self.produceCoverPrompts(project: project, config: config)
        }
    }

    /// Eigene Veröffentlichungs-Pipeline: lässt einen fertig produzierten Roman von mehreren
    /// Agenten nacheinander nachveredeln – Konsistenz-Reparatur (Repair Editor), KDP-Verkaufstexte
    /// (KDP Formatter) und Cover-Prompts (Cover Designer) – als komplettes Veröffentlichungs-Paket.
    func runPublishingPackage(project: Project) async -> String {
        guard !isRunning else {
            return "Gerade läuft bereits eine Produktion oder Reparatur. Bitte warte, bis sie fertig ist."
        }
        guard project.modelContext != nil else {
            return "Dieses Projekt ist nicht mehr verfügbar."
        }
        guard project.bookProfile != nil else {
            return "Für dieses Buch gibt es noch kein Konzept – erst Buch erstellen."
        }

        let previousStatus = project.status
        let config = ProviderSettingsStore.configuration(for: project)
        isRunning = true
        stopMode = .none
        currentProject = project
        currentAgent = AgentName.publisher
        lastError = nil
        markProjectActive(project)
        startHeartbeat()

        var done: [String] = []
        do {
            currentPhase = .manuscriptRevision
            currentAgent = AgentName.repairEditor
            let repairResult = try await runRepairWorkflow(project: project, config: config)
            done.append("Nachbearbeitung: \(repairResult)")

            currentPhase = .kdpFormatting
            currentAgent = AgentName.kdpFormatter
            try await produceKDPMetadata(project: project, config: config)
            done.append("KDP-Verkaufstexte erstellt.")

            currentPhase = .export
            currentAgent = AgentName.coverDesigner
            try await produceCoverPrompts(project: project, config: config)
            done.append("Cover-Prompts erstellt.")

            project.status = previousStatus
            project.updatedAt = Date()
            modelContext?.saveOrLog()
            finish()
            return "Veröffentlichungs-Paket fertig:\n• " + done.joined(separator: "\n• ")
        } catch is CancellationError {
            project.status = previousStatus
            handleStop(project: project)
            return "Veröffentlichungs-Paket pausiert. Erledigt:\n• " + (done.isEmpty ? ["nichts"] : done).joined(separator: "\n• ")
        } catch {
            if let job = currentJob, job.status == .running { failJob(job, error: error) }
            project.status = previousStatus
            lastError = (error as? AIError)?.errorDescription ?? error.localizedDescription
            finish()
            return "Veröffentlichungs-Paket gestoppt (\(lastError ?? error.localizedDescription)). Erledigt:\n• " + (done.isEmpty ? ["nichts"] : done).joined(separator: "\n• ")
        }
    }

    /// „Blick ins Buch": optimiert den Anfang des fertigen Buches (erstes Kapitel) auf
    /// maximalen Lesesog – der stärkste Conversion-Hebel auf Amazon (die Leseprobe verkauft).
    func optimizeOpening(project: Project) async -> String {
        await runMarketingStep(project: project, agent: AgentName.repairEditor, phase: .manuscriptRevision,
                               okMessage: "Buchanfang auf Lesesog optimiert (Blick ins Buch).",
                               errPrefix: "Fehler beim Optimieren des Anfangs") { config in
            try await self.produceOpeningOptimization(project: project, config: config)
        }
    }

    private func produceOpeningOptimization(project: Project, config: ProviderConfiguration) async throws {
        let chapters = (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
        guard let chapter = chapters.first,
              let currentText = chapter.bestText?.trimmingCharacters(in: .whitespacesAndNewlines),
              currentText.count > 200 else {
            throw AIError.systemError("Kein verwertbares erstes Kapitel zum Optimieren.")
        }
        let job = beginJob(agent: AgentName.repairEditor, phase: .manuscriptRevision, project: project)
        do {
            let response = try await generate(
                prompt: PromptFactory.openingHook(
                    language: project.language, bookTitle: project.title,
                    genre: project.genre, chapterText: currentText.truncated(to: 36_000)),
                system: "Du bist ein Bestseller-Lektor und optimierst den Buchanfang (Amazon-Leseprobe) auf maximalen Lesesog. Gib nur den vollständigen Kapiteltext zurück.",
                maxTokens: min(12000, max(4000, currentText.wordCount * 3)),
                temperature: 0.5, config: config, creative: true)
            let improved = AutonomousContentQuality.humanizeProse(
                AutonomousContentQuality.strippingInlineFormatting(
                    AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard improved.wordCount >= max(100, Int(Double(currentText.wordCount) * 0.6)),
                  !AutonomousContentQuality.containsMetaRequest(improved),
                  ContentSafetyFilter.isSafe(improved) else {
                throw AIError.systemError("Optimierter Anfang war unvollständig – Original behalten.")
            }
            chapter.finalText = improved
            chapter.actualWordCount = improved.wordCount
            chapter.status = .finalized
            chapter.updatedAt = Date()
            addReport(project: project, area: "Kapitel \(chapter.chapterNumber)", type: "Blick ins Buch",
                      result: "Anfang auf Lesesog optimiert.", severity: .info,
                      recommendation: "Leseprobe entscheidet den Kauf – Anfang wurde geschärft.")
            completeJob(job, result: "Anfang optimiert", tokens: response.tokensUsed ?? 0)
        } catch {
            if job.status == .running { failJob(job, error: error) }
            throw error
        }
    }

    /// Buch erweitern: bringt ein bestehendes Buch coherent auf einen größeren Zielumfang,
    /// indem jedes Kapitel vertieft wird (mehr Szene, Dialog, Sinnesdetails) – Handlung,
    /// Figuren und Reihenfolge bleiben exakt gleich, der Anschluss zwischen Kapiteln bleibt erhalten.
    func expandBook(project: Project, targetPageCount: Int) async -> String {
        await runMarketingStep(project: project, agent: AgentName.repairEditor, phase: .manuscriptRevision,
                               okMessage: "Buch auf ~\(targetPageCount) Seiten erweitert (Handlung bewahrt).",
                               errPrefix: "Fehler beim Erweitern des Buches") { config in
            try await self.produceBookExpansion(project: project, targetPageCount: targetPageCount, config: config)
        }
    }

    private func produceBookExpansion(project: Project, targetPageCount: Int, config: ProviderConfiguration) async throws {
        let chapters = sortedChapters(project)
        guard !chapters.isEmpty else { throw AIError.systemError("Keine Kapitel zum Erweitern vorhanden.") }
        let currentWords = max(1, project.totalWordCount)
        let targetWords = max(targetPageCount, 1) * AppConstants.wordsPerPage
        guard targetWords > Int(Double(currentWords) * 1.1) else {
            throw AIError.systemError("Der Zielumfang muss deutlich größer sein als der aktuelle Umfang.")
        }
        let scale = Double(targetWords) / Double(currentWords)
        let charactersSummary = project.storyBible.map { compactCharacterSummary($0) } ?? ""
        let genreBrief = project.bookProfile?.genreRules ?? ""
        var storySoFar = ""
        var expandedCount = 0

        for chapter in chapters {
            guard let text = chapter.bestText, text.wordCount >= 50 else {
                if let t = chapter.bestText { storySoFar = String((storySoFar + "\n\n" + t).suffix(8000)) }
                continue
            }
            let chapterTarget = max(text.wordCount + 150, Int(Double(text.wordCount) * scale))
            let job = beginJob(agent: AgentName.repairEditor, phase: .manuscriptRevision, project: project)
            do {
                let response = try await generate(
                    prompt: PromptFactory.expandChapter(
                        language: project.language, style: project.styleProfile, genre: project.genre,
                        bookTitle: project.title, chapterNumber: chapter.chapterNumber,
                        chapterTitle: chapter.title, currentText: text, targetWords: chapterTarget,
                        charactersSummary: charactersSummary, storySoFar: storySoFar, genreBrief: genreBrief),
                    system: "Du bist ein Romanlektor, der ein Kapitel auf mehr Umfang erweitert, ohne die Handlung zu verändern. Gib nur den vollständigen erweiterten Kapiteltext zurück.",
                    maxTokens: min(16000, max(4000, chapterTarget * 2)),
                    temperature: 0.7, config: config, creative: true)
                var expanded = AutonomousContentQuality.humanizeProse(
                    AutonomousContentQuality.strippingInlineFormatting(
                        AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                expanded = AutonomousContentQuality.strippingLeadingTitleEcho(expanded, title: chapter.title)
                if expanded.wordCount >= text.wordCount,
                   !AutonomousContentQuality.containsMetaRequest(expanded),
                   ContentSafetyFilter.isSafe(expanded) {
                    chapter.finalText = expanded
                    chapter.actualWordCount = expanded.wordCount
                    chapter.status = .finalized
                    chapter.updatedAt = Date()
                    expandedCount += 1
                    completeJob(job, result: "Kapitel \(chapter.chapterNumber) erweitert", tokens: response.tokensUsed ?? 0)
                } else {
                    completeJob(job, result: "Kapitel \(chapter.chapterNumber) unverändert (Erweiterung unbrauchbar)", tokens: response.tokensUsed ?? 0)
                }
            } catch {
                if job.status == .running { failJob(job, error: error) }
                // Ein fehlgeschlagenes Kapitel stoppt die Erweiterung nicht.
            }
            storySoFar = String((storySoFar + "\n\n" + (chapter.bestText ?? "")).suffix(8000))
        }

        project.targetPageCount = targetPageCount
        project.updatedAt = Date()
        addReport(project: project, area: "Umfang", type: "Erweiterung",
                  result: "Buch auf Zielumfang ~\(targetPageCount) Seiten erweitert (\(expandedCount) Kapitel vertieft, Handlung bewahrt).",
                  severity: .info, recommendation: "Kohärenz beim Lesen prüfen.")
    }

    /// Serie/Read-Through: baut am Ende des letzten Kapitels einen Cliffhanger + Teaser auf
    /// den nächsten Band ein – damit Leser die Reihe weiterkaufen.
    func addSeriesCliffhanger(project: Project) async -> String {
        await runMarketingStep(project: project, agent: AgentName.repairEditor, phase: .manuscriptRevision,
                               okMessage: "Cliffhanger + Teaser aufs nächste Buch eingebaut.",
                               errPrefix: "Fehler beim Einbauen des Cliffhangers") { config in
            try await self.produceSeriesCliffhanger(project: project, config: config)
        }
    }

    private func produceSeriesCliffhanger(project: Project, config: ProviderConfiguration) async throws {
        let chapters = (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
        guard let chapter = chapters.last,
              let currentText = chapter.bestText?.trimmingCharacters(in: .whitespacesAndNewlines),
              currentText.count > 200 else {
            throw AIError.systemError("Kein verwertbares letztes Kapitel für den Cliffhanger.")
        }
        let job = beginJob(agent: AgentName.repairEditor, phase: .manuscriptRevision, project: project)
        do {
            let response = try await generate(
                prompt: PromptFactory.cliffhangerTeaser(
                    language: project.language, bookTitle: project.title,
                    genre: project.genre, seriesName: project.seriesName,
                    chapterText: currentText.truncated(to: 36_000)),
                system: "Du bist ein Bestseller-Lektor für Serien und baust einen starken Cliffhanger + Teaser ein, ohne den Abschluss des Buches zu zerstören. Gib nur den vollständigen Kapiteltext zurück.",
                maxTokens: min(12000, max(4000, currentText.wordCount * 3)),
                temperature: 0.5, config: config, creative: true)
            let improved = AutonomousContentQuality.humanizeProse(
                AutonomousContentQuality.strippingInlineFormatting(
                    AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard improved.wordCount >= max(100, Int(Double(currentText.wordCount) * 0.6)),
                  !AutonomousContentQuality.containsMetaRequest(improved),
                  ContentSafetyFilter.isSafe(improved) else {
                throw AIError.systemError("Cliffhanger-Fassung war unvollständig – Original behalten.")
            }
            chapter.finalText = improved
            chapter.actualWordCount = improved.wordCount
            chapter.status = .finalized
            chapter.updatedAt = Date()
            addReport(project: project, area: "Kapitel \(chapter.chapterNumber)", type: "Serie",
                      result: "Cliffhanger + Teaser aufs nächste Buch eingebaut.", severity: .info,
                      recommendation: "Read-Through: führt Leser zum Folgeband.")
            completeJob(job, result: "Cliffhanger eingebaut", tokens: response.tokensUsed ?? 0)
        } catch {
            if job.status == .running { failJob(job, error: error) }
            throw error
        }
    }

    // MARK: - Steuerung

    func startPipeline(project: Project, providerConfig: ProviderConfiguration) {
        guard !isRunning else { return }

        isRunning = true
        stopMode = .none
        currentProject = project
        lastError = nil
        sceneTimes = []
        totalTokensUsed = 0
        estimatedCostUSD = 0
        progress = 0
        currentChapter = 0
        currentScene = 0
        estimatedTimeRemaining = ""
        currentBookElapsed = ""
        currentBookEstimatedTotal = ""
        completedBookDurations = []
        lastBookDuration = ""
        averageBookDuration = ""
        currentBookStartedAt = Date()
        updateProductionTiming()

        // Provider-Wahl am Projekt persistieren, damit Fortsetzen funktioniert.
        project.preferredProviderRaw = providerConfig.provider.rawValue
        if let model = providerConfig.defaultModel, !model.isEmpty {
            project.preferredModel = model
        }
        markProjectActive(project)
        ProductionSleepManager.shared.acquire(for: self)
        startHeartbeat()
        backgroundTask = Task { [weak self] in
            await self?.run(project: project, config: providerConfig)
        }
    }

    /// Pausiert die Produktion. Der Fortschritt bleibt vollständig erhalten.
    func pausePipeline() {
        guard isRunning else { return }
        stopMode = .pause
        backgroundTask?.cancel()
    }

    /// Bricht die Produktion ab und markiert das Projekt als fehlgeschlagen.
    func cancelPipeline() {
        guard isRunning else { return }
        stopMode = .cancel
        backgroundTask?.cancel()
    }

    /// Setzt ein pausiertes oder fehlgeschlagenes Projekt fort.
    /// Dank idempotenter Phasen wird nur fehlende Arbeit nachgeholt.
    func resumePipeline(project: Project) {
        guard !isRunning else { return }
        let config = ProviderSettingsStore.configuration(for: project)
        startPipeline(project: project, providerConfig: config)
    }

    // MARK: - Dauerproduktion (Unlimited-Modus)

    /// Startet die Dauerproduktion: Die Pipeline erfindet eigene Buchideen und
    /// produziert Buch für Buch in den Exportordner – bis Stopp gedrückt wird
    /// (oder optional die maximale Buchanzahl erreicht ist).
    func startUnlimitedProduction(settings: UnlimitedSettings, providerConfig: ProviderConfiguration) {
        guard !isRunning else { return }

        isRunning = true
        isUnlimitedMode = true
        stopMode = .none
        lastError = nil
        unlimitedBooksCompleted = 0
        usedTitles = Set(existingProjects().map { $0.title.lowercased() })
        unlimitedRunID = UUID().uuidString
        completedBookDurations = []
        unlimitedConsecutiveFailures = 0
        lastBookDuration = ""
        averageBookDuration = ""
        activeUnlimitedBooks = 0
        parallelUnlimitedBooks = settings.parallelBooks

        ProductionSleepManager.shared.acquire(for: self)
        startHeartbeat()
        backgroundTask = Task { [weak self] in
            await self?.runUnlimited(settings: settings, config: providerConfig)
        }
    }

    /// Stoppt die Dauerproduktion. Das aktuelle Buch bleibt gespeichert
    /// und kann später regulär fortgesetzt werden.
    func stopUnlimitedProduction() {
        pausePipeline()
    }

    private func runUnlimited(settings: UnlimitedSettings, config: ProviderConfiguration) async {
        if settings.parallelBooks > 1 {
            await runParallelUnlimited(settings: settings, config: config)
            return
        }

        var recoveryQueue = recoverableUnlimitedProjects(settings: settings, config: config)
        var interruptedProject: Project?
        var isRetryingCurrentBook = false
        var qualityRepairRounds = 0
        while !Task.isCancelled {
            if !isRetryingCurrentBook {
                sceneTimes = []
                totalTokensUsed = 0
                estimatedCostUSD = 0
                progress = 0
                currentChapter = 0
                currentScene = 0
                totalScenes = 0
                completedScenes = 0
                estimatedTimeRemaining = ""
                currentBookElapsed = ""
                currentBookEstimatedTotal = ""
                currentBookStartedAt = Date()
                currentProject = nil
                interruptedProject = recoveryQueue.isEmpty ? nil : recoveryQueue.removeFirst()
                updateProductionTiming()
            }
            lastError = nil

            do {
                let project: Project
                if let interruptedProject {
                    project = interruptedProject
                    currentProject = project
                    markProjectActive(project)
                    currentAgent = "Unterbrochenes Buch wird an der letzten sicheren Stelle fortgesetzt …"
                } else {
                    project = try await createUnlimitedProject(settings: settings, config: config)
                }
                currentProject = project

                try await executeAllPhases(project: project, config: config)

                try PublicationReadiness.validateForCompletion(project: project)
                project.status = .completed
                progress = 1.0
                recordCompletedBookDuration()
                unlimitedBooksCompleted += 1
                unlimitedConsecutiveFailures = 0
                qualityRepairRounds = 0
                interruptedProject = nil
                isRetryingCurrentBook = false
                markProjectInactive(project)
                currentAgent = "Buch \(unlimitedBooksCompleted) abgeschlossen – nächstes Buch wird geplant …"
                modelContext?.saveOrLog()

                if settings.maxBooks > 0 && unlimitedBooksCompleted >= settings.maxBooks {
                    break
                }
            } catch is CancellationError {
                if let project = currentProject {
                    handleStop(project: project)
                } else {
                    finish()
                }
                isUnlimitedMode = false
                return
            } catch {
                if let job = currentJob, job.status == .running {
                    failJob(job, error: error)
                }
                let aiError = error as? AIError
                lastError = aiError?.errorDescription ?? error.localizedDescription

                if Self.isReadinessShortfall(error), let project = currentProject {
                    qualityRepairRounds += 1
                    readinessRepairAuditDone = false
                    project.status = .export
                    interruptedProject = project
                    isRetryingCurrentBook = true
                    lastError = "Qualitäts-Endabnahme noch offen. Die Reparatur läuft automatisch weiter."
                    currentAgent = "Qualitätsreparatur Runde \(qualityRepairRounds) – dasselbe Buch bleibt aktiv"
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(Self.readinessRetryDelaySeconds * 1_000_000_000)
                        )
                    } catch {
                        handleStop(project: project)
                        isUnlimitedMode = false
                        return
                    }
                    continue
                }

                unlimitedConsecutiveFailures += 1

                // HINWEIS: Es gibt bewusst KEINEN Sonder-Retry für Szenenqualitäts-
                // Fehler mehr. Deterministische Content-Befunde werden im Schreib-Loop
                // als Report gespeichert (nie geworfen); ein unbegrenzter Retry hier
                // war die Ursache für nächtelange Endlos-Schleifen (143 Neustarts).

                // Temporäre Providerfehler setzen dasselbe, bereits geschriebene
                // Projekt fort. Dadurch bleiben 500-Seiten-Bücher nicht wegen
                // eines kurzen Netzausfalls nach hunderten Seiten liegen.
                if ProductionStabilityPolicy.shouldResumeInterruptedBook(after: error),
                   let project = currentProject,
                   project.status != .completed {
                    project.status = .paused
                    interruptedProject = project
                    isRetryingCurrentBook = true
                    let delay = ProductionStabilityPolicy.retryDelay(
                        forConsecutiveFailures: unlimitedConsecutiveFailures
                    )
                    currentAgent = "Provider vorübergehend nicht erreichbar – dieses Buch wird in \(ProductionStabilityPolicy.formatRetryDelay(delay)) fortgesetzt"
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch is CancellationError {
                        handleStop(project: project)
                        isUnlimitedMode = false
                        return
                    } catch {
                        handleStop(project: project)
                        isUnlimitedMode = false
                        return
                    }
                    continue
                }

                // Nicht automatisch behebbarer Buchfehler: Projekt bleibt zum
                // manuellen Fortsetzen erhalten; die Dauerproduktion entscheidet
                // anhand der Fehlerart, ob sie ein neues Buch starten darf.
                interruptedProject = nil
                isRetryingCurrentBook = false
                currentProject?.status = .failed
                markProjectInactive(currentProject)
                modelContext?.saveOrLog()

                // Dauerhaft unbehebbare Fehler beenden die Schleife,
                // statt alle paar Sekunden erneut zu scheitern.
                if ProductionStabilityPolicy.shouldHaltUnlimitedProduction(
                    after: error,
                    consecutiveFailures: unlimitedConsecutiveFailures
                ) {
                    currentAgent = "Dauerproduktion gestoppt – \(unlimitedConsecutiveFailures) Fehler in Folge"
                    break
                }

                let delay = ProductionStabilityPolicy.retryDelay(
                    forConsecutiveFailures: unlimitedConsecutiveFailures
                )
                currentAgent = "Fehler abgefangen – nächster Versuch in \(ProductionStabilityPolicy.formatRetryDelay(delay))"
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { break }
            }
        }

        isUnlimitedMode = false
        currentAgent = "Dauerproduktion beendet – \(unlimitedBooksCompleted) Bücher produziert"
        activeUnlimitedBooks = 0
        finish()
    }

    private func runParallelUnlimited(settings: UnlimitedSettings, config: ProviderConfiguration) async {
        currentProject = nil
        currentPhase = .projectSetup
        progress = 0
        totalScenes = 0
        completedScenes = 0
        totalTokensUsed = 0
        estimatedCostUSD = 0
        currentBookStartedAt = Date()
        updateProductionTiming()

        var launchedBooks = 0
        var activeBooks = 0
        var shouldStopLaunching = false
        var recoveryQueue = recoverableUnlimitedProjects(settings: settings, config: config)

        await withTaskGroup(of: UnlimitedBookOutcome.self) { group in
            @MainActor
            func launchAvailableBooks() {
                guard !shouldStopLaunching, !Task.isCancelled else { return }
                let slots = settings.launchSlots(
                    completedBooks: unlimitedBooksCompleted,
                    activeBooks: activeBooks
                )
                guard slots > 0 else { return }

                for _ in 0..<slots {
                    let bookIndex = launchedBooks
                    let resumeProject = recoveryQueue.isEmpty ? nil : recoveryQueue.removeFirst()
                    launchedBooks += 1
                    activeBooks += 1
                    activeUnlimitedBooks = activeBooks
                    let worker = makeUnlimitedWorker()
                    group.addTask {
                        await worker.runUnlimitedWorkerBook(
                            settings: settings,
                            config: config,
                            bookIndex: bookIndex,
                            resumeProject: resumeProject
                        )
                    }
                }
                currentAgent = "\(activeBooks) von \(settings.parallelBooks) Buch-Workern aktiv"
            }

            launchAvailableBooks()

            while activeBooks > 0, let outcome = await group.next() {
                activeBooks -= 1
                activeUnlimitedBooks = activeBooks
                var relaunchDelay: TimeInterval?

                if outcome.cancelled || Task.isCancelled {
                    shouldStopLaunching = true
                    group.cancelAll()
                    currentAgent = "Dauerproduktion pausiert – aktive Bücher wurden gespeichert"
                    break
                }

                if outcome.completed {
                    unlimitedBooksCompleted += 1
                    unlimitedConsecutiveFailures = 0
                    if outcome.duration > 0 {
                        completedBookDurations.append(outcome.duration)
                        lastBookDuration = ProductionTiming.formatHumanDuration(outcome.duration)
                    }
                    updateProductionTiming()
                    currentAgent = "\(unlimitedBooksCompleted) Bücher fertig · \(activeBooks) parallel aktiv"
                } else {
                    unlimitedConsecutiveFailures += 1
                    lastError = outcome.message
                    if let error = outcome.error,
                       ProductionStabilityPolicy.shouldHaltUnlimitedProduction(
                           after: error,
                           consecutiveFailures: unlimitedConsecutiveFailures
                       ) {
                        shouldStopLaunching = true
                        group.cancelAll()
                        currentAgent = "Dauerproduktion gestoppt – \(unlimitedConsecutiveFailures) Fehler in Folge"
                        break
                    }
                    relaunchDelay = ProductionStabilityPolicy.retryDelay(
                        forConsecutiveFailures: unlimitedConsecutiveFailures
                    )
                }

                if let relaunchDelay, relaunchDelay > 0 {
                    currentAgent = "Fehler abgefangen – neuer Worker in \(ProductionStabilityPolicy.formatRetryDelay(relaunchDelay))"
                    try? await Task.sleep(nanoseconds: UInt64(relaunchDelay * 1_000_000_000))
                    if Task.isCancelled {
                        shouldStopLaunching = true
                        group.cancelAll()
                        currentAgent = "Dauerproduktion pausiert – aktive Bücher wurden gespeichert"
                        break
                    }
                }
                launchAvailableBooks()
            }
        }

        activeUnlimitedBooks = 0
        isUnlimitedMode = false
        currentAgent = "Dauerproduktion beendet – \(unlimitedBooksCompleted) Bücher produziert"
        finish()
    }

    private func makeUnlimitedWorker() -> PipelineOrchestrator {
        let worker = PipelineOrchestrator()
        worker.modelContext = modelContext
        worker.unlimitedRunID = unlimitedRunID
        worker.parallelUnlimitedBooks = parallelUnlimitedBooks
        worker.parentOrchestrator = self
        return worker
    }

    private func runUnlimitedWorkerBook(settings: UnlimitedSettings,
                                        config: ProviderConfiguration,
                                        bookIndex: Int,
                                        resumeProject: Project? = nil) async -> UnlimitedBookOutcome {
        sceneTimes = []
        totalTokensUsed = 0
        estimatedCostUSD = 0
        progress = 0
        currentChapter = 0
        currentScene = 0
        estimatedTimeRemaining = ""
        currentBookElapsed = ""
        currentBookEstimatedTotal = ""
        currentBookStartedAt = Date()
        lastError = nil

        let startedAt = Date()
        var project = resumeProject
        var transientFailures = 0
        var qualityRepairRounds = 0

        if let project {
            currentProject = project
            markProjectActive(project)
            currentAgent = "Unfertiges Buch wird zuerst fortgesetzt …"
            publishWorkerStatus()
        }

        while !Task.isCancelled {
            do {
                if project == nil {
                    project = try await createUnlimitedProject(
                        settings: settings,
                        config: config,
                        bookIndex: bookIndex
                    )
                } else if let project {
                    markProjectActive(project)
                    currentAgent = "Unterbrochenes Buch wird fortgesetzt …"
                    publishWorkerStatus()
                }
                guard let project else {
                    throw AIError.systemError("Buchprojekt konnte nicht angelegt werden")
                }
                currentProject = project

                try await executeAllPhases(project: project, config: config)

                try PublicationReadiness.validateForCompletion(project: project)
                project.status = .completed
                progress = 1.0
                let duration = Date().timeIntervalSince(startedAt)
                markProjectInactive(project)
                modelContext?.saveOrLog()
                retireWorkerStatus()
                return UnlimitedBookOutcome(
                    completed: true,
                    cancelled: false,
                    title: project.title,
                    duration: duration,
                    error: nil,
                    message: ""
                )
            } catch is CancellationError {
                return cancelledUnlimitedBookOutcome()
            } catch {
                if let job = currentJob, job.status == .running {
                    failJob(job, error: error)
                }
                let message = (error as? AIError)?.errorDescription ?? error.localizedDescription

                if Self.isReadinessShortfall(error), let project {
                    qualityRepairRounds += 1
                    readinessRepairAuditDone = false
                    project.status = .export
                    lastError = "Qualitäts-Endabnahme noch offen. Die Reparatur läuft automatisch weiter."
                    currentAgent = "Qualitätsreparatur Runde \(qualityRepairRounds) – dasselbe Buch bleibt aktiv"
                    publishWorkerStatus()
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(Self.readinessRetryDelaySeconds * 1_000_000_000)
                        )
                    } catch {
                        return cancelledUnlimitedBookOutcome()
                    }
                    continue
                }

                if ProductionStabilityPolicy.shouldResumeInterruptedBook(after: error),
                   let project {
                    transientFailures += 1
                    project.status = .paused
                    lastError = message
                    let delay = ProductionStabilityPolicy.retryDelay(
                        forConsecutiveFailures: transientFailures
                    )
                    currentAgent = "Provider unterbrochen – dasselbe Buch läuft in \(ProductionStabilityPolicy.formatRetryDelay(delay)) weiter"
                    publishWorkerStatus()
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return cancelledUnlimitedBookOutcome()
                    }
                    continue
                }

                project?.status = .failed
                markProjectInactive(project)
                modelContext?.saveOrLog()
                retireWorkerStatus()
                return UnlimitedBookOutcome(
                    completed: false,
                    cancelled: false,
                    title: project?.title ?? "",
                    duration: 0,
                    error: error,
                    message: message
                )
            }
        }

        return cancelledUnlimitedBookOutcome()
    }

    private func cancelledUnlimitedBookOutcome() -> UnlimitedBookOutcome {
        if let project = currentProject {
            stopMode = .pause
            handleStop(project: project)
        }
        markProjectInactive(currentProject)
        retireWorkerStatus()
        return UnlimitedBookOutcome(
            completed: false,
            cancelled: true,
            title: currentProject?.title ?? "",
            duration: 0,
            error: nil,
            message: "Abgebrochen"
        )
    }

    /// Erfindet eine Buchidee und legt daraus ein vollständiges Projekt an.
    private func createUnlimitedProject(settings: UnlimitedSettings,
                                        config: ProviderConfiguration,
                                        bookIndex: Int? = nil) async throws -> Project {
        let genre = settings.genreForBook(at: bookIndex ?? unlimitedBooksCompleted)
        let seedIdea = settings.ideaForBook(at: bookIndex ?? unlimitedBooksCompleted)
        let style = settings.style == UnlimitedSettings.randomToken
            ? (UnlimitedSettings.stylePool.randomElement() ?? "atmosphärisch")
            : settings.style
        let memoryEntries = StoryMemory.entries(from: existingProjects())
        let avoidanceBrief = StoryMemory.makeAvoidanceBrief(
            entries: memoryEntries,
            selectedGenres: settings.effectiveGenres
        )

        currentPhase = .projectSetup
        currentAgent = "Ideenfindung für das nächste Buch …"
        currentProject = nil

        var idea: ParsedIdea?
        for attempt in 1...3 {
            let retryHint = attempt == 1 ? "" : "\n\nDer vorige Versuch war leer, generisch oder dupliziert. Erzeuge jetzt 5 konkrete, neue Buchideen im geforderten Format."
            let response = try await generate(
                prompt: PromptFactory.bookIdeas(genre: genre, language: settings.language,
                                                avoidanceBrief: avoidanceBrief,
                                                authorSeed: seedIdea ?? "") + retryHint,
                system: "Du bist ein Bestseller-Lektor und Titel-Experte mit sicherem Gespür für virale, originelle Buchideen und unverwechselbare Titel, die beim Scrollen sofort hängenbleiben. Du denkst in High-Concept-Hooks und genre-typischen Tropes, vermeidest Berufs-/Klischee-Titel und Wiederholungen gegenüber dem Story-Gedächtnis strikt.",
                maxTokens: 1000, temperature: 0.95, config: config
            )
            let ideas = StructureParser.parseIdeas(response.text)
            // Nicht die erste brauchbare Idee nehmen, sondern die mit dem stärksten,
            // klickträchtigsten Titel (virale Auswahl statt „first wins").
            let fresh = ideas.filter {
                AutonomousContentQuality.hasUsableIdea($0)
                    && !StoryMemory.isLikelyDuplicate($0, existing: memoryEntries)
            }
            let usable = fresh.isEmpty ? ideas.filter { AutonomousContentQuality.hasUsableIdea($0) } : fresh
            idea = usable.max {
                AutonomousContentQuality.titleViralityScore($0.title)
                    < AutonomousContentQuality.titleViralityScore($1.title)
            }
            if idea != nil { break }
        }
        // Durchgehende Dauerproduktion: wenn das Modell nach 3 Versuchen keine
        // verwertbare Idee liefert, NICHT abbrechen, sondern eine tragfähige
        // Ersatz-Idee verwenden. So läuft der Auto-Modus ununterbrochen weiter.
        if !AutonomousContentQuality.hasUsableIdea(idea) {
            // Eigene Autoren-Idee direkt als Prämisse nutzen, wenn das Modell nichts
            // Brauchbares lieferte – damit die Vorgabe NIE verloren geht.
            if let seed = seedIdea, !seed.isEmpty {
                // Die eigene Idee des Autors als Prämisse übernehmen – aber NICHT
                // „Thriller-Roman" als Titel. So ein Gattungstitel geht in jeder
                // Trefferliste unter; den Titel liefert die Notfall-Liste.
                let ersatz = fallbackIdea(genre: genre, index: bookIndex ?? unlimitedBooksCompleted)
                idea = ParsedIdea(title: ersatz.title, genre: genre, premise: seed)
            }
            if !AutonomousContentQuality.hasUsableIdea(idea) {
                idea = fallbackIdea(genre: genre, index: bookIndex ?? unlimitedBooksCompleted)
            }
        }

        // Auch hier kein Gattungstitel als letzter Ausweg.
        let baseTitle = idea?.title
            ?? fallbackIdea(genre: genre, index: bookIndex ?? unlimitedBooksCompleted).title
        var title = baseTitle
        var suffix = 2
        while !claimTitle(title) {
            // Schutz gegen Endlosschleife in der Dauerproduktion (z.B. wenn sehr
            // viele Duplikate denselben Basistitel beanspruchen).
            if suffix > 500 {
                title = "\(baseTitle) \(UUID().uuidString.prefix(6))"
                _ = claimTitle(title)
                break
            }
            title = "\(baseTitle) \(suffix)"
            suffix += 1
        }

        let project = Project(
            title: title,
            authorName: settings.authorName,
            language: settings.language,
            genre: genre,
            styleProfile: style,
            targetPageCount: settings.pageCount,
            outputFormats: settings.formats
        )
        project.preferredProviderRaw = config.provider.rawValue
        if let model = config.defaultModel, !model.isEmpty {
            project.preferredModel = model
        }
        project.imprint = settings.imprint
        project.authorBio = settings.authorBio
        project.autoProductionRunID = unlimitedRunID
        project.memorySignature = StoryMemory.signature(
            title: title,
            genre: genre,
            premise: idea?.premise ?? ""
        )

        // Pro Buch einzigartige Stil-DNA würfeln (eindeutiger Seed je Projekt) – verhindert,
        // dass alle autoproduzierten Bücher dieselbe Perspektive/Struktur/Stimme teilen
        // (Amazon-KDP-„Programmatic Content"-Erkennung).
        let signature = NarrativeSignature.make(
            seed: NarrativeSignature.stableSeed("\(project.id.uuidString)|\(title)|\(genre)")
        )
        project.styleSignature = signature.directive

        let profile = BookProfile(
            premise: idea?.premise ?? "",
            theme: "",
            targetAudience: "",
            tonality: style,
            narrativePerspective: signature.pov,
            tense: signature.tense
        )
        profile.project = project

        let bible = StoryBible()
        bible.project = project

        project.bookProfile = profile
        project.storyBible = bible

        modelContext?.insert(project)
        modelContext?.insert(profile)
        modelContext?.insert(bible)
        modelContext?.saveOrLog()
        markProjectActive(project)
        publishWorkerStatus()
        return project
    }

    /// Legt den nächsten Band einer Reihe an: erbt Autor/Genre/Format/Stil-DNA und
    /// einen Fortsetzungs-Kontext (Figuren, Welt, Ausgang, offene Fäden) vom Vorband.
    /// Das neue Projekt wird gespeichert und zurückgegeben; die Produktion startet der
    /// Nutzer wie gewohnt (es durchläuft die Pipeline als FOLGEBAND, kein Neustart).
    @discardableResult
    func createNextVolume(from previous: Project) -> Project {
        let seriesLabel = previous.seriesName.isEmpty ? previous.title : previous.seriesName
        let nextNumber = (previous.seriesNumber > 0 ? previous.seriesNumber : 1) + 1

        let next = Project(
            title: SeriesContinuation.nextVolumeTitle(from: previous),
            authorName: previous.authorName,
            language: previous.language,
            genre: previous.genre,
            styleProfile: previous.styleProfile,
            targetPageCount: previous.targetPageCount,
            outputFormats: previous.outputFormats
        )
        next.subgenre = previous.subgenre
        next.tropes = previous.tropes
        next.spiceLevel = previous.spiceLevel
        next.seriesName = seriesLabel
        next.seriesNumber = nextNumber
        // Gleiche Stil-DNA → einheitlicher Reihen-Ton (Serien dürfen sich ähneln).
        next.styleSignature = previous.styleSignature
        next.sequelContext = SeriesContinuation.brief(from: previous)
        next.trimSizeRaw = previous.trimSizeRaw
        next.imprint = previous.imprint
        next.authorBio = previous.authorBio
        next.preferredProviderRaw = previous.preferredProviderRaw
        next.preferredModel = previous.preferredModel
        next.costLimitUSD = previous.costLimitUSD

        // Buchprofil mit geerbter Perspektive/Tonalität/Zeitform (Reihen-Konsistenz);
        // Prämisse bleibt leer und wird vom Fortsetzungs-Konzept gefüllt.
        let profile = BookProfile(
            premise: "",
            theme: previous.bookProfile?.theme ?? "",
            targetAudience: previous.bookProfile?.targetAudience ?? "",
            tonality: previous.bookProfile?.tonality ?? "",
            narrativePerspective: previous.bookProfile?.narrativePerspective ?? "",
            tense: previous.bookProfile?.tense ?? ""
        )
        profile.project = next
        let bible = StoryBible()
        bible.project = next
        next.bookProfile = profile
        next.storyBible = bible

        modelContext?.insert(next)
        modelContext?.insert(profile)
        modelContext?.insert(bible)
        modelContext?.saveOrLog()
        return next
    }

    private func existingProjects() -> [Project] {
        guard let modelContext else { return [] }
        return (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
    }

    private func recoverableUnlimitedProjects(settings: UnlimitedSettings,
                                               config: ProviderConfiguration) -> [Project] {
        existingProjects()
            .filter { project in
                !activeProjectIDs.contains(project.id)
                    && UnlimitedRecoveryPolicy.shouldRecover(
                        project: project,
                        settings: settings,
                        provider: config.provider
                    )
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Hauptablauf

    /// Führt alle Pipeline-Phasen für ein Projekt aus (wirft bei Fehler/Abbruch).
    private func executeAllPhases(project: Project, config: ProviderConfiguration) async throws {
        for phase in executionPhases(for: project) {
            try Task.checkCancellation()
            currentPhase = phase
            updateProgress(phase: phase, subProgress: 0)

            switch phase {
            case .projectSetup:
                try runInputValidation(project: project)
            case .conceptDevelopment:
                try await runConceptPhase(project: project, config: config)
            case .structurePlanning:
                try await runStructurePhase(project: project, config: config)
            case .chapterPlanning:
                try await runChapterPlanning(project: project, config: config)
            case .scenePlanning:
                try await runScenePlanning(project: project, config: config)
            case .drafting:
                try await runDrafting(project: project, config: config)
            case .chapterRevision:
                try await runChapterRevision(project: project, config: config)
            case .manuscriptRevision:
                try await runConsistencyCheck(project: project, config: config)
            case .proofreading:
                try await runProofreading(project: project, config: config)
                // Bisher liefen Repair-Audit (Kontinuität/Spannung/Tropes) und die
                // „Blick ins Buch"-Eröffnungsoptimierung NUR über manuelle UI-Aktionen –
                // autonom produzierte Bücher bekamen die stärkste Qualitätsstufe nie.
                // Jetzt Teil jeder Pipeline; Fehler dort lassen das Buch nicht scheitern.
                do {
                    _ = try await runRepairWorkflow(project: project, config: config)
                } catch is CancellationError {
                    throw CancellationError() // Stop-Anforderung nie verschlucken
                } catch {
                    addReport(project: project, area: "Lektorat", type: "Reparatur",
                              result: "Automatisches Repair-Audit übersprungen: \(error.localizedDescription)",
                              severity: .warning, recommendation: "Manuell über Veröffentlichung → Reparatur starten.")
                }
                do {
                    try await produceOpeningOptimization(project: project, config: config)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    addReport(project: project, area: "Blick ins Buch", type: "Eröffnung",
                              result: "Automatische Eröffnungsoptimierung übersprungen: \(error.localizedDescription)",
                              severity: .info, recommendation: "Manuell über Veröffentlichung → Blick ins Buch starten.")
                }
            case .copyrightCheck:
                runCopyrightCheck(project: project)
            case .kdpFormatting:
                try await runKDPFormatting(project: project, config: config)
            case .export:
                try await runExport(project: project, config: config)
            default:
                break
            }

            project.updatedAt = Date()
            modelContext?.saveOrLog()
        }
    }

    /// Bestimmt den ersten tatsächlich noch nötigen Schritt aus den gespeicherten
    /// Artefakten. Ein beim Export gestopptes Buch springt dadurch nicht erneut durch
    /// Planung und Rohfassung; frühe, unvollständige Projekte bleiben unverändert.
    private func executionPhases(for project: Project) -> [PipelinePhase] {
        let chapters = sortedChapters(project)
        guard !chapters.isEmpty else { return PipelinePhase.executionOrder }

        let hasUsableFinalManuscript = chapters.allSatisfy { chapter in
            let text = (chapter.finalText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty
                && AutonomousContentQuality.hasCompleteSentenceEnding(text)
                && !AutonomousContentQuality.containsMetaRequest(text)
                && !AutonomousContentQuality.containsPromptArtifacts(text)
                && !PublicContentGuard.disclosureViolation(in: text)
        }
        if hasUsableFinalManuscript {
            for chapter in chapters { chapter.status = .finalized }
            if let profile = project.bookProfile,
               !needsKDPMetadata(project: project, profile: profile) {
                return [.export]
            }
            return [.copyrightCheck, .kdpFormatting, .export]
        }

        let hasRevisedManuscript = chapters.allSatisfy {
            !($0.revisedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if hasRevisedManuscript {
            return [.proofreading, .copyrightCheck, .kdpFormatting, .export]
        }

        let hasCompleteDraft = chapters.allSatisfy { chapter in
            if !(chapter.draftText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            let scenes = sortedScenes(chapter)
            return !scenes.isEmpty && scenes.allSatisfy { isSceneWritten($0) }
        }
        if hasCompleteDraft {
            return [.chapterRevision, .manuscriptRevision, .proofreading,
                    .copyrightCheck, .kdpFormatting, .export]
        }

        return PipelinePhase.executionOrder
    }

    private func run(project: Project, config: ProviderConfiguration) async {
        var consecutiveTransientFailures = 0
        var readinessRetries = 0
        while !Task.isCancelled {
            do {
                try await executeAllPhases(project: project, config: config)
                try PublicationReadiness.validateForCompletion(project: project)
                project.status = .completed
                progress = 1.0
                currentAgent = "Abgeschlossen"
                lastError = nil
                ProductionIncidentStore.clear()
                finish()
                return
            } catch is CancellationError {
                handleStop(project: project)
                return
            } catch {
                if stopMode != .none {
                    handleStop(project: project)
                    return
                }
                if let job = currentJob, job.status == .running { failJob(job, error: error) }

                // Buch ist fertig geschrieben, erfüllt aber die Qualitäts-Endabnahme noch
                // nicht: weiter reparieren, bis die Freigabe besteht oder der Benutzer stoppt.
                if Self.isReadinessShortfall(error) {
                    readinessRetries += 1
                    let remaining = (error as? AIError)?.errorDescription ?? error.localizedDescription
                    ProductionIncidentStore.record(remaining)
                    // Pro Selbstkorrektur-Runde darf das Repair-Audit einmal neu ran.
                    readinessRepairAuditDone = false
                    project.status = .export
                    lastError = "Qualität noch nicht freigegeben – automatische Korrektur läuft weiter (Runde \(readinessRetries))."
                    currentAgent = "Selbstkorrektur Runde \(readinessRetries) läuft weiter …"
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(Self.readinessRetryDelaySeconds * 1_000_000_000)
                        )
                    } catch {
                        handleStop(project: project)
                        return
                    }
                    continue
                }


                if ProductionStabilityPolicy.shouldResumeInterruptedBook(after: error) {
                    consecutiveTransientFailures += 1
                    project.status = .paused
                    let delay = ProductionStabilityPolicy.retryDelay(
                        forConsecutiveFailures: consecutiveTransientFailures
                    )
                    let reason = (error as? AIError)?.errorDescription ?? error.localizedDescription
                    lastError = "Vorübergehende Unterbrechung: \(reason) Die Produktion setzt dieses Buch automatisch fort."
                    ProductionIncidentStore.record(lastError ?? reason)
                    currentAgent = "Verbindung unterbrochen – automatische Fortsetzung in \(ProductionStabilityPolicy.formatRetryDelay(delay))"
                    modelContext?.saveOrLog()
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        handleStop(project: project)
                        return
                    }
                    continue
                }

                let aiError = error as? AIError
                var message = aiError?.errorDescription ?? error.localizedDescription
                if let suggestion = aiError?.recoverySuggestion { message += " – \(suggestion)" }
                lastError = message
                ProductionIncidentStore.record(message)
                project.status = .failed
                finish()
                return
            }
        }
        handleStop(project: project)
    }

    private func handleStop(project: Project) {
        if let job = currentJob, job.status == .running {
            job.status = .paused
            job.endTime = Date()
            currentJob = nil
        }
        project.status = (stopMode == .cancel) ? .failed : .paused
        lastError = nil
        currentAgent = (stopMode == .cancel) ? "Abgebrochen" : "Pausiert"
        finish()
    }

    private func finish() {
        isRunning = false
        // Reparaturuhr beenden (Produktion terminal: fertig, pausiert oder gestoppt).
        repairStartedAt = nil
        repairElapsed = ""
        repairEtaText = ""
        repairIssuesTotal = 0
        repairIssuesRemaining = 0
        readinessRepairAuditDone = false
        heartbeatTask?.cancel()
        heartbeatTask = nil
        markProjectInactive(currentProject)
        if parentOrchestrator == nil {
            activeProjectIDs = []
            workerStatuses = []
        }
        ProductionSleepManager.shared.release(for: self)
        modelContext?.saveOrLog()
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if let job = self.currentJob, job.status == .running {
                    job.lastHeartbeat = Date()
                }
                self.updateProductionTiming()
            }
        }
    }

    // MARK: - Job-Verwaltung

    private func beginJob(agent: String, phase: PipelinePhase, project: Project,
                          chapter: Int? = nil, scene: Int? = nil) -> PipelineJob {
        let job = PipelineJob(agentName: agent, phase: phase, chapterNumber: chapter, sceneNumber: scene)
        job.status = .running
        job.startTime = Date()
        job.lastHeartbeat = Date()
        if project.pipelineJobs == nil { project.pipelineJobs = [] }
        project.pipelineJobs?.append(job)
        modelContext?.insert(job)
        currentJob = job
        currentAgent = agent
        return job
    }

    private func completeJob(_ job: PipelineJob, result: String? = nil, tokens: Int = 0) {
        job.status = .completed
        job.endTime = Date()
        job.result = result.map { String($0.prefix(2000)) }
        job.tokenUsage = tokens
        currentJob = nil
    }

    private func failJob(_ job: PipelineJob, error: Error) {
        if error is CancellationError {
            job.status = .paused
            job.endTime = Date()
            job.result = "Produktion pausiert; gespeicherter Stand bleibt erhalten."
            currentJob = nil
            return
        }
        job.status = .failed
        job.endTime = Date()
        job.errorCount += 1
        job.result = error.localizedDescription
        let location = [
            job.chapterNumber.map { "Kapitel \($0)" },
            job.sceneNumber.map { "Szene \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")
        ProductionIncidentStore.record(
            "\(job.agentName)\(location.isEmpty ? "" : " (\(location))"): \(error.localizedDescription)"
        )
        currentJob = nil
    }

    // MARK: - LLM-Aufruf mit Nutzungsanzeige

    private func generate(prompt: String, system: String, maxTokens: Int,
                          temperature: Double, config: ProviderConfiguration,
                          creative: Bool = false) async throws -> GenerationResponse {
        try Task.checkCancellation()

        let fallbackModel = config.defaultModel ?? config.provider.suggestedModels.first ?? ""
        // Kreative Prosa-Schritte nutzen das (stärkere) Autoren-Modell; Hilfsschritte
        // bleiben auf dem schnellen Standardmodell.
        let model = creative ? resolveWritingModel(for: config, fallback: fallbackModel) : fallbackModel

        func run(_ chosen: String) async throws -> GenerationResponse {
            let request = GenerationRequest(
                prompt: prompt, systemPrompt: system, model: chosen,
                provider: config.provider, maxTokens: maxTokens, temperature: temperature
            )
            let response = try await gateway.generateText(request: request, configuration: config)
            if let tokens = response.tokensUsed {
                recordTokenUsage(tokens, model: chosen)
            }
            return response
        }

        do {
            return try await run(model)
        } catch AIError.modelUnavailable where model != fallbackModel {
            // Starkes Autoren-Modell nicht verfügbar → sicher auf Standardmodell ausweichen,
            // damit die Produktion nie an der Modellwahl scheitert.
            return try await run(fallbackModel)
        }
    }

    /// Wählt das (stärkere) Autoren-Modell für kreative Prosa-Schritte. Nur für
    /// Ollama Cloud; sonst das Standardmodell. „__standard__" = bewusst Standardmodell;
    /// leer = empfohlenes Autoren-Modell. Untaugliche Wahl fällt auf den Default zurück.
    private func resolveWritingModel(for config: ProviderConfiguration, fallback: String) -> String {
        guard config.provider == .ollamaCloud else { return fallback }
        let stored = UserDefaults.standard.string(forKey: OllamaCloudModelCatalog.writingModelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Leer = Qualitätsstandard. "__standard__" ist der bewusst gewählte Schnellmodus.
        if stored.isEmpty { return OllamaCloudModelCatalog.recommendedWritingModel }
        if stored == "__standard__" { return fallback }
        return OllamaCloudModelCatalog.isUsefulForLongFormCloudModel(stored) ? stored : fallback
    }

    /// Bucht Token-/Kostenverbrauch und meldet ihn im Parallelmodus zusätzlich an
    /// den Haupt-Orchestrator, dessen Werte die UI beobachtet. Ohne dieses
    /// Hochreichen zeigte die Kostenanzeige bei parallelen Büchern immer 0.
    private func recordTokenUsage(_ tokens: Int, model: String) {
        guard tokens > 0 else { return }
        let cost = ModelPricing.estimatedCost(model: model, tokens: tokens)
        totalTokensUsed += tokens
        estimatedCostUSD += cost
        if let parent = parentOrchestrator {
            parent.totalTokensUsed += tokens
            parent.estimatedCostUSD += cost
        }
    }

    /// Führt mehrere unabhängige LLM-Anfragen parallel aus (begrenzte Nebenläufigkeit).
    /// Token-/Kostenschätzung erfolgt nur für die Anzeige; sie begrenzt die Produktion nicht.
    private func runParallelGeneration(
        requests: [GenerationRequest],
        config: ProviderConfiguration,
        onResult: ((Int, Result<GenerationResponse, Error>) -> Void)? = nil
    ) async -> [Int: Result<GenerationResponse, Error>] {
        guard !requests.isEmpty else { return [:] }

        // Lokales Ollama arbeitet seriell am schnellsten; Cloud-APIs vertragen Parallelität.
        let maxConcurrent = config.provider == .ollamaLocal ? 1 : 3
        var results: [Int: Result<GenerationResponse, Error>] = [:]
        let gateway = self.gateway

        await withTaskGroup(of: (Int, Result<GenerationResponse, Error>).self) { group in
            var nextIndex = 0
            func launchNext() {
                guard nextIndex < requests.count else { return }
                let index = nextIndex
                let request = requests[index]
                nextIndex += 1
                group.addTask {
                    do {
                        let response = try await gateway.generateText(request: request, configuration: config)
                        return (index, .success(response))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            for _ in 0..<min(maxConcurrent, requests.count) { launchNext() }

            for await (index, result) in group {
                results[index] = result
                if case .success(let response) = result, let tokens = response.tokensUsed {
                    recordTokenUsage(tokens, model: requests[index].model)
                }
                onResult?(index, result)

                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    launchNext()
                }
            }
        }
        return results
    }

    private func makeRequest(prompt: String, system: String, maxTokens: Int,
                             temperature: Double, config: ProviderConfiguration) -> GenerationRequest {
        GenerationRequest(
            prompt: prompt,
            systemPrompt: system,
            model: config.defaultModel ?? config.provider.suggestedModels.first ?? "",
            provider: config.provider,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    // MARK: - Phase 1: Eingabevalidierung (lokal, ohne KI)

    private func runInputValidation(project: Project) throws {
        let job = beginJob(agent: AgentName.input, phase: .projectSetup, project: project)

        let validation = InputValidator.validateProject(project)
        guard validation.isValid else {
            let message = validation.errors.joined(separator: "; ")
            failJob(job, error: AIError.systemError(message))
            throw AIError.systemError(message)
        }

        completeJob(job, result: "Projekt validiert: \(project.title) (\(project.genre), \(project.targetPageCount) Seiten)")
    }

    // MARK: - Phase 2: Konzeptentwicklung

    private func runConceptPhase(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile else {
            throw AIError.systemError("Buchprofil fehlt")
        }
        // Bereits erledigt? Sachbücher ohne neues Quellenmanifest müssen beim
        // Fortsetzen trotzdem durch die nachgerüstete Recherchephase laufen.
        let conceptAlreadyComplete = !(profile.logline ?? "").isEmpty
        if conceptAlreadyComplete,
           !project.isNonfiction || !profile.sourceManifest.isEmpty { return }

        project.status = .conceptDevelopment

        if project.isNonfiction && profile.sourceManifest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let researchJob = beginJob(agent: AgentName.research, phase: .conceptDevelopment,
                                       project: project)
            currentAgent = "\(AgentName.research) – Quellen werden geprüft"
            let topicWords = "\(project.title) \(profile.premise)"
                .split(whereSeparator: \.isWhitespace).prefix(45).joined(separator: " ")
            do {
                let bundle = try await NonfictionResearchService.shared.research(
                    query: topicWords, genre: project.genre, language: project.language
                )
                profile.researchQuery = bundle.query
                profile.researchNotes = bundle.promptContext
                profile.sourceManifest = try NonfictionResearchService.encodeManifest(bundle)
                completeJob(researchJob, result: "\(bundle.sources.count) Quellen recherchiert")
                addReport(project: project, area: "Quellenbasis", type: "Recherche",
                          result: "\(bundle.sources.count) nachvollziehbare Quellen gespeichert",
                          severity: .info,
                          recommendation: bundle.hasScholarlySource
                            ? "Quellen vor Veröffentlichung inhaltlich gegenlesen."
                            : "Mindestens eine fachliche Primärquelle ergänzen.")
            } catch {
                failJob(researchJob, error: error)
                addReport(project: project, area: "Quellenbasis", type: "Recherche",
                          result: "Recherche fehlgeschlagen: \(error.localizedDescription)",
                          severity: .error,
                          recommendation: "Recherchephase erneut ausführen; Sachbuch wird ohne Quellen nicht freigegeben.")
                throw error
            }
        }
        if conceptAlreadyComplete { return }
        // Romance-Genres ohne gewählten Sinnlichkeitsgrad nicht „clean" erzeugen – sinnvollen
        // Standard setzen, damit Dark Romance/Liebesroman die Genre-Erwartung (Wärme) einlöst.
        if project.spiceLevel == 0 {
            let g = project.genre.lowercased()
            if g.contains("dark romance") || g.contains("erotik") || g.contains("erotic") || g.contains("spicy") {
                project.spiceLevel = 4
            } else if g.contains("liebes") || g.contains("romance") || g.contains("romantik")
                        || g.contains("new adult") || g.contains("romantasy") {
                project.spiceLevel = 2
            }
        }
        // GENRE-DIREKTIVE: Titel + Genre vorab analysieren und verbindliche, maßgeschneiderte
        // Vorgaben ableiten, die Konzept, Plot, Kapitelplan und jede Szene steuern.
        if profile.genreRules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let briefJob = beginJob(agent: AgentName.concept, phase: .conceptDevelopment, project: project)
            do {
                let briefResponse = try await generate(
                    prompt: PromptFactory.genreBrief(
                        title: project.title, genre: project.genre, subgenre: project.subgenre,
                        tropes: project.tropes, spiceLevel: project.spiceLevel, language: project.language),
                    system: project.isNonfiction
                        ? "Du bist ein Sachbuchlektor. Du leitest Leserproblem, Nutzen, Lernweg und Faktenregeln präzise ab."
                        : "Du bist ein Verlagslektor und Genre-Stratege. Du leitest aus Titel und Genre präzise, verbindliche Schreibvorgaben ab, damit ein Roman zweifelsfrei in seinem Genre landet. Antworte nur mit der Direktive.",
                    maxTokens: 900, temperature: 0.5, config: config, creative: false)
                let brief = briefResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if brief.wordCount >= 20, !AutonomousContentQuality.containsMetaRequest(brief) {
                    profile.genreRules = project.isNonfiction
                        ? "SACHBUCH\n\(brief)\n\(NonfictionSafety.directive(genre: project.genre, premise: profile.premise))"
                        : brief
                }
                completeJob(briefJob, result: "Genre-Direktive aus Titel + Genre abgeleitet", tokens: briefResponse.tokensUsed ?? 0)
            } catch {
                if briefJob.status == .running { failJob(briefJob, error: error) }
                // Nicht produktionskritisch – ohne Direktive weiter mit den Standard-Genre-Regeln.
            }
        }
        if project.isNonfiction && profile.genreRules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.genreRules = "SACHBUCH\n" + NonfictionSafety.directive(
                genre: project.genre, premise: profile.premise
            )
        }
        let job = beginJob(agent: AgentName.concept, phase: .conceptDevelopment, project: project)
        do {
            var lastResponse: GenerationResponse?
            var accepted = false
            for attempt in 1...3 {
                let retryHint = attempt == 1 ? "" : "\n\nWichtig: Der vorige Versuch war leer, zu kurz oder nicht im Format. Liefere jetzt zwingend Prämisse, Thema, Zielgruppe, Logline und ein ausführliches Exposé mit konkretem Konflikt."
                let prompt = PromptFactory.concept(
                    title: project.title, genre: project.genre, subgenre: project.subgenre,
                    language: project.language, style: project.styleProfile,
                    tonality: profile.tonality, audience: profile.targetAudience,
                    perspective: profile.narrativePerspective, tense: profile.tense,
                    pageCount: project.targetPageCount,
                    ideaSeed: profile.premise,
                    tropes: project.tropes, bookSignature: project.styleSignature,
                    sequelContext: project.sequelContext, genreBrief: profile.genreRules,
                    researchContext: profile.researchNotes
                ) + retryHint
                let response = try await generate(
                    prompt: prompt,
                    system: "Du bist ein erfahrener Verlagslektor und entwickelst originelle, tragfähige Buchkonzepte. Antworte direkt mit Buchkonzept, niemals mit Rückfragen.",
                    maxTokens: 2200, temperature: 0.8, config: config, creative: true
                )
                lastResponse = response

                let parsed = ConceptParser.parse(response.text)
                let candidatePremise = parsed.premise.isEmpty ? profile.premise : parsed.premise
                let candidateSynopsis = parsed.synopsis.isEmpty ? response.text : parsed.synopsis
                if candidatePremise.trimmingCharacters(in: .whitespacesAndNewlines).wordCount >= 8,
                   candidateSynopsis.trimmingCharacters(in: .whitespacesAndNewlines).wordCount >= 20,
                   !AutonomousContentQuality.containsMetaRequest(candidateSynopsis) {
                    profile.premise = candidatePremise
                    profile.logline = parsed.logline.isEmpty ? String(response.text.prefix(200)) : parsed.logline
                    profile.synopsis = candidateSynopsis
                    if !parsed.theme.isEmpty { profile.theme = parsed.theme }
                    if profile.targetAudience.isEmpty && !parsed.audience.isEmpty {
                        profile.targetAudience = parsed.audience
                    }
                    accepted = true
                    break
                }
            }

            if accepted, let response = lastResponse {
                completeJob(job, result: response.text, tokens: response.tokensUsed ?? 0)
            } else {
                // Kein verwertbares Konzept trotz Wiederholungen → aus dem Ideenkern
                // ableiten, damit die Produktion weiterläuft. (Provider-Fehler hätten
                // oben bereits geworfen und das Buch pausiert.)
                let seed = profile.premise.trimmingCharacters(in: .whitespacesAndNewlines)
                let base = seed.wordCount >= 8 ? seed : (project.isNonfiction
                    ? "Ein praxisnahes \(project.genre), das ein konkretes Leserproblem schrittweise erklärt und in einen realistischen, umsetzbaren Handlungsplan überführt."
                    : "Ein \(project.genre) um eine Hauptfigur, die ein dringendes Ziel gegen wachsenden Widerstand verfolgt und dabei an eine innere Grenze stößt.")
                if seed.wordCount < 8 { profile.premise = base }
                if (profile.logline ?? "").isEmpty { profile.logline = String(base.prefix(180)) }
                if (profile.synopsis ?? "").isEmpty {
                    profile.synopsis = base + (project.isNonfiction
                        ? " Die Inhalte bauen vom Verständnis über konkrete Anwendung bis zu einem nachhaltigen Umsetzungsplan auf."
                        : " Im Verlauf eskaliert der zentrale Konflikt über mehrere Wendepunkte, bis eine Entscheidung unter höchstem Druck zur emotional befriedigenden Auflösung führt.")
                }
                addReport(project: project, area: "Konzept", type: "Konzeptentwicklung",
                          result: "Kein verwertbares Konzept vom Modell – aus dem Ideenkern abgeleitet",
                          severity: .info, recommendation: "Konzept bei Bedarf im Manuskript verfeinern.")
                completeJob(job, result: profile.synopsis ?? base, tokens: lastResponse?.tokensUsed ?? 0)
            }
        } catch {
            failJob(job, error: error)
            throw error
        }
    }

    // MARK: - Phase 3: Strukturplanung (Plot + Figuren)

    private func runStructurePhase(project: Project, config: ProviderConfiguration) async throws {
        guard let bible = project.storyBible, let profile = project.bookProfile else {
            throw AIError.systemError("Story Bible oder Buchprofil fehlt")
        }
        project.status = .structurePlanning

        if bible.styleRules.isEmpty {
            bible.styleRules = "Stilprofil: \(project.styleProfile). Tonalität: \(profile.tonality). "
                + "Erzählperspektive: \(profile.narrativePerspective), Zeitform: \(profile.tense). "
                + "Sprache: \(project.language)."
        }

        // Plot
        if bible.plotPoints.isEmpty {
            let job = beginJob(agent: AgentName.plot, phase: .structurePlanning, project: project)
            let prompt = PromptFactory.plot(
                title: project.title, genre: project.genre, style: project.styleProfile,
                concept: profile.synopsis ?? profile.premise,
                pageCount: project.targetPageCount,
                chapterCount: estimatedChapterCount(for: project),
                bookSignature: project.styleSignature,
                sequelContext: project.sequelContext, genreBrief: profile.genreRules,
                researchContext: profile.researchNotes
            )
            var plot = ""
            var tokens = 0
            var lastError: Error?
            for attempt in 1...2 {
                let hint = attempt == 1 ? "" : "\n\nDer vorige Versuch war zu kurz oder unbrauchbar. Liefere jetzt einen ausführlichen, zusammenhängenden Plot in klaren Akten."
                do {
                    let response = try await generate(
                        prompt: prompt + hint,
                        system: project.isNonfiction
                            ? "Du bist ein Sachbucharchitekt. Du baust einen schlüssigen, anwendbaren Lernweg ohne erfundene Belege."
                            : "Du bist ein Plot-Architekt für Romane. Du baust schlüssige, spannende Handlungsbögen.",
                        maxTokens: 3500, temperature: 0.7, config: config, creative: true
                    )
                    tokens += response.tokensUsed ?? 0
                    let p = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if p.wordCount > plot.wordCount { plot = p }
                    if p.wordCount >= 80, !AutonomousContentQuality.containsMetaRequest(p) { lastError = nil; break }
                } catch {
                    lastError = error
                    if isFatalProductionError(error) { failJob(job, error: error); throw error }
                }
            }
            if plot.wordCount < 80 || AutonomousContentQuality.containsMetaRequest(plot) {
                // Provider lieferte nichts → pausieren (fortsetzbar). Sonst tragfähiges Grundgerüst.
                if plot.isEmpty, let error = lastError { failJob(job, error: error); throw error }
                plot = fallbackPlot(project: project, profile: profile)
                addReport(project: project, area: "Plot", type: "Strukturplanung",
                          result: "Kein verwertbarer Plot vom Modell – tragfähiges Grundgerüst aus dem Konzept eingesetzt",
                          severity: .info, recommendation: "Plot bei Bedarf im Manuskript verfeinern.")
            }
            bible.plotPoints = plot
            bible.updatedAt = Date()
            completeJob(job, result: plot, tokens: tokens)
        }

        // Figuren
        if !project.isNonfiction, (bible.characters ?? []).isEmpty {
            let job = beginJob(agent: AgentName.character, phase: .structurePlanning, project: project)
            let prompt = PromptFactory.characters(
                title: project.title, genre: project.genre, plot: bible.plotPoints,
                concept: [profile.premise, profile.synopsis ?? ""].filter { !$0.isEmpty }.joined(separator: "\n"),
                sequelContext: project.sequelContext
            )
            var parsed: [ParsedCharacter] = []
            var tokens = 0
            var lastError: Error?
            for attempt in 1...2 {
                let hint = attempt == 1 ? "" : "\n\nDer vorige Versuch war unvollständig. Liefere jetzt zwingend mindestens Protagonist und Antagonist im geforderten FIGUR|-Format."
                do {
                    let response = try await generate(
                        prompt: prompt + hint,
                        system: "Du bist ein Charakter-Entwickler. Du erschaffst vielschichtige, glaubwürdige Figuren.",
                        maxTokens: 3000, temperature: 0.7, config: config
                    )
                    tokens += response.tokensUsed ?? 0
                    let candidate = StructureParser.parseCharacters(response.text)
                    if candidate.count > parsed.count { parsed = candidate }
                    if parsed.count >= 2 { lastError = nil; break }
                } catch {
                    lastError = error
                    if isFatalProductionError(error) { failJob(job, error: error); throw error }
                }
            }
            if parsed.count < 2 {
                if parsed.isEmpty, let error = lastError { failJob(job, error: error); throw error }
                parsed = fallbackCharacters(project: project, profile: profile)
                addReport(project: project, area: "Figuren", type: "Strukturplanung",
                          result: "Kein verwertbares Figurenensemble vom Modell – Grundbesetzung eingesetzt",
                          severity: .info, recommendation: "Figuren in der Story Bible ausarbeiten.")
            }
            if bible.characters == nil { bible.characters = [] }
            let primaryCanon = primaryStoryCanon(project: project)
            let characterNames = parsed.map(\.name)
            for item in parsed {
                let character = CharacterProfile(name: item.name, role: item.role)
                character.age = item.age
                character.occupation = item.occupation
                character.goal = item.goal
                character.fear = item.fear
                character.weakness = item.weakness
                character.speechPattern = item.speech          // unverwechselbare Dialogstimme
                character.relationships = AutonomousContentQuality.groundedRelationships(
                    item.relationships, canon: primaryCanon, characterNames: characterNames,
                    subject: item.name
                )
                // Handlungstatsachen werden ausschließlich aus Buchprofil und Plot abgeleitet.
                // Freie Modellzusätze wie erfundene Fehlgeburten dürfen nicht zum Kanon werden.
                character.importantFacts = item.appearance.isEmpty ? "" : "Äußeres: \(item.appearance)"
                character.storyBible = bible
                bible.characters?.append(character)
                modelContext?.insert(character)
            }
            bible.updatedAt = Date()
            completeJob(job, result: "\(parsed.count) Figuren angelegt", tokens: tokens)
        }
    }

    // MARK: - Phase 4: Kapitelplanung

    private func runChapterPlanning(project: Project, config: ProviderConfiguration) async throws {
        // Bereits geplant? (Fortsetzen) – verhindert auch doppelte Kapitel.
        let existingChapters = sortedChapters(project)
        if !existingChapters.isEmpty {
            if hasUsableExistingChapterPlan(existingChapters) {
                project.status = .chapterPlanning
                return
            }
            resetChapterPlan(for: project)
        }
        guard let bible = project.storyBible, let profile = project.bookProfile else {
            throw AIError.systemError("Story Bible oder Buchprofil fehlt")
        }

        project.status = .chapterPlanning
        let plan = productionPlan(for: project)
        let chapterCount = plan.chapterCount
        let wordsPerChapter = plan.targetWordsPerChapter

        let job = beginJob(agent: AgentName.chapterPlanner, phase: .chapterPlanning, project: project)
        let primaryCanon = primaryStoryCanon(project: project)
        let characterNames = (bible.characters ?? []).map(\.name)
        let prompt = PromptFactory.chapterPlan(
            title: project.title, genre: project.genre, plot: bible.plotPoints,
            chapterCount: chapterCount, wordsPerChapter: wordsPerChapter,
            scenesPerChapter: plan.scenesPerChapter,
            bookSignature: project.styleSignature,
            genreBrief: profile.genreRules,
            canonicalStory: canonicalStoryContext(project: project)
        )
        var planned: [PlannedChapter] = []
        var tokens = 0
        var lastError: Error?
        for attempt in 1...2 {
            let hint = attempt == 1 ? "" : "\n\nDer vorige Versuch war unbrauchbar. Liefere jetzt zwingend \(chapterCount) Kapitel im geforderten KAPITEL|-Format mit konkreten Zielen und Konflikten."
            do {
                let response = try await generate(
                    prompt: prompt + hint,
                    system: project.isNonfiction
                        ? "Du bist ein Sachbuch-Strukturplaner. Du planst einen klaren Lernweg und hältst das Ausgabeformat exakt ein."
                        : "Du bist ein Strukturplaner für Romane. Du hältst dich exakt an das geforderte Ausgabeformat.",
                    maxTokens: min(8_000, max(4_000, chapterCount * 120)),
                    temperature: 0.6, config: config
                )
                tokens += response.tokensUsed ?? 0
                let candidate = StructureParser.parseChapters(response.text)
                for item in candidate {
                    let itemText = "\(item.title)\n\(item.goal)\n\(item.conflict)"
                    let canonClaims = AutonomousContentQuality.unsupportedCanonClaims(
                        in: itemText, canon: primaryCanon, characterNames: characterNames
                    )
                    let genreDrift = AutonomousContentQuality.hasScenePlanGenreDrift(
                        itemText, genre: project.genre, canon: primaryCanon
                    )
                    guard canonClaims.isEmpty, !genreDrift else { continue }
                    if let existing = planned.firstIndex(where: { $0.number == item.number }) {
                        planned[existing] = item
                    } else {
                        planned.append(item)
                    }
                }
                planned.sort { $0.number < $1.number }
                if planned.count >= chapterCount,
                   AutonomousContentQuality.hasUsableChapterPlan(planned) {
                    lastError = nil
                    break
                }
            } catch {
                lastError = error
                if isFatalProductionError(error) { failJob(job, error: error); throw error }
            }
        }
        var usedFallback = false
        if planned.count < chapterCount || !AutonomousContentQuality.hasUsableChapterPlan(planned) {
            // Provider lieferte nichts → pausieren (fortsetzbar).
            if planned.isEmpty, let error = lastError { failJob(job, error: error); throw error }
            // NICHT den ganzen Plan verwerfen (sonst gingen alle echten, kreativen
            // Kapiteltitel verloren und das Buch bekäme generische „Aufbruch N"-Titel).
            // Stattdessen nur die schwachen Einzelfelder reparieren.
            usedFallback = planned.count < max(3, chapterCount / 2)
            planned = Self.repairedChapterPlan(planned, count: chapterCount,
                                               isNonfiction: project.isNonfiction)
        }

        if project.chapters == nil { project.chapters = [] }
        let chapterTargets = targetWordsByChapter(project: project, count: planned.count)
        for (index, item) in planned.enumerated() {
            let chapter = Chapter(
                chapterNumber: item.number,
                title: item.title,
                goal: item.goal,
                targetWordCount: chapterTargets[index]
            )
            chapter.conflict = item.conflict
            chapter.project = project
            project.chapters?.append(chapter)
            modelContext?.insert(chapter)
        }
        if usedFallback {
            addReport(project: project, area: "Kapitelplan", type: "Kapitelplanung",
                      result: "Kein verwertbarer Kapitelplan vom Modell – tragfähiges Gerüst eingesetzt",
                      severity: .info, recommendation: "Kapitelziele bei Bedarf verfeinern.")
        }
        completeJob(job, result: "\(planned.count) Kapitel geplant", tokens: tokens)
    }

    // MARK: - Phase 5: Szenenplanung

    private func runScenePlanning(project: Project, config: ProviderConfiguration) async throws {
        guard let bible = project.storyBible, let profile = project.bookProfile else {
            throw AIError.systemError("Story Bible oder Buchprofil fehlt")
        }
        project.status = .scenePlanning
        let plan = productionPlan(for: project)

        let chapters = sortedChapters(project)
        for chapter in chapters where !hasUsableExistingScenePlan(chapter, expectedCount: plan.scenesPerChapter) {
            resetScenePlan(for: chapter)
        }
        let pending = chapters.filter { ($0.scenes ?? []).isEmpty } // Fortsetzen: nur ungeplante
        guard !pending.isEmpty else { return }
        let primaryCanon = primaryStoryCanon(project: project)
        let characterNames = (bible.characters ?? []).map(\.name)

        // Der Kapitelplan enthält bereits den vollständigen dramaturgischen Bogen. Für Romane
        // zerlegen wir ihn lokal in kausale Beats. Separate Modellaufrufe pro Kapitel führten
        // wiederholt zu vorgezogenen Enthüllungen, erfundenen Fundstücken und Genre-Abdrift.
        if !project.isNonfiction {
            for (index, chapter) in pending.enumerated() {
                let job = beginJob(agent: AgentName.scenePlanner, phase: .scenePlanning,
                                   project: project, chapter: chapter.chapterNumber)
                persistScenePlanResult(
                    .failure(AIError.systemError("Lokaler kanontreuer Szenenplan")),
                    chapter: chapter,
                    job: job,
                    project: project,
                    profile: profile,
                    expectedCount: plan.scenesPerChapter,
                    primaryCanon: primaryCanon,
                    characterNames: characterNames
                )
                currentAgent = "\(AgentName.scenePlanner) – \(index + 1)/\(pending.count) Kapitel geplant"
                updateProgress(phase: .scenePlanning,
                               subProgress: Double(index + 1) / Double(pending.count))
                modelContext?.saveOrLog()
            }
            aggregateLocations(into: bible, chapters: chapters)
            modelContext?.saveOrLog()
            return
        }

        var jobs: [PipelineJob] = []
        var requests: [GenerationRequest] = []
        for chapter in pending {
            jobs.append(beginJob(agent: AgentName.scenePlanner, phase: .scenePlanning,
                                 project: project, chapter: chapter.chapterNumber))
            requests.append(makeRequest(
                prompt: PromptFactory.scenePlan(
                    bookTitle: project.title,
                    chapterNumber: chapter.chapterNumber, chapterTitle: chapter.title,
                    chapterGoal: chapter.goal, chapterConflict: chapter.conflict,
                    perspective: profile.narrativePerspective,
                    plotContext: bible.plotPoints,
                    targetWords: chapter.targetWordCount,
                    scenesPerChapter: plan.scenesPerChapter,
                    // Schlusskapitel: Auszahlung statt erzwungenem Cliffhanger.
                    isFinalChapter: chapter.chapterNumber == chapters.last?.chapterNumber,
                    canonicalStory: canonicalStoryContext(project: project)
                ),
                system: project.isNonfiction
                    ? "Du bist ein Sachbuchredakteur. Du planst nützliche Abschnitte und hältst das Ausgabeformat exakt ein."
                    : "Du bist ein Szenenplaner für Romane. Du hältst dich exakt an das geforderte Ausgabeformat.",
                maxTokens: 1200, temperature: 0.6, config: config
            ))
        }
        currentAgent = "\(AgentName.scenePlanner) – \(pending.count) Kapitel parallel"

        var answered = 0
        _ = await runParallelGeneration(requests: requests, config: config) { index, result in
            self.persistScenePlanResult(
                result,
                chapter: pending[index],
                job: jobs[index],
                project: project,
                profile: profile,
                expectedCount: plan.scenesPerChapter,
                primaryCanon: primaryCanon,
                characterNames: characterNames
            )
            answered += 1
            self.currentAgent = "\(AgentName.scenePlanner) – \(answered)/\(pending.count) Kapitel beantwortet"
            self.updateProgress(phase: .scenePlanning, subProgress: Double(answered) / Double(pending.count))
            self.modelContext?.saveOrLog()
        }
        // Schauplätze aus den Szenenplänen in die Story Bible übernehmen.
        if !project.isNonfiction {
            aggregateLocations(into: bible, chapters: chapters)
        }
        modelContext?.saveOrLog()

        try Task.checkCancellation()
    }

    private func persistScenePlanResult(
        _ result: Result<GenerationResponse, Error>,
        chapter: Chapter,
        job: PipelineJob,
        project: Project,
        profile: BookProfile,
        expectedCount: Int,
        primaryCanon: String,
        characterNames: [String]
    ) {
        var planned: [PlannedScene] = []
        var tokens = 0
        if case .success(let response) = result {
            let canonClaims = AutonomousContentQuality.unsupportedCanonClaims(
                in: response.text, canon: primaryCanon, characterNames: characterNames
            )
            let genreDrift = AutonomousContentQuality.hasScenePlanGenreDrift(
                response.text, genre: project.genre, canon: primaryCanon
            )
            if canonClaims.isEmpty, !genreDrift {
                planned = StructureParser.parseScenes(response.text)
            } else {
                addReport(project: project, area: "Kapitel \(chapter.chapterNumber)",
                          type: "Kanon-Kontinuität",
                          result: genreDrift
                            ? "Szenenplan wegen Genre-Abdrift verworfen."
                            : "Szenenplan mit unbelegtem Kanon verworfen: "
                                + canonClaims.prefix(2).joined(separator: " | "),
                          severity: .warning,
                          recommendation: "Szenen wurden kanontreu automatisch ersetzt.")
            }
            tokens = response.tokensUsed ?? 0
        }

        if planned.count < expectedCount {
            for number in (planned.count + 1)...expectedCount {
                planned.append(syntheticScene(
                    number: number, chapter: chapter,
                    perspective: profile.narrativePerspective,
                    isNonfiction: project.isNonfiction
                ))
            }
        }
        if !AutonomousContentQuality.hasUsableScenePlan(planned, expectedCount: expectedCount) {
            planned = (1...expectedCount).map {
                syntheticScene(number: $0, chapter: chapter,
                               perspective: profile.narrativePerspective,
                               isNonfiction: project.isNonfiction)
            }
            addReport(project: project, area: "Kapitel \(chapter.chapterNumber)", type: "Szenenplan",
                      result: "Modell lieferte keinen verwertbaren Szenenplan – automatisch ergänzt",
                      severity: .info,
                      recommendation: "Szenen dieses Kapitels bei Bedarf im Manuskript verfeinern.")
        }

        if chapter.scenes == nil { chapter.scenes = [] }
        let sceneTargets = variedWordTargets(
            total: chapter.targetWordCount,
            count: planned.count,
            seedKey: "\(project.id.uuidString)|chapter|\(chapter.chapterNumber)|sections",
            spread: project.isNonfiction ? 0.12 : 0.20
        )
        for (index, item) in planned.enumerated() {
            let scene = StoryScene(
                sceneNumber: item.number,
                perspective: item.perspective.isEmpty ? profile.narrativePerspective : item.perspective,
                location: item.location,
                goal: item.goal,
                targetWordCount: sceneTargets[index]
            )
            scene.time = item.time
            scene.obstacle = item.obstacle
            scene.cliffhanger = item.turn
            scene.chapter = chapter
            chapter.scenes?.append(scene)
            modelContext?.insert(scene)
        }
        chapter.status = .scenesPlanned
        completeJob(job, result: "\(planned.count) Szenen geplant", tokens: tokens)
    }

    /// Garantiert verwertbare, kapitelspezifische Ersatz-Szene (besteht die
    /// Qualitäts-Gates und gibt dem Draft Writer echte dramaturgische Richtung).
    private func syntheticScene(number: Int, chapter: Chapter, perspective: String,
                                isNonfiction: Bool = false) -> PlannedScene {
        let title = chapter.title.isEmpty ? "diesem Kapitel" : chapter.title
        if isNonfiction {
            let goal = chapter.goal.isEmpty ? "ein konkretes Lernziel erreichen" : chapter.goal
            let obstacle = chapter.conflict.isEmpty
                ? "ein typisches Verständnis- oder Umsetzungshindernis"
                : chapter.conflict
            let functions = ["Grundlage verständlich erklären", "Methode an einem Beispiel zeigen",
                             "Leser zur praktischen Anwendung führen", "Fehler mit einer Checkliste vermeiden"]
            let function = functions[(number - 1) % functions.count]
            return PlannedScene(number: number, perspective: "Leser", location: function,
                                time: "Schritt \(number)",
                                goal: "In \(title) \(goal), indem wir \(function.lowercased()).",
                                obstacle: "\(obstacle) wird konkret und ohne Abkürzung bearbeitet.",
                                turn: "Der Leser erhält eine konkrete Anwendung oder einen nächsten Schritt.")
        }
        return AutonomousContentQuality.safeFictionScene(
            number: number,
            chapterTitle: title,
            chapterGoal: chapter.goal,
            chapterConflict: chapter.conflict,
            perspective: perspective
        )
    }

    /// Nur diese Fehler beenden bzw. pausieren die Produktion. Alles andere
    /// (Inhaltsschwäche, einzelne generische Antworten) wird durch Retry/Fallback
    /// aufgefangen, damit ein Buch zuverlässig fertig wird.
    private func isFatalProductionError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        guard let aiError = error as? AIError else { return false }
        switch aiError {
        case .apiKeyInvalid, .quotaExceeded, .baseURLMissing, .contextTooLong, .fileTooLarge:
            return true
        default:
            return false
        }
    }

    /// Absolute Wachstums-Grenze für JEDE Kapitel-Neufassung (Revision, Proofreading,
    /// Repair, Patch): Ein Kapitel, das bereits über der Freigabe-Grenze liegt
    /// (targetWordCount × maximumChapterWordRatio), darf durch keinen Umschreibe-
    /// Schritt weiter wachsen – nur gleich lang bleiben oder kürzer werden.
    /// Relative Deckel (z.B. +15 % je Runde) komponieren sich sonst über die
    /// Selbstkorrektur-Runden (beobachtet: 1,53× → 1,88× des Ziels).
    private func withinGrowthCeiling(_ candidate: String, source: String, chapter: Chapter) -> Bool {
        guard chapter.targetWordCount > 0 else { return true }
        let ceiling = max(source.wordCount,
                          Int(Double(chapter.targetWordCount) * PublicationReadiness.maximumChapterWordRatio))
        return candidate.wordCount <= ceiling
    }

    /// Klar markierter Platzhaltertext, falls eine Szene trotz Wiederholungen nicht
    /// generiert werden kann – das Buch wird trotzdem komplett und der Nutzer kann
    /// die Szene gezielt neu erzeugen.
    private func fallbackSceneText(chapter: Chapter, scene: StoryScene) -> String {
        let goal = scene.goal.isEmpty ? chapter.goal : scene.goal
        var parts = ["[Diese Szene muss noch ausgeschrieben werden – bitte im Manuskript neu erzeugen.]",
                     "Geplanter Inhalt: \(goal)"]
        if !scene.obstacle.isEmpty { parts.append("Hindernis: \(scene.obstacle)") }
        if !scene.cliffhanger.isEmpty { parts.append("Wendung: \(scene.cliffhanger)") }
        return parts.joined(separator: "\n\n")
    }

    /// Tragfähiger Ersatz-Plot aus dem bereits vorhandenen Konzept, falls der
    /// Plot-Architekt keinen verwertbaren Plot liefert.
    private func fallbackPlot(project: Project, profile: BookProfile) -> String {
        let base = (profile.synopsis?.isEmpty == false ? profile.synopsis! : profile.premise)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if project.isNonfiction {
            let seed = base.isEmpty
                ? "Das Buch löst ein konkretes Problem der Zielgruppe mit einem nachvollziehbaren Lernweg."
                : base
            return """
            SACHBUCH-ARCHITEKTUR
            AUSGANGSLAGE UND LESERPROBLEM: \(seed)
            TEIL 1 – ORIENTIERUNG: Begriffe, Ausgangslage, Grenzen und realistisches Ziel klären.
            TEIL 2 – METHODE: Grundlagen schrittweise erklären, an Beispielen demonstrieren und einüben.
            TEIL 3 – ANWENDUNG: typische Hindernisse bearbeiten, Transfer sichern und einen konkreten Umsetzungsplan erstellen.
            Jedes Kapitel liefert Lernziel, Beispiel, Anwendung und Zusammenfassung. Unbelegte aktuelle Behauptungen werden mit [QUELLE PRÜFEN] markiert.
            """
        }
        let seed = base.isEmpty ? "Die Hauptfigur verfolgt ein dringendes Ziel und stößt auf wachsenden Widerstand." : base
        return """
        AUSGANGSLAGE: \(seed)

        AKT 1 – Aufbruch: Die Hauptfigur wird aus ihrem Alltag gerissen; ein auslösendes Ereignis macht ein Zurück unmöglich und etabliert den zentralen Konflikt.
        AKT 2 – Eskalation: Die Komplikationen verschärfen sich, Teilerfolge wechseln mit Rückschlägen, eine Mittelpunkt-Umkehr rahmt alles neu, der Einsatz steigt bis zum Tiefpunkt.
        AKT 3 – Auflösung: Die Hauptfigur trifft eine Entscheidung unter höchstem Druck, stellt sich der finalen Konfrontation; der zentrale Konflikt wird emotional befriedigend aufgelöst.

        Zentrale dramatische Frage: Gelingt es der Hauptfigur, ihr Ziel zu erreichen, ohne das zu verlieren, was ihr am wichtigsten ist?
        """
    }

    /// Minimal-Figurenensemble (Protagonist + Gegenspieler), falls die
    /// Figurenplanung scheitert – hält die Produktion am Laufen.
    private func fallbackCharacters(project: Project, profile: BookProfile) -> [ParsedCharacter] {
        [
            ParsedCharacter(name: "Hauptfigur", role: "Protagonist:in", age: "", occupation: "",
                            goal: "Das zentrale Ziel der Geschichte gegen wachsenden Widerstand erreichen.",
                            fear: "Zu scheitern und das Wichtigste zu verlieren.",
                            weakness: "Ein blinder Fleck, der die Lage immer wieder verschärft."),
            ParsedCharacter(name: "Gegenspieler:in", role: "Antagonist:in", age: "", occupation: "",
                            goal: "Die Hauptfigur an ihrem Ziel hindern.",
                            fear: "Kontrollverlust.",
                            weakness: "Selbstüberschätzung.")
        ]
    }

    /// Tragfähiger Ersatz-Kapitelplan, falls der Strukturplaner keine verwertbaren
    /// Kapitel liefert. Erzeugt konkrete (nicht-generische) Ziele/Konflikte.
    /// Repariert einen größtenteils brauchbaren Kapitelplan, statt ihn komplett zu
    /// verwerfen. Echte, kreative Kapiteltitel des Modells bleiben erhalten; nur
    /// generische Titel oder zu dünne Ziele/Konflikte werden ersetzt. So bekommen
    /// Bücher echte Kapiteltitel statt durchgehend „Aufbruch N".
    nonisolated static func repairedChapterPlan(_ planned: [PlannedChapter], count: Int,
                                                isNonfiction: Bool = false) -> [PlannedChapter] {
        let n = max(3, count)
        return (1...n).map { i in
            let phase: String
            if isNonfiction {
                switch Double(i) / Double(n) {
                case ..<0.25: phase = "Orientierung"
                case ..<0.5: phase = "Grundlagen"
                case ..<0.75: phase = "Anwendung"
                default: phase = "Transfer"
                }
            } else {
                switch Double(i) / Double(n) {
                case ..<0.25: phase = "Aufbruch"
                case ..<0.5: phase = "Eskalation"
                case ..<0.75: phase = "Krise"
                default: phase = "Auflösung"
                }
            }
            let existing = planned.first { $0.number == i }
                ?? (planned.indices.contains(i - 1) ? planned[i - 1] : nil)
            let rawTitle = existing?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawGoal = existing?.goal.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawConflict = existing?.conflict.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = (!rawTitle.isEmpty && !AutonomousContentQuality.isGenericPlaceholder(rawTitle))
                ? rawTitle : "\(phase) \(i)"
            let goal = (rawGoal.wordCount >= 5 && !AutonomousContentQuality.isGenericPlaceholder(rawGoal))
                ? rawGoal
                : (isNonfiction
                    ? "Vermittle in der Phase \(phase) ein konkretes Lernziel und führe es in eine praktische Anwendung."
                    : "Treibe den Hauptkonflikt in der \(phase)-Phase durch eine eigenständige Eskalation spürbar voran.")
            let conflict = rawConflict.wordCount >= 3
                ? rawConflict : (isNonfiction
                    ? "Ein typisches Verständnis- oder Umsetzungshindernis des Lesers wird konkret gelöst."
                    : "Ein konkretes Hindernis stellt sich dem Ziel dieses Kapitels entgegen.")
            return PlannedChapter(number: i, title: title, goal: goal, conflict: conflict)
        }
    }

    private func fallbackChapters(count: Int, project: Project) -> [PlannedChapter] {
        let n = max(3, count)
        return (1...n).map { i in
            let phase: String
            switch Double(i) / Double(n) {
            case ..<0.25: phase = "Aufbruch"
            case ..<0.5: phase = "Eskalation"
            case ..<0.75: phase = "Krise"
            default: phase = "Auflösung"
            }
            return PlannedChapter(
                number: i,
                title: "\(phase) \(i)",
                goal: "Treibe den Hauptkonflikt in der \(phase)-Phase durch eine eigenständige Eskalation spürbar voran.",
                conflict: "Ein konkretes Hindernis stellt sich dem Ziel dieses Kapitels entgegen."
            )
        }
    }

    /// Tragfähige Ersatz-Buchidee, falls das Modell nach 3 Versuchen keine liefert –
    /// damit die Dauerproduktion NIE abbricht. Variiert über den Index, um
    /// Wiederholungen zu vermeiden.
    private func fallbackIdea(genre: String, index: Int) -> ParsedIdea {
        if BookContentType.infer(from: genre) == .nonfiction {
            let topics = [
                ("Kleine Schritte, die bleiben", "LESERPROBLEM: Gute Vorsätze scheitern an zu großen Veränderungen. NUTZENVERSPRECHEN: Der Leser entwickelt eine realistische Alltagsroutine. METHODE: kleine Auslöser, einfache Schritte und wöchentliche Reflexion."),
                ("Klar entscheiden im Alltag", "LESERPROBLEM: Zu viele Optionen führen zu Aufschub und mentaler Last. NUTZENVERSPRECHEN: Der Leser trifft alltägliche Entscheidungen strukturierter. METHODE: Prioritäten, Entscheidungskriterien und praktische Checklisten."),
                ("Weniger planen, mehr schaffen", "LESERPROBLEM: Komplizierte Planungssysteme werden selbst zur Belastung. NUTZENVERSPRECHEN: Der Leser baut ein schlankes Arbeitssystem auf. METHODE: Aufgaben begrenzen, Fokuszeiten und regelmäßiges Aussortieren."),
                ("Gespräche, die weiterführen", "LESERPROBLEM: Schwierige Gespräche enden oft in Rechtfertigung oder Rückzug. NUTZENVERSPRECHEN: Der Leser bereitet klare und respektvolle Gespräche vor. METHODE: Beobachtung, Anliegen, Zuhören und konkrete Vereinbarung.")
            ]
            let item = topics[abs(index) % topics.count]
            return ParsedIdea(title: item.0, genre: genre, premise: item.1)
        }
        let titles = [
            "Honig auf der Klinge", "Drei Winter, die es nie gab", "Was du im Dunkeln versprochen hast",
            "Sie log beim Frühstück", "Das letzte Streichholz", "Ich habe dich erfunden",
            "Zähl die Narben, nicht die Jahre", "Der Geruch von Übermorgen", "Wer hat das Licht gelöscht?",
            "Das Summen, das er mir verschwieg"
        ]
        let premises = [
            "Eine Frau kehrt nach Jahren in ihre Heimatstadt zurück und stößt auf ein Geheimnis, das ihre Familie lange verschwiegen hat, und muss entscheiden, ob die Wahrheit alles zerstört, was sie noch hat.",
            "Als ein unerwartetes Erbe sein altes Leben auf den Kopf stellt, muss ein Mann zwischen dem sicheren Weg und einer riskanten zweiten Chance auf Liebe wählen, bevor die Frist abläuft.",
            "Zwei Fremde teilen sich durch einen Zufall eine Wohnung und merken zu spät, dass ihre Vergangenheiten auf eine Weise verbunden sind, die beide nicht loslässt.",
            "Eine Spurensuche nach einem verschwundenen Angehörigen führt eine junge Frau in ein Netz aus alten Lügen, in dem jeder Verbündete auch ein Verdächtiger sein könnte."
        ]
        // Titel wählen, der NOCH NICHT vergeben ist.
        //
        // Vorher stand hier titles[index % titles.count]. Der Index ist die Zahl der in
        // DIESEM Lauf fertigen Bücher – bei jedem Neustart der Dauerproduktion steht er
        // wieder auf 0, und es kam immer derselbe Titel heraus. Genau das war zu
        // beobachten: mehrere Bücher mit identischem Notfall-Titel.
        //
        // Jetzt entscheidet der BESTAND: schon benutzte Titel werden übersprungen. Sind
        // alle vergeben, sorgt eine Jahreszahl-freie Variante für Eindeutigkeit, ohne
        // dass „Titel 2" entsteht.
        // Vergebene Titel aus ZWEI Quellen: den Projekten in der Datenbank UND den
        // Ordnernamen im Ausgabeverzeichnis. Nur die Datenbank zu prüfen reicht nicht –
        // dort stehen bereits ausgelieferte Bücher oft nicht mehr, im Ordner aber schon.
        // Genau deshalb entstand ein zweites „Honig auf der Klinge", obwohl das Buch
        // längst auf der Platte lag.
        var vergeben = persistedUsedTitles()
        for p in existingProjects() {
            vergeben.insert(p.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        // Zusätzlich der eingestellte Ausgabeordner – er zeigt, was tatsächlich schon
        // ausgeliefert wurde. Steht dort nichts (frisch umgestellt), schadet es nicht.
        if let wurzel = try? ExportEngine.exportRootDirectory(),
           let inhalt = try? FileManager.default.contentsOfDirectory(atPath: wurzel.path) {
            for name in inhalt where !name.hasPrefix(".") {
                let ohneEndung = (name as NSString).deletingPathExtension
                vergeben.insert(ohneEndung.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
        let frei = titles.filter { !vergeben.contains($0.lowercased()) }
        let base: String
        if let ungenutzt = frei.first {
            base = ungenutzt
        } else {
            // Alle zehn verbraucht: aus zwei Bausteinen einen neuen Titel bilden,
            // statt eine Nummer anzuhängen.
            let anfaenge = ["Was", "Wer", "Wie", "Bevor", "Solange", "Niemand", "Keiner"]
            let enden = ["du mir verschwiegen hast", "wir nie ausgesprochen haben",
                         "im Nebel zurückblieb", "am Ende übrig war",
                         "hinter der letzten Tür lag", "sie nie zugeben würde"]
            let a = anfaenge[abs(index) % anfaenge.count]
            let e = enden[abs(index / anfaenge.count) % enden.count]
            base = "\(a) \(e)"
        }
        let premise = premises[abs(index) % premises.count]
        return ParsedIdea(title: base, genre: genre, premise: premise)
    }

    /// Sammelt alle Schauplätze aus den Szenenplänen und legt sie (einmalig)
    /// als Orte in der Story Bible an – inklusive Kapitelbezug.
    private func aggregateLocations(into bible: StoryBible, chapters: [Chapter]) {
        if bible.locations == nil { bible.locations = [] }
        var known = Set((bible.locations ?? []).map { $0.name.lowercased() })

        for chapter in chapters {
            for scene in sortedScenes(chapter) {
                let name = scene.location.trimmingCharacters(in: .whitespaces)
                guard name.count > 1 else { continue }
                let key = name.lowercased()
                let chapterRef = "\(chapter.chapterNumber)"

                if known.contains(key) {
                    if let existing = bible.locations?.first(where: { $0.name.lowercased() == key }) {
                        let refs = existing.relevantChapters
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                        if !refs.contains(chapterRef) {
                            existing.relevantChapters = existing.relevantChapters.isEmpty
                                ? chapterRef
                                : existing.relevantChapters + ", " + chapterRef
                        }
                    }
                    continue
                }

                known.insert(key)
                let location = LocationProfile(name: name, type: "Schauplatz", locationDescription: "")
                location.relevantChapters = chapterRef
                location.storyBible = bible
                bible.locations?.append(location)
                modelContext?.insert(location)
            }
        }
        bible.updatedAt = Date()
    }

    // MARK: - Phase 6: Rohfassung (Szene für Szene, mit Kontinuität)

    private func runDrafting(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile, let bible = project.storyBible else {
            throw AIError.systemError("Buchprofil oder Story Bible fehlt")
        }
        project.status = .drafting

        let chapters = sortedChapters(project)
        guard !chapters.isEmpty else {
            throw AIError.systemError("Keine Kapitel zum Schreiben vorhanden")
        }

        let allScenes = chapters.flatMap { sortedScenes($0) }
        totalScenes = allScenes.count
        completedScenes = allScenes.filter { isSceneWritten($0) }.count

        // Kontinuität wird beim Durchlaufen in Reihenfolge aufgebaut. Eine globale
        // Vorbefüllung mit allen vorhandenen Zusammenfassungen würde beim Reparieren
        // früher Szenen versehentlich Informationen aus späteren Kapiteln verraten.
        var storySoFar: [String] = []
        var previousSceneText: String?
        // Langstrecken-Gedächtnis: verdichtete Zusammenfassung jedes abgeschlossenen
        // Kapitels – verhindert Wiederholungen über hunderte Seiten.
        var chapterDigests: [String] = []
        var priorProseTexts: [String] = []

        let charactersSummary = compactCharacterSummary(bible)
        let primaryCanon = primaryStoryCanon(project: project)
        let characterNames = (bible.characters ?? []).map(\.name)
        let catalogAvoidance = StoryMemory.makeLanguageAvoidanceBrief(
            projects: existingProjects(), excluding: project.id
        )

        for (chapterIndex, chapter) in chapters.enumerated() {
            currentChapter = chapter.chapterNumber
            let scenes = sortedScenes(chapter)

            for (sceneIndex, scene) in scenes.enumerated() {
                try Task.checkCancellation()
                if isSceneWritten(scene), let existingText = scene.text {
                    let collisions = AutonomousContentQuality.repeatedSentenceCollisions(
                        candidate: existingText,
                        priorTexts: priorProseTexts
                    )
                    if collisions.isEmpty {
                        previousSceneText = existingText
                        priorProseTexts.append(existingText)
                        if let summary = scene.summary, !summary.isEmpty {
                            storySoFar.append(
                                "Kap. \(chapter.chapterNumber), Szene \(scene.sceneNumber): \(summary)"
                            )
                        }
                        continue
                    }
                }
                if (scene.text ?? "").isEmpty == false {
                    scene.text = nil
                    scene.summary = nil
                    scene.status = .planned
                }

                currentScene = scene.sceneNumber
                scene.status = .writing
                let sceneStart = Date()

                let isFirstScene = chapterIndex == 0 && sceneIndex == 0
                let isFinalScene = chapterIndex == chapters.count - 1 && sceneIndex == scenes.count - 1
                let previousEnding = previousSceneText.map { String($0.suffix(600)) } ?? ""

                // Position im Buch + Ziel des Folgekapitels: gibt jeder Szene ihren Platz im
                // Spannungsbogen (gegen die monotone Mitte) und lässt Kapitelenden aufs
                // nächste Kapitel hinführen. Fürs Finale zusätzlich das wörtliche
                // Eröffnungsbild, damit sich der Kreis wirklich schließen kann.
                var positionParts: [String] = []
                let percent = Int((Double(chapterIndex + 1) / Double(max(chapters.count, 1))) * 100)
                positionParts.append("POSITION IM BUCH: Kapitel \(chapter.chapterNumber) von \(chapters.count) (ca. \(percent)%). Spannung und emotionale Einsätze müssen gegenüber früheren Kapiteln spürbar STEIGEN, nicht stagnieren.")
                // Amazon-Leseprobe = die ersten ~10% des Buches: Hier entscheidet sich der Kauf.
                if percent <= 10 {
                    positionParts.append("LESEPROBE-BEREICH: Dieses Kapitel liegt in der Amazon-Leseprobe (Blick ins Buch) – maximaler Sog, keine Längen, keine Rückblenden, kein Welt-Erklären. Jede Seite muss zum Kauf führen.")
                }
                if isFirstScene {
                    let planningText = "\(chapter.goal) \(chapter.conflict) \(scene.goal) \(scene.obstacle)"
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                        .lowercased()
                    let allowedCharacters = (bible.characters ?? []).map(\.name).filter { name in
                        let normalized = name.folding(
                            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                        ).lowercased()
                        let firstName = normalized.split(separator: " ").first.map(String.init) ?? normalized
                        return planningText.contains(normalized) || planningText.contains(firstName)
                    }
                    positionParts.append(
                        "FIGURENEINSATZ DER ERSTEN SZENE: Auftreten dürfen ausschließlich: "
                        + (allowedCharacters.isEmpty ? "die Perspektivfigur" : allowedCharacters.joined(separator: ", "))
                        + ". Keine weitere benannte Figur zeigen, beobachten lassen, ankündigen oder als Silhouette einführen."
                    )
                }
                // Romance-Kernversprechen: die Beziehung eskaliert MESSBAR über das Buch.
                if AutonomousContentQuality.isRomanceGenre(project.genre) {
                    let heat = AutonomousContentQuality.romanceHeatTarget(chapterIndex: chapterIndex, chapterCount: chapters.count)
                    positionParts.append("BEZIEHUNGSTEMPERATUR: In diesem Kapitel ca. Stufe \(heat)/10 (Nähe/Anziehung/Spannung zwischen den Hauptfiguren) – spürbar mehr als in früheren Kapiteln. Die Anziehung ist in JEDER gemeinsamen Szene präsent (Blicke, Berührung, Subtext), nie kühl oder beiläufig.")
                }
                if sceneIndex == scenes.count - 1, chapterIndex + 1 < chapters.count {
                    let nextGoal = chapters[chapterIndex + 1].goal
                    if !nextGoal.isEmpty {
                        positionParts.append("NÄCHSTES KAPITEL will: \(nextGoal.truncated(to: 220)) – das Kapitelende führt dorthin, ohne es vorwegzunehmen.")
                    }
                }
                if isFinalScene {
                    let openingText = chapters.first.flatMap { sortedScenes($0).first?.text } ?? ""
                    if !openingText.isEmpty {
                        positionParts.append("SO BEGINNT DAS BUCH (nimm EIN Bild oder Motiv daraus am Ende wieder auf):\n„\(String(openingText.prefix(400)))…“")
                    }
                }
                // Im Schlusskapitel: die in den Szenen-Summaries protokollierten offenen Fäden
                // (OFFEN:-Zeilen) einsammeln und zum Schließen vorlegen – gegen
                // „Was wurde eigentlich aus X?"-Rezensionen.
                if chapterIndex == chapters.count - 1 {
                    let openThreads = storySoFar
                        .flatMap { $0.components(separatedBy: .newlines) }
                        .compactMap { line -> String? in
                            guard let r = line.range(of: "OFFEN:") else { return nil }
                            let thread = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                            return (thread.isEmpty || thread == "-" || thread == "–") ? nil : thread
                        }
                    if !openThreads.isEmpty {
                        positionParts.append("NOCH OFFENE FÄDEN (in diesem Kapitel schließen oder ausdrücklich einem Folgeband übergeben):\n"
                            + openThreads.suffix(10).map { "- \($0)" }.joined(separator: "\n"))
                    }
                }
                let sceneArea = "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)"
                let priorQualityFindings = (project.qualityReports ?? [])
                    .filter { !$0.autoFixed && $0.checkedArea == sceneArea }
                    .suffix(4)
                if !priorQualityFindings.isEmpty {
                    let retryGuidance = Array(Set(priorQualityFindings.map(\.recommendation)))
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .sorted()
                    positionParts.append(
                        "VERBINDLICHE KORREKTURREGELN AUS VORHERIGEN VERSUCHEN:\n"
                        + retryGuidance.map { "- \($0)" }.joined(separator: "\n")
                    )
                }
                let positionBlock = positionParts.joined(separator: "\n")

                let job = beginJob(agent: AgentName.draftWriter, phase: .drafting, project: project,
                                   chapter: chapter.chapterNumber, scene: scene.sceneNumber)
                currentAgent = "\(AgentName.draftWriter) – Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)"

                do {
                    // Hierarchischer Kontext: alle bisherigen Kapitel verdichtet
                    // + die letzten Szenen im Detail.
                    var contextParts: [String] = []
                    if !chapterDigests.isEmpty {
                        contextParts.append("BISHERIGE KAPITEL:\n" + chapterDigests.joined(separator: "\n"))
                    }
                    let recentScenes = storySoFar.suffix(6)
                    if !recentScenes.isEmpty {
                        contextParts.append("LETZTE SZENEN IM DETAIL:\n" + recentScenes.joined(separator: "\n"))
                    }
                    let recentContext = contextParts.joined(separator: "\n\n")
                    let allowedDraftContext = [
                        chapter.goal, chapter.conflict, scene.goal, scene.obstacle,
                        scene.cliffhanger, recentContext
                    ].joined(separator: "\n")
                    let normalizedAllowedContext = allowedDraftContext.folding(
                        options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                    ).lowercased()
                    let allowedSceneCharacters = (bible.characters ?? []).map(\.name).filter { name in
                        let normalized = name.folding(
                            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                        ).lowercased()
                        let firstName = normalized.split(separator: " ").first.map(String.init) ?? normalized
                        return normalizedAllowedContext.contains(normalized)
                            || normalizedAllowedContext.contains(firstName)
                    }
                    let sceneCharactersSummary = charactersSummary.components(separatedBy: .newlines)
                        .filter { line in
                            allowedSceneCharacters.contains { line.hasPrefix($0 + " ") }
                        }
                        .joined(separator: "\n")
                    let sceneDraftCanon = draftStoryCanon(characterSummary: sceneCharactersSummary)
                    let alreadyOverused = AutonomousContentQuality.repeatedSentences(
                        inChapters: priorProseTexts,
                        minimumOccurrences: 2,
                        maxResults: 12
                    )
                    let manuscriptAvoidance = alreadyOverused
                        .map { "- \($0)" }
                        .joined(separator: "\n")
                    let basePrompt = PromptFactory.draftScene(
                        language: project.language, style: project.styleProfile,
                        tonality: profile.tonality, perspective: profile.narrativePerspective,
                        tense: profile.tense, genre: project.genre, bookTitle: project.title,
                        chapterNumber: chapter.chapterNumber, chapterTitle: chapter.title,
                        chapterGoal: chapter.goal, sceneNumber: scene.sceneNumber,
                        sceneGoal: scene.goal, sceneLocation: scene.location,
                        sceneTime: scene.time, sceneObstacle: scene.obstacle,
                        sceneTurn: scene.cliffhanger, scenePerspective: scene.perspective,
                        charactersSummary: sceneCharactersSummary,
                        styleRules: bible.styleRules,
                        storySoFar: recentContext,
                        previousSceneEnding: previousEnding,
                        isFirstScene: isFirstScene, isFinalScene: isFinalScene,
                        targetWords: scene.targetWordCount,
                        bookSignature: project.styleSignature,
                        spiceLevel: project.spiceLevel,
                        genreBrief: profile.genreRules,
                        positionBlock: positionBlock,
                        catalogAvoidance: catalogAvoidance,
                        manuscriptAvoidance: manuscriptAvoidance,
                        researchContext: profile.researchNotes,
                        canonicalStory: sceneDraftCanon
                    )
                    let maxTokens = LongFormProductionPlan.draftMaxTokens(forTargetWords: scene.targetWordCount)
                    let minWords = Int(Double(scene.targetWordCount) * 0.75)

                    var sceneText = ""
                    var sceneTokens = 0
                    var sceneFinishReason: String?
                    var lastProviderError: Error?
                    var lastSentenceCollisions: [String] = []
                    var lastClarityPhrases: [String] = []
                    var lastCanonClaims: [String] = []
                    var lastGenreDrift = false
                    var lastUnexpectedCharacters: [String] = []
                    var lastUnexpectedArtifacts: [String] = []
                    var lastStyleTics: [String] = []
                    // Bis zu 3 Schreibversuche. Provider-FATAL-Fehler pausieren das Buch
                    // (fortsetzbar); reine Inhaltsschwäche lässt es NIE scheitern.
                    for attempt in 1...3 {
                        currentAgent = "\(AgentName.draftWriter) – Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber) · Entwurf \(attempt)/3"
                        let collisionHint = lastSentenceCollisions.isEmpty ? "" : "\n\nWÖRTLICH KOLLIDIERENDE SÄTZE AUS DEM VERSUCH (keinen davon erneut verwenden):\n"
                            + lastSentenceCollisions.map { "- \($0)" }.joined(separator: "\n")
                        let clarityHint = lastClarityPhrases.isEmpty ? "" : "\n\nZU VAGE FORMULIERUNGEN AUS DEM VERSUCH (konkret benennen oder streichen):\n"
                            + lastClarityPhrases.map { "- \($0)" }.joined(separator: "\n")
                        let canonHint = lastCanonClaims.isEmpty ? "" : "\n\nNICHT DURCH DEN BUCHKANON BELEGTE VERWANDTSCHAFTEN (nicht erneut behaupten):\n"
                            + lastCanonClaims.map { "- \($0)" }.joined(separator: "\n")
                        let genreHint = lastGenreDrift
                            ? "\n\nGENRE-ABDRIFT: Keine bedrohliche Silhouette, versteckte Beobachtung, Waffe, Einbrecher-, Geister- oder Horrorinszenierung. Schreibe die Begegnung offen, menschlich und passend zum Liebesroman."
                            : ""
                        let planHint = (lastUnexpectedCharacters + lastUnexpectedArtifacts).isEmpty
                            ? ""
                            : "\n\nPLANVERSTOSS: Der vorige Text enthielt eine ungeplante benannte Figur oder ein zusätzliches Fundstück. Verwende ausschließlich Figuren und Elemente aus Szenenziel, Hindernis, Wendung und bisheriger Handlung. Wiederhole keine Namen oder Gegenstände aus verworfenen Versuchen."
                        let styleTicHint = lastStyleTics.isEmpty ? "" : "\n\nSTIL-TICKS AUS DEM VERSUCH (gehäufte Muster, an denen Leser KI-Prosa erkennen – reduziere sie):\n"
                            + lastStyleTics.map { "- \($0)" }.joined(separator: "\n")
                        let hint = attempt == 1 ? "" : (project.isNonfiction
                            ? "\n\nDer vorige Versuch war zu kurz, unvollständig oder erfüllte die geplante Abschnittsfunktion nicht. Schreibe den vollständigen Abschnitt klar und anwendbar mit 85–115 % der Zielwortzahl. Wenn Abschnittstyp oder Take-away Beispiel, Übung, Aufgabe oder Checkliste verlangen, muss dieses Element sichtbar und vollständig enthalten sein. Erfinde keine Belege oder Statistiken."
                            : "\n\nDer vorige Versuch war zu kurz, zu lang, unklar, unbrauchbar oder klang zu schematisch. Schreibe jetzt die vollständige Szene als reinen Fließtext mit 85–115 % der Zielwortzahl, ohne Meta-Kommentare. Jeder Absatz macht Handlung, Absicht oder Folge konkret. Keine Standardfloskeln und kein deutender Zusammenfassungssatz am Absatzende.") + collisionHint + clarityHint + canonHint + genreHint + planHint + styleTicHint
                        do {
                            let response = try await generate(
                                prompt: basePrompt + hint,
                                system: project.isNonfiction
                                    ? "Du bist ein professioneller Sachbuchautor und Fachredakteur. Du schreibst klar, verantwortungsvoll und praktisch."
                                    : "Du bist ein professioneller Romanautor. Du schreibst lebendige, atmosphärische Prosa mit natürlichen Dialogen.",
                                maxTokens: maxTokens, temperature: 0.85, config: config, creative: true
                            )
                            sceneTokens += response.tokensUsed ?? 0
                            let candidateCollisions = AutonomousContentQuality.repeatedSentenceCollisions(
                                candidate: response.text,
                                priorTexts: priorProseTexts
                            )
                            lastSentenceCollisions = candidateCollisions
                            let candidateClarity = AutonomousContentQuality.clarityAssessment(response.text)
                            lastClarityPhrases = candidateClarity.isAcceptable
                                ? []
                                : AutonomousContentQuality.clarityRepairPhrases(in: response.text)
                            lastCanonClaims = AutonomousContentQuality.unsupportedCanonClaims(
                                in: response.text, canon: primaryCanon,
                                characterNames: characterNames
                            )
                            lastGenreDrift = AutonomousContentQuality.hasScenePlanGenreDrift(
                                response.text, genre: project.genre, canon: primaryCanon
                            )
                            lastUnexpectedCharacters = AutonomousContentQuality.unexpectedCharacterNames(
                                in: response.text, allowedContext: allowedDraftContext,
                                characterNames: characterNames
                            )
                            lastUnexpectedArtifacts = AutonomousContentQuality.unexpectedStoryArtifacts(
                                in: response.text, allowedContext: allowedDraftContext
                            )
                            lastStyleTics = project.isNonfiction
                                ? []
                                : AutonomousContentQuality.styleTicViolations(in: response.text)
                            // „Gut" = keine durchgesickerte Anweisung UND nicht maschinell klingend.
                            // Eine schwächere Fassung führt zu einem neuen Versuch (statt sie zu behalten).
                            let candidateGood = !AutonomousContentQuality.containsPromptArtifacts(response.text)
                                && !AutonomousContentQuality.soundsLikeAI(response.text)
                                && !AutonomousContentQuality.isLikelyTruncated(
                                    response.text, finishReason: response.finishReason)
                                && !PublicContentGuard.disclosureViolation(in: response.text)
                                && ContentSafetyFilter.isSafe(response.text)
                                && candidateCollisions.isEmpty
                                && candidateClarity.isAcceptable
                                && lastCanonClaims.isEmpty
                                && !lastGenreDrift
                                && lastUnexpectedCharacters.isEmpty
                                && lastUnexpectedArtifacts.isEmpty
                                && lastStyleTics.isEmpty
                                && (!project.isNonfiction
                                    || AutonomousContentQuality.satisfiesNonfictionSectionContract(
                                        response.text,
                                        sectionKind: scene.location,
                                        takeaway: scene.cliffhanger
                                    ))
                            let currentGood = !sceneText.isEmpty
                                && !AutonomousContentQuality.containsPromptArtifacts(sceneText)
                                && !AutonomousContentQuality.soundsLikeAI(sceneText)
                                && !AutonomousContentQuality.isLikelyTruncated(
                                    sceneText, finishReason: sceneFinishReason)
                                && !PublicContentGuard.disclosureViolation(in: sceneText)
                                && ContentSafetyFilter.isSafe(sceneText)
                                && AutonomousContentQuality.clarityAssessment(sceneText).isAcceptable
                                && AutonomousContentQuality.repeatedSentenceCollisions(
                                    candidate: sceneText,
                                    priorTexts: priorProseTexts
                                ).isEmpty
                                && AutonomousContentQuality.unsupportedCanonClaims(
                                    in: sceneText, canon: primaryCanon,
                                    characterNames: characterNames
                                ).isEmpty
                                && !AutonomousContentQuality.hasScenePlanGenreDrift(
                                    sceneText, genre: project.genre, canon: primaryCanon
                                )
                                && AutonomousContentQuality.unexpectedCharacterNames(
                                    in: sceneText, allowedContext: allowedDraftContext,
                                    characterNames: characterNames
                                ).isEmpty
                                && AutonomousContentQuality.unexpectedStoryArtifacts(
                                    in: sceneText, allowedContext: allowedDraftContext
                                ).isEmpty
                            let candidateDistance = abs(response.text.wordCount - scene.targetWordCount)
                            let currentDistance = abs(sceneText.wordCount - scene.targetWordCount)
                            let candidatePenalty = AutonomousContentQuality.draftQualityPenalty(response.text)
                            let currentPenalty = AutonomousContentQuality.draftQualityPenalty(sceneText)
                            if sceneText.isEmpty
                                || (candidateGood && !currentGood)
                                || (candidateGood == currentGood && candidatePenalty < currentPenalty)
                                || (candidateGood == currentGood
                                    && candidatePenalty == currentPenalty
                                    && candidateDistance < currentDistance) {
                                sceneText = response.text
                                sceneFinishReason = response.finishReason
                            }
                            if AutonomousContentQuality.acceptsDraftScene(sceneText, targetWords: scene.targetWordCount),
                               !AutonomousContentQuality.containsPromptArtifacts(sceneText),
                               !AutonomousContentQuality.soundsLikeAI(sceneText),
                               AutonomousContentQuality.clarityAssessment(sceneText).isAcceptable,
                               AutonomousContentQuality.repeatedSentenceCollisions(
                                   candidate: sceneText,
                                   priorTexts: priorProseTexts
                               ).isEmpty,
                               AutonomousContentQuality.unsupportedCanonClaims(
                                   in: sceneText, canon: primaryCanon,
                                   characterNames: characterNames
                               ).isEmpty,
                               !AutonomousContentQuality.hasScenePlanGenreDrift(
                                   sceneText, genre: project.genre, canon: primaryCanon
                               ),
                               AutonomousContentQuality.unexpectedCharacterNames(
                                   in: sceneText, allowedContext: allowedDraftContext,
                                   characterNames: characterNames
                               ).isEmpty,
                               AutonomousContentQuality.unexpectedStoryArtifacts(
                                   in: sceneText, allowedContext: allowedDraftContext
                               ).isEmpty,
                               // Stilticks erlauben GENAU EINE gezielte Neufassung (Versuch 2
                               // bekommt den Stiltick-Hinweis); ab Versuch 2 blockieren sie die
                               // Annahme nicht mehr – Kostenkontrolle statt Endlos-Perfektion.
                               (project.isNonfiction || attempt >= 2
                                || AutonomousContentQuality.styleTicViolations(in: sceneText).isEmpty),
                               ContentSafetyFilter.isSafe(sceneText) {
                                lastProviderError = nil
                                break
                            }
                        } catch {
                            lastProviderError = error
                            if isFatalProductionError(error) { throw error }
                        }
                    }

                    if AutonomousContentQuality.isLikelyTruncated(
                        sceneText, finishReason: sceneFinishReason
                    ) {
                        let completed = try await completeTruncatedProse(
                            sceneText,
                            project: project,
                            chapter: chapter,
                            scene: scene,
                            config: config
                        )
                        sceneText = completed.text
                        sceneTokens += completed.tokens
                        sceneFinishReason = "stop"
                    }

                    // Deutlich zu kurze, aber vorhandene Szene einmalig vertiefen –
                    // MIT Kontext (Figuren, Vorszenen-Ende, Genre) und erneuter Prüfung:
                    // Die Nachbesserung der schwächsten Szenen lief vorher ungesichert
                    // und konnte KI-Floskeln/Widersprüche NACH den Qualitäts-Gates einführen.
                    if !sceneText.isEmpty, sceneText.wordCount < minWords {
                        do {
                            let expanded = try await generate(
                                prompt: PromptFactory.expandScene(
                                    language: project.language, style: project.styleProfile,
                                    text: sceneText, targetWords: scene.targetWordCount,
                                    charactersSummary: sceneCharactersSummary,
                                    previousSceneEnding: previousEnding,
                                    genreBrief: profile.genreRules
                                ),
                                system: "Du bist ein professioneller Romanautor. Du vertiefst Szenen, ohne die Handlung zu verändern.",
                                maxTokens: maxTokens, temperature: 0.7, config: config, creative: true
                            )
                            if expanded.text.wordCount > sceneText.wordCount,
                               !AutonomousContentQuality.isLikelyTruncated(
                                   expanded.text, finishReason: expanded.finishReason),
                               !AutonomousContentQuality.containsPromptArtifacts(expanded.text),
                               !PublicContentGuard.disclosureViolation(in: expanded.text),
                               !AutonomousContentQuality.soundsLikeAI(expanded.text),
                               AutonomousContentQuality.clarityAssessment(expanded.text).isAcceptable,
                               AutonomousContentQuality.repeatedSentenceCollisions(
                                   candidate: expanded.text,
                                   priorTexts: priorProseTexts
                               ).isEmpty,
                               ContentSafetyFilter.isSafe(expanded.text) {
                                sceneText = expanded.text
                                sceneTokens += expanded.tokensUsed ?? 0
                                sceneFinishReason = expanded.finishReason
                            }
                        } catch {
                            if isFatalProductionError(error) { throw error }
                        }
                    }

                    if sceneText.wordCount > Int(Double(scene.targetWordCount) * 1.25) {
                        let fitted = try await fitSceneToTarget(
                            sceneText,
                            project: project,
                            chapter: chapter,
                            scene: scene,
                            config: config
                        )
                        sceneText = fitted.text
                        sceneTokens += fitted.tokens
                        sceneFinishReason = "stop"
                    }

                    // Durchgesickerte Prompt-Anweisungen/Labels aus der Prosa entfernen
                    // (z.B. „Knüpfe nahtlos daran …") und KI-typische Gedankenstriche
                    // in natürliche Interpunktion umwandeln – bevor etwas gespeichert wird.
                    sceneText = AutonomousContentQuality.strippingPromptArtifacts(sceneText)
                    sceneText = AutonomousContentQuality.strippingInlineFormatting(sceneText)
                    sceneText = AutonomousContentQuality.humanizeProse(sceneText)

                    let cleanup = try await cleanDraftSentenceCollisions(
                        sceneText,
                        priorTexts: priorProseTexts,
                        project: project,
                        chapter: chapter,
                        scene: scene,
                        config: config
                    )
                    sceneText = cleanup.text
                    sceneTokens += cleanup.tokens
                    let styleCleanup = try await cleanDraftStyleArtifacts(
                        sceneText,
                        priorTexts: priorProseTexts,
                        project: project,
                        chapter: chapter,
                        scene: scene,
                        config: config
                    )
                    sceneText = styleCleanup.text
                    sceneTokens += styleCleanup.tokens
                    if styleCleanup.changed { sceneFinishReason = "stop" }
                    if AutonomousContentQuality.soundsLikeAI(sceneText)
                        || !AutonomousContentQuality.clarityAssessment(sceneText).isAcceptable
                        || !AutonomousContentQuality.repeatedSentenceCollisions(
                            candidate: sceneText, priorTexts: priorProseTexts
                        ).isEmpty
                        || !AutonomousContentQuality.unsupportedCanonClaims(
                            in: sceneText, canon: primaryCanon,
                            characterNames: characterNames
                        ).isEmpty
                        || AutonomousContentQuality.hasScenePlanGenreDrift(
                            sceneText, genre: project.genre, canon: primaryCanon
                        )
                        || !AutonomousContentQuality.unexpectedCharacterNames(
                            in: sceneText, allowedContext: allowedDraftContext,
                            characterNames: characterNames
                        ).isEmpty
                        || !AutonomousContentQuality.unexpectedStoryArtifacts(
                            in: sceneText, allowedContext: allowedDraftContext
                        ).isEmpty {
                        let enforced = try await enforceDraftQuality(
                            sceneText,
                            priorTexts: priorProseTexts,
                            allowedContext: allowedDraftContext,
                            draftCanon: sceneDraftCanon,
                            project: project,
                            chapter: chapter,
                            scene: scene,
                            config: config
                        )
                        sceneText = enforced.text
                        sceneTokens += enforced.tokens
                        if enforced.changed { sceneFinishReason = "stop" }
                    }
                    // Jede modellbasierte Spätkorrektur kann erneut eine Überschrift oder ein
                    // Ausgabe-Label einführen. Deshalb direkt vor den harten Gates nochmals säubern.
                    sceneText = AutonomousContentQuality.humanizeProse(
                        AutonomousContentQuality.strippingInlineFormatting(
                            AutonomousContentQuality.strippingPromptArtifacts(sceneText)
                        )
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    // WICHTIG (Livelock-Schutz): Diese Spät-Prüfungen sind SIGNALE, keine
                    // Abbruchgründe. Ein `throw` hier führte in eine Endlos-Schleife:
                    // die Szene wird nie gespeichert, der Auto-Resume startet die Pipeline
                    // neu und trifft dieselbe Szene mit demselben deterministischen Befund
                    // (143 Neustarts in einer Nacht). Grundregel des Systems: Inhalts-
                    // schwäche beendet NIE das Buch – Befunde werden als Fehler-Report
                    // vermerkt und von Kapitelrevision + finalem Repair-Audit behoben.
                    if AutonomousContentQuality.containsPromptArtifacts(sceneText)
                        || AutonomousContentQuality.containsMetaRequest(sceneText)
                        || PublicContentGuard.disclosureViolation(in: sceneText) {
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene enthält nach der Spätkorrektur noch Meta- oder Prompttext – zur Reparatur vorgemerkt.",
                                  severity: .warning,   // Heuristik-Hinweis: Revision/Repair polieren; darf die Freigabe nicht dauerhaft blockieren
                                  recommendation: "Das finale Repair-Audit ersetzt die markierte Stelle durch reinen Buchtext.")
                    }
                    let finalClarity = AutonomousContentQuality.clarityAssessment(sceneText)
                    if !finalClarity.isAcceptable || AutonomousContentQuality.soundsLikeAI(sceneText) {
                        addReport(
                            project: project,
                            area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                            type: "Stil-Nachbearbeitung",
                            result: "Die Rohfassung enthält nach der Sofortkorrektur noch Stil- oder Klarheitsreste.",
                            severity: .warning,
                            recommendation: "Kapitelrevision und finales Repair-Audit überarbeiten diese Stelle erneut."
                        )
                    }
                    if !AutonomousContentQuality.repeatedSentenceCollisions(
                        candidate: sceneText, priorTexts: priorProseTexts
                    ).isEmpty {
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene enthält noch wortgleiche Sätze – zur Schlusskorrektur vorgemerkt.",
                                  severity: .warning,
                                  recommendation: "Die Schlusskorrektur ersetzt die kollidierenden Sätze kontextbezogen.")
                    }
                    if !AutonomousContentQuality.unsupportedCanonClaims(
                        in: sceneText, canon: primaryCanon,
                        characterNames: characterNames
                    ).isEmpty {
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene führt eine nicht belegte Verwandtschaft oder Statusangabe ein – zur Reparatur vorgemerkt.",
                                  severity: .warning,   // Heuristik-Hinweis: Revision/Repair polieren; darf die Freigabe nicht dauerhaft blockieren
                                  recommendation: "Repair-Audit: ausschließlich Prämisse, Exposé und Primärplot einhalten; unbekannte Details offenlassen.")
                    }
                    let finalGenreDrift = AutonomousContentQuality.scenePlanGenreDriftMarkers(
                        sceneText, genre: project.genre, canon: primaryCanon
                    )
                    if !finalGenreDrift.isEmpty {
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene enthält genrefremde Motive: \(finalGenreDrift.joined(separator: ", ")) – zur Reparatur vorgemerkt.",
                                  severity: .warning,   // Heuristik-Hinweis: Revision/Repair polieren; darf die Freigabe nicht dauerhaft blockieren
                                  recommendation: "Repair-Audit: Begegnungen offen, menschlich und genretreu umschreiben.")
                    }
                    let unexpectedCharacters = AutonomousContentQuality.unexpectedCharacterNames(
                        in: sceneText, allowedContext: allowedDraftContext,
                        characterNames: characterNames
                    )
                    let unexpectedArtifacts = AutonomousContentQuality.unexpectedStoryArtifacts(
                        in: sceneText, allowedContext: allowedDraftContext
                    )
                    if !unexpectedCharacters.isEmpty || !unexpectedArtifacts.isEmpty {
                        let violations = unexpectedCharacters + unexpectedArtifacts
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene zieht ungeplante Figuren oder Elemente vor: \(violations.joined(separator: ", ")) – zur Reparatur vorgemerkt.",
                                  severity: .warning,   // Heuristik-Hinweis: Revision/Repair polieren; darf die Freigabe nicht dauerhaft blockieren
                                  recommendation: "Repair-Audit: nur Figuren und Elemente aus Szenenziel, Wendung und bisheriger Handlung verwenden.")
                    }
                    if AutonomousContentQuality.isLikelyTruncated(
                        sceneText, finishReason: sceneFinishReason
                    ) {
                        addReport(project: project, area: sceneArea, type: "Szenen-Neufassung",
                                  result: "Szene endet möglicherweise unvollständig – zur Reparatur vorgemerkt.",
                                  severity: .warning,   // Heuristik-Hinweis: Revision/Repair polieren; darf die Freigabe nicht dauerhaft blockieren
                                  recommendation: "Repair-Audit: Szenenschluss vervollständigen.")
                    }

                    // HARTE SICHERHEITSSPERRE: sexuelle Inhalte mit Kindern/Minderjährigen
                    // werden NIE gespeichert – unabhängig von Genre oder Sinnlichkeitsgrad.
                    if let safetyViolation = ContentSafetyFilter.violation(in: sceneText) {
                        addReport(project: project,
                                  area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                                  type: "Sicherheit",
                                  result: "Szene vom Schutzfilter blockiert (\(safetyViolation)) – Platzhalter eingefügt",
                                  severity: .critical,
                                  recommendation: "Szene neu erzeugen; an intimen Szenen dürfen ausschließlich erwachsene Figuren beteiligt sein.")
                        sceneText = fallbackSceneText(chapter: chapter, scene: scene)
                    }

                    // Robustheit: Inhaltsschwäche beendet NIE das Buch.
                    let cleaned = sceneText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty || AutonomousContentQuality.containsMetaRequest(cleaned) {
                        // Kein verwertbarer Text. Provider weg → pausieren (fortsetzbar);
                        // sonst klar markierter Platzhalter, damit das Buch komplett wird.
                        if let error = lastProviderError { throw error }
                        sceneText = fallbackSceneText(chapter: chapter, scene: scene)
                        addReport(project: project,
                                  area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                                  type: "Rohfassung",
                                  result: "Szene konnte nicht generiert werden – Platzhalter eingefügt",
                                  severity: .warning,
                                  recommendation: "Szene im Manuskript neu erzeugen.")
                    } else if !AutonomousContentQuality.acceptsDraftScene(sceneText, targetWords: scene.targetWordCount) {
                        let direction = sceneText.wordCount < Int(Double(scene.targetWordCount) * 0.75)
                            ? "unterhalb" : "oberhalb"
                        addReport(project: project,
                                  area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                                  type: "Umfang",
                                  result: "Szene \(direction) des Zielkorridors (\(sceneText.wordCount)/\(scene.targetWordCount) Wörter)",
                                  severity: .warning,
                                  recommendation: direction == "unterhalb"
                                    ? "Szene im Manuskript vertiefen."
                                    : "Redundanz in der Kapitelrevision verdichten.")
                    }

                    scene.text = sceneText
                    scene.status = .written
                    scene.updatedAt = Date()
                    previousSceneText = sceneText
                    priorProseTexts.append(sceneText)
                    chapter.actualWordCount = sortedScenes(chapter).compactMap { $0.text?.wordCount }.reduce(0, +)
                    if AutonomousContentQuality.acceptsDraftScene(
                           sceneText, targetWords: scene.targetWordCount),
                       AutonomousContentQuality.clarityAssessment(sceneText).isAcceptable,
                       !AutonomousContentQuality.soundsLikeAI(sceneText),
                       AutonomousContentQuality.repeatedSentenceCollisions(
                           candidate: sceneText, priorTexts: Array(priorProseTexts.dropLast())
                       ).isEmpty {
                        resolveSceneReports(
                            project: project,
                            chapterNumber: chapter.chapterNumber,
                            sceneNumber: scene.sceneNumber
                        )
                    }
                    completeJob(job, result: "\(sceneText.wordCount) Wörter", tokens: sceneTokens)

                    // Kontext-Zusammenfassung für die folgenden Szenen.
                    let summary = await summarizeScene(sceneText, project: project,
                                                       chapter: chapter, scene: scene, config: config)
                    scene.summary = summary
                    storySoFar.append("Kap. \(chapter.chapterNumber), Szene \(scene.sceneNumber): \(summary)")

                    sceneTimes.append(Date().timeIntervalSince(sceneStart))
                    completedScenes += 1
                    updateProgress(phase: .drafting,
                                   subProgress: totalScenes > 0 ? Double(completedScenes) / Double(totalScenes) : 1)
                    updateEstimatedTime()
                    updateProductionTiming()
                    modelContext?.saveOrLog()
                } catch {
                    scene.status = .needsRevision
                    failJob(job, error: error)
                    throw error
                }
            }

            if !(chapter.finalText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chapter.status = .finalized
            } else if !(chapter.revisedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chapter.status = .revised
            } else {
                chapter.status = .draftComplete
            }

            // Kapitel-Digest für das Langstrecken-Gedächtnis erzeugen (einmalig).
            if (chapter.summary ?? "").isEmpty {
                let digest = await condenseChapterSummary(chapter, project: project, config: config)
                if !digest.isEmpty {
                    chapter.summary = digest
                    chapterDigests.append("Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(digest)")
                }
            }
            if let digest = chapter.summary, !digest.isEmpty,
               !chapterDigests.contains(where: { $0.hasPrefix("Kapitel \(chapter.chapterNumber) ") }) {
                chapterDigests.append("Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(digest)")
            }
            // Echten, inhaltsbezogenen Kapiteltitel sicherstellen (verhindert „Aufbruch N").
            await ensureRealChapterTitle(chapter, project: project,
                                         summary: chapter.summary ?? "", config: config)
            modelContext?.saveOrLog()
        }
        estimatedTimeRemaining = ""
    }

    /// Verdichtet die Szenen-Zusammenfassungen eines Kapitels auf 1-2 Sätze.
    /// Fehler sind nicht fatal – dann dient der gekürzte Rohtext als Ersatz.
    private func condenseChapterSummary(_ chapter: Chapter, project: Project,
                                        config: ProviderConfiguration) async -> String {
        let joined = sortedScenes(chapter).compactMap { $0.summary }.joined(separator: " ")
        guard !joined.isEmpty else { return "" }

        let job = beginJob(agent: AgentName.summarizer, phase: .drafting,
                           project: project, chapter: chapter.chapterNumber)
        do {
            let response = try await generate(
                prompt: PromptFactory.condenseChapter(chapterNumber: chapter.chapterNumber,
                                                      chapterTitle: chapter.title,
                                                      sceneSummaries: joined),
                system: "Du verdichtest Kapitelzusammenfassungen präzise und faktentreu.",
                maxTokens: 160, temperature: 0.2, config: config
            )
            completeJob(job, result: response.text, tokens: response.tokensUsed ?? 0)
            return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            failJob(job, error: error)
            return String(joined.prefix(350))
        }
    }

    /// Benennt ein Kapitel anhand seines Inhalts neu, wenn der Titel generisch oder
    /// leer ist (z.B. „Aufbruch 7"). Liefert echte, konkrete Kapiteltitel statt
    /// Platzhalter. Fehler sind nicht fatal – dann bleibt der bisherige Titel.
    private func ensureRealChapterTitle(_ chapter: Chapter, project: Project,
                                        summary: String, config: ProviderConfiguration) async {
        let current = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let phasePattern = #"^(aufbruch|eskalation|krise|auflösung|kapitel|teil)\s+\d+$"#
        let isGeneric = current.isEmpty
            || AutonomousContentQuality.isGenericPlaceholder(current)
            || current.range(of: phasePattern, options: [.regularExpression, .caseInsensitive]) != nil
        guard isGeneric, !summary.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            let response = try await generate(
                prompt: PromptFactory.chapterTitle(bookTitle: project.title, genre: project.genre,
                                                   chapterNumber: chapter.chapterNumber, summary: summary),
                system: "Du bist ein Lektor und findest treffende, neugierig machende Kapiteltitel.",
                maxTokens: 24, temperature: 0.8, config: config
            )
            let cleaned = (response.text.components(separatedBy: .newlines).first ?? "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "„", with: "")
                .replacingOccurrences(of: "\u{201C}", with: "")
                .replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard chapter.modelContext != nil else { return } // nach await evtl. gelöscht
            if !cleaned.isEmpty, cleaned.count <= 60,
               !AutonomousContentQuality.isGenericPlaceholder(cleaned),
               cleaned.range(of: phasePattern, options: [.regularExpression, .caseInsensitive]) == nil {
                chapter.title = cleaned
            }
        } catch {
            // Titel-Generierung ist nicht fatal; generischer Titel bleibt erhalten.
        }
    }

    /// Erzeugt eine kompakte Szenenzusammenfassung. Fehler hier sind nicht fatal –
    /// dann dient der Szenenanfang als Ersatz.
    private func summarizeScene(_ text: String, project: Project, chapter: Chapter,
                                scene: StoryScene, config: ProviderConfiguration) async -> String {
        let job = beginJob(agent: AgentName.summarizer, phase: .drafting, project: project,
                           chapter: chapter.chapterNumber, scene: scene.sceneNumber)
        do {
            let response = try await generate(
                prompt: PromptFactory.summarizeScene(text: text),
                system: "Du fasst Romanszenen präzise und knapp zusammen.",
                maxTokens: 250, temperature: 0.3, config: config
            )
            let summary = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let canon = primaryStoryCanon(project: project) + "\n\nAKZEPTIERTER SZENENTEXT:\n" + text
            let names = (project.storyBible?.characters ?? []).map(\.name)
            let unsupported = AutonomousContentQuality.unsupportedCanonClaims(
                in: summary, canon: canon, characterNames: names
            )
            if unsupported.isEmpty,
               !AutonomousContentQuality.summaryIntroducesUnsupportedSpecifics(
                   summary, evidence: canon
               ),
               !AutonomousContentQuality.containsPromptArtifacts(summary) {
                completeJob(job, result: summary, tokens: response.tokensUsed ?? 0)
                return summary
            }
            let fallback = safeSceneSummary(text)
            completeJob(job, result: "Zusammenfassung lokal aus Szenentext abgeleitet",
                        tokens: response.tokensUsed ?? 0)
            return fallback
        } catch {
            failJob(job, error: error)
            return safeSceneSummary(text)
        }
    }

    private func safeSceneSummary(_ text: String) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > 420 else { return compact }
        return String(compact.prefix(240)) + " … " + String(compact.suffix(160))
    }

    // MARK: - Phase 7: Kapitelrevision

    private func completeTruncatedProse(
        _ text: String,
        project: Project,
        chapter: Chapter,
        scene: StoryScene?,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int) {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tokens = 0
        let targetWords = max(200, scene?.targetWordCount ?? chapter.targetWordCount)

        for attempt in 1...3 {
            try Task.checkCancellation()
            let safePrefix = AutonomousContentQuality.safePrefixBeforeTruncation(working)
            let missingWords = max(140, min(1_200, targetWords - safePrefix.wordCount + 120))
            let contextTail = String(safePrefix.suffix(7_000))
            let unit = scene.map { "Szene \($0.sceneNumber)" } ?? "Kapitel \(chapter.chapterNumber)"
            let prompt = """
            Technische Fortsetzung für ein abgebrochenes Manuskript.

            Buch: \(project.title)
            Genre: \(project.genre)
            Kapitel \(chapter.chapterNumber): \(chapter.title)
            Kapitelziel: \(chapter.goal)
            Kapitelkonflikt: \(chapter.conflict)
            Einheit: \(unit)
            \(scene.map { "Szenenziel: \($0.goal)\nHindernis: \($0.obstacle)\nWendung: \($0.cliffhanger)" } ?? "Schließe das Kapitel vollständig und stimmig ab.")

            Letzter sicherer Text:
            \(contextTail)

            Schreibe AUSSCHLIESSLICH die fehlende Fortsetzung ab dem nächsten Satz.
            Wiederhole keinen vorhandenen Satz und beginne nicht von vorn.
            Ziel: ungefähr \(missingWords) weitere Wörter, höchstens \(missingWords + 250).
            Löse die geplante Wendung aus, halte Figuren, Perspektive und Zeitform stabil.
            Beende mit einem vollständigen Satz. Keine Überschrift, Analyse oder Notiz.
            Fortsetzungsversuch: \(attempt)/3.
            """
            let response = try await generate(
                prompt: prompt,
                system: "Du reparierst technisch abgebrochene Buchprosa. Du gibst nur die fehlende Fortsetzung zurück.",
                maxTokens: min(6_000, max(1_000, missingWords * 4)),
                temperature: 0.55,
                config: config,
                creative: true
            )
            tokens += response.tokensUsed ?? 0
            var continuation = AutonomousContentQuality.strippingPromptArtifacts(response.text)
            continuation = AutonomousContentQuality.strippingInlineFormatting(continuation)
            continuation = AutonomousContentQuality.humanizeProse(continuation)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !continuation.isEmpty,
                  !AutonomousContentQuality.containsMetaRequest(continuation),
                  !PublicContentGuard.disclosureViolation(in: continuation),
                  ContentSafetyFilter.isSafe(continuation) else {
                continue
            }
            if !safePrefix.isEmpty, continuation.wordCount > missingWords + 350 {
                continue
            }

            working = AutonomousContentQuality.mergingContinuation(
                base: safePrefix,
                continuation: continuation
            )
            if !AutonomousContentQuality.isLikelyTruncated(
                working, finishReason: response.finishReason
            ) {
                return (working, tokens)
            }
        }

        throw AIError.systemError(
            "Kapitel \(chapter.chapterNumber) konnte nach drei Versuchen nicht vollständig fortgesetzt werden."
        )
    }

    private func cleanDraftSentenceCollisions(
        _ source: String,
        priorTexts: [String],
        project: Project,
        chapter: Chapter,
        scene: StoryScene,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int) {
        var paragraphs = source.components(separatedBy: "\n\n")
        var usedTokens = 0

        for _ in 1...2 {
            let currentText = paragraphs.joined(separator: "\n\n")
            let collisions = AutonomousContentQuality.repeatedSentenceCollisions(
                candidate: currentText, priorTexts: priorTexts
            )
            guard !collisions.isEmpty else { break }

            for index in paragraphs.indices {
                let paragraph = paragraphs[index]
                let hits = collisions.filter {
                    paragraph.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }
                guard !hits.isEmpty, paragraph.wordCount >= 5 else { continue }
                let comparisonTexts = priorTexts + paragraphs.enumerated().compactMap {
                    $0.offset == index ? nil : $0.element
                }
                let collisionList = hits.map { "- \($0)" }.joined(separator: "\n")
                var replacement: String?
                for attempt in 1...2 where replacement == nil {
                    let response = try await generate(
                        prompt: """
                        Formuliere in diesem Absatz ausschließlich die folgenden wortgleichen
                        Sätze neu oder entferne sie, falls sie inhaltlich entbehrlich sind:
                        \(collisionList)

                        Bewahre Handlung, Fakten, Dialogbedeutung, Perspektive, Zeitform und
                        ungefähre Länge. Die Ersatzformulierung muss konkret aus diesem Absatz
                        entstehen und darf keine neue Standardfloskel sein. Gib nur den Absatz zurück.

                        KAPITEL \(chapter.chapterNumber), SZENE \(scene.sceneNumber), VERSUCH \(attempt)/2
                        ABSATZ:
                        \(paragraph)
                        """,
                        system: project.isNonfiction
                            ? "Du bist ein präziser Sachbuchlektor und variierst ohne Faktenverlust."
                            : "Du bist ein präziser Romanlektor und variierst ohne Handlungsverlust.",
                        maxTokens: min(3_000, max(500, paragraph.wordCount * 5)),
                        temperature: 0.35,
                        config: config,
                        creative: true
                    )
                    usedTokens += response.tokensUsed ?? 0
                    let candidate = AutonomousContentQuality.humanizeProse(
                        AutonomousContentQuality.strippingInlineFormatting(
                            AutonomousContentQuality.strippingPromptArtifacts(response.text)
                        )
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    if AutonomousContentQuality.isAcceptableRewrite(
                           source: paragraph, candidate: candidate,
                           minRatio: 0.55, maxRatio: 1.40,
                           finishReason: response.finishReason),
                       !hits.contains(where: {
                           candidate.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                       }),
                       !AutonomousContentQuality.containsMetaRequest(candidate),
                       !PublicContentGuard.disclosureViolation(in: candidate),
                       AutonomousContentQuality.repeatedSentenceCollisions(
                           candidate: candidate, priorTexts: comparisonTexts
                       ).isEmpty,
                       ContentSafetyFilter.isSafe(candidate) {
                        replacement = candidate
                    }
                }
                if let replacement { paragraphs[index] = replacement }
            }
        }
        return (paragraphs.joined(separator: "\n\n"), usedTokens)
    }

    private func cleanDraftStyleArtifacts(
        _ source: String,
        priorTexts: [String],
        project: Project,
        chapter: Chapter,
        scene: StoryScene,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int, changed: Bool) {
        guard AutonomousContentQuality.soundsLikeAI(source)
                || !AutonomousContentQuality.clarityAssessment(source).isAcceptable else {
            return (source, 0, false)
        }
        var paragraphs = source.components(separatedBy: "\n\n")
        var usedTokens = 0
        var changed = false

        for index in paragraphs.indices {
            let paragraph = paragraphs[index]
            let phrases = AutonomousContentQuality.aiTellMatches(in: paragraph)
                + AutonomousContentQuality.circumlocutionMatches(in: paragraph)
                + AutonomousContentQuality.clarityRepairPhrases(in: paragraph)
            let hasVocabularyArtifact = AutonomousContentQuality.jargonTellCount(paragraph) > 0
                || AutonomousContentQuality.archaicTellCount(paragraph) > 0
            guard !phrases.isEmpty || hasVocabularyArtifact else { continue }
            guard paragraph.wordCount >= 8 else { continue }

            let phraseList = phrases.isEmpty
                ? "- unnatürlich geschwollenes oder unnötig akademisches Vokabular"
                : Array(Set(phrases)).sorted().map { "- \($0)" }.joined(separator: "\n")
            let comparisonTexts = priorTexts + paragraphs.enumerated().compactMap {
                $0.offset == index ? nil : $0.element
            }
            var replacement: String?
            for attempt in 1...2 where replacement == nil {
                let response = try await generate(
                    prompt: """
                    Überarbeite nur diesen Absatz aus Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber).
                    Ersetze die markierten formelhaften Wendungen durch konkrete, unauffällige Sprache,
                    die nur aus Situation, Figur und Handlung dieses Absatzes entsteht. Bewahre Ereignisse,
                    Fakten, Dialogbedeutung, Perspektive und Zeitform. Keine neue Metapher, Körperfloskel,
                    Zusammenfassung oder Standardreaktion. Benenne klar, wer handelt, was geschieht und
                    welche unmittelbare Folge es hat. Gib nur den vollständigen Absatz zurück.

                    ZU ERSETZEN:
                    \(phraseList)

                    ABSATZ:
                    \(paragraph)

                    Qualitätsversuch \(attempt)/2.
                    """,
                    system: project.isNonfiction
                        ? "Du bist ein präziser Sachbuchlektor und schreibst klar, konkret und ohne Motivationsfloskeln."
                        : "Du bist ein präziser Romanlektor und ersetzt Klischees durch konkrete Handlung und individuelle Wahrnehmung.",
                    maxTokens: min(3_000, max(500, paragraph.wordCount * 5)),
                    temperature: 0.3,
                    config: config,
                    creative: true
                )
                usedTokens += response.tokensUsed ?? 0
                let candidate = AutonomousContentQuality.humanizeProse(
                    AutonomousContentQuality.strippingInlineFormatting(
                        AutonomousContentQuality.strippingPromptArtifacts(response.text)
                    )
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if AutonomousContentQuality.isAcceptableRewrite(
                       source: paragraph,
                       candidate: candidate,
                       minRatio: 0.55,
                       maxRatio: 1.40,
                       finishReason: response.finishReason
                   ),
                   AutonomousContentQuality.aiTellMatches(in: candidate).isEmpty,
                   AutonomousContentQuality.circumlocutionMatches(in: candidate).isEmpty,
                   AutonomousContentQuality.clarityRepairPhrases(in: candidate).isEmpty,
                   AutonomousContentQuality.jargonTellCount(candidate) == 0,
                   AutonomousContentQuality.archaicTellCount(candidate) == 0,
                   !AutonomousContentQuality.containsMetaRequest(candidate),
                   !PublicContentGuard.disclosureViolation(in: candidate),
                   AutonomousContentQuality.repeatedSentenceCollisions(
                       candidate: candidate,
                       priorTexts: comparisonTexts
                   ).isEmpty,
                   ContentSafetyFilter.isSafe(candidate) {
                    replacement = candidate
                }
            }
            if let replacement {
                paragraphs[index] = replacement
                changed = true
            }
        }
        return (paragraphs.joined(separator: "\n\n"), usedTokens, changed)
    }

    private func enforceDraftQuality(
        _ source: String,
        priorTexts: [String],
        allowedContext: String,
        draftCanon: String,
        project: Project,
        chapter: Chapter,
        scene: StoryScene,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int, changed: Bool) {
        var usedTokens = 0
        let clarity = AutonomousContentQuality.clarityAssessment(source)
        let phrases = Array(Set(
            AutonomousContentQuality.aiTellMatches(in: source)
                + AutonomousContentQuality.circumlocutionMatches(in: source)
                + AutonomousContentQuality.clarityRepairPhrases(in: source)
        )).sorted()
        let collisions = AutonomousContentQuality.repeatedSentenceCollisions(
            candidate: source, priorTexts: priorTexts
        )
        let primaryCanon = primaryStoryCanon(project: project)
        let characterNames = (project.storyBible?.characters ?? []).map(\.name)
        let canonClaims = AutonomousContentQuality.unsupportedCanonClaims(
            in: source, canon: primaryCanon, characterNames: characterNames
        )
        let genreDrift = AutonomousContentQuality.hasScenePlanGenreDrift(
            source, genre: project.genre, canon: primaryCanon
        )
        let unexpectedCharacters = AutonomousContentQuality.unexpectedCharacterNames(
            in: source, allowedContext: allowedContext, characterNames: characterNames
        )
        let unexpectedArtifacts = AutonomousContentQuality.unexpectedStoryArtifacts(
            in: source, allowedContext: allowedContext
        )
        let promptSource = AutonomousContentQuality.removingScenePlanViolations(
            from: source,
            characterNames: unexpectedCharacters,
            artifactLabels: unexpectedArtifacts
        )
        var allFindings = phrases + collisions + canonClaims
        if genreDrift {
            allFindings.append("Genre-Abdrift: bedrohliche Horror-/Stalkerinszenierung entfernen")
        }
        if !unexpectedCharacters.isEmpty || !unexpectedArtifacts.isEmpty {
            allFindings.append(
                "Nicht geplante benannte Figuren und zusätzliche Fundstücke vollständig entfernen; "
                + "keine Namen oder Gegenstände aus verworfenen Fassungen übernehmen"
            )
        }
        let findings = allFindings.map { "- \($0)" }.joined(separator: "\n")

        for attempt in 1...3 {
            currentAgent = "\(AgentName.draftWriter) – Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber) · Qualitätsfassung \(attempt)/3"
            let response = try await generate(
                prompt: """
                Schreibe diese Szene als klare, vollständige Endfassung neu, ohne Handlung,
                Reihenfolge, Fakten, Dialogbedeutung, Perspektive, Zeitform oder Wendung zu verändern.
                Der Leser muss beim ersten Lesen verstehen, wer handelt, was geschieht, warum die
                Figur es jetzt tut und welche unmittelbare Folge entsteht. Benenne Konkretes direkt.
                Entferne Vergleichsketten, unbenannte „etwas“-Reaktionen, Filterverben,
                Standardkörperreaktionen und wortgleiche Sätze. Zielumfang: \(scene.targetWordCount)
                Wörter, zulässig 75–125 %. Gib nur die vollständige Szene zurück.

                VERBINDLICHER BUCHKANON:
                \(draftCanon.truncated(to: 6_000))
                Verwandtschaft, Besitz, Todesfälle, Vorgeschichte, Namen und Rollen nicht verändern.
                Bei Liebesromanen keine Silhouetten-, Waffen-, Einbrecher-, Geister- oder
                Stalkerinszenierung. Begegnungen mit dem Love Interest offen und menschlich erzählen.

                ZULÄSSIGER SZENENINHALT:
                \(allowedContext.truncated(to: 6_000))
                Keine weitere Figur und kein zusätzliches Fundstück einführen.

                MESSWERTE DES AUSGANGSTEXTS:
                Vage Referenzen: \(clarity.vagueReferences) (erlaubt \(clarity.vagueReferenceLimit))
                Hypothetische Vergleiche: \(clarity.hypotheticalComparisons) (erlaubt \(clarity.hypotheticalComparisonLimit))
                Filterreaktionen: \(clarity.filterReactions) (erlaubt \(clarity.filterReactionLimit))

                ZU BESEITIGEN:
                \(findings.isEmpty ? "- abstrakte oder unklare Formulierungsdichte" : findings)

                KAPITEL \(chapter.chapterNumber), SZENE \(scene.sceneNumber), VERSUCH \(attempt)/3
                TEXT:
                \(promptSource)
                """,
                system: project.isNonfiction
                    ? "Du bist ein strenger Sachbuch-Schlusslektor. Klarheit, Kausalität und Faktenintegrität sind zwingend."
                    : "Du bist ein strenger Roman-Schlusslektor. Du schreibst konkret, kausal und natürlich, ohne die Geschichte zu verändern.",
                maxTokens: min(8_000, max(2_000, scene.targetWordCount * 4)),
                temperature: 0.25,
                config: config,
                creative: true
            )
            usedTokens += response.tokensUsed ?? 0
            let candidate = AutonomousContentQuality.humanizeProse(
                AutonomousContentQuality.strippingInlineFormatting(
                    AutonomousContentQuality.strippingPromptArtifacts(response.text)
                )
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if AutonomousContentQuality.acceptsDraftScene(
                   candidate, targetWords: scene.targetWordCount),
               AutonomousContentQuality.isAcceptableRewrite(
                   source: source, candidate: candidate,
                   minRatio: 0.65, maxRatio: 1.25,
                   finishReason: response.finishReason),
               AutonomousContentQuality.clarityAssessment(candidate).isAcceptable,
               !AutonomousContentQuality.soundsLikeAI(candidate),
               !AutonomousContentQuality.containsMetaRequest(candidate),
               !PublicContentGuard.disclosureViolation(in: candidate),
               AutonomousContentQuality.repeatedSentenceCollisions(
                   candidate: candidate, priorTexts: priorTexts
               ).isEmpty,
               AutonomousContentQuality.unsupportedCanonClaims(
                   in: candidate, canon: primaryCanon,
                   characterNames: characterNames
               ).isEmpty,
               !AutonomousContentQuality.hasScenePlanGenreDrift(
                   candidate, genre: project.genre, canon: primaryCanon
               ),
               AutonomousContentQuality.unexpectedCharacterNames(
                   in: candidate, allowedContext: allowedContext,
                   characterNames: characterNames
               ).isEmpty,
               AutonomousContentQuality.unexpectedStoryArtifacts(
                   in: candidate, allowedContext: allowedContext
               ).isEmpty,
               ContentSafetyFilter.isSafe(candidate) {
                return (candidate, usedTokens, candidate != source)
            }
        }
        return (source, usedTokens, false)
    }

    private func fitSceneToTarget(
        _ source: String,
        project: Project,
        chapter: Chapter,
        scene: StoryScene,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int) {
        let minimumRatio = SceneFittingSizing.minimumSourceRatio(
            sourceWords: source.wordCount,
            targetWords: scene.targetWordCount
        )
        var usedTokens = 0

        for attempt in 1...3 {
            do {
                let response = try await generate(
                    prompt: """
                    Verdichte den folgenden \(project.isNonfiction ? "Sachbuchabschnitt" : "Romanabschnitt")
                    auf \(scene.targetWordCount) Wörter (zulässig: 75–125 %).
                    Bewahre ALLE Handlungsereignisse, Hinweise, Dialogaussagen, Figurenentscheidungen,
                    die Wendung und den Anschluss zur nächsten Szene. Entferne Wiederholungen,
                    doppelte Bilder, vage Innenschau, Vergleichsketten und weitschweifige Beschreibung.
                    Keine Zusammenfassung: Die kausale Handlung bleibt vollständig ausgespielt.
                    Beende mit einem vollständigen Satz. Gib nur die fertige Szene zurück.

                    Buch: \(project.title)
                    Kapitel \(chapter.chapterNumber): \(chapter.title)
                    Szenenziel: \(scene.goal)
                    Wendung: \(scene.cliffhanger)
                    Technischer Vollständigkeitsversuch \(attempt)/3.

                    TEXT:
                    \(source)
                    """,
                    system: project.isNonfiction
                        ? "Du bist ein präziser Sachbuchlektor. Du verdichtest ohne Wissens-, Quellen- oder Anwendungverlust."
                        : "Du bist ein präziser Romanlektor. Du verdichtest ohne Ereignis- oder Informationsverlust.",
                    maxTokens: min(8_000, max(2_000, scene.targetWordCount * 4)),
                    temperature: 0.25,
                    config: config,
                    creative: true
                )
                usedTokens += response.tokensUsed ?? 0
                var fitted = AutonomousContentQuality.strippingPromptArtifacts(response.text)
                fitted = AutonomousContentQuality.strippingInlineFormatting(fitted)
                fitted = AutonomousContentQuality.humanizeProse(fitted)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if AutonomousContentQuality.isWithinWordTarget(
                       fitted, targetWords: scene.targetWordCount,
                       lowerRatio: 0.75, upperRatio: 1.25),
                   AutonomousContentQuality.isAcceptableRewrite(
                       source: source, candidate: fitted,
                       minRatio: minimumRatio, maxRatio: 1.10,
                       finishReason: response.finishReason),
                   !AutonomousContentQuality.containsMetaRequest(fitted),
                   !PublicContentGuard.disclosureViolation(in: fitted),
                   ContentSafetyFilter.isSafe(fitted) {
                    return (fitted, usedTokens)
                }
            } catch {
                if isFatalProductionError(error) { throw error }
            }
        }

        addReport(project: project,
                  area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                  type: "Umfang",
                  result: "Automatische Verdichtung nach drei Versuchen verworfen – vollständige Ursprungsszene beibehalten",
                  severity: .warning,
                  recommendation: "Kapitelrevision verdichtet Redundanz im nächsten Schritt.")
        return (source, usedTokens)
    }

    private func runChapterRevision(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile else {
            throw AIError.systemError("Buchprofil fehlt")
        }
        try Task.checkCancellation()
        project.status = .chapterRevision

        let chapters = sortedChapters(project)
        for chapter in chapters where (chapter.draftText ?? "").isEmpty {
            // Szenen mit sichtbarem Szenentrenner zusammenfügen (Print-/eBook-Konvention).
            chapter.draftText = sortedScenes(chapter).compactMap { $0.text }.joined(separator: "\n\n***\n\n")
        }

        // Fortsetzen: fehlende oder deutlich überlange Revisionen erneut bearbeiten.
        let pending = chapters.filter { chapter in
            guard let draft = chapter.draftText, !draft.isEmpty else { return false }
            let revised = chapter.revisedText ?? ""
            return revised.isEmpty
                || AutonomousContentQuality.containsMetaRequest(revised)
                || AutonomousContentQuality.containsPromptArtifacts(revised)
                || PublicContentGuard.disclosureViolation(in: revised)
                || !AutonomousContentQuality.isWithinWordTarget(
                    revised,
                    targetWords: chapter.targetWordCount,
                    lowerRatio: 0.55,
                    upperRatio: PublicationReadiness.maximumChapterWordRatio
                )
        }
        guard !pending.isEmpty else { return }

        // Buchweite Lieblingsfloskeln des Modells (in >=3 Kapiteln wiederholte 4-6-Wort-
        // Formulierungen) deterministisch erkennen und der Revision zum Ersetzen geben –
        // der meistzitierte KI-Tell in Rezensionen.
        let allDrafts = chapters.map { $0.draftText ?? "" }
        let overused = AutonomousContentQuality.overusedPhrases(inChapters: allDrafts)
        let repeatedSentences = AutonomousContentQuality.repeatedSentences(
            inChapters: allDrafts,
            minimumOccurrences: 2,
            maxResults: 100
        )
        let overusedList = (overused.prefix(12) + repeatedSentences.prefix(40))
            .map { "- \($0)" }.joined(separator: "\n")
        if !overused.isEmpty || !repeatedSentences.isEmpty {
            addReport(project: project, area: "Gesamtmanuskript", type: "Wiederholungen",
                      result: "Buchweit überstrapazierte Formulierungen oder Satzduplikate erkannt (\(overused.count + repeatedSentences.count)) – werden in der Revision ersetzt",
                      severity: .info,
                      recommendation: (overused.prefix(4) + repeatedSentences.prefix(2)).joined(separator: " · "))
        }
        let charactersSummary = project.storyBible.map { compactCharacterSummary($0) } ?? ""

        var jobs: [PipelineJob] = []
        var requests: [GenerationRequest] = []
        for chapter in pending {
            jobs.append(beginJob(agent: AgentName.reviser, phase: .chapterRevision,
                                 project: project, chapter: chapter.chapterNumber))
            let existingRevision = chapter.revisedText ?? ""
            let draft = existingRevision.isEmpty ? (chapter.draftText ?? "") : existingRevision
            // Nachbar-Anschlüsse: Kapitelanfang/-ende dürfen beim Glätten nicht brechen.
            let chapterIdx = chapters.firstIndex(where: { $0.chapterNumber == chapter.chapterNumber })
            let prevEnding = chapterIdx.flatMap { $0 > 0 ? chapters[$0 - 1].draftText : nil }
                .map { String($0.suffix(400)) } ?? ""
            let nextOpening = chapterIdx.flatMap { $0 + 1 < chapters.count ? chapters[$0 + 1].draftText : nil }
                .map { String($0.prefix(300)) } ?? ""
            // Kapitelende ohne Sog? (Nur Nicht-Schlusskapitel – das Finale darf ruhig ausklingen.)
            let isFinal = chapter.chapterNumber == chapters.last?.chapterNumber
            let endingNote = (!project.isNonfiction && !isFinal && AutonomousContentQuality.hasWeakChapterEnding(draft))
                ? "KAPITELENDE SCHÄRFEN: Dieses Kapitel endet aktuell ohne Sog. Forme den letzten Beat zu einem echten Haken um (offene Frage, Drohung, Enthüllung oder eine Entscheidung ohne gezeigte Antwort) – der Leser darf hier nicht aufhören können. Handlung davor unverändert lassen."
                : ""
            // Kapitelweite Stiltick-Frequenzen (Verneinungs-Rhetorik, Körper-Beats,
            // Adverb-Krücken) der Revision als konkrete Reduktionsaufträge mitgeben.
            let ticNotes = project.isNonfiction
                ? []
                : AutonomousContentQuality.styleTicViolations(in: draft)
            let chapterOverused = overusedList + (ticNotes.isEmpty ? ""
                : (overusedList.isEmpty ? "" : "\n")
                    + ticNotes.map { "- STIL-TICK (reduzieren, ohne Handlung zu ändern): \($0)" }
                        .joined(separator: "\n"))
            requests.append(makeRequest(
                prompt: PromptFactory.reviseChapter(
                    language: project.language, style: project.styleProfile,
                    tonality: profile.tonality, chapterNumber: chapter.chapterNumber,
                    chapterTitle: chapter.title, text: draft,
                    genreBrief: profile.genreRules,
                    charactersSummary: charactersSummary,
                    previousEnding: prevEnding, nextOpening: nextOpening,
                    overusedPhrases: chapterOverused,
                    endingNote: endingNote,
                    targetWords: chapter.targetWordCount,
                    researchContext: profile.researchNotes
                ),
                system: project.isNonfiction
                    ? "Du bist ein erfahrener Sachbuchlektor. Du verbesserst Klarheit, Nutzen und Faktenintegrität."
                    : "Du bist ein erfahrener Lektor. Du verbesserst Prosa, ohne Handlung oder Stimme zu verändern.",
                maxTokens: ChapterRevisionSizing.maxOutputTokens(
                    sourceWords: draft.wordCount,
                    targetWords: chapter.targetWordCount
                ),
                temperature: 0.4, config: config
            ))
        }
        currentAgent = "\(AgentName.reviser) – \(pending.count) Kapitel parallel"

        var answered = 0
        let results = await runParallelGeneration(requests: requests, config: config) { _, _ in
            answered += 1
            self.currentAgent = "\(AgentName.reviser) – \(answered)/\(pending.count) Kapitel beantwortet"
            self.updateProgress(phase: .chapterRevision, subProgress: Double(answered) / Double(pending.count))
        }

        var firstError: Error?
        let pendingIDs = Set(pending.map(\.id))
        var acceptedRevisionTexts = chapters.compactMap { chapter -> String? in
            guard !pendingIDs.contains(chapter.id) else { return nil }
            return chapter.bestText
        }
        var done = 0
        for (index, chapter) in pending.enumerated() {
            let existingRevision = chapter.revisedText ?? ""
            let draft = existingRevision.isEmpty ? (chapter.draftText ?? "") : existingRevision
            switch results[index] {
            case .success(let response)?:
                // Schutz vor abgeschnittenen/leeren Antworten: nie Text verlieren.
                // Strenge Abnahme (>=80% Umfang, Satzschluss am Ende, Szenentrenner erhalten) –
                // vorher reichten 50%, wodurch bei maxTokens abgeschnittene Kapitel
                // stillschweigend halbiert beim Leser landeten.
                let sourceIsOversized = ChapterRevisionSizing.isOversized(
                    sourceWords: draft.wordCount,
                    targetWords: chapter.targetWordCount
                )
                let allowedMinimumRatio = ChapterRevisionSizing.minimumSourceRatio(
                    sourceWords: draft.wordCount,
                    targetWords: chapter.targetWordCount
                )
                let candidateFitsTarget = !sourceIsOversized
                    || AutonomousContentQuality.isWithinWordTarget(
                        response.text,
                        targetWords: chapter.targetWordCount,
                        lowerRatio: ChapterRevisionSizing.minimumTargetRatio,
                        upperRatio: 1.30
                    )
                if candidateFitsTarget,
                   AutonomousContentQuality.isAcceptableRewrite(
                       source: draft,
                       candidate: response.text,
                       minRatio: allowedMinimumRatio,
                       maxRatio: 1.15,   // Revision poliert, bläht die Länge NICHT auf
                       finishReason: response.finishReason),
                   withinGrowthCeiling(response.text, source: draft, chapter: chapter),
                   !AutonomousContentQuality.containsMetaRequest(response.text),
                   !AutonomousContentQuality.containsPromptArtifacts(response.text),
                   !PublicContentGuard.disclosureViolation(in: response.text),
                   AutonomousContentQuality.repeatedSentenceCollisions(
                       candidate: response.text,
                       priorTexts: acceptedRevisionTexts
                   ).isEmpty,
                   ContentSafetyFilter.isSafe(response.text) {
                    chapter.revisedText = response.text
                } else {
                    chapter.revisedText = draft
                    addReport(project: project, area: "Kapitel \(chapter.chapterNumber)",
                              type: "Revision", result: "Revisionsantwort unvollständig/abgeschnitten – Rohfassung übernommen",
                              severity: .warning,
                              recommendation: "Kapitel manuell prüfen oder Revision erneut ausführen.")
                }
                chapter.status = .revised
                chapter.updatedAt = Date()
                if let revised = chapter.revisedText, !revised.isEmpty {
                    acceptedRevisionTexts.append(revised)
                }
                completeJob(jobs[index], result: "Kapitel \(chapter.chapterNumber) überarbeitet",
                            tokens: response.tokensUsed ?? 0)
                done += 1
                updateProgress(phase: .chapterRevision, subProgress: Double(done) / Double(pending.count))

            case .failure(let error)?:
                failJob(jobs[index], error: error)
                if firstError == nil { firstError = error }

            case nil:
                jobs[index].status = .paused
                jobs[index].endTime = Date()
            }
        }
        modelContext?.saveOrLog()

        if let error = firstError { throw error }
        try Task.checkCancellation()
    }

    // MARK: - Phase 8: Gesamtlektorat / Konsistenzprüfung

    private func runConsistencyCheck(project: Project, config: ProviderConfiguration) async throws {
        project.status = .manuscriptRevision
        // Bereits geprüft? (Fortsetzen)
        if (project.qualityReports ?? []).contains(where: { $0.checkType == "Konsistenz" }) { return }
        guard let bible = project.storyBible else { return }

        // Budget FAIR auf alle Kapitel verteilen: Vorher wurde die Gesamtübersicht im
        // Prompt hart bei 10.000 Zeichen gekappt – bei langen Büchern wurde alles ab
        // ca. Kapitel 8 nie auf Widersprüche geprüft (ausgerechnet Mitte und Ende,
        // wo sie Leser am meisten stören).
        let allChapters = sortedChapters(project)
        let summaryBudget = 9_500
        let perChapter = allChapters.isEmpty ? 0 : max(160, summaryBudget / allChapters.count)
        let summaries = allChapters.map { chapter -> String in
            let sceneSummaries = sortedScenes(chapter).compactMap { $0.summary }.joined(separator: " ")
            return "Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(sceneSummaries.truncated(to: perChapter))"
        }.joined(separator: "\n")

        guard !summaries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let job = beginJob(agent: AgentName.consistency, phase: .manuscriptRevision, project: project)
        do {
            let response = try await generate(
                prompt: PromptFactory.consistencyCheck(
                    bookTitle: project.title, summaries: summaries,
                    characters: compactCharacterSummary(bible),
                    isNonfiction: project.isNonfiction
                ),
                system: project.isNonfiction
                    ? "Du bist ein Sachbuchprüfer. Du findest Widersprüche, Quellenrisiken und Lücken im Lernweg."
                    : "Du bist ein Kontinuitätsprüfer für Romane. Du findest Widersprüche und Logikfehler.",
                maxTokens: 2000, temperature: 0.2, config: config
            )

            let issues = StructureParser.parseIssues(response.text)
            for issue in issues {
                addReport(project: project, area: issue.area, type: "Konsistenz",
                          result: issue.message, severity: issue.severity,
                          recommendation: issue.recommendation)
            }
            if issues.isEmpty {
                addReport(project: project, area: "Gesamtmanuskript", type: "Konsistenz",
                          result: "Keine Widersprüche gefunden", severity: .info,
                          recommendation: "")
            }
            completeJob(job, result: "\(issues.count) Hinweise", tokens: response.tokensUsed ?? 0)
        } catch {
            failJob(job, error: error)
            throw error
        }
    }

    // MARK: - Phase 9: Korrektorat

    private func runProofreading(project: Project, config: ProviderConfiguration) async throws {
        try Task.checkCancellation()
        project.status = .proofreading

        let chapters = sortedChapters(project)
        var pending: [Chapter] = []
        var sourceByChapter: [UUID: String] = [:]
        for chapter in chapters {
            let final = (chapter.finalText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty,
               !AutonomousContentQuality.isLikelyTruncated(final),
               !AutonomousContentQuality.containsMetaRequest(final),
               !AutonomousContentQuality.containsPromptArtifacts(final),
               !PublicContentGuard.disclosureViolation(in: final) {
                continue
            }
            var source = final.isEmpty
                ? (chapter.revisedText ?? chapter.draftText ?? "")
                : final
            source = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty else { continue }
            if AutonomousContentQuality.isLikelyTruncated(source) {
                let completed = try await completeTruncatedProse(
                    source,
                    project: project,
                    chapter: chapter,
                    scene: nil,
                    config: config
                )
                source = completed.text
                chapter.revisedText = source
                chapter.finalText = nil
                chapter.status = .revised
                chapter.actualWordCount = source.wordCount
                chapter.updatedAt = Date()
            }
            pending.append(chapter)
            sourceByChapter[chapter.id] = source
        }
        guard !pending.isEmpty else { return }

        var jobs: [PipelineJob] = []
        var requests: [GenerationRequest] = []
        for chapter in pending {
            jobs.append(beginJob(agent: AgentName.proofreader, phase: .proofreading,
                                 project: project, chapter: chapter.chapterNumber))
            let text = sourceByChapter[chapter.id] ?? chapter.revisedText ?? chapter.draftText ?? ""
            requests.append(makeRequest(
                prompt: PromptFactory.proofread(language: project.language, text: text),
                system: "Du bist ein professioneller Korrektor. Du korrigierst nur Fehler, nie den Stil.",
                maxTokens: min(12000, max(3000, text.wordCount * 3)),
                temperature: 0.1, config: config
            ))
        }
        currentAgent = "\(AgentName.proofreader) – \(pending.count) Kapitel parallel"

        var answered = 0
        let results = await runParallelGeneration(requests: requests, config: config) { _, _ in
            answered += 1
            self.currentAgent = "\(AgentName.proofreader) – \(answered)/\(pending.count) Kapitel beantwortet"
            self.updateProgress(phase: .proofreading, subProgress: Double(answered) / Double(pending.count))
        }

        var firstError: Error?
        let pendingIDs = Set(pending.map(\.id))
        var acceptedFinalTexts = chapters.compactMap { chapter -> String? in
            guard !pendingIDs.contains(chapter.id) else { return nil }
            return chapter.finalText
        }
        var done = 0
        for (index, chapter) in pending.enumerated() {
            let source = sourceByChapter[chapter.id] ?? chapter.revisedText ?? chapter.draftText ?? ""
            switch results[index] {
            case .success(let response)?:
                // Korrektorat ändert nur Fehler → Umfang muss nahezu identisch bleiben (>=85%),
                // sauber auf Satzschluss enden und alle Szenentrenner erhalten.
                if AutonomousContentQuality.isAcceptableRewrite(source: source, candidate: response.text,
                                                                 minRatio: 0.85,
                                                                 maxRatio: 1.15,
                                                                 finishReason: response.finishReason),
                   withinGrowthCeiling(response.text, source: source, chapter: chapter),
                   !AutonomousContentQuality.containsMetaRequest(response.text),
                   !AutonomousContentQuality.containsPromptArtifacts(response.text),
                   !PublicContentGuard.disclosureViolation(in: response.text),
                   AutonomousContentQuality.repeatedSentenceCollisions(
                       candidate: response.text,
                       priorTexts: acceptedFinalTexts
                   ).isEmpty,
                   ContentSafetyFilter.isSafe(response.text) {
                    chapter.finalText = response.text
                } else {
                    chapter.finalText = source
                    addReport(project: project, area: "Kapitel \(chapter.chapterNumber)",
                              type: "Korrektorat", result: "Korrektoratsantwort unvollständig/abgeschnitten – vorige Fassung übernommen",
                              severity: .warning,
                              recommendation: "Kapitel manuell prüfen.")
                }
                chapter.status = .finalized
                chapter.actualWordCount = chapter.computedWordCount
                chapter.updatedAt = Date()
                if let final = chapter.finalText, !final.isEmpty {
                    acceptedFinalTexts.append(final)
                }
                completeJob(jobs[index], result: "Kapitel \(chapter.chapterNumber) korrigiert",
                            tokens: response.tokensUsed ?? 0)
                done += 1
                updateProgress(phase: .proofreading, subProgress: Double(done) / Double(pending.count))

            case .failure(let error)?:
                failJob(jobs[index], error: error)
                if firstError == nil { firstError = error }

            case nil:
                jobs[index].status = .paused
                jobs[index].endTime = Date()
            }
        }
        modelContext?.saveOrLog()

        if let error = firstError { throw error }
        try Task.checkCancellation()
    }

    // MARK: - Manuelle KI-Nachbearbeitung

    private func runRepairWorkflow(project: Project, config: ProviderConfiguration) async throws -> String {
        try Task.checkCancellation()

        let chapters = sortedChapters(project).filter { chapter in
            guard let text = chapter.bestText else { return false }
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !chapters.isEmpty else {
            return "Es gibt noch keinen prüfbaren Manuskripttext."
        }

        let summaries = repairAuditSummaries(for: chapters)
        let auditedReports = repairReportsForAudit(project)
        let reportBrief = repairReportBrief(auditedReports)
        let characters = project.storyBible.map(compactCharacterSummary) ?? ""

        currentAgent = "\(AgentName.repairEditor) – Audit"
        let auditJob = beginJob(agent: AgentName.repairEditor, phase: .manuscriptRevision, project: project)
        let auditResponse: GenerationResponse
        do {
            auditResponse = try await generate(
                prompt: PromptFactory.repairAudit(
                    bookTitle: project.title,
                    summaries: summaries,
                    characters: characters,
                    qualityReports: reportBrief,
                    tropes: project.tropes,
                    isNonfiction: project.isNonfiction
                ),
                system: project.isNonfiction
                    ? "Du bist ein präziser Sachbuch-Schlusslektor. Du findest echte Sach-, Quellen- und Verständlichkeitsprobleme."
                    : "Du bist ein präziser Schlusslektor. Du findest nur echte Inkonsistenzen und formulierst konkrete Reparaturaufträge.",
                maxTokens: 3000,
                temperature: 0.15,
                config: config
            )
        } catch {
            failJob(auditJob, error: error)
            throw error
        }
        let issues = RepairIssueParser.expandingGlobalChapterReferences(
            RepairIssueParser.parse(auditResponse.text)
        )
        guard RepairIssueParser.isConclusiveAuditResponse(auditResponse.text) else {
            let error = AIError.systemError(
                "Schlussaudit war unvollständig; vorhandene Qualitätsbefunde bleiben offen."
            )
            failJob(auditJob, error: error)
            throw error
        }

        // Erst ein vollständig lesbares neues Audit darf ältere Befunde ablösen.
        let staleRepairReports = (project.qualityReports ?? []).filter {
            $0.checkType == "KI-Nachbearbeitung" || $0.checkType == "Nachbearbeitung"
        }
        for report in staleRepairReports { modelContext?.delete(report) }
        project.qualityReports?.removeAll {
            $0.checkType == "KI-Nachbearbeitung" || $0.checkType == "Nachbearbeitung"
        }
        for report in auditedReports { report.autoFixed = true }
        completeJob(auditJob, result: "\(issues.count) Reparaturbefunde", tokens: auditResponse.tokensUsed ?? 0)

        guard !issues.isEmpty else {
            addReport(project: project,
                      area: "Gesamtmanuskript",
                      type: "Nachbearbeitung",
                      result: "Keine reparaturpflichtigen Inkonsistenzen gefunden.",
                      severity: .info,
                      recommendation: "")
            modelContext?.saveOrLog()
            return "Prüfung abgeschlossen: keine reparaturpflichtigen Inkonsistenzen gefunden."
        }

        var repairedCount = 0
        var skippedCount = 0
        var processedCount = 0

        for issue in issues {
            try Task.checkCancellation()

            let baseArea = issue.chapterNumber.map { "Kapitel \($0)" } ?? "Gesamtmanuskript"
            let area = issue.area.isEmpty ? baseArea : "\(baseArea) · \(issue.area)"
            let report = addReport(project: project,
                                   area: area,
                                   type: "Nachbearbeitung",
                                   result: issue.problem,
                                   severity: issue.severity,
                                   recommendation: issue.instruction)

            guard issue.severity != .info else {
                skippedCount += 1
                continue
            }
            guard let chapterNumber = issue.chapterNumber,
                  let chapter = chapters.first(where: { $0.chapterNumber == chapterNumber }),
                  let currentText = chapter.bestText,
                  !currentText.isEmpty else {
                skippedCount += 1
                continue
            }

            processedCount += 1
            currentAgent = "\(AgentName.repairEditor) – Kapitel \(chapterNumber)"
            let repairJob = beginJob(agent: AgentName.repairEditor,
                                     phase: .manuscriptRevision,
                                     project: project,
                                     chapter: chapterNumber)
            do {
                let minimumWords = max(100, Int(Double(currentText.wordCount) * 0.65))
                var acceptedRepair: String?
                var repairTokens = 0
                if let targeted = try await targetedRepairPatch(
                    source: currentText,
                    project: project,
                    chapter: chapter,
                    issue: issue,
                    config: config
                ) {
                    acceptedRepair = targeted.text
                    repairTokens += targeted.tokens
                }
                for attempt in 1...2 where acceptedRepair == nil {
                    let response = try await generate(
                        prompt: PromptFactory.repairChapter(
                            language: project.language,
                            bookTitle: project.title,
                            chapterNumber: chapter.chapterNumber,
                            chapterTitle: chapter.title,
                            issue: issue,
                            chapterText: currentText.truncated(to: 36_000),
                            isNonfiction: project.isNonfiction
                        ) + "\n\nTechnischer Vollständigkeitsversuch \(attempt)/2: Der letzte Satz muss vollständig sein.",
                        system: project.isNonfiction
                            ? "Du bist ein chirurgisch arbeitender Sachbuchlektor. Du reparierst exakt den Befund, ohne Belege zu erfinden."
                            : "Du bist ein chirurgisch arbeitender Romanlektor. Du reparierst exakt den Befund und gibst nur den vollständigen Kapiteltext zurück.",
                        maxTokens: min(12_000, max(4_000, currentText.wordCount * 4)),
                        temperature: 0.25,
                        config: config, creative: true
                    )
                    repairTokens += response.tokensUsed ?? 0
                    let candidate = AutonomousContentQuality.humanizeProse(
                        AutonomousContentQuality.strippingInlineFormatting(
                            AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // Ziel-Deckel gegen KUMULATIVES Aufblähen: +15% pro Runde klingt harmlos,
                    // aber über mehrere Reparatur-Runden wuchs ein Kapitel so von 1,53× auf
                    // 1,88× des Ziels (Ping-Pong gegen die Verdichtung, Buch wird nie fertig).
                    // Liegt das Kapitel bereits über der Freigabe-Grenze, darf eine Reparatur
                    // es NIE weiter verlängern – nur gleich lang lassen oder kürzen.
                    let targetCeiling = chapter.targetWordCount > 0
                        ? Int(Double(chapter.targetWordCount) * PublicationReadiness.maximumChapterWordRatio)
                        : Int.max
                    let growthCeiling = max(currentText.wordCount, targetCeiling)
                    if AutonomousContentQuality.isAcceptableRewrite(
                           source: currentText,
                           candidate: candidate,
                           minRatio: 0.65,
                           maxRatio: 1.15,   // Reparatur darf das Kapitel NICHT verlängern
                           finishReason: response.finishReason),
                       candidate.wordCount <= growthCeiling,
                       candidate.wordCount >= minimumWords,
                       !AutonomousContentQuality.containsMetaRequest(candidate),
                       !PublicContentGuard.disclosureViolation(in: candidate),
                       ContentSafetyFilter.isSafe(candidate) {
                        acceptedRepair = candidate
                    }
                }

                if let repaired = acceptedRepair {
                    chapter.finalText = repaired
                    chapter.actualWordCount = repaired.wordCount
                    chapter.status = .finalized
                    chapter.updatedAt = Date()
                    project.updatedAt = Date()
                    report.autoFixed = true
                    repairedCount += 1
                    completeJob(repairJob,
                                result: "Kapitel \(chapterNumber) repariert",
                                tokens: repairTokens)
                } else {
                    addReport(project: project,
                              area: "Kapitel \(chapterNumber)",
                              type: "Nachbearbeitung",
                              result: "Reparaturantwort war unvollständig; Originalfassung blieb erhalten.",
                              severity: .warning,
                              recommendation: "Kapitel im Lektor-Chat manuell prüfen.")
                    completeJob(repairJob,
                                result: "Reparaturantwort unvollständig",
                                tokens: repairTokens)
                }
            } catch {
                failJob(repairJob, error: error)
                throw error
            }
        }

        modelContext?.saveOrLog()
        if repairedCount == 0 {
            return "Prüfung abgeschlossen: \(issues.count) Befund(e) gespeichert, aber keine kapitelgenaue automatische Reparatur ausgeführt."
        }
        var message = "Nachbearbeitung abgeschlossen: \(repairedCount) Kapitel repariert."
        if skippedCount > 0 || processedCount < issues.count {
            message += " \(max(skippedCount, issues.count - processedCount)) Befund(e) bleiben als Report zur manuellen Prüfung."
        }
        return message
    }

    private func targetedRepairPatch(
        source: String,
        project: Project,
        chapter: Chapter,
        issue: RepairIssue,
        config: ProviderConfiguration
    ) async throws -> (text: String, tokens: Int)? {
        var usedTokens = 0
        for attempt in 1...2 {
            let response = try await generate(
                prompt: """
                Repariere ausschließlich die konkrete Fehlerstelle in Kapitel
                \(chapter.chapterNumber) „\(chapter.title)“ aus „\(project.title)“.

                Problem: \(issue.problem)
                Auftrag: \(issue.instruction)

                Wähle einen zusammenhängenden Ausschnitt von 1 bis höchstens 8 Sätzen,
                der im KAPITELTEXT EXAKT und wörtlich vorkommt. SEARCH muss unverändert
                kopiert werden. REPLACE enthält nur die korrigierte Passage und muss
                nahtlos an den Text davor und danach anschließen. Keine Analyse, kein
                Markdown und keine Änderung außerhalb dieser Passage.

                Antworte exakt so:
                <<<SEARCH>>>
                [wörtlicher Originalausschnitt]
                <<<REPLACE>>>
                [korrigierter Ersatz]
                <<<END>>>

                Technischer Patch-Versuch \(attempt)/2.

                KAPITELTEXT:
                \(source.truncated(to: 36_000))
                """,
                system: project.isNonfiction
                    ? "Du bist ein präziser Sachbuchlektor und lieferst einen exakt anwendbaren Textpatch ohne erfundene Belege."
                    : "Du bist ein präziser Romanlektor und lieferst einen exakt anwendbaren Textpatch für den benannten Kontinuitätsfehler.",
                maxTokens: 2_500,
                temperature: 0.15,
                config: config,
                creative: true
            )
            usedTokens += response.tokensUsed ?? 0
            guard let patch = parseTargetedRepairPatch(response.text),
                  patch.search.count >= 20,
                  patch.search.count <= 8_000,
                  patch.replacement.count <= 10_000,
                  let range = source.range(of: patch.search) else {
                continue
            }

            var candidate = source
            candidate.replaceSubrange(range, with: patch.replacement)
            candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if AutonomousContentQuality.isAcceptableRewrite(
                   source: source,
                   candidate: candidate,
                   minRatio: 0.80,
                   maxRatio: 1.15,
                   finishReason: response.finishReason),
               withinGrowthCeiling(candidate, source: source, chapter: chapter),
               !AutonomousContentQuality.containsMetaRequest(candidate),
               !PublicContentGuard.disclosureViolation(in: candidate),
               ContentSafetyFilter.isSafe(candidate) {
                return (candidate, usedTokens)
            }
        }
        return nil
    }

    private func parseTargetedRepairPatch(_ text: String) -> (search: String, replacement: String)? {
        let searchMarker = "<<<SEARCH>>>"
        let replacementMarker = "<<<REPLACE>>>"
        let endMarker = "<<<END>>>"
        guard let searchStart = text.range(of: searchMarker),
              let replacementStart = text.range(
                  of: replacementMarker,
                  range: searchStart.upperBound..<text.endIndex
              ),
              let end = text.range(
                  of: endMarker,
                  range: replacementStart.upperBound..<text.endIndex
              ) else { return nil }

        let search = String(text[searchStart.upperBound..<replacementStart.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = String(text[replacementStart.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty, !replacement.isEmpty else { return nil }
        return (search, replacement)
    }

    // MARK: - Phase 10: Copyright-Prüfung (lokal)

    private func runCopyrightCheck(project: Project) {
        project.status = .copyrightCheck
        let job = beginJob(agent: AgentName.copyright, phase: .copyrightCheck, project: project)

        var findings: [String] = []
        let inputCheck = CopyrightChecker.checkInput(title: project.title, style: project.styleProfile)
        findings.append(contentsOf: inputCheck.warnings)
        if let premise = project.bookProfile?.premise {
            findings.append(contentsOf: CopyrightChecker.checkPlot(premise))
        }
        for chapter in sortedChapters(project) {
            findings.append(contentsOf: CopyrightChecker.checkPlot(chapter.title))
            if let text = chapter.bestText {
                findings.append(contentsOf: CopyrightChecker.checkManuscript(text))
            }
        }
        // Auch die Verkaufstexte prüfen – sie gehen mit nach Amazon.
        if let kdp = project.bookProfile?.kdpDescription, !kdp.isEmpty {
            findings.append(contentsOf: CopyrightChecker.checkManuscript(kdp))
        }
        findings = Array(Set(findings)) // Dubletten zusammenfassen

        if findings.isEmpty {
            addReport(project: project, area: "Copyright", type: "Originalitäts-Check",
                      result: "Originalitäts-Check bestanden – keine geschützten Werke, Figuren, Welten oder Songtexte in Titel, Text oder Verkaufstexten erkannt.", severity: .info,
                      recommendation: "Interne Prüfung, keine juristische Garantie.")
        } else {
            for finding in findings {
                addReport(project: project, area: "Copyright", type: "Risikoanalyse",
                          result: finding, severity: .warning,
                          recommendation: "Formulierung prüfen und ggf. anpassen.")
            }
        }
        completeJob(job, result: findings.isEmpty ? "Unauffällig" : "\(findings.count) Hinweise")
    }

    // MARK: - Phase 11: KDP-Formatierung / Qualitätsbewertung

    private func runKDPFormatting(project: Project, config: ProviderConfiguration) async throws {
        project.status = .kdpFormatting

        // KDP-Metadaten (Verkaufstext, Keywords, Kategorien) generieren. Bei einem
        // früheren Teilergebnis wird die Phase erneut ausgeführt, statt ein Buch ohne
        // vollständige Verkaufsseite als fertig zu markieren.
        if let profile = project.bookProfile, needsKDPMetadata(project: project, profile: profile) {
            let metaJob = beginJob(agent: AgentName.kdpFormatter, phase: .kdpFormatting, project: project)
            do {
                let response = try await generate(
                    prompt: PromptFactory.kdpMetadata(
                        title: project.title, author: project.authorName,
                        authorBio: project.authorBio,
                        genre: project.genre, audience: profile.targetAudience,
                        synopsis: actualStorySynopsis(for: project, fallback: profile.synopsis ?? profile.premise),
                        language: project.language, tropes: project.tropes,
                        spiceLevel: project.spiceLevel
                    ),
                    system: "Du bist ein erfahrener Buchmarketing-Texter für Amazon KDP. Deine Produktbeschreibungen verkaufen.",
                    maxTokens: 1200, temperature: 0.7, config: config
                )
                let parsed = KDPMetadataParser.parse(response.text)
                let description = parsed.salesDescription.isEmpty ? response.text : parsed.salesDescription
                let publicFields = [description, parsed.keywords, parsed.categories,
                                    parsed.salesTitle, parsed.subtitle]
                guard !publicFields.contains(where: PublicContentGuard.disclosureViolation) else {
                    throw AIError.systemError("KDP-Metadaten enthalten einen Produktionshinweis.")
                }
                profile.kdpDescription = description
                profile.kdpKeywords = parsed.keywords
                profile.kdpCategories = parsed.categories
                profile.kdpTitle = parsed.salesTitle.isEmpty ? project.title : parsed.salesTitle
                profile.kdpSubtitle = parsed.subtitle
                // VIRALER VERKAUFSTITEL: 10 Kandidaten (grounded in der Story) generieren und den
                // mit dem stärksten Kauf-Sog wählen – klare, neugierig machende Titel statt schwacher.
                let synopsisForTitle = actualStorySynopsis(for: project, fallback: profile.synopsis ?? profile.premise)
                if let titleResp = try? await generate(
                    prompt: PromptFactory.viralTitles(genre: project.genre, premise: synopsisForTitle, language: project.language),
                    system: "Du bist Profi für virale Buchtitel im deutschsprachigen Amazon-KDP-Markt. Antworte nur im geforderten Format.",
                    maxTokens: 600, temperature: 0.85, config: config, creative: true) {
                    let viral = AutonomousContentQuality.chooseViralTitle(from: titleResp.text, genre: project.genre)
                    // Nur übernehmen, wenn der Titel im geschriebenen Buch VORKOMMT –
                    // ein erfundener Titel enttäuscht nach dem Klick und kostet Ranking.
                    let kapitelTexte = sortedChapters(project).map { $0.finalText ?? $0.revisedText ?? $0.draftText ?? "" }
                    if AutonomousContentQuality.isUsableTitle(viral, genre: project.genre),
                       AutonomousContentQuality.titleIsCoveredByBook(viral, chapters: kapitelTexte) {
                        profile.kdpTitle = viral
                        // Schwachen/Platzhalter-Buchtitel durch den viralen Titel ersetzen.
                        if AutonomousContentQuality.isWeakTitle(project.title, genre: project.genre) {
                            project.title = viral
                        }
                    }
                }
                // Falls noch ein Platzhalter steht, den Verkaufstitel übernehmen.
                if AutonomousContentQuality.isWeakTitle(project.title, genre: project.genre),
                   !AutonomousContentQuality.isWeakTitle(profile.kdpTitle, genre: project.genre) {
                    project.title = profile.kdpTitle
                }
                completeJob(metaJob, result: response.text, tokens: response.tokensUsed ?? 0)
            } catch {
                failJob(metaJob, error: error)
                // Marketing-Metadaten sind nicht produktionskritisch – nur bei
                // Abbruch oder echtem Provider-Kontingentfehler die Pipeline stoppen.
                if error is CancellationError || (error as? AIError) == .quotaExceeded {
                    throw error
                }
                addReport(project: project, area: "KDP-Metadaten", type: "Metadaten",
                          result: "Metadaten konnten nicht generiert werden: \(error.localizedDescription)",
                          severity: .warning,
                          recommendation: "Phase erneut ausführen oder Metadaten manuell verfassen.")
            }
        }

        let job = beginJob(agent: AgentName.kdpFormatter, phase: .kdpFormatting, project: project)

        // Alte Score-Berichte ersetzen (bei Wiederholung keine Duplikate).
        if let stale = project.qualityReports?.filter({ $0.checkType == "Score" }) {
            for report in stale { modelContext?.delete(report) }
            project.qualityReports?.removeAll { $0.checkType == "Score" }
        }

        let scores = QualityScores.compute(for: project)
        let entries: [(String, Double)] = [
            ("Struktur", scores.structure),
            (project.isNonfiction ? "Lesernutzen" : "Figuren", scores.characters),
            ("Stil", scores.style),
            ("Konsistenz", scores.consistency),
            ("KDP-Format", scores.kdp)
        ]
        for (name, value) in entries {
            addReport(project: project, area: name, type: "Score",
                      result: String(format: "%.0f%%", value * 100),
                      severity: value >= 0.7 ? .info : .warning,
                      recommendation: value >= 0.7 ? "" : "Bereich \(name) prüfen.")
        }

        completeJob(job, result: ExportEngine.generateKDPReport(project: project))
    }

    // MARK: - Phase 12: Export

    private func runExport(project: Project, config: ProviderConfiguration) async throws {
        // Bereits die Endabnahme ist aktive Exportarbeit. Der vorherige Status kann
        // `paused` sein; ihn erst nach allen Reparaturen zu ändern ließ Dashboard und
        // Projektseite während eines laufenden Jobs fälschlich „Pausiert" anzeigen.
        project.status = .export
        project.updatedAt = Date()
        modelContext?.saveOrLog()
        try await runFinalReadinessRepairs(project: project, config: config)
        try PublicationReadiness.validateForCompletion(project: project)
        let job = beginJob(agent: AgentName.exporter, phase: .export, project: project)

        do {
            var exported: [String] = []
            let formats = Set(project.outputFormats)
            let snapshot: BookExportSnapshot? = formats.isDisjoint(with: ["EPUB", "PDF", "DOCX"])
                ? nil
                : try ExportEngine.prepareSnapshot(for: project)
            if formats.contains("EPUB"), let snapshot {
                exported.append((try await ExportEngine.exportPreparedToEPUBInBackground(snapshot)).path)
            }
            if formats.contains("PDF"), let snapshot {
                exported.append((try await ExportEngine.exportPreparedToPDFInBackground(snapshot)).path)
            }
            if formats.contains("DOCX"), let snapshot {
                exported.append((try await ExportEngine.exportPreparedToDOCXInBackground(snapshot)).path)
            }
            completeJob(job, result: exported.isEmpty ? "Keine Formate ausgewählt" : exported.joined(separator: "\n"))
        } catch is CancellationError {
            // Stop/Pause unverändert bis zum zentralen Handler weiterreichen. So
            // wird das laufende Projekt nicht fälschlich als Exportfehler markiert.
            throw CancellationError()
        } catch {
            failJob(job, error: error)
            throw AIError.systemError("Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Die Freigabe ist kein Endpunkt, der ein fast fertiges Buch einfach verwirft.
    /// Bis zu drei gezielte Runden beheben die tatsächlich gemeldeten Blocker und
    /// prüfen anschließend das vollständige Manuskript erneut.
    /// Bis zu so viele Reparaturdurchläufe pro Produktionslauf. Bewusst hoch: Die
    /// Produktion soll sich selbst so lange korrigieren, bis das Buch die Abnahme
    /// besteht – nicht nach wenigen Versuchen aufgeben. Die Modell-Reparaturen sind
    /// stochastisch, ein zunächst gescheiterter Versuch gelingt oft im nächsten Anlauf.
    private static let maxReadinessPasses = 10

    private func runFinalReadinessRepairs(project: Project,
                                          config: ProviderConfiguration) async throws {
        // Nichts zu reparieren → keine Reparaturzeit anzeigen.
        let startingIssues = PublicationReadiness.completionBlockingIssues(project: project)
        if startingIssues.isEmpty { return }
        // Reparaturzeit ab jetzt sichtbar mitzählen – über automatische
        // Selbstkorrektur-Runden hinweg (nur beim ersten Eintritt starten).
        if repairStartedAt == nil {
            repairStartedAt = Date()
            repairIssuesTotal = startingIssues.count
        }
        // Basislinie ggf. anheben (falls beim Fortsetzen mehr Punkte offen sind),
        // damit der Fortschritt nie über 100 % springt.
        repairIssuesTotal = max(repairIssuesTotal, startingIssues.count)
        repairIssuesRemaining = startingIssues.count
        updateProductionTiming()

        var bestCount = Int.max
        var stalledPasses = 0

        for pass in 1...Self.maxReadinessPasses {
            try Task.checkCancellation()
            let issues = PublicationReadiness.completionBlockingIssues(project: project)
            if issues.isEmpty { repairIssuesRemaining = 0; repairStartedAt = nil; updateProductionTiming(); return }

            currentAgent = "Finale Qualitätsreparatur \(pass) – \(issues.count) offene Punkte"
            // Das Ganz-Kapitel-Repair-Audit läuft pro Produktionslauf GENAU EINMAL.
            // Wiederholte Kapitel-Neufassungen erzeugten in jeder Runde NEUE
            // Satzdoppler gegen andere Kapitel und ließen Kapitel wieder wachsen –
            // ein divergierendes Feedback (beobachtet: Doppler 2→8, K55 1,53→1,88×).
            // Spätere Runden arbeiten nur noch chirurgisch (Verdichtung, Satzdoppler).
            if !readinessRepairAuditDone,
               issues.contains(where: { $0.contains("Offene Qualitätsbefunde") }) {
                readinessRepairAuditDone = true
                _ = try await runRepairWorkflow(project: project, config: config)
            }
            if issues.contains(where: { $0.contains("über Zielumfang") }) {
                try await runFinalSizingCleanup(project: project, config: config)
            }
            if issues.contains(where: { $0.contains("wiederholte ganze Sätze") }) {
                try await runRepeatedSentenceCleanup(project: project, config: config)
            }

            project.updatedAt = Date()
            modelContext?.saveOrLog()

            let refreshed = PublicationReadiness.completionBlockingIssues(project: project)
            // Fortschritt aktualisieren (offene Punkte + Restzeit-Schätzung).
            repairIssuesTotal = max(repairIssuesTotal, refreshed.count)
            repairIssuesRemaining = refreshed.count
            updateProductionTiming()   // Reparaturzeit + Restschätzung nach jedem Durchlauf
            if refreshed.isEmpty { repairIssuesRemaining = 0; repairStartedAt = nil; updateProductionTiming(); return }

            if refreshed.count < bestCount {
                bestCount = refreshed.count
                stalledPasses = 0
            } else {
                stalledPasses += 1
            }

            // Bleiben ausschließlich Punkte übrig, die diese Reparaturen NICHT beheben
            // können (z.B. fehlende Metadaten/Impressum), bringt Weiterlaufen nichts.
            let hasRepairableIssue = refreshed.contains {
                $0.contains("Offene Qualitätsbefunde")
                    || $0.contains("über Zielumfang")
                    || $0.contains("wiederholte ganze Sätze")
            }
            if !hasRepairableIssue { break }
            // Kein Fortschritt über mehrere Durchläufe → dieser Lauf ist ausgereizt;
            // der übergeordnete Loop setzt (begrenzt) automatisch fort statt zu verwerfen.
            if stalledPasses >= 3 { break }
        }

        let remaining = PublicationReadiness.completionBlockingIssues(project: project)
        guard !remaining.isEmpty else { repairIssuesRemaining = 0; repairStartedAt = nil; updateProductionTiming(); return }
        repairIssuesRemaining = remaining.count
        // Nicht bestanden: Reparaturuhr WEITERLAUFEN lassen – die Selbstkorrektur
        // setzt automatisch fort, die angezeigte Reparaturzeit umfasst alle Runden.
        throw AIError.systemError(
            "\(Self.readinessShortfallMarker): \(remaining.joined(separator: " "))"
        )
    }

    /// Erkennungsmarke für „Buch fertig geschrieben, aber Qualitäts-Endabnahme noch
    /// nicht bestanden". Solche Fälle werden NICHT als endgültiger Fehlschlag behandelt
    /// (Buch verwerfen), sondern führen zu begrenzter automatischer Weiterarbeit.
    static let readinessShortfallMarker = "Finale Qualitätsreparatur noch nicht abgeschlossen"

    /// Kurze Pause zwischen zwei automatischen Reparaturläufen (schont den Provider,
    /// hält die Selbstkorrektur aber zügig).
    static let readinessRetryDelaySeconds: Double = 15

    /// Ist der Fehler „Buch fertig, aber Qualitäts-Endabnahme noch offen"? Nur dann
    /// wird selbstkorrigierend weitergearbeitet statt zu verwerfen.
    static func isReadinessShortfall(_ error: Error) -> Bool {
        guard let aiError = error as? AIError else { return false }
        let text = aiError.errorDescription ?? "\(aiError)"
        return text.contains(Self.readinessShortfallMarker)
    }

    private func runFinalSizingCleanup(project: Project,
                                       config: ProviderConfiguration) async throws {
        for chapter in sortedChapters(project) {
            try Task.checkCancellation()
            guard let source = chapter.bestText,
                  chapter.targetWordCount > 0,
                  Double(source.wordCount) > Double(chapter.targetWordCount)
                    * PublicationReadiness.maximumChapterWordRatio else { continue }

            let job = beginJob(agent: AgentName.reviser, phase: .chapterRevision,
                               project: project, chapter: chapter.chapterNumber)
            var accepted: String?
            var tokens = 0
            do {
                for attempt in 1...3 where accepted == nil {
                    let response = try await generate(
                        prompt: """
                        Verdichte Kapitel \(chapter.chapterNumber) „\(chapter.title)“ aus „\(project.title)“
                        auf \(chapter.targetWordCount) Wörter, Toleranz -20% bis +25%.
                        Bewahre alle Ereignisse, Enthüllungen, Entscheidungen, Figureninformationen,
                        Szenentrenner und den Anschluss an das nächste Kapitel. Entferne ausschließlich
                        Redundanz, doppelte Bilder und Wiederholungen. Keine Zusammenfassung, keine
                        Kommentare. Gib nur das vollständige Kapitel mit vollständigem Satzende zurück.
                        Technischer Versuch \(attempt)/2.

                        KAPITELTEXT:
                        \(source)
                        """,
                        system: project.isNonfiction
                            ? "Du bist ein präziser Sachbuchlektor und verdichtest ohne Wissensverlust."
                            : "Du bist ein präziser Romanlektor und verdichtest ohne Handlungsverlust.",
                        maxTokens: min(12_000, max(4_000, chapter.targetWordCount * 4)),
                        temperature: 0.25,
                        config: config,
                        creative: true
                    )
                    tokens += response.tokensUsed ?? 0
                    let candidate = AutonomousContentQuality.humanizeProse(
                        AutonomousContentQuality.strippingInlineFormatting(
                            AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // FORTSCHRITTS-RATSCHE: Ideal ist eine Fassung im Zielband (0,65–1,30×).
                    // Verfehlt das Modell das Band, wird trotzdem jede Fassung übernommen,
                    // die das Kapitel um >=12 % verkürzt (und nicht unter das Band fällt).
                    // So schrumpft ein stark übergroßes Kapitel über die Runden monoton
                    // auf das Ziel, statt an der Alles-oder-nichts-Abnahme zu scheitern.
                    let withinBand = AutonomousContentQuality.isWithinWordTarget(
                        candidate, targetWords: chapter.targetWordCount,
                        lowerRatio: 0.65, upperRatio: 1.30)
                    let meaningfulShrink = candidate.wordCount <= Int(Double(source.wordCount) * 0.88)
                        && Double(candidate.wordCount) >= Double(chapter.targetWordCount) * 0.65
                    if withinBand || meaningfulShrink,
                       AutonomousContentQuality.isAcceptableRewrite(
                           source: source, candidate: candidate,
                           minRatio: 0.62, finishReason: response.finishReason),
                       !PublicContentGuard.disclosureViolation(in: candidate),
                       ContentSafetyFilter.isSafe(candidate) {
                        accepted = candidate
                    }
                }
            } catch {
                failJob(job, error: error)
                throw error
            }

            // SZENENWEISE VERDICHTUNG (Fallback): Die Ganz-Kapitel-Verdichtung scheitert
            // regelmäßig daran, dass das Modell Szenentrenner (***) verliert oder das
            // Zielband knapp verfehlt – dann wurde ALLES verworfen und das Kapitel blieb
            // dauerhaft zu lang. Szenenweise bleiben die Trenner per Konstruktion
            // erhalten, jedes Teilstück ist klein genug, und JEDER gelungene Abschnitt
            // zählt (Fortschritts-Ratsche statt Alles-oder-nichts).
            if accepted == nil {
                let segments = source.components(separatedBy: "***")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if segments.count > 1, chapter.targetWordCount > 0 {
                    let shrinkFactor = max(0.6, Double(chapter.targetWordCount) / Double(max(1, source.wordCount)))
                    var rebuilt: [String] = []
                    var shrunkAny = false
                    for segment in segments {
                        let segTarget = max(120, Int(Double(segment.wordCount) * shrinkFactor))
                        // Abschnitte, die ihr anteiliges Ziel schon (fast) halten, unangetastet lassen.
                        guard segment.wordCount > Int(Double(segTarget) * 1.15) else {
                            rebuilt.append(segment); continue
                        }
                        do {
                            let response = try await generate(
                                prompt: """
                                Verdichte diesen Szenenabschnitt aus Kapitel \(chapter.chapterNumber) „\(chapter.title)“
                                auf etwa \(segTarget) Wörter. Bewahre alle Ereignisse, Enthüllungen,
                                Entscheidungen, Figureninformationen und den Anschluss an Anfang und Ende.
                                Entferne ausschließlich Redundanz, doppelte Bilder und Wiederholungen.
                                Gib nur den verdichteten Abschnitt als reinen Fließtext zurück.

                                ABSCHNITT:
                                \(segment)
                                """,
                                system: project.isNonfiction
                                    ? "Du bist ein präziser Sachbuchlektor und verdichtest ohne Wissensverlust."
                                    : "Du bist ein präziser Romanlektor und verdichtest ohne Handlungsverlust.",
                                maxTokens: min(6_000, max(1_200, segTarget * 4)),
                                temperature: 0.25,
                                config: config,
                                creative: true
                            )
                            tokens += response.tokensUsed ?? 0
                            let cand = AutonomousContentQuality.humanizeProse(
                                AutonomousContentQuality.strippingInlineFormatting(
                                    AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            // Ratsche: übernehmen, sobald der Abschnitt spürbar kürzer ist
                            // (>=8 %) und nicht abgeschnitten/unsicher.
                            if !cand.isEmpty,
                               cand.wordCount <= Int(Double(segment.wordCount) * 0.92),
                               cand.wordCount >= Int(Double(segTarget) * 0.55),
                               !AutonomousContentQuality.isLikelyTruncated(cand, finishReason: response.finishReason),
                               !AutonomousContentQuality.containsMetaRequest(cand),
                               !PublicContentGuard.disclosureViolation(in: cand),
                               ContentSafetyFilter.isSafe(cand) {
                                rebuilt.append(cand)
                                shrunkAny = true
                            } else {
                                rebuilt.append(segment)
                            }
                        } catch {
                            if isFatalProductionError(error) { failJob(job, error: error); throw error }
                            rebuilt.append(segment)
                        }
                    }
                    if shrunkAny {
                        accepted = rebuilt.joined(separator: "\n\n***\n\n")
                    }
                }
            }

            if let accepted {
                chapter.finalText = accepted
                chapter.actualWordCount = accepted.wordCount
                chapter.status = .finalized
                chapter.updatedAt = Date()
                completeJob(job, result: "Kapitel auf Zielumfang verdichtet", tokens: tokens)
            } else {
                completeJob(job, result: "Verdichtung verworfen – vollständiger Text behalten",
                            tokens: tokens)
            }
        }
    }

    private func runRepeatedSentenceCleanup(project: Project,
                                            config: ProviderConfiguration) async throws {
        let chapters = sortedChapters(project)
        // Nur freigabe-blockierende Wiederholungen gezielt entfernen. Kurze natürliche
        // Dialogbeats bleiben erlaubt; längere wortgleiche Sätze werden absatzweise ersetzt.
        let repeats = AutonomousContentQuality.blockingRepeatedSentences(
            inChapters: chapters.map { $0.bestText ?? "" }
        )
        guard !repeats.isEmpty else { return }

        for chapter in chapters {
            try Task.checkCancellation()
            guard let source = chapter.bestText, !source.isEmpty else { continue }
            let localRepeats = repeats.filter {
                source.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            guard !localRepeats.isEmpty else { continue }

            let job = beginJob(agent: AgentName.repairEditor,
                               phase: .manuscriptRevision,
                               project: project,
                               chapter: chapter.chapterNumber)
            // CHIRURGISCH: Nur die Absätze anfassen, die ein Duplikat enthalten. Der
            // frühere Ansatz ließ das GANZE Kapitel neu schreiben – bei längeren
            // Kapiteln wurde die Antwort abgeschnitten/zu kurz, das Gate verwarf sie,
            // und das Original MIT den Wiederholungen blieb stehen. Absatzweise ist der
            // Input klein (keine Abschneidung), ein Fehlschlag betrifft nur EINEN Absatz,
            // und der Rest des Kapitels bleibt unverändert erhalten.
            var paragraphs = source.components(separatedBy: "\n\n")
            var tokens = 0
            var fixedCount = 0
            var failedCount = 0
            do {
                for (index, paragraph) in paragraphs.enumerated() {
                    try Task.checkCancellation()
                    let hits = localRepeats.filter {
                        paragraph.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                    }
                    guard !hits.isEmpty else { continue }
                    // Szenentrenner/Kurzzeilen (z.B. „***") nicht anfassen.
                    guard paragraph.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else { continue }

                    let duplicateList = hits.map { "- \($0)" }.joined(separator: "\n")
                    let comparisonTexts = chapters.compactMap { other -> String? in
                        guard other.id != chapter.id else { return nil }
                        return other.bestText
                    } + paragraphs.enumerated().compactMap { paragraphIndex, text in
                        paragraphIndex == index ? nil : text
                    }
                    // Kollisionen, die der Absatz SCHON HAT (unveränderte Nachbarsätze),
                    // dürfen die Annahme nicht verhindern – sonst ist jeder Kandidat
                    // chancenlos, weil er die instruierten unveränderten Sätze behält.
                    // Verboten sind nur NEU EINGEFÜHRTE Kollisionen.
                    let preexistingCollisions = Set(AutonomousContentQuality.repeatedSentenceCollisions(
                        candidate: paragraph, priorTexts: comparisonTexts))
                    var replaced: String?
                    for attempt in 1...2 where replaced == nil {
                        let response = try await generate(
                            prompt: """
                            Formuliere in diesem Absatz NUR die folgenden wörtlich mehrfach im Buch \
                            vorkommenden Sätze neu, jeweils passend aus dem unmittelbaren Kontext:
                            \(duplicateList)

                            Lass alles andere unverändert. Bewahre Handlung, Fakten, Dialogbedeutung, \
                            Perspektive, Stimme, Zeitform und die ungefähre Länge. Erzeuge keine neue \
                            Standardformulierung, die an mehreren Stellen identisch wäre. Gib nur den \
                            überarbeiteten Absatz als reinen Fließtext zurück.
                            Technischer Versuch \(attempt)/2.

                            ABSATZ:
                            \(paragraph)
                            """,
                            system: "Du bist ein chirurgisch arbeitender Schlusslektor für abwechslungsreiche, natürliche Buchprosa.",
                            maxTokens: min(4_000, max(600, paragraph.wordCount * 4)),
                            temperature: 0.4,
                            config: config,
                            creative: true
                        )
                        tokens += response.tokensUsed ?? 0
                        let candidate = AutonomousContentQuality.humanizeProse(
                            AutonomousContentQuality.strippingInlineFormatting(
                                AutonomousContentQuality.strippingPromptArtifacts(response.text)))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        // Erfolg nur, wenn das Duplikat wirklich verschwunden ist und der
                        // Absatz sonst intakt/plausibel bleibt.
                        let stillDuplicated = hits.contains {
                            candidate.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                        }
                        if !candidate.isEmpty,
                           !stillDuplicated,
                           AutonomousContentQuality.isAcceptableRewrite(
                               source: paragraph, candidate: candidate,
                               minRatio: 0.6,
                               maxRatio: 1.25,   // Absatz-Neufassung darf nicht aufpolstern
                               finishReason: response.finishReason),
                           !AutonomousContentQuality.containsMetaRequest(candidate),
                           !PublicContentGuard.disclosureViolation(in: candidate),
                           AutonomousContentQuality.repeatedSentenceCollisions(
                               candidate: candidate,
                               priorTexts: comparisonTexts
                           ).allSatisfy({ preexistingCollisions.contains($0) }),
                           ContentSafetyFilter.isSafe(candidate) {
                            replaced = candidate
                        }
                    }
                    // SATZ-CHIRURGIE (letzter Schritt): Absatz-Neufassungen scheitern an
                    // vielen Nebenbedingungen. Minimalinvasiv und hochzuverlässig ist es,
                    // NUR die doppelte Formulierung selbst neu zu formulieren und im
                    // Absatz per Textersatz auszutauschen.
                    if replaced == nil {
                        var working = paragraph
                        var surgeryWorked = false
                        for hit in hits {
                            guard let range = working.range(
                                of: hit, options: [.caseInsensitive, .diacriticInsensitive]
                            ) else { continue }
                            do {
                                let response = try await generate(
                                    prompt: """
                                    Formuliere diese Formulierung neu: gleicher Sinn, gleiche Zeitform und \
                                    Perspektive, aber völlig andere Wortwahl (keine Teilphrase übernehmen). \
                                    Gib NUR die neue Formulierung ohne Anführungszeichen zurück.

                                    KONTEXT (Absatz): \(paragraph)

                                    FORMULIERUNG: \(hit)
                                    """,
                                    system: "Du bist ein präziser Lektor. Du lieferst exakt eine Ersatzformulierung.",
                                    maxTokens: 220, temperature: 0.7, config: config, creative: true
                                )
                                tokens += response.tokensUsed ?? 0
                                let replacement = response.text
                                    .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\"„“”»«'"))
                                let sane = !replacement.isEmpty
                                    && replacement.wordCount <= hit.wordCount * 2 + 4
                                    && replacement.wordCount >= max(3, hit.wordCount / 2)
                                    && replacement.range(of: hit, options: [.caseInsensitive, .diacriticInsensitive]) == nil
                                    && !replacement.contains("\n")
                                    && !AutonomousContentQuality.containsMetaRequest(replacement)
                                    && ContentSafetyFilter.isSafe(replacement)
                                if sane {
                                    working.replaceSubrange(range, with: replacement)
                                    surgeryWorked = true
                                }
                            } catch {
                                if isFatalProductionError(error) { throw error }
                            }
                        }
                        if surgeryWorked { replaced = working }
                    }
                    if let replaced {
                        paragraphs[index] = replaced
                        fixedCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            } catch {
                failJob(job, error: error)
                throw error
            }

            if fixedCount > 0 {
                let rebuilt = paragraphs.joined(separator: "\n\n")
                chapter.finalText = rebuilt
                chapter.actualWordCount = rebuilt.wordCount
                chapter.status = .finalized
                chapter.updatedAt = Date()
            }
            let resultNote: String
            if fixedCount > 0 && failedCount == 0 {
                resultNote = "Satzduplikate chirurgisch bereinigt (\(fixedCount) Absätze)"
            } else if fixedCount > 0 {
                resultNote = "Satzduplikate teilweise bereinigt (\(fixedCount) ok, \(failedCount) offen)"
            } else {
                resultNote = "Duplikat-Bereinigung unvollständig – Original behalten"
            }
            completeJob(job, result: resultNote, tokens: tokens)
        }
    }

    // MARK: - Hilfsfunktionen

    private func estimatedChapterCount(for project: Project) -> Int {
        productionPlan(for: project).chapterCount
    }

    private func productionPlan(for project: Project) -> LongFormProductionPlan {
        let seed = NarrativeSignature.stableSeed(
            "\(project.id.uuidString)|\(project.title)|\(project.genre)|chapter-rhythm"
        )
        let variation = Int(seed % 7) - 3
        let wordsGoal: Int
        if project.isNonfiction {
            wordsGoal = 3_200 + Int((seed >> 8) % 901)
        } else {
            wordsGoal = 2_250 + Int((seed >> 8) % 751)
        }
        return LongFormProductionPlan(pageCount: project.targetPageCount,
                                      wordsPerChapterGoal: wordsGoal,
                                      chapterVariation: variation)
    }

    private func targetWordsByChapter(project: Project, count: Int) -> [Int] {
        variedWordTargets(total: project.targetWordCount, count: count,
                          seedKey: "\(project.id.uuidString)|chapters",
                          spread: project.isNonfiction ? 0.14 : 0.24)
    }

    private func variedWordTargets(total: Int, count: Int, seedKey: String,
                                   spread: Double) -> [Int] {
        guard count > 0 else { return [] }
        let weights: [Double] = (0..<count).map { index in
            let seed = NarrativeSignature.stableSeed("\(seedKey)|\(index + 1)")
            let unit = Double(seed % 10_001) / 10_000.0
            return 1.0 - spread + unit * spread * 2.0
        }
        let totalWeight = weights.reduce(0, +)
        var targets = weights.map {
            max(1, Int((Double(total) * $0 / totalWeight).rounded()))
        }
        let difference = total - targets.reduce(0, +)
        targets[targets.count - 1] = max(1, targets[targets.count - 1] + difference)
        return targets
    }

    private func sortedChapters(_ project: Project) -> [Chapter] {
        (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private func needsKDPMetadata(project: Project, profile: BookProfile) -> Bool {
        let required = [profile.kdpTitle, profile.kdpDescription,
                        profile.kdpKeywords, profile.kdpCategories]
        if required.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return true
        }
        return [profile.kdpTitle, profile.kdpSubtitle, profile.kdpDescription,
                profile.kdpKeywords, profile.kdpCategories, project.authorBio]
            .contains(where: PublicContentGuard.disclosureViolation)
    }

    private func sortedScenes(_ chapter: Chapter) -> [StoryScene] {
        (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }
    }

    private func isSceneWritten(_ scene: StoryScene) -> Bool {
        guard let text = scene.text, !text.isEmpty else { return false }
        guard AutonomousContentQuality.isWithinWordTarget(
            text, targetWords: scene.targetWordCount,
            lowerRatio: 0.55, upperRatio: 1.35
        ), AutonomousContentQuality.hasCompleteSentenceEnding(text),
           !AutonomousContentQuality.containsMetaRequest(text) else {
            return false
        }
        guard AutonomousContentQuality.clarityAssessment(text).isAcceptable,
              !AutonomousContentQuality.soundsLikeAI(text),
              !AutonomousContentQuality.containsPromptArtifacts(text),
              !AutonomousContentQuality.containsMetaRequest(text),
              !PublicContentGuard.disclosureViolation(in: text),
              ContentSafetyFilter.isSafe(text) else {
            return false
        }
        return scene.status == .written || scene.status == .finalized || scene.status == .checking
    }

    private func resolveSceneReports(project: Project, chapterNumber: Int, sceneNumber: Int) {
        let area = "Kapitel \(chapterNumber), Szene \(sceneNumber)"
        let resolvedTypes = Set([
            "Stil", "Klarheit", "Wiederholung", "Umfang", "Rohfassung", "Szenen-Neufassung"
        ])
        for report in project.qualityReports ?? []
        where report.checkedArea == area && resolvedTypes.contains(report.checkType) {
            report.autoFixed = true
        }
    }

    private func hasUsableExistingChapterPlan(_ chapters: [Chapter]) -> Bool {
        let planned = chapters.map {
            PlannedChapter(number: $0.chapterNumber, title: $0.title,
                           goal: $0.goal, conflict: $0.conflict)
        }
        return AutonomousContentQuality.hasUsableChapterPlan(planned)
    }

    private func hasUsableExistingScenePlan(_ chapter: Chapter, expectedCount: Int) -> Bool {
        let planned = sortedScenes(chapter).map {
            PlannedScene(number: $0.sceneNumber, perspective: $0.perspective,
                         location: $0.location, time: $0.time,
                         goal: $0.goal, obstacle: $0.obstacle, turn: $0.cliffhanger)
        }
        return AutonomousContentQuality.hasUsableScenePlan(planned, expectedCount: expectedCount)
    }

    private func resetChapterPlan(for project: Project) {
        for chapter in project.chapters ?? [] {
            modelContext?.delete(chapter)
        }
        project.chapters = []
        project.updatedAt = Date()
        modelContext?.saveOrLog()
    }

    private func resetScenePlan(for chapter: Chapter) {
        // SCHUTZ vor Datenverlust beim Fortsetzen: Enthält das Kapitel bereits GESCHRIEBENE
        // Prosa (Draft/Revision/Endfassung oder Szenentext), NICHT zurücksetzen. Sonst würde
        // ein nachträglich geänderter Zielumfang (z. B. via „Buch erweitern") oder ein
        // strengeres Qualitäts-Heuristik-Urteil einen bereits fertig geschriebenen Text
        // löschen. Ohne Prosa ist das Neuplanen unbedenklich.
        let hasWrittenProse = !(chapter.draftText ?? "").isEmpty
            || !(chapter.revisedText ?? "").isEmpty
            || !(chapter.finalText ?? "").isEmpty
            || (chapter.scenes ?? []).contains { !($0.text ?? "").isEmpty }
        guard !hasWrittenProse else { return }

        for scene in chapter.scenes ?? [] {
            modelContext?.delete(scene)
        }
        chapter.scenes = []
        chapter.draftText = nil
        chapter.revisedText = nil
        chapter.finalText = nil
        chapter.summary = nil
        chapter.actualWordCount = 0
        chapter.status = .planned
        chapter.updatedAt = Date()
        modelContext?.saveOrLog()
    }

    private func repairAuditSummaries(for chapters: [Chapter]) -> String {
        // Gesamt-Budget für echte Prosa-Auszüge, fair auf alle Kapitel verteilt,
        // damit auch lange Manuskripte (50+ Kapitel) den Kontext nicht sprengen.
        let proseBudget = 24_000
        let perChapter = chapters.isEmpty ? 0 : max(360, proseBudget / chapters.count)
        return chapters.map { chapter in
            let summary = chapter.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let core = [chapter.goal, chapter.conflict]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
            // Echter Text (Anfang + Ende), damit der Audit Widersprüche und
            // Kontinuitätsbrüche IM Text findet, nicht nur in der Zusammenfassung.
            let fullText = (chapter.bestText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let prose: String
            if fullText.count > perChapter {
                let head = perChapter * 2 / 3
                let tail = perChapter - head
                prose = String(fullText.prefix(head)) + "\n[…]\n" + String(fullText.suffix(tail))
            } else {
                prose = fullText
            }
            return """
            Kapitel \(chapter.chapterNumber) (\(chapter.title)):
            Ziel/Konflikt: \(core.isEmpty ? "nicht angegeben" : core)
            Zusammenfassung: \(summary.isEmpty ? "—" : summary)
            Textauszug: \(prose.isEmpty ? "(noch kein Text)" : prose)
            """
        }.joined(separator: "\n\n")
    }

    private func repairReportsForAudit(_ project: Project) -> [QualityReport] {
        let candidates = (project.qualityReports ?? [])
            .filter {
                $0.checkType != "Score"
                    && $0.checkType != "KI-Nachbearbeitung"
                    && $0.checkType != "Nachbearbeitung"
            }
            .sorted { $0.createdAt < $1.createdAt }
        let blockers = candidates.filter {
            !$0.autoFixed && ($0.severity == .critical || $0.severity == .error)
        }
        let recentContext = candidates.suffix(24)
        var seen = Set<UUID>()
        return (blockers + recentContext).filter { seen.insert($0.id).inserted }
    }

    private func repairReportBrief(_ reports: [QualityReport]) -> String {
        return reports.map { report in
            "\(report.severity.rawValue) | \(report.checkedArea.truncated(to: 120)) | "
                + "\(report.checkType): \(report.result.truncated(to: 360)) "
                + report.recommendation.truncated(to: 260)
        }.joined(separator: "\n")
    }

    private func compactCharacterSummary(_ bible: StoryBible) -> String {
        // ALLE kanonischen Merkmale durchreichen (eine Zeile pro Figur): Vorher fielen
        // Alter/Beruf/Angst weg – die häufigste Folge waren Figuren, deren Alter, Beruf
        // oder Sprechweise mitten im Buch driftete (klassischer 1-Stern-Trigger).
        (bible.characters ?? []).prefix(8).map { character in
            var line = "\(character.name) (\(character.role))"
            if !character.age.isEmpty { line += ", \(character.age)" }
            if !character.occupation.isEmpty { line += ", \(character.occupation)" }
            if !character.goal.isEmpty { line += " – Ziel: \(character.goal)" }
            if !character.fear.isEmpty { line += ", Angst: \(character.fear)" }
            if !character.weakness.isEmpty { line += ", Schwäche: \(character.weakness)" }
            if !character.speechPattern.isEmpty { line += ", Sprechweise: \(character.speechPattern)" }
            if !character.relationships.isEmpty { line += ", Beziehungen: \(character.relationships)" }
            if !character.importantFacts.isEmpty { line += ", Merkmale: \(character.importantFacts)" }
            return line
        }.joined(separator: "\n")
    }

    private func canonicalStoryContext(project: Project) -> String {
        guard let bible = project.storyBible else { return "" }
        return [
            primaryStoryCanon(project: project),
            "ERGÄNZENDE FIGURENPROFILE (dürfen dem Primärkanon nie widersprechen):\n\(compactCharacterSummary(bible))"
        ].filter { !$0.hasSuffix(": ") && !$0.hasSuffix(":\n") }
            .joined(separator: "\n\n")
    }

    private func primaryStoryCanon(project: Project) -> String {
        guard let profile = project.bookProfile, let bible = project.storyBible else { return "" }
        return [
            "PRIMÄRKANON – ausschließlich diese Quellen definieren Vorgeschichte und Beziehungen:",
            "PRÄMISSE: \(profile.premise)",
            "EXPOSÉ: \(profile.synopsis ?? "")",
            "PLOT: \(bible.plotPoints.truncated(to: 10_000))"
        ].joined(separator: "\n\n")
    }

    private func draftStoryCanon(characterSummary: String) -> String {
        return [
            characterSummary.isEmpty ? "" : "ZULÄSSIGE FIGURENPROFILE:\n\(characterSummary)",
            "Dies ist eine absichtlich szenenbegrenzte Positivliste. Prämisse, Exposé, spätere Figuren, "
                + "Plotpunkte und Enthüllungen sind nicht Teil des Schreibkontexts. Verwende ausschließlich "
                + "den aktuellen Szenenplan, die bisherige Handlung und die oben aufgeführten Figuren."
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    @discardableResult
    private func addReport(project: Project, area: String, type: String, result: String,
                           severity: Severity, recommendation: String) -> QualityReport {
        let report = QualityReport(checkedArea: area, checkType: type, result: result,
                                   severity: severity, recommendation: recommendation)
        if project.qualityReports == nil { project.qualityReports = [] }
        report.project = project
        project.qualityReports?.append(report)
        modelContext?.insert(report)
        return report
    }

    private func updateProgress(phase: PipelinePhase, subProgress: Double) {
        var total = 0.0
        for item in PipelinePhase.executionOrder {
            if item == phase { break }
            total += item.weight
        }
        total += phase.weight * min(max(subProgress, 0), 1)
        progress = min(total, 1.0)
        publishWorkerStatus()
    }

    private func updateEstimatedTime() {
        guard !sceneTimes.isEmpty, totalScenes > completedScenes else {
            estimatedTimeRemaining = ""
            return
        }
        let recent = sceneTimes.suffix(10)
        let avg = recent.reduce(0, +) / Double(recent.count)
        let remaining = avg * Double(totalScenes - completedScenes)

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        estimatedTimeRemaining = hours > 0 ? "\(hours) h \(minutes) min" : "\(max(minutes, 1)) min"
    }

    private func updateProductionTiming() {
        let timing = ProductionTiming(
            currentBookStartedAt: currentBookStartedAt,
            now: Date(),
            completedBookDurations: completedBookDurations,
            completedScenes: completedScenes,
            totalScenes: totalScenes,
            recentSceneDurations: Array(sceneTimes.suffix(10))
        )
        currentBookElapsed = timing.elapsedText
        currentBookEstimatedTotal = timing.estimatedTotalText
        if !timing.averageBookText.isEmpty {
            averageBookDuration = timing.averageBookText
        }
        if !timing.remainingText.isEmpty {
            estimatedTimeRemaining = timing.remainingText
        }
        if let repairStart = repairStartedAt {
            let elapsed = Date().timeIntervalSince(repairStart)
            repairElapsed = ProductionTiming.formatHumanDuration(elapsed)
            // Restzeit-Schätzung aus der bisherigen Fortschrittsrate: erledigte Punkte
            // pro verstrichener Zeit → hochgerechnet auf die noch offenen Punkte.
            let done = max(0, repairIssuesTotal - repairIssuesRemaining)
            if repairIssuesRemaining > 0, done > 0, elapsed > 5 {
                let secondsPerIssue = elapsed / Double(done)
                repairEtaText = ProductionTiming.formatHumanDuration(
                    secondsPerIssue * Double(repairIssuesRemaining))
            } else {
                repairEtaText = ""   // noch keine belastbare Schätzung
            }
        } else {
            repairElapsed = ""
            repairEtaText = ""
        }
        publishWorkerStatus()
    }

    private func recordCompletedBookDuration() {
        guard let currentBookStartedAt else { return }
        let duration = Date().timeIntervalSince(currentBookStartedAt)
        completedBookDurations.append(duration)
        lastBookDuration = ProductionTiming.formatHumanDuration(duration)

        let timing = ProductionTiming(
            currentBookStartedAt: nil,
            now: Date(),
            completedBookDurations: completedBookDurations,
            completedScenes: completedScenes,
            totalScenes: totalScenes,
            recentSceneDurations: Array(sceneTimes.suffix(10))
        )
        averageBookDuration = timing.averageBookText
    }
}
