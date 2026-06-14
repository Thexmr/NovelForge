import Foundation
import SwiftUI

struct AppConstants {
    static let appName = "NovelForge"
    static let appVersion = "2.0.0"
    static let maxPageCount = 1000 // bis zu 1000 Seiten (~250.000 Wörter); Plan skaliert automatisch
    static let minPageCount = 50
    static let wordsPerPage = 250
}

// MARK: - Anzeige-Namen & Fortschritt

extension ProjectStatus {
    var displayName: String {
        switch self {
        case .created: return "Angelegt"
        case .conceptDevelopment: return "Konzeptentwicklung"
        case .structurePlanning: return "Strukturplanung"
        case .chapterPlanning: return "Kapitelplanung"
        case .scenePlanning: return "Szenenplanung"
        case .drafting: return "Rohfassung"
        case .chapterRevision: return "Kapitelrevision"
        case .manuscriptRevision: return "Gesamtlektorat"
        case .proofreading: return "Korrektorat"
        case .copyrightCheck: return "Copyright-Prüfung"
        case .kdpFormatting: return "KDP-Formatierung"
        case .export: return "Export"
        case .completed: return "Abgeschlossen"
        case .failed: return "Fehlgeschlagen"
        case .paused: return "Pausiert"
        }
    }

    /// Grober Projektfortschritt anhand der Phasen-Gewichte.
    var progressFraction: Double {
        let phase: PipelinePhase?
        switch self {
        case .created: phase = .projectSetup
        case .conceptDevelopment: phase = .conceptDevelopment
        case .structurePlanning: phase = .structurePlanning
        case .chapterPlanning: phase = .chapterPlanning
        case .scenePlanning: phase = .scenePlanning
        case .drafting: phase = .drafting
        case .chapterRevision: phase = .chapterRevision
        case .manuscriptRevision: phase = .manuscriptRevision
        case .proofreading: phase = .proofreading
        case .copyrightCheck: phase = .copyrightCheck
        case .kdpFormatting: phase = .kdpFormatting
        case .export: phase = .export
        case .completed: return 1.0
        case .failed, .paused: phase = nil
        }
        guard let phase else { return 0 }
        var total = 0.0
        for item in PipelinePhase.executionOrder {
            if item == phase { break }
            total += item.weight
        }
        return total
    }
}

// MARK: - KDP-Druckformate

/// Von Amazon KDP unterstützte Taschenbuch-Trim-Größen.
enum TrimSize: String, CaseIterable, Identifiable {
    case fiveByEight = "5x8"
    case fiveFiveByEightFive = "5.5x8.5"
    case sixByNine = "6x9"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveByEight: return "5 × 8 Zoll (12,7 × 20,3 cm)"
        case .fiveFiveByEightFive: return "5,5 × 8,5 Zoll (14 × 21,6 cm)"
        case .sixByNine: return "6 × 9 Zoll (15,2 × 22,9 cm)"
        }
    }

    var pageWidth: CGFloat {
        switch self {
        case .fiveByEight: return 360
        case .fiveFiveByEightFive: return 396
        case .sixByNine: return 432
        }
    }

    var pageHeight: CGFloat {
        switch self {
        case .fiveByEight: return 576
        case .fiveFiveByEightFive: return 612
        case .sixByNine: return 648
        }
    }

    /// Innenrand (Bundsteg) nach KDP-Vorgabe, abhängig von der Seitenzahl. In Punkt.
    static func gutterPoints(forPageCount pages: Int) -> CGFloat {
        let inches: CGFloat
        switch pages {
        case ..<151: inches = 0.375
        case ..<301: inches = 0.5
        case ..<501: inches = 0.625
        case ..<701: inches = 0.75
        default: inches = 0.875
        }
        return inches * 72.0
    }
}

extension Project {
    var totalWordCount: Int {
        (chapters ?? []).reduce(0) { $0 + $1.displayWordCount }
    }

    var trimSize: TrimSize {
        TrimSize(rawValue: trimSizeRaw) ?? .sixByNine
    }

    /// BCP-47-Sprachcode für Exportformate.
    var languageCode: String {
        switch language {
        case "Deutsch": return "de"
        case "Englisch": return "en"
        case "Französisch": return "fr"
        case "Spanisch": return "es"
        default: return "de"
        }
    }
}

// MARK: - Qualitätsbewertung (aus echten Projektdaten berechnet)

struct QualityScores {
    let structure: Double
    let characters: Double
    let style: Double
    let consistency: Double
    let kdp: Double

    static func compute(for project: Project) -> QualityScores {
        let chapters = project.chapters ?? []

        // Struktur: Anteil der Kapitel mit Ziel und geplanten Szenen.
        let structure: Double
        if chapters.isEmpty {
            structure = 0
        } else {
            let wellFormed = chapters.filter { !$0.goal.isEmpty && !($0.scenes ?? []).isEmpty }.count
            structure = Double(wellFormed) / Double(chapters.count)
        }

        // Figuren: mindestens 5 ausgearbeitete Figuren gelten als vollständig.
        let characterCount = project.storyBible?.characters?.count ?? 0
        let characters = min(1.0, Double(characterCount) / 5.0)

        // Stil: Anteil der Szenen innerhalb ±25% der Zielwortzahl.
        let scenes = chapters.flatMap { $0.scenes ?? [] }
        let written = scenes.filter { ($0.text ?? "").isEmpty == false }
        let style: Double
        if written.isEmpty {
            style = 0
        } else {
            let inTolerance = written.filter { scene in
                let wordCount = scene.text?.wordCount ?? 0
                let target = max(scene.targetWordCount, 1)
                return abs(wordCount - target) <= Int(Double(target) * 0.25)
            }.count
            style = Double(inTolerance) / Double(written.count)
        }

        // Konsistenz: jede gefundene schwere Inkonsistenz kostet 10%.
        let severeIssues = (project.qualityReports ?? [])
            .filter { $0.checkType == "Konsistenz" && ($0.severity == .error || $0.severity == .critical) }
            .count
        let consistency = max(0.0, 1.0 - Double(severeIssues) * 0.1)

        // KDP: Abweichung vom Zielumfang.
        let totalWords = project.totalWordCount
        let targetWords = max(project.targetWordCount, 1)
        let deviation = abs(Double(totalWords - targetWords)) / Double(targetWords)
        let kdp = totalWords == 0 ? 0 : max(0.0, 1.0 - deviation)

        return QualityScores(structure: structure, characters: characters,
                             style: style, consistency: consistency, kdp: kdp)
    }
}

// MARK: - Formatierung

extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: self)
    }
}

extension String {
    func truncated(to length: Int, trailing: String = "…") -> String {
        if self.count > length {
            return String(self.prefix(length)) + trailing
        }
        return self
    }
}

struct FormattingHelpers {
    static func formatWordCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    static func formatCost(_ cost: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: cost)) ?? String(format: "$%.2f", cost)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Copyright-Schutz (lokale Heuristik)

struct CopyrightChecker {
    private static let forbiddenTerms = [
        "bestsellerautor", "kopiere", "fortsetzung von", "wie j.k. rowling",
        "wie stephen king", "wie george r.r. martin", "wie dan brown",
        "harry potter", "herr der ringe", "game of thrones",
        "star wars", "star trek", "marvel", "dc comics", "hogwarts",
        "mittelerde", "westeros"
    ]

    static func checkInput(title: String, style: String) -> (isValid: Bool, warnings: [String]) {
        var warnings: [String] = []
        let input = "\(title) \(style)".lowercased()
        for term in forbiddenTerms where input.contains(term) {
            warnings.append("Copyright-Risiko erkannt: \"\(term)\"")
        }
        return (warnings.isEmpty, warnings)
    }

    static func checkPlot(_ text: String) -> [String] {
        var issues: [String] = []
        let lowered = text.lowercased()
        for term in forbiddenTerms where lowered.contains(term) {
            issues.append("Mögliche Nähe zu geschütztem Werk/Begriff: \"\(term)\"")
        }
        return issues
    }
}

// MARK: - Validierung

struct InputValidator {
    static func validateProject(_ project: Project) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        if project.title.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Titel ist erforderlich")
        }
        if project.authorName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Autorname ist erforderlich")
        }
        if project.genre.isEmpty {
            errors.append("Genre ist erforderlich")
        }
        if project.targetPageCount < AppConstants.minPageCount || project.targetPageCount > AppConstants.maxPageCount {
            errors.append("Seitenzahl muss zwischen \(AppConstants.minPageCount) und \(AppConstants.maxPageCount) liegen")
        }
        if project.styleProfile.isEmpty {
            errors.append("Stilprofil ist erforderlich")
        }

        let copyrightCheck = CopyrightChecker.checkInput(title: project.title, style: project.styleProfile)
        if !copyrightCheck.isValid {
            errors.append(contentsOf: copyrightCheck.warnings)
        }

        return (errors.isEmpty, errors)
    }
}
