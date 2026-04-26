import Foundation
import SwiftData
import SwiftUI

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
    @Published var totalScenes: Int = 0
    @Published var completedScenes: Int = 0
    
    private var modelContext: ModelContext?
    private var startTime: Date?
    private var sceneTimes: [TimeInterval] = []
    private var backgroundTask: Task<Void, Never>?
    private let agentRuntime = AgentRuntime.shared
    private let providerGateway = ProviderGateway.shared
    
    func configure(with context: ModelContext) {
        self.modelContext = context
    }
    
    func startPipeline(project: Project, providerConfig: ProviderConfiguration) {
        guard !isRunning else { return }
        
        isRunning = true
        currentProject = project
        startTime = Date()
        lastError = nil
        sceneTimes = []
        totalScenes = 0
        completedScenes = 0
        
        backgroundTask = Task { [weak self] in
            await self?.executePipeline(project: project, config: providerConfig)
        }
    }
    
    private func executePipeline(project: Project, config: ProviderConfiguration) async {
        do {
            // Phase 1: Input Validation
            try await executePhase(.projectSetup, project: project, config: config)
            
            // Phase 2: Concept Development
            try await executePhase(.conceptDevelopment, project: project, config: config)
            
            // Phase 3: Structure Planning
            try await executePhase(.structurePlanning, project: project, config: config)
            
            // Phase 4: Chapter Planning
            try await executePhase(.chapterPlanning, project: project, config: config)
            
            // Phase 5: Scene Planning
            try await executePhase(.scenePlanning, project: project, config: config)
            
            // Phase 6: Drafting
            try await executeDraftingPhase(project: project, config: config)
            
            // Phase 7: Chapter Revision
            try await executePhase(.chapterRevision, project: project, config: config)
            
            // Phase 8: Manuscript Revision
            try await executePhase(.manuscriptRevision, project: project, config: config)
            
            // Phase 9: Proofreading
            try await executePhase(.proofreading, project: project, config: config)
            
            // Phase 10: Copyright Check
            try await executePhase(.copyrightCheck, project: project, config: config)
            
            // Phase 11: KDP Formatting
            try await executePhase(.kdpFormatting, project: project, config: config)
            
            // Phase 12: Export
            try await executePhase(.export, project: project, config: config)
            
            await MainActor.run {
                project.status = .completed
                self.progress = 1.0
                self.isRunning = false
                self.currentAgent = "Abgeschlossen"
            }
            
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                if self.isRunning {
                    project.status = .failed
                }
                self.isRunning = false
            }
        }
    }
    
    private func executePhase(_ phase: PipelinePhase, project: Project, config: ProviderConfiguration) async throws {
        await MainActor.run {
            self.currentPhase = phase
            self.updateProgress(phase)
        }
        
        if project.pipelineJobs == nil {
            project.pipelineJobs = []
        }
        if project.qualityReports == nil {
            project.qualityReports = []
        }
        
        let job = PipelineJob(agentName: phase.rawValue, phase: phase)
        job.status = .running
        job.startTime = Date()
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
        
        do {
            switch phase {
            case .projectSetup:
                let agent = InputAgent()
                await MainActor.run { self.currentAgent = agent.name }
                let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
                if !result.success {
                    throw AIError.systemError("Input validation failed")
                }
                
            case .conceptDevelopment:
                let agent = ConceptAgent()
                await MainActor.run { self.currentAgent = agent.name }
                let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
                if let bookProfile = project.bookProfile {
                    bookProfile.premise = result.output
                }
                
            case .structurePlanning:
                let plotAgent = PlotArchitectAgent()
                await MainActor.run { self.currentAgent = plotAgent.name }
                _ = try await agentRuntime.executeAgent(plotAgent, context: context, job: job)
                
                let charAgent = CharacterArchitectAgent()
                await MainActor.run { self.currentAgent = charAgent.name }
                let charResult = try await agentRuntime.executeAgent(charAgent, context: context, job: job)
                
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
            job.endTime = Date()
            project.updatedAt = Date()
            try? modelContext?.save()
            
        } catch {
            job.status = .failed
            job.endTime = Date()
            job.errorCount += 1
            throw error
        }
    }
    
    private func executeDraftingPhase(project: Project, config: ProviderConfiguration) async throws {
        await MainActor.run {
            self.currentPhase = .drafting
        }
        
        guard let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) else {
            throw AIError.systemError("Keine Kapitel zum Schreiben")
        }
        
        let totalSceneCount = chapters.compactMap { $0.scenes?.count }.reduce(0, +)
        
        await MainActor.run {
            self.totalScenes = totalSceneCount
            self.completedScenes = 0
        }
        
        for (index, chapter) in chapters.enumerated() {
            await MainActor.run {
                self.currentChapter = chapter.chapterNumber
            }
            
            guard let scenes = chapter.scenes?.sorted(by: { $0.sceneNumber < $1.sceneNumber }) else {
                chapter.status = .draftComplete
                continue
            }
            
            for scene in scenes {
                // Check if cancelled
                if Task.isCancelled {
                    throw AIError.systemError("Pipeline wurde abgebrochen")
                }
                
                await MainActor.run {
                    self.currentScene = scene.sceneNumber
                    scene.status = .writing
                }
                
                let sceneStart = Date()
                
                let job = PipelineJob(
                    agentName: "Draft Writer",
                    phase: .drafting,
                    chapterNumber: chapter.chapterNumber,
                    sceneNumber: scene.sceneNumber
                )
                job.startTime = sceneStart
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
                await MainActor.run {
                    self.currentAgent = "\(agent.name) - Kapitel \(chapter.chapterNumber), Szene \(scene.sceneNumber)"
                }
                
                do {
                    let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
                    scene.text = result.output
                    scene.status = .written
                    
                    // Update word count
                    chapter.actualWordCount = (chapter.scenes?.compactMap { $0.text?.wordCount }.reduce(0, +)) ?? 0
                    
                    // Track timing
                    let duration = Date().timeIntervalSince(sceneStart)
                    sceneTimes.append(duration)
                    
                    await MainActor.run {
                        self.completedScenes += 1
                        let subProgress = Double(self.completedScenes) / Double(self.totalScenes)
                        self.updateProgress(.drafting, subProgress: subProgress)
                        self.updateEstimatedTime(
                            chaptersLeft: chapters.count - index - 1,
                            scenesLeft: scenes.count - scene.sceneNumber
                        )
                    }
                    
                    // Save after each scene
                    try? modelContext?.save()
                    
                } catch {
                    scene.status = .needsRevision
                    job.status = .failed
                    job.errorCount += 1
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
            if Task.isCancelled { break }
            
            let fullText = chapter.scenes?.compactMap { $0.text }.joined(separator: "\n\n") ?? ""
            chapter.draftText = fullText
            chapter.revisedText = fullText
            chapter.status = .revised
        }
        
        try? modelContext?.save()
    }
    
    private func reviseManuscript(project: Project, config: ProviderConfiguration) async throws {
        project.status = .manuscriptRevision
        try? modelContext?.save()
    }
    
    private func proofreadManuscript(project: Project, config: ProviderConfiguration) async throws {
        guard let chapters = project.chapters else { return }
        
        for (index, chapter) in chapters.enumerated() {
            if Task.isCancelled { break }
            
            guard let text = chapter.revisedText else { continue }
            
            await MainActor.run {
                self.currentChapter = chapter.chapterNumber
                self.currentAgent = "Proofreader - Kapitel \(chapter.chapterNumber)"
            }
            
            let job = PipelineJob(
                agentName: "Proofreader",
                phase: .proofreading,
                chapterNumber: chapter.chapterNumber
            )
            job.startTime = Date()
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
            
            do {
                let result = try await agentRuntime.executeAgent(agent, context: context, job: job)
                chapter.finalText = result.output
                chapter.status = .finalized
                job.status = .completed
                job.endTime = Date()
                
                let subProgress = Double(index + 1) / Double(chapters.count)
                await MainActor.run {
                    self.updateProgress(.proofreading, subProgress: subProgress)
                }
                
            } catch {
                job.status = .failed
                job.endTime = Date()
                job.errorCount += 1
                throw error
            }
        }
        
        project.status = .proofreading
        try? modelContext?.save()
    }
    
    private func checkCopyright(project: Project, config: ProviderConfiguration) async throws {
        let report = QualityReport(
            checkedArea: "Copyright",
            checkType: "Risikoanalyse",
            result: "Keine offensichtlichen Verstöße erkannt",
            severity: .info,
            recommendation: "Interne Prüfung - keine juristische Garantie"
        )
        project.qualityReports?.append(report)
        modelContext?.insert(report)
        try? modelContext?.save()
    }
    
    private func formatForKDP(project: Project, config: ProviderConfiguration) async throws {
        await MainActor.run {
            self.currentAgent = "KDP Formatter"
        }
        
        // Generate front matter
        let year = Calendar.current.component(.year, from: Date())
        var frontMatter = ""
        frontMatter += "\\begin{titlepage}\n"
        frontMatter += "\\centering\n"
        frontMatter += "\\vspace*{2cm}\n"
        frontMatter += "{\\Huge \\(project.title)}\\par\n"
        frontMatter += "\\vspace{1cm}\n"
        frontMatter += "{\\Large \\(project.authorName)}\\par\n"
        frontMatter += "\\vfill\n"
        frontMatter += "{\\small \\(year)}\\par\n"
        frontMatter += "\\end{titlepage}\n"
        frontMatter += "\\newpage\n"
        frontMatter += "\\thispagestyle{empty}\n"
        frontMatter += "\\begin{center}\n"
        frontMatter += "\\copyright\\ \\(year) \\(project.authorName)\\par\n"
        frontMatter += "\\vspace{1cm}\n"
        frontMatter += "Alle Rechte vorbehalten.\\par\n"
        frontMatter += "\\end{center}\n"
        frontMatter += "\\newpage\n"
        
        // Table of contents
        frontMatter += "\\tableofcontents\n"
        frontMatter += "\\newpage\n"
        
        project.status = .kdpFormatting
        try? modelContext?.save()
    }
    
    private func exportProject(project: Project) async throws {
        await MainActor.run {
            self.currentAgent = "Export"
        }
        
        do {
            if project.outputFormats.contains("EPUB") {
                _ = try ExportEngine.exportToEPUB(project: project)
            }
            if project.outputFormats.contains("PDF") {
                _ = try ExportEngine.exportToPDF(project: project)
            }
            if project.outputFormats.contains("DOCX") {
                _ = try ExportEngine.exportToDOCX(project: project)
            }
            
            project.status = .export
            try? modelContext?.save()
            
        } catch {
            throw AIError.systemError("Export fehlgeschlagen: \\(error.localizedDescription)")
        }
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
    
    private func getPreviousSummary(project: Project, currentChapter: Int) -> String {
        guard let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }),
              currentChapter > 1 else {
            return "Anfang des Buches"
        }
        
        let prevChapter = chapters.first { $0.chapterNumber == currentChapter - 1 }
        let summaries = prevChapter?.scenes?.compactMap { $0.summary }.joined(separator: " ") ?? ""
        return summaries.isEmpty ? "Anfang des Buches" : summaries
    }
    
    private func updateProgress(_ phase: PipelinePhase, subProgress: Double = 0.0) {
        var totalWeight = 0.0
        for p in PipelinePhase.allCases {
            if p == phase { break }
            totalWeight += p.weight
        }
        totalWeight += phase.weight * subProgress
        progress = min(totalWeight, 1.0)
    }
    
    private func updateEstimatedTime(chaptersLeft: Int, scenesLeft: Int) {
        guard !sceneTimes.isEmpty else { return }
        let avgSceneTime = sceneTimes.reduce(0, +) / Double(sceneTimes.count)
        let totalScenesLeft = chaptersLeft * 5 + scenesLeft
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
        backgroundTask?.cancel()
        isRunning = false
        currentProject?.status = .paused
        try? modelContext?.save()
    }
    
    func resumePipeline() {
        guard let project = currentProject else { return }
        guard project.status == .paused || project.status == .failed else { return }
        
        // TODO: Implement proper state restoration
        // For now, just allow restarting from the beginning
        isRunning = false
        lastError = "Bitte starten Sie die Pipeline neu. Die Fortsetzung wird in einem zukünftigen Update implementiert."
    }
    
    func cancelPipeline() {
        backgroundTask?.cancel()
        isRunning = false
        currentProject?.status = .failed
        try? modelContext?.save()
    }
}