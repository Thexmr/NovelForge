import Foundation

enum ProductionIncidentStore {
    static let messageKey = "novelforge.production.lastIncident"
    static let dateKey = "novelforge.production.lastIncidentDate"

    static func isActionable(_ message: String) -> Bool {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return !normalized.hasPrefix("produktion pausiert")
            && !normalized.hasPrefix("vom nutzer pausiert")
    }

    static func record(_ message: String) {
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isActionable(cleaned) else { clear(); return }
        UserDefaults.standard.set(cleaned, forKey: messageKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: messageKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}
