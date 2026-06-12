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
    var costLimitPerBook: Double
    var maxBooks: Int          // 0 = unbegrenzt
    var parallelBooks: Int     // 1...10 parallel laufende Bücher
    var formats: [String]
    var imprint: String
    var authorBio: String

    static let randomToken = "Zufällig"
    static let genrePool = ["Thriller", "Roman", "Fantasy", "Science Fiction", "Krimi",
                            "Liebesroman", "Historischer Roman", "Horror", "Jugendbuch", "Abenteuer"]
    static let stylePool = ["düster", "literarisch", "dialogstark", "humorvoll", "episch",
                            "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch",
                            "actionreich", "psychologisch"]

    init(authorName: String, language: String, genre: String, style: String,
         pageCount: Int, costLimitPerBook: Double, maxBooks: Int,
         parallelBooks: Int = 1, formats: [String],
         imprint: String = "", authorBio: String = "") {
        self.init(authorName: authorName, language: language,
                  selectedGenres: genre == Self.randomToken ? [] : [genre],
                  style: style, pageCount: pageCount,
                  costLimitPerBook: costLimitPerBook, maxBooks: maxBooks,
                  parallelBooks: parallelBooks, formats: formats,
                  imprint: imprint, authorBio: authorBio)
    }

    init(authorName: String, language: String, selectedGenres: [String], style: String,
         pageCount: Int, costLimitPerBook: Double, maxBooks: Int,
         parallelBooks: Int = 1, formats: [String],
         imprint: String, authorBio: String) {
        self.authorName = authorName
        self.language = language
        self.selectedGenres = selectedGenres
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.style = style
        self.pageCount = min(max(pageCount, AppConstants.minPageCount), AppConstants.maxPageCount)
        self.costLimitPerBook = costLimitPerBook
        self.maxBooks = maxBooks
        self.parallelBooks = min(max(parallelBooks, 1), 10)
        self.formats = formats
        self.imprint = imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.authorBio = authorBio.trimmingCharacters(in: .whitespacesAndNewlines)
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
    @Published var averageBookDuration: String = ""
    @Published var lastBookDuration: String = ""
    @Published var activeUnlimitedBooks: Int = 0
    @Published var parallelUnlimitedBooks: Int = 1

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
    private var unlimitedConsecutiveFailures = 0
    private let gateway = ProviderGateway.shared

    private struct UnlimitedBookOutcome {
        var completed: Bool
        var cancelled: Bool
        var title: String
        var duration: TimeInterval
        var error: Error?
        var message: String
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
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
        if let limit = providerConfig.costLimit, limit > 0 {
            project.costLimitUSD = limit
        }

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
        usedTitles = []
        unlimitedRunID = UUID().uuidString
        completedBookDurations = []
        unlimitedConsecutiveFailures = 0
        lastBookDuration = ""
        averageBookDuration = ""
        activeUnlimitedBooks = 0
        parallelUnlimitedBooks = settings.parallelBooks

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

        while !Task.isCancelled {
            // Frischer Zustand pro Buch – das Kostenlimit gilt je Buch.
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
            updateProductionTiming()
            lastError = nil

            var bookConfig = config
            bookConfig.costLimit = settings.costLimitPerBook > 0 ? settings.costLimitPerBook : nil

            do {
                let project = try await createUnlimitedProject(settings: settings, config: bookConfig)
                currentProject = project

                try await executeAllPhases(project: project, config: bookConfig)

                project.status = .completed
                progress = 1.0
                recordCompletedBookDuration()
                unlimitedBooksCompleted += 1
                unlimitedConsecutiveFailures = 0
                currentAgent = "Buch \(unlimitedBooksCompleted) abgeschlossen – nächstes Buch wird geplant …"
                try? modelContext?.save()

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
                // Buch fehlgeschlagen: protokollieren, Projekt bleibt fortsetzbar,
                // Dauerproduktion macht mit dem nächsten Buch weiter.
                if let job = currentJob, job.status == .running {
                    failJob(job, error: error)
                }
                currentProject?.status = .failed
                let aiError = error as? AIError
                lastError = aiError?.errorDescription ?? error.localizedDescription
                unlimitedConsecutiveFailures += 1
                try? modelContext?.save()

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
                    launchedBooks += 1
                    activeBooks += 1
                    activeUnlimitedBooks = activeBooks
                    let worker = makeUnlimitedWorker()
                    group.addTask {
                        await worker.runUnlimitedWorkerBook(
                            settings: settings,
                            config: config,
                            bookIndex: bookIndex
                        )
                    }
                }
                currentAgent = "\(activeBooks) von \(settings.parallelBooks) Buch-Workern aktiv"
            }

            launchAvailableBooks()

            while activeBooks > 0, let outcome = await group.next() {
                activeBooks -= 1
                activeUnlimitedBooks = activeBooks

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
        return worker
    }

    private func runUnlimitedWorkerBook(settings: UnlimitedSettings,
                                        config: ProviderConfiguration,
                                        bookIndex: Int) async -> UnlimitedBookOutcome {
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

        var bookConfig = config
        bookConfig.costLimit = settings.costLimitPerBook > 0 ? settings.costLimitPerBook : nil

        do {
            let startedAt = Date()
            let project = try await createUnlimitedProject(
                settings: settings,
                config: bookConfig,
                bookIndex: bookIndex
            )
            currentProject = project

            try await executeAllPhases(project: project, config: bookConfig)

            project.status = .completed
            progress = 1.0
            let duration = Date().timeIntervalSince(startedAt)
            try? modelContext?.save()
            return UnlimitedBookOutcome(
                completed: true,
                cancelled: false,
                title: project.title,
                duration: duration,
                error: nil,
                message: ""
            )
        } catch is CancellationError {
            if let project = currentProject {
                stopMode = .pause
                handleStop(project: project)
            }
            return UnlimitedBookOutcome(
                completed: false,
                cancelled: true,
                title: currentProject?.title ?? "",
                duration: 0,
                error: nil,
                message: "Abgebrochen"
            )
        } catch {
            if let job = currentJob, job.status == .running {
                failJob(job, error: error)
            }
            currentProject?.status = .failed
            let message = (error as? AIError)?.errorDescription ?? error.localizedDescription
            try? modelContext?.save()
            return UnlimitedBookOutcome(
                completed: false,
                cancelled: false,
                title: currentProject?.title ?? "",
                duration: 0,
                error: error,
                message: message
            )
        }
    }

    /// Erfindet eine Buchidee und legt daraus ein vollständiges Projekt an.
    private func createUnlimitedProject(settings: UnlimitedSettings,
                                        config: ProviderConfiguration,
                                        bookIndex: Int? = nil) async throws -> Project {
        let genre = settings.genreForBook(at: bookIndex ?? unlimitedBooksCompleted)
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

        let response = try await generate(
            prompt: PromptFactory.bookIdeas(genre: genre, language: settings.language,
                                            avoidanceBrief: avoidanceBrief),
            system: "Du bist ein Verlagslektor mit sicherem Gespür für verkäufliche, originelle Buchideen. Du vermeidest Wiederholungen gegenüber dem Story-Gedächtnis strikt.",
            maxTokens: 800, temperature: 0.95, config: config
        )
        let ideas = StructureParser.parseIdeas(response.text)
        let idea = ideas.first { !StoryMemory.isLikelyDuplicate($0, existing: memoryEntries) }
            ?? ideas.randomElement()
        guard AutonomousContentQuality.hasUsableIdea(idea) else {
            throw AIError.systemError("Autonom-Modus konnte keine tragfähige Buchidee erzeugen. Provider/Modell lieferte keine verwertbare Idee.")
        }

        var title = idea?.title ?? "\(genre)-Roman"
        if usedTitles.contains(title.lowercased()) {
            title += " \(Int(Date().timeIntervalSince1970) % 10000)"
        }
        usedTitles.insert(title.lowercased())

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
        project.costLimitUSD = settings.costLimitPerBook
        project.imprint = settings.imprint
        project.authorBio = settings.authorBio
        project.autoProductionRunID = unlimitedRunID
        project.memorySignature = StoryMemory.signature(
            title: title,
            genre: genre,
            premise: idea?.premise ?? ""
        )

        let profile = BookProfile(
            premise: idea?.premise ?? "",
            theme: "",
            targetAudience: "",
            tonality: style,
            narrativePerspective: "Personaler Erzähler (Er/Sie)",
            tense: "Präteritum"
        )
        profile.project = project

        let bible = StoryBible()
        bible.project = project

        project.bookProfile = profile
        project.storyBible = bible

        modelContext?.insert(project)
        modelContext?.insert(profile)
        modelContext?.insert(bible)
        try? modelContext?.save()
        return project
    }

    private func existingProjects() -> [Project] {
        guard let modelContext else { return [] }
        return (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
    }

    // MARK: - Hauptablauf

    /// Führt alle Pipeline-Phasen für ein Projekt aus (wirft bei Fehler/Abbruch).
    private func executeAllPhases(project: Project, config: ProviderConfiguration) async throws {
        for phase in PipelinePhase.executionOrder {
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
            case .copyrightCheck:
                runCopyrightCheck(project: project)
            case .kdpFormatting:
                try await runKDPFormatting(project: project, config: config)
            case .export:
                try runExport(project: project)
            default:
                break
            }

            project.updatedAt = Date()
            try? modelContext?.save()
        }
    }

    private func run(project: Project, config: ProviderConfiguration) async {
        do {
            try await executeAllPhases(project: project, config: config)

            project.status = .completed
            progress = 1.0
            currentAgent = "Abgeschlossen"
            finish()

        } catch is CancellationError {
            handleStop(project: project)
        } catch let error as AIError {
            if stopMode != .none {
                handleStop(project: project)
                return
            }
            if let job = currentJob, job.status == .running {
                failJob(job, error: error)
            }
            var message = error.errorDescription ?? "Unbekannter Fehler"
            if let suggestion = error.recoverySuggestion {
                message += " – \(suggestion)"
            }
            lastError = message
            project.status = .failed
            finish()
        } catch {
            if stopMode != .none {
                handleStop(project: project)
                return
            }
            if let job = currentJob, job.status == .running {
                failJob(job, error: error)
            }
            lastError = error.localizedDescription
            project.status = .failed
            finish()
        }
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
        heartbeatTask?.cancel()
        heartbeatTask = nil
        try? modelContext?.save()
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
        job.status = .failed
        job.endTime = Date()
        job.errorCount += 1
        job.result = error.localizedDescription
        currentJob = nil
    }

    // MARK: - LLM-Aufruf mit Kosten-Tracking

    private func generate(prompt: String, system: String, maxTokens: Int,
                          temperature: Double, config: ProviderConfiguration) async throws -> GenerationResponse {
        try Task.checkCancellation()

        if let limit = config.costLimit, limit > 0, estimatedCostUSD >= limit {
            throw AIError.quotaExceeded
        }

        let model = config.defaultModel ?? config.provider.suggestedModels.first ?? ""
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: system,
            model: model,
            provider: config.provider,
            maxTokens: maxTokens,
            temperature: temperature
        )
        let response = try await gateway.generateText(request: request, configuration: config)

        if let tokens = response.tokensUsed {
            totalTokensUsed += tokens
            estimatedCostUSD += ModelPricing.estimatedCost(model: model, tokens: tokens)
        }
        return response
    }

    /// Führt mehrere unabhängige LLM-Anfragen parallel aus (begrenzte Nebenläufigkeit).
    /// Token-/Kostenabrechnung erfolgt zentral; bei erreichtem Kostenlimit oder
    /// Abbruch werden ausstehende Anfragen storniert.
    /// Rückgabe: Ergebnisse je Index + Flag, ob das Kostenlimit ausgelöst hat.
    private func runParallelGeneration(requests: [GenerationRequest],
                                       config: ProviderConfiguration) async -> (results: [Int: Result<GenerationResponse, Error>], hitCostLimit: Bool) {
        guard !requests.isEmpty else { return ([:], false) }

        // Lokales Ollama arbeitet seriell am schnellsten; Cloud-APIs vertragen Parallelität.
        let maxConcurrent = config.provider == .ollamaLocal ? 1 : 3
        var results: [Int: Result<GenerationResponse, Error>] = [:]
        var hitCostLimit = false
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
                    totalTokensUsed += tokens
                    estimatedCostUSD += ModelPricing.estimatedCost(model: requests[index].model, tokens: tokens)
                }

                if Task.isCancelled {
                    group.cancelAll()
                } else if let limit = config.costLimit, limit > 0, estimatedCostUSD >= limit {
                    hitCostLimit = true
                    group.cancelAll()
                } else {
                    launchNext()
                }
            }
        }
        return (results, hitCostLimit)
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
        // Bereits erledigt? (Fortsetzen)
        if let logline = profile.logline, !logline.isEmpty { return }

        project.status = .conceptDevelopment
        let job = beginJob(agent: AgentName.concept, phase: .conceptDevelopment, project: project)
        do {
            let prompt = PromptFactory.concept(
                title: project.title, genre: project.genre, subgenre: project.subgenre,
                language: project.language, style: project.styleProfile,
                tonality: profile.tonality, audience: profile.targetAudience,
                perspective: profile.narrativePerspective, tense: profile.tense,
                pageCount: project.targetPageCount,
                ideaSeed: profile.premise
            )
            let response = try await generate(
                prompt: prompt,
                system: "Du bist ein erfahrener Verlagslektor und entwickelst originelle, tragfähige Buchkonzepte.",
                maxTokens: 1500, temperature: 0.8, config: config
            )

            let parsed = ConceptParser.parse(response.text)
            if !parsed.premise.isEmpty { profile.premise = parsed.premise }
            profile.logline = parsed.logline.isEmpty ? String(response.text.prefix(200)) : parsed.logline
            profile.synopsis = parsed.synopsis.isEmpty ? response.text : parsed.synopsis
            if !parsed.theme.isEmpty { profile.theme = parsed.theme }
            if profile.targetAudience.isEmpty && !parsed.audience.isEmpty {
                profile.targetAudience = parsed.audience
            }
            if profile.premise.trimmingCharacters(in: .whitespacesAndNewlines).wordCount < 8
                || (profile.synopsis ?? "").trimmingCharacters(in: .whitespacesAndNewlines).wordCount < 20
                || AutonomousContentQuality.containsMetaRequest(profile.synopsis ?? "") {
                throw AIError.systemError("Konzeptentwicklung lieferte kein verwertbares Thema/Exposé.")
            }

            completeJob(job, result: response.text, tokens: response.tokensUsed ?? 0)
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
            do {
                let prompt = PromptFactory.plot(
                    title: project.title, genre: project.genre, style: project.styleProfile,
                    concept: profile.synopsis ?? profile.premise,
                    pageCount: project.targetPageCount,
                    chapterCount: estimatedChapterCount(for: project)
                )
                let response = try await generate(
                    prompt: prompt,
                    system: "Du bist ein Plot-Architekt für Romane. Du baust schlüssige, spannende Handlungsbögen.",
                    maxTokens: 3500, temperature: 0.7, config: config
                )
                let plot = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard plot.wordCount >= 80, !AutonomousContentQuality.containsMetaRequest(plot) else {
                    throw AIError.systemError("Plot-Architekt lieferte keinen verwertbaren Plot.")
                }
                bible.plotPoints = plot
                bible.updatedAt = Date()
                completeJob(job, result: response.text, tokens: response.tokensUsed ?? 0)
            } catch {
                failJob(job, error: error)
                throw error
            }
        }

        // Figuren
        if (bible.characters ?? []).isEmpty {
            let job = beginJob(agent: AgentName.character, phase: .structurePlanning, project: project)
            do {
                let prompt = PromptFactory.characters(
                    title: project.title, genre: project.genre, plot: bible.plotPoints
                )
                let response = try await generate(
                    prompt: prompt,
                    system: "Du bist ein Charakter-Entwickler. Du erschaffst vielschichtige, glaubwürdige Figuren.",
                    maxTokens: 3000, temperature: 0.7, config: config
                )

                let parsed = StructureParser.parseCharacters(response.text)
                guard parsed.count >= 2 else {
                    throw AIError.systemError("Figurenplanung lieferte kein verwertbares Figurenensemble.")
                }
                if bible.characters == nil { bible.characters = [] }
                for item in parsed {
                    let character = CharacterProfile(name: item.name, role: item.role)
                    character.age = item.age
                    character.occupation = item.occupation
                    character.goal = item.goal
                    character.fear = item.fear
                    character.weakness = item.weakness
                    character.storyBible = bible
                    bible.characters?.append(character)
                    modelContext?.insert(character)
                }
                bible.updatedAt = Date()
                completeJob(job, result: "\(parsed.count) Figuren angelegt", tokens: response.tokensUsed ?? 0)
            } catch {
                failJob(job, error: error)
                throw error
            }
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
        guard let bible = project.storyBible else {
            throw AIError.systemError("Story Bible fehlt")
        }

        project.status = .chapterPlanning
        let plan = LongFormProductionPlan(pageCount: project.targetPageCount)
        let chapterCount = plan.chapterCount
        let wordsPerChapter = plan.targetWordsPerChapter

        let job = beginJob(agent: AgentName.chapterPlanner, phase: .chapterPlanning, project: project)
        do {
            let prompt = PromptFactory.chapterPlan(
                title: project.title, genre: project.genre, plot: bible.plotPoints,
                chapterCount: chapterCount, wordsPerChapter: wordsPerChapter,
                scenesPerChapter: plan.scenesPerChapter
            )
            let response = try await generate(
                prompt: prompt,
                system: "Du bist ein Strukturplaner für Romane. Du hältst dich exakt an das geforderte Ausgabeformat.",
                maxTokens: 3000, temperature: 0.6, config: config
            )

            let planned = StructureParser.parseChapters(response.text)
            guard AutonomousContentQuality.hasUsableChapterPlan(planned) else {
                throw AIError.systemError("Kapitelplanung lieferte nur leere oder generische Kapitel.")
            }

            if project.chapters == nil { project.chapters = [] }
            for item in planned {
                let chapter = Chapter(
                    chapterNumber: item.number,
                    title: item.title,
                    goal: item.goal,
                    targetWordCount: max(1, project.targetWordCount / planned.count)
                )
                chapter.conflict = item.conflict
                chapter.project = project
                project.chapters?.append(chapter)
                modelContext?.insert(chapter)
            }

            completeJob(job, result: "\(planned.count) Kapitel geplant", tokens: response.tokensUsed ?? 0)
        } catch {
            failJob(job, error: error)
            throw error
        }
    }

    // MARK: - Phase 5: Szenenplanung

    private func runScenePlanning(project: Project, config: ProviderConfiguration) async throws {
        guard let bible = project.storyBible, let profile = project.bookProfile else {
            throw AIError.systemError("Story Bible oder Buchprofil fehlt")
        }
        project.status = .scenePlanning
        let plan = LongFormProductionPlan(pageCount: project.targetPageCount)

        let chapters = sortedChapters(project)
        for chapter in chapters where !hasUsableExistingScenePlan(chapter, expectedCount: plan.scenesPerChapter) {
            resetScenePlan(for: chapter)
        }
        let pending = chapters.filter { ($0.scenes ?? []).isEmpty } // Fortsetzen: nur ungeplante
        guard !pending.isEmpty else { return }

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
                    scenesPerChapter: plan.scenesPerChapter
                ),
                system: "Du bist ein Szenenplaner für Romane. Du hältst dich exakt an das geforderte Ausgabeformat.",
                maxTokens: 1200, temperature: 0.6, config: config
            ))
        }
        currentAgent = "\(AgentName.scenePlanner) – \(pending.count) Kapitel parallel"

        let (results, hitCostLimit) = await runParallelGeneration(requests: requests, config: config)

        var firstError: Error?
        var done = 0
        for (index, chapter) in pending.enumerated() {
            switch results[index] {
            case .success(let response)?:
                var planned = StructureParser.parseScenes(response.text)
                if planned.count < plan.scenesPerChapter {
                    let existing = planned.count
                    planned.append(contentsOf: ((existing + 1)...plan.scenesPerChapter).map {
                        PlannedScene(number: $0, perspective: profile.narrativePerspective,
                                     location: "", time: "",
                                     goal: "Vertiefe das Kapitelziel mit einer eigenständigen Wendung: \(chapter.goal)",
                                     obstacle: "Der bisherige Konflikt verschärft sich.",
                                     turn: "Eine neue Information zwingt zur nächsten Entscheidung.")
                    })
                }
                guard AutonomousContentQuality.hasUsableScenePlan(planned, expectedCount: plan.scenesPerChapter) else {
                    failJob(jobs[index], error: AIError.systemError("Szenenplanung lieferte leere oder generische Szenen."))
                    if firstError == nil {
                        firstError = AIError.systemError("Szenenplanung lieferte leere oder generische Szenen.")
                    }
                    continue
                }

                if chapter.scenes == nil { chapter.scenes = [] }
                for item in planned {
                    let scene = StoryScene(
                        sceneNumber: item.number,
                        perspective: item.perspective.isEmpty ? profile.narrativePerspective : item.perspective,
                        location: item.location,
                        goal: item.goal,
                        targetWordCount: max(1, chapter.targetWordCount / planned.count)
                    )
                    scene.time = item.time
                    scene.obstacle = item.obstacle
                    scene.cliffhanger = item.turn
                    scene.chapter = chapter
                    chapter.scenes?.append(scene)
                    modelContext?.insert(scene)
                }
                chapter.status = .scenesPlanned
                completeJob(jobs[index], result: "\(planned.count) Szenen geplant",
                            tokens: response.tokensUsed ?? 0)
                done += 1
                updateProgress(phase: .scenePlanning, subProgress: Double(done) / Double(pending.count))

            case .failure(let error)?:
                failJob(jobs[index], error: error)
                if firstError == nil { firstError = error }

            case nil: // storniert, bevor gestartet
                jobs[index].status = .paused
                jobs[index].endTime = Date()
            }
        }
        // Schauplätze aus den Szenenplänen in die Story Bible übernehmen.
        aggregateLocations(into: bible, chapters: chapters)
        try? modelContext?.save()

        if hitCostLimit { throw AIError.quotaExceeded }
        if let error = firstError { throw error }
        try Task.checkCancellation()
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

        // Kontinuität: vorhandene Zusammenfassungen und den letzten Szenentext
        // einsammeln (wichtig beim Fortsetzen).
        var storySoFar: [String] = []
        var previousSceneText: String?
        // Langstrecken-Gedächtnis: verdichtete Zusammenfassung jedes abgeschlossenen
        // Kapitels – verhindert Wiederholungen über hunderte Seiten.
        var chapterDigests: [String] = []
        for chapter in chapters {
            if let digest = chapter.summary, !digest.isEmpty {
                chapterDigests.append("Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(digest)")
            }
            for scene in sortedScenes(chapter) where isSceneWritten(scene) {
                if let summary = scene.summary, !summary.isEmpty {
                    storySoFar.append("Kap. \(chapter.chapterNumber), Szene \(scene.sceneNumber): \(summary)")
                }
                previousSceneText = scene.text
            }
        }

        let charactersSummary = compactCharacterSummary(bible)

        for (chapterIndex, chapter) in chapters.enumerated() {
            currentChapter = chapter.chapterNumber
            let scenes = sortedScenes(chapter)

            for (sceneIndex, scene) in scenes.enumerated() {
                try Task.checkCancellation()
                if isSceneWritten(scene) {
                    previousSceneText = scene.text
                    continue
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
                    let prompt = PromptFactory.draftScene(
                        language: project.language, style: project.styleProfile,
                        tonality: profile.tonality, perspective: profile.narrativePerspective,
                        tense: profile.tense, genre: project.genre, bookTitle: project.title,
                        chapterNumber: chapter.chapterNumber, chapterTitle: chapter.title,
                        chapterGoal: chapter.goal, sceneNumber: scene.sceneNumber,
                        sceneGoal: scene.goal, sceneLocation: scene.location,
                        sceneTime: scene.time, sceneObstacle: scene.obstacle,
                        sceneTurn: scene.cliffhanger, scenePerspective: scene.perspective,
                        charactersSummary: charactersSummary,
                        styleRules: bible.styleRules,
                        storySoFar: recentContext,
                        previousSceneEnding: previousEnding,
                        isFirstScene: isFirstScene, isFinalScene: isFinalScene,
                        targetWords: scene.targetWordCount
                    )
                    let maxTokens = LongFormProductionPlan.draftMaxTokens(forTargetWords: scene.targetWordCount)
                    let response = try await generate(
                        prompt: prompt,
                        system: "Du bist ein professioneller Romanautor. Du schreibst lebendige, atmosphärische Prosa mit natürlichen Dialogen.",
                        maxTokens: maxTokens, temperature: 0.85, config: config
                    )

                    var sceneText = response.text
                    var sceneTokens = response.tokensUsed ?? 0

                    // Qualitäts-Gate: deutlich zu kurze Szenen einmalig vertiefen/erweitern.
                    let minWords = Int(Double(scene.targetWordCount) * 0.75)
                    if sceneText.wordCount < minWords {
                        do {
                            let expanded = try await generate(
                                prompt: PromptFactory.expandScene(
                                    language: project.language, style: project.styleProfile,
                                    text: sceneText, targetWords: scene.targetWordCount
                                ),
                                system: "Du bist ein professioneller Romanautor. Du vertiefst Szenen, ohne die Handlung zu verändern.",
                                maxTokens: maxTokens, temperature: 0.7, config: config
                            )
                            if expanded.text.wordCount > sceneText.wordCount {
                                sceneText = expanded.text
                                sceneTokens += expanded.tokensUsed ?? 0
                            }
                        } catch {
                            if error is CancellationError || (error as? AIError) == .quotaExceeded {
                                throw error
                            }
                            // Erweiterung fehlgeschlagen – kurze Szene behalten, Hinweis folgt unten.
                        }
                    }
                    if sceneText.wordCount < minWords {
                        addReport(project: project,
                                  area: "Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)",
                                  type: "Umfang",
                                  result: "Szene unter Zielumfang (\(sceneText.wordCount)/\(scene.targetWordCount) Wörter)",
                                  severity: .warning,
                                  recommendation: "Szene im Manuskript prüfen.")
                    }
                    guard AutonomousContentQuality.acceptsDraftScene(sceneText, targetWords: scene.targetWordCount) else {
                        throw AIError.systemError("Draft Writer lieferte keine verwertbare Romanszene (\(sceneText.wordCount)/\(scene.targetWordCount) Wörter).")
                    }

                    scene.text = sceneText
                    scene.status = .written
                    scene.updatedAt = Date()
                    previousSceneText = sceneText
                    chapter.actualWordCount = sortedScenes(chapter).compactMap { $0.text?.wordCount }.reduce(0, +)
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
                    try? modelContext?.save()
                } catch {
                    scene.status = .needsRevision
                    failJob(job, error: error)
                    throw error
                }
            }

            chapter.status = .draftComplete

            // Kapitel-Digest für das Langstrecken-Gedächtnis erzeugen (einmalig).
            if (chapter.summary ?? "").isEmpty {
                let digest = await condenseChapterSummary(chapter, project: project, config: config)
                if !digest.isEmpty {
                    chapter.summary = digest
                    chapterDigests.append("Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(digest)")
                }
            }
            try? modelContext?.save()
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
            completeJob(job, result: response.text, tokens: response.tokensUsed ?? 0)
            return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            failJob(job, error: error)
            let fallback = text.replacingOccurrences(of: "\n", with: " ")
            return String(fallback.prefix(300))
        }
    }

    // MARK: - Phase 7: Kapitelrevision

    private func runChapterRevision(project: Project, config: ProviderConfiguration) async throws {
        guard let profile = project.bookProfile else {
            throw AIError.systemError("Buchprofil fehlt")
        }
        project.status = .chapterRevision

        let chapters = sortedChapters(project)
        for chapter in chapters where (chapter.draftText ?? "").isEmpty {
            // Szenen mit sichtbarem Szenentrenner zusammenfügen (Print-/eBook-Konvention).
            chapter.draftText = sortedScenes(chapter).compactMap { $0.text }.joined(separator: "\n\n***\n\n")
        }

        // Fortsetzen: nur Kapitel ohne Revision, die Text haben.
        let pending = chapters.filter { chapter in
            guard let draft = chapter.draftText, !draft.isEmpty else { return false }
            return (chapter.revisedText ?? "").isEmpty
        }
        guard !pending.isEmpty else { return }

        var jobs: [PipelineJob] = []
        var requests: [GenerationRequest] = []
        for chapter in pending {
            jobs.append(beginJob(agent: AgentName.reviser, phase: .chapterRevision,
                                 project: project, chapter: chapter.chapterNumber))
            let draft = chapter.draftText ?? ""
            requests.append(makeRequest(
                prompt: PromptFactory.reviseChapter(
                    language: project.language, style: project.styleProfile,
                    tonality: profile.tonality, chapterNumber: chapter.chapterNumber,
                    chapterTitle: chapter.title, text: draft
                ),
                system: "Du bist ein erfahrener Lektor. Du verbesserst Prosa, ohne Handlung oder Stimme zu verändern.",
                maxTokens: min(12000, max(3000, draft.wordCount * 3)),
                temperature: 0.4, config: config
            ))
        }
        currentAgent = "\(AgentName.reviser) – \(pending.count) Kapitel parallel"

        let (results, hitCostLimit) = await runParallelGeneration(requests: requests, config: config)

        var firstError: Error?
        var done = 0
        for (index, chapter) in pending.enumerated() {
            let draft = chapter.draftText ?? ""
            switch results[index] {
            case .success(let response)?:
                // Schutz vor abgeschnittenen/leeren Antworten: nie Text verlieren.
                if response.text.wordCount >= draft.wordCount / 2 {
                    chapter.revisedText = response.text
                } else {
                    chapter.revisedText = draft
                    addReport(project: project, area: "Kapitel \(chapter.chapterNumber)",
                              type: "Revision", result: "Revisionsantwort unvollständig – Rohfassung übernommen",
                              severity: .warning,
                              recommendation: "Kapitel manuell prüfen oder Revision erneut ausführen.")
                }
                chapter.status = .revised
                chapter.updatedAt = Date()
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
        try? modelContext?.save()

        if hitCostLimit { throw AIError.quotaExceeded }
        if let error = firstError { throw error }
        try Task.checkCancellation()
    }

    // MARK: - Phase 8: Gesamtlektorat / Konsistenzprüfung

    private func runConsistencyCheck(project: Project, config: ProviderConfiguration) async throws {
        project.status = .manuscriptRevision
        // Bereits geprüft? (Fortsetzen)
        if (project.qualityReports ?? []).contains(where: { $0.checkType == "Konsistenz" }) { return }
        guard let bible = project.storyBible else { return }

        let summaries = sortedChapters(project).map { chapter -> String in
            let sceneSummaries = sortedScenes(chapter).compactMap { $0.summary }.joined(separator: " ")
            return "Kapitel \(chapter.chapterNumber) (\(chapter.title)): \(sceneSummaries)"
        }.joined(separator: "\n")

        guard !summaries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let job = beginJob(agent: AgentName.consistency, phase: .manuscriptRevision, project: project)
        do {
            let response = try await generate(
                prompt: PromptFactory.consistencyCheck(
                    bookTitle: project.title, summaries: summaries,
                    characters: compactCharacterSummary(bible)
                ),
                system: "Du bist ein Kontinuitätsprüfer für Romane. Du findest Widersprüche und Logikfehler.",
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
        project.status = .proofreading

        let chapters = sortedChapters(project)
        // Fortsetzen: nur Kapitel ohne finale Fassung, die Text haben.
        let pending = chapters.filter { chapter in
            guard (chapter.finalText ?? "").isEmpty else { return false }
            let source = chapter.revisedText ?? chapter.draftText ?? ""
            return !source.isEmpty
        }
        guard !pending.isEmpty else { return }

        var jobs: [PipelineJob] = []
        var requests: [GenerationRequest] = []
        for chapter in pending {
            jobs.append(beginJob(agent: AgentName.proofreader, phase: .proofreading,
                                 project: project, chapter: chapter.chapterNumber))
            let text = chapter.revisedText ?? chapter.draftText ?? ""
            requests.append(makeRequest(
                prompt: PromptFactory.proofread(language: project.language, text: text),
                system: "Du bist ein professioneller Korrektor. Du korrigierst nur Fehler, nie den Stil.",
                maxTokens: min(12000, max(3000, text.wordCount * 3)),
                temperature: 0.1, config: config
            ))
        }
        currentAgent = "\(AgentName.proofreader) – \(pending.count) Kapitel parallel"

        let (results, hitCostLimit) = await runParallelGeneration(requests: requests, config: config)

        var firstError: Error?
        var done = 0
        for (index, chapter) in pending.enumerated() {
            let source = chapter.revisedText ?? chapter.draftText ?? ""
            switch results[index] {
            case .success(let response)?:
                if response.text.wordCount >= source.wordCount / 2 {
                    chapter.finalText = response.text
                } else {
                    chapter.finalText = source
                    addReport(project: project, area: "Kapitel \(chapter.chapterNumber)",
                              type: "Korrektorat", result: "Korrektoratsantwort unvollständig – vorige Fassung übernommen",
                              severity: .warning,
                              recommendation: "Kapitel manuell prüfen.")
                }
                chapter.status = .finalized
                chapter.actualWordCount = chapter.computedWordCount
                chapter.updatedAt = Date()
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
        try? modelContext?.save()

        if hitCostLimit { throw AIError.quotaExceeded }
        if let error = firstError { throw error }
        try Task.checkCancellation()
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
        }

        if findings.isEmpty {
            addReport(project: project, area: "Copyright", type: "Risikoanalyse",
                      result: "Keine offensichtlichen Risiken erkannt", severity: .info,
                      recommendation: "Interne Prüfung – keine juristische Garantie.")
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

        // KDP-Metadaten (Verkaufstext, Keywords, Kategorien) generieren – einmalig.
        if let profile = project.bookProfile, profile.kdpDescription.isEmpty {
            let metaJob = beginJob(agent: AgentName.kdpFormatter, phase: .kdpFormatting, project: project)
            do {
                let response = try await generate(
                    prompt: PromptFactory.kdpMetadata(
                        title: project.title, author: project.authorName,
                        authorBio: project.authorBio,
                        genre: project.genre, audience: profile.targetAudience,
                        synopsis: profile.synopsis ?? profile.premise,
                        language: project.language
                    ),
                    system: "Du bist ein erfahrener Buchmarketing-Texter für Amazon KDP. Deine Produktbeschreibungen verkaufen.",
                    maxTokens: 1200, temperature: 0.7, config: config
                )
                let parsed = KDPMetadataParser.parse(response.text)
                profile.kdpDescription = parsed.salesDescription.isEmpty ? response.text : parsed.salesDescription
                profile.kdpKeywords = parsed.keywords
                profile.kdpCategories = parsed.categories
                completeJob(metaJob, result: response.text, tokens: response.tokensUsed ?? 0)
            } catch {
                failJob(metaJob, error: error)
                // Marketing-Metadaten sind nicht produktionskritisch – nur bei
                // Kostenlimit/Abbruch die Pipeline stoppen.
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
            ("Figuren", scores.characters),
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

    private func runExport(project: Project) throws {
        project.status = .export
        let job = beginJob(agent: AgentName.exporter, phase: .export, project: project)

        do {
            var exported: [String] = []
            let formats = Set(project.outputFormats)
            if formats.contains("EPUB") {
                exported.append(try ExportEngine.exportToEPUB(project: project).path)
            }
            if formats.contains("PDF") {
                exported.append(try ExportEngine.exportToPDF(project: project).path)
            }
            if formats.contains("DOCX") {
                exported.append(try ExportEngine.exportToDOCX(project: project).path)
            }
            completeJob(job, result: exported.isEmpty ? "Keine Formate ausgewählt" : exported.joined(separator: "\n"))
        } catch {
            failJob(job, error: error)
            throw AIError.systemError("Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Hilfsfunktionen

    private func estimatedChapterCount(for project: Project) -> Int {
        LongFormProductionPlan(pageCount: project.targetPageCount).chapterCount
    }

    private func sortedChapters(_ project: Project) -> [Chapter] {
        (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private func sortedScenes(_ chapter: Chapter) -> [StoryScene] {
        (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }
    }

    private func isSceneWritten(_ scene: StoryScene) -> Bool {
        guard let text = scene.text, !text.isEmpty else { return false }
        guard AutonomousContentQuality.acceptsDraftScene(text, targetWords: scene.targetWordCount) else {
            return false
        }
        return scene.status == .written || scene.status == .finalized || scene.status == .checking
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
        try? modelContext?.save()
    }

    private func resetScenePlan(for chapter: Chapter) {
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
        try? modelContext?.save()
    }

    private func compactCharacterSummary(_ bible: StoryBible) -> String {
        (bible.characters ?? []).prefix(8).map { character in
            var line = "\(character.name) (\(character.role))"
            if !character.goal.isEmpty { line += " – Ziel: \(character.goal)" }
            if !character.weakness.isEmpty { line += ", Schwäche: \(character.weakness)" }
            return line
        }.joined(separator: "\n")
    }

    private func addReport(project: Project, area: String, type: String, result: String,
                           severity: Severity, recommendation: String) {
        let report = QualityReport(checkedArea: area, checkType: type, result: result,
                                   severity: severity, recommendation: recommendation)
        if project.qualityReports == nil { project.qualityReports = [] }
        report.project = project
        project.qualityReports?.append(report)
        modelContext?.insert(report)
    }

    private func updateProgress(phase: PipelinePhase, subProgress: Double) {
        var total = 0.0
        for item in PipelinePhase.executionOrder {
            if item == phase { break }
            total += item.weight
        }
        total += phase.weight * min(max(subProgress, 0), 1)
        progress = min(total, 1.0)
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
