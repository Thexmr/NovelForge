import Foundation

/// „Spice"/Hitzegrad (1–5) – in der Romance-Welt eine eigene Such- und Filterachse
/// (Leser suchen aktiv nach Heat). 0 = nicht angegeben (z.B. Nicht-Romance).
///
/// Ein einziger Wert steuert mehrere Stellen: wie explizit die Szenen geschrieben
/// werden (Generierung) UND wie der Hitzegrad in KDP-Verkaufstext/Keywords/Kategorien/
/// Trigger-Hinweise einfließt (Discovery + Erwartungs-Matching gegen Retouren).
enum SpiceLevel {
    static let range = 1...5

    static func isValid(_ level: Int) -> Bool { range.contains(level) }

    static func label(_ level: Int) -> String {
        switch level {
        case 1: return "Sweet / Clean"
        case 2: return "Mild"
        case 3: return "Mittel"
        case 4: return "Heiß"
        case 5: return "Scorching"
        default: return "Nicht angegeben"
        }
    }

    /// Chili-Symbole für die UI-Anzeige (Romance-Konvention).
    static func chili(_ level: Int) -> String {
        guard isValid(level) else { return "—" }
        return String(repeating: "🌶", count: level)
    }

    /// Beschriftung für den Wizard-Picker.
    static func pickerLabel(_ level: Int) -> String {
        guard isValid(level) else { return "Nicht angegeben" }
        return "\(chili(level)) \(level)/5 – \(label(level))"
    }

    /// Verbindlicher Hitzegrad-Block für die Szenengenerierung (draftScene).
    /// Bewusst ohne gerade Anführungszeichen formuliert (SwiftUI/Build-sicher).
    static func generationDirective(_ level: Int) -> String {
        switch level {
        case 1:
            return "HITZEGRAD 1/5 (Sweet/Clean): Romantik lebt von Spannung, Sehnsucht und Gefühl. Körperliche Nähe nur angedeutet (Blicke, Berührungen, Küsse). KEINE expliziten Sex-Szenen, sondern closed-door."
        case 2:
            return "HITZEGRAD 2/5 (mild): Intimität wird aufgebaut, aber vor dem Expliziten ausgeblendet (fade to black). Fokus auf Emotion und Begehren, nicht auf Darstellung."
        case 3:
            return "HITZEGRAD 3/5 (mittel): Es gibt explizite Liebesszenen, aber bewusst sparsam gesetzt; sie treiben die Beziehung voran und dominieren die Handlung nicht."
        case 4:
            return "HITZEGRAD 4/5 (heiß): Häufige, detaillierte, explizite Liebesszenen, die zentral für Beziehung und Lesesog sind – sinnlich, konkret und geschmackvoll erzählt. Alle Beteiligten sind erwachsen und handeln einvernehmlich."
        case 5:
            return "HITZEGRAD 5/5 (sehr explizit, Erotik/Dark Romance): Sehr häufige, sehr explizite Szenen; hoher Heat ist ein Kern-Verkaufsargument. Ausschließlich erwachsene, einvernehmliche Inhalte; nichts Illegales."
        default:
            return ""
        }
    }

    /// Block für die KDP-Metadaten (Verkaufstext-Hinweis, Heat-Keywords, Kategorie,
    /// Trigger-/Content-Hinweise). Steuert Discoverability über die Heat-Achse.
    static func kdpGuidance(_ level: Int) -> String {
        switch level {
        case 1, 2:
            return "\nHITZEGRAD: \(level)/5 (\(label(level))). Signalisiere den niedrigen Heat dezent über passende KEYWORDS (z.B. sweet romance, clean romance, slow burn). Keine expliziten Reizwörter."
        case 3:
            return "\nHITZEGRAD: 3/5 (mittel). Greife den Heat im VERKAUFSTEXT dezent auf. Nimm passende KEYWORDS auf (z.B. spicy romance, steamy, slow burn)."
        case 4:
            return "\nHITZEGRAD: 4/5 (heiß). Bewerbe den Heat als Verkaufsargument (z.B. eine Schlusszeile Heat: 4/5). KEYWORDS u.a. spicy romance, steamy, explicit. Ergänze am Ende kurze Content-/Trigger-Hinweise (erwachsene Inhalte)."
        case 5:
            return "\nHITZEGRAD: 5/5 (sehr explizit, Erotik/Dark Romance). Heat ist Kern-Verkaufsargument. KEYWORDS u.a. dark romance, explicit, steamy. Wähle wo passend die Erotik-Kategorie. Ergänze klare Content-/Trigger-Warnungen (nur erwachsene, einvernehmliche Inhalte). Hinweis: Amazon kann sehr explizite Titel in der Sichtbarkeit filtern."
        default:
            return ""
        }
    }
}
