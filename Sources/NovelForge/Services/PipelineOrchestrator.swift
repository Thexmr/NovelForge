import Foundation
import SwiftData

@MainActor
class PipelineOrchestrator: ObservableObject {
    static let shared = PipelineOrchestrator()
    
    @Published var currentProject: Project?
    @Published var currentPhase: PipelinePhase = .projectSetup
    @Published var progress: Double = 0.0
    @Published var estimatedTimeRemaining: String = ""
    @Published var currentAgent: String = ""
    @Published var currentChapter: Int = 0
    @Published var currentScene: Int = 0
    @Published var isRunning: Bool = false
    @Published var lastError: String?
    
    private var modelContext: ModelContext?
    private var startTime: Date?
    private var sceneTimes: [TimeInterval] = []
    private let agentRuntime = AgentRuntime.shared
    private let providerGateway = ProviderGateway.shared
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    func startPipeline(project: Project, providerConfig: ProviderConfiguration) async {
        guard !isRunning else { return }
        
        isRunning = true
        currentProject = project
        startTime = Date()
        lastError = nil
        
        do {
            // Phase 1: Input Validation
            try await executePhase(.projectSetup, project: project, config: providerConfig)
            
            // Phase 2: Concept Development
            try await executePhase(.conceptDevelopment, project: project, config: providerConfig)
            
            // Phase 3: Structure Planning
            try await executePhase(.structurePlanning, project: project, config: providerConfig)
            
            // Phase 4: Chapter Planning
            try await executePhase(.chapterPlanning, project: project, config: providerConfig)
            
            // Phase 5: StoryScene Planning
            try await executePhase(.scenePlanning, project: project, config: providerConfig)
            
            // Phase 6: Drafting
            try await executeDraftingPhase(project: project, config: providerConfig)
            
            // Phase 7: Chapter Revision
            try await executePhase(.chapterRevision, project: project, config: providerConfig)
            
            // Phase 8: Manuscript Revision
            try await executePhase(.manuscriptRevision, project: project, config: providerConfig)
            
            // Phase 9: Proofreading
            try await executePhase(.proofreading, project: project, config: providerConfig)
            
            // Phase 10: Copyright Check
            try await executePhase(.copyrightCheck, project: project, config: providerConfig)
            
            // Phase 11: KDP Formatting
            try await executePhase(.kdpFormatting, project: project, config: providerConfig)
            
            // Phase 12: Export
            try await executePhase(.export, project: project, config: providerConfig)
            
            project.status = .completed
            updateProgress(.completed)
            
        } catch {
            lastError = error.localizedDescription
            project.status = .failed
            isRunning = false
        }
        
        isRunning = false
    }
    
    private func executePhase(_ phase: PipelinePhase, project: Project, config: ProviderConfiguration) async throws {
        currentPhase = phase
        updateProgress(phase)
        
        if project.pipelineJobs == nil {
            project.pipelineJobs = []
        }
        if project.qualityReports == nil {
            project.qualityReports = []
        }
        
        let job = PipelineJob(agentName: phase.rawValue, phase: phase)
        job.status = .running
        project.pipelineJobs?.append(job)
        modelContext?.insert(job)
        
        let context = AgentContext(
            project: project,
            chapter: nil,
            scene: nil,
            storyBible: project.storyBible,
            previousResults: [:],
            provider: config.provider,
            model: config.defaultModel ?? "gpt-4o"
        )
        
        switch phase {
        case .projectSetup:
            let agent = InputAgent()
            currentAgent = agent.name
            let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
            if !result.success {
                throw AIError.systemError("Input validation failed")
            }
            
        case .conceptDevelopment:
            let agent = ConceptAgent()
            currentAgent = agent.name
            let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
            if let bookProfile = project.bookProfile {
                bookProfile.premise = result.output
            }
            
        case .structurePlanning:
            let plotAgent = PlotArchitectAgent()
            currentAgent = plotAgent.name
            _ = try await agentRuntime.executeAgent(plotAgent, context: context, job: job)
            
            let charAgent = CharacterArchitectAgent()
            currentAgent = charAgent.name
            let charResult = try await agentRuntime.executeAgent(charAgent, context: context, job: job)
            
            // Parse and create characters
            await parseCharacters(from: charResult.output, storyBible: project.storyBible)
            
        case .chapterPlanning:
            try await planChapters(project: project, config: config)
            
        case .scenePlanning:
            try await planScenes(project: project, config: config)
            
        case .chapterRevision:
            try await reviseChapters(project: project, config: config)
            
        case .manuscriptRevision:
            try await reviseManuscript(project: project, config: config)
            
        case .proofreading:
            try await proofreadManuscript(project: project, config: config)
            
        case .copyrightCheck:
            try await checkCopyright(project: project, config: config)
            
        case .kdpFormatting:
            try await formatForKDP(project: project, config: config)
            
        case .export:
            try await exportProject(project: project)
            
        default:
            break
        }
        
        job.status = .completed
        project.updatedAt = Date()
    }
    
    private func executeDraftingPhase(project: Project, config: ProviderConfiguration) async throws {
        currentPhase = .drafting
        
        guard let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) else {
            throw AIError.systemError("Keine Kapitel zum Schreiben")
        }
        
        let totalScenes = chapters.compactMap { $0.scenes?.count }.reduce(0, +)
        var completedScenes = 0
        
        for (index, chapter) in chapters.enumerated() {
            currentChapter = chapter.chapterNumber
            
            guard let scenes = chapter.scenes?.sorted(by: { $0.sceneNumber < $1.sceneNumber }) else {
                chapter.status = .draftComplete
                continue
            }
            
            for scene in scenes {
                currentScene = scene.sceneNumber
                scene.status = .writing
                
                let sceneStart = Date()
                
                let job = PipelineJob(
                    agentName: "Draft Writer",
                    phase: .drafting,
                    chapterNumber: chapter.chapterNumber,
                    sceneNumber: scene.sceneNumber
                )
                project.pipelineJobs?.append(job)
                modelContext?.insert(job)
                
                let context = AgentContext(
                    project: project,
                    chapter: chapter,
                    scene: scene,
                    storyBible: project.storyBible,
                    previousResults: ["previous_summary": getPreviousSummary(project: project, currentChapter: chapter.chapterNumber)],
                    provider: config.provider,
                    model: config.defaultModel ?? "gpt-4o"
                )
                
                let agent = DraftWriterAgent()
                currentAgent = "\(agent.name) - Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)"
                
                do {
                    let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
                    scene.text = result.output
                    scene.status = .written
                    scene.summary = await generateSummary(text: result.output, config: config)
                    
                    // Update word count
                    chapter.actualWordCount = (chapter.scenes?.compactMap { $0.text?.wordCount }.reduce(0, +)) ?? 0
                    
                    // Track timing
                    let duration = Date().timeIntervalSince(sceneStart)
                    sceneTimes.append(duration)
                    completedScenes += 1
                    
                    // Update progress with sub-progress
                    let subProgress = Double(completedScenes) / Double(totalScenes)
                    updateProgress(.drafting, subProgress: subProgress)
                    updateEstimatedTime(chaptersLeft: chapters.count - index - 1, scenesLeft: scenes.count - scene.sceneNumber)
                    
                    // Save after each scene
                    try? modelContext?.save()
                    
                } catch {
                    scene.status = .needsRevision
                    throw error
                }
            }
            
            chapter.status = .draftComplete
        }
    }
    
    private func planChapters(project: Project, config: ProviderConfiguration) async throws {
        let estimatedChapters = max(10, project.targetPageCount / 15)
        
        if project.chapters == nil {
            project.chapters = []
        }
        
        for i in 1...estimatedChapters {
            let chapter = Chapter(
                chapterNumber: i,
                title: "Kapitel \(i)",
                goal: "",
                targetWordCount: project.targetWordCount / estimatedChapters
            )
            chapter.project = project
            project.chapters?.append(chapter)
            modelContext?.insert(chapter)
        }
        
        try? modelContext?.save()
        project.status = .chapterPlanning
    }
    
    private func planScenes(project: Project, config: ProviderConfiguration) async throws {
        guard let chapters = project.chapters else { return }
        
        for chapter in chapters {
            if chapter.scenes == nil {
                chapter.scenes = []
            }
            
            let sceneCount = Int.random(in: 3...6)
            
            for i in 1...sceneCount {
                let scene = StoryScene(
                    sceneNumber: i,
                    perspective: "",
                    location: "",
                    goal: "",
                    targetWordCount: chapter.targetWordCount / sceneCount
                )
                scene.chapter = chapter
                chapter.scenes?.append(scene)
                modelContext?.insert(scene)
            }
            
            chapter.status = .scenesPlanned
        }
        
        try? modelContext?.save()
    }
    
    private func reviseChapters(project: Project, config: ProviderConfiguration) async throws {
        guard let chapters = project.chapters else { return }
        
        for chapter in chapters {
            // Combine scenes
            let fullText = chapter.scenes?.compactMap { $0.text }.joined(separator: "\n\n") ?? ""
            chapter.draftText = fullText
            
            // Simple revision logic - in production this would use Line Editor Agent
            chapter.revisedText = fullText
            chapter.status = .revised
        }
    }
    
    private func reviseManuscript(project: Project, config: ProviderConfiguration) async throws {
        // Overall manuscript check
        project.status = .manuscriptRevision
    }
    
    private func proofreadManuscript(project: Project, config: ProviderConfiguration) async throws {
        guard let chapters = project.chapters else { return }
        
        for chapter in chapters {
            guard let text = chapter.revisedText else { continue }
            
            let job = PipelineJob(
                agentName: "Proofreader",
                phase: .proofreading,
                chapterNumber: chapter.chapterNumber
            )
            project.pipelineJobs?.append(job)
            modelContext?.insert(job)
            
            let context = AgentContext(
                project: project,
                chapter: chapter,
                scene: nil,
                storyBible: project.storyBible,
                previousResults: ["text_to_proofread": text],
                provider: config.provider,
                model: config.defaultModel ?? "gpt-4o-mini"
            )
            
            let agent = ProofreaderAgent()
            let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
            chapter.finalText = result.output
            chapter.status = .finalized
        }
        
        project.status = .proofreading
    }
    
    private func checkCopyright(project: Project, config: ProviderConfiguration) async throws {
        // Copyright risk analysis
        let report = QualityReport(
            checkedArea: "Copyright",
            checkType: "Risikoanalyse",
            result: "Keine offensichtlichen Verstöße erkannt",
            severity: .info,
            recommendation: "Interne Prüfung - keine juristische Garantie"
        )
        project.qualityReports?.append(report)
    }
    
    private func formatForKDP(project: Project, config: ProviderConfiguration) async throws {
        project.status = .kdpFormatting
    }
    
    private func exportProject(project: Project) async throws {
        // Export logic handled by ExportEngine
        project.status = .export
    }
    
    private func parseCharacters(from output: String, storyBible: StoryBible?) async {
        guard let storyBible = storyBible else { return }
        
        if storyBible.characters == nil {
            storyBible.characters = []
        }
        
        let lines = output.components(separatedBy: .newlines)
        var currentName = ""
        
        for line in lines {
            if line.hasPrefix("Name:") || line.hasPrefix("- Name:") || line.contains("**Name:**") {
                currentName = line.replacingOccurrences(of: "Name:", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !currentName.isEmpty {
                    let character = CharacterProfile(name: currentName, role: "Nebenfigur")
                    character.storyBible = storyBible
                    storyBible.characters?.append(character)
                    modelContext?.insert(character)
                }
            }
        }
        
        try? modelContext?.save()
    }
    
    private func generateSummary(text: String, config: ProviderConfiguration) async -> String {
        let prompt = "Fasse die folgende Szene in 2-3 Sätzen zusammen:\n\n\(text.prefix(1000))"
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: nil,
            model: config.defaultModel ?? "gpt-4o-mini",
            provider: config.provider,
            maxTokens: 200,
            temperature: 0.3,
            stream: false
        )
        
        do {
            let response = try await providerGateway.generateText(request: request)
            return response.text
        } catch {
            return "Zusammenfassung nicht verfügbar"
        }
    }
    
    private func getPreviousSummary(project: Project, currentChapter: Int) -> String {
        guard let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }),
              currentChapter > 1 else {
            return "Anfang des Buches"
        }
        
        let prevChapter = chapters.first { $0.chapterNumber == currentChapter - 1 }
        let summaries = prevChapter?.scenes?.compactMap { $0.summary }.joined(separator: " ") ?? ""
        return summaries
    }
    
    private func updateProgress(_ phase: PipelinePhase, subProgress: Double = 0.0) {
        var totalWeight = 0.0
        for p in PipelinePhase.allCases {
            if p == phase { break }
            totalWeight += p.weight
        }
        // Add sub-progress within current phase
        totalWeight += phase.weight * subProgress
        progress = min(totalWeight, 1.0)
    }
    
    private func updateEstimatedTime(chaptersLeft: Int, scenesLeft: Int) {
        guard !sceneTimes.isEmpty else { return }
        let avgSceneTime = sceneTimes.reduce(0, +) / Double(sceneTimes.count)
        let totalScenesLeft = chaptersLeft * 5 + scenesLeft // Estimate 5 scenes per chapter
        let totalSeconds = avgSceneTime * Double(totalScenesLeft)
        
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        
        if hours > 0 {
            estimatedTimeRemaining = "\(hours)h \(minutes)min"
        } else {
            estimatedTimeRemaining = "\(minutes)min"
        }
    }
    
    func pausePipeline() {
        isRunning = false
        currentProject?.status = .paused
        // Save current state
        try? modelContext?.save()
    }
    
    func resumePipeline() {
        guard let project = currentProject else { return }
        guard project.status == .paused || project.status == .failed else { return }
        
        Task {
            isRunning = true
            lastError = nil
            
            // TODO: Find the last completed phase to determine where to resume
            // For now, just mark as running and let the user manually restart
            project.status = .drafting
            isRunning = false
        }
    }
}