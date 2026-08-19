import Foundation

struct StoryMemoryEntry: Codable, Equatable {
    let title: String
    let genre: String
    let premise: String
    let structure: String

    init(title: String, genre: String, premise: String, structure: String = "") {
        self.title = title
        self.genre = genre
        self.premise = premise
        self.structure = structure
    }
}

enum StoryMemory {
    /// Laufzeitregister fuer parallel erzeugte Buchideen. Die Datenbank allein ist
    /// hier zu spaet: Waehren ein Worker seine Idee noch verarbeitet, koennte ein
    /// zweiter dieselbe Praemisse unter einem anderen Titel auswaehlen.
    struct StoryIdeaRegistry {
        private var reservations: [StoryMemoryEntry] = []

        mutating func claim(_ idea: ParsedIdea,
                            existing: [StoryMemoryEntry],
                            persisted: [StoryMemoryEntry]) -> Bool {
            let unavailable = existing + persisted + reservations
            guard !StoryMemory.isLikelyDuplicate(idea, existing: unavailable) else {
                return false
            }
            reservations.append(
                StoryMemoryEntry(
                    title: idea.title,
                    genre: idea.genre,
                    premise: idea.premise
                )
            )
            return true
        }
    }

    static func persistedNameParts(in claims: [String: [String]],
                                   excluding projectID: UUID) -> Set<String> {
        var result = Set<String>()
        for (owner, parts) in claims where owner != projectID.uuidString {
            result.formUnion(parts)
        }
        return result
    }

    /// Laufzeitregister fuer parallele Buch-Worker. SwiftData enthaelt einen Namen erst,
    /// nachdem das Figurenensemble gespeichert wurde; waehrend zwei Modellantworten
    /// gleichzeitig unterwegs sind, reicht ein Datenbankabgleich deshalb nicht aus.
    /// Das Register reserviert Namen auf dem MainActor bereits vor dem Speichern.
    struct CatalogNameRegistry {
        private var reservations: [UUID: Set<String>] = [:]

        mutating func blocked(projects: [Project], persisted: Set<String> = [],
                              for projectID: UUID) -> Set<String> {
            var result = StoryMemory.vergebeneNamensteile(
                projects: projects, excluding: projectID
            )
            // Der unverlierbare Boden: Namen, die das Modell nachweislich immer wieder
            // wählt. Ohne ihn hängt das Gedächtnis allein an der Datenbank – und ist nach
            // einem Zurücksetzen weg.
            result.formUnion(StoryMemory.verbrauchteNamen)
            result.formUnion(persisted)
            for (owner, parts) in reservations where owner != projectID {
                result.formUnion(parts)
            }
            return result
        }

        /// Atomischer Claim: leer bedeutet erfolgreich. Eigene fruehere Claims werden
        /// ausgeblendet, damit Primaerkanon und spaeteres Ensemble denselben Namen
        /// erneut bestaetigen duerfen.
        mutating func reserve(_ names: [String], projects: [Project],
                              persisted: Set<String> = [],
                              for projectID: UUID,
                              grandfatheredNames: [String] = []) -> [String] {
            let unavailable = StoryMemory.forbiddenNamePartsForCanonCheck(
                blocked(
                projects: projects, persisted: persisted, for: projectID
                ),
                establishedNames: grandfatheredNames,
                hasWrittenProse: !grandfatheredNames.isEmpty
            )
            let collisions = StoryMemory.namensKollisionen(names, vergeben: unavailable)
            guard collisions.isEmpty else { return collisions }
            reservations[projectID, default: []].formUnion(
                names.flatMap(CharacterCanonAudit.nameParts)
            )
            return []
        }
    }

    /// Alle in früheren Büchern vergebenen Namensteile – zur harten Prüfung.
    /// Die Sperre gilt katalogweit und liest auch den tatsächlichen Buchtext. Dadurch
    /// bleiben Namen gesperrt, wenn eine alte oder beschädigte Story Bible vom Manuskript
    /// abweicht. Eine zeitliche Grenze wäre hier Datenverlust: Ein Name wird nie wieder frei.
    /// Namen, die das Modell nachweislich immer wieder verwendet – dauerhaft gesperrt.
    ///
    /// **Warum das fest im Code steht und nicht in der Datenbank.** Die Namenssperre las
    /// bisher ausschließlich aus den gespeicherten Projekten. Wird die Datenbank geleert
    /// (am 09.08.2026 geschehen), ist das gesamte Gedächtnis weg – und das Modell greift
    /// sofort wieder zu denselben Namen. Genau das ist am 10.08. passiert: Der frische
    /// Plot hieß wieder „Liv" und „Voss".
    ///
    /// **Gemessen** an 35 ausgelieferten Büchern (5,9 Mio. Wörter, Vorkommen mitten im
    /// Satz, mindestens 25-mal je Buch):
    ///
    /// | Name | in Büchern |
    /// |---|---|
    /// | Mira, Brenner, Voss, Jonas | je **14 von 35** |
    /// | Finn | 5 |
    /// | Liv | 4 |
    /// | Elias, Lena, Weber, Falk | je 3 |
    ///
    /// Vier Namen in 40 % aller Bücher: Für einen Leser, der zwei Titel kauft, ist das
    /// derselbe Autor mit denselben Figuren. Die Liste hier ist der Boden, auf den die
    /// Projektsperre aufsetzt – sie kann nicht verlorengehen.
    ///
    /// Gesperrt wird der Namensteil; `namensKollisionen` sperrt zusätzlich den Klangkern,
    /// sodass auch „Mirja" oder „Vossberg" nicht durchrutschen.
    static let verbrauchteNamen: Set<String> = [
        // 14 von 35 Büchern
        "mira", "brenner", "voss", "jonas",
        // 3 bis 5 Bücher
        "finn", "liv", "elias", "lena", "weber", "falk",
        // Aus der früheren Messung über sechs Bücher, weiterhin gesperrt
        "naja", "aksel", "freja", "erik", "thomas",
        // Ungeeignet als unauffaelliger Nebenfigurenname; im Live-Plan klang
        // "Blumenlieferant Broesel" wie eine Karikatur statt wie eine reale Person.
        "brösel",
    ]

    static func vergebeneNamensteile(projects: [Project], excluding projectID: UUID) -> Set<String> {
        var namen = Set<String>()
        for project in projects where project.id != projectID {
            let bibleNames = (project.storyBible?.characters ?? []).map(\.name)
            var narrativeTexts = [
                project.bookProfile?.premise ?? "",
                project.bookProfile?.logline ?? "",
                project.bookProfile?.synopsis ?? "",
                project.storyBible?.plotPoints ?? ""
            ]
            for chapter in project.chapters ?? [] {
                narrativeTexts.append(chapter.rawBestText ?? "")
                narrativeTexts.append(chapter.summary ?? "")
                narrativeTexts.append(contentsOf: (chapter.scenes ?? []).compactMap(\.summary))
            }
            namen.formUnion(CharacterCanonAudit.catalogNameParts(
                bibleNames: bibleNames, narrativeTexts: narrativeTexts
            ))
        }
        return namen
    }

    /// Catalog rules are prospective. Once prose exists, the book's established
    /// canonical names must remain valid even if a later app version adds one of
    /// them to the global reuse blocklist. Other blocked names stay unavailable.
    static func forbiddenNamePartsForCanonCheck(
        _ forbidden: Set<String>,
        establishedNames: [String],
        hasWrittenProse: Bool
    ) -> Set<String> {
        guard hasWrittenProse else { return forbidden }
        let ownParts = Set(establishedNames.flatMap(CharacterCanonAudit.nameParts))
        return forbidden.subtracting(ownParts)
    }

    /// Welche der neuen Figurennamen kollidieren mit früheren Büchern?
    /// Reduziert einen Namen auf seinen Klangkern: Lena, Leni und Lina werden zu „len"
    /// bzw. „lin" – nah genug, dass ein Leser sie verwechselt. Ohne diese Normalisierung
    /// galten sie als drei verschiedene Namen und standen alle drei in den Büchern.
    private static func namensKern(_ n: String) -> String {
        // Gefaltet wie in `CharacterCanonAudit.nameParts` – siehe die Begründung in
        // `namensKollisionen`. Die manuelle Umlautersetzung weiter unten bleibt für die
        // Fälle, die das Falten nicht abdeckt (ck/tz).
        var k = n.folding(options: [.diacriticInsensitive, .caseInsensitive],
                          locale: .current).lowercased()
        // Endungen abschneiden, die nur flektieren oder verkleinern.
        for endung in ["chen", "lein", "a", "e", "i", "o", "y"] {
            if k.count > 3, k.hasSuffix(endung) {
                k = String(k.dropLast(endung.count))
                break
            }
        }
        // Umlaute und Doppelkonsonanten angleichen.
        k = k.replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ck", with: "k")
            .replacingOccurrences(of: "tz", with: "z")
        return String(k.prefix(4))
    }

    static func namensKollisionen(_ neueNamen: [String], vergeben: Set<String>) -> [String] {
        // Auch die Klangkerne der vergebenen Namen sperren.
        let vergebeneKerne = Set(vergeben.map(namensKern))
        var treffer: [String] = []
        // Klangkern → der Namensteil, der ihn belegt hat. Als Menge reichte es nicht:
        // siehe die Familien-Ausnahme weiter unten.
        var imBuch: [String: String] = [:]
        for name in neueNamen {
            for teil in name.split(separator: " ") {
                // DIAKRITIKA FALTEN – sonst greift die Sperre ins Leere.
                //
                // `CharacterCanonAudit.nameParts` speichert gefaltet („grażyna" wird zu
                // „grazyna"), diese Prüfung verglich aber ungefaltet. Ein Name mit ż, ł, ç
                // oder ş konnte deshalb ein zweites Mal vergeben werden: In der Simulation
                // über 60 Bücher trat genau das bei „Grażyna" auf. Beide Seiten müssen
                // dieselbe Schreibweise vergleichen.
                let n = String(teil)
                    .folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: .current)
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet.letters.inverted)
                guard n.count >= 3 else { continue }
                let kern = namensKern(n)
                if vergeben.contains(n) {
                    treffer.append("\(name) (\"\(teil)\" schon vergeben)")
                    break
                }
                // Klangvariante eines Namens aus einem früheren Buch.
                if kern.count >= 3, vergebeneKerne.contains(kern) {
                    treffer.append("\(name) (\"\(teil)\" klingt wie ein bereits vergebener Name)")
                    break
                }
                // Zwei ähnliche Namen im SELBEN Buch (Lena und Leni nebeneinander).
                //
                // ABER: Ein IDENTISCHER Namensteil ist keine Verwechslung. Er bedeutet
                // eine Familie – oder dieselbe Figur einmal mit und einmal ohne Vornamen.
                //
                // Ohne diese Ausnahme war das eine Falle ohne Ausgang, gemessen an der
                // Produktion vom 10.08.2026: Der Plot hatte „Alva Voss" und „Henning Voss",
                // Tochter und Vater. Die Prüfung meldete den geteilten Nachnamen als
                // Kollision, die Reparatur benannte ihn um – auf BEIDE, denn sie ersetzt
                // Namensteile im ganzen Kanon – und dieselbe Prüfung schlug erneut an, jetzt
                // wegen „Falkenrath". `sichereNamensErsetzungen` gab daraufhin nil zurück,
                // und die Strukturplanung warf. Zwei Figuren mit gemeinsamem Nachnamen
                // waren damit unmöglich; in einem Roman ist das keine Randerscheinung,
                // sondern der Normalfall.
                //
                // Verglichen wird deshalb der TEIL, nicht nur sein Klangkern: „Voss" neben
                // „Voss" ist eine Familie und erlaubt, „Lena" neben „Leni" bleibt ein
                // Befund.
                if kern.count >= 3, let belegtVon = imBuch[kern], belegtVon != n {
                    treffer.append("\(name) (\"\(teil)\" klingt wie eine andere Figur dieses Buchs)")
                    break
                }
                imBuch[kern] = n
            }
        }
        return treffer
    }

    /// Ein Namensraum pro Buch – regional stimmig, über Bücher hinweg rotierend.
    ///
    /// Gemessen über acht Bücher: „Brenner" fünfmal, „Kessler" und „Voss" je viermal,
    /// dazu Lena/Leni/Lina als praktisch derselbe Vorname und zehn von 41 Vornamen mit
    /// M oder L. Das Modell greift ohne Gegendruck immer in denselben engen Namensraum.
    ///
    /// Statt zu bitten wird hier vorgegeben: Jedes Buch bekommt EINE Region zugewiesen,
    /// die mit dem Buchindex rotiert. Das Ensemble bleibt dadurch stimmig – niemand heißt
    /// Björn Kowalski – und zwei aufeinanderfolgende Bücher klingen völlig verschieden.
    struct Namensraum {
        let region: String
        let vornamen: [String]
        let nachnamen: [String]
    }

    static let namensraeume: [Namensraum] = [
        Namensraum(region: "norddeutsch/friesisch",
                   vornamen: ["Anke", "Hauke", "Wiebke", "Tede", "Insa", "Onno", "Frauke", "Broder", "Silke", "Ubbo", "Antje", "Momme", "Enno", "Almut", "Fiete", "Gesa", "Habbo", "Imke", "Jelto", "Karla", "Lammert", "Meike", "Nanne", "Okko", "Peike", "Reemt", "Sanne", "Thies", "Uke", "Volkert", "Wilke", "Ynke", "Bendix", "Doortje", "Eddo", "Gepke", "Hilke", "Jorik", "Lubbe", "Nantke", "Ailke", "Bohle", "Detlev", "Eelke", "Focke", "Gerke", "Harke", "Ihno", "Jann", "Klaas", "Menno", "Nomme", "Oke", "Poppo", "Renke", "Swantje", "Tjark", "Ulfert", "Weert"],
                   nachnamen: ["Jansen", "Petersen", "Boysen", "Harms", "Tammen", "Ubben", "Focken", "Renken", "Siemens", "Alberts", "Cassens", "Dirks", "Eilers", "Fokken", "Gerdes", "Hinrichs", "Koopmann", "Lüders", "Mennen", "Onnen", "Poppen", "Saathoff", "Tjarks", "Weerts", "Ahrens", "Bruhns", "Cordsen", "Dethlefs", "Eggers", "Freese", "Grewe", "Hamkens", "Iben", "Jarchow", "Kruse", "Lorenzen", "Mommsen", "Nissen", "Ohlsen", "Paulsen", "Reimers", "Stührk", "Thordsen", "Wiese"]),
        Namensraum(region: "süddeutsch/bayerisch",
                   vornamen: ["Korbinian", "Theresa", "Ludwig", "Kreszenz", "Sepp", "Anneliese", "Alois", "Burgl", "Xaver", "Rosa", "Benedikt", "Vroni", "Quirin", "Fanny", "Hansjörg", "Zenzi", "Lorenz", "Bartl", "Cilli", "Dominikus", "Emmeram", "Fridolin", "Gundl", "Hias", "Irmi", "Jakobus", "Kilian", "Loisl", "Nandl", "Otmar", "Pankraz", "Resl", "Simmerl", "Tassilo", "Urban", "Wastl", "Zeno", "Gretl", "Michl", "Barbl", "Adlgunde", "Bastl", "Damian", "Eusebius", "Ferdl", "Gebhard", "Hilde", "Ignatz", "Justina", "Kajetan", "Leonhardt", "Monika", "Nepomuk", "Odilo", "Priska", "Rudl", "Sixtus", "Wolfram"],
                   nachnamen: ["Huber", "Obermeier", "Wimmer", "Grasegger", "Zehentner", "Riedl", "Stadlbauer", "Kirchmeier", "Prantl", "Brandlhuber", "Dengler", "Eberl", "Feichtner", "Gschwendtner", "Hinterseer", "Jobst", "Kandler", "Lackner", "Mühlbauer", "Pfaffinger", "Rottensteiner", "Sailer", "Trenkwalder", "Achleitner", "Baumgartner", "Christl", "Daxenberger", "Egglhuber", "Fuchsberger", "Hausladen", "Innerhofer", "Kroneder", "Lindinger", "Moosleitner", "Neumaier", "Osterhammer", "Pointner", "Rauscher", "Schmalzl", "Trostberger", "Waldherr", "Zauner"]),
        Namensraum(region: "österreichisch",
                   vornamen: ["Elfriede", "Ferdinand", "Traudl", "Gottfried", "Notburga", "Sieglinde", "Heimo", "Waltraud", "Egon", "Roswitha", "Adelheid", "Bartholomäus", "Cäcilia", "Dietmar", "Engelbert", "Gerlinde", "Hermine", "Ignaz", "Josefa", "Konradin", "Leopoldine", "Maximiliane", "Oswald", "Perchta", "Reinhold", "Sigrun", "Theodolinde", "Ulrike", "Valentin", "Wolfhard", "Amalie", "Benno", "Dagobert", "Edeltraud", "Fridolina", "Gunthard", "Aloisia", "Balthasar", "Christoph", "Dietlinde", "Emmerich", "Florentine", "Hubertus", "Irmtraud", "Johanna", "Klemens", "Ludmilla", "Melchior", "Ottokar", "Pauline", "Rupert", "Severin", "Thekla", "Vinzenz"],
                   nachnamen: ["Kranebitter", "Gruber", "Pichler", "Steinlechner", "Moosbrugger", "Zöhrer", "Hinterleitner", "Praschl", "Wieser", "Tanzer", "Aigner", "Brandstätter", "Danzinger", "Ebenbauer", "Feldkircher", "Grillmeier", "Hollersbacher", "Kirchgassner", "Lassnig", "Mitterhofer", "Oberrauch", "Puchleitner", "Schwaighofer", "Windisch", "Amerhauser", "Berghammer", "Chalupka", "Dorfinger", "Eibensteiner", "Fankhauser", "Gschwandtner", "Haselwanter", "Innauer", "Jandl", "Kaltenegger", "Leitgeb", "Muhr", "Nachbaur", "Ortner", "Payrleitner", "Rammel", "Stolz", "Thurnher", "Waldner"]),
        Namensraum(region: "rheinisch/westdeutsch",
                   vornamen: ["Änne", "Willi", "Marlies", "Hubert", "Gudrun", "Norbert", "Irmgard", "Detlef", "Rita", "Manfred", "Karin", "Achim", "Trude", "Bertram", "Christa", "Dietrich", "Elke", "Friedhelm", "Heinz", "Ingeborg", "Josef", "Klara", "Lieselotte", "Matthias", "Nikolaus", "Ottilie", "Peter", "Renate", "Siegfried", "Ursel", "Volker", "Waltraut", "Adelgunde", "Bodo", "Cordula", "Dieter", "Gustav", "Agathe", "Clemens", "Doris", "Eberhard", "Franziska", "Godehard", "Helga", "Ilse", "Jost", "Kunigunde", "Ludger", "Mechthild", "Norwin", "Oswin", "Paula", "Reinhild", "Sibylle", "Tilman", "Wendelin"],
                   nachnamen: ["Schlüter", "Bergmann", "Kremer", "Lennartz", "Odenthal", "Küppers", "Winkelmann", "Dahlmann", "Reuter", "Esser", "Sprenger", "Bültmann", "Cremers", "Deckers", "Effertz", "Frielinghaus", "Gierlich", "Hackenbroich", "Jülich", "Kaltenbach", "Lövenich", "Mombauer", "Nettesheim", "Overath", "Bongartz", "Comes", "Dohmen", "Engels", "Frangenberg", "Gilles", "Hommelsheim", "Jakobs", "Kirfel", "Lövenbruck", "Mertens", "Nolden", "Ophoven", "Pesch", "Quirmbach", "Röttgen", "Schallenberg", "Thelen", "Voigtlaender", "Wirtz"]),
        Namensraum(region: "ostdeutsch/sorbisch",
                   vornamen: ["Wenzel", "Hanka", "Bogumil", "Mirko", "Jadwiga", "Ondrej", "Liska", "Radomir", "Zuzanna", "Milan", "Bogumila", "Cyril", "Dobromir", "Elzbieta", "Feliks", "Gerlind", "Havel", "Ilja", "Jaromir", "Kveta", "Ladislav", "Marika", "Nikodem", "Olek", "Pavla", "Radek", "Slavomir", "Tomasz", "Urszula", "Vaclav", "Wojciech", "Zdenka", "Bronislaw", "Dana", "Emil", "Hedwig", "Iwo", "Anezka", "Bozena", "Ctirad", "Eliska", "Frantisek", "Hynek", "Ivana", "Jindrich", "Kamila", "Libuse", "Marta", "Nadezda", "Otokar", "Premysl", "Ruzena", "Stepan", "Tereza", "Vojtech"],
                   nachnamen: ["Nowotny", "Wjenka", "Schade", "Kubitz", "Nawka", "Lehmann", "Brösel", "Krautschick", "Zschornack", "Meschke", "Bartusch", "Cyrus", "Domaschke", "Erdmann", "Franke", "Gerlach", "Hantusch", "Jurk", "Kliem", "Lorenz", "Michalk", "Nuck", "Pietsch", "Ryba", "Barthel", "Czorny", "Domin", "Eichler", "Fiedler", "Gruhle", "Hentschel", "Jentsch", "Kaulfuss", "Liebscher", "Mattick", "Noack", "Petrick", "Quilitzsch", "Rösler", "Sczepanski", "Tzschoppe", "Urbaniak", "Wagner", "Zieschang"]),
        Namensraum(region: "türkisch-deutsch",
                   vornamen: ["Yusuf", "Nilüfer", "Emre", "Zeynep", "Kerem", "Hülya", "Selim", "Ayla", "Baran", "Esra", "Cem", "Meltem", "Aylin", "Berk", "Ceyda", "Deniz", "Ebru", "Ferhat", "Gamze", "Hakan", "Ilkay", "Jale", "Kaan", "Leyla", "Murat", "Nergis", "Okan", "Pinar", "Rüya", "Sinan", "Tugce", "Umut", "Volkan", "Yasemin", "Zehra", "Aras", "Bilge", "Cansu", "Devrim", "Elif", "Arzu", "Bora", "Cemile", "Derya", "Efe", "Filiz", "Gökhan", "Handan", "Ismail", "Julide", "Kudret", "Lale", "Melike", "Nihat", "Orhan", "Perihan", "Rasim", "Sevda", "Tarik", "Ülkü"],
                   nachnamen: ["Özdemir", "Yildirim", "Arslan", "Çelik", "Doğan", "Kurtuluş", "Erdoğan", "Şahin", "Aydın", "Toprak", "Bozkurt", "Çetin", "Demirci", "Ekinci", "Firat", "Güneş", "Halıcı", "Işık", "Kaplan", "Levent", "Menekşe", "Ocak", "Polat", "Sarıkaya", "Akbulut", "Balaban", "Cengiz", "Dinçer", "Ergün", "Fidan", "Gökmen", "Hancı", "Ilhan", "Karabulut", "Limoncu", "Mutlu", "Nazlı", "Öztürk", "Pekcan", "Sezgin", "Tunç", "Uçar", "Yalçın", "Zorlu"]),
        Namensraum(region: "polnisch-deutsch",
                   vornamen: ["Bogdan", "Halina", "Kazimierz", "Wanda", "Tadeusz", "Jolanta", "Marek", "Grażyna", "Zbigniew", "Danuta", "Agnieszka", "Bartosz", "Cecylia", "Dariusz", "Eugenia", "Franciszek", "Genowefa", "Henryk", "Irena", "Janusz", "Krystyna", "Leszek", "Malgorzata", "Otylia", "Przemyslaw", "Regina", "Stanislaw", "Teresa", "Waldemar", "Zofia", "Alicja", "Bronislawa", "Czeslaw", "Dorota", "Edward", "Gabriela", "Aleksy", "Celina", "Feliksa", "Gustaw", "Ignacy", "Kornel", "Lucjan", "Marceli", "Olgierd", "Placyd", "Sabina", "Tytus", "Wladyslaw"],
                   nachnamen: ["Wiśniewski", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski", "Kozłowski", "Jankowski", "Mazur", "Adamczyk", "Baranowski", "Cieslak", "Duda", "Gorski", "Jasinski", "Kaczmarek", "Laskowski", "Michalak", "Nowicki", "Pawlak", "Rutkowski", "Sikora", "Walczak", "Bielawski", "Chmielewski", "Domagala", "Fabisiak", "Grabowski", "Iwanski", "Jablonski", "Kubiak", "Lisowski", "Madej", "Nowakowski", "Olszewski", "Piotrowski", "Roszak", "Sobczak", "Tomaszewski", "Wojcik", "Zaremba", "Bak", "Czapla"]),
        Namensraum(region: "italienisch-deutsch",
                   vornamen: ["Fiorella", "Ennio", "Concetta", "Battista", "Marisa", "Silvio", "Rosalba", "Dario", "Ornella", "Fabrizio", "Agostino", "Bianca", "Calogero", "Donatella", "Emiliano", "Federica", "Gennaro", "Ilaria", "Leandro", "Mariella", "Nicoletta", "Osvaldo", "Patrizia", "Quirino", "Renata", "Salvatore", "Tiziana", "Ugo", "Vincenza", "Zaccaria", "Adriana", "Bruno", "Cinzia", "Domenico", "Elvira", "Fulvio", "Giuliana", "Ippolito", "Amedeo", "Beatrice", "Cesare", "Daniela", "Ercole", "Fiorenzo", "Graziella", "Ilario", "Loredana", "Massimo", "Natalina", "Oreste", "Pierluigi", "Raffaella", "Silvana", "Tullio", "Umberto", "Valerio", "Zita", "Bernardo"],
                   nachnamen: ["Marchetti", "Bertolini", "Faccini", "Zanetti", "Lombardi", "Grimaldi", "Rinaldi", "Costanzo", "Fabbri", "Mancuso", "Alfieri", "Basile", "Cattaneo", "Danieli", "Esposito", "Ferraro", "Gagliardi", "Iacobelli", "Longhi", "Morandi", "Nicolosi", "Orlandi", "Pellegrini", "Ruggeri", "Amoroso", "Bellini", "Carducci", "Devoto", "Emiliani", "Fusaro", "Gandolfi", "Imperato", "Lanzoni", "Mascheroni", "Negrini", "Ottaviani", "Pisani", "Quaglia", "Rovelli", "Sartori", "Tessaro", "Ubaldi", "Venturi", "Zampieri"])
    ]

    /// Wählt den Namensraum für ein Buch – rotiert über die Bücherzahl.
    static func namensraum(fuerBuchNummer nummer: Int) -> Namensraum {
        namensraeume[abs(nummer) % namensraeume.count]
    }

    /// Briefing für die Figurenerzeugung: gibt Region UND konkrete freie Namen vor.
    ///
    /// Bewusst mit Vorschlägen statt nur einer Regel: „Nimm norddeutsche Namen" führt
    /// wieder zu Jansen und Petersen. Konkrete freie Namen aus dem Pool führen dahin,
    /// wo das Modell von allein nie hinkäme.
    static func namensraumBrief(fuerBuchNummer nummer: Int, vergeben: Set<String>) -> String {
        let raum = namensraum(fuerBuchNummer: nummer)
        let freieVor = raum.vornamen.filter { !vergeben.contains($0.lowercased()) }
        let freieNach = raum.nachnamen.filter { !vergeben.contains($0.lowercased()) }
        guard freieVor.count >= 3, freieNach.count >= 3 else { return "" }
        return """
        NAMENSRAUM DIESES BUCHS: \(raum.region).
        ALLE Figuren tragen Namen aus diesem Sprachraum – das Ensemble muss stimmig sein,
        keine Mischung aus verschiedenen Regionen.

        Nimm die Namen AUS DIESER LISTE (frei und in früheren Büchern nicht vergeben):
        Vornamen: \(freieVor.prefix(10).joined(separator: ", "))
        Nachnamen: \(freieNach.prefix(8).joined(separator: ", "))

        Kombiniere frei, aber erfinde keine eigenen Namen und weiche nicht auf gängigere aus.
        Achte darauf, dass keine zwei Figuren mit demselben Buchstaben beginnen und dass
        kein Vorname wie eine Variante eines anderen klingt (nicht Lena und Leni im selben Buch).
        """
    }

    /// Ersetzt kollidierende Namensteile deterministisch durch freie.
    ///
    /// Blockieren allein reicht nicht: Nach vier Fehlversuchen wurde der Name bisher
    /// akzeptiert, damit die Produktion nicht stehenbleibt – so kam „Kessler" trotz
    /// Sperre ein zweites Mal ins Buch. Statt zu blockieren ODER durchzuwinken wird
    /// der Name jetzt getauscht: Die Produktion läuft weiter UND der Name ist neu.
    static func ersetzeKollidierendeNamen(_ namen: [String],
                                          vergeben: Set<String>) -> [String: String] {
        // Bewusst breite, unverbrauchte Auswahl aus verschiedenen Sprachräumen.
        //
        // Die alte Liste enthielt „Falk" und „Jonas" – beide stehen in
        // `verbrauchteNamen`, gemessen in 3 bzw. 14 von 35 Büchern. Die Liste der
        // „sicheren Ersatznamen" speiste also genau die Wiederholung, gegen die sie
        // gebaut wurde. Beide sind entfernt.
        //
        // Von 16 auf 40 Vornamen und von 24 auf 44 Nachnamen erweitert: Bei 35 Büchern mit
        // je fünf bis acht Figuren war der alte Vorrat rechnerisch längst aufgebraucht,
        // und ein leerer Vorrat lässt `sichereNamensErsetzungen` nil zurückgeben – was die
        // Produktion beendet.
        let ersatzNachnamen = [
            "Falkenrath", "Reineke", "Ostwald", "Hagedorn", "Kirchner", "Lindqvist",
            "Marchetti", "Novak", "Petrosyan", "Quandt", "Rosenthal", "Steinbrück",
            "Tavares", "Uhlmann", "Varga", "Wendtland", "Ziegler", "Amrein",
            "Bergström", "Cordes", "Dahlmann", "Eichhorst", "Fontaine", "Grimberg",
            "Halvorsen", "Ibsen", "Jurczyk", "Kowalczyk", "Lauterbach", "Merz",
            "Nordhaus", "Obermeier", "Pflüger", "Reithmann", "Sandoval", "Thalmann",
            "Ursprung", "Vandenberg", "Wieland", "Zimmerli", "Achenbach", "Bruckner",
            "Castellan", "Duvalier"
        ]
        let ersatzVornamen = [
            "Juna", "Malte", "Roswitha", "Tobias", "Isolde", "Nele", "Bruno",
            "Xenia", "Konrad", "Marlene", "Anselm", "Thea", "Elvira", "Ruben",
            "Corinna", "Detlev", "Emilia", "Gero", "Hanna", "Ivo", "Jorinde",
            "Kasimir", "Lorena", "Mattis", "Norina", "Oskar", "Philippa", "Quirin",
            "Rosalie", "Servatius", "Tilda", "Ulrich", "Verena", "Wenzel", "Yvette",
            "Zeno", "Agneta", "Benedikt", "Cosima", "Dorian"
        ]
        var belegt = vergeben
        var belegteKerne = Set(vergeben.map(namensKern))
        var austausch: [String: String] = [:]
        // Namensteil (klein) → sein Ersatz. Hält Familien zusammen (siehe unten).
        var teilErsatz: [String: String] = [:]
        for name in namen {
            let teile = name.split(separator: " ").map(String.init)
            var neueTeile = teile
            var geaendert = false
            for (i, teil) in teile.enumerated() {
                let k = teil.lowercased().trimmingCharacters(in: CharacterSet.letters.inverted)
                guard k.count >= 3 else { continue }
                let kollidiert = belegt.contains(k) || belegteKerne.contains(namensKern(k))
                if !kollidiert {
                    belegt.insert(k)
                    belegteKerne.insert(namensKern(k))
                    continue
                }
                // DERSELBE NAMENSTEIL BEKOMMT IMMER DENSELBEN ERSATZ.
                //
                // Ohne diese Zeile zerreißt die Umbenennung Familien: „Alva Voss" wurde zu
                // „Alva Reineke" und „Henning Voss" zu „Henning Ostwald" – aus Vater und
                // Tochter wurden zwei Fremde, und jeder Verwandtschaftsbezug im Plot ging
                // ins Leere. Gemessen am echten Plot vom 10.08.2026.
                if let bereits = teilErsatz[k] {
                    neueTeile[i] = bereits
                    geaendert = true
                    continue
                }
                // Letzter Teil = Nachname, sonst Vorname.
                let quelle = (i == teile.count - 1 && teile.count > 1)
                    ? ersatzNachnamen : ersatzVornamen
                if let frei = quelle.first(where: {
                    let kandidat = $0.lowercased()
                    return !belegt.contains(kandidat)
                        && !belegteKerne.contains(namensKern(kandidat))
                }) {
                    neueTeile[i] = frei
                    teilErsatz[k] = frei
                    belegt.insert(frei.lowercased())
                    belegteKerne.insert(namensKern(frei))
                    geaendert = true
                }
            }
            if geaendert { austausch[name] = neueTeile.joined(separator: " ") }
        }
        return austausch
    }

    /// Liefert nur dann eine Ersatzabbildung, wenn danach wirklich kein exakter oder
    /// klangähnlicher Katalogtreffer mehr übrig ist. So kann dieselbe Abbildung auf
    /// Prämisse, Logline, Exposé, Plot und Figurenprofile angewandt werden.
    static func sichereNamensErsetzungen(_ namen: [String],
                                         vergeben: Set<String>) -> [String: String]? {
        guard !namen.isEmpty else { return [:] }
        let vorher = namensKollisionen(namen, vergeben: vergeben)
        guard !vorher.isEmpty else { return [:] }
        let austausch = ersetzeKollidierendeNamen(namen, vergeben: vergeben)
        guard !austausch.isEmpty else { return nil }
        let danach = namen.map {
            CharacterCanonAudit.replacingNames(in: $0, replacements: austausch)
        }
        return namensKollisionen(danach, vergeben: vergeben).isEmpty ? austausch : nil
    }

    /// Ersetzt einzelne, nichtkanonische Namensbestandteile in noch ungeschriebenen
    /// Szenenplaenen. Fuer "Lieferant Weber" wird bewusst nur ein freier Nachname
    /// geliefert; ein voller Personenname wuerde Grammatik und Rollenbezug beschaedigen.
    static func sichereSzenenplanNamensErsetzungen(_ namensteile: [String],
                                                   vergeben: Set<String>,
                                                   streuung: UUID) -> [String: String] {
        let collisions = Array(Set(namensteile.map {
            $0.trimmingCharacters(in: CharacterSet.letters.inverted).lowercased()
        }.filter { $0.count >= 3 })).sorted()
        guard !collisions.isEmpty else { return [:] }

        let neutralSurnames = [
            "Albrecht", "Berger", "Brandt", "Cordes", "Dahl", "Ebert",
            "Franke", "Gehring", "Hansen", "Heine", "Kramer", "Lorenz",
            "Martens", "Neumann", "Peters", "Riedel", "Schuster", "Seidel",
            "Thiele", "Winter",
        ]
        let start = NamensGenerator.stabilerSeed(streuung) % neutralSurnames.count
        let ordered = Array(neutralSurnames[start...] + neutralSurnames[..<start])
        var blocked = vergeben
        var replacements: [String: String] = [:]
        for collision in collisions {
            guard let replacement = ordered.first(where: {
                namensKollisionen([$0], vergeben: blocked).isEmpty
            }) else { return [:] }
            replacements[collision] = replacement
            blocked.formUnion(CharacterCanonAudit.nameParts(replacement))
        }
        return replacements
    }

    /// Deterministische, katalogweit freie Namen fuer die seltene Offline-/Format-
    /// Rueckfallebene. Jeder ausgewaehlte Namensteil wird sofort fuer die naechste
    /// Figur reserviert; dadurch entstehen auch innerhalb des Ensembles keine Doppelungen.
    static func freieFigurennamen(anzahl: Int, vergeben: Set<String>,
                                  reserviert: [String] = []) -> [String] {
        guard anzahl > 0 else { return [] }
        var blockiert = vergeben
        blockiert.formUnion(reserviert.flatMap(CharacterCanonAudit.nameParts))
        var ergebnis: [String] = []

        for raum in namensraeume {
            for (index, vorname) in raum.vornamen.enumerated() {
                guard !raum.nachnamen.isEmpty else { continue }
                let nachname = raum.nachnamen[index % raum.nachnamen.count]
                let kandidat = "\(vorname) \(nachname)"
                guard namensKollisionen([kandidat], vergeben: blockiert).isEmpty else { continue }
                ergebnis.append(kandidat)
                blockiert.formUnion(CharacterCanonAudit.nameParts(kandidat))
                if ergebnis.count == anzahl { return ergebnis }
            }
        }
        return ergebnis
    }

    /// Sperrt bereits vergebene Figurennamen UND das Kernmotiv der letzten Bücher.
    ///
    /// Gemessen über sechs Bücher: „Brenner" viermal, „Voss" dreimal, „Mira" und „Liv"
    /// je mehrfach – und vier Titel in Folge über Sprechen und Schweigen. Ein Modell
    /// greift ohne Gegendruck immer auf dieselben Namen und dasselbe Grundthema zurück,
    /// wodurch jedes Buch wie eine Variante des vorigen wirkt.
    static func makeNamensUndMotivSperre(projects: [Project], excluding projectID: UUID) -> String {
        let namen = vergebeneNamensteile(projects: projects, excluding: projectID)
        var titelWoerter = Set<String>()
        for project in projects where project.id != projectID {
            for teil in project.title.split(separator: " ") {
                let w = teil.lowercased().trimmingCharacters(
                    in: CharacterSet.letters.inverted)
                if w.count >= 5 { titelWoerter.insert(w) }
            }
        }
        var bloecke: [String] = []
        if !namen.isEmpty {
            bloecke.append("""
            NAMENSSPERRE – diese Vor- und Nachnamen sind in früheren Büchern bereits vergeben             und hier VERBOTEN, auch in Abwandlung:
            \(namen.sorted().joined(separator: ", "))
            Erfinde völlig andere Namen: andere Anfangsbuchstaben, andere Silbenzahl, andere             regionale Herkunft. Ein Leser, der zwei deiner Bücher kennt, darf keine Figur             wiedererkennen.
            """)
        }
        if !titelWoerter.isEmpty {
            bloecke.append("""
            THEMEN-WIEDERHOLUNG VERMEIDEN – diese Begriffe prägten bereits frühere Bücher:
            \(titelWoerter.sorted().joined(separator: ", "))
            Wähle für dieses Buch ein anderes Grundmotiv. Wenn die letzten Bücher um Schweigen,             Sprechen oder Verschweigen kreisten, MUSS dieses um etwas anderes gehen – Schuld,             Besitz, Rache, Sucht, Aufstieg, Verrat, Sehnsucht, Freiheit. Auch der Figurentyp             wechselt: War die letzte Hauptfigur still und beobachtend, ist diese laut,             zupackend oder aggressiv.
            """)
        }
        return bloecke.joined(separator: "\n\n")
    }

    /// Motivsperre über Buchgrenzen hinweg.
    ///
    /// `makeLanguageAvoidanceBrief` fängt nur wörtlich wiederholte Sechs-Wort-Passagen
    /// und liest je Kapitel nur Anfang und Ende. Die eigentlichen Wiedergänger sind aber
    /// kurze Motive: Eine externe Analyse zweier Bücher fand denselben „zu großen Mantel",
    /// dieselbe aufgerissene „Nagelhaut", dieselbe „Neonröhre" und denselben Geruch nach
    /// „billigem Reinigungsmittel" – das Ergebnis wirkte wie eine Umfärbung desselben Buchs.
    ///
    /// Gesammelt werden auffällige Substantive und Zwei-Wort-Bilder aus dem GESAMTEN Text
    /// aller früheren Bücher; im neuen Buch sind sie tabu.
    static func makeMotivSperre(projects: [Project], excluding projectID: UUID,
                                maxResults: Int = 20) -> String {
        var zaehler: [String: Int] = [:]
        let egal: Set<String> = [
            "seine", "ihrer", "ihren", "einem", "einen", "eines", "einer", "dieser",
            "diesem", "diesen", "wieder", "immer", "nichts", "andere", "anderen",
            "sagte", "fragte", "hatte", "wurde", "konnte", "wollte", "musste", "stand"
        ]
        for project in projects where project.id != projectID {
            var imBuch = Set<String>()
            for chapter in (project.chapters ?? []) {
                // Kapiteltext UND Szenentexte: In der Rohfassung steht der Text in den
                // Szenen, `bestText` ist dort noch leer – ohne die Szenen sah die
                // Motivsperre bei mehr als der Hälfte der Kapitel gar nichts.
                let text = ((chapter.bestText ?? "") + " "
                            + (chapter.scenes ?? []).compactMap(\.text).joined(separator: " "))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let woerter = text.lowercased()
                    .replacingOccurrences(of: #"[^a-zäöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).map(String.init)
                // Auffällige Einzelwörter (lang, selten in Alltagsprosa).
                for w in woerter where w.count >= 8 && !egal.contains(w) {
                    imBuch.insert(w)
                }
                // Zwei-Wort-Bilder mit mindestens einem langen Wort.
                guard woerter.count >= 2 else { continue }
                for i in 0..<(woerter.count - 1) {
                    let paar = [woerter[i], woerter[i + 1]]
                    guard paar.contains(where: { $0.count >= 7 }),
                          !paar.contains(where: { egal.contains($0) }) else { continue }
                    imBuch.insert(paar.joined(separator: " "))
                }
            }
            for m in imBuch { zaehler[m, default: 0] += 1 }
        }
        // Nur was in MEHREREN Büchern auftauchte, ist ein echter Wiedergänger.
        let wiedergaenger = zaehler.filter { $0.value >= 2 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(maxResults)
            .map(\.key)
        guard !wiedergaenger.isEmpty else { return "" }
        return """
        MOTIVSPERRE (Wiedergänger aus deinen früheren Büchern – hier STRENG VERBOTEN):
        \(wiedergaenger.joined(separator: ", "))
        Diese Bilder, Gegenstände und Formulierungen sind in vorherigen Büchern bereits
        mehrfach vorgekommen. Ein Leser, der zwei deiner Bücher liest, merkt sofort, dass
        es dasselbe Buch in anderer Farbe ist. Erfinde für DIESES Buch eine eigene
        Bildwelt: andere Gegenstände, andere Gerüche, andere nervöse Gesten, andere Orte.
        """
    }

    static func makeLanguageAvoidanceBrief(projects: [Project], excluding projectID: UUID,
                                           maxResults: Int = 12) -> String {
        var bookCounts: [String: Int] = [:]
        for project in projects where project.id != projectID {
            var seen = Set<String>()
            for chapter in (project.chapters ?? []) {
                let text = chapter.bestText ?? ""
                guard !text.isEmpty else { continue }
                let sample = String(text.prefix(1_800)) + " " + String(text.suffix(600))
                let words = sample.lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).map(String.init)
                guard words.count >= 6 else { continue }
                for index in 0...(words.count - 6) {
                    let gramWords = Array(words[index..<(index + 6)])
                    guard gramWords.contains(where: { $0.count >= 7 }) else { continue }
                    let gram = gramWords.joined(separator: " ")
                    guard gram.count >= 28 else { continue }
                    seen.insert(gram)
                }
            }
            for phrase in seen { bookCounts[phrase, default: 0] += 1 }
        }

        let repeated = bookCounts.filter { $0.value >= 2 }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .prefix(maxResults).map(\.key)
        guard !repeated.isEmpty else { return "" }
        return """
        KATALOGWEIT BEREITS WIEDERHOLTE FORMULIERUNGEN (in diesem Buch nicht verwenden):
        \(repeated.map { "- \($0)" }.joined(separator: "\n"))
        Formuliere Gesten, Übergänge und Reaktionen eigenständig aus der konkreten Situation.
        """
    }

    static func entries(from projects: [Project]) -> [StoryMemoryEntry] {
        projects
            .filter { $0.status == .completed || !($0.bookProfile?.premise ?? "").isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                StoryMemoryEntry(
                    title: $0.title,
                    genre: $0.genre,
                    premise: $0.bookProfile?.premise ?? $0.storyBible?.plotPoints ?? "",
                    structure: $0.storyBible?.plotPoints ?? ""
                )
            }
    }

    static func makeAvoidanceBrief(entries: [StoryMemoryEntry],
                                   selectedGenres: [String],
                                   limit: Int = 12) -> String {
        let relevant = entries.filter { entry in
            selectedGenres.isEmpty || selectedGenres.contains(entry.genre)
        }.prefix(limit)
        guard !relevant.isEmpty else {
            return "Bisher gibt es noch kein gespeichertes Story-Gedächtnis. Erfinde trotzdem eine eigenständige, nicht klischeehafte Geschichte."
        }

        let lines = relevant.map { entry in
            let structure = entry.structure.trimmingCharacters(in: .whitespacesAndNewlines)
            return "- \(entry.title) [\(entry.genre)]: \(entry.premise.truncated(to: 180))"
                + (structure.isEmpty ? "" : " | Aufbau: \(structure.truncated(to: 120))")
        }.joined(separator: "\n")

        return """
        STORY-GEDÄCHTNIS: Diese bereits geschriebenen oder begonnenen Bücher nicht wiederholen, nicht variieren und nicht spiegeln.
        \(lines)

        Entwickle stattdessen ein anderes Kernproblem, andere Konfliktmechanik oder Methode,
        andere Figuren/Zielgruppe, andere Schauplätze/Beispiele und eine deutlich andere Struktur.
        TITELSPERRE: Verwende weder dieselbe Satzform noch dasselbe auffällige Leitwortfeld wie
        ein gespeicherter Titel. Besonders Befehls-/Bedingungstitel und wiederkehrende Felder wie
        Sprechen/Schweigen dürfen nicht unter neuen Wörtern recycelt werden.
        """
    }

    static func signature(title: String, genre: String, premise: String) -> String {
        normalizedTokens([title, genre, premise].joined(separator: " ")).joined(separator: " ")
    }

    static func isLikelyDuplicate(_ idea: ParsedIdea, existing entries: [StoryMemoryEntry]) -> Bool {
        let ideaTokens = Set(normalizedTokens("\(idea.title) \(idea.genre) \(idea.premise)"))
        guard !ideaTokens.isEmpty else { return false }

        let ideaTitlePatterns = titlePatterns(idea.title)
        if !ideaTitlePatterns.isEmpty, entries.contains(where: {
            !titlePatterns($0.title).isDisjoint(with: ideaTitlePatterns)
        }) {
            return true
        }

        let ideaPattern = premisePattern(idea.premise)
        if !ideaPattern.isEmpty {
            let similarPatterns = entries.filter {
                $0.genre == idea.genre && premisePattern($0.premise) == ideaPattern
            }
            if !similarPatterns.isEmpty { return true }
        }

        return entries.contains { entry in
            let entryTokens = Set(normalizedTokens("\(entry.title) \(entry.genre) \(entry.premise)"))
            guard !entryTokens.isEmpty else { return false }
            let overlap = ideaTokens.intersection(entryTokens).count
            let union = ideaTokens.union(entryTokens).count
            let titleOverlap = normalized(entry.title).contains(normalized(idea.title))
                || normalized(idea.title).contains(normalized(entry.title))
            return titleOverlap || Double(overlap) / Double(union) >= 0.32
        }
    }

    /// Markante Titelbauarten und Leitwortfelder. Ein reiner Wortvergleich erkannte
    /// "Sprich, bevor du stirbst" und "Schweig, wenn sie dich sieht" als verschieden,
    /// obwohl beide im Katalog wie dieselbe Modellschablone wirken.
    private static func titlePatterns(_ title: String) -> Set<String> {
        let words = normalized(title).split(separator: " ").map(String.init)
        guard let first = words.first else { return [] }
        var patterns = Set<String>()

        let conditions: Set<String> = ["wenn", "bevor", "bis", "falls", "solange", "sobald"]
        if words.count >= 3,
           conditions.contains(where: words.dropFirst().contains),
           !["ich", "du", "er", "sie", "es", "wir", "ihr", "wer", "was",
             "wenn", "bevor", "warum", "niemand", "kein", "keine",
             "das", "die", "der"].contains(first) {
            patterns.insert("syntax:command-condition")
        }

        let speechSilenceStems = [
            "sprich", "sprech", "sag", "sagt", "schweig", "stimm", "wort",
            "ungesagt", "verschweig", "fluster", "schrei"
        ]
        if words.contains(where: { word in
            speechSilenceStems.contains(where: word.hasPrefix)
        }) {
            patterns.insert("motif:speech-silence")
        }

        let formulaStarts: Set<String> = [
            "ich", "du", "wenn", "bevor", "warum", "niemand", "kein", "keine"
        ]
        if formulaStarts.contains(first) {
            let secondShape: String
            if let second = words.dropFirst().first {
                let pronouns: Set<String> = [
                    "ich", "du", "er", "sie", "es", "wir", "ihr", "mich", "dich",
                    "mir", "dir", "uns", "euch", "mein", "dein", "sein", "ihr"
                ]
                secondShape = pronouns.contains(second) ? "pronoun" : second
            } else {
                secondShape = "single"
            }
            patterns.insert("start:\(first):\(secondShape)")
        }
        if words.count >= 2, ["das", "die", "der"].contains(first) {
            patterns.insert("article:\(words[1])")
        }
        return patterns
    }

    private static func premisePattern(_ premise: String) -> String {
        let text = normalized(premise)
        let patterns: [(String, [String])] = [
            ("return-secret", ["kehrt", "ruckkehr", "heimat", "geheimnis"]),
            ("inheritance-second-chance", ["erbe", "erbt", "zweite chance", "frist"]),
            ("missing-person-investigation", ["verschwunden", "vermisst", "spurensuche", "sucht"]),
            ("forced-proximity", ["wohnung", "zusammen", "gezwungen", "fremde"]),
            ("reader-habit", ["routine", "gewohnheit", "alltag", "schritte"]),
            ("reader-productivity", ["produktiv", "aufgaben", "planung", "fokus"]),
            ("reader-communication", ["gesprach", "kommunikation", "zuhoren", "konflikt"]),
            ("reader-money", ["finanz", "geld", "invest", "budget"])
        ]
        return patterns.first { _, markers in
            markers.filter(text.contains).count >= 2
        }?.0 ?? ""
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9äöüß]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTokens(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "eine", "einer", "einem", "einen", "ein", "der", "die", "das", "und", "oder",
            "mit", "gegen", "auf", "an", "im", "in", "am", "zu", "den", "dem", "des",
            "roman", "thriller", "krimi", "buch", "geschichte", "entdeckt", "kampft"
        ]
        return normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }
}
