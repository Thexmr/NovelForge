import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var authorName: String
    var language: String
    var genre: String
    var subgenre: String?
    var styleProfile: String
    /// Vom Autor gewählte/ gewünschte Tropes (kommagetrennt) – die Zielgruppe kauft nach Trope.
    var tropes: String = ""
    var targetPageCount: Int
    var targetWordCount: Int
    var outputFormats: [String]
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date

    // Provider-Einstellungen des Projekts (für autonome Produktion & Fortsetzen)
    var preferredProviderRaw: String = "Ollama Cloud"
    var preferredModel: String = ""
    var costLimitUSD: Double = 0

    // Print-Format für den KDP-konformen PDF-Export
    var trimSizeRaw: String = "6x9"

    // KDP-/Auto-Produktion
    var imprint: String = ""
    var authorBio: String = ""
    var memorySignature: String = ""
    var autoProductionRunID: String = ""

    @Relationship(deleteRule: .cascade) var bookProfile: BookProfile?
    @Relationship(deleteRule: .cascade) var chapters: [Chapter]?
    @Relationship(deleteRule: .cascade) var storyBible: StoryBible?
    @Relationship(deleteRule: .cascade) var pipelineJobs: [PipelineJob]?
    @Relationship(deleteRule: .cascade) var qualityReports: [QualityReport]?
    
    init(title: String, authorName: String, language: String, genre: String, 
         styleProfile: String, targetPageCount: Int, outputFormats: [String]) {
        self.id = UUID()
        self.title = title
        self.authorName = authorName
        self.language = language
        self.genre = genre
        self.styleProfile = styleProfile
        self.targetPageCount = targetPageCount
        self.targetWordCount = targetPageCount * 250
        self.outputFormats = outputFormats
        self.status = .created
        self.createdAt = Date()
        self.updatedAt = Date()
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
    case failed
    case paused
}

@Model
final class BookProfile {
    @Attribute(.unique) var id: UUID
    var premise: String
    var theme: String
    var targetAudience: String
    var tonality: String
    var narrativePerspective: String
    var tense: String
    var readerBenefit: String
    var genreRules: String
    var logline: String?
    var synopsis: String?

    // Amazon-KDP-Metadaten (werden in der Phase „KDP-Formatierung" generiert)
    var kdpDescription: String = ""
    var kdpKeywords: String = ""
    var kdpCategories: String = ""
    /// Viraler, klickstarker Verkaufstitel für Amazon KDP (kann vom literarischen Buchtitel abweichen).
    var kdpTitle: String = ""
    /// Keyword-getriebener KDP-Untertitel (Untertitel-Feld bei Amazon KDP).
    var kdpSubtitle: String = ""
    /// Fertige, kopierbare Bildgenerierungs-Prompts (ChatGPT/DALL·E) für das Buchcover.
    var coverPrompts: String = ""
    
    @Relationship(inverse: \Project.bookProfile) var project: Project?
    
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
    }
}
