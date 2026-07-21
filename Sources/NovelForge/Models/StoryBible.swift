import Foundation
import Observation
import SwiftData

final class CharacterProfile: NovelForgePersistentModel {
    private var _$backingData: any BackingData<CharacterProfile> = CharacterProfile.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<CharacterProfile> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \CharacterProfile.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "name", keypath: \CharacterProfile.name),
            Schema.PropertyMetadata(name: "role", keypath: \CharacterProfile.role),
            Schema.PropertyMetadata(name: "age", keypath: \CharacterProfile.age),
            Schema.PropertyMetadata(name: "occupation", keypath: \CharacterProfile.occupation),
            Schema.PropertyMetadata(name: "goal", keypath: \CharacterProfile.goal),
            Schema.PropertyMetadata(name: "fear", keypath: \CharacterProfile.fear),
            Schema.PropertyMetadata(name: "weakness", keypath: \CharacterProfile.weakness),
            Schema.PropertyMetadata(name: "development", keypath: \CharacterProfile.development),
            Schema.PropertyMetadata(name: "relationships", keypath: \CharacterProfile.relationships),
            Schema.PropertyMetadata(name: "speechPattern", keypath: \CharacterProfile.speechPattern),
            Schema.PropertyMetadata(name: "importantFacts", keypath: \CharacterProfile.importantFacts),
            Schema.PropertyMetadata(name: "createdAt", keypath: \CharacterProfile.createdAt),
            Schema.PropertyMetadata(name: "storyBible", keypath: \CharacterProfile.storyBible,
                                    metadata: Schema.Relationship(inverse: \StoryBible.characters)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var name: String = ""
    @PersistedValue var role: String = ""
    @PersistedValue var age: String = ""
    @PersistedValue var occupation: String = ""
    @PersistedValue var goal: String = ""
    @PersistedValue var fear: String = ""
    @PersistedValue var weakness: String = ""
    @PersistedValue var development: String = ""
    @PersistedValue var relationships: String = ""
    @PersistedValue var speechPattern: String = ""
    @PersistedValue var importantFacts: String = ""
    @PersistedValue var createdAt: Date = .distantPast
    
    @PersistedToOne var storyBible: StoryBible? = nil
    
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

    required init(backingData: any BackingData<CharacterProfile>) {
        self._$backingData = backingData
    }
}

final class LocationProfile: NovelForgePersistentModel {
    private var _$backingData: any BackingData<LocationProfile> = LocationProfile.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<LocationProfile> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \LocationProfile.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "name", keypath: \LocationProfile.name),
            Schema.PropertyMetadata(name: "type", keypath: \LocationProfile.type),
            Schema.PropertyMetadata(name: "locationDescription", keypath: \LocationProfile.locationDescription),
            Schema.PropertyMetadata(name: "atmosphere", keypath: \LocationProfile.atmosphere),
            Schema.PropertyMetadata(name: "relevantRules", keypath: \LocationProfile.relevantRules),
            Schema.PropertyMetadata(name: "connectedCharacters", keypath: \LocationProfile.connectedCharacters),
            Schema.PropertyMetadata(name: "relevantChapters", keypath: \LocationProfile.relevantChapters),
            Schema.PropertyMetadata(name: "storyBible", keypath: \LocationProfile.storyBible,
                                    metadata: Schema.Relationship(inverse: \StoryBible.locations)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var name: String = ""
    @PersistedValue var type: String = ""
    @PersistedValue var locationDescription: String = ""
    @PersistedValue var atmosphere: String = ""
    @PersistedValue var relevantRules: String = ""
    @PersistedValue var connectedCharacters: String = ""
    @PersistedValue var relevantChapters: String = ""
    
    @PersistedToOne var storyBible: StoryBible? = nil
    
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

    required init(backingData: any BackingData<LocationProfile>) {
        self._$backingData = backingData
    }
}

final class StoryBible: NovelForgePersistentModel {
    private var _$backingData: any BackingData<StoryBible> = StoryBible.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<StoryBible> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \StoryBible.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "timeline", keypath: \StoryBible.timeline),
            Schema.PropertyMetadata(name: "plotPoints", keypath: \StoryBible.plotPoints),
            Schema.PropertyMetadata(name: "openQuestions", keypath: \StoryBible.openQuestions),
            Schema.PropertyMetadata(name: "resolvedQuestions", keypath: \StoryBible.resolvedQuestions),
            Schema.PropertyMetadata(name: "narrativePerspectives", keypath: \StoryBible.narrativePerspectives),
            Schema.PropertyMetadata(name: "styleRules", keypath: \StoryBible.styleRules),
            Schema.PropertyMetadata(name: "terms", keypath: \StoryBible.terms),
            Schema.PropertyMetadata(name: "updatedAt", keypath: \StoryBible.updatedAt),
            Schema.PropertyMetadata(name: "project", keypath: \StoryBible.project,
                                    metadata: Schema.Relationship(inverse: \Project.storyBible)),
            Schema.PropertyMetadata(name: "characters", keypath: \StoryBible.characters,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
            Schema.PropertyMetadata(name: "locations", keypath: \StoryBible.locations,
                                    metadata: Schema.Relationship(deleteRule: .cascade)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var timeline: String = ""
    @PersistedValue var plotPoints: String = ""
    @PersistedValue var openQuestions: String = ""
    @PersistedValue var resolvedQuestions: String = ""
    @PersistedValue var narrativePerspectives: String = ""
    @PersistedValue var styleRules: String = ""
    @PersistedValue var terms: String = ""
    @PersistedValue var updatedAt: Date = .distantPast
    
    @PersistedToOne var project: Project? = nil
    @PersistedToMany var characters: [CharacterProfile]? = nil
    @PersistedToMany var locations: [LocationProfile]? = nil
    
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

    required init(backingData: any BackingData<StoryBible>) {
        self._$backingData = backingData
    }
}
