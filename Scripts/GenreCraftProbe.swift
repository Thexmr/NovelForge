import Foundation

@main
enum GenreCraftProbe {
    static func main() {
        let horror = PromptFactory.genreCraft("Psychologischer Horror")
        for required in ["konkret", "Quelle", "Verletzlichkeit", "Konsequenz", "Kontrast", "Enthuell"] {
            precondition(horror.localizedCaseInsensitiveContains(required),
                         "Horror-Handwerk braucht: \(required)")
        }
        precondition(horror.localizedCaseInsensitiveContains("keine diffuse Dauerdüsternis"),
                     "Horror darf nicht nur aus vager Daueratmosphaere bestehen")

        let thriller = PromptFactory.genreCraft("Psychothriller")
        precondition(thriller.localizedCaseInsensitiveContains("Kausalitaet"))
        precondition(thriller.localizedCaseInsensitiveContains("keine Pflicht-Cliffhanger"))

        let generic = PromptFactory.genreCraft("Gegenwartsroman")
        precondition(generic.localizedCaseInsensitiveContains("emotional"))
        precondition(generic.localizedCaseInsensitiveContains("Wahrheit"))
        precondition(generic.localizedCaseInsensitiveContains("leicht lesbar"))
        print("NovelForge genre craft probe: PASS")
    }
}
