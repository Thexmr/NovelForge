import Foundation
import Observation
import SwiftData

final class Chapter: NovelForgePersistentModel {
    private var _$backingData: any BackingData<Chapter> = Chapter.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<Chapter> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \Chapter.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "chapterNumber", keypath: \Chapter.chapterNumber),
            Schema.PropertyMetadata(name: "title", keypath: \Chapter.title),
            Schema.PropertyMetadata(name: "goal", keypath: \Chapter.goal),
            Schema.PropertyMetadata(name: "conflict", keypath: \Chapter.conflict),
            Schema.PropertyMetadata(name: "perspectiveCharacter", keypath: \Chapter.perspectiveCharacter),
            Schema.PropertyMetadata(name: "targetWordCount", keypath: \Chapter.targetWordCount),
            Schema.PropertyMetadata(name: "actualWordCount", keypath: \Chapter.actualWordCount),
            Schema.PropertyMetadata(name: "status", keypath: \Chapter.status),
            Schema.PropertyMetadata(name: "draftText", keypath: \Chapter.draftText),
            Schema.PropertyMetadata(name: "revisedText", keypath: \Chapter.revisedText),
            Schema.PropertyMetadata(name: "finalText", keypath: \Chapter.finalText),
            Schema.PropertyMetadata(name: "summary", keypath: \Chapter.summary),
            Schema.PropertyMetadata(name: "createdAt", keypath: \Chapter.createdAt),
            Schema.PropertyMetadata(name: "updatedAt", keypath: \Chapter.updatedAt),
            Schema.PropertyMetadata(name: "project", keypath: \Chapter.project,
                                    metadata: Schema.Relationship(inverse: \Project.chapters)),
            Schema.PropertyMetadata(name: "scenes", keypath: \Chapter.scenes,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var chapterNumber: Int = 0
    @PersistedValue var title: String = ""
    @PersistedValue var goal: String = ""
    @PersistedValue var conflict: String = ""
    @PersistedValue var perspectiveCharacter: String? = nil
    @PersistedValue var targetWordCount: Int = 0
    @PersistedValue var actualWordCount: Int = 0
    @PersistedValue var status: ChapterStatus = .planned
    @PersistedValue var draftText: String? = nil
    @PersistedValue var revisedText: String? = nil
    @PersistedValue var finalText: String? = nil
    /// Verdichtete Kapitelzusammenfassung – Baustein des Langstrecken-Gedächtnisses
    /// (verhindert Wiederholungen über hunderte Seiten).
    @PersistedValue var summary: String? = nil
    @PersistedValue var createdAt: Date = .distantPast
    @PersistedValue var updatedAt: Date = .distantPast
    
    @PersistedToOne var project: Project? = nil
    @PersistedToMany var scenes: [StoryScene]? = nil
    
    init(chapterNumber: Int, title: String, goal: String, targetWordCount: Int) {
        self.id = UUID()
        self.chapterNumber = chapterNumber
        self.title = title
        self.goal = goal
        self.conflict = ""
        self.targetWordCount = targetWordCount
        self.actualWordCount = 0
        self.status = .planned
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    required init(backingData: any BackingData<Chapter>) {
        self._$backingData = backingData
    }
    
    /// Bester verfügbarer Rohtext: final > überarbeitet > Rohfassung > zusammengesetzte Szenen.
    /// Schnell genug für UI-Renderpfade; die teure Bereinigung passiert in `bestText`.
    var rawBestText: String? {
        if let text = finalText, !text.isEmpty {
            return text
        }
        if let text = revisedText, !text.isEmpty {
            return text
        }
        if let text = draftText, !text.isEmpty {
            return text
        }
        let joined = (scenes ?? [])
            .sorted { $0.sceneNumber < $1.sceneNumber }
            .compactMap { $0.text }
            .joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
    }

    /// Bereinigter Export-/Lektor-Text.
    /// Entfernt durchgesickerte Prompt-Anweisungen/Labels – dadurch sind auch
    /// bereits geschriebene Bücher beim erneuten Export sauber.
    var bestText: String? {
        let raw = rawBestText
        guard let raw, !raw.isEmpty else { return nil }
        var cleaned = AutonomousContentQuality.cleaningStoredBookText(
            raw,
            bookTitle: project?.title ?? ""
        )
        cleaned = AutonomousContentQuality.strippingLeadingTitleEcho(cleaned, title: title)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Anzeige-/Export-Titel. Echte Kapiteltitel bleiben erhalten; generische
    /// Platzhalter älterer Bücher (z.B. „Aufbruch 7", „Eskalation 12") werden zu
    /// neutralem „Kapitel N", damit im Inhaltsverzeichnis nicht wiederholt
    /// „Aufbruch/Eskalation/Krise/Auflösung" erscheint.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Kapitel \(chapterNumber)" }
        if t.range(of: #"^(aufbruch|eskalation|krise|auflösung|kapitel|teil)\s+\d+$"#,
                   options: [.regularExpression, .caseInsensitive]) != nil {
            return "Kapitel \(chapterNumber)"
        }
        return t
    }

    var computedWordCount: Int {
        return bestText?.wordCount ?? 0
    }

    /// Schneller Zähler für Listen, Dashboards und Fortschrittsanzeigen.
    /// Die teurere `bestText`-Bereinigung wird erst beim tatsächlichen Lesen/Export gebraucht.
    var displayWordCount: Int {
        if actualWordCount > 0 { return actualWordCount }
        return rawBestTextWordCount
    }

    private var rawBestTextWordCount: Int {
        rawBestText?.wordCount ?? 0
    }
}

enum ChapterStatus: String, Codable {
    case planned
    case scenesPlanned
    case drafting
    case draftComplete
    case revising
    case revised
    case proofreading
    case finalized
}

final class StoryScene: NovelForgePersistentModel {
    private var _$backingData: any BackingData<StoryScene> = StoryScene.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<StoryScene> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \StoryScene.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "sceneNumber", keypath: \StoryScene.sceneNumber),
            Schema.PropertyMetadata(name: "perspective", keypath: \StoryScene.perspective),
            Schema.PropertyMetadata(name: "location", keypath: \StoryScene.location),
            Schema.PropertyMetadata(name: "time", keypath: \StoryScene.time),
            Schema.PropertyMetadata(name: "involvedCharacters", keypath: \StoryScene.involvedCharacters),
            Schema.PropertyMetadata(name: "goal", keypath: \StoryScene.goal),
            Schema.PropertyMetadata(name: "obstacle", keypath: \StoryScene.obstacle),
            Schema.PropertyMetadata(name: "emotionalChange", keypath: \StoryScene.emotionalChange),
            Schema.PropertyMetadata(name: "newInformation", keypath: \StoryScene.newInformation),
            Schema.PropertyMetadata(name: "cliffhanger", keypath: \StoryScene.cliffhanger),
            Schema.PropertyMetadata(name: "targetWordCount", keypath: \StoryScene.targetWordCount),
            Schema.PropertyMetadata(name: "text", keypath: \StoryScene.text),
            Schema.PropertyMetadata(name: "summary", keypath: \StoryScene.summary),
            Schema.PropertyMetadata(name: "status", keypath: \StoryScene.status),
            Schema.PropertyMetadata(name: "createdAt", keypath: \StoryScene.createdAt),
            Schema.PropertyMetadata(name: "updatedAt", keypath: \StoryScene.updatedAt),
            Schema.PropertyMetadata(name: "chapter", keypath: \StoryScene.chapter,
                                    metadata: Schema.Relationship(inverse: \Chapter.scenes)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var sceneNumber: Int = 0
    @PersistedValue var perspective: String = ""
    @PersistedValue var location: String = ""
    @PersistedValue var time: String = ""
    @PersistedValue var involvedCharacters: String = ""
    @PersistedValue var goal: String = ""
    @PersistedValue var obstacle: String = ""
    @PersistedValue var emotionalChange: String = ""
    @PersistedValue var newInformation: String = ""
    @PersistedValue var cliffhanger: String = ""
    @PersistedValue var targetWordCount: Int = 0
    @PersistedValue var text: String? = nil
    @PersistedValue var summary: String? = nil
    @PersistedValue var status: SceneStatus = .planned
    @PersistedValue var createdAt: Date = .distantPast
    @PersistedValue var updatedAt: Date = .distantPast
    
    @PersistedToOne var chapter: Chapter? = nil
    
    init(sceneNumber: Int, perspective: String, location: String, goal: String, targetWordCount: Int) {
        self.id = UUID()
        self.sceneNumber = sceneNumber
        self.perspective = perspective
        self.location = location
        self.time = ""
        self.involvedCharacters = ""
        self.goal = goal
        self.obstacle = ""
        self.emotionalChange = ""
        self.newInformation = ""
        self.cliffhanger = ""
        self.targetWordCount = targetWordCount
        self.status = .planned
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    required init(backingData: any BackingData<StoryScene>) {
        self._$backingData = backingData
    }
}

enum SceneStatus: String, Codable {
    case planned
    case writing
    case written
    case checking
    case needsRevision
    case finalized
}

extension String {
    var wordCount: Int {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.count
    }
}
