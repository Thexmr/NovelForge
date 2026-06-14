import SwiftUI
import SwiftData
import Foundation

@main
struct NovelForgeApp: App {
    @AppStorage("colorScheme") private var colorSchemeSetting = "dark"
    @AppStorage("accentColor") private var accentSetting = "teal"

    init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "novelforge.liquidGlassAppearanceMigrated") {
            defaults.set("dark", forKey: "colorScheme")
            defaults.set("teal", forKey: "accentColor")
            defaults.set(true, forKey: "novelforge.liquidGlassAppearanceMigrated")
        }
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
            QualityReport.self,
            ChatMessage.self
        ])
        .windowStyle(.hiddenTitleBar)
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
