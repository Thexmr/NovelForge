import Foundation

/// Sinnlichkeitsgrad (1–5) – branchenübliche Einstufung der erotischen Intensität
/// eines Romance-Titels. 0 = nicht angegeben (z.B. Nicht-Romance).
///
/// Ein einziger Wert steuert beides: wie ausführlich intime Szenen geschrieben werden
/// (Generierung) UND wie der Grad in KDP-Verkaufstext/Keywords/Kategorien/Inhaltshinweise
/// einfließt (Auffindbarkeit + Erwartungs-Matching, das Retouren senkt).
enum SpiceLevel {
    static let range = 1...5

    static func isValid(_ level: Int) -> Bool { range.contains(level) }

    /// Kurzer Stufenname (für KDP-Hinweis und Review-Zeile).
    static func label(_ level: Int) -> String {
        switch level {
        case 1: return "Dezent"
        case 2: return "Andeutend"
        case 3: return "Moderat"
        case 4: return "Explizit"
        case 5: return "Sehr explizit"
        default: return "Nicht angegeben"
        }
    }

    /// Beschriftung für den Wizard-Picker (sachlich, ohne Symbole).
    static func pickerLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Stufe 1 – Dezent (keine expliziten Szenen)"
        case 2: return "Stufe 2 – Andeutend"
        case 3: return "Stufe 3 – Moderat"
        case 4: return "Stufe 4 – Explizit"
        case 5: return "Stufe 5 – Sehr explizit"
        default: return "Nicht angegeben"
        }
    }

    /// Verbindlicher Block für die Szenengenerierung (draftScene).
    /// Bewusst ohne gerade Anführungszeichen formuliert (SwiftUI/Build-sicher).
    static func generationDirective(_ level: Int) -> String {
        switch level {
        case 1:
            return "SINNLICHKEITSGRAD 1/5 (dezent): Die Romantik lebt von Spannung, Sehnsucht und Gefühl. Körperliche Nähe nur angedeutet (Blicke, Berührungen, Küsse). Keine expliziten Szenen."
        case 2:
            return "SINNLICHKEITSGRAD 2/5 (andeutend): Intimität wird aufgebaut, aber vor dem Expliziten ausgeblendet. Der Fokus liegt auf Emotion und Begehren, nicht auf Darstellung."
        case 3:
            return "SINNLICHKEITSGRAD 3/5 (moderat): Es gibt explizite Liebesszenen, jedoch sparsam gesetzt; sie treiben die Beziehung voran und dominieren die Handlung nicht."
        case 4:
            return "SINNLICHKEITSGRAD 4/5 (explizit): Häufige, detaillierte Liebesszenen, die zentral für die Beziehung sind – sinnlich, konkret und geschmackvoll erzählt. Alle Beteiligten sind erwachsen und handeln einvernehmlich."
        case 5:
            return "SINNLICHKEITSGRAD 5/5 (sehr explizit): Sehr häufige, sehr explizite Szenen mit hoher erotischer Intensität als Kern des Buches. Ausschließlich erwachsene, einvernehmliche Inhalte; nichts Illegales."
        default:
            return ""
        }
    }

    /// Block für die KDP-Metadaten (Verkaufstext-Einordnung, Keywords, Kategorie,
    /// Inhaltshinweise). Sorgt für die passende Auffindbarkeit über die erotische Einstufung.
    static func kdpGuidance(_ level: Int) -> String {
        switch level {
        case 1, 2:
            return "\nSINNLICHKEITSGRAD: \(level)/5 (\(label(level))). Ordne das Buch entsprechend ein: zurückhaltende KEYWORDS (z.B. Gefühlvolle Liebesgeschichte, Slow Burn). Keine expliziten Reizbegriffe."
        case 3:
            return "\nSINNLICHKEITSGRAD: 3/5 (moderat). Greife die sinnliche Note im VERKAUFSTEXT dezent auf. Passende KEYWORDS (z.B. Prickelnde Liebesgeschichte, Slow Burn)."
        case 4:
            return "\nSINNLICHKEITSGRAD: 4/5 (explizit). Weise die erotische Intensität sachlich aus. KEYWORDS u.a. Erotische Romance, Sinnliche Liebesgeschichte. Ergänze am Ende einen kurzen Inhaltshinweis (Szenen mit explizitem Inhalt, nur für Erwachsene)."
        case 5:
            return "\nSINNLICHKEITSGRAD: 5/5 (sehr explizit, Erotik/Dark Romance). KEYWORDS u.a. Erotischer Roman, Dark Romance. Wähle wo passend die Erotik-Kategorie. Ergänze einen klaren Inhaltshinweis (explizite Szenen, nur für Erwachsene). Hinweis: Amazon kann sehr explizite Titel in der Sichtbarkeit einschränken."
        default:
            return ""
        }
    }
}
