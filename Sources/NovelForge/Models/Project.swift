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
    var targetPageCount: Int
    var targetWordCount: Int
    var outputFormats: [String]
    var status: ProjectStatus
    var createdAt: Date
    var updatedAt: Date
    
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