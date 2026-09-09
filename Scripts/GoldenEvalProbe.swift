import Foundation

@main
struct GoldenEvalProbe {
    static func main() {
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 8, approved: true,
                dimensionScores: [8, 8, 7, 8, 8], requiredDimensionCount: 5
            ) == .release
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 7, approved: true,
                dimensionScores: [8, 8, 8, 8, 8], requiredDimensionCount: 5
            ) == .repair
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 8, approved: true,
                dimensionScores: [8, 8, 6, 9, 9], requiredDimensionCount: 5
            ) == .repair
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 8, approved: false,
                dimensionScores: [8, 8, 8, 8, 8], requiredDimensionCount: 5
            ) == .repair
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: nil, approved: true,
                dimensionScores: [8, 8, 8, 8, 8], requiredDimensionCount: 5
            ) == .invalid
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 8, approved: nil,
                dimensionScores: [8, 8, 8, 8, 8], requiredDimensionCount: 5
            ) == .invalid
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 11, approved: true,
                dimensionScores: [8, 8, 8, 8, 8], requiredDimensionCount: 5
            ) == .invalid
        )
        precondition(
            QualityReleasePolicy.goldenEvalDecision(
                score: 8, approved: true,
                dimensionScores: [8, 8, 8, 8], requiredDimensionCount: 5
            ) == .invalid,
            "Eine unvollstaendige Dimensionsbewertung darf niemals freigeben"
        )

        let slashScores = AutonomousContentQuality.parseGoldenEval("""
        SPANNUNGSBOGEN: 8/10 — traegt
        FIGUREN UND DIALOGE: 7/10 — unterscheidbar
        KONFLIKT UND EINSÄTZE: 8/10 — steigen
        STIL UND VOICE: 8/10 — eigen
        SPRACHLICHE SAUBERKEIT: 7/10 — sauber
        ENDE UND KATHARSIS: 8/10 — eingeloest
        GESAMT: 8/10 — veroeffentlichbar
        URTEIL: FREIGABE
        """)
        precondition(slashScores.gesamt == 8)
        precondition(slashScores.noten.count == 6)
        precondition(slashScores.freigabe == true,
                     "Uebliche x/10-Noten muessen als vollstaendige Golden-Eval gelten")

        print("GoldenEvalProbe: PASS")
    }
}
