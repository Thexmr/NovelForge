import Foundation

enum ProductionIncidentStore {
    static let messageKey = "novelforge.production.lastIncident"
    static let dateKey = "novelforge.production.lastIncidentDate"

    static func record(_ message: String) {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        UserDefaults.standard.set(cleaned, forKey: messageKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: messageKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}
