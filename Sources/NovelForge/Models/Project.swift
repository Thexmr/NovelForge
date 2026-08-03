import Foundation
import Observation
import SwiftData

final class Project: NovelForgePersistentModel {
    private var _$backingData: any BackingData<Project> = Project.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<Project> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \Project.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "title", keypath: \Project.title),
            Schema.PropertyMetadata(name: "authorName", keypath: \Project.authorName),
            Schema.PropertyMetadata(name: "language", keypath: \Project.language),
            Schema.PropertyMetadata(name: "genre", keypath: \Project.genre),
            Schema.PropertyMetadata(name: "subgenre", keypath: \Project.subgenre),
            Schema.PropertyMetadata(name: "styleProfile", keypath: \Project.styleProfile),
            Schema.PropertyMetadata(name: "tropes", keypath: \Project.tropes, defaultValue: ""),
            Schema.PropertyMetadata(name: "spiceLevel", keypath: \Project.spiceLevel, defaultValue: 0),
            Schema.PropertyMetadata(name: "seriesName", keypath: \Project.seriesName, defaultValue: ""),
            Schema.PropertyMetadata(name: "seriesNumber", keypath: \Project.seriesNumber, defaultValue: 0),
            Schema.PropertyMetadata(name: "sequelContext", keypath: \Project.sequelContext, defaultValue: ""),
            Schema.PropertyMetadata(name: "styleSignature", keypath: \Project.styleSignature, defaultValue: ""),
            Schema.PropertyMetadata(name: "targetPageCount", keypath: \Project.targetPageCount),
            Schema.PropertyMetadata(name: "targetWordCount", keypath: \Project.targetWordCount),
            Schema.PropertyMetadata(name: "outputFormats", keypath: \Project.outputFormats),
            Schema.PropertyMetadata(name: "status", keypath: \Project.status),
            Schema.PropertyMetadata(name: "createdAt", keypath: \Project.createdAt),
            Schema.PropertyMetadata(name: "updatedAt", keypath: \Project.updatedAt),
            Schema.PropertyMetadata(name: "preferredProviderRaw", keypath: \Project.preferredProviderRaw,
                                    defaultValue: "Ollama Cloud"),
            Schema.PropertyMetadata(name: "preferredModel", keypath: \Project.preferredModel, defaultValue: ""),
            Schema.PropertyMetadata(name: "costLimitUSD", keypath: \Project.costLimitUSD, defaultValue: 0.0),
            Schema.PropertyMetadata(name: "trimSizeRaw", keypath: \Project.trimSizeRaw, defaultValue: "6x9"),
            Schema.PropertyMetadata(name: "imprint", keypath: \Project.imprint, defaultValue: ""),
            Schema.PropertyMetadata(name: "authorBio", keypath: \Project.authorBio, defaultValue: ""),
            Schema.PropertyMetadata(name: "memorySignature", keypath: \Project.memorySignature, defaultValue: ""),
            Schema.PropertyMetadata(name: "autoProductionRunID", keypath: \Project.autoProductionRunID,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "bookProfile", keypath: \Project.bookProfile,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
            Schema.PropertyMetadata(name: "chapters", keypath: \Project.chapters,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
            Schema.PropertyMetadata(name: "storyBible", keypath: \Project.storyBible,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
            Schema.PropertyMetadata(name: "pipelineJobs", keypath: \Project.pipelineJobs,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
            Schema.PropertyMetadata(name: "qualityReports", keypath: \Project.qualityReports,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var title: String = ""
    @PersistedValue var authorName: String = ""
    @PersistedValue var language: String = ""
    @PersistedValue var genre: String = ""
    @PersistedValue var subgenre: String? = nil
    @PersistedValue var styleProfile: String = ""
    /// Vom Autor gewählte/ gewünschte Tropes (kommagetrennt) – die Zielgruppe kauft nach Trope.
    @PersistedValue var tropes: String = ""
    /// Sinnlichkeitsgrad 1–5 (0 = nicht angegeben) – branchenübliche Einstufung der
    /// erotischen Intensität; steuert die Ausführlichkeit intimer Szenen und fließt in
    /// KDP-Verkaufstext/Keywords/Kategorien ein.
    @PersistedValue var spiceLevel: Int = 0
    /// Serien-Metadaten (Read-Through-Hebel): Reihenname + Bandnummer.
    @PersistedValue var seriesName: String = ""
    @PersistedValue var seriesNumber: Int = 0
    /// Fortsetzungs-Kontext: wenn gesetzt, ist dies ein FOLGEBAND, der die Geschichte
    /// des Vorbands fortsetzt (Figuren/Welt erben, Handlung weiterführen). Leer =
    /// eigenständiges Buch (das sich bewusst vom Vorgänger unterscheidet).
    @PersistedValue var sequelContext: String = ""
    /// Pro Buch einzigartige „Stil-DNA" (Perspektive, Struktur, Stimme …). Wird einmal
    /// beim Anlegen gewürfelt und über den ganzen Produktionslauf konstant gehalten –
    /// verhindert die Template-Signatur, die Amazon KDP als „Programmatic Content" erkennt.
    @PersistedValue var styleSignature: String = ""
    @PersistedValue var targetPageCount: Int = 0
    @PersistedValue var targetWordCount: Int = 0
    @PersistedValue var outputFormats: [String] = []
    @PersistedValue var status: ProjectStatus = .created
    @PersistedValue var createdAt: Date = .distantPast
    @PersistedValue var updatedAt: Date = .distantPast

    // Provider-Einstellungen des Projekts (für autonome Produktion & Fortsetzen)
    @PersistedValue var preferredProviderRaw: String = "Ollama Cloud"
    @PersistedValue var preferredModel: String = ""
    @PersistedValue var costLimitUSD: Double = 0

    // Print-Format für den KDP-konformen PDF-Export
    @PersistedValue var trimSizeRaw: String = "6x9"

    // KDP-/Auto-Produktion
    @PersistedValue var imprint: String = ""
    @PersistedValue var authorBio: String = ""
    @PersistedValue var memorySignature: String = ""
    @PersistedValue var autoProductionRunID: String = ""

    @PersistedToOne var bookProfile: BookProfile? = nil
    @PersistedToMany var chapters: [Chapter]? = nil
    @PersistedToOne var storyBible: StoryBible? = nil
    @PersistedToMany var pipelineJobs: [PipelineJob]? = nil
    @PersistedToMany var qualityReports: [QualityReport]? = nil
    
    init(title: String, authorName: String, language: String, genre: String, 
         styleProfile: String, targetPageCount: Int, outputFormats: [String]) {
        self.id = UUID()
        self.title = title
        self.authorName = authorName
        self.language = language
        self.genre = genre
        self.styleProfile = styleProfile
        self.tropes = ""
        self.spiceLevel = 0
        self.seriesName = ""
        self.seriesNumber = 0
        self.sequelContext = ""
        self.styleSignature = ""
        self.targetPageCount = targetPageCount
        self.targetWordCount = targetPageCount * 250
        self.outputFormats = outputFormats
        self.status = .created
        self.createdAt = Date()
        self.updatedAt = Date()
        self.preferredProviderRaw = "Ollama Cloud"
        self.preferredModel = ""
        self.costLimitUSD = 0
        self.trimSizeRaw = "6x9"
        self.imprint = ""
        self.authorBio = ""
        self.memorySignature = ""
        self.autoProductionRunID = ""
    }

    required init(backingData: any BackingData<Project>) {
        self._$backingData = backingData
    }
}

enum ProjectStatus: String, Codable {
    case created
    case conceptDevelopment
    case structurePlanning
    case chapterPlanning
    case scenePlanning
    case drafting
    case chapterRevision
    case manuscriptRevision
    case proofreading
    case copyrightCheck
    case kdpFormatting
    case export
    case completed
    case needsReview
    case failed
    case paused
}

final class BookProfile: NovelForgePersistentModel {
    private var _$backingData: any BackingData<BookProfile> = BookProfile.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<BookProfile> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \BookProfile.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "premise", keypath: \BookProfile.premise),
            Schema.PropertyMetadata(name: "theme", keypath: \BookProfile.theme),
            Schema.PropertyMetadata(name: "targetAudience", keypath: \BookProfile.targetAudience),
            Schema.PropertyMetadata(name: "tonality", keypath: \BookProfile.tonality),
            Schema.PropertyMetadata(name: "narrativePerspective", keypath: \BookProfile.narrativePerspective),
            Schema.PropertyMetadata(name: "tense", keypath: \BookProfile.tense),
            Schema.PropertyMetadata(name: "readerBenefit", keypath: \BookProfile.readerBenefit),
            Schema.PropertyMetadata(name: "genreRules", keypath: \BookProfile.genreRules),
            Schema.PropertyMetadata(name: "logline", keypath: \BookProfile.logline),
            Schema.PropertyMetadata(name: "synopsis", keypath: \BookProfile.synopsis),
            Schema.PropertyMetadata(name: "kdpDescription", keypath: \BookProfile.kdpDescription,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "kdpKeywords", keypath: \BookProfile.kdpKeywords,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "kdpCategories", keypath: \BookProfile.kdpCategories,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "kdpTitle", keypath: \BookProfile.kdpTitle, defaultValue: ""),
            Schema.PropertyMetadata(name: "kdpSubtitle", keypath: \BookProfile.kdpSubtitle, defaultValue: ""),
            Schema.PropertyMetadata(name: "coverPrompts", keypath: \BookProfile.coverPrompts,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "researchQuery", keypath: \BookProfile.researchQuery,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "researchNotes", keypath: \BookProfile.researchNotes,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "sourceManifest", keypath: \BookProfile.sourceManifest,
                                    defaultValue: ""),
            Schema.PropertyMetadata(name: "project", keypath: \BookProfile.project,
                                    metadata: Schema.Relationship(inverse: \Project.bookProfile)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var premise: String = ""
    @PersistedValue var theme: String = ""
    @PersistedValue var targetAudience: String = ""
    @PersistedValue var tonality: String = ""
    @PersistedValue var narrativePerspective: String = ""
    @PersistedValue var tense: String = ""
    @PersistedValue var readerBenefit: String = ""
    @PersistedValue var genreRules: String = ""
    @PersistedValue var logline: String? = nil
    @PersistedValue var synopsis: String? = nil

    // Amazon-KDP-Metadaten (werden in der Phase „KDP-Formatierung" generiert)
    @PersistedValue var kdpDescription: String = ""
    @PersistedValue var kdpKeywords: String = ""
    @PersistedValue var kdpCategories: String = ""
    /// Viraler, klickstarker Verkaufstitel für Amazon KDP (kann vom literarischen Buchtitel abweichen).
    @PersistedValue var kdpTitle: String = ""
    /// Keyword-getriebener KDP-Untertitel (Untertitel-Feld bei Amazon KDP).
    @PersistedValue var kdpSubtitle: String = ""
    /// Fertige, kopierbare Bildgenerierungs-Prompts (ChatGPT/DALL·E) für das Buchcover.
    @PersistedValue var coverPrompts: String = ""
    /// Automatisch recherchierte, nachvollziehbare Quellenbasis für Sachbücher.
    @PersistedValue var researchQuery: String = ""
    @PersistedValue var researchNotes: String = ""
    /// JSON-kodiertes `ResearchBundle`; URLs und Quellentypen bleiben strukturiert prüfbar.
    @PersistedValue var sourceManifest: String = ""
    
    @PersistedToOne var project: Project? = nil
    
    init(premise: String, theme: String, targetAudience: String, tonality: String,
         narrativePerspective: String, tense: String) {
        self.id = UUID()
        self.premise = premise
        self.theme = theme
        self.targetAudience = targetAudience
        self.tonality = tonality
        self.narrativePerspective = narrativePerspective
        self.tense = tense
        self.readerBenefit = ""
        self.genreRules = ""
        self.kdpDescription = ""
        self.kdpKeywords = ""
        self.kdpCategories = ""
        self.kdpTitle = ""
        self.kdpSubtitle = ""
        self.coverPrompts = ""
        self.researchQuery = ""
        self.researchNotes = ""
        self.sourceManifest = ""
    }

    required init(backingData: any BackingData<BookProfile>) {
        self._$backingData = backingData
    }
}
