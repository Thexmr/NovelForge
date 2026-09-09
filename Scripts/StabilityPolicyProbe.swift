import Foundation

@main
enum StabilityPolicyProbe {
    @MainActor
    static func main() {
        precondition(
            ProductionStabilityPolicy.classifyTooManyRequests(
                message: "you have reached your weekly usage limit, upgrade for higher limits"
            ) == .quotaExceeded,
            "Ein ausgeschoepftes Wochenkontingent darf nicht endlos wiederholt werden"
        )
        precondition(
            ProductionStabilityPolicy.classifyTooManyRequests(
                message: "add extra usage in settings"
            ) == .quotaExceeded,
            "Zukauf erfordernde Limits sind Kontingentfehler"
        )
        precondition(
            ProductionStabilityPolicy.classifyTooManyRequests(
                message: "too many requests, retry after 30 seconds"
            ) == .rateLimitExceeded,
            "Eine kurzfristige Drosselung muss wiederholbar bleiben"
        )
        precondition(
            ProductionStabilityPolicy.classifyPaymentRequired(
                message: "this model uses extra usage only and your extra usage balance is empty"
            ) == .modelUnavailable,
            "Ein Extra-Credit-Modell muss auf ein normales Cloud-Modell ausweichen koennen"
        )
        precondition(
            ProductionStabilityPolicy.classifyPaymentRequired(
                message: "payment required: credit balance is empty"
            ) == .quotaExceeded,
            "Ein allgemein leeres Guthaben muss als klare Kontingentsperre pausieren"
        )
        precondition(ProductionStabilityPolicy.shouldPauseForUserAction(after: AIError.quotaExceeded))
        precondition(ProductionStabilityPolicy.shouldPauseForUserAction(after: AIError.apiKeyInvalid))
        precondition(ProductionStabilityPolicy.shouldPauseForUserAction(after: AIError.modelUnavailable))
        precondition(!ProductionStabilityPolicy.shouldPauseForUserAction(after: AIError.networkError),
                     "Netzwerkfehler sollen automatisch wiederholt und nicht dauerhaft pausiert werden")
        let rejectedDraft = AIError.contentQualityRejected(
            "Der Plot enthaelt keine belastbare zentrale Wende."
        )
        precondition(
            ProductionStabilityPolicy.shouldResumeInterruptedBook(
                after: rejectedDraft, consecutiveFailures: 0
            ),
            "Eine erste abgelehnte Modellfassung soll automatisch neu erzeugt werden"
        )
        precondition(
            !ProductionStabilityPolicy.shouldResumeInterruptedBook(
                after: rejectedDraft,
                consecutiveFailures: ProductionStabilityPolicy.maxContentQualityRestarts
            ),
            "Eine dauerhaft abgelehnte Modellfassung darf nie endlos neu gestartet werden"
        )
        precondition(
            ProductionStabilityPolicy.shouldResumeInterruptedBook(
                after: AIError.networkError,
                consecutiveFailures: ProductionStabilityPolicy.maxContentQualityRestarts + 20
            ),
            "Das Qualitaetsbudget darf echte temporaere Providerfehler nicht blockieren"
        )
        precondition(ProductionStabilityPolicy.isDeferredTechnicalDraftIssue(
            "beschädigte Dialogtypografie"
        ), "Reparierbare Dialogzeichen duerfen keinen Neustart des ganzen Buchs ausloesen")
        precondition(!ProductionStabilityPolicy.isDeferredTechnicalDraftIssue(
            "unvollstaendiges Satzende"
        ), "Inhaltlich unvollstaendige Prosa muss eine harte Speichergrenze bleiben")
        let lowStorage = ProductionStorageGuard.blockingError(
            availableBytes: 100 * 1_048_576
        )
        precondition(lowStorage != nil,
                     "Weniger als 1 GB freier Speicher muss die Produktion blockieren")
        precondition(!ProductionStabilityPolicy.shouldPauseForUserAction(after: lowStorage!),
                     "Freier Speicher entsteht ohne Nutzeraktion – die Produktion wartet ihn ab")
        precondition(!ProductionStabilityPolicy.shouldHaltUnlimitedProduction(
            after: lowStorage!, consecutiveFailures: 1
        ), "Speichermangel darf die Dauerproduktion nicht mehr beenden")
        precondition(!ProductionStabilityPolicy.shouldHaltUnlimitedProduction(
            after: lowStorage!, consecutiveFailures: 30
        ), "Auch wiederholter Speichermangel bleibt eine Wartelage, kein Produktionsende")
        precondition(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: lowStorage!),
                     "Dasselbe Buch muss nach Speichermangel automatisch weiterlaufen")
        precondition(ProductionStorageGuard.isStorageFailure(lowStorage!),
                     "Der Speicherfehler muss als solcher erkennbar bleiben")
        precondition(ProductionStorageGuard.recheckInterval > 0,
                     "Ohne Nachprueffrist wuerde die Wartelage nie enden")
        // Die Selbstheilung muss ein vom Speichermangel gestopptes Buch von selbst
        // wieder aufnehmen – sonst nuetzt das Warten nichts, wenn die App zwischendurch
        // beendet wurde.
        let speicherGrund = "Fehler: Nicht genug freier Speicherplatz (noch etwa 327 MB)."
        precondition(
            ProductionRecoveryPolicy.shouldAutoResume(result: speicherGrund, projectStatus: .paused),
            "Ein wegen Speichermangel pausiertes Buch muss automatisch fortgesetzt werden"
        )
        precondition(
            ProductionRecoveryPolicy.shouldAutoResume(result: speicherGrund, projectStatus: .failed),
            "Auch als fehlgeschlagen markierte Speicher-Stopps sind fortsetzbar"
        )
        precondition(
            !ProductionRecoveryPolicy.shouldAutoResume(
                result: "Pausiert durch Benutzer", projectStatus: .paused
            ),
            "Eine von Hand gedrueckte Pause darf niemals automatisch aufgehoben werden"
        )
        precondition(
            !ProductionRecoveryPolicy.shouldAutoResume(
                result: speicherGrund, projectStatus: .completed
            ),
            "Ein fertiges Buch wird nie wieder angefahren"
        )
        precondition(ProductionStorageGuard.blockingError(
            availableBytes: 2 * 1_073_741_824
        ) == nil, "Ausreichender Speicher darf die Produktion nicht blockieren")
        precondition(
            !ProductionStabilityPolicy.shouldHaltUnlimitedProduction(
                after: rejectedDraft, consecutiveFailures: 1
            ),
            "Eine schlechte Modellantwort darf die Dauerproduktion nicht beenden"
        )
        precondition(
            !ProductionStabilityPolicy.shouldPauseForUserAction(after: rejectedDraft),
            "Eine automatisch neu generierbare Fassung braucht keine Nutzeraktion"
        )
        let foreignPlanNames = ProductionRecoveryPolicy.unexpectedPlanNames(
            planTexts: [
                "Elena Voss sucht Jonas im Korridor.",
                "Agnieszka Baranowski trifft Genowefa Laskowski im Saal."
            ],
            allowedNames: ["Agnieszka Baranowski", "Genowefa Laskowski"]
        )
        precondition(foreignPlanNames.contains("elena"),
                     "Eine Altfigur in einem ungeschriebenen Kapitelplan muss erkannt werden")
        precondition(!foreignPlanNames.contains("agnieszka")
                     && !foreignPlanNames.contains("genowefa"),
                     "Aktuelle Kanonfiguren duerfen nicht als Altlast gelten")
        let now = Date()
        let recentFailures = ProductionRecoveryPolicy.failuresSinceLastProgress(
            failureDates: [
                now.addingTimeInterval(-500), now.addingTimeInterval(-300),
                now.addingTimeInterval(-30)
            ],
            progressDates: [now.addingTimeInterval(-120)]
        )
        precondition(recentFailures == 1,
                     "Alte Fehler vor einer erfolgreich geschriebenen Szene duerfen den Wiederanlauf nicht blockieren")
        precondition(ProductionRecoveryPolicy.failuresSinceLastProgress(
            failureDates: [now.addingTimeInterval(-40), now.addingTimeInterval(-20)],
            progressDates: []
        ) == 2, "Ohne Schreibfortschritt muessen alle aktuellen Fehler zaehlen")
        precondition(PipelineOrchestrator.maxDuplicateSceneRepairAttempts == 1,
                     "Ein semantischer Dopplungsbefund darf keine minutenlange Vierfachreparatur starten")
        precondition(PipelineOrchestrator.maxFullChapterRepairAttempts == 1,
                     "Ein lokaler Endbefund darf nicht mehrfach das ganze Kapitel neu schreiben")
        precondition(
            PipelineOrchestrator.reconciledCompletedSceneCount(
                total: 24,
                writtenFlags: Array(repeating: true, count: 24)
            ) == 24,
            "Eine beim Fortsetzen erneut geschriebene Szene darf den Fortschritt nicht doppelt erhoehen"
        )
        precondition(
            PipelineOrchestrator.reconciledCompletedSceneCount(
                total: 24,
                writtenFlags: Array(repeating: true, count: 26)
            ) == 24,
            "Der sichtbare Szenenzaehler darf niemals groesser als sein Gesamtwert werden"
        )
        precondition(
            PipelineOrchestrator.applyingTargetedRepairPatch(
                source: "Er ging zur Tuer.\n\nDann blieb er stehen.",
                search: "Er ging zur Tuer. Dann blieb er stehen.",
                replacement: "Er erreichte die Tuer und blieb stehen."
            ) == "Er erreichte die Tuer und blieb stehen.",
            "Ein sicherer Absatz-Patch muss unterschiedliche Leerraeume tolerieren"
        )
        precondition(
            PipelineOrchestrator.applyingTargetedRepairPatch(
                source: "Derselbe Satz.\n\nDerselbe Satz.",
                search: "Derselbe Satz.",
                replacement: "Neuer Satz."
            ) == nil,
            "Mehrdeutige Text-Patches duerfen niemals automatisch angewendet werden"
        )
        final class TestOwner {}
        let firstWorker = TestOwner()
        let secondWorker = TestOwner()
        ProductionSleepManager.shared.acquire(for: firstWorker)
        ProductionSleepManager.shared.acquire(for: secondWorker)
        precondition(ProductionSleepManager.shared.isActive,
                     "Aktive Buchproduktion muss den Mac wach halten")
        ProductionSleepManager.shared.release(for: firstWorker)
        precondition(ProductionSleepManager.shared.isActive,
                     "Ein fertiger Parallel-Worker darf den Schlafschutz der anderen nicht loesen")
        ProductionSleepManager.shared.release(for: secondWorker)
        precondition(!ProductionSleepManager.shared.isActive,
                     "Nach dem letzten Worker muss der normale Energiesparmodus wieder gelten")
        print("NovelForge stability policy probe: PASS")
    }
}
