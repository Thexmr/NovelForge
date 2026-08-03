import Foundation
import OSLog
import SwiftData

enum ProductionRecoveryPolicy {
    static func shouldAutoResume(result: String?, projectStatus: ProjectStatus) -> Bool {
        guard projectStatus == .paused else { return false }
        let reason = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (reason.hasPrefix("Die App wurde während ")
                || reason.hasPrefix("Die App wurde zwischen "))
            && reason.contains("gespeicherte Stand ist vollständig")
    }

    /// Ein aktiver Phasenstatus kann nach einem frischen Prozessstart nicht echt
    /// weiterlaufen. Er bedeutet, dass die App genau zwischen zwei persistierten Jobs
    /// beendet wurde. `paused` ist ausdrücklich nicht enthalten, damit eine manuelle
    /// Pause niemals automatisch aufgehoben wird.
    static func isOrphanedActiveStatus(_ status: ProjectStatus) -> Bool {
        switch status {
        case .conceptDevelopment, .structurePlanning, .chapterPlanning, .scenePlanning,
             .drafting, .chapterRevision, .manuscriptRevision, .proofreading,
             .copyrightCheck, .kdpFormatting, .export:
            return true
        case .created, .completed, .needsReview, .failed, .paused:
            return false
        }
    }

    static func phase(for status: ProjectStatus) -> PipelinePhase {
        switch status {
        case .conceptDevelopment: return .conceptDevelopment
        case .structurePlanning: return .structurePlanning
        case .chapterPlanning: return .chapterPlanning
        case .scenePlanning: return .scenePlanning
        case .drafting: return .drafting
        case .chapterRevision: return .chapterRevision
        case .manuscriptRevision: return .manuscriptRevision
        case .proofreading: return .proofreading
        case .copyrightCheck: return .copyrightCheck
        case .kdpFormatting: return .kdpFormatting
        case .export: return .export
        case .created, .completed, .needsReview, .failed, .paused: return .projectSetup
        }
    }
}

@MainActor
enum ProductionRecoveryService {
    private static var didRecoverThisLaunch = false

    /// Jobs mit einem aktiven Status stammen nach einem App-Neustart zwingend aus
    /// dem vorherigen Prozess. Sie werden pausiert, damit die idempotente Pipeline
    /// sie fortsetzen kann und kein verwaister Job die Veröffentlichung blockiert.
    @discardableResult
    static func recoverInterruptedJobs(in modelContext: ModelContext) -> Int {
        guard !didRecoverThisLaunch, !PipelineOrchestrator.shared.isRunning else { return 0 }

        let activeStatuses: Set<JobStatus> = [
            .waiting, .running, .writing, .checking, .revising, .retrying
        ]
        let recentJobs: [PipelineJob]
        do {
            var recentDescriptor = FetchDescriptor<PipelineJob>(
                sortBy: [SortDescriptor(\PipelineJob.createdAt, order: .reverse)]
            )
            // Selbst bei zehn parallelen Büchern liegen alle Jobs des vorherigen
            // Prozesses sicher unter den neuesten 250 Einträgen. Der begrenzte Fetch
            // hält den App-Start auch nach tausenden Produktionsschritten schnell.
            recentDescriptor.fetchLimit = 250
            recentJobs = try modelContext.fetch(recentDescriptor)
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Unterbrochene Jobs konnten nicht geladen werden: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        didRecoverThisLaunch = true

        let now = Date()
        var recoveredJobs = 0
        var projectsWithInterruptedJob = Set<UUID>()
        for job in recentJobs where activeStatuses.contains(job.status) {
            job.status = .paused
            job.endTime = now
            job.lastHeartbeat = now
            setRecoveryReasonIfMissing(for: job, appWasInterrupted: true)
            recoveredJobs += 1

            guard let project = job.project,
                  project.status != .completed,
                  project.status != .needsReview else { continue }
            projectsWithInterruptedJob.insert(project.id)
            project.status = .paused
            project.updatedAt = now
        }

        // App-Abbruch GENAU zwischen zwei Jobs: Der letzte Job ist bereits abgeschlossen,
        // das Projekt trägt aber noch einen aktiven Phasenstatus. Ohne Recovery-Marker
        // blieb es nach dem Neustart unbegrenzt auf „Rohfassung“, ohne Job, Heartbeat oder
        // Fehlermeldung. Dieser Zustand wurde im echten 50-Seiten-Test reproduziert.
        let projects: [Project]
        do {
            projects = try modelContext.fetch(FetchDescriptor<Project>())
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Verwaiste Projekte konnten nicht geladen werden: \(error.localizedDescription, privacy: .public)")
            return recoveredJobs
        }
        for project in projects
        where ProductionRecoveryPolicy.isOrphanedActiveStatus(project.status)
            && !projectsWithInterruptedJob.contains(project.id) {
            let phase = ProductionRecoveryPolicy.phase(for: project.status)
            let marker = PipelineJob(agentName: "Recovery Monitor", phase: phase)
            marker.status = .paused
            marker.startTime = now
            marker.endTime = now
            marker.lastHeartbeat = now
            marker.result = "Die App wurde zwischen zwei Produktionsschritten in der Phase \(phase.rawValue) beendet. Der gespeicherte Stand ist vollständig und kann fortgesetzt werden."
            marker.project = project
            modelContext.insert(marker)
            project.status = .paused
            project.updatedAt = now
            projectsWithInterruptedJob.insert(project.id)
            recoveredJobs += 1
        }

        // Ein älterer Build konnte den Status bereits auf „pausiert“ setzen, ohne
        // einen Erklärungstext zu hinterlassen. Diese kleinen Altlasten werden beim
        // nächsten Start nachgetragen, ohne tausende abgeschlossene Jobs zu laden.
        var backfilledReasons = 0
        for job in recentJobs where job.status == .paused {
            if setRecoveryReasonIfMissing(for: job, appWasInterrupted: false) {
                backfilledReasons += 1
            }
        }

        if recoveredJobs > 0 || backfilledReasons > 0 {
            modelContext.saveOrLog()
        }
        if let incident = recentJobs.first(where: {
            $0.status == .paused
                && $0.project?.status != .completed
                && !($0.result ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.result {
            ProductionIncidentStore.record(incident)
        } else {
            // Historische Pausen eines inzwischen fertiggestellten Buchs sind kein
            // aktueller Produktionsabbruch und dürfen nach einem Neustart nicht wieder
            // als Warnung erscheinen.
            ProductionIncidentStore.clear()
        }
        Logger(subsystem: "com.novelforge.app", category: "recovery")
            .info("Startprüfung abgeschlossen: \(recoveredJobs) offene Jobs pausiert, \(backfilledReasons) Hinweise ergänzt")
        return recoveredJobs
    }

    /// Korrigiert den Altzustand früherer Builds: Ein komplett geschriebenes Buch mit
    /// offenen Lektoratsbefunden wurde nach dem Reparaturlimit fälschlich als technischer
    /// Fehler gespeichert. Solche Projekte werden beim Start sichtbar neu eingeordnet.
    @discardableResult
    static func reclassifyCompletedManuscripts(in modelContext: ModelContext) -> Int {
        let projects: [Project]
        do {
            projects = try modelContext.fetch(FetchDescriptor<Project>())
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Projektstatus konnte nicht geprüft werden: \(error.localizedDescription, privacy: .public)")
            return 0
        }

        var changed = 0
        for project in projects where project.status == .failed {
            let chapters = project.chapters ?? []
            let texts = chapters.map { $0.rawBestText ?? "" }
            let hasOpenBlockingFinding = (project.qualityReports ?? []).contains {
                !$0.autoFixed && ($0.severity == .critical || $0.severity == .error)
            }
            guard hasOpenBlockingFinding,
                  ProductionCompletionPolicy.shouldRequireReview(
                    chapterTexts: texts,
                    readinessShortfall: true,
                    retriesExhausted: true
                  ) else { continue }
            project.status = .needsReview
            project.updatedAt = Date()
            changed += 1
        }
        if changed > 0 { modelContext.saveOrLog("Altstatus Prüfung erforderlich") }
        return changed
    }

    /// Bereinigt auch historische Rohszenen in der Datenbank. Der Export ist bereits
    /// defensiv geschützt; diese Migration verhindert zusätzlich, dass Arbeitsmarken
    /// bei einer späteren Szenenreparatur wieder in ein Kapitel zurückgelangen.
    @discardableResult
    static func sanitizePersistedScenes(in modelContext: ModelContext) -> Int {
        let scenes: [StoryScene]
        do {
            scenes = try modelContext.fetch(FetchDescriptor<StoryScene>())
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Rohszenen konnten nicht bereinigt werden: \(error.localizedDescription, privacy: .public)")
            return 0
        }

        var changed = 0
        for scene in scenes {
            guard let text = scene.text, !text.isEmpty else { continue }
            let cleaned = AutonomousContentQuality.cleaningStoredBookText(
                text,
                bookTitle: scene.chapter?.project?.title ?? ""
            )
            guard cleaned != text else { continue }
            scene.text = cleaned
            scene.updatedAt = Date()
            changed += 1
        }
        if changed > 0 { modelContext.saveOrLog("Historische Rohszenen bereinigt") }
        return changed
    }

    /// Nur ein durch App-Abbruch unterbrochener NEUESTER Projektjob darf automatisch
    /// fortgesetzt werden. Eine manuelle Pause bleibt dadurch immer respektiert.
    static func automaticResumeCandidate(in modelContext: ModelContext) -> Project? {
        let recentJobs: [PipelineJob]
        do {
            var descriptor = FetchDescriptor<PipelineJob>(
                sortBy: [SortDescriptor(\PipelineJob.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 250
            recentJobs = try modelContext.fetch(descriptor)
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Auto-Fortsetzung konnte Jobs nicht laden: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        var seenProjects = Set<UUID>()
        for job in recentJobs {
            guard let project = job.project else { continue }
            guard seenProjects.insert(project.id).inserted else { continue }
            guard job.status == .paused,
                  ProductionRecoveryPolicy.shouldAutoResume(
                    result: job.result,
                    projectStatus: project.status
                  ) else { continue }
            return project
        }
        return nil
    }

    @discardableResult
    private static func setRecoveryReasonIfMissing(for job: PipelineJob,
                                                   appWasInterrupted: Bool) -> Bool {
        guard (job.result ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let location = [
            job.chapterNumber.map { "Kapitel \($0)" },
            job.sceneNumber.map { "Szene \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")
        let step = "\(job.agentName)\(location.isEmpty ? "" : " (\(location))")"
        job.result = appWasInterrupted
            ? "Die App wurde während \(step) beendet. Der gespeicherte Stand ist vollständig und kann fortgesetzt werden."
            : "Die Produktion wurde während \(step) unterbrochen. Der gespeicherte Stand ist vollständig und kann fortgesetzt werden."
        return true
    }
}
