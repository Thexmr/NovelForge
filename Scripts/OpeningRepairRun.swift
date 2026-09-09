import Foundation
import SwiftData

/// Repariert den ersten Kapitelanfang eines isolierten Test-Stores mit exakt dem
/// On-Demand-Ablauf der App. Zugangsdaten werden niemals ausgegeben.
@main
@MainActor
enum OpeningRepairRun {
    static func main() async {
        let environment = ProcessInfo.processInfo.environment
        guard let storePath = environment["NF_OPENING_STORE"], !storePath.isEmpty else {
            print("OPENING_REPAIR_FAIL: NF_OPENING_STORE fehlt")
            exit(2)
        }
        // Neu kompilierte, unsignierte Testlaeufer haben eine andere Keychain-Identitaet
        // als die installierte App. Ein nur fuer diesen Prozess uebergebener Schluessel
        // verhindert deshalb macOS-Freigabedialoge, ohne ihn auszugeben oder einzubauen.
        if let apiKey = environment["NF_OLLAMA_KEY"], !apiKey.isEmpty {
            UserDefaults.standard.setVolatileDomain([
                "apikey_store_\(AIProvider.ollamaCloud.rawValue)": Data(apiKey.utf8).base64EncodedString()
            ], forName: UserDefaults.argumentDomain)
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
            let projects = try context.fetch(FetchDescriptor<Project>())
            let requestedTitle = environment["NF_OPENING_TITLE"]
            guard let project = projects.first(where: {
                requestedTitle == nil || $0.title == requestedTitle
            }) else {
                print("OPENING_REPAIR_FAIL: Testbuch fehlt")
                exit(3)
            }

            project.preferredProviderRaw = AIProvider.ollamaCloud.rawValue
            project.preferredModel = OllamaCloudModelCatalog.recommendedWritingModel
            try context.save()

            let orchestrator = PipelineOrchestrator.shared
            orchestrator.configure(with: context)
            let result = await orchestrator.optimizeOpening(project: project)
            print("OPENING_REPAIR_RESULT: \(result)")

            guard let chapter = (project.chapters ?? [])
                .sorted(by: { $0.chapterNumber < $1.chapterNumber }).first,
                  let text = chapter.bestText, !text.isEmpty else {
                print("OPENING_REPAIR_FAIL: Kapiteltext fehlt nach Reparatur")
                exit(4)
            }
            let names = (project.storyBible?.characters ?? []).map(\.name)
            let protagonists = (project.storyBible?.characters ?? []).filter {
                $0.role.localizedCaseInsensitiveContains("protagon")
                    || $0.role.localizedCaseInsensitiveContains("hauptfigur")
            }.map(\.name)
            let issues = AutonomousContentQuality.finalOpeningIssues(
                in: text,
                protagonistNames: protagonists.isEmpty ? Array(names.prefix(1)) : protagonists
            )
            let unexpected = CharacterCanonAudit.unexpectedActingCharacterParts(
                in: text, allowedNames: names
            )
            print("OPENING_REPAIR_WORDS: \(text.wordCount)")
            print("OPENING_REPAIR_RULE_ISSUES: \(issues.isEmpty ? "PASS" : issues.joined(separator: " | "))")
            print("OPENING_REPAIR_NAMES: \(unexpected.isEmpty ? "PASS" : unexpected.joined(separator: ", "))")
            print("OPENING_REPAIR_PREVIEW:")
            print(String(text.prefix(1_800)))
            let pending = (project.qualityReports ?? []).filter {
                $0.checkType == LocalEditorialAssistant.openingReviewType && !$0.autoFixed
            }
            for report in pending {
                print("OPENING_REPAIR_PENDING: \(report.recommendation)")
            }
            exit(result.localizedCaseInsensitiveContains("Fehler") || !pending.isEmpty
                 || !issues.isEmpty || !unexpected.isEmpty ? 1 : 0)
        } catch {
            print("OPENING_REPAIR_FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
