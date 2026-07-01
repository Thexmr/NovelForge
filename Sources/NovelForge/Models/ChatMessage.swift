import Foundation
import SwiftData

/// Eine Nachricht im Lektor-Chat zu einem Buch. Über die Projekt-UUID verknüpft,
/// damit das Project-Schema unangetastet bleibt.
@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var projectID: UUID
    var roleRaw: String   // "user" | "assistant"
    var text: String
    var createdAt: Date

    init(projectID: UUID, role: ChatRole, text: String) {
        self.id = UUID()
        self.projectID = projectID
        self.roleRaw = role.rawValue
        self.text = text
        self.createdAt = Date()
    }

    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .assistant }

    /// Löscht alle Chat-Nachrichten eines Projekts. ChatMessage ist über projectID
    /// lose verknüpft (keine SwiftData-Relation), daher gibt es kein automatisches
    /// Cascade-Delete – beim Projekt-Löschen aufrufen, damit keine verwaisten
    /// Nachrichten zurückbleiben.
    static func deleteMessages(forProjectID id: UUID, in context: ModelContext) {
        // Gezielt nur die Nachrichten DIESES Projekts laden (indiziertes Prädikat statt
        // Gesamt-Tabellen-Scan) – skaliert auch bei vielen Büchern/Chats.
        let predicate = #Predicate<ChatMessage> { $0.projectID == id }
        if let matches = try? context.fetch(FetchDescriptor<ChatMessage>(predicate: predicate)) {
            for message in matches {
                context.delete(message)
            }
        }
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
}
