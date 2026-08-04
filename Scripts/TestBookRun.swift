import Foundation
import SwiftData
import SwiftUI

// Headless-Testlauf: erzeugt EIN Testbuch über die echte Produktions-Pipeline
// (identisch zum Wizard-Pfad) und gibt am Ende Status, Wortzahl und die
// Qualitätsbefunde (Golden-Eval, Beta-Leser, Figurenstimme, Emotionsschritt,
// Ton-Angleich …) aus. Konfiguration über Umgebungsvariablen:
//   NF_OLLAMA_KEY (Pflicht)  API-Key für Ollama Cloud
//   NF_TEST_PAGES            Zielseiten (Standard: 30)
//   NF_TEST_STORE            Pfad des SwiftData-Stores (Standard: /tmp/nf-testbook.store)
//   NF_TEST_TIMEOUT          Max. Minuten (Standard: 180)

@main
@MainActor
struct TestBookRun {
    static func main() async {
        let env = ProcessInfo.processInfo.environment
        guard let apiKey = env["NF_OLLAMA_KEY"], !apiKey.isEmpty else {
            print("FEHLER: NF_OLLAMA_KEY nicht gesetzt")
            exit(2)
        }
        let pages = Int(env["NF_TEST_PAGES"] ?? "") ?? 30
        let timeoutMinutes = Double(env["NF_TEST_TIMEOUT"] ?? "") ?? 180
        let storeURL = URL(fileURLWithPath: env["NF_TEST_STORE"] ?? "/tmp/nf-testbook.store")
        let freshStart = env["NF_TEST_FRESH"] == "1"
        if freshStart {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self
        ])
        let modelConfig = ModelConfiguration(schema: schema, url: storeURL)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfig])
        } catch {
            print("FEHLER ModelContainer: \(error.localizedDescription)")
            exit(2)
        }
        let context = ModelContext(container)

        let orchestrator = PipelineOrchestrator.shared
        orchestrator.configure(with: context)

        var config = ProviderConfiguration(provider: .ollamaCloud)
        config.isActive = true
        config.apiKey = apiKey
        config.defaultModel = "kimi-k2.6"
        config.baseURL = AIProvider.ollamaCloud.defaultBaseURL

        // Fortsetzen: Existiert im Store bereits ein Projekt, wird genau dieses
        // weiterproduziert (die Pipeline-Phasen sind idempotent). Nur bei
        // NF_TEST_FRESH=1 oder leerem Store wird ein neues Testbuch angelegt.
        let existing = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let project: Project
        if let resumed = existing.first {
            project = resumed
            print("RESUME vorhandenes Projekt: \(project.title) | Status: \(project.status.rawValue)")
        } else {
            let genre = "Liebesroman"
            let neu = Project(
                title: "Wo der Wind die Briefe trägt",
                authorName: "NovelForge Testlauf",
                language: "Deutsch",
                genre: genre,
                styleProfile: "Warm, bildhaft, modern, nah an den Figuren",
                targetPageCount: pages,
                outputFormats: ["EPUB"]
            )
            neu.tropes = "Second Chance, Kleinstadt, Rückkehr in die Heimat"
            neu.spiceLevel = 1
            let signature = NarrativeSignature.make(
                seed: NarrativeSignature.stableSeed("\(neu.id.uuidString)|\(neu.title)|\(genre)")
            )
            neu.styleSignature = signature.directiveText(
                povOverride: "Personaler Erzähler (Er/Sie)", tenseOverride: "Präteritum"
            )
            let bookProfile = BookProfile(
                premise: "Mara kehrt nach zehn Jahren auf die Nordseeinsel zurück, um den "
                    + "heruntergekommenen Leuchtturm ihres Vaters zu verkaufen – und trifft "
                    + "auf Jonas, ihre Jugendliebe, der den Turm ausgerechnet mit den Briefen "
                    + "sanieren will, die sie ihm damals nie gegeben hat.",
                theme: "Heimat, zweite Chancen, loslassen",
                targetAudience: "Leserinnen 25–55",
                tonality: "warm, hoffnungsvoll",
                narrativePerspective: "Personaler Erzähler (Er/Sie)",
                tense: "Präteritum"
            )
            bookProfile.project = neu
            let storyBible = StoryBible()
            storyBible.project = neu
            neu.bookProfile = bookProfile
            neu.storyBible = storyBible
            context.insert(neu)
            context.insert(bookProfile)
            context.insert(storyBible)
            try? context.save()
            project = neu
            print("START Testbuch: \(neu.title) | \(pages) Seiten | Modell: kimi-k2.6")
        }
        fflush(stdout)
        orchestrator.startPipeline(project: project, providerConfig: config)

        let started = Date()
        var lastLine = ""
        while orchestrator.isRunning {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            let elapsed = Int(Date().timeIntervalSince(started))
            let line = "[\(elapsed / 60)m\(elapsed % 60)s] "
                + "\(orchestrator.currentPhase.rawValue) | "
                + "Kap \(orchestrator.currentChapter)/Sz \(orchestrator.currentScene) | "
                + "\(orchestrator.completedScenes)/\(orchestrator.totalScenes) Szenen | "
                + "\(orchestrator.totalTokensUsed) Tokens | "
                + String(format: "%.3f", orchestrator.estimatedCostUSD) + " USD"
            if line != lastLine {
                print(line)
                fflush(stdout)
                lastLine = line
            }
            if Date().timeIntervalSince(started) > timeoutMinutes * 60 {
                print("TIMEOUT nach \(Int(timeoutMinutes)) Minuten – breche ab (Projekt bleibt fortsetzbar)")
                orchestrator.pausePipeline()
                break
            }
        }

        if let error = orchestrator.lastError {
            print("PIPELINE-FEHLER: \(error)")
        }
        print("STATUS: \(project.status.rawValue) | Wörter: \(project.recordedWordCount)")

        // Qualitätsbefunde nach Typ gruppieren und ausgeben
        let reports = (project.qualityReports ?? []).sorted { $0.createdAt < $1.createdAt }
        var byType: [String: [QualityReport]] = [:]
        for report in reports { byType[report.checkType, default: []].append(report) }
        print("\n===== QUALITÄTSBEFUNDE (\(reports.count) gesamt, \(byType.count) Typen) =====")
        for type in byType.keys.sorted() {
            let items = byType[type] ?? []
            print("\n--- \(type) (\(items.count)) ---")
            for item in items.prefix(8) {
                let fixed = item.autoFixed ? " [behoben]" : ""
                print("  [\(item.severity.rawValue)] \(item.checkedArea): \(item.result)\(fixed)")
                if !item.recommendation.isEmpty {
                    print("      → \(item.recommendation)")
                }
            }
            if items.count > 8 { print("  … +\(items.count - 8) weitere") }
        }
        print("\nENDE TESTLAUF")
        exit(0)
    }
}
