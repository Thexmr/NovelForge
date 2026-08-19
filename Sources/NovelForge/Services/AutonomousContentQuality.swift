import Foundation
import NaturalLanguage

struct ProseClarityAssessment {
    let vagueReferences: Int
    let hypotheticalComparisons: Int
    let filterReactions: Int
    let vagueReferenceLimit: Int
    let hypotheticalComparisonLimit: Int
    let filterReactionLimit: Int

    var isAcceptable: Bool {
        vagueReferences <= vagueReferenceLimit
            && hypotheticalComparisons <= hypotheticalComparisonLimit
            && filterReactions <= filterReactionLimit
            && vagueReferences + hypotheticalComparisons + filterReactions
                <= vagueReferenceLimit + hypotheticalComparisonLimit + filterReactionLimit
    }
}

enum SceneFittingSizing {
    static func minimumSourceRatio(sourceWords: Int, targetWords: Int) -> Double {
        guard sourceWords > 0, targetWords > 0 else { return 0.50 }
        guard Double(sourceWords) > Double(targetWords) * 1.25 else { return 0.50 }
        let lowerTargetRatio = Double(targetWords) * 0.75 / Double(sourceWords)
        return min(0.50, max(0.25, lowerTargetRatio * 0.90))
    }
}

enum AutonomousContentQuality {
    private static let kinshipTerms = [
        "vater", "mutter", "schwester", "bruder", "tante", "onkel", "nichte", "neffe",
        "tochter", "sohn", "ehefrau", "ehemann", "großmutter", "grossmutter", "großvater",
        "grossvater"
    ]
    private static let deathTerms = [
        "tod", "tot", "verstorben", "starb", "gestorben", "erhangte", "suizid", "umgebracht"
    ]

    static func safeFictionScene(number: Int, chapterTitle: String, chapterGoal: String,
                                 chapterConflict: String, perspective: String) -> PlannedScene {
        let ziel = chapterGoal.isEmpty ? "das Kapitelziel" : chapterGoal
        let conflict = chapterConflict.isEmpty
            ? "Ein bereits etablierter Widerstand erschwert den nächsten Schritt"
            : chapterConflict

        // WARUM DIESE BEATS SO GEBAUT SIND: Der frühere Fallback gab JEDER Szene dasselbe
        // Kapitelziel als Szenenziel („Clara findet das Foto…"). Der Schreiber führte das
        // Ziel dann in jeder Szene aus – im Testbuch fand die Heldin dasselbe Foto drei-
        // bis viermal, das Telefon klingelte dreimal. Ein Plan, der dreimal dasselbe sagt,
        // erzeugt dreimal dieselbe Szene.
        //
        // Jetzt beschreibt jede Szene eine ANDERE dramaturgische Funktion (Einstieg,
        // Komplikation, Zuspitzung, Wende). Das Kapitelziel wird als Richtung genannt,
        // aber KEINE Szene wiederholt die Handlung einer früheren – das steht ausdrücklich
        // in jedem Beat.
        let beats: [(String, String, String)] = [
            (
                "EINSTIEG: Die Perspektivfigur betritt die Ausgangslage und unternimmt den ERSTEN konkreten Schritt in Richtung: \(ziel). Etabliere Ort, Stimmung und den Auslöser der Handlung.",
                "\(conflict). Der erste Versuch stößt sofort an eine Grenze.",
                "Ein erster Handlungsimpuls ist gesetzt – die Szene endet mit einer offenen Spannung, NICHT mit dem Erreichen des Kapitelziels."
            ),
            (
                "KOMPLIKATION: Ausgehend vom Ende der vorigen Szene ein NEUER, anderer Vorstoß. Zeige eine Handlung, die in Szene 1 noch NICHT vorkam – keine Wiederholung von Fund, Anruf oder Entdeckung von zuvor.",
                "\(conflict). Ein zusätzliches, konkretes Hindernis verschärft die Lage.",
                "Die Figur trifft eine Entscheidung, die neue Folgen auslöst und die Handlung vorantreibt."
            ),
            (
                "ZUSPITZUNG: Die Folgen der vorigen Szenen zwingen die Figur zu einem Schritt mit sichtbarem Einsatz oder Verzicht. Nichts bereits Gezeigtes wird erneut aufgerollt.",
                "\(conflict). Der Preis des Weitergehens wird deutlich.",
                "Ein Wendepunkt verändert die Lage spürbar – die Szene hebt die Spannung, statt zum Anfang zurückzukehren."
            ),
            (
                "WENDE UND ÜBERGANG: Eine Entscheidung oder Enthüllung bringt das Kapitel zu seinem Höhepunkt und öffnet die Tür zum nächsten. Fasse NICHTS aus früheren Szenen noch einmal aus.",
                "\(conflict). Die Entscheidung fordert eine unmittelbare persönliche Konsequenz.",
                "Die Konsequenz führt kausal in das folgende Kapitel – ohne neue Vorgeschichte zu erfinden und ohne eine frühere Szene zu wiederholen."
            )
        ]
        let beat = beats[(max(1, number) - 1) % beats.count]
        return PlannedScene(number: number, perspective: perspective,
                            location: "", time: "fortlaufend",
                            goal: beat.0, obstacle: beat.1, turn: beat.2)
    }

    static func hasScenePlanGenreDrift(_ text: String, genre: String, canon: String) -> Bool {
        !scenePlanGenreDriftMarkers(text, genre: genre, canon: canon).isEmpty
    }

    /// Titel echter, veröffentlichter Bücher – als NEGATIV-Liste.
    ///
    /// Diese Titel stehen als Muster in den Titel-Prompts. Genau deshalb besteht die
    /// Gefahr, dass das Modell sie übernimmt statt sich davon inspirieren zu lassen.
    /// Ein übernommener Titel wäre nicht nur peinlich, sondern rechtlich heikel:
    /// Buchtitel genießen in Deutschland Werktitelschutz nach § 5 MarkenG, sobald sie
    /// Unterscheidungskraft haben.
    static let bekannteBuchtitel: [String] = [
        "Ein Wiedersehen im Sommer", "Zwischen Ende und Anfang", "Das kleine Zuhause in Prag",
        "Der kleine Dünenkiosk auf Sylt", "Sommer, Glück und Ringelblumen",
        "Der Geschmack von Sommer und Karamell", "Warte auf mich am Meer",
        "All das Ungesagte zwischen uns", "Unser Tag ist heute", "Die Tage mit Dir",
        "Eine Liebe ohne Sommer", "A Taste of Cornwall", "Der Teufel trägt Prada",
        "Das Lied der Weite", "Wo die Nächte hell sind", "Solange die Hoffnung bleibt",
        "Als der Sommer uns gehörte", "Stolz und Vorurteil", "Der große Gatsby",
    ]

    /// Ist der Titel eine Kopie oder Fast-Kopie eines bekannten Buches?
    ///
    /// Verglichen werden nur die inhaltstragenden Wörter – Artikel und Präpositionen
    /// bleiben außen vor, sonst gälte jeder Titel mit „Der … in …" als Kopie. Zwei
    /// gemeinsame Inhaltswörter bei kurzen Titeln reichen für einen Treffer: „Ein
    /// Wiedersehen im Winter" ist zu nah an „Ein Wiedersehen im Sommer".
    static func istKopieBekannterTitel(_ titel: String, weitereBekannte: [String] = []) -> Bool {
        func inhaltswoerter(_ s: String) -> Set<String> {
            // Auch Beziehungs- und Allerweltswörter zählen hier NICHT als Merkmal:
            // „zwischen uns" steht in Dutzenden Titeln. Ohne diese Ausnahme gälte
            // „Was zwischen uns steht" als Kopie von „All das Ungesagte zwischen uns",
            // obwohl beide nichts Charakteristisches teilen.
            let fuellwoerter: Set<String> = ["der", "die", "das", "ein", "eine", "einer", "eines",
                                             "den", "dem", "des", "und", "oder", "in", "im", "am",
                                             "an", "auf", "bei", "von", "vom", "mit", "für", "zu",
                                             "zur", "zum", "als", "wie", "ist", "war", "the", "of",
                                             "a", "an",
                                             "uns", "wir", "dir", "dich", "mich", "mein", "unser",
                                             "zwischen", "was", "wo", "wenn", "alles", "all",
                                             "kleine", "kleiner", "letzte", "letzten"]
            return Set(s.folding(options: [.diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 && !fuellwoerter.contains($0) })
        }
        let kandidat = inhaltswoerter(titel)
        guard !kandidat.isEmpty else { return false }

        for bekannt in bekannteBuchtitel + weitereBekannte {
            let referenz = inhaltswoerter(bekannt)
            guard !referenz.isEmpty else { continue }
            // Ein einzelnes Allerweltswort macht noch keine Kopie: „Meer", „Sommer" oder
            // „Nacht" stehen in hunderten Liebesromantiteln. Nur wenn das gemeinsame
            // Wort MARKANT ist (oder es mehrere gibt), ist der Titel zu nah dran.
            let haeufigeTitelwoerter: Set<String> = [
                "meer", "sommer", "winter", "regen", "nacht", "licht", "schatten", "herz",
                "liebe", "haus", "weg", "himmel", "stille", "sterne", "wind", "insel",
                "tage", "jahre", "leben", "zeit", "morgen", "abend", "hoffnung"
            ]
            let geteilt = kandidat.intersection(referenz)
            let markant = geteilt.subtracting(haeufigeTitelwoerter)
            let gemeinsam = geteilt.count
            guard gemeinsam >= 2 || !markant.isEmpty else { continue }
            // Überwiegen die gemeinsamen Wörter auf BEIDEN Seiten, ist es zu nah dran.
            //
            // Die Hälfte genügt, weil kurze Titel wenige Inhaltswörter haben: „Ein
            // Wiedersehen im Winter" teilt mit „Ein Wiedersehen im Sommer" nur EIN
            // Wort – aber es ist das prägende, und der Titel wäre erkennbar abgekupfert.
            let anteilKandidat = Double(gemeinsam) / Double(kandidat.count)
            let anteilReferenz = Double(gemeinsam) / Double(referenz.count)
            if anteilKandidat >= 0.5 && anteilReferenz >= 0.5 { return true }
        }
        return false
    }

    /// Klingt der Titel nach Literaturpreis-Bewerbung statt nach einem Buch, das sich
    /// verkauft?
    ///
    /// Recherchiert an den aktuellen deutschen Bestsellerlisten (Rowohlt, dtv,
    /// Droemer Knaur, Amazon): „Ein Wiedersehen im Sommer", „Warte auf mich am Meer",
    /// „All das Ungesagte zwischen uns", „Der Geschmack von Sommer und Karamell",
    /// „Das kleine Zuhause in Prag", „Unser Tag ist heute". Alle enthalten warme
    /// Alltagswörter und mindestens einen von drei Ankern: einen Ort, eine Zeitangabe
    /// oder ein Beziehungswort.
    ///
    /// Der Testbuch-Titel „Das Gewicht von Seide" hat keinen davon – ein Gegenstand
    /// ohne Menschen, ohne Ort, mit einem schweren Abstraktum als Kern. Solche Titel
    /// werden im Thumbnail überscrollt.
    static func titelWirktVerkopft(_ titel: String) -> Bool {
        let t = titel.lowercased()
        guard !t.isEmpty else { return false }

        // Muster „Das <Abstraktum> von/des <Stoff>" – die typische Preisjury-Konstruktion.
        let schwereKerne = ["gewicht", "substanz", "essenz", "wesen", "fragment", "membran",
                            "beschaffenheit", "aggregat", "resonanz", "textur", "kontur"]
        if schwereKerne.contains(where: { t.contains($0) }) { return true }

        // Mindestens ein Anker muss vorhanden sein.
        // Zeitanker: Jahreszeiten, Tageszeiten – und die Zeitkonjunktionen, mit denen
        // Verlagstitel arbeiten („Bevor der Regen kam", „Als der Sommer uns gehörte").
        let zeit = ["sommer", "winter", "frühling", "herbst", "morgen", "abend", "nacht",
                    "tag", "tage", "heute", "damals", "wiedersehen", "jahr", "stunde",
                    "august", "juli", "juni", "september", "weihnacht",
                    "bevor", "solange", "nachdem", "seit", "wenn ", "als ", "wo "]
        let beziehung = ["uns", "dir", "dich", "wir", "mich", "mein", "unser", "euch", "ihr "]
        // Führendes Leerzeichen ergänzen, damit Präpositionen auch am Titelanfang greifen
        // („Zwischen Ende und Anfang") und nicht als Wortteil („beinahe" → „am").
        let mitRand = " " + t
        let ortSignal = [" in ", " im ", " am ", " an ", " auf ", " bei ", " zwischen ", " nach ",
                         " über ", " unter ", " vor "]
        let hatAnker = zeit.contains { t.contains($0) }
            || beziehung.contains { t.contains($0) }
            || ortSignal.contains { mitRand.contains($0) }
        return !hatAnker
    }

    /// Anteil wörtlicher Rede am Text (0–1).
    ///
    /// Gemessen an „Das Gewicht von Seide": **2,3 %** über das ganze Buch, sieben von
    /// zwölf Kapiteln ohne ein einziges Anführungszeichen. Das Buch besteht fast nur
    /// aus Beschreibung und Innenschau – und genau das ermüdet einen Leser stärker als
    /// jeder lange Satz. Belletristik liegt üblicherweise bei 25–40 %, ruhige
    /// literarische Prosa selten unter 15 %.
    ///
    /// Gezählt werden alle im Deutschen üblichen Anführungszeichen; der Text der App
    /// verwendet „…" nach der Typografie-Bereinigung.
    static func dialoganteil(in text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let muster = "[\u{201E}\u{201C}\"\u{00BB}][^\u{201E}\u{201C}\u{201D}\"\u{00AB}\u{00BB}]{3,}[\u{201C}\u{201D}\"\u{00AB}]"
        guard let re = try? NSRegularExpression(pattern: muster) else { return 0 }
        let ns = text as NSString
        let treffer = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        let zeichen = treffer.reduce(0) { $0 + $1.range.length }
        return Double(zeichen) / Double(ns.length)
    }

    /// Vereinheitlicht alle Anführungszeichen auf die deutsche Form „…".
    ///
    /// Buch 9 mischte »Guillemets« und „Gänsefüßchen" im selben Manuskript – für ein
    /// verkauftes Buch ein klarer Satzfehler. Gerade Zoll-Zeichen (") ersetzt ein
    /// Schalter: das erste öffnet, das nächste schließt.
    static func vereinheitlicheAnfuehrungszeichen(_ text: String) -> String {
        var ergebnis = ""
        ergebnis.reserveCapacity(text.count)
        var offen = false
        for zeichen in text {
            switch zeichen {
            case "«", "»", "‹", "›", "\u{201C}", "\u{201D}", "\u{201E}", "\u{2018}", "\u{2019}":
                // Typografische Varianten: Richtung aus dem Zustand ableiten, damit
                // auch falsch herum gesetzte Zeichen korrekt landen.
                ergebnis.append(offen ? "\u{201C}" : "\u{201E}")
                offen.toggle()
            case "\"":
                ergebnis.append(offen ? "\u{201C}" : "\u{201E}")
                offen.toggle()
            default:
                ergebnis.append(zeichen)
            }
        }
        return ergebnis
    }

    /// Absätze, in denen jemand offensichtlich spricht, die Rede aber nicht als
    /// solche ausgezeichnet ist.
    ///
    /// „Ich wiederhole die Frage, sagte Erik Brenner." – so stand es in Buch 9. Der
    /// Leser kann Rede und Erzählung nicht mehr trennen; das Buch wirkt wie ein
    /// unfertiges Manuskript. Zusätzlich zählt `dialoganteil` solche Stellen nicht
    /// mit, wodurch die Dialogprüfung ins Leere lief.
    static func dialogOhneAnfuehrungszeichen(in text: String) -> [String] {
        let einleitungen = ["sagte", "fragte", "erwiderte", "antwortete", "flüsterte",
                            "rief", "murmelte", "entgegnete", "brummte", "seufzte",
                            "zischte", "stammelte", "erklärte", "wiederholte"]
        var treffer: [String] = []
        for absatz in text.components(separatedBy: "\n") {
            let a = absatz.trimmingCharacters(in: .whitespaces)
            guard a.count > 20 else { continue }
            // Enthält der Absatz bereits Rede-Auszeichnung, ist alles in Ordnung.
            guard !a.contains("\u{201E}"), !a.contains("\u{201C}"),
                  !a.contains("»"), !a.contains("\"") else { continue }
            let verbMuster = einleitungen.joined(separator: "|")
            // Ein echtes Redeetikett braucht nach dem Verb einen Sprecher. Formulierungen
            // wie "nahm ab, sagte nur ihren Namen" berichten einen Sprechakt, enthalten
            // aber keine ausgelassene direkte Rede.
            let kommaMuster = #",\s*(?:"# + verbMuster
                + #")\s+(?:ich|du|er|sie|wir|ihr|[A-ZÄÖÜ][\p{L}-]+)\b"#
            let doppelpunktMuster = #"\b(?:"# + verbMuster + #")\s*:\s*\p{L}"#
            let hatEinleitung = a.range(of: kommaMuster, options: .regularExpression) != nil
                || a.range(of: doppelpunktMuster, options: .regularExpression) != nil
            if hatEinleitung { treffer.append(String(a.prefix(120))) }
        }
        return treffer
    }

    /// Finds paragraphs whose dialogue punctuation is structurally broken.
    /// Quote style differences are harmless and are normalized elsewhere; unmatched
    /// marks and punctuation on both sides of a closing mark are not.
    static func brokenDialogueTypography(in text: String) -> [String] {
        let quoteCharacters = CharacterSet(charactersIn: "\"«»‹›„“‘’")
        let suspiciousPatterns = [
            #"[.!?][„“\"]+[.!?]"#,
            #"\.[„“\"],"#,
            #"[„“\"]\.[„“\"]"#,
            #"[“»\"]\p{L}"#,
            #"[!?]{2,}"#,
        ]
        var findings: [String] = []
        for paragraph in text.components(separatedBy: .newlines) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let quoteCount = trimmed.unicodeScalars
                .filter { quoteCharacters.contains($0) }.count
            let suspicious = suspiciousPatterns.contains { pattern in
                trimmed.range(of: pattern, options: .regularExpression) != nil
            }
            if !quoteCount.isMultiple(of: 2) || suspicious {
                findings.append(String(trimmed.prefix(220)))
            }
        }
        return findings
    }

    /// Untergrenze, ab der eine Szene als dialogarm gilt.
    ///
    /// Eine reine Beschreibungsszene ist legitim, ein ganzes Buch daraus nicht.
    ///
    /// **Warum der Wert von 0,12 auf 0,20 gestiegen ist.** Gemessen an 34 fertigen
    /// Titeln dieses Programms (5,9 Mio. Wörter, `Scripts/BuchScanProbe.swift`) lag der
    /// Dialoganteil im Mittel bei **exakt 12 %** – dem alten Wert, aufs Prozent genau.
    /// Zwanzig der 34 Bücher lagen bei 12 % oder darunter, sieben unter 10 %.
    ///
    /// Das ist kein Zufall, sondern das bekannteste Muster überhaupt: Eine Untergrenze
    /// wird zum Zielwert. Das System hört auf, sobald es gerade eben durchkommt.
    /// Unterhaltungsliteratur liegt bei 25–40 %; bei 12 % besteht ein Buch zu neun
    /// Zehnteln aus Beschreibung und Innenschau, und genau das ermüdet einen Leser
    /// stärker als jeder lange Satz.
    ///
    /// 0,20 liegt weiterhin UNTER dem Zielband – es ist eine Untergrenze, kein Ziel.
    /// Höher zu gehen wäre riskant: Der Wert steht auch in der Annahmebedingung der
    /// Rohfassung, wo er Neuversuche auslöst. Das eigentliche Ziel gehört in den
    /// Schreibprompt, wo es die Szene formt, statt sie nachträglich abzulehnen.
    static let dialogUntergrenze = 0.20

    /// Sätze, die den Leser abhängen: lang UND stark verschachtelt.
    ///
    /// Gemessen an „Das Gewicht von Seide" (literarischer Stil, 14.700 Wörter): 53
    /// Sätze mit über 30 Wörtern und mehr als vier Einschüben, der längste mit 70
    /// Wörtern und 18 Einschüben – ein Satz, der über eine halbe Seite läuft und
    /// keine Atempause lässt. Für anspruchsvolle Belletristik mag das tragen, für ein
    /// breit verkäufliches Buch ist es die häufigste Abbruchursache.
    ///
    /// Beide Schwellen müssen greifen: Ein langer Satz ohne Einschübe liest sich
    /// flüssig, ein kurzer mit drei Kommas ebenfalls. Erst die Kombination bremst.
    /// Echte Bandwürmer – bewusst großzügiger als früher.
    ///
    /// Die alte Grenze (über 30 Wörter mit mehr als vier Einschüben) hat nebenbei die
    /// gewollte Satzvarianz erstickt: Gemessen an einem Buch lagen 80 % der Sätze unter
    /// 15 Wörtern und nur 2,8 % über 30. Menschliche Prosa mischt sehr kurze Sätze mit
    /// langen, verschachtelten – genau diese langen fehlten. Jetzt schlägt die Prüfung
    /// erst bei echten Lesehindernissen an: über 45 Wörter UND mehr als sechs Einschübe.
    static func schwerLesbareSaetze(in text: String) -> [String] {
        saetzeAusText(text).filter { satz in
            let woerter = satz.split(separator: " ").count
            guard woerter > 45 else { return false }
            let einschuebe = satz.filter { $0 == "," || $0 == "–" || $0 == "—" }.count
            return einschuebe > 6
        }
    }

    /// Fehlt dem Text die Satzvarianz? („Burstiness")
    ///
    /// Gemessen wird nicht die Standardabweichung allein – die sieht schon gut aus, wenn
    /// viele kurze Sätze aufeinandertreffen. Entscheidend ist, ob es überhaupt LANGE
    /// Sätze gibt. Menschliche Erzählprosa hat regelmäßig Perioden über 30 Wörter.
    /// Altmodische Wendungen, die einen langen Satz unlesbar machen.
    ///
    /// Die gelockerte Satzlaengen-Grenze erlaubt jetzt lange Perioden. Die duerfen aber
    /// modern klingen und nicht ins 19. Jahrhundert kippen. Diese Pruefung faengt genau
    /// die Konstruktionen ab, an denen ein Leser haengenbleibt und zurueckspringen muss.
    static func altmodischeWendungen(in text: String) -> [String] {
        let muster: [(String, String)] = [
            (#"\bwelche[rsmn]?\s+[a-zaeoeue]"#, "welcher/welche statt der/die"),
            (#"\b(sodann|alsdann|indes|gleichwohl|mithin|dieweil|nunmehr|derlei)\b"#,
             "gehobene Partikel"),
            (#"\b(vermochte|ward|obliegt|geziemt)\b"#, "veraltetes Verb"),
            (#"\b\w+(ung|heit|keit|nis)\s+des\s+\w+(ung|heit|keit|nis)\b"#, "Genitivkette"),
            (#"(^|[.!?]\s)[A-Z][a-z]{3,}nd\s+[a-z]"#, "Partizip am Satzanfang")
        ]
        var treffer: [String] = []
        let ns = text as NSString
        for (regex, name) in muster {
            guard let re = try? NSRegularExpression(pattern: regex) else { continue }
            let n = re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
            if n > 0 { treffer.append(name + " (" + String(n) + "x)") }
        }
        return treffer
    }

    /// Findet die EINZELNEN Saetze, die einen Tick enthalten.
    ///
    /// Der entscheidende Unterschied zu allen bisherigen Pruefungen: Die melden, dass
    /// eine Szene einen Fehler hat, und geben nach drei Versuchen frei - damit die
    /// Produktion nicht stehenbleibt. Dadurch ist jede Regel am Ende optional, und
    /// gemessen stand "zaehlen" trotz Sperre 46-mal im Buch.
    ///
    /// Diese Funktion liefert die betroffenen Saetze einzeln. Dann muss nicht die ganze
    /// Szene verworfen werden - es reichen die drei, vier Saetze, die wirklich falsch
    /// sind. Die Produktion laeuft weiter UND der Fehler verschwindet.
    static func saetzeMitTicks(in text: String) -> [(satz: String, grund: String)] {
        let muster: [(String, String)] = [
            (#"z(ä|a)hlt?e?\b"#, "Zaehl-Zwang: die Figur zaehlt etwas"),
            (#"(kribbel|prickel)"#, "kribbelnde Gliedmassen"),
            (#"\btaub\w*\b"#, "taube Finger/Haende"),
            (#"(zitter|beb)te?\w*"#, "zitternde Haende"),
            (#"Z(ä|a)hne[^.!?]{0,15}klapper"#, "klappernde Zaehne"),
            (#"Nervenbahn"#, "abgestorbene Nervenbahn"),
            (#"\b\w{3,},\s+\w{3,}\s+und\s+\w{3,}\b"#, "Dreier-Aufzaehlung"),
            (#"(T(ü|u)r|T(ü|u)re)[^.!?]{0,40}(fiel|schloss|klickte)"#, "Tuer faellt ins Schloss"),
            (#"nicht\s+[^,.!?]{2,40},\s*sondern"#, "Antithese nicht-X-sondern-Y")
        ]
        var treffer: [(satz: String, grund: String)] = []
        for satz in saetzeAusText(text) {
            let ns = satz as NSString
            let ganz = NSRange(location: 0, length: ns.length)
            for (regex, grund) in muster {
                guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
                else { continue }
                if re.firstMatch(in: satz, range: ganz) != nil {
                    treffer.append((satz, grund))
                    break
                }
            }
        }
        // Nur wiederkehrende Deutungsformeln und bewusst ausgestellte Schlusssätze
        // gehen in die Satz-Chirurgie. Ein einzelner klarer Gedanke bleibt legitime
        // Figurenperspektive; die Häufung macht Prosa dagegen wie kommentierte KI-Ausgabe.
        let antiGlaette = antiGlaetteFindings(in: text)
        for finding in antiGlaette where !treffer.contains(where: { $0.satz == finding.satz }) {
            treffer.append(finding)
        }
        return treffer
    }

    /// Findet Deutungssätze, die eine vorher bereits sichtbare Handlung oder Reaktion
    /// nachträglich auslegen. Einzelne Einordnungen sind normale Erzählstimme; erst ein
    /// wiederkehrendes Muster wird als KI-typische Glätte gewertet.
    static func uebererklaerendeDeutungssaetze(in text: String) -> [(satz: String, grund: String)] {
        let muster: [(String, String)] = [
            (#"\b(?:das|dies)\s+(?:war|ist)\s+(?:der|die|das)\s+(?:punkt|moment|art|weise|grund)\b"#,
             "Erklärsatz deutet die Szene nachträglich aus"),
            (#"\b(?:sie|er)\s+(?:wusste|merkte|spürte),?\s+dass\s+(?:das|dies)\b"#,
             "Erklärsatz benennt eine bereits gezeigte Bedeutung"),
            (#"\b(?:das|dies)\s+(?:zeigte|bedeutete|machte klar),?\s+(?:dass|wie)\b"#,
             "Erklärsatz kommentiert statt die Folge auszuspielen"),
            (#"\b(?:es|das)\s+war\s+(?:nicht|mehr)\s+nur\b"#,
             "Bedeutungssteigerung wird behauptet statt konkret gezeigt")
        ]
        var treffer: [(satz: String, grund: String)] = []
        for satz in saetzeAusText(text) {
            let ns = satz as NSString
            let range = NSRange(location: 0, length: ns.length)
            for (regex, grund) in muster {
                guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
                else { continue }
                if re.firstMatch(in: satz, range: range) != nil {
                    treffer.append((satz, grund))
                    break
                }
            }
        }
        return treffer
    }

    /// Findet ausschließlich im Schlussfenster einer Passage künstlich aufgerufene
    /// Erkenntnis- oder Fragenformeln. Ein ruhiges, konkretes Ende bleibt erlaubt;
    /// blockiert werden nur sichtbare "Bedeutungs-Schleifen" wie "plötzlich stand da
    /// eine Frage", die einen Haken behaupten statt eine Folge zu erzeugen.
    static func kuenstlichRundeSchlusssaetze(in text: String) -> [(satz: String, grund: String)] {
        let absatzEnde = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.wordCount >= 3 }
            .suffix(2)
            .joined(separator: " ")
        guard !absatzEnde.isEmpty else { return [] }
        let muster: [(String, String)] = [
            (#"\b(?:stand|lag|blieb)\s+(?:dort\s+)?(?:plötzlich\s+)?(?:eine|die)\s+(?:frage|erkenntnis|wahrheit)\b"#,
             "Künstlich ausgestellter Erkenntnis-Haken am Szenenende"),
            (#"\b(?:frage|erkenntnis|wahrheit)\s*,?\s+die\s+(?:sie|er|niemand)\s+(?:nicht|nie)\s+(?:mehr\s+)?(?:loswurde|weg(?:bekam|bekommen)|ignorieren)\b"#,
             "Künstlich ausgestellter Erkenntnis-Haken am Szenenende"),
            (#"\bwas\s+geschah\s+mit\b"#,
             "Rhetorische Bedeutungsfrage statt konkreter Szenenfolge"),
            (#"\b(?:zweite chance|neuer anfang)\b[^.!?]{0,70}\b(?:frage|bedeutete|bedeuten)\b"#,
             "Thema wird am Szenenende erklärt statt durch Handlung offen gelassen")
        ]
        var treffer: [(satz: String, grund: String)] = []
        for satz in saetzeAusText(absatzEnde) {
            let ns = satz as NSString
            let range = NSRange(location: 0, length: ns.length)
            for (regex, grund) in muster {
                guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
                else { continue }
                if re.firstMatch(in: satz, range: range) != nil {
                    treffer.append((satz, grund))
                    break
                }
            }
        }
        return treffer
    }

    /// Gemeinsame, konservative Anti-Glätte-Diagnose. Eine Szene darf reflektieren;
    /// befundet wird erst die Häufung von Nachdeutungen oder ein sichtbar gebauter
    /// Erkenntnis-Haken. Alle nachgelagerten Gates nutzen genau diese Schnittstelle.
    static func antiGlaetteFindings(in text: String) -> [(satz: String, grund: String)] {
        let deutungen = uebererklaerendeDeutungssaetze(in: text)
        return kuenstlichRundeSchlusssaetze(in: text)
            + (deutungen.count >= 2 ? deutungen : [])
    }

    static func fehlendeSatzvarianz(in text: String) -> String? {
        let laengen = saetzeAusText(text).map { $0.split(separator: " ").count }
        guard laengen.count >= 12 else { return nil }
        let mittel = Double(laengen.reduce(0, +)) / Double(laengen.count)
        let varianz = laengen.reduce(0.0) { summe, laenge in
            let abstand = Double(laenge) - mittel
            return summe + abstand * abstand
        } / Double(laengen.count)
        let standardabweichung = sqrt(varianz)
        let haeufigkeiten = Dictionary(grouping: laengen, by: { $0 }).mapValues(\.count)
        let groessterGleichlauf = haeufigkeiten.values.max() ?? 0
        let gleichlaufAnteil = Double(groessterGleichlauf) / Double(laengen.count)

        // Satzvarianz bedeutet nicht, dass ein Roman Schachtelsaetze braucht. Auffaellig
        // ist erst ein nahezu metronomischer Gleichlauf: immer dieselbe Laenge und damit
        // derselbe Atem. Kurze und mittlere Saetze duerfen einen ganzen Abschnitt tragen.
        if standardabweichung < 1.8 || gleichlaufAnteil >= 0.55 {
            let wert = String(format: "%.1f", standardabweichung)
            return "Die Satzlängen laufen zu gleichförmig (Standardabweichung \(wert)). Variiere kurze und mittlere Sätze organisch; lange Sätze sind nur sinnvoll, wenn sie beim ersten Lesen klar bleiben."
        }
        return nil
    }

    // MARK: - Erzählen statt Stimmung stapeln
    //
    // Eine Lektoratsanalyse eines fertigen Buchs brachte den Kernfehler auf den Punkt:
    // „Stil-Überflieger mit Handlungs-Untergewicht". Jeder Satz will bedeutungsschwer
    // sein, zwischen den Wendepunkten liegen Dutzende Seiten Innenschau, Leitmotive
    // wiederholen sich wie ein Mantra. Die folgenden Prüfungen machen genau das
    // messbar – Prompt-Regeln allein haben sich als wirkungslos erwiesen.

    /// Absätze reiner Beschreibung: lang, ohne ein gesprochenes Wort.
    ///
    /// Ab etwa 120 Wörtern ohne Rede bekommt der Leser keine Luft mehr. Genau daraus
    /// entsteht der Eindruck, die Handlung stehe still.
    static func beschreibungsbloecke(in text: String, grenze: Int = 120) -> [String] {
        text.components(separatedBy: "\n").compactMap { absatz -> String? in
            let a = absatz.trimmingCharacters(in: .whitespaces)
            guard a.wordCount > grenze else { return nil }
            // Enthält der Absatz Rede, ist die Länge unkritisch – dann wird gesprochen.
            guard !a.contains("\u{201E}"), !a.contains("\u{201C}"), !a.contains("»") else { return nil }
            return String(a.prefix(140))
        }
    }

    /// Sätze mit gestapelten Bildern: mehr als ein Vergleich in einem Satz.
    ///
    /// „Die Neonröhre flackerte im Rhythmus eines kaputten Herzschlags, als hätte
    /// jemand die Zeit angehalten." – zwei Bilder in einem Satz. Eines trägt, zwei
    /// heben sich gegenseitig auf.
    static func gestapelteBilder(in text: String) -> [String] {
        let partikel = ["wie ein", "wie eine", "wie einen", "wie das", "wie der", "wie die",
                        "als hätte", "als wäre", "als hätten", "als wären", "als ob",
                        "gleich einem", "gleich einer", "einem ", "wirkte wie", "schien wie"]
        return saetzeAusText(text).filter { satz in
            let klein = satz.lowercased()
            let treffer = partikel.reduce(0) { summe, p in
                summe + klein.components(separatedBy: p).count - 1
            }
            return treffer >= 2 && satz.split(separator: " ").count > 12
        }
    }

    /// Wortgruppen, die im Buch immer wieder gleich auftauchen.
    ///
    /// „Liv berührte ihre Kehle", „Caius zählte ihre Atemzüge" – als Leitmotiv gedacht,
    /// als Füllmaterial gelesen. Ein Motiv, das sich nicht verändert, verliert seine
    /// Kraft. Geprüft werden Vier-Wort-Folgen über den GESAMTEN bisherigen Text.
    ///
    /// - Returns: Wortgruppen mit ihrer Häufigkeit, absteigend.
    static func wiederholteWortgruppen(in texte: [String], abHaeufigkeit: Int = 3) -> [(gruppe: String, anzahl: Int)] {
        // Reine Funktionswort-Folgen ("und dann war es") sind kein Motiv.
        let funktionswoerter: Set<String> = [
            "und", "oder", "aber", "der", "die", "das", "den", "dem", "des", "ein", "eine",
            "einen", "einem", "einer", "ist", "war", "sind", "waren", "hat", "hatte", "sich",
            "nicht", "auch", "noch", "nur", "schon", "dann", "wenn", "als", "wie", "in", "an",
            "auf", "zu", "mit", "von", "für", "es", "er", "sie", "ich", "du", "wir", "ihr",
            "so", "da", "am", "im", "vom", "zum", "zur", "dass", "sehr", "mehr", "aus", "bei"
        ]
        var zaehler: [String: Int] = [:]
        for text in texte {
            let woerter = text.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            guard woerter.count >= 4 else { continue }
            for i in 0...(woerter.count - 4) {
                let gruppe = Array(woerter[i..<(i + 4)])
                // Mindestens zwei bedeutungstragende Wörter, sonst ist es Grammatik.
                guard gruppe.filter({ !funktionswoerter.contains($0) }).count >= 2 else { continue }
                zaehler[gruppe.joined(separator: " "), default: 0] += 1
            }
        }
        return zaehler.filter { $0.value >= abHaeufigkeit }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(12)
            .map { (gruppe: $0.key, anzahl: $0.value) }
    }

    /// Verhindert, dass der Roman in erklaerender Vorgeschichte stecken bleibt.
    /// Eine Vergangenheitsebene kann tragen, ist aber weder Pflicht noch automatisch tief.
    /// Entscheidend ist, dass in der aktuellen Szene jemand handelt oder entscheidet.
    static func anfangTiefeMaengel(in text: String) -> [String] {
        let anfang = text.split(separator: " ").prefix(180).joined(separator: " ").lowercased()
        let vergangenheit = ["damals", "früher", "als kind", "jahre zuvor", "jahren zuvor",
                             "seitdem", "seither", "hatte damals", "erinnerte sich"]
        let aktuelleHandlung = ["sagte", "fragte", "ging", "griff", "zog", "öffnete",
                                "oeffnete", "lief", "trat", "nahm", "warf", "riss",
                                "entschied", "wählte", "waehlte", "musste", "wollte"]
        let rueckblicke = vergangenheit.filter { anfang.contains($0) }.count
        let handeltJetzt = aktuelleHandlung.contains { anfang.contains($0) }
        if rueckblicke >= 2 && !handeltJetzt {
            return ["Der Anfang erklärt zu viel Vergangenheit, bevor in der aktuellen Szene etwas geschieht. Lass die Hauptfigur jetzt handeln oder entscheiden; Vorgeschichte nur dort einflechten, wo sie die laufende Szene verändert."]
        }
        return []
    }

    /// Prüft den Romananfang: Lernt der Leser sofort die Hauptfigur kennen?
    ///
    /// Die erste Seite entscheidet, ob jemand weiterliest. Sie muss zeigen, WER die
    /// Figur ist und dass etwas auf dem Spiel steht – nicht mit Wetter, Landschaft
    /// oder einer Rückblende beginnen, in der niemand etwas will.
    ///
    /// - Returns: Die Mängel im Klartext; leer heißt: Anfang trägt.
    static func romananfangMaengel(in text: String, figurennamen: [String]) -> [String] {
        var maengel: [String] = []
        let woerter = text.split(separator: " ")
        let auftakt = woerter.prefix(90).joined(separator: " ")
        let auftaktKlein = auftakt.lowercased()

        // Ein Name in den ersten Zeilen kann helfen, ist aber keine Pflicht. Gute
        // personale oder Ich-Einstiege duerfen die Hauptfigur zuerst ueber eine klare
        // Handlung einfuehren. Eine starre Namensfrist wuerde solche Anfaenge kuenstlich
        // und formelhaft machen.
        _ = figurennamen
        // 2. Reiner Stimmungsauftakt ohne handelnde Person.
        let kulisse = ["regen", "schnee", "nebel", "wind", "himmel", "sonne", "wolken",
                       "licht fiel", "dämmerung", "morgen brach", "stadt lag", "luft roch"]
        let handlung = ["sagte", "fragte", "ging", "griff", "zog", "öffnete", "lief",
                        "stand auf", "wollte", "musste", "wusste", "hielt", "nahm", "drehte"]
        let hatKulisse = kulisse.contains { auftaktKlein.contains($0) }
        let hatHandlung = handlung.contains { auftaktKlein.contains($0) }
        if hatKulisse && !hatHandlung {
            maengel.append("Der Auftakt beschreibt nur Kulisse – niemand handelt und niemand will etwas.")
        }
        // 3. Es muss etwas auf dem Spiel stehen: ein Wunsch, ein Mangel, eine Drohung.
        let einsatz = ["nicht mehr", "seit", "verloren", "vermisst", "tot", "gestorben",
                       "letzte", "letzter", "letztes", "musste", "wollte", "brauchte",
                       "angst", "gefahr", "schuld", "geheim", "lüge", "warten", "wartete",
                       "bevor", "wenn", "niemand", "kein", "nie", "sollte", "durfte"]
        let ersteHaelfte = woerter.prefix(220).joined(separator: " ").lowercased()
        if !einsatz.contains(where: { ersteHaelfte.contains($0) }) {
            maengel.append("Auf den ersten Absätzen steht nichts auf dem Spiel – kein Wunsch, kein Mangel, keine Drohung.")
        }
        return maengel
    }

    /// Erlaubt einen einzelnen, aus der Szene erwachsenden Auslöser, verhindert aber
    /// die typische KI-Abkürzung: Mehrere geheimnisvolle Requisiten werden ohne
    /// emotionalen Aufbau in den ersten Absatz gestellt und simulieren so Spannung.
    /// Die Schwelle ist absichtlich hoch, damit ein kanonisch notwendiger Brief oder
    /// ein Foto nicht fälschlich verworfen wird.
    static func openingMysteryStackIssues(in text: String) -> [String] {
        let start = text.split(whereSeparator: \.isWhitespace).prefix(260)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        guard !start.isEmpty else { return [] }

        let signals = [
            "anonymer brief", "anonyme nachricht", "kryptische nachricht",
            "unbekannte nummer", "unbekannte nachricht", "geheimnisvoller umschlag",
            "alter brief", "alte akte", "alte polizeiakte", "unbekanntes foto",
            "altes foto", "fundstueck", "fundstück", "schluesselbund", "schlüsselbund",
            "verschlossener umschlag", "ohne absender", "niemand wusste", "drohung"
        ]
        let hits = signals.filter { start.contains($0) }
        guard hits.count >= 3 else { return [] }
        return [
            "Der Romananfang stapelt mehrere Mystery-Requisiten (\(hits.prefix(4).joined(separator: ", "))), bevor der persönliche Konflikt tragen kann. Verankere zuerst Figur, Alltagssituation und kleines Ziel; führe danach nur einen Auslöser ein."
        ]
    }

    /// Endabnahme des tatsaechlich gespeicherten Romananfangs. Die Szenenpruefung
    /// allein reicht nicht, weil Revision, Korrektorat und Blick-ins-Buch-Pass den
    /// Anfang danach erneut veraendern koennen.
    static func finalOpeningIssues(in text: String,
                                   protagonistNames: [String]) -> [String] {
        let sample = String(text.prefix(7_000))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sample.isEmpty else { return ["Der Romananfang ist leer."] }

        var issues = romananfangMaengel(in: sample, figurennamen: protagonistNames)
        issues.append(contentsOf: anfangTiefeMaengel(in: sample))
        issues.append(contentsOf: openingMysteryStackIssues(in: sample))

        let clarity = clarityAssessment(sample)
        if !clarity.isAcceptable {
            issues.append(
                "Der Romananfang ist durch vage Referenzen, Filterreaktionen oder Vergleichsketten nicht beim ersten Lesen klar."
            )
        }
        if soundsLikeAI(sample) {
            issues.append(
                "Der Romananfang enthaelt zu viele formelhafte oder maschinell wirkende Wendungen."
            )
        }
        let antiGlaette = antiGlaetteFindings(in: sample)
        if !antiGlaette.isEmpty {
            issues.append(
                "Der Romananfang erklärt sichtbare Handlung nachträglich oder baut einen künstlichen Erkenntnis-Haken. Lass die konkrete Folge stehen, statt ihre Bedeutung auszuformulieren."
            )
        }
        // Ein einzelner langer Satz oder eine kurze Stakkato-Passage kann als bewusstes
        // Spannungssignal funktionieren. Erst ein wiederkehrendes Muster blockiert die
        // Freigabe des gesamten Blick-ins-Buch-Ausschnitts.
        if schwerLesbareSaetze(in: sample).count >= 2 {
            issues.append(
                "Der Romananfang enthaelt mehrere schwer lesbare Bandwurmsaetze."
            )
        }
        if stakkatoKetten(in: sample) >= 2 {
            issues.append(
                "Der Romananfang enthaelt mehrfach monotone Ketten aus sehr kurzen Saetzen."
            )
        }

        var seen = Set<String>()
        return issues.filter { seen.insert($0).inserted }.prefix(6).map { $0 }
    }

    /// Meldet nur eindeutige Tempuswechsel im fruehen Erzaehltext.
    ///
    /// Deutsche Zeitformen lassen sich ohne morphologischen Parser nicht vollstaendig
    /// bestimmen. Deshalb ist dies absichtlich kein allgemeiner Grammatikrichter: Dialog
    /// wird entfernt, geprueft werden nur die ersten 140 Woerter, und ein einzelnes
    /// Gegenwartsverb gilt erst zusammen mit mindestens zwei klaren
    /// Vergangenheitsformen als Wechsel. So faellt „Der Becher kuehlt ... Alva stand ..."
    /// auf, waehrend ein eingeschobener allgemeiner Satz allein nicht blockiert.
    static func narrativeTenseIssues(in text: String, expectedTense: String) -> [String] {
        func normalizedGerman(_ value: String) -> String {
            value.lowercased()
                .replacingOccurrences(of: "ä", with: "ae")
                .replacingOccurrences(of: "ö", with: "oe")
                .replacingOccurrences(of: "ü", with: "ue")
                .replacingOccurrences(of: "ß", with: "ss")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        let ohneDialog = text.replacingOccurrences(
            of: #"[\"„“»«][^\"„“»«]*[\"„“»«]"#,
            with: " ", options: .regularExpression
        )
        let sample = normalizedGerman(
            ohneDialog.split(whereSeparator: \.isWhitespace)
                .prefix(140).joined(separator: " ")
        )
        let woerter = sample.components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        let gegenwart: Set<String> = [
            "steht", "geht", "sitzt", "liegt", "haelt", "nimmt", "oeffnet", "sagt",
            "fragt", "sieht", "hoert", "spuert", "fuehlt", "weiss", "muss", "will",
            "kann", "kommt", "bleibt", "laeuft", "zieht", "dreht", "greift", "klopft",
            "kuehlt", "haengt", "traegt", "blickt", "wartet", "atmet", "laechelt",
            "schliesst", "stellt", "legt", "merkt", "holt", "tritt",
        ]
        let vergangenheit: Set<String> = [
            "stand", "ging", "sass", "lag", "hielt", "nahm", "oeffnete", "sagte",
            "fragte", "sah", "hoerte", "spuerte", "fuehlte", "wusste", "musste",
            "wollte", "konnte", "kam", "blieb", "lief", "zog", "drehte", "griff",
            "klopfte", "kuehlte", "hing", "trug", "blickte", "wartete", "atmete",
            "laechelte", "schloss", "stellte", "legte", "merkte", "holte", "trat",
        ]
        let praesensTreffer = woerter.filter(gegenwart.contains).count
        let praeteritumTreffer = woerter.filter(vergangenheit.contains).count
        let erwartet = normalizedGerman(expectedTense)

        if (erwartet.contains("prater") || erwartet.contains("praeter")
            || erwartet.contains("vergangen")),
           praesensTreffer >= 1, praeteritumTreffer >= 2 {
            return ["Der Einstieg wechselt trotz vorgegebenem Praeteritum in die Gegenwart."]
        }
        if (erwartet.contains("prasens") || erwartet.contains("praesens")
            || erwartet.contains("gegenwart")),
           praeteritumTreffer >= 2, praesensTreffer >= 1 {
            return ["Der Einstieg wechselt trotz vorgegebenem Praesens ins Praeteritum."]
        }
        return []
    }

    /// Endabnahme fuer zusammengesetzte Kapiteltexte. Jede neue Szene beginnt
    /// sprachlich neu und muss deshalb ein eigenes Tempusfenster bekommen; sonst
    /// verdecken die ersten 140 korrekten Kapitelwoerter einen spaeteren Neustart.
    static func narrativeTenseIssuesAcrossSections(in text: String,
                                                   expectedTense: String) -> [String] {
        let markers: Set<String> = ["***", "* * *", "###", "# # #", "---", "— — —"]
        var sections: [String] = []
        var current: [String] = []
        for line in text.components(separatedBy: .newlines) {
            if markers.contains(line.trimmingCharacters(in: .whitespacesAndNewlines)) {
                let section = current.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !section.isEmpty { sections.append(section) }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(line)
            }
        }
        let finalSection = current.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalSection.isEmpty { sections.append(finalSection) }
        if sections.isEmpty { sections = [text] }

        var findings: [String] = []
        for (sectionIndex, section) in sections.enumerated() {
            findings.append(contentsOf: narrativeTenseIssues(
                in: section, expectedTense: expectedTense
            ).map { "Abschnitt \(sectionIndex + 1): \($0)" })

            // Falls ein nachgelagerter Bereinigungsschritt den sichtbaren Szenenmarker
            // entfernt hat, bleiben Absatzgrenzen erhalten. Der erste Absatz steckt
            // bereits im Abschnittsfenster; spaetere laengere Absaetze separat pruefen.
            let paragraphs = section.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.wordCount >= 12 }
            for (paragraphIndex, paragraph) in paragraphs.dropFirst().enumerated() {
                findings.append(contentsOf: narrativeTenseIssues(
                    in: paragraph, expectedTense: expectedTense
                ).map {
                    "Abschnitt \(sectionIndex + 1), Absatz \(paragraphIndex + 2): \($0)"
                })
            }
        }
        return Array(findings.prefix(8))
    }

    struct CharacterNameOveruseFinding {
        let chapterIndex: Int
        let characterName: String
        let paragraphIndices: [Int]
        let maximumMentions: Int
    }

    /// Findet Abschnitte, in denen der Figurenname wie ein mechanischer Ersatz fuer
    /// Pronomen gehaemmert wird. Normale Namensnennung bleibt erlaubt; blockiert
    /// werden nur mindestens drei Nennungen in einem kurzen Absatz oder sechs in
    /// zwei direkt aufeinanderfolgenden Abschnitten.
    static func characterNameOveruseFindings(inChapters chapters: [String],
                                              characterNames: [String])
        -> [CharacterNameOveruseFinding] {
        let canonical: [(full: String, token: String)] = characterNames.compactMap { name in
            let token = name.split(whereSeparator: \.isWhitespace).first.map(String.init)?
                .trimmingCharacters(in: CharacterSet.letters.inverted) ?? ""
            guard token.count >= 3 else { return nil }
            return (name, token)
        }
        guard !canonical.isEmpty else { return [] }

        func count(_ token: String, in text: String) -> Int {
            let escaped = NSRegularExpression.escapedPattern(for: token)
            guard let expression = try? NSRegularExpression(
                pattern: "(?<![\\p{L}])\(escaped)(?![\\p{L}])",
                options: [.caseInsensitive]
            ) else { return 0 }
            let ns = text as NSString
            return expression.numberOfMatches(
                in: text, range: NSRange(location: 0, length: ns.length)
            )
        }

        var findings: [CharacterNameOveruseFinding] = []
        for (chapterIndex, chapter) in chapters.enumerated() {
            let paragraphs = chapter.components(separatedBy: "\n\n")
            for character in canonical {
                let mentions = paragraphs.map { count(character.token, in: $0) }
                var affected = Set<Int>()
                var maximum = mentions.max() ?? 0

                for (index, paragraph) in paragraphs.enumerated() {
                    let words = max(1, paragraph.wordCount)
                    if mentions[index] >= 4
                        || (mentions[index] >= 3 && words <= 140) {
                        affected.insert(index)
                    }
                }
                if paragraphs.count >= 2 {
                    for index in 0..<(paragraphs.count - 1) {
                        let combinedMentions = mentions[index] + mentions[index + 1]
                        let combinedWords = paragraphs[index].wordCount
                            + paragraphs[index + 1].wordCount
                        maximum = max(maximum, combinedMentions)
                        if combinedMentions >= 6 && combinedWords <= 280 {
                            affected.insert(index)
                            affected.insert(index + 1)
                        }
                    }
                }
                // Verteiltes Namenshaemmern: Ein Modell kann jeden kurzen Absatz mit
                // „Alva ..." beginnen und bleibt trotzdem unter der alten Grenze von drei
                // Nennungen PRO Absatz. Ein gleitendes Fenster macht dieses deutlich
                // maschinelle Muster sichtbar, ohne einen langen Dialogabsatz zu bestrafen.
                if paragraphs.count >= 3 {
                    for start in paragraphs.indices {
                        var words = 0
                        var totalMentions = 0
                        var window: [Int] = []
                        for end in start..<paragraphs.count {
                            let paragraphWords = paragraphs[end].wordCount
                            if words + paragraphWords > 480, words >= 220 { break }
                            words += paragraphWords
                            totalMentions += mentions[end]
                            window.append(end)
                            guard words >= 220 else { continue }
                            let rate = Double(totalMentions) * 1_000.0 / Double(max(1, words))
                            if totalMentions >= 7, rate >= 18.0 {
                                for index in window where mentions[index] > 0 {
                                    affected.insert(index)
                                }
                                maximum = max(maximum, totalMentions)
                                break
                            }
                        }
                    }
                }
                if !affected.isEmpty {
                    findings.append(CharacterNameOveruseFinding(
                        chapterIndex: chapterIndex,
                        characterName: character.full,
                        paragraphIndices: affected.sorted(),
                        maximumMentions: maximum
                    ))
                }
            }
        }
        return findings
    }

    /// Fremdwörter und Fachbegriffe, über die ein normaler Leser stolpert.
    ///
    /// Gemessen an den bisherigen Büchern: „Deprivation" stand fünfmal im Text, dazu
    /// Halluzination, Radiologie, Passivität, Neutralität. Ein Roman soll sich flüssig
    /// lesen lassen – wer nachschlagen muss, hört auf zu lesen. Erkannt wird über
    /// typische Fremdwort-Endungen; Alltagswörter mit denselben Endungen stehen in der
    /// Ausnahmeliste, damit „Moment" oder „Restaurant" nie anschlagen.
    static func schwereFremdwoerter(in text: String) -> [String] {
        let endungen = ["ation", "ismus", "ität", "ivität", "ologie", "ogie", "esk",
                        "abel", "ibel", "uell", "ual", "anz", "enz", "ismen", "atorisch",
                        "iv", "ös"]
        // Wörter, die jeder kennt – die dürfen nie als Fremdwort gelten.
        let alltag: Set<String> = [
            "moment", "restaurant", "apartment", "talent", "prozent", "patient",
            "station", "situation", "information", "nation", "portion", "position",
            "aktiv", "passiv", "motiv", "negativ", "positiv", "relativ", "intensiv",
            "nervös", "religiös", "chance", "distanz", "substanz", "instanz", "allianz",
            "eleganz", "akzeptanz", "existenz", "konsequenz", "differenz", "konferenz",
            "sequenz", "frequenz", "tendenz", "präsenz", "essenz", "agentur", "natur",
            "kultur", "struktur", "temperatur", "figur", "spur", "tour", "büro",
            "energie", "familie", "linie", "serie", "melodie", "fantasie", "garantie",
            "batterie", "galerie", "industrie", "kopie", "therapie", "biologie",
            "qualität", "realität", "universität", "aktivität", "identität", "autorität",
            "reaktion", "aktion", "funktion", "tradition",
            "million", "region", "religion", "version", "explosion", "vision",
            "adresse", "kaffee", "hotel", "hotels", "material", "normal", "total",
            "spezial", "sozial", "digital", "signal", "kanal", "lokal", "brutal",
            "fatal", "banal", "global", "individuell", "aktuell", "sensibel", "stabil",
            "archiv", "migration", "motiv", "massiv", "explosiv", "effektiv", "attraktiv",
            "konservativ", "kreativ", "objektiv", "subjektiv", "perspektiv", "detektiv"
        ]
        var gefunden: [String] = []
        var gesehen = Set<String>()
        for wort in text.components(separatedBy: CharacterSet.letters.inverted)
        where wort.count >= 9 {
            let klein = wort.lowercased()
            guard !alltag.contains(klein) else { continue }
            // Zusammensetzungen mit einem bekannten Alltagswort am Ende durchlassen
            // („Aufnahmestation", „Stadtarchiv").
            guard !alltag.contains(where: { klein.hasSuffix($0) && $0.count >= 5 }) else { continue }
            guard endungen.contains(where: { klein.hasSuffix($0) }) else { continue }
            guard gesehen.insert(klein).inserted else { continue }
            gefunden.append(wort)
        }
        return gefunden
    }

    /// Szenenziele, die ein bereits geplantes Ereignis wiederholen.
    ///
    /// Der Grund, warum sich Kapitel wie Varianten voneinander lesen: Gemessen an einem
    /// laufenden Buch waren die Ziele von K1S1–S4 und K2S1–S4 zu 100 % identisch
    /// („EINSTIEG: Die Perspektivfigur betritt die Ausgangslage …") – generische
    /// Schablonen statt echter Pläne. Dazu echte Doppelungen wie „Ordner öffnen und
    /// Janas Tod verstehen" in Kapitel 3 und erneut in Kapitel 6.
    ///
    /// **Abgrenzung zu `EreignisRegister`.** Beide suchen doppelte Ereignisse, an
    /// verschiedenen Stellen und mit verschiedener Datenbasis – sie ersetzen einander
    /// nicht, und sie können sich auch nicht widersprechen, weil diese Prüfung den Plan
    /// verwirft und der Aufrufer dann sofort zurückkehrt:
    ///
    /// | | diese Funktion | `EreignisRegister` |
    /// |---|---|---|
    /// | Datenbasis | nur das Ziel | Ziel + Hindernis + Wendung |
    /// | Wirkung | verwirft den Plan | meldet und warnt den Schreiber |
    /// | Perspektive | ignoriert | Perspektivwechsel ist erlaubt |
    /// | Nachklang | ignoriert | ausgenommen |
    /// | Schablonen | erkennt leere Muster | – |
    ///
    /// Gemessen an acht Szenenpaaren: Auf dem Ziel allein liegt die Register-Schwelle
    /// falsch (zwei Fehlalarme), weil ein Ziel zu wenig Wörter hat; auf dem vollen Tripel
    /// trennt sie sauber. Deshalb bleibt hier die eigene Schwelle stehen.
    ///
    /// - Returns: Die Ziele, die zu nah an einem früheren liegen, mit Fundstelle.
    static func doppelteSzenenziele(neueZiele: [String], bekannteZiele: [String],
                                    schwelle: Double = 0.55) -> [String] {
        func kern(_ t: String) -> Set<String> {
            Set(t.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 5 })
        }
        // Schablonen-Präfixe zählen nicht als Inhalt – sie stehen in jedem Plan.
        let schablonen = ["einstieg", "komplikation", "zuspitzung", "wende und übergang",
                          "wende", "übergang", "perspektivfigur", "ausgangslage"]
        func inhalt(_ t: String) -> Set<String> {
            kern(t).subtracting(schablonen)
        }
        var treffer: [String] = []
        let bekannt = bekannteZiele.map(inhalt)
        for ziel in neueZiele {
            let a = inhalt(ziel)
            guard a.count >= 3 else {
                treffer.append("\(ziel.prefix(60)) – leere Schablone ohne konkretes Ereignis")
                continue
            }
            for b in bekannt where b.count >= 3 {
                // Nicht die reine Mengenschnittmenge: Die scheiterte messbar an zwei
                // Eigenheiten des Deutschen. „Sie will die Bienenstöcke öffnen" gegen
                // „Sie möchte die Stöcke öffnen" ergab 0 Überlappung (Kompositum), und
                // „verschlossene Schublade" gegen „verschlossenen Schubladen" ebenfalls
                // (Flexion). Beides sind eindeutige Dopplungen, beide liefen durch.
                // `EreignisRegister.passen` löst genau dieses Problem und ist dort an
                // Beispielen kalibriert – eine zweite Kopie würde nur auseinanderdriften.
                var frei = b
                var paarungen = 0
                for wort in a.sorted(by: { $0.count > $1.count }) {
                    guard let partner = frei.first(where: {
                        EreignisRegister.passen(wort, $0)
                    }) else { continue }
                    frei.remove(partner)
                    paarungen += 1
                }
                let ov = Double(paarungen) / Double(min(a.count, b.count))
                if ov > schwelle {
                    treffer.append("\(ziel.prefix(60)) – wiederholt ein bereits geplantes Ereignis")
                    break
                }
            }
        }
        return treffer
    }

    // MARK: - Stimmungsklischees und Handlungsschleifen
    //
    // Gemessen über 176.778 Wörter aller bisherigen Bücher: „Licht" 309-mal,
    // „Atem" 251-mal, „Stille" 137-mal, „Kälte" 134-mal – und die Wendung
    // „die Tür fiel ins Schloss" 93-mal. Diese Wörter sind nicht verboten, ein Roman
    // braucht sie. Sie dürfen nur nicht die Stelle einnehmen, an der ein konkretes
    // Geräusch, ein Geruch oder eine Handlung stehen müsste.

    /// Stimmungswörter, die ihr Budget überschreiten.
    ///
    /// Budget je 10.000 Wörter, kalibriert am gemessenen Ist-Zustand: Was aktuell
    /// bei 17 liegt, wird auf 4 begrenzt – streng genug, um den Reflex zu brechen,
    /// weit genug, damit legitime Verwendungen bleiben.
    /// - Parameter priorTexts: Der bisherige Buchtext. Das Budget gilt für das GANZE
    ///   Buch, nicht je Szene – sonst scheitert bei 600-Wort-Szenen jedes Budget an der
    ///   Rundung auf 1 und die Produktion erstickt (gemessen: 191 von 282 Szenen).
    static func stimmungsklischees(in text: String, priorTexts: [String] = []) -> [String] {
        let bisher = priorTexts.joined(separator: " ")
        let gesamt = bisher.isEmpty ? text : bisher + " " + text
        let woerter = gesamt.wordCount
        guard woerter >= 150 else { return [] }
        // (Wortstamm, erlaubte Treffer je 10.000 Wörter)
        let budgets: [(String, Double)] = [
            ("licht", 4), ("atem", 4), ("stille", 2), ("kälte", 2), ("kalt", 4),
            ("leere", 1.5), ("schatten", 2), ("echo", 0.5), ("frequenz", 0.3),
            ("dunkel", 3), ("unbeschreiblich", 0.2), ("tiefgründig", 0.2),
            ("unendlich", 0.5), ("schweigen", 3), ("flacker", 0.5)
        ]
        var treffer: [String] = []
        let faktor = Double(woerter) / 10_000.0
        for (stamm, proZehntausend) in budgets {
            // Mindestens 8 Vorkommen sind immer frei. Ohne diese Untergrenze liegt
            // das Budget am Buchanfang rechnerisch bei 1 und die Prüfung schlägt bei
            // fast jeder Szene an (gemessen: 36 von 40) – die Produktion erstickt,
            // bevor überhaupt ein Reflex entstehen kann.
            let erlaubt = max(8, Int((proZehntausend * faktor).rounded()))
            guard let re = try? NSRegularExpression(pattern: stamm, options: [.caseInsensitive])
            else { continue }
            let ns = gesamt as NSString
            let n = re.numberOfMatches(in: gesamt, range: NSRange(location: 0, length: ns.length))
            // Nur melden, wenn die NEUE Szene selbst dazu beiträgt – sonst schlägt die
            // Prüfung ewig an, obwohl die aktuelle Szene das Wort gar nicht benutzt.
            let nsNeu = text as NSString
            let imNeuen = re.numberOfMatches(in: text, range: NSRange(location: 0, length: nsNeu.length))
            if n > erlaubt, imNeuen > 0 {
                treffer.append("\(stamm): \(n)x im Buch (Budget \(erlaubt))")
            }
        }
        return treffer
    }

    /// Handlungen, die als Reflex immer wiederkehren.
    ///
    /// Nicht einzelne Wörter, sondern ganze Gesten: aufs Handy sehen, den Schlüssel
    /// umfassen, Sekunden zählen, die Tür ins Schloss fallen lassen. Über alle Bücher
    /// hinweg 93-mal dieselbe Türformel.
    static func handlungsSchleifen(in text: String) -> [String] {
        let woerter = text.wordCount
        guard woerter >= 150 else { return [] }
        let muster: [(String, String)] = [
            (#"(Tür|Türe)[^.!?]{0,40}(fiel|schloss|klickte)"#, "Tür fällt ins Schloss"),
            (#"(zählte|zählt)[^.!?]{0,25}(bis|Sekunden|Atemzüge|Schritte)"#, "Sekunden/Atemzüge zählen"),
            (#"(hielt|hält)[^.!?]{0,12}Atem an"#, "den Atem anhalten"),
            (#"(sah|schaute|blickte)[^.!?]{0,25}(Handy|Display|Telefon|Uhr)"#, "aufs Handy/die Uhr sehen"),
            (#"Schlüssel[^.!?]{0,30}(Hand|Tasche|umschloss|drück|berühr)"#, "den Schlüssel umfassen"),
            (#"(hob|zuckte)[^.!?]{0,15}Schultern"#, "Schultern zucken"),
            (#"(strich|fuhr)[^.!?]{0,25}(Haar|Nacken|Stirn)"#, "durchs Haar fahren"),
            (#"(?:Telefon[^.!?]{0,24}klingel|klingel[^.!?]{0,24}Telefon)"#, "Telefon klingelt"),
            (#"(?:(?:ging|stand|trat|kehrte|blickte|sah)[^.!?]{0,28}Fenster|Fenster[^.!?]{0,28}(?:ging|stand|trat|blickte|sah))"#, "ans Fenster zurückkehren"),
            (#"(schluckte|räusperte sich)"#, "schlucken/räuspern")
        ]
        var treffer: [String] = []
        let ns = text as NSString
        for (regex, name) in muster {
            guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
            else { continue }
            let n = re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
            // In EINER Szene ist jede dieser Gesten höchstens einmal vertretbar.
            if n > 1 { treffer.append("\(name) \(n)x") }
        }
        return treffer
    }

    /// Handlungen dieser Szene, die im Buch schon verbraucht sind.
    ///
    /// Das ist die „Global Motif List": Was ein Kapitel an markanten Gesten benutzt
    /// hat, ist im nächsten gesperrt.
    static func verbrauchteHandlungen(candidate: String, priorTexts: [String]) -> [String] {
        let bisher = priorTexts.joined(separator: " ")
        let imBuch = Set(handlungsGrundformen(in: bisher))
        return handlungsGrundformen(in: candidate).filter { imBuch.contains($0) }
    }

    /// Erkennt die Grundform markanter Gesten – unabhängig von Häufigkeit.
    private static func handlungsGrundformen(in text: String) -> [String] {
        let muster: [(String, String)] = [
            (#"(Tür|Türe)[^.!?]{0,40}(fiel|schloss|klickte)"#, "Tür fällt ins Schloss"),
            (#"(zählte|zählt)[^.!?]{0,25}(bis|Sekunden|Atemzüge|Schritte)"#, "Zählen als Beruhigung"),
            (#"(hielt|hält)[^.!?]{0,12}Atem an"#, "Atem anhalten"),
            (#"(sah|schaute|blickte)[^.!?]{0,25}(Handy|Display|Telefon)"#, "aufs Handy sehen"),
            (#"Schlüssel[^.!?]{0,30}(Hand|Tasche|umschloss|drück)"#, "Schlüssel umfassen"),
            (#"(hob|zuckte)[^.!?]{0,15}Schultern"#, "Schultern zucken"),
            (#"(strich|fuhr)[^.!?]{0,25}(Haar|Nacken|Stirn)"#, "durchs Haar fahren"),
            (#"(?:Telefon[^.!?]{0,24}klingel|klingel[^.!?]{0,24}Telefon)"#, "Telefon klingelt"),
            (#"(?:(?:ging|stand|trat|kehrte|blickte|sah)[^.!?]{0,28}Fenster|Fenster[^.!?]{0,28}(?:ging|stand|trat|blickte|sah))"#, "ans Fenster zurückkehren"),
            (#"Etikett[^.!?]{0,30}(juck|kratz|drück|Nacken)"#, "juckendes Etikett"),
            (#"Narbe[^.!?]{0,25}(juck|brenn|zieh|Handgelenk)"#, "juckende Narbe"),
            (#"(Tasse|Becher)[^.!?]{0,30}(abgeplatzt|Rand|Kante)"#, "abgeplatzter Tassenrand")
        ]
        var gefunden: [String] = []
        let ns = text as NSString
        for (regex, name) in muster {
            guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
            else { continue }
            if re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil {
                gefunden.append(name)
            }
        }
        return gefunden
    }

    /// Ersetzt Namen im FERTIGEN Szenentext, die nicht zur Figurenliste gehören.
    ///
    /// Der entscheidende Unterschied zu allen bisherigen Namenssperren: Die haben den
    /// PLAN geprüft (Ideenfindung, Figurenerzeugung) und dem Modell Anweisungen gegeben.
    /// Anweisungen sind Bitten – gemessen an einem Testbuch stand „Liv" 263-mal im Text,
    /// obwohl die Figurenliste Naja, Aksel und Freja nannte. Der Draft Writer erfindet
    /// beim Schreiben eigene Namen, und keine Prompt-Regel hält ihn auf.
    ///
    /// Diese Funktion bittet nicht, sie ersetzt. Gefunden wird nur, was in einem
    /// FRÜHEREN Buch schon Figurenname war und im aktuellen nicht vorkommt.
    ///
    /// - Parameters:
    ///   - text: Der geschriebene Szenentext.
    ///   - erlaubteNamen: Namen aus der Story Bible dieses Buchs.
    ///   - fremdeNamen: Namensteile aus früheren Büchern (kleingeschrieben).
    /// - Returns: Der korrigierte Text und die vorgenommenen Ersetzungen.
    static func ersetzeFremdeNamen(in text: String, erlaubteNamen: [String],
                                   fremdeNamen: Set<String>) -> (text: String, ersetzt: [String]) {
        // Erlaubte Namensteile sammeln – die dürfen natürlich vorkommen.
        var erlaubteTeile = Set<String>()
        for name in erlaubteNamen {
            for teil in name.split(separator: " ") {
                let t = String(teil).trimmingCharacters(in: CharacterSet.letters.inverted)
                if t.count >= 3 { erlaubteTeile.insert(t.lowercased()) }
            }
        }
        // Ersatz ist der Vorname der ersten Figur aus der Liste.
        guard let ersatzVoll = erlaubteNamen.first,
              let ersatz = ersatzVoll.split(separator: " ").first.map(String.init),
              !ersatz.isEmpty else { return (text, []) }

        var ergebnis = text
        var ersetzt: [String] = []
        // Nur Namen aus früheren Büchern anfassen, die hier NICHT erlaubt sind.
        for fremd in fremdeNamen where !erlaubteTeile.contains(fremd) {
            guard fremd.count >= 3 else { continue }
            let gross = fremd.prefix(1).uppercased() + fremd.dropFirst()
            // DEUTSCHE FLEXION MITNEHMEN. Eine reine Wortgrenze traf nur „Liv" –
            // der Genitiv „Livs" und der Dativ „Liven" blieben stehen. Die Endung
            // wird erfasst und an den Ersatznamen weitergereicht, damit aus
            // „Livs Hand" nicht „Naja Hand" wird, sondern „Najas Hand".
            //
            // Wortgrenze vorn und hinten verhindert Treffer in „Lieferung" oder
            // „Miranda".
            guard let re = try? NSRegularExpression(
                pattern: "\\b\(gross)(s|en|n|e)?\\b")
            else { continue }
            let ns = ergebnis as NSString
            let treffer = re.matches(in: ergebnis,
                                     range: NSRange(location: 0, length: ns.length))
            guard !treffer.isEmpty else { continue }
            // Von hinten ersetzen, damit die Bereiche gültig bleiben.
            var neuerText = ergebnis
            for m in treffer.reversed() {
                let endung = m.range(at: 1).location == NSNotFound
                    ? "" : (ergebnis as NSString).substring(with: m.range(at: 1))
                let voll = (neuerText as NSString)
                neuerText = voll.replacingCharacters(in: m.range, with: ersatz + endung)
            }
            ergebnis = neuerText
            ersetzt.append("\(gross) → \(ersatz) (\(treffer.count)x)")
        }
        return (ergebnis, ersetzt)
    }

    /// Meldet katalogweit gesperrte Namen im Szenentext, ohne sie blind durch die
    /// erstbeste aktuelle Figur zu ersetzen. Ein solcher Austausch verwandelte etwa
    /// eine neu erfundene "Silke" in den Notar "Neumann" und beschaedigte dadurch
    /// Handlung und Geschlecht der Figur. Der richtige Weg ist Neuschreiben.
    static func foreignCatalogNameMentions(in text: String, allowedNames: [String],
                                           forbiddenNames: Set<String>) -> [String] {
        let allowed = Set(allowedNames.flatMap(CharacterCanonAudit.nameParts))
        return forbiddenNames.compactMap { raw -> String? in
            let name = raw.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased()
            guard name.count >= 3, !allowed.contains(name) else { return nil }
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let normalizedText = text.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased()
            let pattern = #"\b"# + escaped + #"(?:s|en|n|e)?\b"#
            return normalizedText.range(of: pattern, options: .regularExpression) != nil
                ? raw : nil
        }.sorted()
    }

    /// Erkennt gesperrte, grossgeschriebene Namen in Planfeldern deterministisch.
    /// NaturalLanguage uebersieht seltene Nachnamen wie "Broesel"; reine Berufswoerter
    /// nach einem Artikel ("Der Weber arbeitet") bleiben dagegen unangetastet.
    static func scenePlanForeignCatalogNames(in text: String,
                                             allowedNames: [String],
                                             forbiddenNames: Set<String>) -> [String] {
        func normalized(_ value: String) -> String {
            value.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased()
        }
        let allowed = Set(allowedNames.flatMap(CharacterCanonAudit.nameParts).map(normalized))
        let forbiddenByNormalized = Dictionary(
            uniqueKeysWithValues: forbiddenNames.map { (normalized($0), $0) }
        )
        let tokens = text.components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        let articles: Set<String> = [
            "der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer"
        ]
        var found = Set<String>()
        for index in tokens.indices {
            let token = tokens[index]
            guard token.first?.isUppercase == true else { continue }
            let raw = normalized(token)
            let candidates = [raw] + ["s", "en", "n", "e"].compactMap { suffix -> String? in
                raw.hasSuffix(suffix) && raw.count > suffix.count + 2
                    ? String(raw.dropLast(suffix.count)) : nil
            }
            guard let key = candidates.first(where: { forbiddenByNormalized[$0] != nil }),
                  !allowed.contains(key) else { continue }
            let previous = index > tokens.startIndex ? normalized(tokens[index - 1]) : ""
            guard !articles.contains(previous) else { continue }
            if let original = forbiddenByNormalized[key] { found.insert(original) }
        }
        return found.sorted()
    }

    /// Letzte deterministische Korrektur fuer vom Modell neu erfundene Altbuchnamen.
    /// Der Austausch geschieht nur fuer Namen, die auch die harte Speicherpruefung als
    /// Person bestaetigt; Kanonnamen und bereits im Szenenkontext belegte Namen bleiben.
    static func sanitizingDraftCatalogNames(
        in text: String,
        targetWords: Int,
        allowedNames: [String],
        forbiddenNames: Set<String>,
        occupiedContext: String,
        seed: UUID
    ) -> (text: String, replacements: [String: String]) {
        _ = targetWords
        let personParts = Set(
            CharacterCanonAudit.personNames(in: text)
                .flatMap(CharacterCanonAudit.nameParts)
        )
        let collisions = foreignCatalogNameMentions(
            in: text,
            allowedNames: allowedNames,
            forbiddenNames: forbiddenNames
        ).filter { raw in
            !Set(CharacterCanonAudit.nameParts(raw)).isDisjoint(with: personParts)
        }
        guard !collisions.isEmpty else { return (text, [:]) }

        let occupied = occupiedContext.components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 }
            .map {
                $0.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()
            }
        let replacements = StoryMemory.sichereSzenenplanNamensErsetzungen(
            collisions,
            vergeben: forbiddenNames.union(occupied),
            streuung: seed
        )
        guard replacements.count == Set(collisions.map { $0.lowercased() }).count else {
            return (text, [:])
        }
        return (
            CharacterCanonAudit.replacingNames(in: text, replacements: replacements),
            replacements
        )
    }

    /// Konkrete Rueckmeldung fuer den naechsten Szenenentwurf.
    ///
    /// Ein allgemeines "ungeplante Figur entfernen" reicht nicht: Im Live-Lauf wurde
    /// derselbe gesperrte Name dadurch in drei Fassungen wiederholt. Der Retry muss die
    /// tatsaechlich beanstandeten Namen und Gegenstaende sehen, darf aber keinen davon
    /// blind durch eine andere Figur ersetzen.
    static func draftRetryPlanViolationHint(unexpectedCharacters: [String],
                                            unexpectedArtifacts: [String]) -> String {
        let characters = Array(Set(unexpectedCharacters.filter { !$0.isEmpty })).sorted()
        let artifacts = Array(Set(unexpectedArtifacts.filter { !$0.isEmpty })).sorted()
        guard !characters.isEmpty || !artifacts.isEmpty else { return "" }

        var lines = [
            "PLANVERSTOSS: Der vorige Text enthielt Elemente, die in dieser Szene nicht erlaubt sind."
        ]
        if !characters.isEmpty {
            lines.append(
                "KONKRET VERBOTENE NAMEN ODER FIGUREN (nicht erneut verwenden): "
                    + characters.prefix(8).joined(separator: ", ")
            )
        }
        if !artifacts.isEmpty {
            lines.append(
                "KONKRET VERBOTENE GEGENSTAENDE (nicht erneut verwenden): "
                    + artifacts.prefix(8).joined(separator: ", ")
            )
        }
        lines.append(
            "Ersetze keinen Namen mechanisch. Verwende ausschliesslich bereits erlaubte Figuren "
                + "und Elemente aus Szenenziel, Hindernis, Wendung und bisheriger Handlung."
        )
        return "\n\n" + lines.joined(separator: "\n")
    }

    // MARK: - Algorithmische Ticks
    //
    // Eine externe Analyse fand vier Muster, die sich durch ALLE Bücher ziehen –
    // gemessen an einem Buch mit 45.194 Wörtern: „zählen" 46-mal, „kribbeln/taub"
    // 40-mal, 37 Drei-Wort-Listen. Jede Hauptfigur zählt Dinge und hat taube Finger,
    // egal ob Taucherin, Dolmetscherin oder Fotografin. Das ist kein Stil, das ist
    // ein Werkzeugkasten, in den das Modell immer wieder greift.

    /// Zähl-Zwang: Figuren, die Atemzüge, Sekunden, Fliesen oder Stufen zählen.
    static func zaehlZwang(in text: String) -> Int {
        guard let re = try? NSRegularExpression(
            pattern: #"z(ä|a)hlt?e?\b"#, options: [.caseInsensitive]) else { return 0 }
        let ns = text as NSString
        return re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
    }

    /// Körperliche Ticks, die in jedem Buch identisch auftauchen.
    static func koerperTicks(in text: String) -> [String] {
        let muster: [(String, String)] = [
            (#"(kribbel|prickel)"#, "kribbelnde Gliedmaßen"),
            (#"\btaub\w*\b"#, "taube Finger/Hände"),
            (#"(zitter|beb)te?\w*"#, "zitternde Hände"),
            (#"Zähne[^.!?]{0,15}klapper"#, "klappernde Zähne"),
            (#"Nervenbahn"#, "abgestorbene Nervenbahn"),
            (#"(Puls|Herz)[^.!?]{0,15}(hämmer|raste|schlug schneller)"#, "hämmernder Puls")
        ]
        var treffer: [String] = []
        let ns = text as NSString
        for (regex, name) in muster {
            guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
            else { continue }
            let n = re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
            if n > 0 { treffer.append("\(name) (\(n)x)") }
        }
        return treffer
    }

    /// Dreier-Aufzählungen: „Stein, kalt und scharf", „Diesel, Zwiebeln und Salz".
    ///
    /// Ein erkennbares Muster: Statt eines starken Eindrucks werden drei aufgereiht.
    static func dreiWortListen(in text: String) -> [String] {
        guard let re = try? NSRegularExpression(
            pattern: #"\b\w{3,},\s+\w{3,}\s+und\s+\w{3,}\b"#) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    /// EIN körperliches Merkmal je Buch – deterministisch aus der Buchnummer.
    ///
    /// Ohne Vorgabe bekommt jede Hauptfigur dieselben tauben Finger. Mit Vorgabe hat
    /// jedes Buch ein eigenes, dezentes Merkmal, das nicht zum Dauerreflex wird.
    static func koerperMerkmal(fuerBuchNummer nummer: Int) -> String {
        let merkmale = [
            "eine Narbe an der Augenbraue, die bei Kälte weiß anläuft",
            "ein steifes Knie, das beim Treppensteigen knackt",
            "ein Ohr, auf dem sie schlecht hört und das sie unbewusst vordreht",
            "raue Handflächen von jahrelanger Arbeit, die an Stoff hängenbleiben",
            "ein Zahn, der auf Süßes reagiert",
            "eine Sehne am Handgelenk, die springt, wenn sie greift",
            "trockene Lippen, die sie sich nie eincremt",
            "ein Muttermal am Hals, das andere zuerst sehen",
            "kalte Füße, egal bei welcher Temperatur",
            "eine heisere Stimme am Morgen, die sich erst freiräuspern muss"
        ]
        return merkmale[abs(nummer) % merkmale.count]
    }

    /// Orakel-Sätze: Figuren, die ihre eigene Geschichte deuten.
    ///
    /// „Das Schweigen war keine Garantie. Es war nur die einzige Währung, die sie
    /// besaß." – klingt beim ersten Mal klug, wirkt über ein ganzes Buch künstlich.
    /// Menschen unter Druck sprechen kurz und banal; niemand erklärt mitten in der
    /// Angst die Bedeutung des eigenen Erlebens. Eine externe Manuskript-Analyse
    /// nannte genau das als zweitgrößten Hinweis auf maschinell erzeugten Text.
    ///
    /// Erkannt wird das Muster „abstrakter Begriff + Kopula + Deutung" – gemessen
    /// 16-mal in einem Testbuch.
    static func orakelSaetze(in text: String) -> [String] {
        let abstrakta = ["schweigen", "stille", "angst", "wahrheit", "vertrauen",
                         "erinnerung", "trauer", "schuld", "hoffnung", "liebe",
                         "verlust", "einsamkeit", "leere", "freiheit", "gewissheit"]
        let kopula = [" war ", " ist ", " bedeutete ", " bedeutet ", " blieb "]
        return saetzeAusText(text).filter { satz in
            let klein = satz.lowercased()
            let woerter = satz.split(separator: " ").count
            // Kurze bis mittlere Sätze; lange sind meist echte Handlung.
            guard (4...22).contains(woerter) else { return false }
            guard abstrakta.contains(where: { klein.contains($0) }) else { return false }
            guard kopula.contains(where: { klein.contains($0) }) else { return false }
            // Deutungsmarker: Genau sie machen aus einer Aussage eine Sentenz.
            let marker = ["keine ", "kein ", "nur ", "einzige", "eigentlich", "immer ",
                          "niemals", "nichts als", "letztlich", "am ende"]
            return marker.contains { klein.contains($0) }
        }
    }

    /// Ein zur Szene passender Wahrnehmungsfokus, ohne Pflicht-Gimmicks.
    ///
    /// Frueher erzwang dieser Block unpassende Erinnerungen, koerperliche Ablenkungen
    /// und schmutzige Details. Das machte Figuren unkonzentriert und Szenen willkuerlich.
    /// Jetzt darf ein Sinn nur dann hervortreten, wenn er Orientierung, Figur,
    /// Atmosphaere oder Handlung konkret staerkt.
    static func sinnesUndAssoziationsBrief(chapterNumber: Int, sceneNumber: Int) -> String {
        let sinne = [
            "Geruch oder Temperatur",
            "ein konkretes Geraeusch",
            "Oberflaeche, Gewicht oder Widerstand eines wichtigen Gegenstands",
            "Licht, Abstand oder Bewegung im Raum",
            "eine koerperliche Wahrnehmung, die aus der aktuellen Belastung folgt"
        ]
        let s = sinne[(chapterNumber * 3 + sceneNumber) % sinne.count]
        return """
        WAHRNEHMUNGSOPTION DIESER SZENE: \(s).
        Nutze hoechstens ein praezises Detail daraus, und nur wenn es aus Perspektive,
        Ort und aktueller Absicht der Figur natuerlich entsteht. Das Detail muss
        Orientierung, Beziehung, Atmosphaere oder Handlung tragen. Erfinde keine
        unpassende Erinnerung, koerperliche Marotte oder Ablenkung, nur um den Text
        individuell wirken zu lassen. Wenn der Szenenmoment keinen Sinnesakzent braucht,
        schreibe ohne ihn weiter.
        """
    }

    /// Prüft den Kapitelplan, BEVOR geschrieben wird.
    ///
    /// Ein schlechter Plan lässt sich durch gute Sätze nicht retten: Wenn zwei Kapitel
    /// dasselbe Ziel verfolgen oder der emotionale Stand sich nie ändert, entsteht genau
    /// die Handlungslethargie, die ein Lektorat an einem Testbuch bemängelte („Was hat
    /// sich in den letzten 50 Seiten geändert? Kaum etwas.").
    ///
    /// - Parameters:
    ///   - ziele: Kapitelziele in Reihenfolge.
    ///   - schritte: Emotionale Schritte in derselben Reihenfolge.
    /// - Returns: Klartext-Mängel; leer heißt: Der Plan trägt.
    static func kapitelplanMaengel(ziele: [String], schritte: [String]) -> [String] {
        var maengel: [String] = []
        let n = ziele.count
        guard n >= 4 else { return ["Zu wenige Kapitel für einen tragfähigen Bogen."] }

        func kern(_ s: String) -> Set<String> {
            Set(s.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 5 })
        }
        // 1. Zwei Kapitel dürfen nicht dasselbe wollen.
        for i in 0..<n {
            for j in (i + 1)..<n {
                let a = kern(ziele[i]), b = kern(ziele[j])
                guard a.count >= 3, b.count >= 3 else { continue }
                let überschneidung = Double(a.intersection(b).count) / Double(min(a.count, b.count))
                if überschneidung > 0.6 {
                    maengel.append("Kapitel \(i + 1) und \(j + 1) verfolgen praktisch dasselbe Ziel – eines davon bringt die Handlung nicht voran.")
                }
            }
        }
        // 2. Der emotionale Stand muss sich bewegen – sonst steht die Figur still.
        var gesehen = Set<String>()
        for (i, s) in schritte.enumerated() {
            let k = kern(s)
            guard !k.isEmpty else {
                maengel.append("Kapitel \(i + 1) hat keinen emotionalen Schritt.")
                continue
            }
            let schlüssel = k.sorted().joined(separator: " ")
            if !gesehen.insert(schlüssel).inserted {
                maengel.append("Kapitel \(i + 1) wiederholt den emotionalen Stand eines früheren Kapitels.")
            }
        }
        // 3. Dramaturgische Marken muessen vorhanden UND richtig angeordnet sein.
        let kapitelTexte = (0..<n).map { index in
            let schritt = index < schritte.count ? schritte[index] : ""
            return (ziele[index] + " " + schritt).lowercased()
        }
        func erstePosition(_ woerter: [String]) -> Int? {
            kapitelTexte.firstIndex { text in woerter.contains { text.contains($0) } }
        }
        // Allgemeine Verben wie "kippt" kommen schon in Erinnerungen, Stimmungen oder
        // Beziehungen vor und markierten dadurch faelschlich ein fruehes Kapitel als
        // Romanmitte. Nur eindeutige dramaturgische Bezeichnungen duerfen die Position
        // des Midpoints bestimmen; ein ausdrueckliches Label hat stets Vorrang.
        let midpoint = erstePosition(["midpoint"])
            ?? erstePosition(["zentrale wende", "spielregeln ändern", "spielregeln aendern"])
        let hoehepunkt = erstePosition(["höhepunkt", "hoehepunkt", "endkonfrontation", "finale konfrontation"])
        let aufloesung = erstePosition(["auflösung", "aufloesung", "neue normalität", "neue normalitaet", "ausklang"])

        for (marke, position) in [("Midpoint", midpoint), ("Höhepunkt", hoehepunkt),
                                  ("Auflösung", aufloesung)] where position == nil {
            maengel.append("Im Plan fehlt ein erkennbarer \(marke).")
        }
        if let midpoint, let hoehepunkt, let aufloesung {
            let fruehesterMidpoint = max(1, Int(Double(n) * 0.30))
            let spaetesterMidpoint = min(n - 2, Int(ceil(Double(n) * 0.70)) - 1)
            if midpoint < fruehesterMidpoint || midpoint > spaetesterMidpoint {
                maengel.append("Der Midpoint liegt in Kapitel \(midpoint + 1) statt im Mittelteil.")
            }
            if hoehepunkt <= midpoint || hoehepunkt < Int(Double(n) * 0.70) {
                maengel.append("Der Höhepunkt muss nach dem Midpoint im letzten Romandrittel liegen.")
            }
            if aufloesung <= hoehepunkt || aufloesung < Int(Double(n) * 0.80) {
                maengel.append("Die Auflösung muss nach dem Höhepunkt am Ende des Romans liegen.")
            }
        }
        return Array(maengel.prefix(6))
    }

    /// Prueft, ob das Schlusskapitel die Geschichte wirklich auszahlt.
    ///
    /// „Offenes Ende" ist nicht automatisch schlecht. Ein Unterhaltungsroman fuer KDP
    /// muss jedoch seinen zentralen Bandkonflikt beantworten; offene Serienfaeden duerfen
    /// erst danach bleiben. Diese Pruefung blockiert deshalb nur ausdrueckliche
    /// Nicht-Aufloesungen und Schlussplaene ohne konkrete Entscheidung oder Folge.
    static func finalChapterResolutionIssues(_ chapter: PlannedChapter) -> [String] {
        let combined = [chapter.goal, chapter.conflict, chapter.decision,
                        chapter.outcome, chapter.emotionalStep]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        var issues: [String] = []
        let unresolved = [
            "frage bleibt offen", "bleibt offen", "ohne antwort", "keine antwort",
            "nicht mit einer antwort", "frage selbst", "keine auflosung",
            "ohne auflosung", "endet nicht", "unvollendet", "unabgeschlossen",
            "nachste nacht konnte", "nachste nacht koennte", "erneut beginnt",
        ]
        if unresolved.contains(where: combined.contains) {
            issues.append("Das Schlusskapitel verweigert ausdruecklich die Aufloesung der zentralen Buchfrage.")
        }
        if chapter.decision.wordCount < 6 {
            issues.append("Im Schlusskapitel fehlt eine konkrete letzte Entscheidung der Hauptfigur.")
        }
        if chapter.outcome.wordCount < 8 {
            issues.append("Das Schlusskapitel zeigt keine konkrete Folge und keine neue Normalitaet.")
        }
        let consequenceMarkers = [
            "haft", "verurteilt", "freigesprochen", "verkauft", "verlasst", "verlaesst",
            "kehrt", "bleibt", "beginnt", "endet", "trennt", "versohnt", "versoehnt",
            "rettet", "verliert", "gewinnt", "zahlt", "zahlt", "sagt aus", "gesteht",
            "beerdigt", "zerstort", "zerstoert", "offnet", "oeffnet", "schliesst",
        ]
        if !consequenceMarkers.contains(where: {
            chapter.outcome.folding(
                options: [.caseInsensitive, .diacriticInsensitive], locale: .current
            ).lowercased().contains($0)
        }) {
            issues.append("Die Aufloesung benennt keine sichtbare, bleibende Konsequenz.")
        }
        return Array(Set(issues)).sorted()
    }

    /// Letzte, kanontreue Rettung fuer einen vollstaendigen Plan, dessen Schlussfolge
    /// nach zwei Modellreparaturen noch zu vage ist. Es wird ausschliesslich der bereits
    /// akzeptierte Aufloesungs-Beat des Plots eingesetzt; ein ausdruecklich offenes Ende
    /// oder ein ebenso vager Beat bleibt unveraendert und damit weiterhin gesperrt.
    static func finalChapterUsingCanonicalResolution(
        _ chapter: PlannedChapter,
        previous: PlannedChapter?,
        resolutionBeat: String
    ) -> PlannedChapter {
        let currentIssues = finalChapterResolutionIssues(chapter)
        guard !currentIssues.isEmpty,
              !currentIssues.contains(where: { $0.contains("verweigert ausdruecklich") })
        else { return chapter }

        let resolution = resolutionBeat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolution.wordCount >= 8 else { return chapter }
        let cause: String
        if chapter.cause.wordCount >= 6 {
            cause = chapter.cause
        } else if let previous {
            cause = "FOLGE AUS KAPITEL \(previous.number): \(previous.outcome)"
        } else {
            cause = chapter.cause
        }
        let candidate = PlannedChapter(
            number: chapter.number,
            title: chapter.title,
            goal: chapter.goal,
            conflict: chapter.conflict,
            cause: cause,
            decision: chapter.decision,
            outcome: "AUFLÖSUNG: " + resolution,
            emotionalStep: chapter.emotionalStep
        )
        return finalChapterResolutionIssues(candidate).isEmpty ? candidate : chapter
    }

    /// Prueft die kausale Wirbelsaeule eines Romanplans. Formale Akte reichen nicht:
    /// Jedes Kapitel nach dem ersten muss aus der neuen Lage des direkten Vorgaengers
    /// entstehen, eine aktive Entscheidung enthalten und erneut einen veraenderten
    /// Zustand hinterlassen. So werden episodische Aneinanderreihungen vor der Prosa
    /// gestoppt, statt spaeter als Logikspruenge im Manuskript aufzutauchen.
    static func kapitelKausalitaetsMaengel(_ chapters: [PlannedChapter]) -> [String] {
        guard chapters.count >= 4 else {
            return ["Zu wenige Kapitel fuer eine pruefbare Entscheidungs-Folgen-Kette."]
        }
        var maengel: [String] = []

        func norm(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
        }
        func kern(_ text: String) -> Set<String> {
            let stop: Set<String> = [
                "diese", "dieser", "dieses", "einen", "einer", "einem", "eine",
                "kapitel", "folge", "entscheidung", "aktive", "neue", "lage",
                "emotionaler", "schritt", "muss", "wird", "sich", "dass", "durch"
            ]
            return Set(norm(text)
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 5 && !stop.contains($0) })
        }
        func fastGleich(_ lhs: String, _ rhs: String) -> Bool {
            let a = kern(lhs), b = kern(rhs)
            guard a.count >= 3, b.count >= 3 else { return norm(lhs) == norm(rhs) }
            return Double(a.intersection(b).count) / Double(min(a.count, b.count)) >= 0.75
        }

        for (index, chapter) in chapters.enumerated() {
            if chapter.number != index + 1 {
                maengel.append("Kapitel \(index + 1) ist nicht fortlaufend nummeriert.")
            }
            if chapter.cause.wordCount < 6 {
                maengel.append("Kapitel \(chapter.number) benennt keinen konkreten Ausloeser oder keine Folge.")
            }
            if chapter.decision.wordCount < 6 {
                maengel.append("Kapitel \(chapter.number) enthaelt keine konkrete aktive Entscheidung.")
            }
            if chapter.outcome.wordCount < 6 {
                maengel.append("Kapitel \(chapter.number) hinterlaesst keine konkret veraenderte Lage.")
            }
            if chapter.emotionalStep.wordCount < 5 {
                maengel.append("Kapitel \(chapter.number) hat keinen konkreten emotionalen Schritt.")
            }

            let cause = norm(chapter.cause)
            if index == 0 {
                if !cause.contains("ausloser") && !cause.contains("ausloeser")
                    && !cause.contains("ausgangslage")
                    && !cause.contains("fruhe storung") && !cause.contains("fruehe stoerung") {
                    maengel.append("Kapitel 1 muss seinen Ausloeser ausdruecklich benennen.")
                }
            } else {
                // KAUSALITÄT MESSEN, NICHT EINE FORMEL VERLANGEN.
                //
                // Hier stand nur `cause.contains("folge aus kapitel N")`. Der Kapitelplan
                // musste diese Zeichenkette wörtlich enthalten – und der Prompt hat sie
                // NIE verlangt (geprüft: kommt in `PromptFactory` nirgends vor). Damit war
                // diese Sperre für jeden Roman unerfüllbar, und sie steht in der finalen
                // Freigabe der Kapitelplanung. Gemessen am 10.08.2026: kein einziger
                // Belletristik-Plan kam durch.
                //
                // Was die Prüfung eigentlich wissen will: Folgt dieses Kapitel aus dem
                // vorigen? Das lässt sich messen – der Auslöser muss inhaltlich an die
                // Entscheidung oder die neue Lage des Vorkapitels anknüpfen. Die alte
                // Formel gilt weiterhin als gültige Form, damit ältere Pläne bestehen.
                let vorher = chapters[index - 1]
                let formel = cause.contains("folge aus kapitel \(vorher.number)")
                let anschluss = EreignisRegister.uebereinstimmung(
                    EreignisRegister.inhaltswoerter(chapter.cause),
                    EreignisRegister.inhaltswoerter(vorher.decision + " " + vorher.outcome)
                )
                // 0,25 ist bewusst niedrig: Der Auslöser wiederholt das Vorkapitel nicht,
                // er greift ein Element daraus auf. Ein einzelnes gemeinsames Substantiv
                // („der Vertrag", „das Haus") genügt als Beleg, dass der Faden hält.
                if !formel, anschluss < 0.25 {
                    maengel.append(
                        "Kapitel \(chapter.number) knüpft nicht erkennbar an Kapitel "
                            + "\(vorher.number) an: Der Auslöser greift weder die "
                            + "Entscheidung noch die neue Lage des Vorkapitels auf."
                    )
                }
            }

            if index > 0 {
                let previous = chapters[index - 1]
                if fastGleich(chapter.decision, previous.decision) {
                    maengel.append("Kapitel \(chapter.number) wiederholt praktisch dieselbe Entscheidung.")
                }
                if fastGleich(chapter.outcome, previous.outcome) {
                    maengel.append("Kapitel \(chapter.number) wiederholt praktisch dieselbe neue Lage.")
                }
                if fastGleich(chapter.emotionalStep, previous.emotionalStep) {
                    maengel.append("Kapitel \(chapter.number) wiederholt praktisch denselben emotionalen Schritt.")
                }
            }
        }
        return Array(maengel.prefix(10))
    }

    /// Ein Konzept ist erst dann eine belastbare Quelle fuer Plot und Figuren, wenn alle
    /// Kernelemente konkret genug ausgearbeitet sind. Fehlende Felder duerfen nicht durch
    /// generische Standardsaetze ersetzt werden, weil sich deren Leere durchs ganze Buch zieht.
    static func konzeptMaengel(praemisse: String, logline: String, expose: String,
                               thema: String, zielgruppe: String,
                               istSachbuch: Bool) -> [String] {
        var maengel: [String] = []
        if praemisse.wordCount < 12 {
            maengel.append("Die Praemisse ist zu kurz oder zu allgemein.")
        }
        if logline.wordCount < 10 || logline.wordCount > 55 {
            maengel.append("Die Logline muss den Kernkonflikt praegnant in 10 bis 55 Woertern tragen.")
        }
        let exposeMinimum = istSachbuch ? 60 : 80
        if expose.wordCount < exposeMinimum {
            maengel.append("Das Expose ist mit \(expose.wordCount) Woertern zu duenn (mindestens \(exposeMinimum)).")
        }
        if thema.wordCount < 5 {
            maengel.append(istSachbuch
                ? "Die zentrale Leserfrage oder das Thema fehlt."
                : "Die thematische Frage des Romans fehlt.")
        }
        if zielgruppe.wordCount < 3 {
            maengel.append("Die Zielgruppe ist nicht konkret benannt.")
        }
        if [praemisse, logline, expose, thema, zielgruppe].contains(where: containsMetaRequest) {
            maengel.append("Das Konzept enthaelt Meta-Text oder eine Rueckfrage statt Buchinhalt.")
        }
        return maengel
    }

    /// Verhindert, dass ein kurzer Inhaltsabriss oder ein generisches Grundgeruest als
    /// belastbare Bucharchitektur in die Kapitelplanung gelangt. Die Pruefung verlangt
    /// dramaturgische Funktionen, aber kein bestimmtes Aktmodell und keine festen Labels.
    /// Die Beat-Zeilen eines Plots: `BEAT|Funktion|Beschreibung`.
    ///
    /// Der Schlüssel wird auf Kleinbuchstaben ohne Diakritika normalisiert, damit
    /// „Auflösung", „Aufloesung" und „AUFLOESUNG" dieselbe Funktion bezeichnen. Ohne diese
    /// Normalisierung wäre der Vertrag genauso brüchig wie die Stichwortsuche, die er
    /// ersetzt.
    ///
    /// - Returns: Funktion → Beschreibung. Leer, wenn der Plot keine Beat-Liste hat.
    static func plotBeats(_ plot: String) -> [String: String] {
        var ergebnis: [String: String] = [:]
        for zeile in plot.components(separatedBy: .newlines) {
            let z = zeile.trimmingCharacters(in: .whitespaces)
            guard z.uppercased().hasPrefix("BEAT|") else { continue }
            let felder = z.dropFirst("BEAT|".count)
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard felder.count >= 2 else { continue }
            let schluessel = felder[0]
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: "ss", with: "s")
            guard !schluessel.isEmpty, !felder[1].isEmpty else { continue }
            // Erster Treffer gewinnt: Wiederholt das Modell eine Funktion, zählt die
            // ausführlichere Erstnennung, nicht die knappe Wiederholung am Ende.
            if ergebnis[normalisierterBeatSchluessel(schluessel)] == nil {
                ergebnis[normalisierterBeatSchluessel(schluessel)] = felder[1]
            }
        }
        return ergebnis
    }

    /// Ordnet Schreibvarianten der acht Pflicht-Funktionen zu.
    private static func normalisierterBeatSchluessel(_ roh: String) -> String {
        if roh.hasPrefix("auslos") || roh.hasPrefix("storung") { return "ausloeser" }
        if roh.hasPrefix("entscheidung") || roh.hasPrefix("irreversibl") { return "entscheidung" }
        if roh.hasPrefix("umkehr") || roh.hasPrefix("wende") || roh.hasPrefix("midpoint")
            || roh.hasPrefix("mitte") { return "umkehr" }
        if roh.hasPrefix("preis") || roh.hasPrefix("opfer") || roh.hasPrefix("verlust") { return "preis" }
        if roh.hasPrefix("finale") || roh.hasPrefix("hohepunkt") || roh.hasPrefix("klimax")
            || roh.hasPrefix("konfrontation") { return "finale" }
        if roh.hasPrefix("auflosung") || roh.hasPrefix("nachklang")
            || roh.hasPrefix("ende") { return "aufloesung" }
        if roh.hasPrefix("frage") || roh.hasPrefix("dramatische") { return "frage" }
        if roh.hasPrefix("nebenhandlung") || roh.hasPrefix("subplot")
            || roh.hasPrefix("nebenstrang") { return "nebenhandlung" }
        return roh
    }

    static func plotArchitekturMaengel(_ plot: String, istSachbuch: Bool) -> [String] {
        let text = plot.lowercased()
        var maengel: [String] = []

        func enthaelt(_ marker: [String]) -> Bool {
            marker.contains { text.contains($0) }
        }
        func position(_ marker: [String]) -> String.Index? {
            marker.compactMap { text.range(of: $0)?.lowerBound }.min()
        }

        let mindestWoerter = istSachbuch ? 160 : 180
        if plot.wordCount < mindestWoerter {
            maengel.append("Die Bucharchitektur ist mit \(plot.wordCount) Woertern zu duenn (mindestens \(mindestWoerter)).")
        }

        if istSachbuch {
            let funktionen: [(String, [String])] = [
                ("Leserproblem und Ausgangslage", ["leserproblem", "ausgangslage", "problem der zielgruppe"]),
                ("Methode oder tragendes Prinzip", ["methode", "prinzip", "grundlage", "modell"]),
                ("konkrete Anwendung", ["anwendung", "uebung", "übung", "praxis", "beispiel"]),
                ("Hindernisse und Grenzen", ["hindernis", "grenze", "fehler", "einwand"]),
                ("Transfer oder Umsetzungsplan", ["transfer", "umsetzungsplan", "handlungsplan", "naechste schritte", "nächste schritte"]),
                ("messbares Ergebnis", ["ergebnis", "lernziel", "fortschritt", "wirkung"])
            ]
            for (name, marker) in funktionen where !enthaelt(marker) {
                maengel.append("In der Sachbucharchitektur fehlt: \(name).")
            }
            return Array(maengel.prefix(6))
        }

        // ZUERST DIE BEAT-LISTE. Sie ist der Vertrag, die Stichwortsuche darunter nur der
        // Notnagel für alte Pläne.
        //
        // WARUM. Die Suche unten prüft, ob im Plot-FLIESSTEXT bestimmte Zeichenketten
        // vorkommen. Gemessen an einer laufenden Produktion am 10.08.2026: Der Plot-Agent
        // wurde NEUNMAL hintereinander abgelehnt („Im Romanplot fehlt: Ausloeser … zentrale
        // Umkehr … unvermeidbarer Preis … Nebenhandlung"), und die Produktion brach jedes
        // Mal in der Strukturplanung ab – Phase 3 von 12, das Buch kam nie zur ersten Zeile.
        // Der zuvor gespeicherte, bestandene Plot desselben Programms enthielt dieselben
        // Wörter, und zwar als Großbuchstaben-Überschriften: AUSLÖS…, UMKEHR, PREIS,
        // NEBENHANDLUNG. Bestanden hat also nicht der bessere Plot, sondern der mit den
        // zufällig passenden Überschriften.
        //
        // Eine Prüfung, die das Etikett testet statt der Sache, lehnt guten Text ab und
        // lässt schlechten durch. Deshalb verlangt der Plot-Prompt jetzt acht `BEAT|`-Zeilen
        // mit festen Schlüsselwörtern. Sind sie da, entscheiden sie – der Fließtext darf
        // heißen, wie er will.
        let beats = plotBeats(plot)
        if !beats.isEmpty {
            let pflicht: [(String, String)] = [
                ("ausloeser", "Ausloeser oder fruehe Stoerung"),
                ("entscheidung", "irreversible Entscheidung"),
                ("umkehr", "zentrale Umkehr"),
                ("preis", "unvermeidbarer Preis"),
                ("finale", "finale Entscheidung oder Konfrontation"),
                ("aufloesung", "Aufloesung und Nachklang"),
                ("frage", "zentrale dramatische Frage"),
                ("nebenhandlung", "Nebenhandlung"),
            ]
            for (schluessel, name) in pflicht {
                guard let inhalt = beats[schluessel] else {
                    maengel.append("Im Romanplot fehlt: \(name).")
                    continue
                }
                // Eine Beat-Zeile, die nur die Funktion wiederholt, ist keine Angabe.
                if inhalt.wordCount < 4 {
                    maengel.append("Der Beat \u{201E}\(name)\u{201C} ist zu unbestimmt: "
                        + "\u{201E}\(inhalt)\u{201C}.")
                }
            }
            return Array(maengel.prefix(8))
        }

        let funktionen: [(String, [String])] = [
            ("Ausloeser oder fruehe Stoerung", ["auslöser", "ausloeser", "frühe störung", "fruehe stoerung", "auslösendes ereignis"]),
            ("irreversible Entscheidung", ["irreversible entscheidung", "kein zurück", "kein zurueck", "unwiderrufliche entscheidung"]),
            ("zentrale Umkehr", ["midpoint", "romanmitte", "zentrale wende", "zentrale umkehr", "neue deutung"]),
            ("unvermeidbarer Preis", ["preis", "opfert", "verliert", "kostet sie", "kostet ihn"]),
            ("finale Entscheidung oder Konfrontation", ["finale und", "finale entscheidung", "finalen konfrontation", "finale konfrontation", "höhepunkt", "hoehepunkt"]),
            ("Aufloesung und Nachklang", ["auflösung", "aufloesung", "nachklang", "neue normalität", "neue normalitaet"]),
            ("zentrale dramatische Frage", ["dramatische frage", "zentrale frage", "hauptfrage"]),
            ("Nebenhandlung", ["nebenhandlung", "subplot"])
        ]
        for (name, marker) in funktionen where !enthaelt(marker) {
            maengel.append("Im Romanplot fehlt: \(name).")
        }

        let wende = position(["midpoint", "romanmitte", "zentrale wende", "zentrale umkehr", "neue deutung"])
        let finale = position(["finale und", "finale entscheidung", "finalen konfrontation", "finale konfrontation", "höhepunkt", "hoehepunkt"])
        let ende = position(["auflösung", "aufloesung", "nachklang", "neue normalität", "neue normalitaet"])
        if let wende, let finale, finale <= wende {
            maengel.append("Das Finale muss nach der zentralen Wende liegen.")
        }
        if let finale, let ende, ende <= finale {
            maengel.append("Aufloesung und Nachklang muessen nach dem Finale liegen.")
        }
        return Array(maengel.prefix(8))
    }

    /// Einzelwörter, in die sich das Modell verliebt hat.
    ///
    /// Das gravierendste gemessene Problem: In „Schweig, wenn du sie siehst" stand
    /// „kalkweiß" 84-mal, „flackern" 65-mal, „Stille" 44-mal. Sobald ein Modell ein
    /// Wort als atmosphärisch erkennt, benutzt es das Wort als Krücke – der Leser
    /// merkt es spätestens beim dritten Mal, und der Text wirkt maschinell.
    ///
    /// Bewusst ohne feste Verbotsliste: Geprüft wird, was DIESES Buch übernutzt.
    /// So greift die Regel auch bei Lieblingswörtern, die niemand vorhersehen konnte.
    /// - Parameter figurennamen: Namen der Figuren. Sie MÜSSEN sich wiederholen –
    ///   ohne diese Ausnahme blockierte jede Szene, in der die Hauptfigur vorkommt.
    static func verliebteWoerter(candidate: String, priorTexts: [String],
                                 grenze: Int = 8,
                                 figurennamen: [String] = []) -> [String] {
        // Namensstämme nie als Loop werten.
        var namensStaemme = Set<String>()
        for name in figurennamen {
            for teil in name.split(separator: " ") {
                let n = String(teil).lowercased()
                    .trimmingCharacters(in: CharacterSet.letters.inverted)
                if n.count >= 3 { namensStaemme.insert(String(n.prefix(6))) }
            }
        }
        // Die Grenze wächst mit dem Buch: In 3.000 Wörtern ist ein Wort ab 5× auffällig,
        // in 120.000 Wörtern erst ab deutlich mehr. Eine feste Zahl würde bei langen
        // Büchern jede Szene blockieren und die Produktion anhalten.
        let bisherWoerter = priorTexts.reduce(0) { $0 + $1.split(separator: " ").count }
        let wirksameGrenze = max(grenze, Int(Double(bisherWoerter) / 2_500.0))
        // Nur auffällige, bedeutungstragende Wörter – Funktionswörter dürfen sich
        // beliebig wiederholen, das ist Grammatik und keine Stilschwäche.
        // Allerweltswörter: In jedem Roman häufig, kein Stilproblem. Konkrete Körperwörter
        // wie Hand, Finger, Augen oder Stimme gehören ausdrücklich NICHT hierher: Sie sind
        // als einzelne Wörter unauffällig, werden in generierter Prosa aber schnell zur
        // immergleichen Ersatzgeste. Dafür gilt unten eine eigene, kürzere Stammliste.
        let egal: Set<String> = [
            "sagte", "fragte", "hatte", "hätte", "wurde", "würde", "konnt", "wollte",
            "musste", "sollte", "durfte", "stand", "nahm", "zimmer", "mann", "frau",
            "nicht", "immer", "wieder", "schon",
            "noch", "dann", "aber", "doch", "auch", "sehr", "mehr", "jahren", "jahre",
            "nichts", "telefo", "tablet", "drückt", "verste",
            "gesich", "morgen", "wieder", "zwisch", "manchm", "vielle", "eigent",
            "einfac", "richti", "wirkli", "ander", "andere", "leute", "mensch",
            "minute", "stunde", "sekund", "letzte", "ersten", "zweite", "wenige",
            "gerade", "wieder", "zurück", "weiter", "sitzen", "stehen", "liegen",
            "sprech", "denken", "wissen", "sehen", "hören", "fühlen", "halten"
        ]
        let kurzeProsakruecken: Set<String> = [
            "hand", "hände", "augen", "blick", "kopf", "atem", "puls", "finger", "stimme"
        ]
        // WORTSTAMM statt Vollform. „flackerte", „flackernd", „flackern" und
        // „flackerndes" galten vorher als vier verschiedene Wörter – jedes blieb unter
        // der Grenze, obwohl der Stamm 16-mal im Buch stand. Genau daran ist die Sperre
        // vorbeigelaufen. Sechs Zeichen treffen den Stamm zuverlässig, ohne verschiedene
        // Wörter zusammenzuwerfen.
        func stamm(_ w: String) -> String { String(w.prefix(6)) }
        func zaehle(_ text: String) -> [String: Int] {
            var z: [String: Int] = [:]
            for w in text.lowercased().components(separatedBy: CharacterSet.letters.inverted)
            where (w.count >= 6 || kurzeProsakruecken.contains(w)) && !egal.contains(w) {
                z[stamm(w), default: 0] += 1
            }
            return z
        }
        var bisher: [String: Int] = [:]
        for t in priorTexts {
            for (w, n) in zaehle(t) { bisher[w, default: 0] += n }
        }
        let neu = zaehle(candidate)
        return neu.keys
            .filter { !namensStaemme.contains($0) && (bisher[$0] ?? 0) >= wirksameGrenze }
            .sorted { (bisher[$0] ?? 0) > (bisher[$1] ?? 0) }
            .prefix(5)
            .map { "\($0) (schon \(bisher[$0] ?? 0)×)" }
    }

    /// Auffaellige Worthaemmerung innerhalb EINER Szene. Die buchweite Pruefung oben
    /// sieht ein Lieblingswort erst, wenn es bereits in frueherer Prosa oft vorkam;
    /// dadurch blieb der erste Text mit vier- bis fuenffachem "warm" oder "Schluessel"
    /// unbemerkt. Kurze Funktionswoerter und kanonische Figurennamen sind ausgenommen.
    static func localContentWordOveruse(in text: String,
                                        characterNames: [String] = []) -> [String] {
        let stop: Set<String> = [
            "aber", "alle", "also", "auch", "dann", "dass", "deine", "denen", "deren",
            "dies", "diese", "doch", "eine", "einem", "einen", "einer", "eines", "etwas", "hatte", "hätte",
            "bevor", "hier", "ihnen", "ihre", "ihrer", "immer", "jetzt", "kann", "keine", "konnte", "mehr",
            "nach", "nicht", "noch", "sagte", "schon", "seine", "seiner", "sich", "sollte", "stand",
            "ueber", "über", "unter", "wieder", "wurde", "würde", "waren", "wenn", "weiter",
            "wollte", "zwischen", "zurueck", "zurück"
        ]
        func localStem(_ word: String) -> String {
            if word.count >= 6 { return String(word.prefix(6)) }
            if word.count == 5,
               let last = word.last,
               ["e", "n", "r", "s"].contains(last) {
                return String(word.dropLast())
            }
            return word
        }
        let nameStems = Set(characterNames.flatMap { name in
            name.components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 4 }
                .map { localStem($0.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()) }
        })
        let words = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        ).lowercased().components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 4 && !stop.contains($0) }
        let threshold = words.count > 800 ? 5 : 4
        var counts: [String: Int] = [:]
        for word in words {
            let stem = localStem(word)
            guard !nameStems.contains(stem) else { continue }
            counts[stem, default: 0] += 1
        }
        return counts.filter { $0.value >= threshold }
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(6)
            .map { "\($0.key) (\($0.value)× in dieser Szene)" }
    }

    /// Beginnen zu viele Sätze gleich? („Sie hatte …" stand 43-mal in einem Buch.)
    static func monotoneSatzanfaenge(in text: String, grenze: Int = 4) -> [String] {
        var zaehler: [String: Int] = [:]
        for satz in saetzeAusText(text) {
            let woerter = satz.split(separator: " ")
            guard woerter.count >= 2 else { continue }
            let anfang = woerter.prefix(2).joined(separator: " ").lowercased()
            zaehler[anfang, default: 0] += 1
        }
        return zaehler.filter { $0.value >= grenze }
            .sorted { $0.value > $1.value }
            .map { "\($0.key) … (\($0.value)×)" }
    }

    /// Greift die neue Szene zu Wendungen, die im Buch längst verbraucht sind?
    ///
    /// Gemessen an „Schweig, wenn du sie siehst": „die Narbe am Handgelenk" stand
    /// zwölfmal im Buch, „Mira öffnete den Mund" neunmal, „hielt den Atem an" neunmal.
    /// Als Leitmotiv gedacht, als Mantra gelesen. Diese Prüfung schlägt an, sobald eine
    /// Szene eine Wendung benutzt, die vorher schon mehrfach gefallen ist.
    static func verbrauchteWendungen(candidate: String, priorTexts: [String],
                                     abHaeufigkeit: Int = 3) -> [String] {
        let bekannt = wiederholteWortgruppen(in: priorTexts, abHaeufigkeit: abHaeufigkeit)
        guard !bekannt.isEmpty else { return [] }
        let neu = candidate.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return bekannt.filter { neu.contains($0.gruppe) }
            .map { "\($0.gruppe) (bereits \($0.anzahl)×)" }
    }

    /// Ketten aus sehr kurzen Sätzen – das Gegenstück zum Bandwurm.
    ///
    /// Vier oder mehr Sätze unter sechs Wörtern hintereinander wirken gehetzt und
    /// lassen die Szene zerhackt erscheinen. Im selben Buch: zwölf solcher Ketten.
    static func stakkatoKetten(in text: String) -> Int {
        var ketten = 0
        var lauf = 0
        for satz in saetzeAusText(text) {
            if satz.split(separator: " ").count < 6 {
                lauf += 1
            } else {
                if lauf >= 4 { ketten += 1 }
                lauf = 0
            }
        }
        if lauf >= 4 { ketten += 1 }
        return ketten
    }

    /// A single nominal fragment can add emphasis; several make finished prose
    /// read like notes. Direct dialogue replies under three words stay untouched.
    static func proseSentenceFragments(in text: String) -> [String] {
        var fragments: [String] = []
        for sentence in saetzeAusText(text) {
            let words = sentence.components(separatedBy: CharacterSet.letters.inverted)
                .filter { !$0.isEmpty }
            guard words.count >= 3, words.count <= 18 else { continue }
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = sentence
            var hasVerb = false
            tagger.enumerateTags(
                in: sentence.startIndex..<sentence.endIndex,
                unit: .word,
                scheme: .lexicalClass,
                options: [.omitWhitespace, .omitPunctuation]
            ) { tag, _ in
                if tag == .verb { hasVerb = true }
                return !hasVerb
            }
            if !hasVerb { fragments.append(sentence) }
        }
        return fragments
    }

    private static func saetzeAusText(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?\u{201C}"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 3 }
    }

    /// Bricht die Szene die Erzählperspektive des Buches?
    ///
    /// Gemessen an „Wo wir zuletzt tanzten": 4 von 48 Szenen standen in der ICH-Form,
    /// obwohl das Buch als personaler Erzähler (Er/Sie) angelegt war – mitten im Buch,
    /// in den Kapiteln 2, 6, 8 und 9. Das fällt jedem Leser sofort auf und wirkt wie
    /// ein Anfängerfehler. Es gab dafür bis dahin keinerlei Prüfung.
    ///
    /// Gezählt wird nur der ERZÄHLER: Direkte Rede fällt heraus, sonst schlüge jede
    /// Szene an, in der eine Figur „ich" sagt. Ein Ich-Roman (erste Person als
    /// Vorgabe) wird nicht geprüft – dort ist die Ich-Form richtig.
    static func brichtErzaehlperspektive(_ text: String, perspektive: String) -> Bool {
        let ziel = canonNormalized(perspektive)
        // Nur prüfen, wenn das Buch NICHT in der Ich-Form erzählt werden soll.
        guard !ziel.contains("ich"), !ziel.contains("erste person"),
              !ziel.contains("first person") else { return false }

        // Direkte Rede entfernen: deutsche und gerade Anführungszeichen.
        var ausserhalb = text
        for muster in ["[\u{201E}\u{201C}][^\u{201C}\u{201D}\u{201E}]*[\u{201C}\u{201D}]",
                       "\"[^\"]*\"", "\u{00BB}[^\u{00AB}]*\u{00AB}"] {
            ausserhalb = ausserhalb.replacingOccurrences(
                of: muster, with: " ", options: .regularExpression)
        }
        func treffer(_ pattern: String) -> Int {
            let bereich = NSRange(ausserhalb.startIndex..<ausserhalb.endIndex, in: ausserhalb)
            guard let re = try? NSRegularExpression(pattern: pattern) else { return 0 }
            return re.numberOfMatches(in: ausserhalb, range: bereich)
        }
        let ich = treffer(#"\b(?:[Ii]ch|mich|mir|mein(?:e|er|es|em|en)?)\b"#)
        guard ich >= 12 else { return false }
        let dritte = treffer(#"\b(?:sie|Sie|ihr(?:e|er|es|em|en)?|er|Er|ihm|ihn)\b"#)
        // Erzähler-Ich muss die dritte Person deutlich überlagern, nicht nur vorkommen.
        guard Double(ich) > Double(dritte) * 0.35 else { return false }

        // EINGEBETTETE Ich-Texte sind kein Perspektivbruch: Briefe, Tagebucheinträge und
        // Zitate stehen zu Recht in der ersten Person, solange die Szene sie in dritter
        // Person rahmt. Gemessen an „Wo wir zuletzt tanzten", Kapitel 6 Szene 3: Die
        // Szene öffnet mit „Lena betrat den stillen Seesaal", bringt dann Jonas' Brief
        // („Lena, ich schreibe dir im Zug nach Hamburg") und schließt wieder mit „Lena
        // strich über die Zeilen". Ohne diese Ausnahme meldete die Prüfung genau diese
        // – dramaturgisch starke – Szene als Fehler und hätte sie neu schreiben lassen.
        func istDritterPerson(_ ausschnitt: String) -> Bool {
            let bereich = NSRange(ausschnitt.startIndex..<ausschnitt.endIndex, in: ausschnitt)
            func zahl(_ p: String) -> Int {
                guard let re = try? NSRegularExpression(pattern: p) else { return 0 }
                return re.numberOfMatches(in: ausschnitt, range: bereich)
            }
            return zahl(#"\b(?:sie|Sie|ihr(?:e|er|es|em|en)?|er|Er|ihm|ihn)\b"#)
                > zahl(#"\b(?:[Ii]ch|mich|mir|mein(?:e|er|es|em|en)?)\b"#)
        }
        let kopf = String(ausserhalb.prefix(420))
        let fuss = String(ausserhalb.suffix(420))
        if istDritterPerson(kopf), istDritterPerson(fuss) { return false }

        return true
    }

    /// Besteht der Plan nur aus den generischen Notfall-Beats?
    ///
    /// Gemessen an Buch 7: Ein Drittel aller Szenen bekam Ziele wie „KOMPLIKATION:
    /// ein NEUER, anderer Vorstoß" und bei allen vier Szenen eines Kapitels dasselbe
    /// Hindernis. Der Draft Writer hat damit keinerlei Unterscheidungsmerkmal und
    /// erzählt dasselbe Ereignis mehrfach. Diese Doppler sind später durch KEINE
    /// Reparatur behebbar – eine Szene wurde achtmal neu geschrieben und blieb ein
    /// Doppler, weil ihr Plan mit dem der Nachbarszene identisch war. Deshalb gilt
    /// ein solcher Plan als unbrauchbar und wird neu angefordert.
    static func istGenerischerSzenenplan(_ planned: [PlannedScene]) -> Bool {
        guard planned.count >= 2 else { return false }
        let marken = ["einstieg:", "komplikation:", "zuspitzung:", "wende und übergang",
                      "wende und ubergang"]
        let generisch = planned.filter { szene in
            let ziel = szene.goal.folding(options: [.diacriticInsensitive], locale: .current)
                .lowercased()
            return marken.contains { ziel.hasPrefix($0) || ziel.contains($0) }
        }.count
        // Mehrheit generisch → unbrauchbar.
        if generisch * 2 > planned.count { return true }
        // Oder: alle Szenen teilen sich wörtlich dasselbe Hindernis.
        let hindernisse = Set(planned.map {
            $0.obstacle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })
        return hindernisse.count == 1 && planned.count >= 3
    }

    static func scenePlanGenreDriftMarkers(_ text: String, genre: String,
                                           canon: String) -> [String] {
        let normalizedGenre = canonNormalized(genre)
        guard !normalizedGenre.contains("horror"),
              !normalizedGenre.contains("mystery"),
              !normalizedGenre.contains("thriller"),
              !normalizedGenre.contains("krimi") else { return [] }
        let established = canonNormalized(canon)
        // Nur was der Kandidat NEU einführt, ist Abdrift. Was der etablierte Text
        // bereits enthält, darf eine Fortsetzung aufgreifen.
        //
        // Gemessen an Buch 7: Kapitel 1, Szene 3 enthält „eine flüchtige Gestalt"
        // vor dem Fenster. Der established-Abgleich galt bisher NUR für die
        // `driftMarkers`-Liste am Ende – die fest verdrahteten Regeln darüber
        // prüften ihn nie. Jede Reparatur, die diese Szene korrekt fortführte,
        // schlug deshalb zwangsläufig als „bedrohliche Gestalt" an und konnte nie
        // angenommen werden: ein Patt, das sich nicht auflösen lässt.
        let imKandidaten = genreDriftRuleHits(in: canonNormalized(text))
        guard !imKandidaten.isEmpty else { return [] }
        let imEtablierten = Set(genreDriftRuleHits(in: established))
        return imKandidaten.filter { !imEtablierten.contains($0) }.sorted()
    }

    /// Wendet den Regelsatz auf EINEN Text an. Getrennt, damit derselbe Satz auch auf
    /// den etablierten Text angewendet werden kann – sonst zählt Bestehendes als neu.
    private static func genreDriftRuleHits(in candidate: String) -> [String] {
        var matches: [String] = []
        if candidate.contains("schatten"),
           candidate.contains("waldrand") || candidate.contains("zwischen den baumen") {
            matches.append("Schatten am Waldrand/zwischen den Bäumen")
        }
        if candidate.contains("beobacht"),
           candidate.contains("waldrand") || candidate.contains("heimlich") {
            matches.append("heimliche Beobachtung/am Waldrand")
        }
        if containsStandaloneMarker("gestalt", in: candidate),
           ["waldrand", "vor dem fenster", "hinter dem fenster", "gestalt im schatten", "verfolg"]
            .contains(where: candidate.contains) {
            matches.append("bedrohliche Gestalt")
        }
        if containsStandaloneMarker("axt", in: candidate)
            || containsStandaloneMarker("beil", in: candidate) {
            if ["wie eine waffe", "drohte", "bedrohte", "erhob", "schwang", "griff an",
                "zwischen den baumen", "trat hervor", "waldrand"]
                .contains(where: candidate.contains) {
                matches.append("Axt/Beil als Bedrohung")
            }
        }
        if candidate.contains("jemand"),
           ["wahrend sie schlief", "wahrend sie geschlafen", "hereingelegt", "war im haus",
            "abdruck eines kopfes", "nicht der ihre", "wer hier gewesen", "vorhange zuruckgezogen"]
            .contains(where: candidate.contains) {
            matches.append("unbekannte Person im Haus")
        }
        if candidate.contains("hinter der tur") && candidate.contains("unter dem bett") {
            matches.append("Eindringlings-/Horrorinszenierung")
        }
        if candidate.contains("das haus"),
           ["haus atmete", "atmete nicht", "schien zu warten", "als wurde es warten"]
            .contains(where: candidate.contains) {
            matches.append("bedrohlich vermenschlichtes Haus")
        }
        if ["haustur offen stand", "tur stand offen", "tur wieder offen"]
            .contains(where: candidate.contains),
           ["obwohl", "nachdem", "niemand", "von selbst", "unerklart"]
            .contains(where: candidate.contains) {
            matches.append("unerklärlich offene Tür")
        }
        let driftMarkers = [
            "menschliche silhouette", "gestalt am waldrand",
            "geruch nach verwesung", "verwesung", "einbrecher", "geistererscheinung",
            "stimme flustert", "stimme flusterte", "ein schatten bewegte sich",
            "wie eine waffe", "kein tier",
            "bemerkt nicht den forster", "beobachtet sie vom waldrand",
            "sie beobachten mich", "nicht jeder hier freut sich", "schatten zwischen den baumen",
            "schlussel, der nicht",
            "einzelnen schlussel", "fremden schlussel", "unbekannten schlussel",
            "frischer abdruck", "frische mulde", "wer hier gewesen war"
        ]
        // Kein established-Abgleich mehr an dieser Stelle: Er gilt jetzt zentral in
        // scenePlanGenreDriftMarkers für ALLE Regeln, nicht nur für diese Liste.
        matches.append(contentsOf: driftMarkers.filter {
            containsStandaloneMarker($0, in: candidate)
        })
        return Array(Set(matches)).sorted()
    }

    private static func containsStandaloneMarker(_ marker: String, in text: String) -> Bool {
        if marker.contains(" ") || marker.contains(",") { return text.contains(marker) }
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: marker) + #"\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    static func summaryIntroducesUnsupportedSpecifics(_ summary: String,
                                                       evidence: String) -> Bool {
        let candidate = canonNormalized(summary)
        let source = canonNormalized(evidence)
        let riskStems = [
            "eltern", "mutter", "schwester", "bruder", "tante", "onkel", "kind",
            "schwanger", "verstorben", "gestorben", "starb", "tod", "ermordet",
            "uberwacht", "heimlich", "mysterios", "waffe", "suizid", "erhangt"
        ]
        return riskStems.contains { stem in
            candidate.contains(stem) && !source.contains(stem)
        }
    }

    static func evidenceBoundSummary(_ summary: String, evidence: String, canon: String,
                                     characterNames: [String],
                                     perspectiveName: String = "") -> Bool {
        let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              hasCompleteSentenceEnding(cleaned),
              !containsPromptArtifacts(cleaned),
              !containsMetaRequest(cleaned) else { return false }
        let completeEvidence = [canon, evidence].filter { !$0.isEmpty }.joined(separator: "\n")
        return unsupportedCanonClaims(
            in: cleaned,
            canon: completeEvidence,
            characterNames: characterNames
        ).isEmpty
            && unsupportedPerspectiveRelationshipClaims(
                in: cleaned,
                canon: canon,
                perspectiveName: perspectiveName,
                characterNames: characterNames
            ).isEmpty
            && !summaryIntroducesUnsupportedSpecifics(cleaned, evidence: completeEvidence)
    }

    /// Deterministic continuity memory used when a model summary is unavailable or
    /// introduces unsupported facts. Planned scene facts are safer and more useful
    /// than arbitrary first/last prose snippets.
    static func plannedSceneSummary(perspective: String, goal: String,
                                    obstacle: String, turn: String) -> String {
        [
            ("Perspektive", perspective),
            ("Ziel", goal),
            ("Hindernis", obstacle),
            ("Wendung", turn)
        ].compactMap { label, value in
            let cleaned = value.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : "\(label): \(cleaned)"
        }.joined(separator: ". ") + "."
    }

    /// Builds a fact-safe chapter memory from complete scene summaries. It never
    /// cuts through a sentence, which previously produced unusable fragments.
    static func extractiveChapterDigest(sceneSummaries: [String],
                                        maxCharacters: Int = 1_600) -> String {
        var result: [String] = []
        var used = 0
        for raw in sceneSummaries {
            let summary = raw.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { continue }
            if used + summary.count <= maxCharacters {
                result.append(summary)
                used += summary.count + 1
                continue
            }
            let remaining = maxCharacters - used
            guard remaining >= 80 else { break }
            let prefix = String(summary.prefix(remaining))
            if let boundary = prefix.lastIndex(where: { ".!?".contains($0) }) {
                result.append(String(prefix[...boundary]))
            }
            break
        }
        return result.joined(separator: " ")
    }

    static func unexpectedCharacterNames(in text: String, allowedContext: String,
                                         characterNames: [String]) -> [String] {
        let candidate = canonNormalized(text)
        let allowed = canonNormalized(allowedContext)
        return characterNames.filter { name in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            let appears = candidate.contains(normalized) || candidate.contains(first)
            let isAllowed = allowed.contains(normalized) || allowed.contains(first)
            return appears && !isAllowed
        }
    }

    static func unexpectedStoryArtifacts(in text: String, allowedContext: String) -> [String] {
        let candidate = canonNormalized(text)
        let allowed = canonNormalized(allowedContext)
        let artifacts = [
            (#"\bbrief[\p{L}-]*"#, "Brief"), (#"\bfoto[\p{L}-]*"#, "Foto"),
            (#"\balbum[\p{L}-]*"#, "Album"), (#"\bumschlag[\p{L}-]*"#, "Umschlag"),
            (#"\bkassett[\p{L}-]*"#, "Kassette"), (#"\btestament[\p{L}-]*"#, "Testament"),
            (#"\bdokument[\p{L}-]*"#, "Dokument"), (#"\btonaufnahme[\p{L}-]*"#, "Tonaufnahme"),
            (#"\btagebuch[\p{L}-]*"#, "Tagebuch"), (#"\bnotizbuch[\p{L}-]*"#, "Notizbuch"),
            (#"\bzettel[\p{L}-]*"#, "Zettel"), (#"\bnotiz(?:en)?\b"#, "Notiz"),
            (#"\bring(?:s)?\b"#, "Ring"), (#"\bultraschall[\p{L}-]*"#, "Ultraschallbild"),
            (#"\bkaufvertrag[\p{L}-]*"#, "Kaufvertrag")
        ]
        return artifacts.compactMap { pattern, label in
            let appears = candidate.range(of: pattern, options: .regularExpression) != nil
            let isAllowed = allowed.range(of: pattern, options: .regularExpression) != nil
            return appears && !isAllowed ? label : nil
        }
    }

    static func removingScenePlanViolations(from text: String,
                                            characterNames: [String],
                                            artifactLabels: [String]) -> String {
        let normalizedNames = characterNames.flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        }
        let artifactPatterns: [String: String] = [
            "Brief": #"\bbrief[\p{L}-]*"#,
            "Foto": #"\bfoto[\p{L}-]*"#,
            "Album": #"\balbum[\p{L}-]*"#,
            "Umschlag": #"\bumschlag[\p{L}-]*"#,
            "Kassette": #"\bkassett[\p{L}-]*"#,
            "Testament": #"\btestament[\p{L}-]*"#,
            "Dokument": #"\bdokument[\p{L}-]*"#,
            "Tonaufnahme": #"\btonaufnahme[\p{L}-]*"#,
            "Tagebuch": #"\btagebuch[\p{L}-]*"#,
            "Notizbuch": #"\bnotizbuch[\p{L}-]*"#,
            "Zettel": #"\bzettel[\p{L}-]*"#,
            "Notiz": #"\bnotiz(?:en)?\b"#,
            "Ring": #"\bring(?:s)?\b"#,
            "Ultraschallbild": #"\bultraschall[\p{L}-]*"#,
            "Kaufvertrag": #"\bkaufvertrag[\p{L}-]*"#
        ]
        let activePatterns = artifactLabels.compactMap { artifactPatterns[$0] }
        var kept: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) {
            substring, _, _, _ in
            guard let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sentence.isEmpty else { return }
            let normalized = canonNormalized(sentence)
            let hasName = normalizedNames.contains { containsStandaloneMarker($0, in: normalized) }
            let hasArtifact = activePatterns.contains {
                normalized.range(of: $0, options: .regularExpression) != nil
            }
            if !hasName && !hasArtifact { kept.append(sentence) }
        }
        return kept.joined(separator: " ")
    }

    /// Blocks newly assigned family relationships before they can enter a plan or manuscript.
    /// The guard is intentionally narrow: it only judges explicit kinship claims for known names.
    static func unsupportedCanonClaims(in candidate: String, canon: String,
                                       characterNames: [String]) -> [String] {
        let canonClauses = relationshipClauses(in: canon)
        let aliases = Array(Set(characterNames.flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        })).sorted { $0.count > $1.count }

        return relationshipClauses(in: candidate).compactMap { original, normalized in
            let mentioned = aliases.filter { normalized.contains($0) }
            guard !mentioned.isEmpty else { return nil }

            if let term = kinshipTerms.first(where: { containsWordStem($0, in: normalized) }) {
                let directPossessors = aliases.filter {
                    hasDirectKinshipClaim(possessor: $0, term: term, in: normalized)
                }
                let supported: Bool
                if !directPossessors.isEmpty {
                    supported = directPossessors.allSatisfy { possessor in
                        canonClauses.contains { _, clause in
                            hasDirectKinshipClaim(possessor: possessor, term: term, in: clause)
                        }
                    }
                } else {
                    let propertyClaim = normalized.contains("haus") || normalized.contains("erb")
                    supported = canonClauses.contains { _, clause in
                        containsWordStem(term, in: clause)
                            && mentioned.allSatisfy { clause.contains($0) }
                            && (!propertyClaim || clause.contains("haus") || clause.contains("erb"))
                    }
                }
                if !supported { return original }
            }

            let deathSubjects = aliases.filter { hasDirectDeathClaim(subject: $0, in: normalized) }
            if !deathSubjects.isEmpty {
                let supported = deathSubjects.allSatisfy { subject in
                    canonClauses.contains { _, clause in
                        hasDirectDeathClaim(subject: subject, in: clause)
                    }
                }
                if !supported { return original }
            }
            return nil
        }
    }

    /// Detects a narrow but damaging class of relationship drift: a scene turns a
    /// canonical former spouse into the current bride/groom (or vice versa). Generic
    /// relationships are deliberately ignored; a claim is rejected only when the canon
    /// explicitly establishes a conflicting romantic status for the same two people.
    static func unsupportedPerspectiveRelationshipClaims(
        in candidate: String,
        canon: String,
        perspectiveName: String,
        characterNames: [String]
    ) -> [String] {
        enum RomanticStatus { case current, former }

        let currentTerms = ["brautigam", "braeutigam", "braut", "verlobt", "ehemann", "ehefrau"]
        let formerTerms = ["exmann", "exfrau", "ex-ehemann", "ex-ehefrau"]

        func aliases(for name: String) -> [String] {
            let full = canonNormalized(name)
            let parts = full.components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 3 }
            return Array(Set([full] + parts)).sorted { $0.count > $1.count }
        }

        func mentions(_ name: String, in clause: String) -> Bool {
            aliases(for: name).contains { alias in
                let escaped = NSRegularExpression.escapedPattern(for: alias)
                return clause.range(
                    of: #"\b"# + escaped + #"(?:s|['’])?\b"#,
                    options: .regularExpression
                ) != nil
            }
        }

        func status(in clause: String) -> RomanticStatus? {
            let normalized = canonNormalized(clause)
            if formerTerms.contains(where: { containsWordStem($0, in: normalized) }) {
                return .former
            }
            let hasSpouseTerm = ["ehemann", "ehefrau"].contains {
                containsWordStem($0, in: normalized)
            }
            if hasSpouseTerm,
               normalized.range(
                of: #"\b(?:ehemalig|damalig)[\p{L}-]*\s+(?:[\p{L}-]+\s+){0,2}(?:ehemann|ehefrau)"#,
                options: .regularExpression
               ) != nil {
                return .former
            }
            if currentTerms.contains(where: { containsWordStem($0, in: normalized) }) {
                return .current
            }
            return nil
        }

        func status(for term: String, in context: String) -> RomanticStatus {
            if formerTerms.contains(term) { return .former }
            if ["ehemann", "ehefrau"].contains(term), status(in: context) == .former {
                return .former
            }
            return .current
        }

        func canonicalStatuses(between firstName: String, and secondName: String,
                               in rawClause: String) -> [RomanticStatus] {
            let clause = canonNormalized(rawClause)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let allTerms = formerTerms + currentTerms
            var result: [RomanticStatus] = []

            // Explicit genitives such as "Lennarts Braut" or "Marens Exmann".
            for owner in [firstName, secondName] {
                for alias in aliases(for: owner) {
                    for term in allTerms where hasDirectKinshipClaim(
                        possessor: alias, term: term, in: clause
                    ) {
                        result.append(status(for: term, in: clause))
                    }
                }
            }

            // Perspective-linked possessives in canonical prose, for example
            // "Maren ... die Hochzeit ihres Exmannes Lennart".
            for (owner, target) in [(firstName, secondName), (secondName, firstName)] {
                for ownerAlias in aliases(for: owner) {
                    let escapedOwner = NSRegularExpression.escapedPattern(for: ownerAlias)
                    for targetAlias in aliases(for: target) {
                        let escapedTarget = NSRegularExpression.escapedPattern(for: targetAlias)
                        for term in allTerms {
                            let escapedTerm = NSRegularExpression.escapedPattern(for: term)
                            let pattern = #"\b"# + escapedOwner
                                + #"\b.{0,180}\b(?:ihr|ihre|ihren|ihrem|ihrer|ihres|sein|seine|seinen|seinem|seiner|seines)\s+(?:[\p{L}-]+\s+){0,2}"#
                                + escapedTerm + #"[\p{L}-]*\s+(?:[\p{L}-]+\s+){0,3}"#
                                + escapedTarget + #"\b"#
                            if clause.range(of: pattern, options: .regularExpression) != nil {
                                result.append(status(for: term, in: clause))
                            }
                        }
                    }
                }
            }
            return result
        }

        let canonClauses = canon.components(
            separatedBy: CharacterSet(charactersIn: ".!?;")
        )
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ($0, canonNormalized($0)) }
        let candidateClauses = relationshipClauses(in: candidate)
        let perspective = perspectiveName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !perspective.isEmpty else { return [] }

        var findings: [String] = []
        for (original, normalized) in candidateClauses {
            guard let claimedStatus = status(in: normalized) else { continue }
            let hasPerspectivePossessive = normalized.range(
                of: #"\b(?:ihr|ihre|ihren|ihrem|ihrer|ihres|sein|seine|seinen|seinem|seiner|seines)\s+(?:[\p{L}-]+\s+){0,2}(?:brautigam|braeutigam|braut|verlobt[\p{L}-]*|ehemann|ehefrau)\b"#,
                options: .regularExpression
            ) != nil

            let namedPossessors = characterNames.filter { name in
                aliases(for: name).contains { alias in
                    currentTerms.contains { term in
                        hasDirectKinshipClaim(possessor: alias, term: term, in: normalized)
                    }
                }
            }
            let possessors = namedPossessors.isEmpty && hasPerspectivePossessive
                ? [perspective]
                : namedPossessors
            guard !possessors.isEmpty else { continue }

            for possessor in possessors {
                let targets = characterNames.filter {
                    canonNormalized($0) != canonNormalized(possessor) && mentions($0, in: normalized)
                }
                for target in targets {
                    let establishedStatuses = canonClauses.flatMap { originalCanon, canonClause -> [RomanticStatus] in
                        guard mentions(possessor, in: canonClause), mentions(target, in: canonClause) else {
                            return []
                        }
                        return canonicalStatuses(
                            between: possessor, and: target, in: originalCanon
                        )
                    }
                    guard !establishedStatuses.isEmpty,
                          establishedStatuses.allSatisfy({ $0 != claimedStatus }) else { continue }
                    findings.append(original)
                }
            }
        }
        return Array(Set(findings))
    }

    static func draftCanonIssues(in candidate: String, canon: String,
                                 perspectiveName: String,
                                 characterNames: [String]) -> [String] {
        Array(Set(
            unsupportedCanonClaims(
                in: candidate, canon: canon, characterNames: characterNames
            ) + unsupportedPerspectiveRelationshipClaims(
                in: candidate,
                canon: canon,
                perspectiveName: perspectiveName,
                characterNames: characterNames
            )
        ))
    }

    static func groundedRelationships(_ candidate: String, canon: String,
                                      characterNames: [String], subject: String = "") -> String {
        let subjectAliases = Set([subject].flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        })
        let knownAliases = Set(characterNames.flatMap { name -> [String] in
            let normalized = canonNormalized(name)
            let first = normalized.split(separator: " ").first.map(String.init) ?? normalized
            return [normalized, first].filter { $0.count >= 3 }
        }).subtracting(subjectAliases)
        return candidate.components(separatedBy: CharacterSet(charactersIn: ";\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { clause in
                let claim = subject.isEmpty ? clause : "\(subject) ist \(clause)"
                let normalized = canonNormalized(clause)
                guard !clause.isEmpty,
                      knownAliases.contains(where: { containsStandaloneMarker($0, in: normalized) })
                else { return false }
                let claimsKinship = kinshipTerms.contains {
                    containsWordStem($0, in: normalized)
                }
                return !claimsKinship || unsupportedCanonClaims(
                    in: claim, canon: canon, characterNames: characterNames
                ).isEmpty
            }
            .joined(separator: "; ")
    }

    static func groundedRelationshipsBySubject(
        _ candidates: [String: String], canon: String, characterNames: [String]
    ) -> [String: String] {
        Dictionary(uniqueKeysWithValues: candidates.map { subject, relationships in
            (
                subject,
                groundedRelationships(
                    relationships,
                    canon: canon,
                    characterNames: characterNames,
                    subject: subject
                )
            )
        })
    }

    private static func relationshipClauses(in text: String) -> [(String, String)] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ($0, canonNormalized($0)) }
    }

    private static func canonNormalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func containsWordStem(_ term: String, in text: String) -> Bool {
        text.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: term) + #"(?:s|es|e|en|er)?\b"#,
                   options: .regularExpression) != nil
    }

    private static func hasDirectKinshipClaim(possessor: String, term: String,
                                               in text: String) -> Bool {
        let escapedPossessor = NSRegularExpression.escapedPattern(for: possessor)
        let escapedTerm = NSRegularExpression.escapedPattern(for: term)
        let pattern = #"\b"# + escapedPossessor
            + #"(?:s|['’])?\s+(?:[\p{L}-]+\s+){0,2}"#
            + escapedTerm + #"(?:s|es|e|en|er)?\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func hasDirectDeathClaim(subject: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: subject)
        let death = deathTerms.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let possessive = #"\b"# + escaped + #"(?:s|['’])\s+(?:[\p{L}-]+\s+)?(?:"#
            + death + #")[\p{L}-]*\b"#
        let subjectVerb = #"\b"# + escaped + #"\s+(?:[\p{L}-]+\s+){0,2}(?:"#
            + death + #")[\p{L}-]*\b"#
        let deathOf = #"\b(?:"# + death + #")[\p{L}-]*\s+(?:von\s+)?(?:[\p{L}-]+\s+){0,2}"#
            + escaped + #"\b"#
        return [possessive, subjectVerb, deathOf].contains {
            text.range(of: $0, options: .regularExpression) != nil
        }
    }

    static func hasUsableIdea(_ idea: ParsedIdea?) -> Bool {
        guard let idea else { return false }
        let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let premise = idea.premise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 4, premise.wordCount >= 10 else { return false }
        return !isGenericPlaceholder(title)
            && !isOccupationalTitleCliche(title)
            && !containsMetaRequest(premise)
    }

    /// Heuristische Klickstärke/„Viralität" eines Titels für die Auto-Produktion:
    /// bevorzugt kurze, klangstarke, neugierig machende Titel (gut als Amazon-KDP-
    /// Thumbnail lesbar), bestraft generische und Berufs-/Ort-Klischee-Titel.
    /// Reine Heuristik – kein Netzwerkaufruf, deterministisch.
    static func titleViralityScore(_ rawTitle: String) -> Int {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return 0 }
        if isGenericPlaceholder(title) { return 0 }

        var score = 50
        let words = title.split(separator: " ").count
        switch words {            // Wortzahl-Sweetspot 2–5 (im Suchergebnis sofort lesbar)
        case 2...5: score += 25
        case 1, 6: score += 8
        default: score -= 12      // 7+ Wörter: zu lang fürs Thumbnail
        }
        switch title.count {      // kurze Titel = besser sichtbar
        case ...28: score += 15
        case 29...40: score += 6
        default: score -= 10
        }
        if isOccupationalTitleCliche(title) { score -= 40 }

        let lower = title.lowercased()
        let curiosityWords = ["niemand", "nie", "letzte", "letzter", "letztes", "bevor", "wenn",
                              "warum", "was", "kein", "keiner", "still", "schweigen", "lüge",
                              "geheimnis", "schatten", "blut", "nacht", "tod", "verloren",
                              "vergiss", "sag", "bleib", "komm",
                              // Romance/Sehnsucht (größter KDP-Markt)
                              "küss", "berühr", "versprich", "gehörst", "mein", "dein",
                              "sehnsucht", "verboten", "verbotene", "zwischen uns", "ansieht",
                              "begehr", "herz", "haut", "näher", "fremder"]
        if curiosityWords.contains(where: { lower.contains($0) }) { score += 14 }
        if lower.contains(" und ") || lower.contains(" oder ") || title.contains(",") { score += 6 }
        if lower.contains("dich") || lower.contains("dir") || lower.contains(" du ") { score += 6 }

        // POLARISIERUNG: Titel mit Tabu-/Anschuldigungs-/Dilemma-Ladung lösen sofort eine
        // Reaktion aus und werden geklickt – gefällige Titel werden überscrollt.
        let polarizingWords = ["schuld", "verrat", "betrog", "belog", "rache", "sünde", "hass",
                               "hasse", "monster", "teufel", "verboten", "gehörst", "niemals",
                               "gestehe", "geständnis", "beichte", "stahl", "zerstör", "feind",
                               "ehemann", "witwe", "affäre", "bett"]
        if polarizingWords.contains(where: { lower.contains($0) }) { score += 12 }
        // Ich-/Du-Konfrontation („Ich habe …", „Du hast …") = Geständnis/Anschuldigung.
        if lower.hasPrefix("ich ") || lower.hasPrefix("du ") { score += 6 }

        // Deko-Titel dürfen nie gewinnen: ohne jedes Spannungssignal bleibt der Titel
        // ein hübsches Bild ohne Sog („Unser Sommer in der blauen Küche").
        if !hatSpannungssignal(title) { score -= 45 }
        if istBaukastenTitel(title) { score -= 30 }

        return max(0, score)
    }

    /// Trägt der Titel ein Versprechen, einen Konflikt oder eine Ansprache?
    ///
    /// Ein Titel ohne jedes dieser Signale beschreibt nur eine Kulisse. Genau das
    /// war der Fehler bei „Unser Sommer in der blauen Küche": schön, aber niemand
    /// erfährt daraus, was auf dem Spiel steht – und niemand klickt darauf.
    static func hatSpannungssignal(_ rawTitle: String) -> Bool {
        let lower = rawTitle.lowercased()
        let wörter = Set(lower.components(separatedBy: CharacterSet.letters.inverted)
                            .filter { !$0.isEmpty })

        // Wortstämme, die überall im Titel greifen dürfen: sie sind lang genug,
        // um nicht versehentlich in einem harmlosen Wort zu stecken.
        let stämme = ["niemand", "niemals", "nichts", "letzt", "bevor", "warum",
                      "lüge", "lügst", "gelogen", "geheim", "schweig", "verschwieg",
                      "schuld", "verrat", "betrog", "belog", "rache", "sünde",
                      "verboten", "verlier", "verlor", "verloren", "vergiss", "vergessen",
                      "stirb", "blut", "angst", "gefahr", "jagd", "mörder", "mord",
                      "versprich", "versprechen", "gestehe", "geständnis", "beicht",
                      "gehörst", "begehr", "sehnsucht", "küss", "berühr",
                      "zwischen uns", "hass", "feind", "affäre", "fremder",
                      "flucht", "fliehen", "wartet", "vorbei", "zerbrich", "zerbrach"]
        if stämme.contains(where: { lower.contains($0) }) { return true }

        // Kurze Signalwörter NUR als ganzes Wort prüfen – sonst schlägt „uns" in
        // „unser" an und ausgerechnet der Deko-Titel käme durch.
        let signalwörter: Set<String> = [
            "nie", "kein", "keine", "keiner", "keinen", "nicht", "ohne",
            "uns", "dich", "dir", "du", "ich", "mich", "mir", "dein", "deine",
            "was", "wer", "wen", "wem", "wie", "wenn", "wo", "bis", "denn",
            "ende", "endet", "enden", "schluss", "spät", "zurück", "wieder", "immer",
            "nur", "einzig", "einziges", "einzige", "einmal", "mal",
            "tod", "tot", "sag", "sagst", "bleib", "bleibst", "komm", "lass",
            "haut", "hätte", "hätt", "würde", "sollte", "musst", "darfst", "kannst",
            "wirst", "warte", "such", "suche", "finde", "geh", "gehst", "bleiben"
        ]
        if !signalwörter.isDisjoint(with: wörter) { return true }

        // Frage oder Ausruf = eingebaute Reaktion.
        if rawTitle.contains("?") || rawTitle.contains("!") { return true }
        return false
    }

    /// Der Baukasten-Titel: Possessiv/Artikel + Zeitangabe + „in dem/der" + erfundenes
    /// Detail. Diese Bauart entsteht, wenn ein Modell Anker-Vorgaben mechanisch
    /// abarbeitet, statt eine Geschichte zu versprechen – sie klingt immer konstruiert.
    static func istBaukastenTitel(_ rawTitle: String) -> Bool {
        let lower = rawTitle.lowercased()
        let zeit = ["sommer", "winter", "frühling", "herbst", "jahr", "tage", "tag",
                    "nacht", "nächte", "woche", "monat", "juli", "august", "september"]
        let ortsfuge = [" in der ", " in dem ", " im ", " in den ", " am ", " an der ",
                        " auf der ", " auf dem ", " hinter der ", " unter dem "]
        let hatZeit = zeit.contains { lower.contains($0) }
        let hatOrtsfuge = ortsfuge.contains { lower.contains($0) }
        let hatBesitz = ["unser", "mein", "dein", "ihr "].contains { lower.hasPrefix($0) }
        // Erst die Kombination macht den Baukasten aus – „Die letzte Nacht" bleibt gut.
        return hatZeit && hatOrtsfuge && (hatBesitz || lower.hasPrefix("der ")
                                          || lower.hasPrefix("die ") || lower.hasPrefix("das "))
    }

    /// Untergrenze für einen veröffentlichbaren Titel. Darunter wird der Titel
    /// verworfen und – mit konkreter Begründung – neu angefordert.
    static let titelMindestScore = 70

    /// Warum ist der Titel durchgefallen? Der Text geht wörtlich in den nächsten
    /// Versuch. Diese Rückkopplung hat schon bei den Szenenreparaturen die Trefferquote
    /// vervielfacht – Modelle korrigieren gezielt, wenn sie den Grund kennen.
    static func titelAblehnungsgrund(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "leer" }
        let teile = trimmed.split(whereSeparator: \.isWhitespace)
        if teile.count > 1, let nummer = Int(teile.last ?? ""), (2...500).contains(nummer) {
            return "„\(title)“ wirkt wie ein nummeriertes Duplikat. Jeder Buchtitel muss eigenständig sein."
        }
        if trimmed.range(of: #"\s+[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil {
            return "„\(title)“ enthält einen technischen Eindeutigkeitszusatz statt eines echten Titels."
        }
        if istKopieBekannterTitel(title) {
            return "„\(title)“ liegt zu nah an einem existierenden Bestseller – Titel müssen eigenständig sein."
        }
        if istBaukastenTitel(title) {
            return "„\(title)“ ist ein Baukasten-Titel (Possessiv + Jahreszeit + Ortsangabe mit erfundenem Detail). Diese Bauart klingt konstruiert und verspricht nichts."
        }
        if !hatSpannungssignal(title) {
            return "„\(title)“ beschreibt nur eine Kulisse. Es fehlt das Versprechen: kein Konflikt, kein Geheimnis, keine Ansprache – niemand erfährt, was auf dem Spiel steht."
        }
        if titelWirktVerkopft(title) {
            return "„\(title)“ ist verkopft/abstrakt. Leser suchen keine Wort-Collagen."
        }
        if titleViralityScore(title) < titelMindestScore {
            return "„\(title)“ ist zu schwach und austauschbar (Sog-Wert unter der Mindestgrenze)."
        }
        return nil
    }

    /// Endet das Kapitel ohne Sog? (Rein deterministisch – erkennt ruhige Beschreibungs-
    /// Enden ohne Frage, Zuspitzung oder kurzen Schlag.) Wird für Nicht-Schlusskapitel
    /// in die Revision eingespeist: „Kapitelende schärfen".
    static func hasWeakChapterEnding(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.wordCount >= 120 else { return false } // Kurztexte nicht beurteilen
        let tail = String(trimmed.suffix(400))
        // Frage oder abgebrochene Rede im Schluss = Sog vorhanden.
        if tail.contains("?") { return false }
        if tail.hasSuffix("…") || tail.hasSuffix("–") || tail.hasSuffix("-") { return false }
        // Letzten Satz isolieren (nach dem letzten Satzende davor).
        let sentences = tail.components(separatedBy: CharacterSet(charactersIn: ".!…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let last = sentences.last else { return true }
        // Kurzer Schlusssatz (≤ 8 Wörter) = bewusster Schlag/Punch → stark.
        if last.wordCount <= 8 { return false }
        // Endet in wörtlicher Rede → meist Zuspitzung/Drohung → stark.
        if tail.hasSuffix("\"") || tail.hasSuffix("“") || tail.hasSuffix("«") || tail.hasSuffix("»") { return false }
        return true
    }

    /// Wählt aus der Antwort des viralen Titel-Prompts (KANDIDATEN + BESTER) den stärksten
    /// brauchbaren Titel. Bevorzugt die Modell-Wahl, fällt sonst auf den höchstbewerteten Kandidaten.
    static func chooseViralTitle(from response: String, genre: String) -> String {
        var best = ""
        var candidates: [String] = []
        for raw in response.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.lowercased().hasPrefix("bester"), let colon = line.firstIndex(of: ":") {
                best = cleanTitleLine(String(line[line.index(after: colon)...]))
            } else if line.range(of: #"^\d+[\)\.\-:]"#, options: .regularExpression) != nil {
                let t = cleanTitleLine(line.replacingOccurrences(of: #"^\d+[\)\.\-:]\s*"#, with: "", options: .regularExpression))
                if !t.isEmpty { candidates.append(t) }
            }
        }
        if isUsableTitle(best, genre: genre) { return best }
        let usable = candidates.filter { isUsableTitle($0, genre: genre) }
        let score: (String) -> Int = BookContentType.infer(from: genre) == .nonfiction
            ? nonfictionTitleScore
            : titleViralityScore
        if let top = usable.max(by: { score($0) < score($1) }) { return top }
        return best.isEmpty ? (candidates.first ?? "") : best
    }

    private static func cleanTitleLine(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'„“”»«*-–—_.").union(.whitespacesAndNewlines))
    }

    /// Ist der Titel durch das GESCHRIEBENE Buch gedeckt?
    ///
    /// Modelle erfinden gern klangvolle Titel mit Begriffen, die im Buch gar nicht
    /// vorkommen („Der Drachenthron" für einen Krimi). Solche Titel enttäuschen Leser
    /// nach dem Klick – und enttäuschte Leser sind auf Amazon teurer als ein
    /// unspektakulärer Titel. Deshalb muss mindestens ein inhaltstragendes Wort des
    /// Titels wirklich im Manuskript stehen.
    static func titleIsCoveredByBook(_ title: String, chapters: [String]) -> Bool {
        let stoppwoerter: Set<String> = ["der", "die", "das", "ein", "eine", "und", "oder",
                                         "von", "dem", "den", "des", "im", "in", "auf", "mit", "für"]
        let woerter = title.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 4 && !stoppwoerter.contains($0) }
        guard !woerter.isEmpty else { return true }   // reine Funktionswörter: nichts zu prüfen
        let text = chapters.joined(separator: " ").lowercased()
        return woerter.contains { text.contains($0) }
    }

    /// Brauchbar als gewählter Titel (Länge ok, kein Platzhalter/Berufsklischee/Genre-Label).
    static func isUsableTitle(_ title: String, genre: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = t.split(separator: " ").count
        return t.count >= 4 && words >= 1 && words <= 7 && !isWeakTitle(t, genre: genre)
    }

    /// Schwacher Titel, der ersetzt werden soll: Platzhalter, Berufsklischee oder reines Genre-Label.
    static func isWeakTitle(_ title: String, genre: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if isGenericPlaceholder(t) || isOccupationalTitleCliche(t) { return true }
        if CopyrightChecker.isInfringingTitle(t) { return true } // kein geschützter Werk-/Reihentitel

        let low = t.lowercased()
        let genreLabels = ["liebesroman", "erotik-roman", "erotikroman", "erotik", "thriller", "krimi",
                           "roman", "dark romance", "romance", "fantasy", "new adult", "romantasy"]
        let nonfictionLabels = BookContentType.nonfictionGenres.map { $0.lowercased() }
        return genreLabels.contains(low) || nonfictionLabels.contains(low) || low == genre.lowercased()
    }

    private static func nonfictionTitleScore(_ title: String) -> Int {
        let words = title.split(whereSeparator: \.isWhitespace).count
        var score = 70
        if (2...6).contains(words) { score += 16 }
        if title.contains(":") { score += 6 }
        let lower = title.lowercased()
        if ["garantiert", "mühelos", "sofort reich", "für immer", "wunder"].contains(where: lower.contains) {
            score -= 50
        }
        if lower.hasPrefix("ich ") || lower.hasPrefix("du ") { score -= 8 }
        return max(0, score)
    }

    /// Warum ein einzelnes Kapitel unbrauchbar ist – oder `nil`, wenn es taugt.
    ///
    /// **Warum es diese Funktion zusätzlich zu `hasUsableChapterPlan` gibt.**
    /// Die Ja/Nein-Prüfung sagt nicht, WELCHES Kapitel scheitert. Gemessen an der
    /// Produktion vom 10.08.2026, 14:59: Die Lückenfüllung lieferte einen vollständigen
    /// Plan, die Prüfung lehnte ihn ab, und in der Meldung stand „Ergänzung unvollständig
    /// (12/12)" – eine Zahl, die dem Leser nichts sagt und dem Programm nichts zu tun gibt.
    ///
    /// Mit dem konkreten Grund lässt sich ein dünnes Kapitel wie ein fehlendes behandeln:
    /// Beides sind Lücken, und beide werden gezielt nachgeplant statt den ganzen Plan zu
    /// verwerfen.
    static func kapitelMangel(_ chapter: PlannedChapter) -> String? {
        if isGenericPlaceholder(chapter.title) {
            return "Titel ist eine Schablone (\u{201E}\(chapter.title.prefix(40))\u{201C})"
        }
        if isGenericPlaceholder(chapter.goal) {
            return "Kapitelziel ist eine Schablone"
        }
        if chapter.goal.wordCount < 5 {
            return "Kapitelziel zu dünn (\(chapter.goal.wordCount) Wörter, nötig 5)"
        }
        if chapter.conflict.wordCount < 3 {
            return "Konflikt zu dünn (\(chapter.conflict.wordCount) Wörter, nötig 3)"
        }
        return nil
    }

    static func hasUsableChapterPlan(_ chapters: [PlannedChapter]) -> Bool {
        guard chapters.count >= 3 else { return false }
        return chapters.allSatisfy { chapter in
            !isGenericPlaceholder(chapter.title)
                && !isGenericPlaceholder(chapter.goal)
                && chapter.goal.wordCount >= 5
                && chapter.conflict.wordCount >= 3
        }
    }

    /// Harte Freigabe vor dem Speichern eines Kapitelplans. Nur objektiv
    /// unbehebbare Strukturfehler blockieren; sprachbasierte Dramaturgie- und
    /// Kausalitaetsheuristiken bleiben Hinweise fuer die Ueberarbeitungsrunden.
    static func chapterPlanReleaseIssues(_ chapters: [PlannedChapter],
                                         expectedCount: Int,
                                         isNonfiction: Bool) -> [String] {
        var issues: [String] = []
        let sorted = chapters.sorted { $0.number < $1.number }
        if sorted.count != expectedCount {
            issues.append("unvollstaendiger Kapitelplan (\(sorted.count) statt \(expectedCount))")
        }
        let expectedNumbers = expectedCount > 0 ? Array(1...expectedCount) : []
        let actualNumbers = sorted.map(\.number)
        if actualNumbers != expectedNumbers {
            issues.append("Kapitelnummern sind nicht lueckenlos: \(actualNumbers)")
        }
        if !hasUsableChapterPlan(sorted) {
            issues.append("mindestens ein Kapitel ist inhaltlich unbrauchbar")
        }
        if !isNonfiction {
            if let final = sorted.last, final.number == expectedCount {
                issues.append(contentsOf: finalChapterResolutionIssues(final))
            } else {
                issues.append("Schlusskapitel fehlt")
            }
        }
        return Array(Set(issues)).sorted()
    }

    static func hasUsableScenePlan(_ scenes: [PlannedScene], expectedCount: Int) -> Bool {
        guard scenes.count >= expectedCount else { return false }
        let requiredScenes = Array(scenes.prefix(expectedCount))
        return requiredScenes.allSatisfy { scene in
            !scene.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !scene.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && scene.goal.wordCount >= 5
                && scene.obstacle.wordCount >= 3
                && scene.turn.wordCount >= 3
                && !isGenericPlaceholder(scene.goal)
                && !isGenericPlaceholder(scene.obstacle)
                && !isGenericPlaceholder(scene.turn)
        }
    }

    /// Harte Freigabe fuer einen Szenenplan, bevor daraus Prosa entstehen darf.
    /// Ein unvollstaendiger oder doppelter Plan laesst sich spaeter nicht verlaesslich
    /// reparieren: Der Draft Writer erzaehlt dann zwangsläufig denselben Beat erneut.
    static func szenenplanMaengel(_ scenes: [PlannedScene], erwarteteAnzahl: Int) -> [String] {
        guard erwarteteAnzahl > 0 else { return ["ungueltige erwartete Szenenzahl"] }

        var maengel: [String] = []
        if scenes.count != erwarteteAnzahl {
            maengel.append("unvollstaendiger Plan (\(scenes.count) statt \(erwarteteAnzahl) Szenen)")
        }

        let requiredScenes = Array(scenes.prefix(erwarteteAnzahl))
        var hatKonkretenFeldfehler = false
        for scene in requiredScenes {
            var felder: [String] = []
            if scene.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                felder.append("Ort fehlt")
            }
            if scene.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                felder.append("Zeit fehlt")
            }
            if scene.goal.wordCount < 5 || isGenericPlaceholder(scene.goal) {
                felder.append("Ziel zu kurz oder allgemein")
            }
            if scene.obstacle.wordCount < 3 || isGenericPlaceholder(scene.obstacle) {
                felder.append("Hindernis zu kurz oder allgemein")
            }
            if scene.turn.wordCount < 3 || isGenericPlaceholder(scene.turn) {
                felder.append("Wendung zu kurz oder allgemein")
            }
            if !felder.isEmpty {
                hatKonkretenFeldfehler = true
                maengel.append("Szene \(scene.number): " + felder.joined(separator: ", "))
            }
        }
        if !hasUsableScenePlan(requiredScenes, expectedCount: erwarteteAnzahl),
           !hatKonkretenFeldfehler {
            maengel.append("mindestens eine Szene ist inhaltlich unbrauchbar")
        }

        let erwarteteNummern = Array(1...erwarteteAnzahl)
        if requiredScenes.map(\.number) != erwarteteNummern {
            maengel.append("Szenennummern sind nicht lueckenlos 1 bis \(erwarteteAnzahl)")
        }
        if istGenerischerSzenenplan(requiredScenes) {
            maengel.append("nur allgemeine Standard-Beats ohne konkrete Ereignisse")
        }

        maengel.append(contentsOf: duplicatedSceneBeats(requiredScenes))

        var fruehereZiele: [String] = []
        for scene in requiredScenes {
            let doppelungen = doppelteSzenenziele(
                neueZiele: [scene.goal], bekannteZiele: fruehereZiele
            )
            if !doppelungen.isEmpty {
                maengel.append("Szene \(scene.number) wiederholt ein Ziel innerhalb des Kapitels")
            }
            fruehereZiele.append(scene.goal)
        }

        var gesehen = Set<String>()
        return maengel.filter { gesehen.insert($0).inserted }
    }

    /// A stored plan is grandfathered across app upgrades when its objective structure
    /// is complete. Similarity heuristics still reject newly generated plans, but must
    /// not delete an accepted future roadmap halfway through a manuscript.
    static func persistedScenePlanIsUsable(_ scenes: [PlannedScene],
                                           expectedCount: Int) -> Bool {
        guard expectedCount > 0, scenes.count == expectedCount else { return false }
        let requiredScenes = Array(scenes.prefix(expectedCount))
        guard requiredScenes.map(\.number) == Array(1...expectedCount) else { return false }
        return hasUsableScenePlan(requiredScenes, expectedCount: expectedCount)
            && !istGenerischerSzenenplan(requiredScenes)
    }

    /// Oberer Umfang-Korridor: Bei kleinen Szenenzielen (< 300 Woerter) schreiben
    /// Schreibmodelle natuerlicherweise 400-650 Woerter; ein enger 1.25x-Deckel
    /// fuehrt dort nur zu Endlos-Verdichtung. Langform bleibt streng (1.25x).
    static func sceneUpperRatio(forTargetWords targetWords: Int) -> Double {
        targetWords < 300 ? 1.7 : 1.25
    }

    static func acceptsDraftScene(_ text: String, targetWords: Int) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        guard !containsMetaRequest(cleaned) else { return false }
        guard hasCompleteSentenceEnding(cleaned) else { return false }
        guard !PublicContentGuard.disclosureViolation(in: cleaned) else { return false }
        let minimum = max(80, Int(Double(targetWords) * 0.55))
        let maximum = max(minimum, Int(Double(targetWords) * sceneUpperRatio(forTargetWords: targetWords)))
        return cleaned.wordCount >= minimum && cleaned.wordCount <= maximum
    }

    /// Harte, deterministische Gruende, aus denen eine Rohszene nicht gespeichert werden
    /// darf. Stil- und Klarheitsbefunde gehoeren absichtlich nicht hierher: Sie sind weich,
    /// werden im Repair-Audit bearbeitet und duerfen keinen identischen Endlos-Retry
    /// ausloesen. Diese Grenze schuetzt nur vor echtem Datenmuell.
    static func draftPersistenceIssues(_ text: String, targetWords: Int) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()
        let stubFloor = max(60, Int(Double(targetWords) * 0.25))
        var issues: [String] = []
        if cleaned.wordCount < stubFloor { issues.append("zu kurz") }
        if !hasCompleteSentenceEnding(cleaned) { issues.append("unvollstaendiges Satzende") }
        if lower.contains("muss noch ausgeschrieben werden")
            || lower.contains("geplanter inhalt:") {
            issues.append("Platzhalter")
        }
        if containsPromptArtifacts(cleaned) { issues.append("Promptreste") }
        if containsMetaRequest(cleaned) { issues.append("Meta-Anweisung") }
        if !dialogOhneAnfuehrungszeichen(in: cleaned).isEmpty {
            issues.append("unmarkierte direkte Rede")
        }
        if PublicContentGuard.disclosureViolation(in: cleaned) {
            issues.append("unzulässiger Offenlegungstext")
        }
        if !ContentSafetyFilter.isSafe(cleaned) { issues.append("Inhaltssperre") }
        return issues
    }

    /// Harte Speichergrenzen enthalten nur objektiv unbrauchbaren Text und Namen,
    /// die nachweislich schon zu einem anderen Buch gehoeren. Freie Eigennamen- und
    /// Requisitenheuristiken bleiben Repair-Hinweise: NaturalLanguage stuft auch
    /// Rollenwoerter wie "Schwager" als Person ein, und "Ring" kann ebenso ein
    /// Telefonklingeln wie ein Schmuckstueck sein.
    static func hardDraftPersistenceIssues(_ text: String, targetWords: Int,
                                           allowedNames: [String],
                                           forbiddenNames: Set<String>) -> [String] {
        var issues = draftPersistenceIssues(text, targetWords: targetWords)
        let mentionedPersonParts = Set(
            CharacterCanonAudit.personNames(in: text)
                .flatMap(CharacterCanonAudit.nameParts)
        )
        let foreignNames = foreignCatalogNameMentions(
            in: text,
            allowedNames: allowedNames,
            forbiddenNames: forbiddenNames
        ).filter { rawName in
            !Set(CharacterCanonAudit.nameParts(rawName))
                .isDisjoint(with: mentionedPersonParts)
        }
        if !foreignNames.isEmpty {
            issues.append(
                "Namen aus frueheren Buechern: "
                    + foreignNames.prefix(4).joined(separator: ", ")
            )
        }
        return issues
    }

    /// Gemeinsame harte Speichergrenze fuer Rohszenen. Nur Text, der auch nach einem
    /// App-Neustart als geschrieben gelten wuerde, darf im laufenden Durchgang den
    /// Status `.written` erhalten. Stilmaengel bleiben sichtbar, werden aber spaeter
    /// repariert, statt den bereits erzeugten Inhalt zu verwerfen.
    static func isPersistableDraftText(_ text: String, targetWords: Int) -> Bool {
        draftPersistenceIssues(text, targetWords: targetWords).isEmpty
    }

    static func isWithinWordTarget(_ text: String, targetWords: Int,
                                   lowerRatio: Double = 0.75,
                                   upperRatio: Double? = nil) -> Bool {
        guard targetWords > 0 else { return !text.isEmpty }
        let upper = upperRatio ?? sceneUpperRatio(forTargetWords: targetWords)
        let count = text.wordCount
        return count >= Int(Double(targetWords) * lowerRatio)
            && count <= Int(Double(targetWords) * upper)
    }

    static func isGenericPlaceholder(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.isEmpty { return true }
        if normalized == "titel" || normalized == "neues buch" || normalized == "unbenannt" { return true }
        if normalized.range(of: #"^kapitel\s+\d+$"#, options: .regularExpression) != nil {
            return true
        }
        if normalized.range(
            of: #"^(aufbruch|eskalation|krise|auflösung|orientierung|grundlagen|anwendung|transfer)\s+\d+$"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        let patterns = [
            "roman-roman",
            "setze den plot konsequent fort",
            "führe das kapitelziel weiter",
            "vertiefe das kapitelziel",
            "treibe den hauptkonflikt in der",
            "ein konkretes hindernis stellt sich dem ziel dieses kapitels entgegen",
            "vermittle in der phase",
            "ein typisches verständnis- oder umsetzungshindernis",
            "nächstes buch",
            "untitled"
        ]
        if patterns.contains(where: { normalized == $0 || normalized.hasPrefix($0) }) { return true }
        let hollowPlanningPhrases = [
            "bringt die hauptfigur durch",
            "blockiert das unmittelbare vorankommen",
            "eine neue wendung verschiebt die lage",
            "enthüllt eine information, die das kräfteverhältnis",
            "lässt einen rückschlag den einsatz",
            "einstieg: die perspektivfigur",
            "komplikation: ausgehend vom ende",
            "zuspitzung: die folgen der vorigen szenen",
            "wende und übergang: eine entscheidung oder enthüllung"
        ]
        return hollowPlanningPhrases.contains(where: normalized.contains)
    }

    /// Verhindert Auto-Buchtitel nach schwachen Berufs-Hooks wie
    /// "Die Imkerin von Ulrichstein" oder "Das Schweigen der Imkerin".
    /// Berufe dürfen in der Geschichte vorkommen, aber nicht als austauschbarer
    /// Titel-Hook die komplette Idee tragen.
    static func isOccupationalTitleCliche(_ title: String) -> Bool {
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }

        let occupationalWords = [
            "imkerin", "imker", "kassiererin", "kassierer", "bäckerin", "bäcker",
            "lehrerin", "lehrer", "ärztin", "arzt", "pflegerin", "pfleger",
            "polizistin", "polizist", "anwältin", "anwalt", "journalistin", "journalist",
            "floristin", "florist", "bibliothekarin", "bibliothekar",
            "buchhändlerin", "buchhändler", "friseurin", "friseur", "sekretärin",
            "sekretär", "köchin", "koch", "architektin", "architekt",
            "ingenieurin", "ingenieur", "forscherin", "forscher", "maklerin",
            "makler", "verkäuferin", "verkäufer", "fahrerin", "fahrer",
            "taxifahrerin", "taxifahrer", "gärtnerin", "gärtner", "wirtin", "wirt"
        ]
        let locationConnectors = [" von ", " aus ", " in ", " am ", " an der ", " im "]
        let genericGenitiveHooks = [
            "geheimnis", "schweigen", "lüge", "wahrheit", "versprechen", "tagebuch",
            "brief", "erbe", "schatten", "lied", "haus", "leben", "liebe",
            "winter", "sommer", "nacht", "stimme", "spur", "rückkehr"
        ]

        let hasArticlePrefix = normalized.hasPrefix("die ") || normalized.hasPrefix("der ")
            || normalized.hasPrefix("das ") || normalized.hasPrefix("eine ")
            || normalized.hasPrefix("ein ")
        guard hasArticlePrefix else {
            return false
        }

        for word in occupationalWords {
            guard normalized.range(of: #"\b\#(word)\b"#, options: .regularExpression) != nil else {
                continue
            }
            if normalized.range(of: #"^(die|der|das|eine|ein)\s+\#(word)\b"#, options: .regularExpression) != nil {
                return true
            }
            if locationConnectors.contains(where: normalized.contains) {
                return true
            }
            let usesGenericGenitiveHook = genericGenitiveHooks.contains { hook in
                normalized.range(of: #"\b\#(hook)\b"#, options: .regularExpression) != nil
            }
            if usesGenericGenitiveHook
                && normalized.range(of: #"\b(der|des|einer|eines)\s+\#(word)\b"#,
                                    options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    static func containsMetaRequest(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let patterns = [
            "bitte füge",
            "bitte gib",
            "fehlt in deiner",
            "nicht übermittelt",
            "nicht im prompt enthalten",
            "keine szene bereitgestellt",
            "szene fehlt",
            "szenentext fehlt",
            "muss noch ausgeschrieben werden",
            "im manuskript neu erzeugen",
            "geplanter inhalt:",
            "ich kann die szene leider nicht schreiben",
            "ich benötige noch",
            "fehlende angaben",
            "als sprachmodell",
            "als ki-modell",
            "kann ich nicht schreiben",
            "kann ich nicht erstellen",
            "kann ich nicht verfassen",
            "kann ich nicht generieren",
            "kann ich nicht beantworten",
            "kann ich dieser anfrage nicht"
        ]
        if patterns.contains(where: { normalized.contains($0) }) { return true }
        // "als ki" nur als eigenständiges Wort – sonst matcht es "als Kind",
        // "als Kino" usw. und verwirft korrekte Romantexte.
        return normalized.range(of: #"\bals ki\b"#, options: .regularExpression) != nil
    }

    /// Unverwechselbare Instruktions-Fragmente aus den Prompts. Tauchen sie im
    /// generierten Text auf, hat das Modell eine Anweisung in die Prosa kopiert.
    static let promptInstructionMarkers = [
        "knüpfe nahtlos daran an",
        "knüpfe daran an",
        "setze die szene unmittelbar fort",
        "ohne das geschehene zu wiederholen",
        "wörtliches ende der vorherigen szene",
        "bisherige handlung",
        "letzte szenen im detail",
        "bisherige kapitel",
        "genre-handwerk",
        "verbotene floskeln",
        "sog-techniken",
        "keine überschriften",
        "keine meta-kommentare",
        "meta-kommentar",
        "langform-pflicht",
        "schreibe ausschließlich auf",
        "schreibe die szene",
        "schreibe szene",
        "der erste satz ist der wichtigste",
        "erste szene des buches",
        "letzte szene des buches",
        "beginne mitten in der bewegung",
        "zeigen statt behaupten",
        "dialog mit subtext",
        "bestseller-standard",
        "gib ausschließlich den fertigen prosatext",
        "übernimm niemals anweisungen",
        "hinweise aus diesem auftrag",
        "fertigen prosatext der szene",
        "zielumfang"
    ]

    /// Teilmenge der Marker, die GELÖSCHT werden dürfen: nur eindeutige
    /// Anweisungs-Fragmente, die in echter Belletristik praktisch nie vorkommen.
    /// Mehrdeutige Marker (z.B. „schreibe die szene", „bisherige handlung",
    /// „der erste satz ist der wichtigste") lösen weiterhin eine Neufassung aus
    /// (via `promptInstructionMarkers`), werden aber NICHT satzweise gelöscht –
    /// sonst verschwänden legitime Dialog-/Erzählsätze und der Lesefluss bräche.
    static let deletableInstructionMarkers = [
        "knüpfe nahtlos daran an",
        "knüpfe daran an",
        "setze die szene unmittelbar fort",
        "ohne das geschehene zu wiederholen",
        "wörtliches ende der vorherigen szene",
        "letzte szenen im detail",
        "genre-handwerk",
        "verbotene floskeln",
        "sog-techniken",
        "keine überschriften",
        "keine meta-kommentare",
        "langform-pflicht",
        "gib ausschließlich den fertigen prosatext",
        "übernimm niemals anweisungen",
        "hinweise aus diesem auftrag",
        "fertigen prosatext der szene",
        "bestseller-standard",
        "zielumfang"
    ]

    /// Prompt-Labels, die als eigene Zeile auftauchen, wenn das Modell die
    /// Szenen-Vorgabe abschreibt.
    static let promptLabelPrefixes = [
        "stil:", "stilregeln:", "kapitelziel:", "sprache:", "tonalität:",
        "perspektive:", "erzählperspektive:", "zeitform:", "ort:", "zeit:",
        "ziel:", "hindernis:", "wendung am ende:", "wendung:", "figuren:",
        "szene:", "thema:", "zielumfang:", "zielwörter:", "zielwortzahl:",
        "genre:", "tonalität:", "kapitel:", "- ort:", "- zeit:", "- ziel:",
        "- hindernis:", "- wendung", "verdichtete fassung", "überarbeitete fassung",
        "ueberarbeitete fassung", "endfassung"
    ]

    /// Hat das Modell eine Prompt-Anweisung/-Label in die Prosa durchsickern lassen?
    /// Wird beim Schreiben genutzt, um eine betroffene Szene NEU zu generieren.
    static func containsPromptArtifacts(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if promptInstructionMarkers.contains(where: { lowered.contains($0) }) { return true }
        for line in text.components(separatedBy: .newlines) {
            let l = line.trimmingCharacters(in: .whitespaces).lowercased()
            if promptLabelPrefixes.contains(where: { l.hasPrefix($0) }) { return true }
        }
        return false
    }

    /// Entfernt durchgesickerte Prompt-Anweisungen/-Labels aus generierter Prosa –
    /// SATZGENAU, damit auch ein mitten im Absatz eingebetteter Anweisungssatz
    /// verschwindet, ohne die umgebende Erzählung zu beschädigen. Reine Label-Zeilen
    /// (z.B. „Ort: Bäckerei") werden komplett entfernt. Das darf NIE im Buch landen.
    /// Entfernt eine vom Modell vorangestellte ÜBERSCHRIFT aus dem Szenentext.
    ///
    /// Der Auftrag lautet „Schreibe diese Szene als vollständige Endfassung neu" – viele
    /// Modelle setzen daraufhin eine Kopfzeile davor: „Kapitel 34, Szene 2 – Endfassung".
    /// An einem fertigen Buch gemessen betraf das 39 von 184 Szenen, also über ein
    /// Fünftel des Manuskripts. Ohne diese Reinigung stehen die Zeilen im gedruckten Buch.
    ///
    /// Entfernt werden nur ERSTE Zeilen, die eindeutig eine Arbeitsangabe sind – ein
    /// echter Kapiteltitel oder ein Prosa-Anfang bleibt unangetastet.
    /// Erzwingt die kanonischen Figurennamen aus der Story Bible.
    ///
    /// Das szenenweise erzeugte Manuskript vertauscht Nachnamen zwischen Figuren – ein
    /// klassischer LLM-Fehler. Am frisch produzierten Buch „Sie hat mich geküsst, bevor
    /// sie starb" nachgewiesen: Der Held heißt in der Story Bible „Jonas Brenner", im
    /// Text stand aber 2× „Jonas Hartmann" – „Hartmann" ist der Nachname der Figur Lina.
    /// Die Konsistenzprüfung meldete das als KRITISCH („zwei Personen oder
    /// Namensinkonsistenz?") und das Buch fiel zu Recht durch.
    ///
    /// Diese Korrektur ist streng begrenzt und dadurch sicher: Ersetzt wird nur
    /// „Vorname FremderNachname", wobei der FremderNachname NACHWEISLICH einer ANDEREN
    /// Figur gehört. Ein Vorname mit unbekanntem Nachnamen bleibt unangetastet, ebenso
    /// Geschwister mit gleichem Nachnamen (Clara/Mira/Niko Voss).
    ///
    /// - Parameter namen: kanonische vollständige Namen aus der Story Bible.
    static func enforcingNameCanon(_ text: String, namen: [String]) -> (text: String, korrekturen: [String]) {
        // Vorname → richtiger Nachname; Menge aller bekannten Nachnamen.
        var vorZuNach: [String: String] = [:]
        var nachnamen = Set<String>()
        let anreden: Set<String> = ["herr", "frau", "dr", "dr.", "prof", "prof.", "sir", "lady", "miss", "mr", "mrs"]
        for name in namen {
            let teile = name.split(separator: " ").map(String.init)
            guard teile.count >= 2 else { continue }
            let vor = teile[0], nach = teile[teile.count - 1]
            guard vor.count >= 3, nach.count >= 3, !anreden.contains(vor.lowercased()) else { continue }
            vorZuNach[vor] = nach
            nachnamen.insert(nach)
        }
        guard !vorZuNach.isEmpty else { return (text, []) }

        var ergebnis = text
        var korrekturen: [String] = []
        for (vor, richtig) in vorZuNach {
            for falsch in nachnamen where falsch != richtig {
                // Nur echte Vertauschung: „Vorname FremderNachname" → „Vorname RichtigerNachname".
                let muster = "\\b" + NSRegularExpression.escapedPattern(for: vor)
                    + "\\s+" + NSRegularExpression.escapedPattern(for: falsch) + "\\b"
                guard let re = try? NSRegularExpression(pattern: muster) else { continue }
                let bereich = NSRange(ergebnis.startIndex..., in: ergebnis)
                let treffer = re.numberOfMatches(in: ergebnis, range: bereich)
                guard treffer > 0 else { continue }
                ergebnis = re.stringByReplacingMatches(
                    in: ergebnis, range: bereich,
                    withTemplate: NSRegularExpression.escapedTemplate(for: "\(vor) \(richtig)"))
                korrekturen.append("\(vor) \(falsch)→\(vor) \(richtig) (\(treffer)×)")
            }
        }
        return (ergebnis, korrekturen)
    }

    /// Setzt deutsche Anführungszeichen richtig und räumt Satzzeichen-Doppler auf.
    ///
    /// Im ausgelieferten Buch nachgezählt: 3573 Zitate wurden mit dem typografischen „
    /// geöffnet, aber nur 2648 korrekt mit “ geschlossen – **967 endeten mit dem geraden
    /// Schreibmaschinen-Zeichen "**. Im gedruckten Buch und im E-Book sieht man das sofort.
    /// Dazu drei doppelte Satzpunkte („… nahm Lena das Metall des Rings wahr..").
    ///
    /// Die Umwandlung ist ortsabhängig: Ein gerades Zeichen VOR einem Buchstaben öffnet
    /// (wird „), eines NACH einem Buchstaben oder Satzzeichen schließt (wird “). Genau so
    /// setzt es ein Setzer auch.
    static func fixingTypography(_ text: String) -> String {
        var ergebnis = ""
        ergebnis.reserveCapacity(text.count)
        let zeichen = Array(text)
        for (i, c) in zeichen.enumerated() {
            guard c == "\"" else { ergebnis.append(c); continue }
            // Was steht davor, was danach?
            let davor = i > 0 ? zeichen[i - 1] : " "
            let danach = i + 1 < zeichen.count ? zeichen[i + 1] : " "
            let schliesst = davor.isLetter || davor.isNumber
                || ".,!?;:…".contains(davor) || davor == "\u{201C}"
            let oeffnet = danach.isLetter || danach.isNumber || danach == "\u{201E}"
            if schliesst {
                ergebnis.append("\u{201C}")           // “
            } else if oeffnet {
                ergebnis.append("\u{201E}")           // „
            } else {
                ergebnis.append("\u{201C}")           // im Zweifel schließen
            }
        }
        // Doppelte Satzpunkte, die keine Auslassung sind.
        while let r = ergebnis.range(of: "(?<![.])\\.\\.(?!\\.)", options: .regularExpression) {
            ergebnis.replaceSubrange(r, with: ".")
        }
        // Leerzeichen vor Satzzeichen – aber NICHT vor Auslassungspunkten: Dort gehört
        // im Deutschen ein Leerzeichen hin, wenn ein ganzes Wort ausgelassen ist
        // („Drei Punkte bleiben … erhalten"). Der erste Wurf zog das zusammen.
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]+([,;:!?])", with: "$1", options: .regularExpression)
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]+\\.(?![.\\s])", with: ".", options: .regularExpression)
        // Mehrfache Leerzeichen innerhalb einer Zeile.
        ergebnis = ergebnis.replacingOccurrences(
            of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        return ergebnis
    }

    /// Entfernt Arbeitsmarken ÜBERALL im Text – nicht nur in der ersten Zeile.
    ///
    /// WARUM DAS NÖTIG IST: Im ausgelieferten Buch „Das letzte Streichholz" standen
    /// 85 Arbeitsmarken mitten in der Prosa, verteilt über 21 von 46 Kapiteln:
    ///
    ///     KAPITEL 10, SZENE 1, VERSUCH 2/2
    ///     Kapitel 4, Szene 1 – Endfassung
    ///     KAPITZEL 36, SZENE 2, VERSUCH 1/2
    ///     ABSATZ:
    ///
    /// Diese Zeilen wurden mit dem EPUB zu Amazon hochgeladen. `strippingSceneHeading`
    /// half dagegen nicht: Es sieht nur die ERSTE Zeile an, wird nur an einer von mehreren
    /// Erzeugungsstellen aufgerufen, und sein Muster `^kapitel\s*\d+` greift beim
    /// Tippfehler „KAPITZEL" nicht.
    ///
    /// Diese Funktion arbeitet zeilenweise über den ganzen Text und ist gegen genau solche
    /// Verdreher tolerant. Sie entfernt NUR Zeilen, die als reine Arbeitsmarke erkennbar
    /// sind – kurz, ohne Satzschluss, mit Stellen- oder Fassungsangabe. Ein Prosasatz, der
    /// zufällig „Kapitel" enthält („Sie las das Kapitel zweimal."), bleibt stehen.
    /// - Parameter buchtitel: Steht der Buchtitel als eigene Zeile am Kapitelanfang, ist
    ///   das ebenfalls ein Erzeugungsrest. Im ausgelieferten Buch stand „Das letzte
    ///   Streichholz" als erste Zeile von Kapitel 1 – mitten im Prosatext, direkt vor dem
    ///   ersten Satz. Ein Satz, der den Titel beiläufig ENTHÄLT, bleibt unangetastet;
    ///   entfernt wird nur eine Zeile, die aus nichts anderem besteht.
    static func strippingProductionMarkers(_ text: String, buchtitel: String = "") -> String {
        let zeilen = text.components(separatedBy: .newlines)
        let titelNorm = buchtitel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var behalten: [String] = []
        var nurLeerzeilenBisher = true
        for zeile in zeilen {
            let roh = zeile.trimmingCharacters(in: .whitespacesAndNewlines)
            // Titelzeile nur am Anfang entfernen – später im Text könnte sie Absicht sein
            // (etwa ein Buch, das im Buch vorkommt).
            if nurLeerzeilenBisher, !titelNorm.isEmpty, roh.lowercased() == titelNorm { continue }
            if !roh.isEmpty { nurLeerzeilenBisher = false }
            if istArbeitsmarke(zeile) { continue }
            behalten.append(zeile)
        }
        // Durch entfernte Zeilen entstandene Dreifach-Leerzeilen wieder zusammenziehen.
        var ergebnis = behalten.joined(separator: "\n")
        while ergebnis.contains("\n\n\n") {
            ergebnis = ergebnis.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return ergebnis.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Einheitlicher letzter Filter für jeden Text, der in Datenbank oder Export landet.
    /// Zentralisiert die bisher auf mehrere Produktionsphasen verteilte Bereinigung.
    static func cleaningStoredBookText(_ text: String, bookTitle: String = "") -> String {
        fixingTypography(
            strippingProductionMarkers(
                humanizeProse(
                    strippingInlineFormatting(
                        strippingPromptArtifacts(text)
                    )
                ),
                buchtitel: bookTitle
            )
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ist diese Zeile eine reine Arbeitsmarke der Produktion?
    static func istArbeitsmarke(_ zeile: String) -> Bool {
        let roh = zeile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roh.isEmpty, roh.count <= 90 else { return false }
        // Ohne Satzzeichen am Ende (Prosa endet auf . ! ? " ' – Marken nicht).
        let endetWieProsa = roh.hasSuffix(".") || roh.hasSuffix("!") || roh.hasSuffix("?")
            || roh.hasSuffix("\u{201C}") || roh.hasSuffix("\u{201D}") || roh.hasSuffix("\"")
        let niedrig = roh.lowercased()

        // „VERSUCH 2/2", „VERSUCH 1 ABSATZ:" – eindeutig, auch mit Satzzeichen.
        if niedrig.range(of: "versuch\\s*\\d+\\s*(/\\s*\\d+)?", options: .regularExpression) != nil {
            return true
        }
        if niedrig.range(of: "^absatz\\s*:", options: .regularExpression) != nil { return true }

        // Stellenangabe: „kapitel 4, szene 1" – tolerant gegen Verdreher wie „kapitzel".
        // \p{L}{0,2} lässt bis zu zwei eingeschobene Buchstaben zu.
        let nenntStelle = niedrig.range(
            of: "kapit\\p{L}{0,3}\\s*\\d+\\s*[,.\\-–]?\\s*szene\\s*\\d+",
            options: .regularExpression) != nil
        let nenntFassung = niedrig.contains("endfassung") || niedrig.contains("rohfassung")
            || niedrig.contains("fassung:") || niedrig.contains("überarbeitet")
        if nenntStelle || nenntFassung { return !endetWieProsa || nenntStelle }

        // Alleinstehende Szenenangabe ohne Prosa-Satzschluss.
        if !endetWieProsa,
           niedrig.range(of: "^(kapit\\p{L}{0,3}|szene)\\s*\\d+", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func strippingSceneHeading(_ text: String) -> String {
        var zeilen = text.components(separatedBy: .newlines)
        // Führende Leerzeilen weg.
        while let erste = zeilen.first, erste.trimmingCharacters(in: .whitespaces).isEmpty {
            zeilen.removeFirst()
        }
        guard let kopf = zeilen.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !kopf.isEmpty else { return text }

        // Eine Arbeitsüberschrift ist kurz und nennt Kapitel/Szene oder eine Fassung.
        let niedrig = kopf.lowercased()
        let nenntStelle = niedrig.range(of: "^(kapitel|szene)\\s*\\d+", options: .regularExpression) != nil
            || niedrig.range(of: "\\bszene\\s*\\d+", options: .regularExpression) != nil
        let nenntFassung = niedrig.contains("endfassung") || niedrig.contains("überarbeitet")
            || niedrig.contains("rohfassung") || niedrig.contains("fassung:")
        let istKurz = kopf.count <= 80

        guard istKurz, nenntStelle || nenntFassung else { return text }

        zeilen.removeFirst()
        while let erste = zeilen.first, erste.trimmingCharacters(in: .whitespaces).isEmpty {
            zeilen.removeFirst()
        }
        let rest = zeilen.joined(separator: "\n")
        // Sicherheitsnetz: Wenn danach fast nichts übrig bleibt, war es doch keine
        // Überschrift – dann lieber den Originaltext behalten.
        return rest.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40 ? rest : text
    }

    static func strippingPromptArtifacts(_ text: String) -> String {
        var keptLines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if trimmed.isEmpty { keptLines.append(line); continue }
            // Ganze Label-/Vorgabe-Zeile entfernen.
            if promptLabelPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
            // Innerhalb der Zeile nur die Anweisungs-SÄTZE entfernen.
            let cleaned = removingInstructionSentences(from: line)
            if !cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
                keptLines.append(cleaned)
            }
        }
        var result = keptLines.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Entfernt durchgesickerte Markdown-Auszeichnung aus der Prosa: **fett**,
    /// *kursiv*, _kursiv_ sowie übrig gebliebene Einzel-Sternchen und Emojis.
    /// Reine Szenentrenner-Zeilen („***" / „* * *") bleiben erhalten, weil der
    /// Export sie als Szenenwechsel erkennt. So verschwinden die „komischen
    /// Sterne" mitten im Satz aus Anzeige UND Export – auch bei alten Büchern.
    static func strippingInlineFormatting(_ text: String) -> String {
        let cleanedLines = text.components(separatedBy: "\n").map { line -> String in
            let compact = line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
            if compact == "***" { return line } // Szenentrenner unangetastet lassen
            var l = line
            l = l.replacingOccurrences(of: #"\*\*([^*\n]+?)\*\*"#, with: "$1", options: .regularExpression)
            l = l.replacingOccurrences(of: #"\*([^*\n]+?)\*"#, with: "$1", options: .regularExpression)
            l = l.replacingOccurrences(of: #"(?<![\p{L}\p{N}])_([^_\n]+?)_(?![\p{L}\p{N}])"#,
                                       with: "$1", options: .regularExpression)
            // Übrig gebliebene Einzel-Sterne in einer Prosazeile entfernen (nie legitim).
            l = l.replacingOccurrences(of: "*", with: "")
            // Emojis/Bildzeichen haben in einem Roman nichts verloren. Skalar-basiert
            // und deterministisch (keine ICU-Eigenheiten bei Emoji-Blöcken).
            l.removeAll { (ch: Character) in
                ch.unicodeScalars.contains { s in
                    let v = s.value
                    return (0x1F000...0x1FFFF).contains(v) || (0x2600...0x27BF).contains(v)
                        || (0x2300...0x23FF).contains(v) || (0xFE00...0xFE0F).contains(v) || v == 0x200D
                }
            }
            return l
        }
        // Doppelte Leerzeichen, die durch das Entfernen entstehen können, glätten.
        return cleanedLines.joined(separator: "\n")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }

    /// Vereinheitlicht Typografie, ohne legitime Satzzeichen oder den Stil umzubauen.
    static func humanizeProse(_ text: String) -> String {
        // Einheitliche deutsche Anführungszeichen. Hier zentral, weil jede Stelle,
        // die Prosa aufbereitet, durch diese Funktion läuft – Buch 9 mischte sonst
        // »Guillemets« und „Gänsefüßchen" im selben Manuskript.
        // Rechtschreibung auf dem aktuellen Stand: Modelle sind auf viel Deutsch von VOR
        // der Reform 1996 trainiert und schreiben gelegentlich „daß“ oder „muß“. In einem
        // Buch von 2026 ist das ein Rechtschreibfehler, den Leser sofort sehen. Die
        // Zuordnung ist eindeutig, deshalb wird hier still korrigiert statt gemeldet.
        var t = SpellCheckService.korrigiereVeralteteRechtschreibung(text)
        t = vereinheitlicheAnfuehrungszeichen(t)
        let speechTags = "sagte|fragte|erwiderte|antwortete|flüsterte|rief|murmelte|entgegnete|brummte|seufzte|zischte|stammelte|erklärte|wiederholte"
        t = t.replacingOccurrences(
            of: #"([\p{L}\p{N}])“("# + speechTags + #")\b"#,
            with: "$1“, $2", options: [.regularExpression, .caseInsensitive]
        )
        t = t.replacingOccurrences(
            of: #"([!?])“("# + speechTags + #")\b"#,
            with: "$1“ $2", options: [.regularExpression, .caseInsensitive]
        )
        t = t.replacingOccurrences(of: #"\?{2,}"#, with: "?", options: .regularExpression)
        t = t.replacingOccurrences(of: #"!{2,}"#, with: "!", options: .regularExpression)
        // A model occasionally glues the next narrative sentence directly to a
        // closing German quote and omits the preceding full stop.
        t = t.replacingOccurrences(
            of: #"([\p{L}\p{N}])“([A-ZÄÖÜ])"#,
            with: "$1.“ $2", options: .regularExpression)
        t = t.replacingOccurrences(
            of: #"([.!?])“([A-ZÄÖÜ])"#,
            with: "$1“ $2", options: .regularExpression)
        // Aufräumen: Leerzeichen vor Satzzeichen, doppelte Kommas, führende Kommas,
        // doppelte Leerzeichen.
        t = t.replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?m)^\\s*,\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        // Modell-Echo entfernen: am Kapitelanfang verdreifacht sich oft der erste Satz.
        t = collapsingImmediateRepeats(t)
        return t
    }

    /// Entfernt unmittelbar wiederholte identische Absätze/Zeilen (häufiges Modell-Artefakt:
    /// der erste Satz eines Kapitels steht 2–3× hintereinander) sowie einen sofort doppelten
    /// Satz innerhalb einer Zeile. Durch anderen Text GETRENNTE Wiederholungen (stilistische
    /// Anaphern) bleiben unangetastet – nur direkte Dubletten werden eingeklappt.
    static func collapsingImmediateRepeats(_ text: String) -> String {
        // 1) Aufeinanderfolgende identische, nicht-leere Zeilen → eine.
        var deduped: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty,
               let last = deduped.last,
               last.trimmingCharacters(in: .whitespaces) == trimmed {
                continue
            }
            deduped.append(line)
        }
        // 2) Unmittelbar wiederholte Sätze innerhalb jeder Zeile einklappen. Der frühere
        // Regex mit Rückreferenz konnte auf längerer Prosa exponentiell zurückspringen
        // und den Produktionsprozess minutenlang bei 100 % CPU festhalten.
        return deduped
            .map(collapseImmediateSentenceRepeats)
            .joined(separator: "\n")
    }

    private static func collapseImmediateSentenceRepeats(in line: String) -> String {
        let characters = Array(line)
        let sentenceEndings = Set<Character>([".", "!", "?", "…"])
        let closingQuotes = Set<Character>(["\"", "”", "“", "’", "'", "»", "›"])
        var output = ""
        var previousSentence: String?
        var segmentStart = 0
        var index = 0

        while index < characters.count {
            guard sentenceEndings.contains(characters[index]) else {
                index += 1
                continue
            }

            var segmentEnd = index + 1
            while segmentEnd < characters.count,
                  closingQuotes.contains(characters[segmentEnd]) {
                segmentEnd += 1
            }
            let segment = String(characters[segmentStart..<segmentEnd])
            let normalized = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSignificant = normalized.count >= 12
            if !isSignificant || normalized != previousSentence {
                output += segment
            }
            previousSentence = isSignificant ? normalized : nil
            segmentStart = segmentEnd
            index = segmentEnd
        }

        if segmentStart < characters.count {
            output += String(characters[segmentStart...])
        }
        return output
    }

    /// Entfernt eine erste Textzeile/einen ersten Satz, der die Kapitelüberschrift wörtlich
    /// wiederholt (Modell-Artefakt: der Titel erscheint sonst doppelt – als Überschrift UND
    /// als erster Satz des Kapitels). Greift auch bei bereits erzeugten Büchern beim Re-Export.
    static func strippingLeadingTitleEcho(_ text: String, title: String) -> String {
        let normTitle = normalizedTitleKey(title)
        guard normTitle.count >= 8 else { return text }
        var lines = text.components(separatedBy: "\n")
        guard let idx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return text }
        let line = lines[idx].trimmingCharacters(in: .whitespaces)
        let sentenceEnd = line.firstIndex(where: { ".!?…".contains($0) })
        let firstSentence = sentenceEnd.map { String(line[...$0]) } ?? line
        guard normalizedTitleKey(firstSentence) == normTitle else { return text }
        var rest = ""
        if let e = sentenceEnd, line.index(after: e) < line.endIndex {
            rest = String(line[line.index(after: e)...]).trimmingCharacters(in: .whitespaces)
        }
        if rest.isEmpty { lines.remove(at: idx) } else { lines[idx] = rest }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTitleKey(_ s: String) -> String {
        let trimChars = CharacterSet(charactersIn: " \n\t.!?:;-\u{2014}\u{2013}\u{201E}\u{201C}\u{201D}\"'\u{00BB}\u{00AB}")
        return s.lowercased().trimmingCharacters(in: trimChars)
    }

    private static func removingInstructionSentences(from line: String) -> String {
        let lower = line.lowercased()
        // NUR eindeutige Marker löschen – mehrdeutige würden legitime Prosa fressen.
        guard deletableInstructionMarkers.contains(where: { lower.contains($0) }) else {
            return line // kein eindeutiges Anweisungs-Fragment → Zeile unverändert lassen
        }
        var kept: [String] = []
        line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: [.bySentences, .localized]) { sub, _, _, _ in
            guard let sub else { return }
            let s = sub.lowercased()
            if !deletableInstructionMarkers.contains(where: { s.contains($0) }) {
                kept.append(sub)
            }
        }
        let rebuilt = kept.joined()
        // Falls die Satzsegmentierung nichts trennen konnte, die ganze Zeile verwerfen.
        return rebuilt.trimmingCharacters(in: .whitespaces).isEmpty ? "" : rebuilt
    }

    // MARK: - KI-Erkennung (Anti-Detektor)

    /// Kuratierte Denylist hochsignifikanter deutscher KI-Floskeln (überwiegend
    /// Mehrwort-Phrasen, damit echte Prosa nicht fälschlich markiert wird).
    /// Quelle: synthetisiertes Experten-Korpus. Dient dem weichen Neufassungs-Gate
    /// beim Schreiben – NICHT zum mechanischen Löschen (das beschädigte Prosa).
    static let aiTellPhrases: [String] = [
        "ein schauer lief", "lief ihr über den rücken", "lief ihm über den rücken",
        "die zeit schien stillzustehen", "die zeit stand still", "die welt schien stillzustehen",
        "nichts würde mehr sein wie zuvor", "nichts war mehr wie zuvor", "nichts würde je wieder so sein",
        "ein lächeln umspielte", "ein lächeln huschte über", "ein schatten huschte über ihr gesicht",
        "ein wissendes lächeln", "ihr herz machte einen satz", "ihr herz schlug bis zum hals",
        "sein herz schlug bis zum hals", "das herz schlug ihr bis zum hals", "ihr herz schlug schneller",
        "ihr herz hämmerte", "ihr herz pochte wild", "ihr herz setzte einen schlag aus",
        "ein kloß bildete sich", "ein kloß in ihrem hals", "ein kloß steckte ihr im hals",
        "ein knoten in ihrem magen", "die luft war zum schneiden", "ein teil von ihr", "ein teil von ihm",
        "ein gefühl von", "ein gefühl der", "ein gefühl überkam sie", "eine mischung aus", "ein gemisch aus",
        "ein hauch von", "ein anflug von", "ein schwall von", "eine welle der", "eine welle von", "eine welle aus",
        "etwas in ihr", "etwas in ihm", "etwas in ihrem inneren", "in ihr begann etwas",
        "in ihm begann etwas", "etwas regte sich in ihr",
        "etwas regte sich in ihm", "etwas in ihr zerbrach", "in diesem moment", "in diesem augenblick",
        "für einen moment", "für einen augenblick", "einen moment lang", "einen augenblick lang",
        "einen herzschlag lang", "einen wimpernschlag lang", "sie atmete tief durch", "er atmete tief durch",
        "sie holte tief luft", "ihr atem stockte", "ihr stockte der atem", "der atem stockte ihr",
        "ihre augen weiteten sich", "ihre kehle schnürte sich zu", "ihre kehle wurde eng",
        "ihr magen zog sich zusammen", "sein magen krampfte", "sie schluckte schwer",
        "sie ballte die hände zu fäusten", "kaum merklich", "kaum wahrnehmbar", "kaum spürbar",
        "ein kalter schauer", "ein eiskalter schauer lief", "gänsehaut breitete sich aus",
        "machte sich breit", "breitete sich in ihr aus", "breitete sich in ihm aus", "durchfuhr sie",
        "durchfuhr ihn", "durchströmte sie", "durchströmte ihn", "überkam sie", "überkam ihn",
        "überrollte sie", "überrollte ihn", "stieg in ihr auf", "stieg in ihm auf", "wusch über sie hinweg",
        "wut stieg in ihr auf", "wut stieg in ihm auf", "wut kochte in ihm hoch", "panik stieg in ihr auf",
        "angst kroch in ihr hoch", "kroch in ihr hoch", "trauer überkam sie", "verzweiflung überrollte ihn",
        "es war, als ob", "es war, als würde", "es fühlte sich an, als", "als würde die zeit",
        "als wäre die welt", "in diesem moment verstand sie", "in diesem moment verstand er",
        "in diesem augenblick begriff sie", "in diesem augenblick verstand sie", "und so begriff sie",
        "und so begriff er", "und so wurde ihr klar", "sie wusste in diesem moment", "ihr wurde klar",
        "es wurde ihr bewusst", "stille breitete sich aus", "stille senkte sich über",
        "schweigen breitete sich aus", "eine bedrückende stille", "ein moment, der alles veränderte",
        "ein moment, den sie nie vergessen würde", "mehr als worte je könnten", "tief in ihrem inneren",
        "tief in ihrem innersten", "tief in seinem inneren", "in ihrem innersten", "sondern vielmehr",
        "auf gewisse weise", "auf seltsame weise", "auf unerklärliche weise", "wie aus dem nichts",
        "ein zeichen ihrer unsicherheit", "ein zeichen seiner nervosität", "verriet ihre nervosität",
        "nicht benennen konnte", "nicht benennen wollte", "nicht in worte fassen",
        "das sie nicht benennen", "das er nicht benennen",
        // Aus der Diagnose echter Bücher ergänzt (Mehrwort-Floskeln; abstrakte
        // Leitsubstantive wie Kontrolle/Nähe bewusst NICHT hier, sondern im Prompt
        // frequenzbegrenzt, sonst würden sie gute Prosa fälschlich markieren).
        "als hätte jemand", "als ob jemand", "als hätte man", "wie ein krankheitsbild",
        "wie in trance", "wie betäubt", "wie ferngesteuert", "wie von selbst",
        "etwas zog sich in ihr zusammen", "etwas brach in ihr", "etwas verschob sich zwischen ihnen",
        "ein gefühl, das sie nicht einordnen konnte", "ein gefühl, das sie nicht kannte",
        "sie konnte es nicht in worte fassen", "sie hätte es nicht erklären können",
        "irgendetwas an ihm", "irgendetwas an ihr", "ein stich von eifersucht", "ein stich von schuld",
        "ein knoten im magen", "ihr herz zog sich zusammen", "eine seltsame vertrautheit",
        "merkwürdig vertraut", "ein wohliges kribbeln", "ein kribbeln im bauch",
        "schmetterlinge im bauch", "tausend schmetterlinge", "still und reglos", "leer und kalt",
        "fremd und vertraut zugleich", "roh und ehrlich", "zart und zerbrechlich",
        "klar und unmissverständlich", "müde und ausgelaugt", "nah und doch fern",
        "ihre blicke trafen sich", "ihre blicke begegneten sich", "die luft zwischen ihnen knisterte",
        "es knisterte zwischen ihnen", "die anziehung zwischen ihnen war greifbar",
        "die spannung zwischen ihnen war greifbar", "ein magnetischer sog",
        "sein blick bohrte sich in ihren", "sein blick durchbohrte sie", "die stille war ohrenbetäubend",
        "die dunkelheit legte sich wie ein mantel", "ein lächeln, das ihre augen nicht erreichte",
        "ein lächeln, das seine augen nicht erreichte", "die welt um sie herum verschwand",
        "alles andere verblasste", "beinahe zärtlich", "fast schon zärtlich",
        "für den bruchteil einer sekunde", "den bruchteil einer sekunde lang",
        // Aus dem Repetition-Scan echter Bücher: verbatim überstrapazierte Standard-Beats,
        // die den Lesefluss zerstören (z.B. „öffnete den Mund, schloss ihn" 36x, „drehte
        // sich nicht um" 86x, „…", sagte sie. Keine Frage." 27x in einem einzigen Buch).
        "öffnete den mund, schloss ihn", "den mund, schloss ihn wieder", "drehte sich nicht um",
        "sagte sie. keine frage", "sagte er. keine frage",
        "etwas, das sie nicht sehen konnte", "etwas, das sie nicht deuten konnte",
        "etwas, das sie nicht lesen konnte",
        "unweigerlich", "zweifellos", "gleichsam", "nichtsdestotrotz",
        // Weitere überstrapazierte Cliché-/KI-Wendungen (aus Lesproben echter KI-Romane)
        "ihr atem stockte", "sein atem stockte", "der atem stockte", "sie hielt den atem an",
        "ihr herz raste", "ihr herz hämmerte", "ihr herz pochte", "ein kloß im hals",
        "jede faser ihres körpers", "mit jeder faser", "die zeit stand still",
        "die zeit schien stillzustehen", "alles in ihr schrie", "eine welle der",
        "wie ein offenes buch", "achterbahn der gefühle", "ein wirbelsturm der gefühle"
    ]

    /// Englische KI-Tells (B3): Die App schreibt wahlweise auf Englisch
    /// (Sprachauswahl im Wizard), die gesamte Erkennung war aber deutsch-only –
    /// ein englisches Buch passierte das KI-Gate ungeprüft. Kuratierte,
    /// hochsignifikante Mehrwort-Phrasen, symmetrisch zur deutschen Liste.
    /// Werden mit der deutschen Liste kombiniert ausgewertet: Deutsche Phrasen
    /// kommen in englischen Büchern praktisch nicht vor (und umgekehrt), so
    /// deckt EINE kombinierte Zählung beide Sprachen ab, ohne dass jeder
    /// Aufrufort die Buchsprache kennen muss.
    static let aiTellPhrasesEnglish: [String] = [
        "a shiver ran down", "ran down her spine", "ran down his spine",
        "sent shivers down", "sent a shiver down",
        "couldn't help but", "could not help but",
        "little did she know", "little did he know", "little did they know",
        "didn't know she was holding", "didn't know he was holding",
        "the air was thick with", "air thick with tension",
        "heart hammered in her chest", "heart hammered in his chest",
        "heart pounded in her chest", "heart pounded in his chest",
        "washed over her", "washed over him", "a wave of relief",
        "a mixture of", "a mix of emotions",
        "something inside her", "something inside him",
        "deep within her", "deep within him",
        "in that moment", "in that instant", "for a heartbeat",
        "time seemed to stand still", "time stood still",
        "nothing would ever be the same",
        "didn't reach her eyes", "didn't reach his eyes", "failed to reach her eyes",
        "their eyes met", "eyes locked",
        "tension between them was palpable", "palpable tension",
        "butterflies in her stomach", "butterflies in his stomach",
        "a knot in her stomach", "a knot in his stomach",
        "a lump in her throat", "a lump in his throat",
        "every fiber of her being", "every fiber of his being",
        "she swallowed hard", "he swallowed hard",
        "welled up in her eyes", "welled up in his eyes", "tears welled",
        "a sense of dread", "dread settled",
        "a testament to", "tapestry of", "delve into", "delved into",
        "deafening silence", "danced in the moonlight",
        "a flicker of doubt", "uncharted territory",
        "her breath hitched", "his breath hitched",
        "breath caught in her throat", "breath caught in his throat",
        "more than words could"
    ]

    /// Deutsch + Englisch kombiniert (einmalig aufgebaut).
    private static let aiTellPhrasesAll: [String] = aiTellPhrases + aiTellPhrasesEnglish

    /// Zählt die Treffer aus `aiTellPhrases` + `aiTellPhrasesEnglish` im Text
    /// (Gesamtvorkommen, beide Sprachen kombiniert – s. B3-Kommentar oben).
    static func aiTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in aiTellPhrasesAll {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    static func aiTellMatches(in text: String, maxResults: Int = 20) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in aiTellPhrasesAll where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    // MARK: - Buchweite Reaktionsformeln

    /// Häufige Einzelgesten sind keine Stilfehler. Werden dieselben körperlichen
    /// Reaktionsformeln jedoch über ein ganzes Manuskript hinweg immer wieder als
    /// Spannungsersatz eingesetzt, lesen sie sich wie eine Generierungsschablone.
    /// Diese Liste enthält daher nur konkrete Mehrwortmuster aus den geprüften
    /// NovelForge-Manuskripten; abstrakte Gefühle oder normale Bewegungen bleiben frei.
    private static let formulaicReactionPatterns: [(label: String, pattern: String)] = [
        ("drehte sich um", #"\b(?:[A-Za-zÄÖÜäöüß]+\s+)?drehte sich um\b"#),
        ("schüttelte den Kopf", #"\bschüttelte den Kopf\b"#),
        ("schloss die Augen", #"\bschloss die Augen\b"#),
        ("spürte, wie sich", #"\bspürte,?\s+wie sich\b"#),
        ("nicht benennen konnte", #"\bnicht benennen konnte\b"#)
    ]

    /// Meldet ausschließlich Reaktionsformeln, die öfter als einmal je 5.000 Wörter
    /// auftreten (mindestens siebenmal). So bleiben bewusste Leitmotive und einzelne
    /// starke Gesten erhalten, während die in realen Ausgaben gemessenen Cluster wie
    /// „drehte sich um" (83-mal) oder „spürte, wie sich" (41-mal) vor der Freigabe
    /// zuverlässig in die chirurgische Überarbeitung gehen.
    static func blockingFormulaicReactionPhrases(inChapters chapters: [String],
                                                 maxResults: Int = 12) -> [String] {
        let text = chapters.joined(separator: "\n\n")
        let words = max(1, text.wordCount)
        let allowedOccurrences = max(6, words / 5_000)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var findings: [(label: String, count: Int)] = []

        for candidate in formulaicReactionPatterns {
            guard let expression = try? NSRegularExpression(
                pattern: candidate.pattern,
                options: [.caseInsensitive]
            ) else { continue }
            let count = expression.numberOfMatches(in: text, range: range)
            if count > allowedOccurrences {
                findings.append((candidate.label, count))
            }
        }

        return findings
            .sorted { $0.count > $1.count }
            .prefix(maxResults)
            .map(\.label)
    }

    static func draftQualityPenalty(_ text: String) -> Int {
        let clarity = clarityAssessment(text)
        return aiTellCount(text) * 10
            + circumlocutionCount(text) * 3
            + jargonTellCount(text) * 15
            + archaicTellCount(text) * 15
            + clarity.vagueReferences * 5
            + clarity.hypotheticalComparisons * 4
            + clarity.filterReactions * 3
            + (containsPromptArtifacts(text) || containsMetaRequest(text) ? 100 : 0)
            + (isLikelyTruncated(text) ? 100 : 0)
    }

    /// Altertümliche/„mittelalterliche“, geschwollene Wörter, die moderne Profi-Prosa
    /// NICHT verwendet. Schon wenige Treffer lassen einen Text antiquiert klingen.
    static let archaicTellPhrases: [String] = [
        "alsbald", "fürwahr", "sintemal", "weiland", "dünkte", "dünkt ", "wohlan",
        "antlitz", "jüngling", "die maid", "junge maid", "das weib", "ein weib",
        "holde ", "holder ", "es begab sich", "begab sich", "allerorten", "allzumal",
        "ingleichen", "sodann", "auf dass", "des nachts", "ein jeglich", "geziemt",
        "gewahrte", "hub an", "sann nach", "zur stund"
    ]

    /// Akademisches Fachvokabular/Bildungswörter, die normale Leser nicht kennen und
    /// die in Unterhaltungsromanen nichts verloren haben (Dave-Feedback: „Mediävistiker"
    /// sagt niemand). Bewusst nur EINDEUTIG seltene Wörter – keine False Positives.
    static let jargonTellPhrases: [String] = [
        "mediävist", "komparatist", "kartographisch", "kartografisch", "diaphan",
        "ephemer", "evozier", "konzedier", "proliferier", "habilitand", "hermeneut",
        "ontolog", "epistemolog", "palimpsest", "apokryph", "äquidistant",
        "dichotom", "paradigmat", "narratolog", "semiot", "diskursiv"
    ]

    /// Umschreibungs-Marker: Benennungs-Vermeidung, Korrekturfiguren und Ins-Ungefähre-
    /// Vergleiche. Einzeln legitim – GEHÄUFT machen sie den Text kryptisch und der Leser
    /// versteht die Geschichte nicht mehr (Dave-Feedback zu echten Buchauszügen).
    static let circumlocutionMarkers: [String] = [
        "das, was", "etwas, das", "etwas, dass", "so etwas wie", "eine art ",
        ", sondern", "als ob es", "wie etwas, das", "nicht benennen", "kein wort dafür",
        "etwas härterem als", "etwas anderem als", "aus etwas, das"
    ]

    static let vagueReferenceMarkers: [String] = [
        "etwas, das", "etwas in ihr", "etwas in ihm", "irgendetwas",
        "nicht benennen", "nicht einordnen", "nicht deuten", "nicht erklären konnte",
        "konnte nicht sagen", "was er nicht aussprach",
        "was sie nicht aussprach", "ohne zu wissen warum", "ohne zu wissen, warum",
        "eine art ", "so etwas wie"
    ]

    static let hypotheticalComparisonMarkers: [String] = [
        "als würde", "als hätte", "als wäre", "als ob", "als wollte", "als könnte", "als müsste",
        "als sollte", "als gehöre", "als fürchte"
    ]

    /// ACHTUNG – NICHT dasselbe wie `filterwoerter(in:)`, trotz des ähnlichen Namens.
    ///
    /// Diese Liste gehört zur KLARHEITS-Bewertung (`clarityAssessment`) und misst vage,
    /// passive Kognition („sie wusste nicht“, „ihm wurde klar“). `filterwoerter(in:)`
    /// misst die POV-Distanz über den Nebensatz („sie sah, dass …“) und speist die
    /// Satz-Chirurgie.
    ///
    /// Vor einer Zusammenlegung geprüft, an einem Buch mit 194.517 Wörtern gemessen:
    /// alte Liste 41 Treffer, neue Prüfung 45, ÜBERSCHNEIDUNG GENAU 1. Die beiden
    /// messen also fast disjunkte Mengen – Zusammenlegen wäre ein Verlust, kein
    /// Aufräumen. Beide bleiben, getrennt und mit getrenntem Zweck.
    static let filterReactionMarkers: [String] = [
        "sie spürte", "er spürte", "sie bemerkte", "er bemerkte",
        "sie fühlte", "er fühlte", "sie wusste nicht", "er wusste nicht",
        "ihr wurde klar", "ihm wurde klar", "sie konnte nicht verstehen",
        "er konnte nicht verstehen"
    ]

    static func clarityAssessment(_ text: String) -> ProseClarityAssessment {
        let words = max(1, text.wordCount)
        return ProseClarityAssessment(
            vagueReferences: phraseOccurrenceCount(in: text, phrases: vagueReferenceMarkers),
            hypotheticalComparisons: phraseOccurrenceCount(
                in: text, phrases: hypotheticalComparisonMarkers),
            filterReactions: phraseOccurrenceCount(in: text, phrases: filterReactionMarkers),
            vagueReferenceLimit: max(1, words / 300),
            hypotheticalComparisonLimit: max(2, words / 220),
            filterReactionLimit: max(2, words / 250)
        )
    }

    static func clarityRepairPhrases(in text: String, maxResults: Int = 30) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in vagueReferenceMarkers
            + hypotheticalComparisonMarkers
            + filterReactionMarkers where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    private static func phraseOccurrenceCount(in text: String, phrases: [String]) -> Int {
        let lower = text.lowercased()
        var count = 0
        for phrase in phrases {
            var searchRange = lower.startIndex..<lower.endIndex
            while let match = lower.range(of: phrase, range: searchRange) {
                count += 1
                searchRange = match.upperBound..<lower.endIndex
            }
        }
        return count
    }

    /// Zählt Umschreibungs-Marker (Gesamtvorkommen).
    static func circumlocutionCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in circumlocutionMarkers {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    static func circumlocutionMatches(in text: String, maxResults: Int = 20) -> [String] {
        let lower = text.lowercased()
        var matches: [String] = []
        for phrase in circumlocutionMarkers where lower.contains(phrase) {
            guard !matches.contains(phrase) else { continue }
            matches.append(phrase)
            if matches.count >= maxResults { break }
        }
        return matches
    }

    /// Zählt Fachvokabular-Marker (Gesamtvorkommen).
    static func jargonTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in jargonTellPhrases {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    /// Zählt altertümliche Marker (Gesamtvorkommen).
    static func archaicTellCount(_ text: String) -> Int {
        let lower = text.lowercased()
        guard !lower.isEmpty else { return 0 }
        var count = 0
        for phrase in archaicTellPhrases {
            var range = lower.startIndex..<lower.endIndex
            while let hit = lower.range(of: phrase, range: range) {
                count += 1
                range = hit.upperBound..<lower.endIndex
            }
        }
        return count
    }

    // MARK: - Stilticks (Frequenz-Übernutzung, an der Leser KI-Prosa erkennen)

    /// Deterministische Frequenz-Prüfung auf stilistische Ticks, die einzeln legitim
    /// sind, aber gehäuft sofort nach KI klingen. Aus der Diagnose echter Produktionen:
    /// „Nicht …“-Satzanfänge (die LLM-Rhetorik „Nicht X. Sondern Y.“) standen 365× in
    /// einem einzigen Buch; dazu Körper-Beat-Lexeme (schlucken/Atem/hämmern) und
    /// Adverb-Krücken (leise/langsam/fast). Liefert konkrete, prompt-taugliche
    /// Anweisungen. WEICHES Signal: fließt in Neufassungs-Hinweise ein, wirft NIE
    /// und blockiert NIE die Freigabe (Anti-Hänger-Regel).
    static func styleTicViolations(in text: String) -> [String] {
        let words = text.wordCount
        guard words >= 200 else { return [] }
        var violations: [String] = []

        // 1) „Nicht …“ als Satzanfang: budgetiert auf ~1 je 350 Wörter.
        var nichtStarts = 0
        for raw in text.components(separatedBy: CharacterSet(charactersIn: ".!?…\n")) {
            let s = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t„“”»«‚'\""))
            if s.hasPrefix("Nicht ") || s.hasPrefix("Kein ") || s.hasPrefix("Keine ") {
                nichtStarts += 1
            }
        }
        // Kalibriert an 184 echten Szenen (Trip-Rate ~20%): nur klar auffällige
        // Szenen lösen die eine zusätzliche Neufassung aus, nicht jede zweite.
        let nichtBudget = max(4, words / 150)
        if nichtStarts > nichtBudget {
            violations.append("„Nicht/Kein …“-Satzanfänge: \(nichtStarts)× (erlaubt \(nichtBudget)). Formuliere positiv, was IST – die Verneinungs-Rhetorik „Nicht X. Sondern Y.“ höchstens einmal.")
        }

        // 1b-1d) Stil-Ticks im Satzinneren. Die Pruefung oben faengt nur Satzanfaenge --
        // gemessen an einem laufenden Buch: 6x "nicht X, sondern Y", 5x "etwas, das",
        // 6x "Tuer fiel ins Schloss" auf 13.000 Woertern, alle unbemerkt. Eine externe
        // Manuskriptanalyse nannte genau diese drei als auffaelligste KI-Merkmale.
        func trefferZahl(_ muster: String) -> Int {
            guard let re = try? NSRegularExpression(pattern: muster, options: [.caseInsensitive])
            else { return 0 }
            let ns = text as NSString
            return re.numberOfMatches(in: text, range: NSRange(location: 0, length: ns.length))
        }
        let ticks: [(muster: String, budget: Int, hinweis: String)] = [
            (#"nicht\s+[^,.!?]{2,40},\s*sondern"#, max(1, words / 1_200),
             "Antithese nicht-X-sondern-Y ist ein KI-Erkennungsmerkmal. Sag direkt, was IST."),
            (#"\betwas,\s+(das|was|die|der)\b"#, max(1, words / 1_500),
             "Vage Umschreibung etwas-das: benenne das Konkrete."),
            (#"(Tuer|Tuere|Tür|Türe)[^.!?]{0,40}(fiel|schloss|klickte)"#, max(1, words / 2_500),
             "Tuer-faellt-ins-Schloss als Szenenabschluss: finde andere Schlussbilder.")
        ]
        for tick in ticks {
            let n = trefferZahl(tick.muster)
            if n > tick.budget {
                violations.append("\(tick.hinweis) (\(n)x im Text)")
            }
        }

        // 1e) Übererklären und sichtbare Schlusshaken. Nicht jeder Gedanke ist ein
        // Fehler; zwei Deutungssätze in derselben Passage oder eine demonstrativ
        // ausformulierte Erkenntnis am Ende klingen jedoch nach kommentierter KI-Prosa.
        let deutungen = uebererklaerendeDeutungssaetze(in: text)
        if deutungen.count >= 2 {
            violations.append("Übererklärende Deutungssätze gehäuft (\(deutungen.count)×): Handlung und Dialog nicht nachträglich auslegen, sondern die konkrete Folge stehen lassen.")
        }
        let rundeEnden = kuenstlichRundeSchlusssaetze(in: text)
        if !rundeEnden.isEmpty {
            violations.append("Künstlich ausgestellter Szenenabschluss: \(rundeEnden.prefix(2).map(\.grund).joined(separator: " | ")).")
        }

        // 2) Körper-Beat-Lexeme: zusammen budgetiert auf ~1 je 300 Wörter.
        let lower = text.lowercased()
        let beatLexemes = ["schluckte", "atemzug", "hämmerte", "stockte", "zog sich zusammen",
                           "krampfte", "kribbelte", "zitterte", "bebte"]
        var beatCounts: [(String, Int)] = []
        var beatTotal = 0
        for lex in beatLexemes {
            let c = lower.components(separatedBy: lex).count - 1
            if c > 0 { beatCounts.append((lex, c)); beatTotal += c }
        }
        let beatBudget = max(3, words / 200)
        if beatTotal > beatBudget {
            let list = beatCounts.sorted { $0.1 > $1.1 }.prefix(4).map { "\($0.0) \($0.1)×" }.joined(separator: ", ")
            violations.append("Körpersignal-Beats gehäuft (\(beatTotal)×, erlaubt \(beatBudget)): \(list). Ersetze durch konkrete Handlung, Blickrichtung, Objekt oder Dialog – nicht durch ein anderes Körpersignal.")
        }

        // 3) Adverb-Krücken: zusammen budgetiert auf ~1 je 200 Wörter.
        let crutches = ["leise", "langsam", "plötzlich", "einfach", "irgendwie"]
        var crutchTotal = 0
        var crutchCounts: [(String, Int)] = []
        for c in crutches {
            let n = lower.components(separatedBy: c).count - 1
            if n > 0 { crutchCounts.append((c, n)); crutchTotal += n }
        }
        let crutchBudget = max(5, words / 120)
        if crutchTotal > crutchBudget {
            let list = crutchCounts.sorted { $0.1 > $1.1 }.prefix(3).map { "\($0.0) \($0.1)×" }.joined(separator: ", ")
            violations.append("Adverb-Krücken gehäuft (\(crutchTotal)×, erlaubt \(crutchBudget)): \(list). Zeige das Tempo/die Lautstärke über die Handlung selbst.")
        }

        // 4) Filterwörter: die Perspektivfigur beobachtet sich beim Wahrnehmen.
        let filter = filterwoerter(in: text)
        let filterBudget = max(1, words / 500)
        if filter.count > filterBudget {
            let list = filter.prefix(3).map { $0.stelle }.joined(separator: ", ")
            violations.append("Filterwörter gehäuft (\(filter.count)×, erlaubt \(filterBudget)): \(list). Streiche die Wahrnehmungsinstanz und zeige direkt, was geschieht – statt „sie sah, dass er ging“ nur „er ging“.")
        }

        // 5) Vergleichs-Dichte über die ganze Passage.
        let bilder = vergleichsDichte(in: text)
        if bilder.anzahl > bilder.budget {
            let list = bilder.stellen.prefix(3).joined(separator: " · ")
            violations.append("Zu viele Vergleiche (\(bilder.anzahl)×, erlaubt \(bilder.budget)): \(list). Behalte das stärkste Bild und erzähle den Rest nüchtern – wenn jedes Geräusch und jedes Gesicht ein Bild bekommt, wirkt keines mehr.")
        }

        return violations
    }

    /// Filterwörter – der stärkste Deep-POV-Verräter.
    ///
    /// „Sie sah, dass er die Tür schloss“ schiebt eine Beobachtungsinstanz zwischen
    /// Leser und Figur; „Er schloss die Tür“ setzt den Leser direkt in die Szene.
    /// Bei tiefer Perspektive ist die Wahrnehmung implizit – alles, was erzählt wird,
    /// nimmt die Perspektivfigur ohnehin wahr.
    ///
    /// Erfasst werden nur SINNES-Verben mit Nebensatz. Kognitive Verben („dachte“,
    /// „wusste“) bleiben bewusst außen vor: Sie sind in deutscher Erzählprosa oft
    /// legitim, und ein falsch-positives Gate erzwingt eine Neufassung, die den Text
    /// schlechter macht.
    ///
    /// - Returns: Fundstellen mit Vorschlag, jeweils gekürzt auf Prompt-Länge.
    static func filterwoerter(in text: String) -> [(stelle: String, hinweis: String)] {
        let muster: [(regex: String, hinweis: String)] = [
            (#"\b(sah|sahen|hörte|hörten|spürte|spürten|fühlte|fühlten|bemerkte|bemerkten|beobachtete|beobachteten|merkte|merkten|registrierte|registrierten|roch|rochen|schmeckte|schmeckten)\s*,\s*(dass|wie)\b"#,
             "Wahrnehmungsverb streichen"),
            (#"\bkonnte\s+\w{3,}en\s*,\s*(dass|wie)\b"#,
             "„konnte sehen/hören“ streichen"),
            (#"\bes\s+(schien|kam)\s+(ihr|ihm|ihnen)\b"#,
             "Distanzformel „es schien ihr“ streichen"),
            (#"\b(sie|er|es)\s+(schien|wirkte)\s*,\s*als\b"#,
             "Vermutungsformel: direkt behaupten")
        ]
        var treffer: [(String, String)] = []
        let ns = text as NSString
        for (regex, hinweis) in muster {
            guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive])
            else { continue }
            for match in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let stelle = ns.substring(with: match.range)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                treffer.append((stelle, hinweis))
            }
        }
        return treffer.map { (stelle: $0.0, hinweis: $0.1) }
    }

    /// Vergleichs-Dichte über eine ganze Passage.
    ///
    /// `gestapelteBilder` findet nur zwei Bilder im SELBEN Satz. Gemessen an einem
    /// echten Produktionsbuch („Das Schweigen der Imkerin“, Kapitel 13) standen acht
    /// Vergleiche auf 350 Wörtern – jeder brav in einem eigenen Satz, deshalb von
    /// keiner Prüfung erfasst. Der Draft-Prompt erlaubt ein bis zwei Bilder pro Szene;
    /// diese Funktion macht genau das messbar.
    ///
    /// Erkannt wird nur der figurative Gebrauch. „wie“ ist im Deutschen stark
    /// überladen – es leitet auch Nebensätze ein („er wusste, wie es geht“) und
    /// feste Wendungen („wie immer“). Getroffen wird deshalb nur, wenn eine
    /// NOMINALPHRASE folgt: entweder ein Artikel („wie ein Stecker“), eine
    /// Präposition mit Artikel („wie aus einem Ventilator“) oder ein großgeschriebenes
    /// Substantiv („wie Glassplitter“, „wie abgenutzte Möbelpolsterung“).
    /// Großgeschriebene Pronomen und Anreden werden ausgeschlossen, damit
    /// „wie Sie wissen“ nicht als Bild zählt.
    ///
    /// - Returns: gefundene Anzahl, erlaubtes Budget und die Fundstellen.
    static func vergleichsDichte(in text: String) -> (anzahl: Int, budget: Int, stellen: [String]) {
        let words = text.wordCount
        // Vorgabe des Autors: höchstens EIN Bild je zehn Druckseiten. Bei
        // `AppConstants.wordsPerPage` = 250 sind das 2500 Wörter, also 0,4 je 1000.
        // Diese Zielmarke steht im Draft-Prompt (Prävention kostet nichts).
        //
        // Der Reparatur-Schwellwert hier liegt bewusst LOCKERER (1 je 1250 Wörter):
        // Die Satz-Chirurgie soll Häufungen abräumen, nicht jedes Einzelbild jagen –
        // jede erzwungene Neufassung ist ein Risiko für den Text. Zusammen mit der
        // Freigabegrenze ergibt das drei Stufen: Ziel 0,4 · Chirurgie ab 0,8 ·
        // Freigabe blockiert ab 1,0 je 1000 Wörter.
        let budget = max(1, words / 1_250)
        let muster = [
            // „wie ein Stecker“, „wie eine defekte Lampe“.
            // BEWUSST nur unbestimmte Artikel: „das/der/die“ sind im Deutschen auch
            // Relativ- und Demonstrativpronomen, „wie das ausgeht“ wäre sonst ein Bild.
            // Bestimmte Artikel deckt die Substantiv-Regel unten mit ab („wie der Wind“).
            #"\bwie\s+(ein|eine|einen|einem|einer)\s+[A-ZÄÖÜa-zäöüß]{3,}"#,
            // „wie aus einem Ventilator“, „wie bei einem Tanz“
            #"\bwie\s+(bei|aus|von|in|an|auf|nach|unter|durch)\s+(einem|einer|eines|dem|der|den)\b"#,
            // „wie Glassplitter“, „wie abgenutzte Möbelpolsterung“
            #"\bwie\s+([a-zäöüß]{3,}\s+)?[A-ZÄÖÜ][a-zäöüß]{2,}"#,
            // Irrealis-Vergleich
            #"\bals\s+(hätte|hätten|wäre|wären|würde|würden|ob|sei|seien)\b"#,
            #"\bgleich\s+(einem|einer)\s+\w+"#
        ]
        // Großgeschriebene Wörter, die keine Bildspender sind.
        let keineBilder: Set<String> = ["sie", "ihnen", "ihr", "ihre", "ihrem", "ihren",
                                        "er", "es", "ich", "wir", "du", "man", "immer",
                                        "gesagt", "erwartet", "besprochen", "vereinbart"]
        // Die Muster überlappen bewusst („wie eine Bühne“ trifft Artikel- UND
        // Substantiv-Regel). Ohne Entdopplung zählte dieselbe Stelle mehrfach und das
        // Budget wäre wertlos – deshalb wird nach Position dedupliziert: pro Textstelle
        // zählt genau ein Bild.
        var funde: [(bereich: NSRange, text: String)] = []
        let ns = text as NSString
        for regex in muster {
            guard let re = try? NSRegularExpression(pattern: regex, options: [])
            else { continue }
            for match in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let fund = ns.substring(with: match.range)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let letztes = fund.split(separator: " ").last.map(String.init)?.lowercased() ?? ""
                guard !keineBilder.contains(letztes) else { continue }
                // „die Art, wie sie ging“ / „auf die Weise, wie er sprach“ sind
                // Relativkonstruktionen, keine Bilder. An echter Ausgabe belegt: das
                // waren die einzigen systematischen Fehltreffer einer 18er-Stichprobe.
                let davorStart = max(0, match.range.location - 14)
                let davor = ns.substring(with: NSRange(location: davorStart,
                                                       length: match.range.location - davorStart))
                    .lowercased()
                guard !davor.hasSuffix("art, "), !davor.hasSuffix("weise, "),
                      !davor.hasSuffix("art "), !davor.hasSuffix("weise ") else { continue }
                funde.append((match.range, fund))
            }
        }
        var stellen: [String] = []
        var belegtBis = -1
        for fund in funde.sorted(by: { $0.bereich.location < $1.bereich.location }) {
            guard fund.bereich.location > belegtBis else { continue }
            stellen.append(fund.text)
            belegtBis = fund.bereich.location + fund.bereich.length - 1
        }
        return (anzahl: stellen.count, budget: budget, stellen: stellen)
    }

    /// Die Sätze, die ÜBER dem Bilder-Budget liegen.
    ///
    /// Ein bis zwei Bilder pro Szene sind erwünscht – erst die Häufung stumpft ab.
    /// Deshalb werden nicht alle Vergleiche gemeldet, sondern nur die überzähligen:
    /// Die ersten Treffer im Text bleiben stehen, alles darüber geht in die
    /// Satz-Chirurgie. Gemessen an einem ausgelieferten Buch (194.517 Wörter):
    /// 1462 Bilder bei einem Budget von 486.
    static func ueberzaehligeBilder(in text: String) -> [(satz: String, grund: String)] {
        let budget = max(1, text.wordCount / 1_250)
        var gesehen = 0
        var treffer: [(satz: String, grund: String)] = []
        for satz in saetzeAusText(text) {
            let anzahl = vergleichsDichte(in: satz).anzahl
            guard anzahl > 0 else { continue }
            gesehen += anzahl
            if gesehen > budget {
                treffer.append((satz,
                    "Bild über dem Budget (\(budget) pro Szene): erzähle diesen Satz nüchtern ohne Vergleich"))
            }
        }
        return treffer
    }

    /// Die Sätze, die über dem Filterwort-Budget liegen.
    static func filterwortSaetze(in text: String) -> [(satz: String, grund: String)] {
        let budget = max(1, text.wordCount / 500)
        var gesehen = 0
        var treffer: [(satz: String, grund: String)] = []
        for satz in saetzeAusText(text) {
            let anzahl = filterwoerter(in: satz).count
            guard anzahl > 0 else { continue }
            gesehen += anzahl
            if gesehen > budget {
                treffer.append((satz,
                    "Filterwort: streiche die Wahrnehmungsinstanz und zeige direkt, was geschieht"))
            }
        }
        return treffer
    }

    /// ALLE Sätze, die die Satz-Chirurgie gezielt ersetzen kann – eine einzige Liste.
    ///
    /// Warum gebündelt: Die Lektion aus dem 329-Runden-Patt lautet „was die Abnahme
    /// beanstandet, muss die Reparatur auch beheben können“. Deshalb sehen Befund und
    /// Reparatur ab hier dieselbe Menge. Die Obergrenze hält den Reparatur-Prompt
    /// bezahlbar und die Runde endlich.
    static func reparierbareStilSaetze(in text: String,
                                       hoechstens: Int = 12) -> [(satz: String, grund: String)] {
        var gesehen = Set<String>()
        var ergebnis: [(satz: String, grund: String)] = []
        let fragmente = proseSentenceFragments(in: text).dropFirst().map {
            (satz: $0,
             grund: "Satzfragment: als vollständigen, natürlich lesbaren Satz mit finitem Verb formulieren")
        }
        for fund in saetzeMitTicks(in: text) + ueberzaehligeBilder(in: text)
            + filterwortSaetze(in: text) + fragmente {
            let schluessel = fund.satz.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !schluessel.isEmpty, gesehen.insert(schluessel).inserted else { continue }
            ergebnis.append(fund)
            if ergebnis.count >= hoechstens { break }
        }
        return ergebnis
    }

    /// Applies the line-based response from `repairSentences` without allowing a
    /// malformed or repeated model line to damage otherwise valid prose.
    static func applyingSentenceRepairs(
        to text: String,
        findings: [(satz: String, grund: String)],
        response: String
    ) -> (text: String, replacedCount: Int) {
        var result = text
        var appliedNumbers = Set<Int>()
        let quoteCharacters = CharacterSet(charactersIn: "\"«»‹›„“‘’")

        for rawLine in response.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix("ERSATZ|") else { continue }
            let fields = line.split(separator: "|", maxSplits: 2,
                                    omittingEmptySubsequences: false)
            guard fields.count == 3,
                  let number = Int(fields[1].trimmingCharacters(in: .whitespaces)),
                  number >= 1, number <= findings.count,
                  !appliedNumbers.contains(number) else { continue }

            let oldSentence = findings[number - 1].satz
            let rawCandidate = String(fields[2])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let oldQuoteCount = oldSentence.unicodeScalars
                .filter { quoteCharacters.contains($0) }.count
            let candidateQuoteCount = rawCandidate.unicodeScalars
                .filter { quoteCharacters.contains($0) }.count

            // Sentence surgery must preserve the dialogue structure. Odd or newly
            // multiplied quote marks produced broken passages such as ?“?„ and
            // duplicated speech tags in real manuscripts.
            guard candidateQuoteCount == oldQuoteCount,
                  candidateQuoteCount.isMultiple(of: 2) else { continue }

            let candidate = humanizeProse(rawCandidate)
            guard candidate.wordCount >= 3,
                  candidate != oldSentence,
                  let range = result.range(of: oldSentence) else { continue }

            result.replaceSubrange(range, with: candidate)
            appliedNumbers.insert(number)
        }
        return (humanizeProse(result), appliedNumbers.count)
    }

    /// Buchweite Stil-Kennzahlen je 1000 Wörter – für Freigabe und Diagnose.
    static func stilKennzahlen(inChapters chapters: [String]) -> (bilder: Double,
                                                                 filter: Double,
                                                                 woerter: Int) {
        let text = chapters.joined(separator: "\n\n")
        let woerter = max(1, text.wordCount)
        let je1000 = { (n: Int) in Double(n) * 1000.0 / Double(woerter) }
        return (bilder: je1000(vergleichsDichte(in: text).anzahl),
                filter: je1000(filterwoerter(in: text).count),
                woerter: woerter)
    }

    /// Weiches Gate: Klingt die Szene maschinell ODER altertümlich (für ihre Länge)?
    /// Löst beim Schreiben höchstens EINE Neufassung aus; verwirft nie Inhalt.
    static func soundsLikeAI(_ text: String) -> Bool {
        let words = text.wordCount
        guard words >= 150 else { return false }
        // Schon zwei altertümliche Marker lassen den Text sofort antiquiert wirken.
        if archaicTellCount(text) >= 2 { return true }
        // Zwei akademische Fachwörter machen den Text für normale Leser unzugänglich.
        if jargonTellCount(text) >= 2 { return true }
        // Gehäufte Umschreibungen (Benennungs-Vermeidung, Korrekturfiguren) machen die
        // Geschichte unverständlich – dichteabhängig, damit lange Kapitel nicht über
        // legitime Einzelvorkommen stolpern.
        if circumlocutionCount(text) >= max(4, words / 220) { return true }
        let threshold = max(2, words / 300)
        return aiTellCount(text) >= threshold
    }

    // MARK: - Buchweite Wiederholungen (N-Gramm-Scan)

    /// Redebegleiter/Allerwelts-Phrasen, die naturgemäß oft vorkommen und KEINE
    /// Wiederholungs-Befunde sind.
    private static let ngramStopPhrases: Set<String> = [
        "sagte er und sah sie", "sagte sie und sah ihn",
        "sah sie an und sagte", "sah ihn an und sagte",
        "es war nicht das erste", "zum ersten mal seit langem"
    ]

    /// Findet Formulierungen (4-6-Wort-N-Gramme), die in mehreren VERSCHIEDENEN Kapiteln
    /// wiederkehren – die Lieblingsfloskeln des Modells, an denen Leser KI-Prosa erkennen.
    /// Rein deterministisch, kein Modell-Call. Liefert die auffälligsten zuerst.
    static func overusedPhrases(inChapters chapters: [String], minChapters: Int = 3,
                                maxResults: Int = 12) -> [String] {
        guard chapters.count >= minChapters else { return [] }
        // Pro Kapitel zählt jedes N-Gramm nur EINMAL – uns interessiert die
        // KAPITEL-übergreifende Wiederkehr, nicht die Dichte innerhalb eines Kapitels.
        var chapterCounts: [String: Int] = [:]
        var firstSpelling: [String: String] = [:]
        for chapter in chapters {
            let words = chapter
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            guard words.count >= 6 else { continue }
            var seenInChapter = Set<String>()
            for n in 4...6 {
                guard words.count >= n else { continue }
                for start in 0...(words.count - n) {
                    let gramWords = Array(words[start..<(start + n)])
                    let raw = gramWords.joined(separator: " ")
                    let key = String(raw.lowercased()
                        .filter { !",.;:!?…„“”»«\"'()".contains($0) })
                    // Nur „inhaltige" Gramme: mindestens ein Wort > 5 Zeichen,
                    // sonst matcht man nur Funktionswort-Ketten („und dann sah sie").
                    guard key.count >= 18,
                          gramWords.contains(where: { $0.count > 5 }),
                          !ngramStopPhrases.contains(key),
                          !seenInChapter.contains(key) else { continue }
                    seenInChapter.insert(key)
                    chapterCounts[key, default: 0] += 1
                    if firstSpelling[key] == nil { firstSpelling[key] = raw }
                }
            }
        }
        // Auffälligste zuerst; Teil-Gramme bereits gemeldeter Formulierungen unterdrücken.
        let hits = chapterCounts.filter { $0.value >= minChapters }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
        var results: [String] = []
        for (key, _) in hits {
            guard results.count < maxResults else { break }
            let spelled = firstSpelling[key] ?? key
            if !results.contains(where: { $0.lowercased().contains(key) || key.contains($0.lowercased()) }) {
                results.append(spelled)
            }
        }
        return results
    }

    /// Verbindliche Buchfreigabe fuer gehaemmerte Formulierungen. Anders als
    /// `overusedPhrases` zaehlt diese Pruefung auch die Gesamthaeufigkeit: Ein bewusstes
    /// Echo darf zweimal erscheinen, ein Textbaustein in vier oder mehr Kapiteln nicht.
    static func blockingRepeatedPhrases(inChapters chapters: [String],
                                        minimumChapters: Int = 3,
                                        minimumOccurrences: Int = 4,
                                        maxResults: Int = 12) -> [String] {
        guard chapters.count >= minimumChapters else { return [] }
        let stopWords: Set<String> = [
            "aber", "als", "am", "an", "auch", "auf", "aus", "bei", "da", "dann",
            "das", "dass", "dem", "den", "der", "des", "die", "du", "ein", "eine",
            "einem", "einen", "einer", "er", "es", "fuer", "für", "hat", "hatte",
            "ich", "ihm", "ihn", "ihr", "im", "in", "ist", "kein", "keine", "mit",
            "noch", "nicht", "nur", "oder", "sein", "seine", "sie", "sich", "so",
            "um", "und", "vom", "von", "war", "wenn", "wie", "wir", "zu", "zum", "zur"
        ]
        struct PhraseStat {
            var occurrences = 0
            var chapters = Set<Int>()
            var spelling = ""
        }
        var stats: [String: PhraseStat] = [:]
        let trimSet = CharacterSet.letters.union(.decimalDigits).inverted

        for (chapterIndex, chapter) in chapters.enumerated() {
            let originalWords = chapter.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: trimSet) }
                .filter { !$0.isEmpty }
            let normalizedWords = originalWords.map {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
            }
            guard normalizedWords.count >= 4 else { continue }
            for n in 4...6 where normalizedWords.count >= n {
                for start in 0...(normalizedWords.count - n) {
                    let words = Array(normalizedWords[start..<(start + n)])
                    let content = words.filter { !stopWords.contains($0) && $0.count >= 3 }
                    guard content.count >= 2 else { continue }
                    let key = words.joined(separator: " ")
                    guard key.count >= 16, !ngramStopPhrases.contains(key) else { continue }
                    var stat = stats[key] ?? PhraseStat()
                    stat.occurrences += 1
                    stat.chapters.insert(chapterIndex)
                    if stat.spelling.isEmpty {
                        stat.spelling = Array(originalWords[start..<(start + n)])
                            .joined(separator: " ")
                    }
                    stats[key] = stat
                }
            }
        }

        let candidates = stats.filter {
            $0.value.occurrences >= minimumOccurrences
                && $0.value.chapters.count >= minimumChapters
        }.sorted { lhs, rhs in
            if lhs.value.chapters.count != rhs.value.chapters.count {
                return lhs.value.chapters.count > rhs.value.chapters.count
            }
            if lhs.value.occurrences != rhs.value.occurrences {
                return lhs.value.occurrences > rhs.value.occurrences
            }
            return lhs.key.split(separator: " ").count > rhs.key.split(separator: " ").count
        }

        var results: [(key: String, spelling: String)] = []
        for (key, stat) in candidates {
            guard results.count < maxResults else { break }
            // Von ueberlappenden 4/5/6-Grammen nur die aussagekraeftigste Form melden.
            if results.contains(where: { $0.key.contains(key) || key.contains($0.key) }) {
                continue
            }
            results.append((key, stat.spelling))
        }
        return results.map(\.spelling)
    }

    /// Fruehwarnung beim Szenenschreiben: Meldet nur Phrasen, deren naechster Einsatz
    /// den Kandidaten selbst zum dritten Vorkommen ueber mindestens zwei Szenen macht.
    /// Damit wird die vierte, publikationsblockierende Wiederholung gar nicht erst
    /// geschrieben. Bereits vorhandene Altlasten blockieren eine neue Szene nur, wenn
    /// diese Szene die betreffende Wortfolge tatsaechlich erneut verwendet.
    static func repeatedPhraseCollisions(candidate: String,
                                         priorTexts: [String],
                                         maxResults: Int = 8) -> [String] {
        guard !candidate.isEmpty, !priorTexts.isEmpty else { return [] }

        func normalizedPhrase(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.letters.union(.decimalDigits).inverted)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        let candidateKey = normalizedPhrase(candidate)
        return blockingRepeatedPhrases(
            inChapters: priorTexts + [candidate],
            minimumChapters: 2,
            minimumOccurrences: 3,
            maxResults: maxResults * 2
        ).filter { phrase in
            let key = normalizedPhrase(phrase)
            return !key.isEmpty && candidateKey.contains(key)
        }.prefix(maxResults).map { $0 }
    }

    /// Exakte längere Satzduplikate sind in erzählender Prosa und Sachtext ein starkes
    /// Zeichen für Copy-/Template-Artefakte. Kurze Alltagssätze werden bewusst ignoriert.
    static func repeatedSentences(inChapters chapters: [String],
                                  minimumOccurrences: Int = 3,
                                  maxResults: Int = 10) -> [String] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for chapter in chapters {
            // Auch an Zeilenumbrüchen trennen: Dialogzeilen enden oft ohne Satzzeichen
            // („…Text“\n\nNächster Satz.“), sonst zöge der Umbruch in den „Satz" hinein
            // und der Treffer ließe sich später absatzweise nicht wiederfinden.
            let rawSentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?…\n"))
            for raw in rawSentences {
                let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { continue }
                let key = sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard key.count >= 26 else { continue }
                counts[key, default: 0] += 1
                if spelling[key] == nil { spelling[key] = sentence }
            }
        }
        return counts.filter { $0.value >= minimumOccurrences }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .prefix(maxResults)
            .map { spelling[$0.key] ?? $0.key }
    }

    /// Wie `repeatedSentences`, aber mit Häufigkeit UND Wortzahl je Satz. Grundlage
    /// für die abgestufte, professionelle Freigabe: nicht jede Wiederholung wiegt
    /// gleich schwer.
    static func repeatedSentenceStats(inChapters chapters: [String],
                                      minimumOccurrences: Int = 3
    ) -> [(sentence: String, occurrences: Int, words: Int)] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for chapter in chapters {
            let rawSentences = chapter.components(separatedBy: CharacterSet(charactersIn: ".!?…\n"))
            for raw in rawSentences {
                let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { continue }
                let key = sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#, with: " ", options: .regularExpression)
                    .split(whereSeparator: \.isWhitespace).joined(separator: " ")
                guard key.count >= 26 else { continue }
                counts[key, default: 0] += 1
                if spelling[key] == nil { spelling[key] = sentence }
            }
        }
        return counts.filter { $0.value >= minimumOccurrences }
            .sorted { ($0.value, $0.key.count) > ($1.value, $1.key.count) }
            .map { (spelling[$0.key] ?? $0.key, $0.value, (spelling[$0.key] ?? $0.key).wordCount) }
    }

    /// Wiederholungen, die eine Veröffentlichung wirklich blockieren (professioneller
    /// Maßstab): EGREGIÖSE Fälle. Ein Roman darf ein paar kurze, wiederkehrende Beats
    /// haben – aber KEINE distinktiven längeren Sätze wortgleich mehrfach und KEINEN
    /// Satz, der geradezu gehämmert wird. Diese Liste bestimmt sowohl die Freigabe als
    /// auch, was die Schlussreparatur gezielt entfernt (so konvergiert sie, statt kurze
    /// Beats endlos gegeneinander auszutauschen).
    ///
    /// Berücksichtigt zusätzlich, WO ein Satz wiederkehrt: Eine Wiederholung innerhalb
    /// EINES Kapitels ist meist ein bewusstes Stilmittel (Refrain, Echo), eine über das
    /// halbe Buch verteilte dagegen ein Textbaustein-Fehler. Ohne diese Unterscheidung
    /// wurden literarisch gewollte Wiederholungen fälschlich als Mangel gemeldet – und
    /// die Schlussreparatur tauschte sie sinnlos gegeneinander aus.
    static func blockingRepeatedSentences(inChapters chapters: [String]) -> [String] {
        func chapterIndices(containing sentence: String) -> [Int] {
            chapters.indices.filter { chapters[$0].localizedCaseInsensitiveContains(sentence) }
        }
        return repeatedSentenceStats(inChapters: chapters, minimumOccurrences: 2).compactMap { stat in
            let indices = chapterIndices(containing: stat.sentence)
            if indices.count <= 1 { return nil }                       // Stilmittel im selben Kapitel
            if indices.count == 2, let first = indices.first, let last = indices.last,
               last - first <= 1, stat.words <= 8 { return nil }       // kurzes Leitmotiv nebenan
            let isDistinctive = stat.words >= 7 && stat.occurrences >= 2
            let isHammered = stat.occurrences >= 5
            return (isDistinctive || isHammered) ? stat.sentence : nil
        }
    }

    /// Findet längere Sätze eines neuen Entwurfs, die im bisherigen Manuskript
    /// bereits wörtlich vorkommen. Anders als der buchweite Report meldet diese
    /// Prüfung nur Kollisionen, die der neue Text tatsächlich einführt.
    static func repeatedSentenceCollisions(candidate: String,
                                           priorTexts: [String],
                                           maxResults: Int = 12) -> [String] {
        let priorRecords = priorTexts.flatMap { significantSentenceRecords(in: $0) }
        let priorKeys = Set(priorRecords.map(\.key))
        // Wortfolgen der bisherigen Sätze – Grundlage für die Erkennung von
        // Fast-Wiederholungen (siehe `istFastGleich`).
        let priorTrigramme = priorRecords.map { wortTrigramme($0.spelling) }

        var seenInCandidate = Set<String>()
        var seenTrigramme: [Set<[String]>] = []
        var collisions: [String] = []

        for record in significantSentenceRecords(in: candidate) {
            let exaktSchonDa = priorKeys.contains(record.key)
            let exaktImKandidaten = !seenInCandidate.insert(record.key).inserted
            let eigene = wortTrigramme(record.spelling)
            // NEU: auch fast gleiche Sätze zählen, nicht nur wortgleiche.
            let fastSchonDa = !exaktSchonDa && priorTrigramme.contains { istFastGleich(eigene, $0) }
            let fastImKandidaten = !exaktImKandidaten && seenTrigramme.contains { istFastGleich(eigene, $0) }
            seenTrigramme.append(eigene)

            guard exaktSchonDa || exaktImKandidaten || fastSchonDa || fastImKandidaten else { continue }
            guard !collisions.contains(where: {
                normalizedSentenceKey($0) == record.key
            }) else { continue }
            collisions.append(record.spelling)
            if collisions.count >= maxResults { break }
        }
        return collisions
    }

    /// Anteil der Kandidaten-Sätze, die bereits erzählte Sätze (fast) wortgleich
    /// wiederholen – der deterministische „Dieselbe Szene noch einmal"-Detektor.
    ///
    /// WARUM: `repeatedSentenceCollisions` meldet nur die ersten 12 Einzelsätze und
    /// dient als Gate. Eine komplett neu erzählte Szene in leicht anderen Worten
    /// fällt damit nicht auf, obwohl sie inhaltlich eine Wiederholung ist. Der
    /// ANTEIL dagegen steigt bei einer echten Nacherzählung sprunghaft (30 % und
    /// mehr der Sätze sind Fast-Dubletten), während normale Folge-Szenen unter
    /// ~10 % bleiben (Rückverweise, wiederkehrende Formulierungen).
    static func retellingOverlap(candidate: String, priorTexts: [String]) -> Double {
        let candidateRecords = significantSentenceRecords(in: candidate)
        guard !candidateRecords.isEmpty else { return 0 }
        let priorRecords = priorTexts.flatMap { significantSentenceRecords(in: $0) }
        guard !priorRecords.isEmpty else { return 0 }
        let priorKeys = Set(priorRecords.map(\.key))
        let priorTrigramme = priorRecords.map { wortTrigramme($0.spelling) }
        var hits = 0
        for record in candidateRecords {
            let exact = priorKeys.contains(record.key)
            let eigene = wortTrigramme(record.spelling)
            if exact || priorTrigramme.contains(where: { istFastGleich(eigene, $0) }) {
                hits += 1
            }
        }
        return Double(hits) / Double(candidateRecords.count)
    }

    /// Ab diesem Anteil fast gleicher Sätze gilt eine Szene als Nacherzählung.
    static let retellingOverlapLimit = 0.30

    /// Anteil, ab dem zwei Sätze als dieselbe Formulierung gelten.
    ///
    /// Am fertigen Buch „Das letzte Streichholz" kalibriert: Bei 0,5 werden 63 Stellen in
    /// 31 Kapiteln getroffen, und jede einzelne davon ist eine echte Doppelung – etwa
    /// „Die ölige Pfütze im Eingangsbereich glänzte noch immer" gegen „Die ölige Pfütze
    /// im Flur glänzte noch immer". Niedriger angesetzt beginnt die Prüfung, normale
    /// Prosa zu beanstanden; höher lässt sie die Hälfte der Fälle durch.
    static let fastGleichSchwelle = 0.5

    /// Sind zwei Sätze dieselbe Formulierung mit ausgetauschten Wörtern?
    ///
    /// WARUM DAS GEBRAUCHT WIRD: Die Prüfung verglich vorher nur auf WORTGLEICHHEIT
    /// (normalisierter Satzschlüssel). Am fertigen Buch nachgemessen: 384 Satzpaare in
    /// benachbarten Szenen waren einander zu mindestens 62 % ähnlich – davon aber nur
    /// ACHT wortgleich. Die anderen 376 rutschten durch:
    ///
    ///     „Sie kniete sich hin, berührte die matte Oberfläche mit den Fingerspitzen."
    ///     „Sie bückte sich, berührte die Körner mit den Fingerspitzen."
    ///
    ///     „Die Treppe knarrte unter ihren Stiefeln wie morsche Knochen."
    ///     „Die Dielen knarrten unter ihren Stiefeln."
    ///     „Die Dielen stöhnten unter ihrem Gewicht."
    ///
    /// Genau solche Variationen derselben Satzschablone lassen einen Text maschinell
    /// wirken – jede Szene erzählt die vorige mit anderen Wörtern noch einmal. Der
    /// Erzeugungs-Prompt verbietet Wiederholungen ausdrücklich („ohne das Geschehene zu
    /// wiederholen"); das Modell hält sich nicht daran. Wirksam ist nur die Prüfung
    /// danach.
    ///
    /// Verglichen werden Wort-Dreiergruppen: Sie erfassen die Satzkonstruktion, nicht
    /// bloß den Wortschatz. Zwei Sätze über dasselbe Thema mit anderem Bau fallen nicht
    /// auf, dieselbe Konstruktion mit getauschten Wörtern schon.
    static func istFastGleich(_ a: Set<[String]>, _ b: Set<[String]>) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        let gemeinsam = a.intersection(b).count
        return Double(gemeinsam) / Double(min(a.count, b.count)) >= fastGleichSchwelle
    }

    /// Wort-Dreiergruppen eines Satzes, normalisiert (klein, ohne Diakritika/Satzzeichen).
    static func wortTrigramme(_ satz: String) -> Set<[String]> {
        let worte = satz
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard worte.count >= 3 else { return [] }
        var ergebnis = Set<[String]>()
        for i in 0...(worte.count - 3) {
            ergebnis.insert(Array(worte[i..<(i + 3)]))
        }
        return ergebnis
    }

    // MARK: - Spannungskurve (D2)

    /// Ein Punkt auf der Spannungskurve: Einsatz-Stufe (1–10) und ggf. eine
    /// dramaturgische Marke (HOOK, MIDPOINT-WENDE, DUNKLE NACHT, HÖHEPUNKT, AUFLÖSUNG).
    struct TensionAnchor {
        let kapitel: Int
        let stufe: Int
        let marke: String
    }

    /// SPANNUNGSKURVE: Der bisherige Planungs-Prompt sagte nur „Tempo variieren" –
    /// ob die EINSÄTZE über 40 Kapitel wirklich steigen, blieb dem Modell überlassen.
    /// Ergebnis: die klassische monotone Mitte, in der Kapitel 15 sich anfühlt wie
    /// Kapitel 8. Diese Kurve macht die Eskalation verbindlich und messbar:
    ///
    /// - Start bei 2/10 (Hook muss soghaft sein, aber Luft nach oben lassen)
    /// - leicht überlineare Steigung (pow 1.15) bis 10/10 – spätere Kapitel eskalieren
    ///   SCHNELLER, wie es Bestseller tun
    /// - MIDPOINT-WENDE (~50 %): Spielregeln ändern sich, Stufe springt auf ≥ 8
    /// - DUNKLE NACHT (~78 %): größter Verlust kurz vor dem Finale
    /// - HÖHEPUNKT (vorletztes Kapitel): 10/10, unvermeidliche Konfrontation
    /// - AUFLÖSUNG (letztes Kapitel): Auszahlung, bewusst ruhig (3/10)
    ///
    /// Wichtig: Die Kurve beschreibt EINSÄTZE, nicht Tempo – ruhige, tiefe Kapitel
    /// bleiben erlaubt, solange das, was auf dem Spiel steht, nie kleiner wird.
    static func spannungskurve(chapterCount n: Int) -> [TensionAnchor] {
        guard n > 0 else { return [] }
        let midpoint = max(2, n / 2)
        // Drei-Akt-Struktur mit den Positionen, die Leser erwarten: Katalysator bei
        // 12 %, Plot Point 1 („keine Umkehr mehr") am Ende von Akt I bei 25 %, Twist
        // bei 75 %. Ohne diese Anker franst der Mittelteil aus – genau der Vorwurf
        // „Handlung bewegt sich kaum vorwärts" aus dem Lektorat.
        let katalysator = max(2, Int((Double(n) * 0.12).rounded()))
        let plotPoint1 = max(katalysator + 1, Int((Double(n) * 0.25).rounded()))
        let twist = max(midpoint + 1, Int((Double(n) * 0.75).rounded()))
        let erstePruefung = Int((Double(n) * 0.37).rounded())
        let falscheSicherheit = Int((Double(n) * 0.62).rounded())
        let darkNight = max(twist + 1, Int((Double(n) * 0.85).rounded()))
        let climax = max(1, n - 1)
        return (1...n).map { k in
            let progress = Double(k - 1) / Double(max(n - 1, 1))
            var stufe = 2 + Int((8.0 * pow(progress, 1.15)).rounded())
            var marke = ""
            if k == 1 { marke = "HOOK"; stufe = min(stufe, 3) }
            if n >= 8 && k == katalysator { marke = "KATALYSATOR"; stufe = max(stufe, 5) }
            if n >= 8 && k == plotPoint1 && plotPoint1 != midpoint {
                marke = "PLOT POINT 1"; stufe = max(stufe, 6)
            }
            // LANGFORM: Ab 20 Kapiteln liegen sonst zehn und mehr Kapitel ohne
            // dramaturgischen Anker zwischen den Wendepunkten – genau dort franst
            // ein 500-Seiten-Buch aus („Was hat sich in den letzten 50 Seiten
            // geändert? Kaum etwas."). Zwei Zwischenziele halten den Mittelteil.
            if n >= 20 && k == erstePruefung && erstePruefung != plotPoint1 && erstePruefung != midpoint {
                marke = "ERSTE PRÜFUNG"; stufe = max(stufe, 6)
            }
            if n >= 20 && k == falscheSicherheit && falscheSicherheit != midpoint && falscheSicherheit != twist {
                marke = "FALSCHE SICHERHEIT"; stufe = max(stufe, 7)
            }
            if n >= 6 && k == midpoint { marke = "MIDPOINT-WENDE"; stufe = max(stufe, 8) }
            if n >= 10 && k == twist && twist != climax && twist != darkNight {
                marke = "TWIST"; stufe = max(stufe, 9)
            }
            if n >= 8 && k == darkNight && darkNight != climax { marke = "DUNKLE NACHT"; stufe = max(stufe, 8) }
            if n >= 2 && k == climax { marke = "HÖHEPUNKT"; stufe = 10 }
            if n >= 2 && k == n { marke = "AUFLÖSUNG"; stufe = 3 }
            return TensionAnchor(kapitel: k, stufe: stufe, marke: marke)
        }.reducingMonotonicity(untilChapter: climax)
    }

    /// Kompakte Textform der Kurve für Prompts („K1:2·HOOK, K2:2, …").
    static func spannungskurvenBrief(chapterCount: Int) -> String {
        spannungskurve(chapterCount: chapterCount).map { anchor in
            anchor.marke.isEmpty
                ? "K\(anchor.kapitel):\(anchor.stufe)"
                : "K\(anchor.kapitel):\(anchor.stufe)·\(anchor.marke)"
        }.joined(separator: ", ")
    }

    /// Stufe und Marke für ein konkretes Kapitel (0-basierter Index, wie er im
    /// Schreibloop verwendet wird).
    static func spannungsStufe(chapterIndex: Int, chapterCount: Int) -> TensionAnchor {
        let kurve = spannungskurve(chapterCount: chapterCount)
        guard chapterIndex >= 0, chapterIndex < kurve.count else {
            return TensionAnchor(kapitel: chapterIndex + 1, stufe: 5, marke: "")
        }
        return kurve[chapterIndex]
    }

    /// Konkrete Schreibanweisung zur Marke – was DIESES Kapitel dramaturgisch leisten muss.
    static func dramaturgieHinweis(marke: String) -> String {
        switch marke {
        case "HOOK":
            return """
            Erste Seite mitten im Konflikt, kein Welt-Erklären: ein konkretes Problem, eine Figur unter Druck, eine Frage, die der Leser beantwortet haben will. \
            DER LESER MUSS DIE HAUPTFIGUR KENNENLERNEN – dieses Kapitel beantwortet vier Fragen, und zwar im Handeln, nicht durch Erklären: \
            1) WER ist sie? Name, Lage, wie sie spricht und entscheidet – der Leser muss sie sich vorstellen können. \
            2) WIE SIEHT IHR ALLTAG AUS? Zeig die Normalwelt, bevor sie zerbricht: den Ort, an dem sie lebt, die Menschen um sie herum, ihre Routine. Nur so spürt der Leser später, was verloren geht. \
            3) WAS FEHLT IHR? Eine innere Leere, ein unerfüllter Wunsch, eine Angst, eine alte Schuld – etwas, das sie antreibt, auch wenn sie es selbst nicht ausspricht. \
            4) WAS STEHT AUF DEM SPIEL? Was kann sie verlieren – ein Mensch, ihre Existenz, ihr Selbstbild, ein Geheimnis? \
            Der Alltag darf gezeigt werden, aber niemals als ruhige Bestandsaufnahme: Er steht bereits unter Spannung, und etwas verändert sich schon in diesem Kapitel. \
            VERBOTEN als Einstieg: Wetter, Landschaft, Aufwachen, Rückblende oder Weltbeschreibung, ohne dass die Hauptfigur etwas will.
            """
        case "KATALYSATOR":
            return "Das auslösende Ereignis: Etwas zerbricht den Alltag der Hauptfigur endgültig. Sie kann nicht weitermachen wie bisher – aber sie hat sich noch nicht entschieden, was sie tut."
        case "PLOT POINT 1":
            return "KEINE UMKEHR MEHR: Die Hauptfigur trifft aktiv die Entscheidung, sich der Sache zu stellen, und betritt die neue Welt. Ab hier gibt es keinen Weg zurück in den Alltag von Kapitel 1 – die Tür fällt hinter ihr zu. Das muss ihre eigene Entscheidung sein, nicht etwas, das ihr zustößt."
        case "ERSTE PRÜFUNG":
            return "Der erste ernste Rückschlag in der neuen Welt: Der Plan der Hauptfigur scheitert zum ersten Mal richtig, und dadurch entsteht ein GRÖSSERES Problem als vorher. Sie lernt etwas über den Gegner oder über sich – aber es kostet sie etwas. Kein Leerlauf-Kapitel: Die Lage muss danach messbar schwieriger sein."
        case "FALSCHE SICHERHEIT":
            return "Scheinbarer Fortschritt: Die Hauptfigur glaubt, den Dreh raus zu haben, ein Teilziel gelingt, eine Beziehung stabilisiert sich. Genau darin liegt der Fehler – der Leser darf ahnen, dass es zu glatt läuft. Diese Ruhe baut den Druck für den kommenden Wendepunkt auf."
        case "MIDPOINT-WENDE":
            return "Hier ändern sich die SPIELREGELN: entweder ein FALSCHER SIEG (die Figur glaubt, sie habe es geschafft – es stimmt nicht) oder eine schwere Niederlage. Eine enthüllte Wahrheit, ein Verrat oder ein Verlust zerstört ihren bisherigen Plan. Keine kleine Wendung: Der Leser muss merken, dass dies eine andere Geschichte ist als die, die er zu lesen glaubte. Ab hier reagiert die Figur nicht mehr, sie handelt."
        case "TWIST":
            return "Der große Wendepunkt: Neue Information stellt alles infrage, was Figur UND Leser geglaubt haben – eine aufgedeckte Lüge, eine wahre Identität, ein Verrat. Entscheidend: Der Twist muss im Rückblick zwingend logisch wirken. Es müssen vorher Hinweise gelegen haben, die der Leser jetzt neu deutet. Kein Schock um des Schocks willen, sondern eine Vertiefung des Themas."
        case "DUNKLE NACHT":
            return "Der größte Verlust des Buches: scheinbare Niederlage, gebrochene Beziehung oder verlorene Hoffnung, die Figur ist isoliert und am Boden. Entscheidend ist, was hier NICHT passiert: Das Problem wird nicht größer. Die Hauptfigur muss eine INNERE Entscheidung treffen – sie muss sich selbst ändern, um es lösen zu können. Genau dieser Wandel trägt das Finale."
        case "HÖHEPUNKT":
            return "Die unvermeidliche Konfrontation: ALLES steht auf dem Spiel, keine Zurückhaltung, keine neuen Erklärungen – nur Entscheidung und Konsequenz."
        case "AUFLÖSUNG":
            return "DER ANFANG WAR EIN VERSPRECHEN – jetzt wird es eingelöst: Was Kapitel 1 aufgeworfen hat (die Frage, der Mangel, die Drohung), muss hier beantwortet sein, sonst fühlt sich der Leser betrogen. Echte Auszahlung statt neuer Eskalation: lose Fäden schließen, die neue Normalität zeigen (was hat sich für die Figur verändert?), ein Bild finden, das den Anfang spiegelt. Auch ein trauriges Ende muss den Leser zufrieden ausatmen lassen."
        default:
            return "Die Einsätze müssen über dem Niveau der früheren Kapitel liegen – Tempo-Atempause ja, kleiner werdende Einsätze nie."
        }
    }

    // MARK: - Szenen-Rhythmus (D1)

    /// Dramaturgisch begründete Szenenlängen statt reiner Zufallsstreuung.
    ///
    /// Bisher bekamen alle Szenen eines Kapitels per Zufall ±20 % desselben
    /// Wortziels – das Ohr des Lesers hört aber keine Wortzahl-Varianz, sondern
    /// das VERHÄLTNIS: ein kurzer Schock neben einem langen Kammerspiel. Diese
    /// Funktion verteilt die Szenen deterministisch auf drei Längenklassen
    /// (kurz 0.55×, mittel 1.0×, lang 1.6×) und positioniert sie nach
    /// Spannungsstufe des Kapitels:
    ///
    /// - hohe Stufe (≥8: Midpoint, dunkle Nacht, Höhepunkt): STAKKATO – mehrere
    ///   kurze, harte Szenen; die längste Szene ist die LETZTE (Klimax des Kapitels)
    /// - niedrige Stufe (≤4: Hook, Auflösung, Übergänge): KAMMERSPIEL – kurzer
    ///   Einstieg vorn, ausgedehnte Szenen in der Mitte/am Ende
    /// - Mittelfeld: WECHSELBAD – kurz und lang gemischt, die lange Szene in der
    ///   zweiten Kapitelhälfte (Zuspitzung zum Kapitelende)
    ///
    /// Rückgabe: Gewichte je Szene (werden auf das Kapitel-Wortziel normiert)
    /// und Etiketten für den Pacing-Hinweis im Szenenplan-Prompt.
    ///
    /// `targetWords` (Kapitel-Ziel) aktiviert den Kurzform-Schutz: Ergibt das
    /// Ziel im Schnitt weniger als 600 Wörter pro Szene, werden alle Szenen
    /// gleich lang – kleinere Klassen würden sonst Szenen unter ~250 Wörter
    /// erzeugen, die das Umfang-Gate endlos bekämpft. Bei Langform-Kapiteln
    /// (≥600 Wörter Ø pro Szene) bleibt der volle Rhythmus erhalten.
    static func szenenRhythmus(sceneCount: Int, stufe: Int, seedKey: String,
                               targetWords: Int = 0)
        -> (gewichte: [Double], etiketten: [String]) {
        guard sceneCount > 1 else {
            return sceneCount == 1 ? ([1.0], ["mittel – Fließtempo"]) : ([], [])
        }
        let seed = NarrativeSignature.stableSeed(seedKey)
        func seedWert(_ schritt: Int) -> Int {
            Int((seed >> UInt64((schritt % 8) * 8)) % 10_007)
        }
        // 0 = kurz, 1 = mittel, 2 = lang
        var klassen = [Int](repeating: 1, count: sceneCount)
        if stufe >= 8 {
            klassen[sceneCount - 1] = 2
            let kurzZiel = min(sceneCount - 1, max(2, sceneCount / 2))
            var gesetzt = 0
            var position = seedWert(1) % max(1, sceneCount - 1)
            while gesetzt < kurzZiel {
                if klassen[position] == 1 {
                    klassen[position] = 0
                    gesetzt += 1
                }
                position = (position + 1) % max(1, sceneCount - 1)
            }
        } else if stufe <= 4 {
            klassen[0] = 0
            klassen[sceneCount / 2] = 2
            if sceneCount >= 5 {
                klassen[sceneCount - 1] = 2
            }
        } else {
            let kurzIndex = seedWert(2) % sceneCount
            klassen[kurzIndex] = 0
            let hintereHaelfte = max(1, sceneCount - sceneCount / 2)
            var langIndex = sceneCount - 1 - (seedWert(3) % hintereHaelfte)
            if langIndex == kurzIndex {
                langIndex = kurzIndex == sceneCount - 1 ? sceneCount - 2 : sceneCount - 1
            }
            klassen[langIndex] = 2
            if sceneCount >= 5 {
                var zweiteKurze = (kurzIndex + 1 + seedWert(4)) % sceneCount
                if zweiteKurze == kurzIndex || zweiteKurze == langIndex {
                    zweiteKurze = (kurzIndex + 1) % sceneCount
                    if zweiteKurze == langIndex { zweiteKurze = (zweiteKurze + 1) % sceneCount }
                }
                klassen[zweiteKurze] = 0
            }
        }
        // Kurzform-Schutz: Ergibt das Kapitel-Ziel im Schnitt weniger als 600
        // Wörter pro Szene, würde jede Längenklasse Szenen unter ~250 Wörter
        // erzeugen – zu wenig für eine echte Szene, und das Umfang-Gate
        // bekämpft sie danach endlos. Kleine Kapitel bekommen daher gleich
        // lange Szenen; der Rhythmus ist ein Langform-Merkmal (s. Kommentar).
        let kurzform = targetWords > 0 && sceneCount > 0
            && Double(targetWords) / Double(sceneCount) < 600
        if kurzform {
            klassen = [Int](repeating: 1, count: sceneCount)
        }
        let gewichte = klassen.map { klasse -> Double in
            switch klasse {
            case 0: return 0.55
            case 2: return 1.6
            default: return 1.0
            }
        }
        let etiketten = klassen.map { klasse -> String in
            switch klasse {
            case 0: return "kurz – Schlaglicht, harter Schnitt"
            case 2: return "lang – Kammerspiel, emotionale Tiefe"
            default: return "mittel – Fließtempo"
            }
        }
        return (gewichte, etiketten)
    }

    /// Filtert den Fakten-Ledger auf die Zeilen, die für DIESE Szene relevant sind.
    ///
    /// WARUM: Der Ledger wurde bisher vollständig in JEDEN Szenen-Prompt injiziert.
    /// Bei einem 40-Kapitel-Buch sind das schnell 100+ Zeilen Fakten zu Figuren und
    /// Orten, die in der aktuellen Szene gar nicht vorkommen – der Prompt wird
    /// länger, die Aufmerksamkeit des Modells für die wirklich wichtigen Fakten
    /// sinkt (und die Tokenkosten steigen). Relevanz heißt hier: Die Faktenzeile
    /// teilt mindestens ein bedeutendes Wort (≥4 Buchstaben) mit dem Szenenkontext
    /// (Kapitelziel, Szenenziel, Hindernis, Ort, auftretende Figuren, jüngste Handlung).
    /// Sicherheitsnetz: Bleiben zu wenige Zeilen übrig, wird der volle Ledger
    /// (gedeckelt) verwendet – lieber ein Fakt zu viel als einer zu wenig.
    static func relevantFacts(ledger: String, context: String, maxLines: Int = 40) -> String {
        let lines = ledger.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 8 else { return lines.joined(separator: "\n") }

        let contextWords = Set(
            context.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
        )
        guard !contextWords.isEmpty else {
            return lines.prefix(maxLines).joined(separator: "\n")
        }

        let relevant = lines.filter { line in
            line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .contains { $0.count >= 4 && contextWords.contains($0) }
        }
        // Zu aggressiv gefiltert? Dann lieber den (gedeckelten) vollen Ledger.
        guard relevant.count >= 3 else {
            return lines.prefix(maxLines).joined(separator: "\n")
        }
        return relevant.prefix(maxLines).joined(separator: "\n")
    }

    // MARK: - Thematisches Retrieval (C3)

    /// Findet die 2–3 thematisch ÄHNLICHSTEN früheren Szenen zur aktuellen Szene.
    ///
    /// WARUM: Der Schreibkontext enthält bisher nur das chronologische Fenster
    /// („LETZTE SZENEN IM DETAIL": die 6 jüngsten) plus verdichtete Kapitel-
    /// Digests. Ruft eine Szene in Kapitel 30 ein Ereignis aus Kapitel 4 zurück
    /// (derselbe Ort, dieselbe Figur, dasselbe Versprechen), fehlen dem Modell
    /// die konkreten Details – es erfindet sie neu und widerspricht damit dem
    /// früheren Kapitel, ODER es erzählt das Ereignis versehentlich noch einmal
    /// als „neu". Dieses Retrieval holt die inhaltlich passenden alten Szenen-
    /// Summaries gezielt in den Prompt: Das Modell kann daran anknüpfen, statt
    /// zu raten.
    ///
    /// Ähnlichkeit = Anzahl geteilter bedeutender Wörter (≥4 Buchstaben, ohne
    /// hochfrequente Funktionswörter). Die letzten `ausschlussLetzte` Einträge
    /// werden übersprungen (sie stehen schon im Detailfenster). Mindestens
    /// `mindestTreffer` geteilte Wörter, damit kein Rauschen in den Prompt kommt.
    static func thematischAehnlicheSzenen(sceneSummaries: [String], kontext: String,
                                          ausschlussLetzte: Int = 6,
                                          maxErgebnisse: Int = 3,
                                          mindestTreffer: Int = 2) -> [String] {
        // Hochfrequente Wörter, die in fast jeder Summary vorkommen und sonst
        // Schein-Ähnlichkeit erzeugen würden.
        let funktionswoerter: Set<String> = [
            "dass", "aber", "oder", "wenn", "dann", "noch", "schon", "wieder",
            "immer", "sagt", "geht", "kommt", "sieht", "steht", "macht", "gibt",
            "wird", "wurde", "haben", "seine", "seiner", "seinen", "ihre",
            "ihrer", "ihren", "einer", "einem", "einen", "nach", "sich",
            "nicht", "auch", "mehr", "beim", "über", "unter", "zwischen",
            "weil", "als", "mit", "von", "und", "der", "die", "das", "ein",
            "eine", "ist", "sind", "war", "waren", "hat", "hatte", "kann",
            "muss", "soll", "will", "lässt", "bleibt", "findet", "nimmt",
            "zwei", "erste", "letzte", "ganz", "sehr", "viel", "alle", "alles"
        ]
        func woerter(_ text: String) -> Set<String> {
            Set(
                text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 4 && !funktionswoerter.contains($0) }
            )
        }
        let kontextWoerter = woerter(kontext)
        guard !kontextWoerter.isEmpty else { return [] }

        let kandidaten = sceneSummaries.dropLast(ausschlussLetzte)
        let bewertet: [(index: Int, treffer: Int, zeile: String)] = kandidaten.enumerated()
            .compactMap { index, zeile in
                let treffer = woerter(zeile).intersection(kontextWoerter).count
                return treffer >= mindestTreffer ? (index, treffer, zeile) : nil
            }
        // Treffer entscheiden; bei Gleichstand gewinnt die JÜNGERE Szene
        // (höhere Wahrscheinlichkeit, dass der Rückruf aktuell ist).
        return bewertet
            .sorted { lhs, rhs in
                lhs.treffer != rhs.treffer ? lhs.treffer > rhs.treffer : lhs.index > rhs.index
            }
            .prefix(maxErgebnisse)
            .sorted { $0.index < $1.index } // Ausgabe wieder chronologisch
            .map(\.zeile)
    }

    /// Parst die Antwort des Figurenstand-Prompts (`PromptFactory.characterStateUpdate`)
    /// in `Name → Stand`. Nur Zeilen, deren Name einer bekannten Figur entspricht,
    /// werden übernommen – so können weder Halluzinations-Figuren noch Freitext
    /// das Register vergiften. Der Vergleich ist diakritik- und groß/klein-tolerant,
    /// weil das Modell Namen gelegentlich leicht anders schreibt.
    static func parseCharacterStateLines(_ antwort: String, knownNames: [String]) -> [String: String] {
        func norm(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t-•*"))
        }
        var ergebnis: [String: String] = [:]
        for rawLine in antwort.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let namePart = norm(String(line[..<colon]))
            let stand = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            guard !stand.isEmpty else { continue }
            guard let kanonName = knownNames.first(where: {
                let kanon = norm($0)
                // Voller Name oder eindeutiger Vorname (verhindert „Jonas" vs. „Jonas Hartmann"-Duplikate).
                return kanon == namePart || kanon.split(separator: " ").first.map(String.init) == namePart
            }) else { continue }
            // Zeilen hart deckeln: Der Stand wird in jeden folgenden Szenen-Prompt
            // injiziert – ein ausufernder Eintrag fräße das Kontextbudget.
            ergebnis[kanonName] = stand.truncated(to: 220)
        }
        return ergebnis
    }

    /// Ergebnis der Golden-Eval (siehe PromptFactory.goldenEval): numerische Noten
    /// je Dimension, Gesamtnote, Freigabe-Urteil und konkrete Schwächen.
    struct GoldenEval {
        var noten: [(name: String, wert: Int)] = []
        var gesamt: Int?
        var gesamtBegruendung = ""
        var freigabe: Bool?
        var schwaechen: [String] = []
    }

    /// Parst die Golden-Eval-Antwort. Tolerant gegenüber Formatwacklern (fehlende
    /// Begründung, „Note: 7" statt „7", URTEIL in Kleinbuchstaben), aber strikt bei
    /// den Notenwerten: Nur ganze Zahlen 1–10 zählen, alles andere wird ignoriert,
    /// damit ein ausuferndes Modell keine Phantom-Noten erzeugt.
    static func parseGoldenEval(_ antwort: String) -> GoldenEval {
        var eval = GoldenEval()
        for rawLine in antwort.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let schluessel = String(line[..<colon])
                .trimmingCharacters(in: .whitespaces).uppercased()
            let rest = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)

            if schluessel.hasPrefix("URTEIL") {
                eval.freigabe = rest.uppercased().hasPrefix("FREIGABE")
                continue
            }
            if schluessel.hasPrefix("SCHWÄCHE") || schluessel.hasPrefix("SCHWACHE") {
                if !rest.isEmpty, eval.schwaechen.count < 3 {
                    eval.schwaechen.append(rest.truncated(to: 300))
                }
                continue
            }
            // Notenzeile: Zahl am Anfang (optional „Note:" davor), Begründung nach „—".
            var zahlText = rest
            if let noteRange = zahlText.range(of: "—") {
                zahlText = String(zahlText[..<noteRange.lowerBound])
            } else if let noteRange = zahlText.range(of: " - ") {
                zahlText = String(zahlText[..<noteRange.lowerBound])
            }
            zahlText = zahlText.replacingOccurrences(of: "Note", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            // Modelle schreiben trotz Formatvorgabe haeufig „7/10". Das ist eine
            // vollstaendige Note und darf nicht einen weiteren kompletten
            // Endabnahme-Zyklus ausloesen.
            let numericPrefix = zahlText.prefix { $0.isNumber }
            guard let wert = Int(numericPrefix),
                  (1...10).contains(wert) else { continue }
            let begruendung: String
            if let dash = rest.range(of: "—") ?? rest.range(of: " - ") {
                begruendung = String(rest[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                begruendung = ""
            }
            if schluessel.hasPrefix("GESAMT") {
                eval.gesamt = wert
                eval.gesamtBegruendung = begruendung
            } else {
                if let index = eval.noten.firstIndex(where: { $0.name == schluessel }) {
                    eval.noten[index] = (name: schluessel, wert: wert)
                } else {
                    eval.noten.append((name: schluessel, wert: wert))
                }
            }
        }
        return eval
    }

    /// Ein Ton-Drift-Befund (A3): ein Kapitel, das stilistisch aus dem Buchton fällt.
    struct ToneDriftFinding {
        let number: Int
        let grund: String
    }

    /// TON-ANGLEICH (A3): Die Kapitelrevision läuft parallel und isoliert – kein
    /// Kapitel weiß, wie seine Nachbarn revidiert wurden. Dadurch kann der Ton
    /// driften: Kapitel 7 plötzlich mit halb so langen Sätzen, Kapitel 12 fast
    /// ohne Dialog, Kapitel 20 voller Floskeln. Leser merken das als „unruhiges
    /// Lesegefühl", ohne es benennen zu können.
    ///
    /// Dieser Check misst drei robuste Stil-Metriken pro Kapitel (mittlere
    /// Satzlänge, Dialogdichte, Floskeldichte) und meldet Ausreißer gegenüber dem
    /// Buch-Median. Bewusst deterministisch und nur MELDEND (Warnung ins
    /// Schlussaudit): Eine automatische Re-Revision wegen 61 % Abweichung würde
    /// gute, bewusst anders getaktete Kapitel (Action vs. Kammerspiel) ruinieren.
    static func toneDriftFindings(chapters: [(number: Int, text: String)],
                                  minChapters: Int = 5) -> [ToneDriftFinding] {
        struct Metrik {
            let number: Int
            let satzlaenge: Double     // Wörter pro Satz
            let dialogDichte: Double   // Rede-Einsätze pro 1000 Wörter
            let floskelDichte: Double  // KI-Tells pro 1000 Wörter
        }
        let metriken: [Metrik] = chapters.compactMap { (number, text) in
            let woerter = text.split(whereSeparator: { $0.isWhitespace }).count
            guard woerter >= 250 else { return nil }
            let saetze = max(1, text.components(separatedBy: CharacterSet(charactersIn: ".!?…"))
                .filter { $0.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0.isWhitespace }).count >= 3 }.count)
            let reden = text.components(separatedBy: "„").count - 1
                + text.components(separatedBy: "»").count - 1
            let tells = aiTellCount(text)
            let pro1000 = 1000.0 / Double(woerter)
            return Metrik(number: number,
                          satzlaenge: Double(woerter) / Double(saetze),
                          dialogDichte: Double(reden) * pro1000,
                          floskelDichte: Double(tells) * pro1000)
        }
        guard metriken.count >= minChapters else { return [] }

        func median(_ werte: [Double]) -> Double {
            let sortiert = werte.sorted()
            return sortiert[sortiert.count / 2]
        }
        let medianSatz = median(metriken.map(\.satzlaenge))
        let medianDialog = median(metriken.map(\.dialogDichte))
        let medianFloskel = median(metriken.map(\.floskelDichte))

        var befunde: [ToneDriftFinding] = []
        for m in metriken {
            var gruende: [String] = []
            // 60 % Abweichung vom Buch-Median = aus dem Buchton gefallen.
            // Dialogdichte nur prüfen, wenn das Buch überhaupt Dialog hat
            // (Median 0 würde jeden Dialog zum „Ausreißer" machen).
            if medianSatz > 0, abs(m.satzlaenge - medianSatz) / medianSatz > 0.6 {
                gruende.append(String(format: "mittlere Satzlänge %.0f statt ~%.0f Wörter",
                                      m.satzlaenge, medianSatz))
            }
            if medianDialog >= 2, abs(m.dialogDichte - medianDialog) / medianDialog > 0.6 {
                gruende.append(String(format: "Dialogdichte %.0f statt ~%.0f Reden pro 1000 Wörter",
                                      m.dialogDichte, medianDialog))
            }
            if medianFloskel > 0.5, abs(m.floskelDichte - medianFloskel) / medianFloskel > 0.6,
               m.floskelDichte > medianFloskel {   // nur ZU VIELE Floskeln sind Drift
                gruende.append(String(format: "Floskeldichte %.0f statt ~%.0f pro 1000 Wörter",
                                      m.floskelDichte, medianFloskel))
            }
            if !gruende.isEmpty {
                befunde.append(ToneDriftFinding(number: m.number,
                                                grund: gruende.joined(separator: "; ")))
            }
        }
        return befunde
    }


    struct StyleTicVerdict {
        let muster: String
        let beleg: String
        let anweisung: String
    }

    /// Parst TICK-Zeilen des Stiltick-Judges. Strikt beim Format (vier Felder mit
    /// „|" getrennt), damit Kommentarzeilen des Modells nicht als Befund durchrutschen;
    /// tolerant bei Leerzeichen und Aufzählungszeichen am Zeilenanfang.
    static func parseStyleTicVerdicts(_ antwort: String, maxVerdicts: Int = 5) -> [StyleTicVerdict] {
        parseVerdictLines(antwort, tag: "TICK", maxVerdicts: maxVerdicts)
    }

    /// Parst STIMME-Zeilen des Figurenstimmen-Audits (gleiches Zeilenformat wie TICK,
    /// andere Prüffrage – siehe PromptFactory.dialogueVoiceAudit).
    static func parseDialogueVoiceVerdicts(_ antwort: String, maxVerdicts: Int = 4) -> [StyleTicVerdict] {
        parseVerdictLines(antwort, tag: "STIMME", maxVerdicts: maxVerdicts)
    }

    /// Hat das Kapitel genug wörtliche Rede, dass sich ein Stimmen-Audit lohnt?
    /// Unter ~6 Rede-Einsätzen gibt es keine belastbare Vergleichsbasis – der
    /// Audit-Call wäre Kosten ohne Aussage.
    static func hatNennenswertenDialog(_ text: String) -> Bool {
        let anfuehrungen = text.components(separatedBy: "„").count - 1
        let guillemets = text.components(separatedBy: "»").count - 1
        return anfuehrungen + guillemets >= 6
    }

    /// Urteil eines simulierten Beta-Lesers (siehe PromptFactory.betaReaderPass).
    struct BetaReaderVerdict {
        let persona: String
        let sterne: Int
        let problem: String
        let anweisung: String
    }

    /// Parst PERSONA-Zeilen des Beta-Leser-Passes. Nur Zeilen mit gültiger
    /// Sternezahl (1–5) zählen; „keins"/„-"-Platzhalter werden als sauber gewertet.
    /// Zurückgegeben werden ALLE geparsten Urteile (auch 4–5 Sterne) – die
    /// Filterung auf handlungsbedürftige Befunde ist Aufgabe des Aufrufers.
    static func parseBetaReaderVerdicts(_ antwort: String) -> [BetaReaderVerdict] {
        antwort.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix("PERSONA|") else { return nil }
            let felder = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard felder.count >= 5 else { return nil }
            let persona = felder[1]
            guard !persona.isEmpty,
                  let sterne = Int(felder[2]), (1...5).contains(sterne) else { return nil }
            return BetaReaderVerdict(persona: persona.truncated(to: 40),
                                     sterne: sterne,
                                     problem: felder[3].truncated(to: 240),
                                     anweisung: felder[4].truncated(to: 240))
        }
    }

    /// Ergebnis der Emotionsschritt-Verifikation (D3).
    struct EmotionalStepVerdict {
        let erfuellt: Bool
        let problem: String
        let anweisung: String
    }

    /// Holt den geplanten „Emotionalen Schritt" aus dem Kapitelziel. Der
    /// Kapitelplan-Parser faltet das 4. Planfeld als „ – Emotionaler Schritt: …"
    /// ins Ziel (siehe Agents.swift ~Zeile 2496) – diese Funktion macht die
    /// Verpackung wieder rückgängig, ohne das eigentliche Ziel anzutasten.
    static func plannedEmotionalStep(from chapterGoal: String) -> String {
        guard let range = chapterGoal.range(
            of: "Emotionaler Schritt:", options: .caseInsensitive
        ) else { return "" }
        return String(chapterGoal[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parst die ERFÜLLT/FEHLT-Antwort des Emotionsschritt-Audits.
    /// Unklare Antworten gelten als ERFÜLLT – eine verschattete Prüfung darf nie
    /// falsche Reparaturaufträge erzeugen (im Zweifel zählt der geschriebene Text).
    static func parseEmotionalStepVerdict(_ antwort: String) -> EmotionalStepVerdict {
        let line = antwort.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard line.uppercased().hasPrefix("FEHLT|") else {
            return EmotionalStepVerdict(erfuellt: true, problem: "", anweisung: "")
        }
        let felder = line.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard felder.count >= 3, !felder[1].isEmpty else {
            return EmotionalStepVerdict(erfuellt: true, problem: "", anweisung: "")
        }
        return EmotionalStepVerdict(erfuellt: false,
                                    problem: felder[1].truncated(to: 240),
                                    anweisung: felder[2].truncated(to: 240))
    }

    /// Gemeinsamer Zeilenparser für Judge-Antworten im Format
    /// `TAG|Feld1|Feld2|Feld3`. Strikt beim Tag und der Feldzahl, damit
    /// Kommentarzeilen des Modells nicht als Befund durchrutschen; tolerant bei
    /// Leerzeichen und Aufzählungszeichen am Zeilenanfang.
    private static func parseVerdictLines(_ antwort: String, tag: String,
                                          maxVerdicts: Int) -> [StyleTicVerdict] {
        antwort.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
                .trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix(tag + "|") else { return nil }
            let felder = line.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard felder.count >= 4 else { return nil }
            let muster = felder[1], anweisung = felder[3]
            guard !muster.isEmpty, !anweisung.isEmpty else { return nil }
            return StyleTicVerdict(muster: muster.truncated(to: 120),
                                   beleg: felder[2].truncated(to: 160),
                                   anweisung: anweisung.truncated(to: 220))
        }.prefix(maxVerdicts).map { $0 }
    }

    /// Findet Szenenpläne, deren Beats einander inhaltlich wiederholen.
    ///
    /// WARUM: Die Wurzel der doppelt erzählten Szenen liegt im PLAN, nicht in der
    /// Prosa – bekamen zwei Szenen desselben Plan-Beat („ein neuer Vorstoß"), MUSSTE
    /// der Draft Writer dasselbe Ereignis zweimal erzählen, und keine spätere
    /// Reparatur konnte das beheben (gemessen: acht erfolgreiche Neufassungen, acht
    /// Doppler). Bisher prüfte `istGenerischerSzenenplan` nur abstrakte Standard-
    /// Formulierungen; ein Plan kann aber auch mit konkret klingenden, einander
    /// gleichenden Beats durchkommen. Verglichen wird die kombinierte Beat-Signatur
    /// (Ziel + Hindernis + Wendung) paarweise via Wort-Trigrammen – derselbe
    /// Mechanismus, der sich bei der Satz-Doppler-Erkennung bewährt hat.
    ///
    /// Rückgabe: lesbare Beschreibungen der Doppler-Paare (für Ablehnungsgrund und
    /// Neuplanungshinweis), leer bei einem diversen Plan.
    static func duplicatedSceneBeats(_ planned: [PlannedScene]) -> [String] {
        guard planned.count > 1 else { return [] }
        let signaturen = planned.map { szene in
            wortTrigramme("\(szene.goal) \(szene.obstacle) \(szene.turn)")
        }
        let genericWords: Set<String> = [
            "dabei", "damit", "danach", "erneut", "gegen", "ihren", "ihrer", "ihrem",
            "kapitel", "maren", "merkt", "muss", "nicht", "seine", "seiner", "szene",
            "unter", "wieder", "will", "wird", "wurde", "zuruck"
        ]
        let schluesselwoerter = planned.map { scene -> Set<String> in
            let perspectiveParts = Set(CharacterCanonAudit.nameParts(scene.perspective))
            return Set(
                "\(scene.goal) \(scene.obstacle) \(scene.turn)"
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                    .components(separatedBy: CharacterSet.letters.inverted)
                    .filter {
                        $0.count >= 5 && !genericWords.contains($0)
                            && !perspectiveParts.contains($0)
                    }
            )
        }
        var doppler: [String] = []
        for i in 0..<planned.count {
            for j in (i + 1)..<planned.count {
                let gemeinsameSchluessel = schluesselwoerter[i].intersection(schluesselwoerter[j])
                let kleinereMenge = max(1, min(schluesselwoerter[i].count, schluesselwoerter[j].count))
                let semantischGleich = gemeinsameSchluessel.count >= 4
                    && Double(gemeinsameSchluessel.count) / Double(kleinereMenge) >= 0.22
                guard istFastGleich(signaturen[i], signaturen[j]) || semantischGleich else { continue }
                let beschreibung = "Szene \(planned[i].number) und Szene \(planned[j].number) erzählen denselben Beat"
                if !doppler.contains(beschreibung) { doppler.append(beschreibung) }
            }
        }
        return doppler
    }

    private static func significantSentenceRecords(in text: String) -> [(key: String, spelling: String)] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?…\n")).compactMap { raw in
            let sentence = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.wordCount >= 5, sentence.wordCount <= 40 else { return nil }
            let key = normalizedSentenceKey(sentence)
            guard key.count >= 26 else { return nil }
            return (key, sentence)
        }
    }

    private static func normalizedSentenceKey(_ sentence: String) -> String {
        sentence.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9äöüß ]+"#,
                                  with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func nonfictionPracticalCoverage(_ chapters: [String]) -> Double {
        guard !chapters.isEmpty else { return 0 }
        let markers = ["beispiel", "übung", "checkliste", "nächster schritt",
                       "so gehst du", "in der praxis", "reflexion", "aufgabe"]
        let useful = chapters.filter { chapter in
            let normalized = chapter.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return markers.contains(where: normalized.contains)
        }.count
        return Double(useful) / Double(chapters.count)
    }

    static func satisfiesNonfictionSectionContract(_ text: String,
                                                   sectionKind: String,
                                                   takeaway: String) -> Bool {
        let expected = "\(sectionKind) \(takeaway)"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let candidate = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if expected.contains("checkliste") { return candidate.contains("checkliste") }
        if expected.contains("ubung") || expected.contains("aufgabe") {
            return candidate.contains("ubung") || candidate.contains("aufgabe")
        }
        if expected.contains("beispiel") { return candidate.contains("beispiel") }
        return true
    }

    // MARK: - Romance-Eskalation (Beziehungstemperatur)

    /// Romance-artige Genres, deren Kernversprechen eine ESKALIERENDE Beziehung ist.
    static func isRomanceGenre(_ genre: String) -> Bool {
        let g = genre.lowercased()
        return ["romance", "liebe", "romantasy", "erotik", "new adult"].contains { g.contains($0) }
    }

    /// Zielwert der Beziehungstemperatur (2–10) für ein Kapitel: steigt linear über das
    /// Buch. Gibt dem „Slow Burn" eine messbare Leiter – gegen das bekannte
    /// „Dark Romance liest sich als kühler Thriller"-Problem (No Burn).
    static func romanceHeatTarget(chapterIndex: Int, chapterCount: Int) -> Int {
        guard chapterCount > 1 else { return 6 }
        let fraction = Double(chapterIndex) / Double(chapterCount - 1)
        return min(10, max(2, 2 + Int((fraction * 8.0).rounded())))
    }

    // MARK: - Rewrite-Abnahme (Revision/Korrektorat)

    static func hasCompleteSentenceEnding(_ text: String) -> Bool {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let closingCharacters = CharacterSet(charactersIn: "\"'“”„«»’)]}")
        trimmed = trimmed.trimmingCharacters(in: closingCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return false }
        return ".!?…".contains(last)
    }

    static func finishReasonIndicatesTruncation(_ finishReason: String?) -> Bool {
        guard let reason = finishReason?.lowercased() else { return false }
        return ["length", "max_token", "token_limit", "max_output", "incomplete"]
            .contains { reason.contains($0) }
    }

    static func isLikelyTruncated(_ text: String, finishReason: String? = nil) -> Bool {
        finishReasonIndicatesTruncation(finishReason) || !hasCompleteSentenceEnding(text)
    }

    /// Ein Plot braucht neben einem vollständigen letzten Satz einen expliziten Marker.
    /// Der Marker verhindert, dass ein zufällig am Satzende erreichtes Tokenlimit wie eine
    /// vollständige Bucharchitektur aussieht. `PLOT_ENDE` wird nur in frischen Plotprompts
    /// verlangt; bereits gespeicherte Altprojekte bleiben beim Fortsetzen unangetastet.
    static func plotCompletionIssues(_ text: String, finishReason: String?) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [String] = []
        if finishReasonIndicatesTruncation(finishReason) {
            issues.append("Die Bucharchitektur erreichte das Ausgabelimit.")
        }

        let lines = trimmed.components(separatedBy: .newlines)
        let hasEndMarker = lines.last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("PLOT_ENDE") == .orderedSame
        if !hasEndMarker {
            issues.append("Der eindeutige Abschlussmarker PLOT_ENDE fehlt.")
        }

        let body = hasEndMarker
            ? lines.dropLast().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed
        if !hasCompleteSentenceEnding(body) {
            issues.append("Die Bucharchitektur bricht mitten im Satz ab.")
        }
        return issues
    }

    /// Schneidet nur das technisch unvollständige Satzfragment am Ende ab. Bereits
    /// abgeschlossene Sätze bleiben bytegenau erhalten und bilden den Fortsetzungspunkt.
    static func safePrefixBeforeTruncation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !hasCompleteSentenceEnding(trimmed) else { return trimmed }
        guard let boundary = trimmed.lastIndex(where: { ".!?…".contains($0) }) else { return "" }
        return String(trimmed[...boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Verbindet eine Modell-Fortsetzung ohne den häufig wiederholten letzten Absatz/Satz.
    static func mergingContinuation(base: String, continuation: String) -> String {
        let left = base.trimmingCharacters(in: .whitespacesAndNewlines)
        var right = continuation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }

        let lastParagraph = left.components(separatedBy: "\n\n").last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sentenceParts = left.components(separatedBy: CharacterSet(charactersIn: ".!?…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lastSentenceStem = sentenceParts.last ?? ""
        let candidates = [lastParagraph, lastSentenceStem]
            .filter { $0.count >= 24 }
            .sorted { $0.count > $1.count }
        for repeated in candidates where right.hasPrefix(repeated) {
            right.removeFirst(repeated.count)
            right = String(right.drop(while: \.isWhitespace))
            let leftoverClosers = CharacterSet(charactersIn: ".!?…)]}”’»")
            while let first = right.unicodeScalars.first, leftoverClosers.contains(first) {
                right.removeFirst()
            }
            right = String(right.drop(while: \.isWhitespace))
            break
        }
        return right.isEmpty ? left : left + "\n\n" + right
    }

    /// Prüft, ob eine Überarbeitung als Ersatz für die Quelle akzeptiert werden darf.
    /// Vorher genügten 50% der Wortzahl – ein bei maxTokens ABGESCHNITTENES Kapitel
    /// (endet mitten im Satz, Szenentrenner fehlen) wurde stillschweigend übernommen
    /// und landete halbiert beim Leser.
    static func isAcceptableRewrite(source: String, candidate: String,
                                    minRatio: Double = 0.8,
                                    maxRatio: Double? = nil,
                                    finishReason: String? = nil) -> Bool {
        let sourceWords = source.wordCount
        let candidateWords = candidate.wordCount
        guard sourceWords > 0 else { return !candidate.isEmpty }
        guard Double(candidateWords) >= Double(sourceWords) * minRatio else { return false }
        // Obergrenze: Eine Politur/Reparatur darf ein Kapitel NICHT aufblähen. Ohne
        // dieses Limit vervielfachten die ganz-Kapitel-Umschreibungen die Länge (z.B.
        // 873 → 2.344 Wörter) und machten die sonst zielgenaue Rohfassung kaputt.
        if let maxRatio, Double(candidateWords) > Double(sourceWords) * maxRatio { return false }
        guard !isLikelyTruncated(candidate, finishReason: finishReason) else { return false }
        // Szenentrenner müssen erhalten bleiben (beide Prompts fordern es; verlorene
        // Trenner zerstören die Szenenwechsel im Export).
        let sourceSeparators = source.components(separatedBy: "***").count - 1
        let candidateSeparators = candidate.components(separatedBy: "***").count - 1
        if sourceSeparators > 0, candidateSeparators < sourceSeparators { return false }
        return true
    }
}

private extension Array where Element == AutonomousContentQuality.TensionAnchor {
    /// Erzwingt nicht-fallende Einsatz-Stufen bis zum Höhepunkt. Die Basis-Kurve
    /// steigt von selbst, aber erzwungene Anker-Sprünge (z. B. MIDPOINT auf ≥ 8)
    /// ließen das Folgekapitel wieder auf den Basiswert abfallen – genau das
    /// „Einsatz-Loch", das die Kurve verhindern soll. Nach dem Höhepunkt bleibt
    /// die AUFLÖSUNG bewusst unberührt (sie darf fallen).
    func reducingMonotonicity(untilChapter climax: Int) -> [Element] {
        var ergebnis: [Element] = []
        ergebnis.reserveCapacity(count)
        for anchor in self {
            if let vorher = ergebnis.last, anchor.kapitel <= climax,
               anchor.stufe < vorher.stufe {
                ergebnis.append(AutonomousContentQuality.TensionAnchor(
                    kapitel: anchor.kapitel, stufe: vorher.stufe, marke: anchor.marke))
            } else {
                ergebnis.append(anchor)
            }
        }
        return ergebnis
    }
}
