import Foundation

/// Trennt einen echten Produktionsabbruch von einem vollständig geschriebenen Buch,
/// dessen Qualitätsprüfung noch offene Punkte enthält.
enum ProductionCompletionPolicy {
    static func shouldRequireReview(chapterTexts: [String],
                                    readinessShortfall: Bool,
                                    retriesExhausted: Bool) -> Bool {
        guard readinessShortfall, retriesExhausted, !chapterTexts.isEmpty else { return false }
        return chapterTexts.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
