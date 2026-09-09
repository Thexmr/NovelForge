import Foundation

/// Deterministische Kapitel-Scorecard für den Lektoratsmodus.
///
/// Die Scorecard ersetzt kein menschliches Urteil und keine Blindrevision. Sie macht
/// jedoch die wiederkehrenden, messbaren Qualitätsmerkmale je Kapitel sichtbar, bevor
/// ein Manuskript in eine globale Endabnahme oder einen KDP-Entwurf gelangt. Die Werte
/// sind absichtlich als Diagnose ausgelegt: Ein schwacher Szenenplan, zu wenig
/// konkreter Konflikt oder KI-typische Prosa werden erklärt statt hinter einer einzigen
/// unbrauchbaren Zahl versteckt.
struct ChapterEditorialScorecard: Equatable {
    enum Verdict: String, Equatable {
        case ready = "freigegeben"
        case revise = "überarbeiten"
        case incomplete = "unvollständig"
    }

    let chapterNumber: Int
    let wordCount: Int
    let prose: Double
    let sceneCraft: Double
    let momentum: Double
    let dialogue: Double
    let overall: Double
    let verdict: Verdict
    let findings: [String]

    static let passThreshold = 0.78

    /// Ermittelt die Scorecard aus einem persistierten Kapitel. Die Auswertung speichert
    /// nichts und ist daher für UI, Exportprüfung und Tests identisch verwendbar.
    static func evaluate(chapter: Chapter) -> ChapterEditorialScorecard {
        evaluate(
            chapterNumber: chapter.chapterNumber,
            text: chapter.bestText ?? "",
            goal: chapter.goal,
            conflict: chapter.conflict,
            targetWordCount: chapter.targetWordCount,
            scenes: chapter.scenes ?? []
        )
    }

    /// Reine Kernfunktion ohne SwiftData-Seiteneffekte. Sie ist bewusst öffentlich
    /// innerhalb des Moduls, damit Regressionstests denselben Maßstab verwenden.
    static func evaluate(chapterNumber: Int,
                         text: String,
                         goal: String,
                         conflict: String,
                         targetWordCount: Int,
                         scenes: [StoryScene]) -> ChapterEditorialScorecard {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.wordCount
        guard words >= 120 else {
            return ChapterEditorialScorecard(
                chapterNumber: chapterNumber, wordCount: words,
                prose: 0, sceneCraft: 0, momentum: 0, dialogue: 0, overall: 0,
                verdict: .incomplete,
                findings: ["Kapiteltext ist für eine belastbare Lektoratsbewertung zu kurz."]
            )
        }

        var findings: [String] = []

        // Prosa: dieselben deterministischen Regeln wie die Endabnahme, aber mit
        // abgestufter Diagnose statt eines pauschalen Ja/Nein.
        var prose = 1.0
        let clarity = AutonomousContentQuality.clarityAssessment(trimmed)
        if AutonomousContentQuality.soundsLikeAI(trimmed) {
            prose -= 0.35
            findings.append("Formelhafte oder unnötig vage Prosa schwächt den Lesefluss.")
        }
        if !clarity.isAcceptable {
            prose -= 0.25
            findings.append("Unklare Referenzen, Filterreaktionen oder Vergleichsketten sind zu dicht.")
        }
        let formulaic = AutonomousContentQuality.blockingFormulaicReactionPhrases(
            inChapters: [trimmed]
        )
        if !formulaic.isEmpty {
            prose -= 0.25
            findings.append("Reaktionsformeln häufen sich: " + formulaic.prefix(3).joined(separator: " | ") + ".")
        }
        let antiGlaette = AutonomousContentQuality.antiGlaetteFindings(in: trimmed)
        if !antiGlaette.isEmpty {
            prose -= min(0.25, 0.12 * Double(antiGlaette.count))
            let reasons = Array(Set(antiGlaette.prefix(3).map(\.grund))).sorted().joined(separator: " | ")
            findings.append("Übererklärende oder künstlich gerundete Prosa: " + reasons + ".")
        }
        let teenReadability = AutonomousContentQuality.teenReadabilityIssues(in: trimmed)
        if !teenReadability.isEmpty {
            prose -= min(0.30, 0.15 * Double(teenReadability.count))
            findings.append(contentsOf: teenReadability.prefix(2))
        }
        prose = bounded(prose)

        // Szenenhandwerk: Ein Kapitel braucht Ziel und Konflikt; jede geplante Szene
        // sollte wenigstens ein Hindernis oder eine erkennbare Veränderung tragen.
        let plannedScenes = scenes.filter { ($0.text ?? "").wordCount > 0 }
        var sceneCraft = 0.0
        if goal.wordCount >= 3 { sceneCraft += 0.22 } else {
            findings.append("Das Kapitelziel ist nicht konkret genug formuliert.")
        }
        if conflict.wordCount >= 3 { sceneCraft += 0.22 } else {
            findings.append("Der zentrale Kapitelkonflikt ist nicht klar genug hinterlegt.")
        }
        if plannedScenes.isEmpty {
            findings.append("Es liegen keine ausgeschriebenen Szenen für die Kapitelprüfung vor.")
        } else {
            let withGoal = plannedScenes.filter { $0.goal.wordCount >= 3 }.count
            let withResistance = plannedScenes.filter {
                $0.obstacle.wordCount >= 3 || $0.cliffhanger.wordCount >= 3
            }.count
            let withChange = plannedScenes.filter {
                $0.emotionalChange.wordCount >= 3 || $0.newInformation.wordCount >= 3
            }.count
            let count = Double(plannedScenes.count)
            sceneCraft += 0.20 * Double(withGoal) / count
            sceneCraft += 0.18 * Double(withResistance) / count
            sceneCraft += 0.18 * Double(withChange) / count
            if withResistance < plannedScenes.count {
                findings.append("Mindestens eine Szene hat kein klar geplantes Hindernis oder keine Wendung.")
            }
            if withChange < plannedScenes.count {
                findings.append("Mindestens eine Szene dokumentiert keine erkennbare neue Information oder Veränderung.")
            }
        }
        if targetWordCount > 0 {
            let deviation = abs(Double(words - targetWordCount)) / Double(targetWordCount)
            if deviation <= 0.25 {
                sceneCraft += 0.10
            } else {
                findings.append("Der Kapitelumfang weicht deutlich vom geplanten Ziel ab.")
            }
        } else {
            sceneCraft += 0.10
        }
        sceneCraft = bounded(sceneCraft)

        // Sog: Jede Szene braucht eine Bewegung. Ziel und Widerstand allein ergeben
        // noch keinen Lesesog, wenn am Ende nichts kippt, keine neue Folge entsteht
        // oder dieselbe Absicht mehrfach nur anders formuliert wird.
        var momentum = 0.0
        if plannedScenes.isEmpty {
            findings.append("Der Spannungs- und Fortschrittswert kann ohne ausgeschriebene Szenen nicht belegt werden.")
        } else {
            let count = Double(plannedScenes.count)
            let withGoal = plannedScenes.filter { $0.goal.wordCount >= 3 }.count
            let withResistance = plannedScenes.filter {
                $0.obstacle.wordCount >= 3 && !AutonomousContentQuality.isGenericPlaceholder($0.obstacle)
            }.count
            let withTurn = plannedScenes.filter {
                $0.cliffhanger.wordCount >= 3 && !AutonomousContentQuality.isGenericPlaceholder($0.cliffhanger)
            }.count
            let withConsequence = plannedScenes.filter {
                $0.newInformation.wordCount >= 3 || $0.emotionalChange.wordCount >= 3
            }.count
            momentum += 0.20 * Double(withGoal) / count
            momentum += 0.25 * Double(withResistance) / count
            momentum += 0.30 * Double(max(withTurn, withConsequence)) / count
            momentum += 0.15 * Double(withConsequence) / count

            let normalizedGoals = plannedScenes.map {
                $0.goal.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased().split(whereSeparator: \.isWhitespace).prefix(12).joined(separator: " ")
            }.filter { $0.wordCount >= 3 }
            let duplicateGoals = Dictionary(grouping: normalizedGoals, by: { $0 })
                .values.filter { $0.count > 1 }.count
            if duplicateGoals == 0 { momentum += 0.10 } else {
                momentum -= 0.20
                findings.append("Szenen wiederholen dasselbe Ziel, statt die Handlung sichtbar weiterzutreiben.")
            }
            if withTurn < plannedScenes.count && withConsequence < plannedScenes.count {
                findings.append("Mindestens eine Szene endet ohne erkennbare Wendung oder Folge für die nächste Szene.")
            }
        }
        momentum = bounded(momentum)

        // Dialoge sind nicht Pflicht. Gibt es genug Frage-Antwort-Paare, muss der
        // Subtext aber weder wie ein Verhör noch wie willkürliches Ausweichen klingen.
        let subtext = DialogSubtext.messe(in: trimmed)
        var dialogue = 1.0
        if let report = DialogSubtext.befund(fuer: subtext) {
            dialogue = 0.45
            findings.append(report)
        } else if subtext.belastbar {
            dialogue = 0.90
        } else if DialogSubtext.repliken(in: trimmed).count >= 8 {
            // Viel Dialog, aber kaum prüfbare Fragen: plausibel, jedoch nicht als volle
            // Bestnote deklarieren, weil die Spannung dann noch nicht messbar belegt ist.
            dialogue = 0.78
        }

        let overall = bounded(prose * 0.35 + sceneCraft * 0.25 + momentum * 0.25 + dialogue * 0.15)
        let verdict: Verdict = overall >= passThreshold && prose >= 0.75
            && sceneCraft >= 0.70 && momentum >= 0.75 && antiGlaette.isEmpty
            && teenReadability.isEmpty ? .ready : .revise
        if verdict == .revise && findings.isEmpty {
            findings.append("Das Kapitel erreicht den Lektoratsgrenzwert noch nicht sicher.")
        }

        return ChapterEditorialScorecard(
            chapterNumber: chapterNumber, wordCount: words,
            prose: prose, sceneCraft: sceneCraft, momentum: momentum, dialogue: dialogue,
            overall: overall, verdict: verdict, findings: findings
        )
    }

    private static func bounded(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
