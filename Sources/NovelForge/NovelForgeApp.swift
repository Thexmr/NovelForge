import SwiftUI
import SwiftData

@main
struct NovelForgeApp: App {
    var body: some Scene {
        WindowGroup("NovelForge") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [
            Project.self,
            BookProfile.self,
            StoryBible.self,
            CharacterProfile.self,
            LocationProfile.self,
            Chapter.self,
            StoryScene.self,
            PipelineJob.self,
            QualityReport.self
        ])
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
    }
}