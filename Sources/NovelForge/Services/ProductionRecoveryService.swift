import Foundation
import OSLog
import SwiftData

enum ProductionRecoveryPolicy {
    /// Beschriftung für einen Lauf, der ohne Nutzeraktion abgerissen ist. Nur dieser
    /// Text (und die App-Beendet-Meldungen) erlaubt automatisches Fortsetzen – eine
    /// von Hand gedrückte Pause bleibt weiterhin unangetastet liegen.
    static let involuntaryStopMarker =
        "Die Produktion wurde unerwartet unterbrochen. Der gespeicherte Stand ist vollständig und wird automatisch fortgesetzt."

    static func shouldAutoResume(result: String?, projectStatus: ProjectStatus) -> Bool {
        // `failed` gehört dazu: ein abgerissener Lauf landete bisher dort und war
        // damit endgültig tot, obwohl jede geschriebene Szene noch vorhanden war.
        guard projectStatus == .paused || projectStatus == .failed else { return false }
        let reason = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if reason == involuntaryStopMarker { return true }
        // Ein Lauf, den nur der volle Datentraeger gestoppt hat, ist genauso fortsetzbar
        // wie ein abgerissener: Der Grund verschwindet von selbst, sobald wieder Platz
        // frei ist. Ohne diese Regel blieb ein so gestopptes Buch liegen, bis jemand von
        // Hand auf „Fortsetzen" drueckte – auch dann noch, wenn laengst wieder 9 GB frei
        // waren. Genau so lag „Morgen frueh bei dir" seit dem 09.09.2026, 16:02 still.
        if ProductionStorageGuard.isStorageFailureMessage(reason) { return true }
        return (reason.hasPrefix("Die App wurde während ")
                || reason.hasPrefix("Die App wurde zwischen "))
            && reason.contains("gespeicherte Stand ist vollständig")
    }

    /// Höchstzahl automatischer Neuanläufe eines fehlgeschlagenen Buchs.
    ///
    /// Buch 11 lag mit 48 fertigen Szenen und 31.362 Wörtern still, weil ein einzelnes
    /// Kapitel scheiterte. Ein Buch mit echtem Fortschritt bekommt deshalb weitere
    /// Anläufe – aber nicht unbegrenzt, sonst dreht ein dauerhaft kaputtes Projekt
    /// endlos im Kreis und verbrennt Kontingent.
    static let maxAutoNeustarts = 4

    /// Darf ein hart fehlgeschlagenes Projekt erneut angefahren werden?
    /// Bedingung: es ist bereits substanzieller Text vorhanden und die Zahl der
    /// bisherigen Fehlversuche liegt unter der Grenze.
    static func shouldRetryFailed(wordCount: Int, previousFailures: Int) -> Bool {
        wordCount >= 500 && previousFailures < maxAutoNeustarts
    }

    static func failuresSinceLastProgress(failureDates: [Date],
                                          progressDates: [Date]) -> Int {
        guard let lastProgress = progressDates.max() else { return failureDates.count }
        return failureDates.filter { $0 > lastProgress }.count
    }

    /// Namen, die in einem gespeicherten Plan handeln, aber nicht zur aktuellen
    /// Figurenbibel gehören. Das ist der typische Altzustand nach einer früheren
    /// Teil-Neugenerierung: Profile und Szenenperspektiven sind neu, Kapitelziele
    /// erzählen aber weiterhin die alte Geschichte.
    static func unexpectedPlanNames(planTexts: [String],
                                    allowedNames: [String]) -> [String] {
        let allowed = Set(allowedNames.flatMap(CharacterCanonAudit.nameParts))
        var found = Set<String>()
        let planningLabels: Set<String> = [
            "aktive", "entscheidung", "emotionaler", "schritt", "neue", "lage",
            "folge", "aus", "kapitel", "szene", "ausloeser", "auslöser"
        ]
        for text in planTexts {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let expression = try? NSRegularExpression(
                pattern: #"(?<!\p{L})([\p{Lu}][\p{L}'’-]{2,})\s+([\p{Lu}][\p{L}'’-]{2,})(?!\p{L})"#
            ) {
                for match in expression.matches(in: text, range: range) {
                    let first = ns.substring(with: match.range(at: 1))
                    let second = ns.substring(with: match.range(at: 2))
                    guard first != first.uppercased(), second != second.uppercased(),
                          !planningLabels.contains(first.lowercased()),
                          !planningLabels.contains(second.lowercased()) else { continue }
                    for part in CharacterCanonAudit.nameParts("\(first) \(second)")
                    where !allowed.contains(part) {
                        found.insert(part)
                    }
                }
            }
            if let expression = try? NSRegularExpression(
                pattern: #"(?<!\p{L})([\p{Lu}][\p{L}'’-]{2,})['’]\s+\p{L}"#
            ) {
                for match in expression.matches(in: text, range: range)
                where match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                    let candidate = ns.substring(with: match.range(at: 1))
                    if let part = CharacterCanonAudit.nameParts(candidate).first,
                       !allowed.contains(part) {
                        found.insert(part)
                    }
                }
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: #"^[\p{Lu}][\p{L}'’-]{2,}$"#,
                             options: .regularExpression) != nil,
               let part = CharacterCanonAudit.nameParts(trimmed).first,
               !allowed.contains(part) {
                found.insert(part)
            }
        }
        return found.subtracting(allowed).sorted()
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
                && ProductionIncidentStore.isActionable($0.result ?? "")
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

    /// Heilt Figurenkanon-Altlasten frueherer Parser ueber ALLE gespeicherten Quellen.
    /// Eine Teilreparatur waere schlimmer als keine: Expose, Kapitelplan und Prosa
    /// muessen danach denselben Namen tragen.
    @discardableResult
    static func repairLegacyCharacterCanon(in modelContext: ModelContext) -> Int {
        let projects: [Project]
        do {
            projects = try modelContext.fetch(FetchDescriptor<Project>())
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "recovery")
                .error("Figurenkanon konnte nicht geladen werden: \(error.localizedDescription, privacy: .public)")
            return 0
        }

        var changedProjects = 0
        for project in projects where !project.isNonfiction {
            guard let bible = project.storyBible else { continue }
            let characters = bible.characters ?? []
            let relationships = Dictionary(
                uniqueKeysWithValues: characters.map { ($0.name, $0.relationships) }
            )
            let replacements = CharacterCanonAudit.legacyPossessiveAliasReplacements(
                characterNames: characters.map(\.name),
                relationshipsByName: relationships
            )
            let invalidProfiles = characters.filter { character in
                if CharacterCanonAudit.isNonPersonCharacterRole(character.role) { return true }
                let parts = character.name.split(whereSeparator: { !$0.isLetter }).map(String.init)
                guard parts.count == 2, parts[1].lowercased().hasSuffix("s") else {
                    return false
                }
                let stale = String(parts[1].dropLast())
                return replacements.keys.contains(where: {
                    $0.caseInsensitiveCompare(stale) == .orderedSame
                })
            }
            let chapters = project.chapters ?? []
            let hasWrittenProse = chapters.contains {
                !(($0.rawBestText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            let rejectedScenePlanReports = (project.qualityReports ?? []).filter {
                !$0.autoFixed
                    && $0.checkType == "Szenenplan"
                    && $0.result.localizedCaseInsensitiveContains("verworfen")
            }
            let rejectedScenePlans = rejectedScenePlanReports.count
            let hasStalledUnwrittenPlan = !hasWrittenProse && !chapters.isEmpty
                && rejectedScenePlans >= 12
            guard !replacements.isEmpty || !invalidProfiles.isEmpty
                    || hasStalledUnwrittenPlan else { continue }

            func renamed(_ text: String) -> String {
                CharacterCanonAudit.replacingNames(in: text, replacements: replacements)
            }
            if let profile = project.bookProfile {
                profile.premise = renamed(profile.premise)
                profile.logline = profile.logline.map(renamed)
                profile.synopsis = profile.synopsis.map(renamed)
                profile.kdpDescription = renamed(profile.kdpDescription)
                profile.coverPrompts = renamed(profile.coverPrompts)
            }
            bible.timeline = renamed(bible.timeline)
            bible.plotPoints = renamed(bible.plotPoints)
            bible.openQuestions = renamed(bible.openQuestions)
            bible.resolvedQuestions = renamed(bible.resolvedQuestions)
            bible.terms = renamed(bible.terms)
            for character in characters where !invalidProfiles.contains(where: { $0.id == character.id }) {
                character.name = renamed(character.name)
                character.goal = renamed(character.goal)
                character.fear = renamed(character.fear)
                character.weakness = renamed(character.weakness)
                character.development = renamed(character.development)
                character.relationships = renamed(character.relationships)
                character.importantFacts = renamed(character.importantFacts)
            }
            for chapter in project.chapters ?? [] {
                chapter.title = renamed(chapter.title)
                chapter.goal = renamed(chapter.goal)
                chapter.conflict = renamed(chapter.conflict)
                chapter.perspectiveCharacter = chapter.perspectiveCharacter.map(renamed)
                chapter.draftText = chapter.draftText.map(renamed)
                chapter.revisedText = chapter.revisedText.map(renamed)
                chapter.finalText = chapter.finalText.map(renamed)
                chapter.summary = chapter.summary.map(renamed)
                for scene in chapter.scenes ?? [] {
                    scene.perspective = renamed(scene.perspective)
                    scene.location = renamed(scene.location)
                    scene.involvedCharacters = renamed(scene.involvedCharacters)
                    scene.goal = renamed(scene.goal)
                    scene.obstacle = renamed(scene.obstacle)
                    scene.emotionalChange = renamed(scene.emotionalChange)
                    scene.newInformation = renamed(scene.newInformation)
                    scene.cliffhanger = renamed(scene.cliffhanger)
                    scene.text = scene.text.map(renamed)
                    scene.summary = scene.summary.map(renamed)
                }
            }
            for character in invalidProfiles {
                bible.characters?.removeAll { $0.id == character.id }
                modelContext.delete(character)
            }
            // Ohne Prosa ist ein gemischter Plan nicht erhaltenswert: Eine blinde
            // Zuordnung Elena -> Agnieszka könnte Rollen vertauschen. Die sichere
            // Reparatur ist, Kapitel und Szenen zu löschen und aus dem aktuellen
            // Primärkanon neu planen zu lassen. Geschriebener Text bleibt tabu.
            if hasStalledUnwrittenPlan {
                for chapter in chapters { modelContext.delete(chapter) }
                project.chapters = []
                for report in rejectedScenePlanReports { report.autoFixed = true }
            }
            bible.updatedAt = Date()
            project.updatedAt = Date()

            let report = QualityReport(
                checkedArea: "Buchkanon",
                checkType: "Historische Plan- und Figurenkorrektur",
                result: "Historische Plan-/Figurenaltlasten automatisch bereinigt: "
                    + (replacements.map { "\($0.key) -> \($0.value)" }
                        + invalidProfiles.map(\.name)
                        + (hasStalledUnwrittenPlan
                           ? ["festgefahrener Altplan (\(rejectedScenePlans) Ablehnungen)"]
                           : []))
                        .sorted().joined(separator: ", "),
                severity: .info,
                recommendation: "Alle Kanonquellen und vorhandenen Texte verwenden wieder dieselben Figuren."
            )
            report.autoFixed = true
            report.project = project
            if project.qualityReports == nil { project.qualityReports = [] }
            project.qualityReports?.append(report)
            modelContext.insert(report)
            changedProjects += 1
        }
        if changedProjects > 0 {
            modelContext.saveOrLog("Historischen Figurenkanon repariert")
        }
        return changedProjects
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

        // Fehlgeschlagene Bücher mit echtem Fortschritt zuerst: Buch 11 lag mit 48
        // fertigen Szenen still, weil ein einzelnes Kapitel scheiterte. Die Prüfung
        // läuft bewusst über die Projekte statt über den jeweils neuesten Job – der
        // letzte Job eines Projekts ist nicht zwangsläufig der fehlgeschlagene, und
        // genau daran lief die Erkennung vorher vorbei.
        if let projekte = try? modelContext.fetch(FetchDescriptor<Project>()) {
            for project in projekte where project.status == .failed {
                let jobs = project.pipelineJobs ?? []
                guard jobs.contains(where: { $0.status == .failed }) else { continue }
                let wörter = (project.chapters ?? []).reduce(0) { summe, kapitel in
                    summe + (kapitel.finalText ?? kapitel.revisedText ?? kapitel.draftText ?? "").wordCount
                        + (kapitel.scenes ?? []).reduce(0) { $0 + ($1.text ?? "").wordCount }
                }
                let fehlversuche = ProductionRecoveryPolicy.failuresSinceLastProgress(
                    failureDates: jobs.filter { $0.status == .failed }.map(\.createdAt),
                    progressDates: jobs.filter {
                        $0.status == .completed && $0.agentName == AgentName.draftWriter
                    }.map(\.createdAt)
                )
                if ProductionRecoveryPolicy.shouldRetryFailed(wordCount: wörter,
                                                              previousFailures: fehlversuche) {
                    return project
                }
            }
        }

        var seenProjects = Set<UUID>()
        for job in recentJobs {
            guard let project = job.project else { continue }
            guard seenProjects.insert(project.id).inserted else { continue }
            // Ein Speichermangel beendet den Job als „fehlgeschlagen", nicht als
            // „pausiert" – ohne diese Ausnahme lief die Selbstheilung daran vorbei.
            let wurdeVonSpeichermangelGestoppt =
                ProductionStorageGuard.isStorageFailureMessage(job.result ?? "")
            guard job.status == .paused || wurdeVonSpeichermangelGestoppt,
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
