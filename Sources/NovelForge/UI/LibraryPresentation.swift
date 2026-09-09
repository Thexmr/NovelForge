import Foundation

enum BookLibraryFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case unfinished = "In Arbeit"
    case attention = "Prüfen"
    case completed = "Fertig"
    var id: String { rawValue }

    static func wordProgress(written: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, Double(written) / Double(target)))
    }

    func includes(_ status: ProjectStatus) -> Bool {
        switch self {
        case .all: return true
        case .unfinished: return status != .completed
        case .attention: return status == .failed || status == .needsReview
        case .completed: return status == .completed
        }
    }

    static func matches(query: String, title: String, author: String, genre: String) -> Bool {
        let text = [title, author, genre].joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy {
            text.localizedStandardContains(String($0))
        }
    }
}
