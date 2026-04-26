import Foundation

protocol Agent {
    var name: String { get }
    var description: String { get }
    func execute(context: AgentContext) async throws -> AgentResult
}

struct AgentContext {
    let project: Project
    let chapter: Chapter?
    let scene: StoryScene?
    let storyBible: StoryBible?
    let previousResults: [String: String]
    let provider: AIProvider
    let model: String
}

struct AgentResult {
    let success: Bool
    let output: String
    let updatedContext: [String: String]
    let qualityIssues: [QualityIssue]
}

struct QualityIssue {
    let severity: Severity
    let message: String
    let suggestion: String
}

actor AgentRuntime {
    static let shared = AgentRuntime()
    private var activeAgents: [String: Task<AgentResult, Error>] = [:]
    private var heartbeatInterval: TimeInterval = 30
    
    func executeAgent(_ agent: Agent, context: AgentContext, job: PipelineJob) async throws -> AgentResult {
        let taskId = "\(agent.name)-\(job.id.uuidString)"
        
        // Start heartbeat
        let heartbeatTask = Task {
            while !Task.isCancelled {
                await updateHeartbeat(job: job)
                try await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
            }
        }
        
        defer {
            heartbeatTask.cancel()
            activeAgents.removeValue(forKey: taskId)
        }
        
        do {
            let result = try await agent.execute(context: context)
            await completeJob(job: job, result: result)
            return result
        } catch {
            await failJob(job: job, error: error)
            throw error
        }
    }
    
    private func updateHeartbeat(job: PipelineJob) async {
        job.lastHeartbeat = Date()
    }
    
    private func completeJob(job: PipelineJob, result: AgentResult) async {
        job.status = .completed
        job.endTime = Date()
        job.result = result.output
    }
    
    private func failJob(job: PipelineJob, error: Error) async {
        job.status = .failed
        job.endTime = Date()
        job.errorCount += 1
        job.result = error.localizedDescription
    }
}

// MARK: - Specialized Agents

struct InputAgent: Agent {
    let name = "Input Agent"
    let description = "Prüft und normalisiert Nutzereingaben"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        var warnings: [String] = []
        var blocked: [String] = []
        
        // Validate title
        if context.project.title.isEmpty {
            throw AIError.systemError("Titel ist erforderlich")
        }
        
        // Validate author
        if context.project.authorName.isEmpty {
            throw AIError.systemError("Autorname ist erforderlich")
        }
        
        // Validate page count
        if context.project.targetPageCount < 50 || context.project.targetPageCount > 500 {
            throw AIError.systemError("Seitenzahl muss zwischen 50 und 500 liegen")
        }
        
        // Check for risky copyright inputs
        let riskyTerms = ["bestsellerautor", "kopiere", "fortsetzung von", "wie j.k. rowling", "wie stephen king"]
        let input = "\(context.project.title) \(context.project.styleProfile)".lowercased()
        for term in riskyTerms {
            if input.contains(term) {
                blocked.append("Riskante Copyright-Vorgabe erkannt: '\(term)'")
            }
        }
        
        let output = """
        Projekt validiert:
        - Titel: \(context.project.title)
        - Autor: \(context.project.authorName)
        - Genre: \(context.project.genre)
        - Sprache: \(context.project.language)
        - Zielseiten: \(context.project.targetPageCount)
        - Stil: \(context.project.styleProfile)
        - Warnungen: \(warnings.joined(separator: ", "))
        - Blockiert: \(blocked.joined(separator: ", "))
        """
        
        return AgentResult(
            success: blocked.isEmpty,
            output: output,
            updatedContext: ["input_validated": "true"],
            qualityIssues: blocked.map { QualityIssue(severity: .error, message: $0, suggestion: "Verwenden Sie abstrakte Stilprofile statt konkreter Autoren.") }
        )
    }
}

struct ConceptAgent: Agent {
    let name = "Concept Agent"
    let description = "Erstellt Prämisse, Logline und Exposé"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        let prompt = """
        Erstelle ein Buchkonzept für:
        Titel: \(context.project.title)
        Genre: \(context.project.genre)
        Sprache: \(context.project.language)
        Stil: \(context.project.styleProfile)
        Zielseiten: \(context.project.targetPageCount)
        
        Gib zurück im Format:
        PRÄMISSE: [1-2 Sätze]
        LOGLINE: [Ein Satz]
        EXPOSE: [3-5 Sätze]
        HAUPTKONFLIKT: [1 Satz]
        THEMA: [1-2 Wörter]
        ZIELGRUPPE: [Beschreibung]
        TONALITÄT: \(context.project.styleProfile)
        """
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: "Du bist ein erfahrener Buchautor und erstellst überzeugende Buchkonzepte. Die Idee muss eigenständig sein und keine geschützten Werke nachahmen.",
            model: context.model,
            provider: context.provider,
            maxTokens: 2000,
            temperature: 0.8,
            stream: false
        )
        
        let response = try await ProviderGateway.shared.generateText(request: request)
        
        return AgentResult(
            success: true,
            output: response.text,
            updatedContext: ["concept": response.text],
            qualityIssues: []
        )
    }
}

struct PlotArchitectAgent: Agent {
    let name = "Plot Architect"
    let description = "Erstellt den Gesamtplot und Kapitelstruktur"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        let estimatedChapters = max(10, context.project.targetPageCount / 15)
        
        let prompt = """
        Erstelle einen detaillierten Plot für das Buch "\(context.project.title)".
        Genre: \(context.project.genre)
        Stil: \(context.project.styleProfile)
        Zielseiten: \(context.project.targetPageCount) (~\(estimatedChapters) Kapitel)
        
        Konzept: \(context.previousResults["concept"] ?? "")
        
        Definiere:
        1. Anfang und Auslöser
        2. Zentrale Frage
        3. Wendepunkte (mindestens 3)
        4. Krise und finale Eskalation
        5. Höhepunkt und Auflösung
        6. Kapitelübersicht mit Seitenverteilung
        
        Format:
        PLOT: [Detaillierte Beschreibung]
        KAPITEL: [Nummer - Titel - Seiten - Ziel]
        """
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: "Du bist ein Plot-Architekt für Romane. Erstelle strukturierte, spannende Plots mit klarem Spannungsbogen.",
            model: context.model,
            provider: context.provider,
            maxTokens: 4000,
            temperature: 0.7,
            stream: false
        )
        
        let response = try await ProviderGateway.shared.generateText(request: request)
        
        return AgentResult(
            success: true,
            output: response.text,
            updatedContext: ["plot": response.text],
            qualityIssues: []
        )
    }
}

struct CharacterArchitectAgent: Agent {
    let name = "Character Architect"
    let description = "Erstellt Figurenprofile"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        let prompt = """
        Erstelle Figuren für "\(context.project.title)".
        Genre: \(context.project.genre)
        Plot: \(context.previousResults["plot"] ?? "")
        
        Erstelle:
        1. Hauptfigur (Protagonist)
        2. Gegenspieler (Antagonist)
        3. 3-5 Nebenfiguren
        
        Für jede Figur:
        - Name, Rolle, Alter, Beruf
        - Ziel, Angst, Schwäche
        - Innere Konflikte und äußere Ziele
        - Entwicklungsbogen
        - Beziehungen zu anderen Figuren
        - Sprachmuster
        """
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: "Du bist ein Charakter-Entwickler. Erstelle tiefe, glaubwürdige Figuren mit klaren Motivationen.",
            model: context.model,
            provider: context.provider,
            maxTokens: 4000,
            temperature: 0.7,
            stream: false
        )
        
        let response = try await ProviderGateway.shared.generateText(request: request)
        
        return AgentResult(
            success: true,
            output: response.text,
            updatedContext: ["characters": response.text],
            qualityIssues: []
        )
    }
}

struct DraftWriterAgent: Agent {
    let name = "Draft Writer"
    let description = "Schreibt einzelne Szenen"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        guard let scene = context.scene, let chapter = context.chapter else {
            throw AIError.systemError("Keine Szene oder Kapitel im Kontext")
        }
        
        let prompt = """
        Schreibe Szene \(scene.sceneNumber) aus Kapitel \(chapter.chapterNumber): "\(chapter.title)"
        
        Szenen-Details:
        - Perspektive: \(scene.perspective)
        - Ort: \(scene.location)
        - Zeit: \(scene.time)
        - Ziel: \(scene.goal)
        - Hindernis: \(scene.obstacle)
        - Zielwortzahl: \(scene.targetWordCount)
        
        Stil: \(context.project.styleProfile)
        Sprache: \(context.project.language)
        
        Story Bible Auszug:
        \(context.storyBible?.styleRules ?? "")
        
        Vorherige Zusammenfassung:
        \(context.previousResults["previous_summary"] ?? "Anfang des Buches")
        
        Wichtig:
        - Halte den Stil konsequent
        - Zeige, erzähle nicht
        - Jede Szene muss etwas verändern
        - Keine Füllszenen
        """
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: "Du bist ein professioneller Romanautor. Schreibe lebendige, atmosphärische Szenen mit natürlichen Dialogen.",
            model: context.model,
            provider: context.provider,
            maxTokens: min(scene.targetWordCount * 2, 4000),
            temperature: 0.85,
            stream: false
        )
        
        let response = try await ProviderGateway.shared.generateText(request: request)
        
        let wordCount = response.text.wordCount
        let tolerance = Double(scene.targetWordCount) * 0.2
        var issues: [QualityIssue] = []
        
        if abs(wordCount - scene.targetWordCount) > Int(tolerance) {
            issues.append(QualityIssue(
                severity: .warning,
                message: "Wortzahl außerhalb der Toleranz: \(wordCount) statt \(scene.targetWordCount)",
                suggestion: "Szene anpassen oder neu schreiben"
            ))
        }
        
        return AgentResult(
            success: true,
            output: response.text,
            updatedContext: ["scene_text": response.text, "word_count": "\(wordCount)"],
            qualityIssues: issues
        )
    }
}

struct ProofreaderAgent: Agent {
    let name = "Proofreader"
    let description = "Prüft Rechtschreibung, Grammatik und Zeichensetzung"
    
    func execute(context: AgentContext) async throws -> AgentResult {
        guard let text = context.previousResults["text_to_proofread"] else {
            throw AIError.systemError("Kein Text zum Korrekturlesen")
        }
        
        let prompt = """
        Korrigiere den folgenden Text. Beachte:
        - Rechtschreibung
        - Grammatik
        - Zeichensetzung
        - Tippfehler
        - Doppelte Wörter
        - Inkonsistente Anführungszeichen
        
        Text:
        \(text)
        
        Gib nur den korrigierten Text zurück, ohne Erklärungen.
        """
        
        let request = GenerationRequest(
            prompt: prompt,
            systemPrompt: "Du bist ein professioneller Korrektor. Korrigiere nur offensichtliche Fehler, ändere den Stil nicht.",
            model: context.model,
            provider: context.provider,
            maxTokens: text.count + 1000,
            temperature: 0.1,
            stream: false
        )
        
        let response = try await ProviderGateway.shared.generateText(request: request)
        
        return AgentResult(
            success: true,
            output: response.text,
            updatedContext: ["proofread_text": response.text],
            qualityIssues: []
        )
    }
}