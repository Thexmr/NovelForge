import Foundation

@main
enum LibraryPresentationProbe {
    static func main() {
        precondition(BookLibraryFilter.attention.includes(.failed))
        precondition(BookLibraryFilter.attention.includes(.needsReview))
        precondition(!BookLibraryFilter.attention.includes(.completed))
        precondition(BookLibraryFilter.unfinished.includes(.paused))
        precondition(BookLibraryFilter.unfinished.includes(.failed))
        precondition(!BookLibraryFilter.completed.includes(.needsReview))
        precondition(BookLibraryFilter.matches(query: "  nacht DAVE ", title: "Die Nacht", author: "Dave", genre: "Thriller"))
        precondition(BookLibraryFilter.matches(query: "demare", title: "Buch", author: "Demaré", genre: "Roman"))
        precondition(BookLibraryFilter.matches(query: "  ", title: "", author: "", genre: ""))
        precondition(!BookLibraryFilter.matches(query: "Nacht Horror", title: "Die Nacht", author: "Dave", genre: "Roman"))
        precondition(Set(SidebarItem.allCases.map(\.title)).count == SidebarItem.allCases.count)
        precondition(SidebarItem.dashboard.rawValue == "Dashboard")
        precondition(BookLibraryFilter.wordProgress(written: 100, target: 200) == 0.5)
        precondition(BookLibraryFilter.wordProgress(written: 500, target: 200) == 1)
        precondition(BookLibraryFilter.wordProgress(written: 500, target: 0) == 0)
        precondition(!ProductionIncidentStore.isActionable("Produktion pausiert; gespeicherter Stand bleibt erhalten."))
        precondition(ProductionIncidentStore.isActionable("Netzwerkfehler beim Schreiben"))
        print("Library presentation: 17 checks PASS")
    }
}
