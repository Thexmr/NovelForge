import Foundation
import SwiftData

@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var chapterNumber: Int
    var title: String
    var goal: String
    var conflict: String
    var perspectiveCharacter: String?
    var targetWordCount: Int
    var actualWordCount: Int
    var status: ChapterStatus
    var draftText: String?
    var revisedText: String?
    var finalText: String?
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(inverse: \Project.chapters) var project: Project?
    @Relationship(deleteRule: .cascade) var scenes: [StoryScene]?
    
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
    
    var computedWordCount: Int {
        return finalText?.wordCount ?? revisedText?.wordCount ?? draftText?.wordCount ?? 0
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

@Model
final class StoryScene {
    @Attribute(.unique) var id: UUID
    var sceneNumber: Int
    var perspective: String
    var location: String
    var time: String
    var involvedCharacters: String
    var goal: String
    var obstacle: String
    var emotionalChange: String
    var newInformation: String
    var cliffhanger: String
    var targetWordCount: Int
    var text: String?
    var summary: String?
    var status: SceneStatus
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(inverse: \Chapter.scenes) var chapter: Chapter?
    
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