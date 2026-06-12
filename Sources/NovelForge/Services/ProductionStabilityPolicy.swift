import Foundation

enum ProductionStabilityPolicy {
    static let maxConsecutiveBookFailures = 3
    static let maxRetryDelay: TimeInterval = 300

    static func shouldHaltUnlimitedProduction(after error: Error,
                                               consecutiveFailures: Int) -> Bool {
        if consecutiveFailures >= maxConsecutiveBookFailures {
            return true
        }

        guard let aiError = error as? AIError else {
            return false
        }

        switch aiError {
        case .apiKeyInvalid, .quotaExceeded, .baseURLMissing, .contextTooLong, .fileTooLarge:
            return true
        case .costLimitReached, .providerUnavailable, .modelUnavailable, .networkError,
             .rateLimitExceeded, .ollamaNotRunning, .systemError, .unknown:
            // costLimitReached betrifft nur das Budget des einzelnen Buchs –
            // das nächste Buch startet mit frischem Budget.
            return false
        }
    }

    static func retryDelay(forConsecutiveFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        let uncapped = 5 * pow(3.0, Double(failures - 1))
        return min(maxRetryDelay, uncapped)
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
