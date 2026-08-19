import Foundation

/// VERGIBT FIGURENNAMEN, STATT SIE ZU PRÜFEN.
///
/// **Warum die bisherige Richtung falsch war.** Das Modell erfand die Namen, danach suchte
/// das Programm nach Kollisionen und benannte im Konfliktfall um. Diese Reihenfolge kann
/// nicht funktionieren, und die Zahlen sagen genau, wie schlecht sie funktioniert hat.
/// Gemessen an 35 ausgelieferten Büchern (5,9 Mio. Wörter):
///
/// | Name | in Büchern |
/// |---|---|
/// | Mira | 14 von 35 |
/// | Brenner | 14 von 35 |
/// | Voss | 14 von 35 |
/// | Jonas | 14 von 35 |
///
/// Vier Namen in 40 % aller Bücher. Für einen Leser, der zwei Titel kauft, ist das
/// derselbe Roman mit anderem Umschlag.
///
/// Der Grund ist strukturell: Ein Sprachmodell hat Lieblingsnamen, und eine Anweisung
/// („benutze andere Namen") ist eine Bitte. Dieselbe Erfahrung wie bei der Bildersperre
/// (7,5 statt 0,4) und der alten Namenssperre („Liv" stand 263-mal im Buch, obwohl die
/// Figurenliste andere Namen nannte).
///
/// **Die Umkehrung.** Die Namen werden VOR dem Figurenagenten vergeben und ihm als
/// gesetzt übergeben. Er erfindet keine mehr; er füllt die Figuren dahinter. Was nicht
/// erfunden wird, kann sich nicht wiederholen.
///
/// **Serien sind ausgenommen.** Ein Folgeband MUSS dieselben Figuren führen – dort greift
/// der Generator nicht.
enum NamensGenerator {

    enum Geschlecht: String, Equatable {
        case weiblich
        case maennlich
        case unbekannt

        var promptLabel: String {
            switch self {
            case .weiblich: return "weiblich"
            case .maennlich: return "männlich"
            case .unbekannt: return "neutral/ungeklärt"
            }
        }
    }

    /// Ein vollständiger Name mit seiner Herkunftsregion.
    struct Vorschlag: Equatable {
        let vorname: String
        let nachname: String
        let region: String
        var voll: String { "\(vorname) \(nachname)" }
        var geschlecht: Geschlecht { NamensGenerator.geschlecht(vonVorname: vorname) }
    }

    /// Erzeugt paarweise verschiedene, katalogweit freie Namen.
    ///
    /// - Parameters:
    ///   - anzahl: Wie viele Namen gebraucht werden.
    ///   - gesperrt: Alle katalogweit belegten Namensteile (inklusive
    ///     `StoryMemory.verbrauchteNamen`).
    ///   - streuung: Seed für die Auswahl – üblicherweise die Projekt-ID. Gleicher Seed
    ///     ergibt dieselben Namen, damit ein wiederaufgenommener Lauf nicht plötzlich
    ///     andere Figuren bekommt.
    ///   - eineFamilie: Wenn `true`, teilen sich die ersten beiden Namen einen Nachnamen.
    ///     Romane leben von Verwandtschaft; ohne diese Möglichkeit bekäme jede Figur einen
    ///     eigenen Familiennamen, was künstlich wirkt.
    static func namen(anzahl: Int, gesperrt: Set<String>, streuung: UUID,
                      eineFamilie: Bool = true) -> [Vorschlag] {
        guard anzahl > 0 else { return [] }

        // KOMBINATORISCH, NICHT PAARWEISE.
        //
        // Der vorhandene `freieFigurennamen` paarte Vorname i mit Nachname (i % n) und
        // erzeugte damit aus 88 Vornamen und 80 Nachnamen ganze 88 Namen – ein Vorrat, der
        // nach wenigen Büchern erschöpft ist. Innerhalb einer Region kombiniert ergeben
        // dieselben Listen rund 900 Namen, über alle Regionen mehrere Tausend.
        //
        // Kombiniert wird bewusst NUR innerhalb einer Region: „Hauke Kowalczyk" liest sich
        // falsch. Die Region wird je Buch gewählt, damit nicht jedes Buch dieselbe
        // Mischung hat.
        var frei = gesperrt
        var ergebnis: [Vorschlag] = []
        var familienname: String?

        let raeume = StoryMemory.namensraeume
        guard !raeume.isEmpty else { return [] }

        // Deterministische, aber je Buch verschiedene Startposition.
        let seed = stabilerSeed(streuung)
        let raumStart = seed % raeume.count

        for versatz in 0..<raeume.count {
            let raum = raeume[(raumStart + versatz) % raeume.count]
            guard !raum.vornamen.isEmpty, !raum.nachnamen.isEmpty else { continue }
            let nStart = (seed / 7) % raum.nachnamen.count

            // Rollenensembles koennen ueberwiegend weiblich oder maennlich sein. Eine
            // zufaellige Folge von sechs Vornamen lieferte im echten Wiederaufnahmetest
            // nur zwei passende Frauennamen und machte jede sichere Zuordnung unmoeglich.
            // Deshalb wird der Pool stabil abwechselnd aus beiden Gruppen aufgebaut.
            let women = raum.vornamen.filter { geschlecht(vonVorname: $0) == .weiblich }
            let men = raum.vornamen.filter { geschlecht(vonVorname: $0) == .maennlich }
            guard !women.isEmpty, !men.isEmpty else { continue }
            let womenStart = seed % women.count
            let menStart = (seed / 11) % men.count
            let rotatedWomen = Array(women[womenStart...] + women[..<womenStart])
            let rotatedMen = Array(men[menStart...] + men[..<menStart])
            let startsWithWomen = seed.isMultiple(of: 2)
            var orderedFirstNames: [String] = []
            for index in 0..<max(rotatedWomen.count, rotatedMen.count) {
                let groups = startsWithWomen
                    ? [rotatedWomen, rotatedMen]
                    : [rotatedMen, rotatedWomen]
                for group in groups where group.indices.contains(index) {
                    orderedFirstNames.append(group[index])
                }
            }

            for (vi, vorname) in orderedFirstNames.enumerated() {
                guard istFrei(vorname, in: frei) else { continue }

                // Zweite Figur der Familie: Nachname wird geteilt.
                if eineFamilie, ergebnis.count == 1, let fam = familienname {
                    frei.formUnion(teile(vorname))
                    ergebnis.append(Vorschlag(vorname: vorname, nachname: fam,
                                              region: raum.region))
                    if ergebnis.count == anzahl { return ergebnis }
                    continue
                }

                var gewaehlt: String?
                for ni in 0..<raum.nachnamen.count {
                    let nachname = raum.nachnamen[(nStart + vi + ni) % raum.nachnamen.count]
                    if istFrei(nachname, in: frei) { gewaehlt = nachname; break }
                }
                guard let nachname = gewaehlt else { continue }

                frei.formUnion(teile(vorname))
                frei.formUnion(teile(nachname))
                if ergebnis.isEmpty { familienname = nachname }
                ergebnis.append(Vorschlag(vorname: vorname, nachname: nachname,
                                          region: raum.region))
                if ergebnis.count == anzahl { return ergebnis }
            }
        }
        return ergebnis
    }

    /// UUID-Seed ohne `hashValue`: Swift randomisiert Hashes pro Prozess. Der bisherige
    /// Seed lieferte demselben Projekt nach jedem App-Neustart andere Figurennamen.
    static func stabilerSeed(_ uuid: UUID) -> Int {
        let compact = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        return Int(compact.prefix(15), radix: 16) ?? 0
    }

    /// Der Block für den Figuren-Prompt.
    ///
    /// Bewusst als Vorgabe formuliert, nicht als Vorschlag: Ein „du kannst diese Namen
    /// verwenden" wird zuverlässig ignoriert, sobald das Modell einen Lieblingsnamen im
    /// Sinn hat. Deshalb steht auch die Begründung dabei – Modelle befolgen begründete
    /// Vorgaben messbar zuverlässiger als nackte Verbote.
    static func promptBlock(_ vorschlaege: [Vorschlag]) -> String {
        guard !vorschlaege.isEmpty else { return "" }
        let liste = vorschlaege.map {
            "- \($0.voll) [\($0.geschlecht.promptLabel)]"
        }.joined(separator: "\n")
        return """

        FIGURENNAMEN – VERBINDLICH VORGEGEBEN:
        \(liste)

        Verwende ausschließlich Namen aus dieser Liste und ordne sie geschlechts- und
        rollenpassend zu. Erfinde keine eigenen Namen und ändere keinen Buchstaben.

        Warum das festgelegt ist: In diesem Verlagsprogramm sind bereits Bücher erschienen.
        Frei erfundene Namen wiederholen sich zwangsläufig, und ein Leser, der zwei Titel
        kauft, findet dieselben Figuren wieder. Diese Namen sind katalogweit geprüft und
        noch nie verwendet worden.
        """
    }

    static func geschlecht(vonVorname vorname: String) -> Geschlecht {
        let normalized = vorname.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        ).lowercased()
        return weiblicheVornamen.contains(normalized) ? .weiblich : .maennlich
    }

    static func geschlecht(vonRolle role: String, beruf: String) -> Geschlecht {
        let text = "\(role) \(beruf)".folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        ).lowercased()
        let femaleMarkers = [
            "protagonistin", "antagonistin", "schwester", "mutter", "tochter",
            "ehefrau", "freundin", "frau", "weiblich"
        ]
        if femaleMarkers.contains(where: text.contains) { return .weiblich }
        let words = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if words.contains(where: {
            $0.count >= 6 && $0 != "berlin"
                && ($0.hasSuffix("erin") || $0.hasSuffix("lerin") || $0.hasSuffix("in"))
        }) { return .weiblich }
        let maleMarkers = [
            "protagonist", "antagonist", "bruder", "vater", "sohn", "ehemann",
            "freund", "mann", "maennlich", "männlich"
        ]
        if maleMarkers.contains(where: text.contains) { return .maennlich }
        if words.contains(where: { word in
            word.count >= 5 && ["mann", "meister", "ator", "eur", "iker", "ler", "ner", "er"]
                .contains(where: { word.hasSuffix($0) })
        }) { return .maennlich }
        return .unbekannt
    }

    static func geschlechtsgerechteErsetzungen(
        candidateNames: [String],
        rolesByName: [String: String],
        occupationsByName: [String: String],
        requiredNames: [String],
        assigned: [Vorschlag]
    ) -> [String: String]? {
        let unauthorized = Set(CharacterCanonAudit.unauthorizedSupplementaryNames(
            candidateNames: candidateNames,
            requiredNames: requiredNames,
            assignedSupplementaryNames: assigned.map(\.voll)
        ).map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
        })
        let assignedByName = Dictionary(uniqueKeysWithValues: assigned.map {
            ($0.voll.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased(), $0)
        })

        var needsReplacement: [(name: String, gender: Geschlecht)] = []
        var correctlyUsed = Set<String>()
        for name in candidateNames {
            let exact = name.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased()
            let wanted = geschlecht(
                vonRolle: rolesByName[name] ?? "",
                beruf: occupationsByName[name] ?? ""
            )
            if unauthorized.contains(exact) {
                needsReplacement.append((name, wanted))
            } else if let proposal = assignedByName[exact],
                      wanted != .unbekannt, proposal.geschlecht != wanted {
                needsReplacement.append((name, wanted))
            } else if assignedByName[exact] != nil {
                correctlyUsed.insert(exact)
            }
        }
        guard !needsReplacement.isEmpty else { return [:] }

        var available = assigned.filter {
            !correctlyUsed.contains($0.voll.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased())
        }
        var replacements: [String: String] = [:]
        for (oldName, wanted) in needsReplacement {
            let index = available.firstIndex {
                wanted == .unbekannt || $0.geschlecht == wanted
            }
            guard let index else { return nil }
            replacements[oldName] = available.remove(at: index).voll
        }
        return replacements
    }

    private static let weiblicheVornamen: Set<String> = [
        "adelgunde", "adlgunde", "agathe", "agnieszka", "ailke", "alicja", "aloisia", "almut",
        "amalie", "anezka", "anke", "anneliese", "antje", "arzu", "ayla", "aylin",
        "barbl", "beatrice",
        "bianca", "bilge", "bogumila", "bozena", "bronislawa", "burgl", "cansu",
        "cacilia", "cecilia", "cecylia", "celina", "cemile", "ceyda", "cilli", "cinzia",
        "concetta", "cordula", "dana", "daniela", "danuta", "derya", "dietlinde",
        "doortje", "doris", "dorota", "ebru", "edeltraud", "elfriede", "elif", "esra",
        "eliska", "elvira", "elzbieta", "eugenia", "fanny", "federica", "feliksa",
        "filiz", "fiorella", "florentine", "franziska", "frauke", "fridolina",
        "gabriela", "gamze", "gepke", "gerlind", "gerlinde", "gesa", "genowefa",
        "giuliana", "grazyna", "graziella", "gretl", "gudrun", "gundl", "halina",
        "handan", "hanka", "hedwig", "helga", "hilde", "hilke", "hermine", "hulya",
        "ilaria", "ilse", "imke", "ingeborg", "insa", "irena", "irmgard", "irmi",
        "irmtraud", "ivana", "jadwiga", "jale", "johanna", "jolanta", "josefa",
        "julide", "justina", "kamila", "karin", "karla", "klara", "kreszenz",
        "krystyna", "kunigunde", "kveta", "lale", "leopoldine", "leyla", "libuse",
        "lieselotte", "liska", "loredana", "ludmilla", "malgorzata", "marika",
        "mariella", "marlies", "marta", "marisa", "mechthild", "meike", "melike",
        "meltem", "monika", "nadezda", "nandl", "nantke", "natalina", "nergis",
        "nicoletta", "nilufer", "notburga", "ornella", "ottilie", "otylia", "patrizia",
        "paula", "pauline", "pavla", "peike", "perchta", "perihan", "pinar", "priska",
        "raffaella", "regina", "reinhild", "renata", "renate", "resl", "rita", "rosa",
        "rosalba", "roswitha", "ruya", "ruzena", "sabina", "sanne", "sevda", "sibylle",
        "sieglinde", "sigrun", "silke", "silvana", "swantje", "teresa", "tereza",
        "theresa", "thekla", "theodolinde", "tiziana", "traudl", "trude", "tugce",
        "ulku", "ulrike", "ursel", "urszula", "vincenza", "vroni", "waltraud",
        "waltraut", "wanda", "wiebke", "yasemin", "ynke", "zehra", "zdenka",
        "zenzi", "zeynep", "zita", "zofia", "zuzanna", "anne"
    ]

    // MARK: - Intern

    private static func istFrei(_ name: String, in gesperrt: Set<String>) -> Bool {
        StoryMemory.namensKollisionen([name], vergeben: gesperrt).isEmpty
    }

    private static func teile(_ name: String) -> Set<String> {
        Set(CharacterCanonAudit.nameParts(name))
    }
}
