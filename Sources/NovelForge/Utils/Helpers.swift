import Foundation
import SwiftUI
import SwiftData
import OSLog

// MARK: - Persistenz-Logging

extension ModelContext {
    /// Speichert den Kontext und PROTOKOLLIERT Fehler, statt sie stillschweigend zu
    /// verschlucken (`try? save()`). Das Verhalten bleibt bewusst nicht-fatal – ein
    /// fehlgeschlagener Save unterbricht die App nicht –, aber Disk-voll-/Constraint-
    /// Fehler landen jetzt im Log statt spurlos zu verschwinden (In-Memory- und Disk-
    /// Zustand konnten so unbemerkt divergieren).
    func saveOrLog(_ label: String = "", file: String = #fileID, line: Int = #line) {
        do {
            try save()
        } catch {
            Logger(subsystem: "com.novelforge.app", category: "persistence")
                .error("SwiftData-Speicherfehler [\(label, privacy: .public)] \(file):\(line) – \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct AppConstants {
    static let appName = "NovelForge"
    static let appVersion = "2.1.1"
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

    /// Schnelle Wortzahl für Listen und Dashboards. Die Pipeline aktualisiert den
    /// Wert nach jeder geschriebenen bzw. überarbeiteten Szene; anders als
    /// `totalWordCount` muss dafür kein kompletter Buchtext geladen werden.
    var recordedWordCount: Int {
        (chapters ?? []).reduce(0) { $0 + $1.actualWordCount }
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

    private struct CachedEntry {
        let fingerprint: Int
        let scores: QualityScores
    }

    @MainActor private static var uiCache: [UUID: CachedEntry] = [:]

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

        // Bei Romanen: Figurenensemble. Bei Sachbüchern: Leserproblem, Zielgruppe,
        // Nutzenversprechen und konkrete Kapitelziele statt einer künstlichen Figurenliste.
        let characters: Double
        if project.isNonfiction {
            let profile = project.bookProfile
            let fields = [profile?.premise ?? "", profile?.targetAudience ?? "",
                          profile?.readerBenefit ?? "", profile?.synopsis ?? ""]
            let profileScore = Double(fields.filter { $0.wordCount >= 5 }.count) / Double(fields.count)
            let usefulChapters = chapters.filter { $0.goal.wordCount >= 4 && $0.conflict.wordCount >= 3 }.count
            let chapterScore = chapters.isEmpty ? 0 : Double(usefulChapters) / Double(chapters.count)
            characters = (profileScore + chapterScore) / 2
        } else {
            let characterCount = project.storyBible?.characters?.count ?? 0
            characters = min(1.0, Double(characterCount) / 5.0)
        }

        // Stil: Umfang allein ist kein Qualitätsbeweis. Kombiniere Zieltreue mit
        // deterministischen Prüfungen auf maschinelle Muster und buchweite Floskeln.
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
            let lengthScore = Double(inTolerance) / Double(written.count)
            let natural = written.filter {
                !AutonomousContentQuality.soundsLikeAI($0.text ?? "")
            }.count
            let naturalnessScore = Double(natural) / Double(written.count)
            let chapterTexts = chapters.compactMap(\.bestText).filter { !$0.isEmpty }
            let repeated = AutonomousContentQuality.overusedPhrases(inChapters: chapterTexts)
            let repetitionScore = max(0.0, 1.0 - Double(repeated.count) / 10.0)
            style = lengthScore * 0.30 + naturalnessScore * 0.45 + repetitionScore * 0.25
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

    /// Schnelle Variante für SwiftUI-Ansichten. Produktionsphase und Exportbericht
    /// nutzen weiterhin `compute(for:)`, damit dort immer frisch geprüft wird.
    @MainActor
    static func cached(for project: Project) -> QualityScores {
        let fingerprint = uiFingerprint(project)
        if let cached = uiCache[project.id], cached.fingerprint == fingerprint {
            return cached.scores
        }

        let scores = compute(for: project)
        if uiCache.count >= 256, uiCache[project.id] == nil {
            uiCache.removeAll(keepingCapacity: true)
        }
        uiCache[project.id] = CachedEntry(fingerprint: fingerprint, scores: scores)
        return scores
    }

    @MainActor
    private static func uiFingerprint(_ project: Project) -> Int {
        var hasher = Hasher()
        hasher.combine(project.id)
        hasher.combine(project.updatedAt)
        hasher.combine(project.targetWordCount)
        hasher.combine(project.storyBible?.characters?.count ?? 0)

        let chapters = project.chapters ?? []
        hasher.combine(chapters.count)
        for chapter in chapters {
            hasher.combine(chapter.id)
            hasher.combine(chapter.updatedAt)
            hasher.combine(chapter.actualWordCount)
            hasher.combine(chapter.targetWordCount)
            hasher.combine(chapter.goal.isEmpty)

            let scenes = chapter.scenes ?? []
            hasher.combine(scenes.count)
            for scene in scenes {
                hasher.combine(scene.id)
                hasher.combine(scene.updatedAt)
                hasher.combine(scene.status.rawValue)
                hasher.combine(scene.targetWordCount)
                hasher.combine(scene.text?.isEmpty ?? true)
            }
        }

        let reports = project.qualityReports ?? []
        hasher.combine(reports.count)
        for report in reports {
            hasher.combine(report.id)
            hasher.combine(report.createdAt)
            hasher.combine(report.severity.rawValue)
            hasher.combine(report.autoFixed)
        }
        return hasher.finalize()
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
    /// Namen/Begriffe aus geschützten Werken (Figuren, Orte, Welten, Reihen) + Plagiat-/Meta-Marker.
    /// Bewusst breit für die meistproduzierten Genres (Romance/Thriller/Fantasy), damit kein
    /// fremdes Werk übernommen wird.
    static let forbiddenTerms = [
        // Meta / direkte Nachahmung
        "bestsellerautor", "kopiere", "fortsetzung von", "schreibe wie", "wie j.k. rowling",
        "wie stephen king", "wie george r.r. martin", "wie dan brown", "wie colleen hoover",
        "wie e.l. james", "wie sarah j. maas",
        // Fantasy / SciFi – Welten & Figuren
        "harry potter", "hermine granger", "hermione granger", "dumbledore", "voldemort",
        "hogwarts", "gryffindor", "slytherin", "herr der ringe", "mittelerde", "auenland",
        "frodo", "gandalf", "sauron", "game of thrones", "westeros", "daenerys", "jon snow",
        "khaleesi", "lannister", "targaryen", "star wars", "darth vader", "jedi", "skywalker",
        "star trek", "marvel", "dc comics", "spider-man", "batman", "hunger games", "katniss",
        "tribute von panem", "percy jackson", "narnia",
        // Romance-Bestseller (Hauptgenre)
        "fifty shades", "shades of grey", "christian grey", "anastasia steele", "bridgerton",
        "outlander", "twilight", "bella swan", "edward cullen", "jacob black", "it ends with us",
        "a court of thorns", "feyre", "rhysand", "throne of glass",
        // Thriller / Krimi
        "sherlock holmes", "james bond", "jack reacher", "hannibal lecter", "lisbeth salander",
        "kommissar wallander", "harry hole", "robert langdon", "da vinci code"
    ]

    static func checkInput(title: String, style: String) -> (isValid: Bool, warnings: [String]) {
        let input = "\(title) \(style)".lowercased()
        let warnings = forbiddenTerms.filter { input.contains($0) }.map { "Copyright-Risiko erkannt: \"\($0)\"" }
        return (warnings.isEmpty, warnings)
    }

    static func checkPlot(_ text: String) -> [String] {
        let lowered = text.lowercased()
        return forbiddenTerms.filter { lowered.contains($0) }.map { "Mögliche Nähe zu geschütztem Werk/Begriff: \"\($0)\"" }
    }

    /// Scannt das GESAMTE Manuskript auf Namen/Begriffe aus geschützten Werken und auf mögliche
    /// wörtliche Songtext-/Gedicht-Zitate (strikt geschützt, keine Fair-Use-Annahme).
    static func checkManuscript(_ text: String) -> [String] {
        var issues: [String] = []
        let lowered = text.lowercased()
        for term in forbiddenTerms where lowered.contains(term) {
            issues.append("Geschützter Name/Begriff im Text: \"\(term)\"")
        }
        if lowered.contains("songtext") || lowered.contains("liedtext")
            || text.range(of: #"[♪🎵]"#, options: .regularExpression) != nil {
            issues.append("Mögliches Songtext-Zitat – reale Liedtexte NICHT abdrucken (strikt urheberrechtlich geschützt).")
        }
        return issues
    }

    /// Liegt der Titel zu nah an einem geschützten Werk/Reihentitel?
    static func isInfringingTitle(_ title: String) -> Bool {
        let low = title.lowercased()
        return forbiddenTerms.contains { low.contains($0) }
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
