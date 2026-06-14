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
}

enum ChatRole: String, Codable {
    case user
    case assistant
}
