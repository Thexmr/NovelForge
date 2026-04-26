import Foundation
import SwiftData

@Model
final class CharacterProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var role: String
    var age: String
    var occupation: String
    var goal: String
    var fear: String
    var weakness: String
    var development: String
    var relationships: String
    var speechPattern: String
    var importantFacts: String
    var createdAt: Date
    
    @Relationship(inverse: \StoryBible.characters) var storyBible: StoryBible?
    
    init(name: String, role: String) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.age = ""
        self.occupation = ""
        self.goal = ""
        self.fear = ""
        self.weakness = ""
        self.development = ""
        self.relationships = ""
        self.speechPattern = ""
        self.importantFacts = ""
        self.createdAt = Date()
    }
}

@Model
final class LocationProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: String
    var locationDescription: String
    var atmosphere: String
    var relevantRules: String
    var connectedCharacters: String
    var relevantChapters: String
    
    @Relationship(inverse: \StoryBible.locations) var storyBible: StoryBible?
    
    init(name: String, type: String, locationDescription: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.locationDescription = locationDescription
        self.atmosphere = ""
        self.relevantRules = ""
        self.connectedCharacters = ""
        self.relevantChapters = ""
    }
}

@Model
final class StoryBible {
    @Attribute(.unique) var id: UUID
    var timeline: String
    var plotPoints: String
    var openQuestions: String
    var resolvedQuestions: String
    var narrativePerspectives: String
    var styleRules: String
    var terms: String
    var updatedAt: Date
    
    @Relationship(inverse: \Project.storyBible) var project: Project?
    @Relationship(deleteRule: .cascade) var characters: [CharacterProfile]?
    @Relationship(deleteRule: .cascade) var locations: [LocationProfile]?
    
    init() {
        self.id = UUID()
        self.timeline = ""
        self.plotPoints = ""
        self.openQuestions = ""
        self.resolvedQuestions = ""
        self.narrativePerspectives = ""
        self.styleRules = ""
        self.terms = ""
        self.updatedAt = Date()
    }
}