import Foundation

struct ChapterEventDuplicate: Equatable {
    let laterSceneNumber: Int
    let earlierSceneNumber: Int
    let event: String
    let instruction: String
}

enum ChapterEventDuplicateParser {
    static func isConclusive(_ text: String) -> Bool {
        !parse(text).isEmpty || text.localizedCaseInsensitiveContains("KEINE DOPPLUNG")
    }

    static func parse(_ text: String) -> [ChapterEventDuplicate] {
        text.components(separatedBy: .newlines).compactMap { line in
            let cleaned = line
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.uppercased().hasPrefix("DUPLICATE|") else { return nil }
            let parts = cleaned.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count >= 5,
                  let later = Int(parts[1]), let earlier = Int(parts[2]),
                  later > earlier, !parts[3].isEmpty else { return nil }
            let instruction = parts.dropFirst(4).joined(separator: " | ")
            guard !instruction.isEmpty else { return nil }
            return ChapterEventDuplicate(laterSceneNumber: later,
                                         earlierSceneNumber: earlier,
                                         event: parts[3], instruction: instruction)
        }
    }

    /// Ein Lektor meldet dieselbe Szenenpaar-Dopplung oft in mehreren Facetten
    /// (Bestellung, Ortswechsel, Entscheidung). Fuer die Reparatur ist das EIN Auftrag:
    /// Drei Zeilen fuer Szene 1 -> 2 duerfen nicht als drei unabhaengige Szenenfehler
    /// gelten und dadurch die Plausibilitaetssperre ausloesen.
    static func consolidated(_ findings: [ChapterEventDuplicate],
                             validSceneNumbers: Set<Int>) -> [ChapterEventDuplicate] {
        struct Pair: Hashable {
            let later: Int
            let earlier: Int
        }

        var order: [Pair] = []
        var events: [Pair: [String]] = [:]
        var instructions: [Pair: [String]] = [:]
        for finding in findings {
            guard validSceneNumbers.contains(finding.laterSceneNumber),
                  validSceneNumbers.contains(finding.earlierSceneNumber),
                  finding.laterSceneNumber > finding.earlierSceneNumber else { continue }
            let pair = Pair(later: finding.laterSceneNumber,
                            earlier: finding.earlierSceneNumber)
            if events[pair] == nil { order.append(pair) }
            if events[pair]?.contains(finding.event) != true {
                events[pair, default: []].append(finding.event)
            }
            if instructions[pair]?.contains(finding.instruction) != true {
                instructions[pair, default: []].append(finding.instruction)
            }
        }
        return order.map { pair in
            ChapterEventDuplicate(
                laterSceneNumber: pair.later,
                earlierSceneNumber: pair.earlier,
                event: events[pair, default: []].joined(separator: "; "),
                instruction: instructions[pair, default: []].joined(separator: " ")
            )
        }
    }
}

struct ChapterSceneReference: Equatable, Hashable {
    let chapterNumber: Int
    let sceneNumber: Int
}

/// Eine Ereignisdopplung ÜBER KAPITELGRENZEN hinweg.
///
/// WARUM EIN EIGENES FORMAT: Der kapitelinterne Audit (ChapterEventDuplicate)
/// sieht nur die Szenen EINES Kapitels. Die teuersten Doppler entstehen aber
/// kapitelübergreifend – dieselbe Entdeckung/Begegnung wird in Kapitel 3, 5 und 9
/// jeweils „zum ersten Mal" inszeniert. Solche Doppler waren bisher nur über die
/// Zusammenfassungs-Konsistenzprüfung sichtbar, die keine Szenentexte kennt.
struct CrossChapterEventDuplicate: Equatable {
    let laterChapterNumber: Int
    let laterSceneNumber: Int
    let earlierChapterNumber: Int
    let earlierSceneNumber: Int
    let event: String
    let instruction: String
}

enum CrossChapterEventDuplicateParser {
    static func isConclusive(_ text: String) -> Bool {
        !parse(text).isEmpty || text.localizedCaseInsensitiveContains("KEINE DOPPLUNG")
    }

    /// Format: DUPLICATE|späteres Kap|spätere Sz|früheres Kap|frühere Sz|Ereignis|Anweisung
    static func parse(_ text: String) -> [CrossChapterEventDuplicate] {
        text.components(separatedBy: .newlines).compactMap { line in
            let cleaned = line
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.uppercased().hasPrefix("DUPLICATE|") else { return nil }
            let parts = cleaned.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count >= 7,
                  let laterChapter = Int(parts[1]), let laterScene = Int(parts[2]),
                  let earlierChapter = Int(parts[3]), let earlierScene = Int(parts[4]),
                  (laterChapter, laterScene) != (earlierChapter, earlierScene),
                  laterChapter >= earlierChapter,
                  !parts[5].isEmpty else { return nil }
            let instruction = parts.dropFirst(6).joined(separator: " | ")
            guard !instruction.isEmpty else { return nil }
            return CrossChapterEventDuplicate(
                laterChapterNumber: laterChapter, laterSceneNumber: laterScene,
                earlierChapterNumber: earlierChapter, earlierSceneNumber: earlierScene,
                event: parts[5], instruction: instruction
            )
        }
    }
}

enum ChapterSceneReferenceParser {
    static func parse(_ text: String) -> [ChapterSceneReference] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)kapitel\s+(\d+)\s*[,;:\-–]?\s*szene\s+(\d+)"#
        ) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<ChapterSceneReference>()
        return regex.matches(in: text, range: range).compactMap { match in
            guard let chapterRange = Range(match.range(at: 1), in: text),
                  let sceneRange = Range(match.range(at: 2), in: text),
                  let chapter = Int(text[chapterRange]),
                  let scene = Int(text[sceneRange]) else { return nil }
            let reference = ChapterSceneReference(chapterNumber: chapter, sceneNumber: scene)
            return seen.insert(reference).inserted ? reference : nil
        }
    }
}
