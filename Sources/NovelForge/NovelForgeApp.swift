import SwiftUI
import SwiftData

@main
struct NovelForgeApp: App {
    @AppStorage("colorScheme") private var colorSchemeSetting = "dark"
    @AppStorage("accentColor") private var accentSetting = "teal"

    init() {
        _ = ProviderSettingsStore.shared
    }

    var body: some Scene {
        WindowGroup("NovelForge") {
            ContentView()
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(preferredScheme)
                .tint(accentColor)
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
        .defaultSize(width: 1280, height: 840)
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemeSetting {
        case "system": return nil
        case "light": return .light
        case "dark": return .dark
        default: return .dark
        }
    }

    private var accentColor: Color {
        switch accentSetting {
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .blue
        }
    }
}
