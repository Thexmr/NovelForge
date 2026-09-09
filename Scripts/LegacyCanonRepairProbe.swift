import Foundation
import SwiftData

@main
@MainActor
enum LegacyCanonRepairProbe {
    static func main() {
        guard let storePath = ProcessInfo.processInfo.environment["NF_REPAIR_STORE"],
              !storePath.isEmpty else {
            print("REPAIR_FAIL: NF_REPAIR_STORE fehlt")
            exit(2)
        }
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(
                    schema: schema, url: URL(fileURLWithPath: storePath)
                )]
            )
            let context = ModelContext(container)
            let projectsBeforeRepair = try context.fetch(FetchDescriptor<Project>())
            let stalledProjectIDs = Set(projectsBeforeRepair.compactMap { project -> UUID? in
                let chapters = project.chapters ?? []
                let hasWrittenProse = chapters.contains {
                    !(($0.rawBestText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                let rejectedPlans = (project.qualityReports ?? []).filter {
                    !$0.autoFixed
                        && $0.checkType == "Szenenplan"
                        && $0.result.localizedCaseInsensitiveContains("verworfen")
                }.count
                return !hasWrittenProse && !chapters.isEmpty && rejectedPlans >= 12
                    ? project.id : nil
            })
            let expectStalledPlan = ProcessInfo.processInfo.environment["NF_EXPECT_STALLED"] != "0"
            if expectStalledPlan {
                precondition(!stalledProjectIDs.isEmpty,
                             "Testdaten enthalten keinen festgefahrenen Altplan")
            }
            let changed = ProductionRecoveryService.repairLegacyCharacterCanon(in: context)
            let projects = try context.fetch(FetchDescriptor<Project>())
            guard let project = projects.first(where: { $0.title == "Die Nacht jagt dich" }) else {
                print("REPAIR_FAIL: Testprojekt fehlt")
                exit(3)
            }
            let names = (project.storyBible?.characters ?? []).map(\.name)
            let allCanon = [
                project.bookProfile?.premise ?? "",
                project.bookProfile?.logline ?? "",
                project.bookProfile?.synopsis ?? "",
                project.storyBible?.plotPoints ?? "",
                project.storyBible?.timeline ?? "",
            ] + (project.chapters ?? []).flatMap { chapter in
                [chapter.title, chapter.goal, chapter.conflict, chapter.summary ?? ""]
                    + (chapter.scenes ?? []).flatMap { scene in
                        [scene.perspective, scene.involvedCharacters, scene.goal,
                         scene.obstacle, scene.emotionalChange, scene.newInformation,
                         scene.cliffhanger, scene.summary ?? "", scene.text ?? ""]
                    }
            }
            let combined = allCanon.joined(separator: "\n")
            precondition(!names.contains("Wald"), "Ein Schauplatz blieb als Figur gespeichert")
            precondition(!names.contains("Ostwald Livs"), "Das Aliasprofil blieb gespeichert")
            precondition(!combined.localizedCaseInsensitiveContains("Livs"),
                         "Der alte Genitivname blieb im Kanon")
            let livPattern = #"(?i)(?<!\p{L})Liv(?!\p{L})"#
            precondition(combined.range(of: livPattern, options: .regularExpression) == nil,
                         "Der alte Einzelname blieb im Kanon")
            precondition(names.contains("Hagedorn"), "Die kanonische Tochter ging verloren")
            let repairedStalledProjects = projects.filter { stalledProjectIDs.contains($0.id) }
            precondition(repairedStalledProjects.allSatisfy { ($0.chapters ?? []).isEmpty },
                         "Ein festgefahrener Altplan blieb gespeichert")
            let unresolvedRejectedPlans = repairedStalledProjects.flatMap { project in
                (project.qualityReports ?? []).filter {
                    !$0.autoFixed
                        && $0.checkType == "Szenenplan"
                        && $0.result.localizedCaseInsensitiveContains("verworfen")
                }
            }
            precondition(
                unresolvedRejectedPlans.isEmpty,
                "Bereits verworfene Altplaene blieben als neue Ablehnungen aktiv"
            )
            print("NovelForge legacy canon repair: PASS | \(changed) Projekt(e) repariert")
        } catch {
            print("REPAIR_FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
