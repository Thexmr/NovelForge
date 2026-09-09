import Foundation

enum ProductionStorageGuard {
    static let minimumFreeBytes: Int64 = 1_073_741_824
    static let messageMarker = "Nicht genug freier Speicherplatz"
    /// Abstand zwischen zwei Speicherprüfungen, solange die Produktion wartet.
    /// Ein voller Datenträger löst sich typischerweise von selbst (Caches, Snapshots,
    /// Downloads), deshalb wird regelmäßig nachgesehen statt aufgegeben.
    static let recheckInterval: TimeInterval = 30

    static func availableBytes(at path: String = NSHomeDirectory()) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path),
              let bytes = attributes[.systemFreeSize] as? NSNumber else { return nil }
        return bytes.int64Value
    }

    static func blockingError(availableBytes: Int64? = availableBytes()) -> AIError? {
        guard let availableBytes, availableBytes < minimumFreeBytes else { return nil }
        let megabytes = max(0, availableBytes / 1_048_576)
        return .systemError(
            "\(messageMarker) (noch etwa \(megabytes) MB). NovelForge pausiert das Buch, "
                + "bevor die Projektdatenbank beschädigt wird. Bitte mindestens 1 GB freigeben."
        )
    }

    static func isStorageFailure(_ error: Error) -> Bool {
        let message = (error as? AIError)?.errorDescription ?? error.localizedDescription
        return isStorageFailureMessage(message)
    }

    static func isStorageFailureMessage(_ message: String) -> Bool {
        let normalized = message.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .current
        ).lowercased()
        return normalized.contains(messageMarker.lowercased())
            || normalized.contains("database or disk is full")
            || normalized.contains("disk is full")
            || normalized.contains("no space left on device")
    }
}

enum ProductionStabilityPolicy {
    static let maxRetryDelay: TimeInterval = 300
    /// Phasen wie Szenen- und Kapitelplanung reparieren intern bereits mehrfach.
    /// Bleibt die Ausgabe danach unbrauchbar, darf der gesamte Buchlauf nur noch
    /// begrenzt neu ansetzen. Sonst wird derselbe persistierte Plan endlos geprüft.
    static let maxContentQualityRestarts = 2

    /// HTTP 429 bedeutet nicht immer eine kurzfristige Drosselung. Provider wie
    /// Ollama verwenden denselben Status auch fuer ausgeschoepfte Wochenkontingente.
    /// Ein solches Limit darf nicht automatisch neu versucht werden, weil es ohne
    /// Aenderung am Konto bis zum Reset garantiert erneut scheitert.
    static func classifyTooManyRequests(message: String?) -> AIError {
        let normalized = message?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased() ?? ""
        let quotaMarkers = [
            "weekly usage limit",
            "monthly usage limit",
            "daily usage limit",
            "usage quota",
            "quota exceeded",
            "insufficient_quota",
            "credits exhausted",
            "credit balance",
            "spending limit",
            "billing limit",
            "upgrade for higher limits",
            "add extra usage",
            "kontingent erschopft",
        ]
        return quotaMarkers.contains(where: normalized.contains)
            ? .quotaExceeded
            : .rateLimitExceeded
    }

    /// Ollama nutzt HTTP 402 sowohl fuer ein allgemein leeres Guthaben als auch fuer
    /// Modelle, die ausschliesslich Extra-Credits verbrauchen. Nur der zweite Fall
    /// ist durch automatisches Ausweichen auf ein normales Cloud-Modell loesbar.
    static func classifyPaymentRequired(message: String?) -> AIError {
        let normalized = message?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased() ?? ""
        let modelOnlyMarkers = [
            "this model uses extra usage only",
            "model requires extra usage",
            "extra-usage-only model",
        ]
        return modelOnlyMarkers.contains(where: normalized.contains)
            ? .modelUnavailable
            : .quotaExceeded
    }

    static func shouldHaltUnlimitedProduction(after error: Error,
                                               consecutiveFailures: Int) -> Bool {
        guard let aiError = error as? AIError else {
            return false
        }

        switch aiError {
        case .apiKeyInvalid, .modelUnavailable, .quotaExceeded,
             .baseURLMissing, .contextTooLong, .fileTooLarge:
            return true
        // Speichermangel beendete die Dauerproduktion frueher endgueltig. Er ist aber
        // ein voruebergehender Zustand des Rechners, den die Pipeline selbst pruefen
        // kann: Sie wartet jetzt darauf, dass wieder Platz frei wird, statt den Lauf
        // abzuwerfen und einen manuellen Neustart zu verlangen.
        case .systemError, .providerUnavailable, .networkError,
             .rateLimitExceeded, .ollamaNotRunning, .contentQualityRejected, .unknown:
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
             .contextTooLong, .baseURLMissing, .contentQualityRejected,
             .systemError, .unknown:
            return false
        }
    }

    static func isContentQualityRejection(_ error: Error) -> Bool {
        guard let aiError = error as? AIError else { return false }
        if case .contentQualityRejected = aiError { return true }
        return false
    }

    /// Objektiv reparierbare Satztechnik wird bis zur Schlusskorrektur sichtbar
    /// zurueckgestellt, statt den gesamten Buchlauf neu zu starten. Inhaltliche
    /// Defekte wie Abbruch, Meta-Text oder Sicherheitsverstoss bleiben hart.
    static func isDeferredTechnicalDraftIssue(_ issue: String) -> Bool {
        issue.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: .current
        ).lowercased().contains("beschadigte dialogtypografie")
    }

    /// Ein temporärer Providerfehler darf ein bereits weit geschriebenes Buch
    /// nicht verwaisen lassen. Auch eine nach den phaseninternen Versuchen abgelehnte
    /// Modellfassung wird neu erzeugt: Sie ist kein Bedienfehler und darf deshalb nie
    /// einen manuellen "Fortsetzen"-Klick verlangen. Gateway-Retries bleiben davon
    /// unberuehrt, damit nicht dieselbe Antwort innerhalb eines Requests wiederholt wird.
    static func shouldResumeInterruptedBook(after error: Error,
                                            consecutiveFailures: Int = 0) -> Bool {
        // Voller Datentraeger: dasselbe, bereits geschriebene Buch wird fortgesetzt.
        // Ein 500-Seiten-Manuskript darf nicht liegen bleiben, weil kurzzeitig weniger
        // als 1 GB frei war.
        if ProductionStorageGuard.isStorageFailure(error) { return true }
        guard let aiError = error as? AIError else { return false }
        if case .contentQualityRejected = aiError {
            return consecutiveFailures < maxContentQualityRestarts
        }
        return isRetryableProviderError(aiError)
    }

    /// Fehler, die ohne eine Aenderung an Konto oder Konfiguration garantiert wieder
    /// auftreten. Das Buch bleibt pausiert und fortsetzbar; automatisches Retry waere
    /// eine Endlosschleife, `failed` wuerde dagegen einen intakten Zwischenstand falsch markieren.
    static func shouldPauseForUserAction(after error: Error) -> Bool {
        guard let aiError = error as? AIError else { return false }
        switch aiError {
        case .quotaExceeded, .apiKeyInvalid, .modelUnavailable, .baseURLMissing:
            return true
        // Speichermangel gehoert bewusst NICHT mehr hierher: Er ist maschinell pruefbar
        // und loest sich ohne Konto- oder Konfigurationsaenderung. Die Produktion wartet
        // ihn ab (siehe `waitForStorageSpace`), statt auf einen Klick zu warten.
        case .systemError, .providerUnavailable, .networkError, .rateLimitExceeded,
             .ollamaNotRunning, .fileTooLarge, .contextTooLong, .contentQualityRejected,
             .unknown:
            return false
        }
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
