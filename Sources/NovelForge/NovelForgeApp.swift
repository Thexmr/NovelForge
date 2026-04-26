import SwiftUI
import SwiftData

@main
struct NovelForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
        }
    }
}