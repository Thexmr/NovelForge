import Foundation

/// Hält den Mac nur während aktiver Buchproduktion wach. Der Bildschirm darf
/// weiterhin nach den Systemeinstellungen ausgehen. Manueller Schlaf und Zuklappen
/// können von einer normalen App nicht überstimmt werden.
@MainActor
final class ProductionSleepManager {
    static let shared = ProductionSleepManager()

    private var activity: NSObjectProtocol?
    private var owners = Set<ObjectIdentifier>()

    func acquire(for owner: AnyObject) {
        owners.insert(ObjectIdentifier(owner))
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "NovelForge produziert und exportiert ein Buch"
        )
    }

    func release(for owner: AnyObject) {
        owners.remove(ObjectIdentifier(owner))
        guard owners.isEmpty, let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }

    var isActive: Bool { activity != nil }
}
