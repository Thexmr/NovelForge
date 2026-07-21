import Foundation
import OSLog
import SwiftData

enum ProductionRecoveryPolicy {
    static func shouldAutoResume(result: String?, projectStatus: ProjectStatus) -> Bool {
        guard projectStatus == .paused else { return false }
        let reason = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reason.hasPrefix("Die App wurde während ")
            && reason.contains("gespeicherte Stand ist vollständig")
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
        for job in recentJobs where activeStatuses.contains(job.status) {
            job.status = .paused
            job.endTime = now
            job.lastHeartbeat = now
            setRecoveryReasonIfMissing(for: job, appWasInterrupted: true)
            recoveredJobs += 1

            guard let project = job.project, project.status != .completed else { continue }
            project.status = .paused
            project.updatedAt = now
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
