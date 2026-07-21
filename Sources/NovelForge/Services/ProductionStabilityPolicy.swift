import Foundation

enum ProductionStabilityPolicy {
    static let maxRetryDelay: TimeInterval = 300

    static func shouldHaltUnlimitedProduction(after error: Error,
                                               consecutiveFailures: Int) -> Bool {
        guard let aiError = error as? AIError else {
            return false
        }

        switch aiError {
        case .apiKeyInvalid, .modelUnavailable, .quotaExceeded,
             .baseURLMissing, .contextTooLong, .fileTooLarge:
            return true
        case .providerUnavailable, .networkError,
             .rateLimitExceeded, .ollamaNotRunning, .systemError, .unknown:
            return false
        }
    }

    static func retryDelay(forConsecutiveFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        let uncapped = 5 * pow(3.0, Double(failures - 1))
        return min(maxRetryDelay, uncapped)
    }

    static func isRetryableProviderError(_ error: AIError) -> Bool {
        switch error {
        case .rateLimitExceeded, .networkError, .providerUnavailable, .ollamaNotRunning:
            return true
        case .apiKeyInvalid, .modelUnavailable, .quotaExceeded, .fileTooLarge,
             .contextTooLong, .baseURLMissing, .systemError, .unknown:
            return false
        }
    }

    /// Ein temporärer Providerfehler darf ein bereits weit geschriebenes Buch
    /// nicht verwaisen lassen. Nur eindeutig vorübergehende Fehler setzen genau
    /// dieses Projekt fort; falsche Keys, Quota und Inhalts-/Konfigurationsfehler
    /// brauchen dagegen eine Nutzeraktion oder einen anderen Ablauf.
    static func shouldResumeInterruptedBook(after error: Error) -> Bool {
        guard let aiError = error as? AIError else { return false }
        return isRetryableProviderError(aiError)
    }

    static func providerRetryDelay(attempt: Int, jitter: Double = 1.0) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let boundedJitter = min(max(jitter, 0.75), 1.25)
        let exponential = 2.0 * pow(2.0, Double(attempt - 1))
        return min(60, exponential * boundedJitter)
    }

    static func formatRetryDelay(_ delay: TimeInterval) -> String {
        let seconds = max(0, Int(delay.rounded()))
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        let rest = seconds % 60
        if rest == 0 { return "\(minutes) min" }
        return "\(minutes) min \(rest) s"
    }
}
