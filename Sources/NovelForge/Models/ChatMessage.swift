import Foundation
import Observation
import SwiftData

/// Eine Nachricht im Lektor-Chat zu einem Buch. Über die Projekt-UUID verknüpft,
/// damit das Project-Schema unangetastet bleibt.
final class ChatMessage: NovelForgePersistentModel {
    private var _$backingData: any BackingData<ChatMessage> = ChatMessage.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<ChatMessage> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \ChatMessage.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "projectID", keypath: \ChatMessage.projectID),
            Schema.PropertyMetadata(name: "roleRaw", keypath: \ChatMessage.roleRaw),
            Schema.PropertyMetadata(name: "text", keypath: \ChatMessage.text),
            Schema.PropertyMetadata(name: "createdAt", keypath: \ChatMessage.createdAt),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var projectID: UUID = UUID()
    @PersistedValue var roleRaw: String = ""   // "user" | "assistant"
    @PersistedValue var text: String = ""
    @PersistedValue var createdAt: Date = .distantPast

    init(projectID: UUID, role: ChatRole, text: String) {
        self.id = UUID()
        self.projectID = projectID
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = Date()
    }

    required init(backingData: any BackingData<ChatMessage>) {
        self._$backingData = backingData
    }

    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .assistant }

    /// Löscht alle Chat-Nachrichten eines Projekts. ChatMessage ist über projectID
    /// lose verknüpft (keine SwiftData-Relation), daher gibt es kein automatisches
    /// Cascade-Delete – beim Projekt-Löschen aufrufen, damit keine verwaisten
    /// Nachrichten zurückbleiben.
    static func deleteMessages(forProjectID id: UUID, in context: ModelContext) {
        // FoundationMacros gehört nicht zu Apples Command Line Tools. Der explizite
        // UUID-Filter hält diesen Pfad auch in Xcode-freien Builds vollständig nutzbar.
        if let messages = try? context.fetch(FetchDescriptor<ChatMessage>()) {
            for message in messages where message.projectID == id {
                context.delete(message)
            }
        }
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
}
