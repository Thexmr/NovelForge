import SwiftUI
import SwiftData
import AppKit

// Rendert die Hauptansichten offscreen in PNGs (kein Screen-Recording nötig):
// NSHostingView legt die View in einem unsichtbaren Fenster an, wir ziehen
// die Bitmap aus dem Layer. So ist echtes visuelles Feedback für
// Design-Iterationen ohne UI möglich.
// Aufruf: design_snapshot [ausgabeverzeichnis]

@main
@MainActor
struct DesignSnapshot {
    static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static func main() {
        let outDir = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1] : "/tmp/nf_design"
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
        log("Erzeuge Container …")

        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            log("FEHLER: ModelContainer")
            exit(2)
        }

        // Realistische Testdaten: ein laufendes + zwei fertige Projekte,
        // damit das Dashboard nicht nur den Leerzustand zeigt.
        // (recordedWordCount ist berechnet – die Wortzahl steckt in den Kapiteln.)
        let context = ModelContext(container)
        func withChapter(_ project: Project, words: Int) {
            let chapter = Chapter(chapterNumber: 1, title: "Anfang", goal: "",
                                  targetWordCount: words)
            chapter.actualWordCount = words
            chapter.project = project
            project.chapters = [chapter]
            context.insert(chapter)
        }
        let p1 = Project(title: "Wo der Wind die Briefe trägt", authorName: "Lena Sturm",
                         language: "Deutsch", genre: "Liebesroman",
                         styleProfile: "Warm", targetPageCount: 220, outputFormats: ["EPUB"])
        p1.status = .drafting
        withChapter(p1, words: 18_450)
        let p2 = Project(title: "Die Stille zwischen den Seiten", authorName: "Lena Sturm",
                         language: "Deutsch", genre: "Drama",
                         styleProfile: "Ruhig", targetPageCount: 180, outputFormats: ["EPUB", "PDF"])
        p2.status = .completed
        withChapter(p2, words: 45_120)
        let p3 = Project(title: "Nachtzug nach Lissabon", authorName: "Lena Sturm",
                         language: "Deutsch", genre: "Thriller",
                         styleProfile: "Düster", targetPageCount: 320, outputFormats: ["EPUB"])
        p3.status = .completed
        withChapter(p3, words: 78_900)
        for p in [p1, p2, p3] { context.insert(p) }
        try? context.save()

        log("Rendere dashboard …")
        render(DashboardView().frame(width: 1028, height: 840),
               name: "dashboard", to: outDir, container: container)
        log("Rendere wizard …")
        render(NewBookWizardView().frame(width: 760, height: 620),
               name: "wizard", to: outDir, container: container)
        log("Rendere settings …")
        render(SettingsView().frame(width: 980, height: 760),
               name: "settings", to: outDir, container: container)
        log("Rendere production …")
        render(ProductionView().frame(width: 1028, height: 840),
               name: "production", to: outDir, container: container)
        log("Rendere agents …")
        render(AgentMonitorView().frame(width: 1028, height: 840),
               name: "agents", to: outDir, container: container)
        log("Rendere manuscript …")
        render(ManuscriptView().frame(width: 1028, height: 840),
               name: "manuscript", to: outDir, container: container)
        log("Rendere factory …")
        render(FactoryView().frame(width: 1028, height: 840),
               name: "factory", to: outDir, container: container)
        log("Rendere editorchat …")
        render(EditorChatView().frame(width: 1028, height: 840),
               name: "editorchat", to: outDir, container: container)

        log("FERTIG: Snapshots in \(outDir)")
        exit(0)
    }

    static func render<V: View>(_ view: V, name: String, to outDir: String,
                                container: ModelContainer, scheme: ColorScheme = .dark) {
        let hosted = view
            .modelContainer(container)
            .preferredColorScheme(scheme)
            .environment(\.font, .body)
        let hostingView = NSHostingView(rootView: hosted)
        // Fenster exakt in View-Größe: NSHostingView liefert die ideale Größe
        // (das .frame(width:height:) der Views oben), so entstehen keine
        // schwarzen Ränder im Snapshot.
        let fitting = hostingView.fittingSize
        let size = NSSize(width: max(1, fitting.width), height: max(1, fitting.height))
        let frame = NSRect(origin: .zero, size: size)
        hostingView.frame = frame
        log("\(name): Fenster …")
        // Ein unsichtbares Fenster erzwingt Layout + Material-Rendering.
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hostingView
        window.orderBack(nil)
        hostingView.layoutSubtreeIfNeeded()
        log("\(name): Layout läuft …")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.0))
        log("\(name): Bitmap …")

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: frame) else {
            log("FEHLER bitmap \(name)")
            return
        }
        hostingView.cacheDisplay(in: frame, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            log("FEHLER png \(name)")
            return
        }
        let path = "\(outDir)/\(name).png"
        try? png.write(to: URL(fileURLWithPath: path))
        log("OK \(path) (\(Int(frame.width))x\(Int(frame.height)))")
    }
}
