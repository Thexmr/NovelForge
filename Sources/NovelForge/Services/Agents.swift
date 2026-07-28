import Foundation

/// Namen der spezialisierten Agenten – erscheinen im Agenten-Monitor und im Protokoll.
enum AgentName {
    static let input = "Input Agent"
    static let research = "Research Agent"
    static let concept = "Concept Agent"
    static let plot = "Plot Architect"
    static let character = "Character Architect"
    static let chapterPlanner = "Chapter Planner"
    static let scenePlanner = "Scene Planner"
    static let draftWriter = "Draft Writer"
    static let summarizer = "Context Summarizer"
    static let reviser = "Chapter Reviser"
    static let consistency = "Consistency Checker"
    static let proofreader = "Proofreader"
    static let repairEditor = "Repair Editor"
    static let copyright = "Copyright Checker"
    static let kdpFormatter = "KDP Formatter"
    static let exporter = "Export Agent"
    static let coverDesigner = "Cover Designer"
    static let publisher = "Publishing Lead"
}

// MARK: - Prompt-Vorlagen
// Alle Prompts arbeiten mit reinen Strings (keine SwiftData-Objekte),
// damit sie threadsicher außerhalb des MainActors verwendet werden können.

enum PromptFactory {

    static func authorBioSuggestions(authorName: String, facts: String,
                                     genre: String, language: String) -> String {
        let provided = facts.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Formuliere 3 professionelle Kurzbiografien für die KDP-Autorenseite und das Buch.
        Name/Pseudonym: \(authorName)
        Buchbereich: \(genre)
        Sprache: \(language)
        Vom Autor tatsächlich angegebene Informationen:
        \(provided.isEmpty ? "Keine biografischen Fakten angegeben." : provided)

        VERBINDLICH: Erfinde niemals Beruf, Ausbildung, Titel, Auszeichnungen, Verkaufserfolge,
        Wohnort, Familie, Erfahrung, Qualifikation oder persönliche Geschichte. Nutze ausschließlich
        die angegebenen Fakten. Fehlen Fakten, formuliere eine kurze neutrale Markenbio über Themen,
        Perspektive und Art der Bücher, ohne Tatsachen über die Person zu erfinden.
        Jede Variante 45–90 Wörter, dritte Person, glaubwürdig und ohne Werbeübertreibung.

        Gib exakt drei einzelne Zeilen aus:
        BIO|[Variante 1]
        BIO|[Variante 2]
        BIO|[Variante 3]
        """
    }

    /// Kommerziell vielversprechende Buchideen. `authorSeed` ist eine optionale
    /// eigene Idee des Autors, die zu einer vollwertigen Buchidee ausgebaut wird.
    /// Generiert 10 virale Titel-Kandidaten (grounded in der Story) + die stärkste Wahl.
    /// Liefert klare, neugierig machende Kauf-Titel statt schwacher oder kryptischer.
    static func viralTitles(genre: String, premise: String, language: String, count: Int = 10) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionTitles(genre: genre, premise: premise, language: language, count: count)
        }
        return """
        Erfinde \(count) extrem starke, klickstarke Titel für diesen Roman (Genre: \(genre), Sprache: \(language)) – Titel, die im Amazon-Suchergebnis sofort Neugier wecken und zum Kauf treiben.

        Worum es geht:
        \(premise.truncated(to: 1500))

        WAS EINEN VIRALEN TITEL AUSMACHT:
        - Neugier-Lücke: ein angedeutetes Geheimnis, eine Drohung, eine Frage, ein Tabu – der Leser MUSS wissen, was dahintersteckt.
        - Emotion und Einsatz sofort spürbar (Verrat, verbotene Liebe, Gefahr, Verlust, Rache).
        - POLARISIEREN: Der Titel muss eine SOFORTIGE emotionale Reaktion auslösen – Empörung, Tabu-Reiz, moralisches Dilemma, eine Anschuldigung oder ein gefährliches Versprechen. Ein Titel, zu dem jeder eine Meinung hat, wird geklickt; ein netter, gefälliger Titel wird überscrollt. Mut zur Kante: „Ich habe seinen Bruder geliebt" schlägt „Eine schwierige Liebe".
        - Konkret und bildhaft, nicht abstrakt oder verkopft. Kurz: 2-6 Wörter, im Thumbnail sofort lesbar. Nur Alltagswörter, die jeder kennt.
        - Genre-Signal: der Titel fühlt sich nach \(genre) an.
        - Direkte Ansprache (du/dich/mein/dein) erzeugt Nähe und Sofort-Spannung.
        Starke Bauarten (mischen): Bevor/Wenn/Warum/Was ...; Das Mädchen, das ...; eine Drohung oder ein Versprechen als Satz; ein Geständnis oder eine Anschuldigung in der Ich-/Du-Form; ein aufgeladenes konkretes Objekt; eine Negation (Niemand ..., Kein ...); ein Name plus Einsatz.

        STRENG VERBOTEN: Genre-Wörter als Titel (Liebesroman, Erotik-Roman, Thriller); Platzhalter (Titel); kryptische Wort-Collagen oder Nonsens (z. B. Schluckauf im Erdboden); Berufs-/Ort-Klischees (Die [Beruf] von [Ort]); mehr als 6 Wörter; Tippfehler; alles, was auf zehn anderen Büchern stehen könnte.

        Antworte exakt in diesem Format:
        KANDIDATEN:
        1) ...
        \(count)) ...
        BESTER: [exakt einer der Kandidaten oben – der mit dem stärksten Kauf-Sog]
        """
    }

    static func bookIdeas(genre: String, language: String, avoidanceBrief: String = "",
                          authorSeed: String = "") -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionIdeas(genre: genre, language: language,
                                   avoidanceBrief: avoidanceBrief, authorSeed: authorSeed)
        }
        let memoryBlock = avoidanceBrief.isEmpty ? "" : "\n\(avoidanceBrief)\n"
        let seed = authorSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        let seedBlock = seed.isEmpty ? "" : """

        AUTOREN-IDEE (verbindlicher Ausgangspunkt): Der Autor gibt diese Idee vor – baue sie zu einer \
        vollwertigen Buchidee aus, bleib ihrem Kern treu, entwickle sie weiter statt sie zu ersetzen:
        „\(seed)"
        Mindestens eine der Ideen MUSS direkt auf dieser Vorgabe aufbauen.

        """
        return """
        Entwickle 5 eigenständige, kommerziell durchschlagende Buchideen \
        (Genre-Schwerpunkt: \(genre.isEmpty ? "frei wählbar" : genre), Sprache: \(language)). \
        Ziel sind Bücher, über die Leser online reden und die sie weiterempfehlen (BookTok/Amazon-Bestseller-Niveau) – \
        jede Idee braucht einen frischen, überraschenden Dreh und einen klaren zentralen Konflikt. \
        Keine Klischee-Plots, keine Nacherzählung bestehender Werke.
        \(seedBlock)\(memoryBlock)
        \(genreViralAngle(genre))

        GENRE ERNST NEHMEN (verbindlich): Liefere echte Genre-Ware, kein verkapptes Alltagsdrama.
        Die Geschichte darf NICHT um einen Beruf oder Arbeitsplatz als Hauptthema kreisen
        („eine Bäckerin/Imkerin/Kassiererin entdeckt ein Geheimnis" ist verboten – ein Beruf ist
        höchstens Kulisse, nie der Kern). Erfülle die Kernerwartung des Genres voll:
        bei Liebesroman/Erotik treiben Beziehung, Anziehung und Begehren die Handlung (mit
        spürbarer Hitze, wo das Genre es verlangt); bei Thriller/Krimi die Gefahr und das Rätsel;
        bei Fantasy/SciFi die fantastische Welt. Das Genre-Versprechen steht im Zentrum, nicht am Rand.

        KONZEPT-PFLICHT (was ein Buch viral macht): Jede Idee braucht
        – einen High-Concept-Hook, der sich in EINEM Satz erzählen lässt und sofort neugierig macht ("Was wäre, wenn …"),
        – eine sofort verständliche Zielgruppe und ein starkes emotionales Versprechen,
        – eine konkrete Kernwunde der Hauptfigur und einen Einsatz, bei dem viel zu verlieren ist,
        – eine Eskalation mit Wendung, die man nicht kommen sieht.

        TITEL-PFLICHT – EXTREM stark und viral, aber NIE komisch oder kryptisch (die besten Bestseller-Titel sind BEIDES zugleich: magnetisch UND sofort verständlich):
        – VIRAL & DAUMEN-STOPPEND: Der Titel stoppt beim Scrollen sofort, macht augenblicklich süchtig auf die Geschichte und ist BookTok-würdig (man will ihn aussprechen und weiterempfehlen). Starkes emotionales Versprechen, hohe Aufladung, sofortiger Klick-Sog – ziel auf die Wucht echter Verkaufsschlager. Brave, schwache, austauschbare Titel sind verboten.
        – POLARISIEREND: Der Titel provoziert eine sofortige Reaktion (Tabu-Reiz, Anschuldigung, moralisches Dilemma, gefährliches Versprechen) – jeder, der ihn liest, hat SOFORT ein Gefühl dazu. Mut zur Kante schlägt Gefälligkeit.
        – ZUGLEICH KLAR & NATÜRLICH: idiomatisches Deutsch, beim ersten Lesen sofort verständlich, genre-richtig. „Viral" heißt NICHT rätselhaft, sondern ein echtes Gefühl/Versprechen in klare, einprägsame Worte fassen. 2–6 Wörter bevorzugt (aktive Sätze dürfen länger), kein erklärender Nebensatz, kein Gedankenstrich.
        – AMAZON-KDP-MARKTFIT: im Amazon-KDP-Suchergebnis und als kleines Thumbnail sofort lesbar, klickbar und genre-richtig.
        – STRENG VERBOTEN, weil es „komisch"/künstlich klingt: kryptische, prätentiöse oder rätselhafte Titel; synästhetische oder paradoxe Wort-Collagen („Salz im Stromnetz", „Die Farbe deiner Stimme"); Wörter, die zusammen keinen Sinn ergeben; gewollt „literarische" Bilder, die kein echter Leser als Buchtitel sucht oder beim ersten Lesen versteht.
        – EBENFALLS VERBOTEN: Berufs-Ort-Klischee („Die Kassiererin von X"), Berufs-Genitiv („Das Schweigen der Imkerin", „Die Tochter des …"), blasse Einzelwörter („Feuerprobe", „Schicksal", „Neuanfang"), brave Allerwelts-Sätze ohne Sog.
        – STÄRKSTE, NATÜRLICHE BAUARTEN (je Idee eine andere, ALLE eingängig UND magnetisch): eine provokante Aussage/Drohung/ein Versprechen mit echtem Einsatz; eine Du-/Ich-Anrede, die den Leser direkt trifft; eine zugespitzte Frage; ein konkretes, aufgeladenes Bild aus der Welt der Geschichte; eine emotional gespannte Situation, die man sofort versteht. Konkret und klar – nicht abstrakt verrätselt.
        – HÄRTETEST (BEIDES muss stimmen): 1) Würde ein Leser beim Scrollen sofort klicken? 2) Versteht er den Titel beim ersten Lesen, und würde ein echter Verlag ihn so aufs Cover drucken? Nur wenn BEIDES ja ist, behalten. Kein Titel darf austauschbar auf zehn anderen Büchern des Genres stehen. Jeder der 5 Titel klingt anders – alle natürlich UND extrem zugkräftig.
        – NUR MUSTER, NICHT KOPIEREN: Übernimm KEINEN der Beispieltitel oben und keines ihrer markanten Wörter. Jeder Titel entsteht FRISCH aus DEINER eigenen Prämisse.

        Gib für JEDE Idee GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        IDEE|Titel|Genre|Prämisse in 2 Sätzen – Satz 1 ist der High-Concept-Hook, Satz 2 nennt Konflikt und Einsatz

        Keine weiteren Erklärungen.
        """
    }

    private static func nonfictionTitles(genre: String, premise: String, language: String,
                                         count: Int) -> String {
        """
        Entwickle \(count) professionelle Amazon-KDP-Titel für ein \(genre) auf \(language).

        Inhalt und Nutzen:
        \(premise.truncated(to: 1500))

        Der Haupttitel ist kurz, konkret und glaubwürdig. Er benennt Problem, Methode oder erwünschte
        Veränderung, ohne Clickbait. Ein Untertitel darf Zielgruppe und konkreten Nutzen erklären.
        Verboten: Erfolgsgarantien, Heilungs- oder Einkommensversprechen, erfundene Superlative,
        "Bestseller", "garantiert", "mühelos", "für immer" und nicht belegbare Zahlenversprechen.

        Antworte exakt in diesem Format:
        KANDIDATEN:
        1) ...
        \(count)) ...
        BESTER: [exakt einer der Kandidaten]
        """
    }

    private static func nonfictionIdeas(genre: String, language: String,
                                        avoidanceBrief: String, authorSeed: String) -> String {
        let seed = authorSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        let seedBlock = seed.isEmpty ? "" : "\nAUTOREN-IDEE (verbindlich): \(seed)\n"
        let memoryBlock = avoidanceBrief.isEmpty ? "" : "\n\(avoidanceBrief)\n"
        return """
        Entwickle 5 eigenständige, praktisch wertvolle Ideen für \(genre) auf \(language).
        \(seedBlock)\(memoryBlock)

        QUALITÄTSVERTRAG:
        - LESERPROBLEM: ein konkretes, relevantes Problem einer klar benannten Zielgruppe.
        - NUTZENVERSPRECHEN: eine realistische Veränderung, die das Buch Schritt für Schritt ermöglicht.
        - DIFFERENZIERUNG: ein nachvollziehbarer Blickwinkel oder eine bessere praktische Methode,
          keine bloße Zusammenstellung bekannter Allgemeinplätze.
        - UMSETZUNG: Beispiele, Checklisten, Übungen und nächste Schritte müssen möglich sein.
        - Keine erfundenen Fakten, Studien, Statistiken, Quellen, Zitate oder Fachleute.
        - Keine Heilungs-, Erfolgs- oder Einkommensgarantien und kein irreführender Clickbait.
        \(NonfictionSafety.directive(genre: genre, premise: seed))

        Titel sind klar, glaubwürdig und suchnah. Jede Idee unterscheidet sich deutlich von den
        gespeicherten Büchern in Thema, Zielgruppe, Methode und Nutzen.

        Gib für JEDE Idee GENAU eine Zeile aus:
        IDEE|Titel|Genre|LESERPROBLEM: ... NUTZENVERSPRECHEN: ... METHODE: ...

        Keine weiteren Erklärungen.
        """
    }

    /// Genre-spezifischer "viraler Winkel": welches Thema/welcher Trope in diesem Genre
    /// Mundpropaganda und KDP-Verkäufe treibt, plus der passende Titel-Klang mit
    /// originellen Beispieltiteln (NICHT abgeschrieben, NICHT die verbotenen Berufs-Klischees).
    /// Bewusst getrennt von `genreCraft` (das die Prosa beim Schreiben steuert).
    static func genreViralAngle(_ genre: String) -> String {
        let g = genre.lowercased()
        // VIRAL HIT ist kein Genre, sondern eine Arbeitsweise: das Konzept wird gezielt
        // auf die Mechanik gebaut, die Bücher auf BookTok groß macht. Recherchierte
        // Treiber: eine starke Gefühlsreaktion (weinen, mitfiebern, empört sein), ein
        // Titel, der sich selbst verkauft, und ein Haken, den man in einem Satz
        // weitererzählen kann. Genre-Etikett wählt das Modell passend zur Idee.
        if g.contains("viral") {
            return """
            VIRALES THEMA (Viral Hit): Das Buch ist auf WEITERERZÄHLBARKEIT gebaut. Prüfe jede Idee an drei Fragen:
            1) Löst sie eine starke Gefühlsreaktion aus, über die Leser reden – Tränen, Wut, Fassungslosigkeit, Sehnsucht?
            2) Lässt sich die Prämisse in EINEM Satz erzählen, den jemand seiner Freundin weitersagt?
            3) Gibt es einen Moment, den man zitiert oder markiert – eine Wendung, ein Geständnis, einen letzten Satz?
            Wähle selbst das passende Genre-Etikett (Dark Romance, Psychothriller, Romantasy, Domestic Suspense …)
            und liefere es im Feld GENRE mit. Setze auf ein aktuelles, aufgeladenes Thema mit klarer Zielgruppe:
            verbotene Nähe, Rache mit Preis, ein Geheimnis zwischen zwei Menschen, eine Schuld, die zurückkommt.
            TITEL-KLANG: ein Satz, den man aussprechen und weitersagen will – Anrede, Versprechen oder Anschuldigung.
            Beispiele für die Stoßrichtung (nicht übernehmen):
            "Ich hätte dich gehen lassen sollen" · "Sag es niemandem, Anna" · "Du schuldest mir ein Leben" · "Er wusste, dass ich lüge".
            """
        }
        if g.contains("thriller") || g.contains("krimi") {
            return """
            VIRALES THEMA (Thriller/Krimi): Ein "Was wäre, wenn"-Albtraum mitten im Alltag, eine tickende Uhr,
            eine unzuverlässige Erzählerin und ein Mittelteil-Twist, der alles davor neu deutet. Der Hook muss
            den Leser zwingen, die Auflösung wissen zu wollen.
            TITEL-KLANG: knapp, bedrohlich, mit Sog. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Sag, dass du mich nicht siehst" · "Die letzten vierzig Sekunden" · "Zähl nicht bis zehn" · "Du warst nie allein im Haus".
            """
        }
        if g.contains("erotik") || g.contains("erotic") || g.contains("dark romance") || g.contains("spicy") {
            return """
            VIRALES THEMA (Erotik/Dark Romance): Eine verbotene, aufgeladene Dynamik (Boss, Bodyguard, Rivale,
            gefährlicher Beschützer), ein morally-grey, possessiver – aber stets einvernehmlicher – Love Interest,
            Slow Burn mit knisternder Nähe bis zur Eskalation, hohe Hitze und ein Tabu, das man umblättern muss.
            TITEL-KLANG: verlangend, herausfordernd, mit Spannung. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Berühr mich, wenn du dich traust" · "Der Vertrag, den niemand lesen sollte" · "Gehörst du mir bis Mitternacht" · "Spiel nicht mit dem Feuer, das du gelegt hast".
            """
        }
        if g.contains("liebes") || g.contains("romance") {
            return """
            VIRALES THEMA (Liebesroman): Ein sofort erkennbarer Trope-Hook (Enemies-to-Lovers, verbotene Liebe,
            Second Chance, Fake-Beziehung, nur-ein-Bett, grummelig/sonnig), unwiderstehliche Chemie und ein klares
            "Warum dürfen sie nicht?"-Hindernis. BookTok lebt vom Trope plus dem Gefühl, das man weitererzählt.
            TITEL-KLANG: warm, sehnsüchtig, mit einem Funken Widerstand. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Vielleicht im nächsten Sommer" · "Tausend Gründe gegen dich" · "Nur dieses eine Mal nicht" · "Bis du mich ansiehst".
            """
        }
        if g.contains("fantasy") || g.contains("science") || g.contains("sci-fi") || g.contains("dystop") || g.contains("romantasy") || g.contains("steampunk") || g.contains("märchen") {
            return """
            VIRALES THEMA (Fantasy/SciFi): Ein in EINEM Satz fassbares, originelles Welt- oder Magie-Konzept,
            eine regelbrechende Heldin und eine Welt am Abgrund. Die stärkste Verkaufskombination ist Romantasy
            (große Romanze IN der fantastischen Welt) – Sehnsucht und Hochspannung gleichzeitig.
            TITEL-KLANG: mythisch, bildstark, neugierig machend. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Die Stadt, die nur nachts existiert" · "Wer den Sturm ruft" · "Was die Götter vergaßen" · "Sterben lernt man zweimal".
            """
        }
        if g.contains("horror") {
            return """
            VIRALES THEMA (Horror): Eine archaische Urangst, ganz konkret gemacht, ein isolierter Ort, eine
            Falschheit, die langsam eskaliert, und ein persönlicher Einsatz. Der Hook ist ein Bild, das man
            nicht mehr loswird.
            TITEL-KLANG: beklemmend, körperlich, mit Drohung. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Es atmet, wenn du schläfst" · "Das Haus zählt mit" · "Niemand verlässt Talgrund" · "Was unter dem Eis wartet".
            """
        }
        if g.contains("histor") {
            return """
            VIRALES THEMA (Historischer Roman): Ein reales dramatisches Ereignis, erzählt durch ein intimes,
            persönliches Schicksal, ein Geheimnis, das bis heute nachhallt, und eine verbotene Bindung gegen die
            Regeln der Epoche. Große Geschichte, an einem Herzschlag festgemacht.
            TITEL-KLANG: atmosphärisch, schicksalhaft, mit Ort/Epoche aufgeladen. Beispiele für die Stoßrichtung (nicht übernehmen):
            "Was Asche nicht verbrennt" · "Der letzte Zug aus Königsberg" · "Im Schatten der Kathedrale" · "Wir nannten es Heimat".
            """
        }
        return """
        VIRALES THEMA: Eine universelle emotionale Wunde, hochkonzeptionell zugespitzt und teilbar – eine Frage,
        die man weitererzählen will. Vertrautes Gefühl, überraschender Dreh.
        TITEL-KLANG: kurz, bildstark, anziehend. Beispiele für die Stoßrichtung (nicht übernehmen):
        "Was bleibt, wenn alle gehen" · "Die zweite Hälfte von uns" · "Hundert Namen für Schweigen" · "Bevor das Licht ausgeht".
        """
    }

    /// Analysiert den vom Autor gewählten Titel UND das Genre und leitet eine verbindliche,
    /// auf genau dieses Buch zugeschnittene Genre-Direktive ab. Diese steuert anschließend
    /// Konzept, Plot, Kapitelplan und jede Szene – damit das Buch zweifelsfrei im Genre landet.
    static func genreBrief(title: String, genre: String, subgenre: String?,
                           tropes: String = "", spiceLevel: Int = 0, language: String) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionBrief(title: title, genre: genre, subgenre: subgenre, language: language)
        }
        var genreLine = genre
        if let subgenre, !subgenre.isEmpty { genreLine += " / \(subgenre)" }
        let t = tropes.trimmingCharacters(in: .whitespacesAndNewlines)
        let tropesLine = t.isEmpty ? "" : "\nVom Autor gewünschte Tropes: \(t)"
        let spiceLine = spiceLevel > 0 ? "\nSinnlichkeitsgrad: \(spiceLevel)/5 (\(SpiceLevel.label(spiceLevel)))" : ""
        return """
        Der Autor hat Titel und Genre fest vorgegeben – beides ist UNVERÄNDERLICH:
        TITEL: „\(title)"
        GENRE: \(genreLine)
        Sprache: \(language)\(tropesLine)\(spiceLine)

        Analysiere TITEL und GENRE gemeinsam und leite die VERBINDLICHEN, auf genau dieses Buch
        zugeschnittenen Schreibvorgaben ab, damit der Roman zweifelsfrei im Genre „\(genreLine)" landet
        und das Versprechen des Titels „\(title)" einlöst. Sei konkret und spezifisch für diesen Titel,
        nicht allgemein. Jede Zeile knapp.

        Gib AUSSCHLIESSLICH diese Direktive aus (Labels exakt so):
        KERNVERSPRECHEN: [die eine Erwartung, die ein Leser dieses Genres bei diesem Titel garantiert erfüllt sehen will]
        TON & STIMMUNG: [3-5 Stichworte]
        PFLICHT-TROPES: [3-5 konkrete, genre-typische Tropes, die wirklich geliefert werden müssen]
        PFLICHT-SZENEN: [3-5 genre-typische Schlüsselmomente, die im Buch vorkommen müssen]
        TEMPO & STRUKTUR: [wie sich dieses Genre erzählt – Tempo, Kapitelenden, Eskalation]
        SINNLICHKEIT: [bei Liebes-/Romance-Genres konkret: wie Anziehung und Begehren über das Buch eskalieren und welche Nähe-/Spice-Stufe gelebt wird; sonst kurz]
        TITEL-EINLÖSUNG: [wie genau der Titel „\(title)" in der Handlung erzählerisch eingelöst und am Ende beantwortet wird]
        GENRE-ABDRIFT VERBOTEN: [die 2-3 typischsten Wege, dieses Genre zu verfehlen – hier konkret untersagen; z. B. bei Romance: kein Ermittlungs-/Psychothriller-Plot als Hauptlinie, keine kühle Beziehung ohne spürbare Anziehung]
        VERGLEICHSTITEL: [2-3 „Für Fans von …"]
        """
    }

    /// Formatiert die Genre-Direktive als verbindlichen Block für die nachgelagerten Prompts.
    static func genreDirectiveBlock(_ brief: String) -> String {
        let t = brief.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "" : """

        GENRE-DIREKTIVE (verbindlich, aus Titel + Genre abgeleitet – das GANZE Buch hält sich strikt daran, Figuren, Konflikt und jede Szene erfüllen sie):
        \(t)

        """
    }

    /// Verbindliche Urheberrechts-Direktive: stellt Eigenständigkeit sicher (kein fremdes Werk).
    static let copyrightDirective = """
    EIGENSTÄNDIGKEIT (verbindlich, Urheberrecht): Erfinde ALLE Figuren, Namen, Orte, Welten, Organisationen und Titel selbst. Übernimm KEINE Figuren, Schauplätze, Magie-/Weltensysteme oder Handlungsstränge aus existierenden Werken (z. B. Harry Potter/Hogwarts, Herr der Ringe, Game of Thrones, Twilight, Fifty Shades, Bridgerton). Zitiere NIEMALS reale Songtexte, Gedichte oder geschützte Passagen. Keine realen, identifizierbaren Personen in erfundenen ehrenrührigen Handlungen. Markennamen höchstens beiläufig, keine Slogans/Logos/Werbetexte.
    """

    static func concept(title: String, genre: String, subgenre: String?, language: String,
                        style: String, tonality: String, audience: String,
                        perspective: String, tense: String, pageCount: Int,
                        ideaSeed: String, tropes: String = "", bookSignature: String = "",
                        sequelContext: String = "", genreBrief: String = "",
                        researchContext: String = "") -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionConcept(title: title, genre: genre, subgenre: subgenre,
                                     language: language, style: style, tonality: tonality,
                                     audience: audience, pageCount: pageCount, ideaSeed: ideaSeed,
                                     researchContext: researchContext)
        }
        var genreLine = genre
        if let subgenre, !subgenre.isEmpty {
            genreLine += " / \(subgenre)"
        }
        var seedBlock = ""
        if !ideaSeed.isEmpty {
            seedBlock = "\nIDEENKERN (verbindlicher Ausgangspunkt, weiterentwickeln statt ersetzen):\n\(ideaSeed)\n"
        }
        var tropeBlock = ""
        let trimmedTropes = tropes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTropes.isEmpty {
            tropeBlock = "\nTROPE-VERTRAG (VERBINDLICH – die Zielgruppe kauft genau diese Tropes; liefere sie deutlich und befriedigend über den ganzen Bogen, nicht nur angedeutet, und verankere sie in Prämisse, Hauptkonflikt und Wendepunkten):\n\(trimmedTropes)\n"
        }
        let trimmedSignature = bookSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        let signatureBlock = trimmedSignature.isEmpty ? "" : "\n\(trimmedSignature)\n"
        let trimmedSequel = sequelContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSequel = !trimmedSequel.isEmpty
        let openingLine = isSequel
            ? "Entwickle das Konzept für den NÄCHSTEN BAND dieser Reihe (Fortsetzung, kein eigenständiger Neustart)."
            : "Entwickle ein eigenständiges Buchkonzept (keine Nachahmung geschützter Werke)."
        let sequelBlock = isSequel ? "\nSERIE / FOLGEBAND (VERBINDLICH): Führe die bestehende Reihe konsequent weiter. Behalte die wiederkehrenden Figuren (gleiche Namen, Eigenschaften, Beziehungen) und die etablierte Welt bei, entwickle sie weiter, greife offene Fäden auf und erhöhe den Einsatz. Eröffne einen neuen, in sich abgeschlossenen Hauptkonflikt für GENAU DIESEN Band – kein Wiedererzählen des Vorbands. Bisheriger Verlauf der Reihe:\n\(trimmedSequel)\n" : ""
        return """
        \(openingLine)\(sequelBlock)
        \(seedBlock)
        Titel: \(title)
        Genre: \(genreLine)
        Sprache des Buches: \(language)
        Stilprofil: \(style)
        Tonalität: \(tonality)
        Zielgruppe: \(audience)
        Erzählperspektive: \(perspective), Zeitform: \(tense)
        Zielumfang: ca. \(pageCount) Seiten
        \(tropeBlock)\(signatureBlock)
        VERBINDLICH: Titel und Genre sind fest vorgegeben (vom Autor gewählt). Entwickle das Konzept so, \
        dass es exakt zum Titel „\(title)" und zum Genre „\(genreLine)" passt und den Titel erzählerisch \
        einlöst – er soll nach der Lektüre sinnfällig und treffend wirken. Ändere oder ersetze den \
        Titel NICHT und weiche nicht ins Genre-Fremde ab. Diese Bindung gilt für das GANZE Buch: jede \
        Hauptfigur, der zentrale Konflikt und jede Szene erfüllen das Genre „\(genreLine)" und zahlen auf \
        das Titel-Versprechen ein – der fertige Roman liefert genau das, was Titel und Genre versprechen, \
        sonst fühlt sich der Leser betrogen.
        \(genreDirectiveBlock(genreBrief))
        \(copyrightDirective)
        \(genreCraft(genre))
        Nimm das Genre ernst: Die Kernerwartung des Genres steht im Zentrum der Handlung. Die \
        Geschichte kreist NICHT um einen Beruf/Arbeitsplatz als Hauptthema; ein Beruf ist höchstens \
        Kulisse. Bei Liebesroman/Erotik treiben Beziehung und Begehren den Plot (mit der Hitze, die \
        das Genre verlangt), nicht ein nebenbei erzähltes Alltagsleben.
        \(romanceGenreContract(genre))

        BESTSELLER-KERN (verbindlich):
        - HIGH CONCEPT: Die Prämisse ist zugespitzt und einzigartig, in EINEM Satz fassbar und sofort neugierig machend – NICHT generisch („Frau kehrt heim und findet Geheimnisse" ist verboten). Was ist das Besondere an genau DIESER Figur, DIESEM Konflikt, DIESEM Einsatz?
        - TITEL EINLÖSEN: Die Prämisse macht das Versprechen des Titels „\(title)" zur TREIBENDEN Kraft der Handlung, nicht nur zur Stimmung. Verspricht der Titel eine Liebes-/Beziehungsfrage, ist genau diese der Motor des Plots und wird am Ende konkret beantwortet.
        - GENRE LIEFERN, nicht nur behaupten: Die Kern-Dynamik des Genres steht konkret in Szenen. Bei (Dark) Romance / Slow Burn: spürbare, von Kapitel zu Kapitel eskalierende Anziehung mit klaren Teasern, Beinahe-Momenten und einer Auszahlung – kein „No Burn". Bei „dark": ein gefährlicher, fordernder, ambivalenter Gegenpart und ein spürbares Machtgefälle, keine bloße Melancholie.
        - AKTIVE HAUPTFIGUR (Agency): Die Hauptfigur TREIBT die Handlung durch eigene Entscheidungen mit Konsequenzen; sie reagiert nicht nur passiv, sondern riskiert etwas, macht Fehler und verändert sich sichtbar.
        - STARKER GEGENPART: Antagonist bzw. Love Interest ist scharf gezeichnet, präsent und erzeugt echte, spürbare Chemie und Reibung – kein vager „Nebel".

        Antworte ausschließlich in diesem Format (Labels exakt so verwenden):
        PRÄMISSE: [1-2 Sätze]
        LOGLINE: [Ein Satz]
        EXPOSÉ: [5-8 Sätze, die den kompletten Handlungsbogen umreißen]
        HAUPTKONFLIKT: [1-2 Sätze]
        THEMA: [1-3 Wörter]
        ZIELGRUPPE: [Kurze Beschreibung]
        """
    }

    static func plot(title: String, genre: String, style: String, concept: String,
                     pageCount: Int, chapterCount: Int, bookSignature: String = "",
                     sequelContext: String = "", genreBrief: String = "",
                     researchContext: String = "") -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionArchitecture(title: title, genre: genre, style: style,
                                          concept: concept, pageCount: pageCount,
                                          chapterCount: chapterCount, genreBrief: genreBrief,
                                          researchContext: researchContext)
        }
        let trimmedSignature = bookSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        let signatureBlock = trimmedSignature.isEmpty ? "" : """

        \(trimmedSignature)
        Ordne die folgenden dramaturgischen Beats DIESER Erzählstruktur unter: Die Beats bleiben das kausale Gerüst, ihre Anordnung und Präsentation folgen der Stil-DNA (z.B. nichtlinear, Rahmenerzählung, parallele Stränge), niemals einer Standardschablone.

        """
        let trimmedSequel = sequelContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let sequelLine = trimmedSequel.isEmpty ? "" : "\nSERIE / FOLGEBAND: Dies ist eine FORTSETZUNG. Dieselben Figuren und dieselbe Welt wie im Vorband; knüpfe an dessen Ausgang an und führe offene Fäden weiter. Baue dennoch einen eigenen, in sich abgeschlossenen Spannungsbogen für DIESEN Band.\n"
        return """
        Erstelle den vollständigen Plot für den Roman "\(title)".
        Genre: \(genre) | Stil: \(style) | Umfang: ca. \(pageCount) Seiten in \(chapterCount) Kapiteln.

        Konzept:
        \(concept)
        \(signatureBlock)\(sequelLine)
        \(genreDirectiveBlock(genreBrief))
        Entwickle einen kausalen, genresicheren Spannungsbogen, dessen konkrete Architektur der
        STIL-DNA dieses Buches folgt. Verwende die folgenden Funktionen, aber NICHT als starre
        Drei-Akt- oder Prozentschablone und nicht immer in derselben sichtbaren Reihenfolge:
        - eine frühe Störung, die das zentrale Versprechen aktiviert
        - mindestens eine irreversible Entscheidung der Hauptfigur
        - Komplikationen, die aus vorherigen Entscheidungen entstehen
        - eine Erkenntnis oder Umkehr, die Ziel oder Bedeutung verändert
        - einen Preis, den die Hauptfigur nicht umgehen kann
        - eine finale Entscheidung, Konfrontation oder Enthüllung
        - eine genre- und figurenbezogene Auszahlung mit angemessenem Nachklang

        Lage, Anzahl und Abstand dieser Funktionen variieren nach Strukturmodell, Genre und Stimme.
        Nichtlineare, parallele, Mosaik-, Countdown- oder Rahmenstrukturen müssen auf der Seite
        tatsächlich anders funktionieren und dürfen nicht bloß eine umbenannte Drei-Akt-Fassung sein.

        Zusätzlich:
        - Formuliere die zentrale dramatische Frage in einem Satz.
        - Webe mindestens eine Nebenhandlung ein, die den Hauptplot am Ende verstärkt.
        - Platziere offene Fragen (Open Loops), die erst spät beantwortet werden – sie halten den Leser im Buch.
        - Jede Figur trifft Entscheidungen unter Druck; keine passiven Zufälle als Plotmotor.
        - Plane Kapitelenden so, dass Neugier, Sorge oder Erwartung offen bleiben.
        - HANDLUNGSDICHTE & TEMPO: In regelmäßigen Abständen (etwa alle 1-2 Kapitel) eine echte Wendung, Enthüllung oder Eskalation – keine langen Strecken ohne Fortschritt. Das Erzähltempo wechselt mit dem Geschehen (treibend in Zuspitzungen, ruhiger in Wendepausen). Atmosphäre dient der Handlung, ersetzt sie nie.
        - Der Umfang muss tragfähig für den Zielumfang sein: keine Kurzgeschichten-Struktur für lange KDP-Romane.

        Schreibe als zusammenhängenden, klar gegliederten Text.
        """
    }

    static func characters(title: String, genre: String, plot: String, concept: String = "",
                           sequelContext: String = "") -> String {
        let trimmedSequel = sequelContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let sequelBlock = trimmedSequel.isEmpty ? "" : "\nSERIE / FOLGEBAND (VERBINDLICH): Übernimm die wiederkehrenden Figuren der Reihe UNVERÄNDERT (gleiche Namen, Rollen, Eigenschaften) und führe sie als erste Einträge auf; ergänze nur neue Figuren, die DIESER Band zusätzlich braucht. Wiederkehrende Figuren der Reihe:\n\(trimmedSequel)\n"
        return """
        Entwickle das Figurenensemble für den Roman "\(title)" (Genre: \(genre)).
        \(copyrightDirective)
        \(sequelBlock)
        Plot:
        \(plot.truncated(to: 4000))

        VERBINDLICHER BUCHKANON:
        \(concept.truncated(to: 3500))

        Erstelle den Protagonisten, den Antagonisten und 3-5 wichtige Nebenfiguren.
        Gib für JEDE Figur GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        FIGUR|Name|Rolle|Alter|Beruf|Ziel|Angst|Schwäche|Sprechweise|Markantes Äußeres|Beziehungen|Kanonische Fakten

        Sprechweise = 1 kurzer Marker, der die Figur im Dialog UNVERWECHSELBAR macht \
        (Satzlänge, Lieblingsausdruck, was sie nie sagen würde) – jede Figur klingt anders. \
        Markantes Äußeres = 2-3 unveränderliche Merkmale (bleiben das ganze Buch kanonisch).
        Beziehungen = konkrete Verwandtschaft und Beziehung zu allen zentralen Figuren. Kanonische
        Fakten = nur unveränderliche, handlungsrelevante Tatsachen aus Buchkanon und Plot, besonders
        Besitz, Tod/Leben, Herkunft und frühere Ereignisse. Erfinde hier KEINE Alternative zum Kanon.

        Danach darfst du zu jeder Figur 2-3 Sätze Hintergrund ergänzen.
        """
    }

    static func chapterPlan(title: String, genre: String, plot: String,
                            chapterCount: Int, wordsPerChapter: Int,
                            scenesPerChapter: Int = 4, bookSignature: String = "",
                            genreBrief: String = "", canonicalStory: String = "") -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionChapterPlan(title: title, genre: genre, architecture: plot,
                                         chapterCount: chapterCount, wordsPerChapter: wordsPerChapter,
                                         sectionsPerChapter: scenesPerChapter, genreBrief: genreBrief)
        }
        let trimmedSignature = bookSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        let signatureBlock = trimmedSignature.isEmpty ? "" : """

        \(trimmedSignature)
        Kapitelrhythmus, Abfolge und Architektur folgen dieser Stil-DNA – nicht einer wiederkehrenden Standardvorlage.

        """
        return """
        Plane die Kapitelstruktur für den Roman "\(title)" (Genre: \(genre)).
        Es sollen GENAU \(chapterCount) Kapitel mit je ca. \(wordsPerChapter) Wörtern sein.
        Plane so, dass jedes Kapitel später in mindestens \(scenesPerChapter) eigenständige Szenen zerlegt werden kann.
        Langform-Pflicht: Der Konflikt muss groß genug für alle \(chapterCount) Kapitel sein; keine Abkürzungen,
        keine summarischen Sprünge, kein Kurzgeschichtenbogen mit künstlicher Streckung.
        \(signatureBlock)
        \(genreDirectiveBlock(genreBrief))
        VERBINDLICHER BUCHKANON (steht über jeder kreativen Ergänzung):
        \(canonicalStory.truncated(to: 7000))

        Plot:
        \(plot.truncated(to: 6000))

        Regeln für Bestseller-Kapitelstruktur:
        - Die meisten Kapitel enden mit Vorwärtsbewegung oder einer offenen Erwartung. Nutze harte Cliffhanger nur an dramaturgisch passenden Stellen; ruhige emotionale Nachwirkungen und abgeschlossene Teilziele sind ausdrücklich erlaubt.
        - Variiere das Tempo: Auf intensive Kapitel folgt ein ruhigeres mit Charaktertiefe – nie zwei gleiche hintereinander.
        - Jedes Kapitel hat genau ein klares Ziel und treibt den Hauptplot messbar voran. Keine Füllkapitel.
        - KONTINUITÄT: Verwandtschaft, Besitz, Todesfälle, Vergangenheit, Berufe, Namen und Rollen aus
          dem Buchkanon niemals ändern oder durch neue Varianten ersetzen. Keine neue Schwester, Tante,
          kein neuer Onkel oder Erblasser, wenn der Kanon diese Beziehung nicht festlegt. Unklare Details
          offenlassen statt erfinden. Keine Genreverschiebung durch übernatürliche Elemente ohne Kanonbasis.
        - KAPITELTITEL kreativ, eigenständig, doppelbödig: jeder Titel ist ein BILD, ein VERSPRECHEN oder eine FRAGE, macht schon im Inhaltsverzeichnis neugierig und verrät NICHT, was passiert (kein Spoiler), klingt im Rückblick aber anders. STRENG VERBOTEN: „Kapitel N", „Teil N", Phasennamen (Aufbruch/Eskalation/Krise/Auflösung), Durchnummerierung und jedes über mehrere Kapitel wiederholte Titelwort. Mische die Bauarten über das Buch (konkretes geladenes Objekt, abgebrochener Halbsatz, Dialog-Echo mit Subtext, sinnliche Wahrnehmung, Paradox, offene Frage, Zeit/Countdown, Drohung/Versprechen); mindestens jeder dritte Titel zielt auf die Beziehungsebene. Kurz (2-6 Wörter), jeder Titel unverwechselbar anders.

        Gib für JEDES Kapitel GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        KAPITEL|Nummer|Titel|Ziel des Kapitels|Zentraler Konflikt|Emotionaler Schritt

        Emotionaler Schritt = wie sich der innere Zustand bzw. die Beziehung der Hauptfigur \
        in DIESEM Kapitel verändert (z. B. „Misstrauen kippt in erstes Vertrauen") – der \
        Gefühlsbogen entwickelt sich über das Buch stetig weiter, nie zwei Kapitel mit \
        demselben emotionalen Stand.

        Keine weiteren Erklärungen. Die Kapitel müssen den kompletten Plot von Anfang bis Auflösung abdecken.
        """
    }

    static func scenePlan(bookTitle: String, chapterNumber: Int, chapterTitle: String,
                          chapterGoal: String, chapterConflict: String,
                          perspective: String, plotContext: String, targetWords: Int,
                          scenesPerChapter: Int = 4, isFinalChapter: Bool = false,
                          canonicalStory: String = "") -> String {
        if plotContext.contains("SACHBUCH-ARCHITEKTUR") {
            return nonfictionSectionPlan(bookTitle: bookTitle, chapterNumber: chapterNumber,
                                         chapterTitle: chapterTitle, chapterGoal: chapterGoal,
                                         chapterChallenge: chapterConflict, architecture: plotContext,
                                         targetWords: targetWords, sectionCount: scenesPerChapter,
                                         isFinalChapter: isFinalChapter)
        }
        // Schlusskapitel: kein erzwungener Haken – die letzten Szenen gehören der Auszahlung.
        // (Vorher erzwang der Plan auch im Finale einen Cliffhanger → abrupte, unbefriedigende
        // Enden, der häufigste 1-Stern-Trigger.)
        // Haken-Typ rotiert deterministisch – sonst enden 40 Kapitel mit demselben Bauplan.
        let hookTypes = [
            "eine offene Frage, die der Leser SOFORT beantwortet haben will",
            "eine konkrete Bedrohung, die gerade sichtbar wird",
            "eine überraschende Enthüllung im letzten Moment",
            "eine Entscheidung, deren Ausgang NICHT mehr gezeigt wird"
        ]
        let endingNote = isFinalChapter
            ? """
              Dies ist das SCHLUSSKAPITEL des Buches: Baue die Szenen als Höhepunkt → Auflösung →
              emotionaler Nachklang. Die letzte Szene beantwortet die zentrale Frage des Buches und
              endet OHNE neuen Haken – reserviere mindestens die letzte Szene ganz für die Auszahlung.
              """
            : """
              Die LETZTE Szene des Kapitels muss mit einem starken Haken
              enden (Feld „Wendung am Szenenende" entsprechend zugespitzt) – der Leser darf das
              Buch am Kapitelende nicht weglegen können. Haken-Typ für dieses Kapitel:
              \(hookTypes[abs(chapterNumber) % hookTypes.count]).
              """
        return """
        Plane die Szenen für Kapitel \(chapterNumber) ("\(chapterTitle)") des Romans "\(bookTitle)".
        Kapitelziel: \(chapterGoal)
        Kapitelkonflikt: \(chapterConflict)
        Standard-Erzählperspektive: \(perspective)
        Gesamtumfang des Kapitels: ca. \(targetWords) Wörter.

        VERBINDLICHER BUCHKANON:
        \(canonicalStory.truncated(to: 6000))
        Jede Szene muss diesem Kanon entsprechen. Verwandtschaft, Besitz, Vergangenheit, Todesfälle,
        Namen und Rollen niemals abwandeln. Keine neue kanonische Tatsache erfinden, nur weil sie als
        dramatische Wendung bequem wäre.

        Plotkontext:
        \(plotContext.truncated(to: 3000))

        Plane mindestens \(scenesPerChapter) Szenen (bei Bedarf mehr, aber nicht weniger).
        Für 500-Seiten-Langform braucht jede Szene eine eigene dramatische Funktion:
        neues Ziel, neue Reibung, neue Information, veränderte Beziehung oder verschärfter Einsatz.
        KANON-GRENZE: Konkretisiere ausschließlich das vorgegebene Kapitelziel. Erfinde KEINE neue
        Vorgeschichte, Verwandtschaft, Schwangerschaft, Geburt, Todesursache, Todesort, Datumsfolge,
        Besitzurkunde, geheime Abstammung oder frühere Tat. Plane keine Briefe, Fotos, Tagebücher,
        Ultraschallbilder oder sonstigen Beweisstücke, die nicht bereits im Primärkanon genannt sind.
        Keine Geister-, Stalker-, Einbrecher-, Silhouetten- oder Verwesungsbilder, wenn das Genre sie
        nicht verlangt. Atmosphäre darf Spannung erzeugen, aber niemals das Genre in Horror oder
        Mystery verschieben. Keine scheinbar spektakuläre Wendung auf Kosten von Logik und Kanon.
        Jede Information im Feld „Wendung“ muss sich wörtlich aus Primärkanon, Kapitelziel oder
        Kapitelkonflikt begründen lassen. Bei Unsicherheit plane eine Entscheidung oder
        Beziehungsverschiebung statt einer neuen Tatsache.
        \(endingNote)

        Gib für JEDE Szene GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        SZENE|Nummer|Perspektive|Ort|Zeit|Ziel der Szene|Hindernis|Wendung am Szenenende

        Keine weiteren Erklärungen.
        """
    }

    /// Genre-spezifische Handwerksregeln auf Bestseller-Niveau.
    /// Synthese aus zwei Experten-Modulen (Stimme/Subtext + Lexik/Rhythmus).
    /// Bricht gezielt die statistischen und lexikalischen Muster, an denen
    /// KI-Detektoren maschinell erzeugte Prosa erkennen (Burstiness/Perplexität),
    /// OHNE die literarische Qualität oder Lesbarkeit zu senken.
    static var humanCraftRules: String {
        """
        MENSCHLICH SCHREIBEN – DAMIT ES NICHT NACH KI KLINGT (diese Regeln stehen über dem reinen Glattschreiben; erzähl die Szene trotzdem vollständig zu Ende und kommentiere sie nie):
        - ZEITGEMÄSSE, PROFESSIONELLE SPRACHE (KEIN historischer/mittelalterlicher Klang): Schreibe wie ein aktueller deutschsprachiger Bestseller von heute – klar, natürlich, gegenwärtig, sofort verständlich. STRENG VERBOTEN sind altertümliche oder geschwollene Wörter/Wendungen wie „alsbald", „ward", „fürwahr", „sodann", „dünkte", „Antlitz", „Gemach", „Maid", „Jüngling", „Weib" (für Frau), „holde/edle", „auf dass", „es begab sich", „harrte", „allerorten", „weilte", „sann", „vermochte" sowie pathetische Inversionen und feierlich-erhabener Ton. Moderne Wortwahl, normale Wortstellung, heutige Begriffe (es sei denn, das Genre ist ausdrücklich historisch).
        - DIREKT ERZÄHLEN – UMSCHREIBUNGEN STRENG BEGRENZEN: Nenne Dinge, Gefühle und Ereignisse beim konkreten Namen, statt sie zu umschreiben. Der Leser muss in JEDEM Absatz ohne Rätseln verstehen, wer was tut und was gerade passiert. STRENG VERBOTEN sind gehäufte Umschreibungs-Ketten: Benennungs-Vermeidung („das, was sie waren", „etwas, das sie nicht benennen konnte"), Korrekturfiguren in Serie („Nicht leergezogen, sondern ausgelöscht"), abstrakte Vergleiche ins Ungefähre („wie eine Wand aus etwas Härterem als Luft"), Substantiv-Kaskaden, die dieselbe Sache dreimal neu umschreiben. HÖCHSTENS EINE Umschreibung pro Szene – alles andere in klaren, direkten Sätzen. Wenn ein Satz beim ersten Lesen nicht sofort verständlich ist, schreibe ihn einfacher.
        - ALLTAGSSPRACHE STATT FACHVOKABULAR: Verwende AUSSCHLIESSLICH Wörter, die ein normaler Leser kennt und im Alltag benutzt. KEINE akademischen Fachbegriffe, Bildungswörter, bildungssprachlichen Adjektive oder seltenen Fremdwörter (z. B. NIEMALS „Mediävistiker", „Komparatistik", „kartographisch", „diaphan", „ephemer", „Ökonometrie", „Habilitand", „proliferieren", „evozieren", „konzedieren"). Braucht eine Figur einen Fachberuf, beschreibe ihn so, wie Menschen wirklich reden („Professor für mittelalterliche Geschichte" statt „Mediävistiker"; „ein Fleck wie eine Landkarte" statt „kartographisch"). Auch KEINE unerklärten Bildungs-Anspielungen (antike Dramen, Dissertationsthemen, Literaturtheorie), die nur Akademiker verstehen – wenn eine Figur studiert, bleibt ihr Fachgebiet in einfachen Worten beschrieben. Härtetest: Würde jemand das Wort in einem Gespräch unter Freunden sagen? Wenn nein, ersetze es.
        - INHALTLICH STIMMIG (muss Sinn ergeben): Jeder Satz schließt logisch an den vorigen an; keine schön klingenden, aber leeren, widersprüchlichen oder unverständlichen Sätze. Lieber klar und konkret als kunstvoll und vage. Handlung, Zeit und Ort müssen nachvollziehbar bleiben.
        - KLARE KAUSALITÄT UND ABSICHT: Der Leser erkennt jederzeit, WER handelt, WAS konkret geschieht, WARUM die Figur es jetzt tut und WELCHE unmittelbare Folge daraus entsteht. Geheim gehalten werden darf eine benannte Information, niemals die sichtbare Handlung oder die aktuelle Absicht. Keine Absätze, die nur Stimmung, Vermutung oder Reaktion umkreisen. Spätestens nach einer kurzen Wahrnehmung folgt Entscheidung, Dialog oder Handlung.
        - ERZÄHLTEMPO VARIIEREN (passend zum Geschehen, NIE durchgehend langsam): Spannung, Action, Konfrontation, Gefahr und Wendepunkte schnell und treibend erzählen – kurze Sätze, harte Schnitte, wenig Innenschau, Fokus auf Handlung und Dialog. Ruhige, emotionale oder verbindende Momente dürfen kurz atmen, bleiben aber zielgerichtet. Steigere das Tempo zum Szenen- und Kapitelende. Lange Wetter-, Stimmungs- oder Reflexionspassagen, die die Handlung nicht vorantreiben, sind verboten (höchstens wenige Sätze, dann weiter).
        - SATZRHYTHMUS ORGANISCH VARIIEREN: Satzlänge folgt Wahrnehmung, Stimme und Tempo der konkreten Szene. Kurze Sätze und Fragmente nur als echte Akzente, niemals nach Quote oder wiederkehrendem Muster. Lesefluss ist wichtiger als demonstrative Variation.
        - ABSATZRHYTHMUS: Absätze nach Gedanken-, Handlungs- und Sprecherwechsel setzen. Ein-Satz-Absätze sparsam verwenden; keine sichtbare Längenschablone erzeugen.
        - ABSATZ-ENDEN (das wichtigste Verbot): Kein Absatz endet mit einem zusammenfassenden, deutenden oder moralisierenden Satz („Und so begriff sie …", „Es war ein Moment, der alles veränderte", „Nichts würde mehr sein wie zuvor"). Brich auf einer konkreten Handlung, einem Gegenstand oder einem halben Gedanken ab. Auch der Schlusssatz der Szene bleibt nüchtern, nicht feierlich, nicht aphoristisch – hör auf, bevor die Bedeutung sauber ist.
        - SATZANFÄNGE BRECHEN: Nicht jeder Satz beginnt mit dem Subjekt (Sie/Er/Name). Keine gehäuften Partizip- oder Adverb-Auftakte („Langsam …", „Mit zitternden Händen …") – höchstens einmal pro Absatz. Stell Sätze ruhig hart und unverbunden nebeneinander (Parataxe).
        - KONNEKTOREN-DIÄT: Höchstens EIN Satz-Anfangs-Konnektor pro Absatz; streiche „jedoch", „dennoch", „indes", „gleichwohl", „nichtsdestotrotz", „letztlich", „letztendlich", „mit anderen Worten", „in der Tat".
        - KEINE TRIKOLA / KEINE ANTITHESE-SCHABLONE: Keine Dreierreihung als Reflex („müde, hungrig und allein") – kürze auf zwei Glieder oder überlade asymmetrisch auf vier. Kein „Nicht X, sondern Y", kein „Nicht X. Nicht Y. Sondern Z." – schreib eine schlichte Aussage.
        - ADJEKTIV-DIÄT: Höchstens ein wertendes Adjektiv pro Satz. Keine synonymen Adjektivpaare („kalt und unbarmherzig", „leise und vorsichtig"). Lieber ein präzises Substantiv oder ein starkes Verb.
        - ZEIGEN, NICHT BENENNEN: Benenne kein Gefühl und liefere keine Begründung dazu („sie war nervös, weil …"). Zeig die Handlung: was die Hände tun, wie kurz die Antwort ausfällt, was die Figur zählt. Eine Geste bleibt stehen – etikettiere sie nicht („…, ein Zeichen ihrer Unsicherheit" ist verboten).
        - KEINE VAGE INNENSCHAU, KEINE STANDARD-GEFÜHLSVERBEN: Weg mit „ein Gefühl von …", „etwas in ihr/ihm", „eine Mischung aus … und …", „in diesem Moment/Augenblick", „einen Herzschlag lang"; ebenso „machte sich breit", „breitete sich aus", „durchströmte", „überkam", „überrollte". Zeig stattdessen, was die Figur konkret tut.
        - KEINE HEDGES: Streiche „gewissermaßen", „gleichsam", „durchaus", „ein Stück weit", „kaum merklich", „unweigerlich", „zweifellos", „gewiss". Eine menschliche Stimme behauptet oder schweigt, sie versichert nicht.
        - STIMME & EIGENHEIT: Gib der Erzählstimme eine feste Marotte (ein schräges Lieblingswort, einen wiederkehrenden Vergleich aus der Erfahrungswelt genau dieser Figur). Vergleiche nur mit Bildern aus dem Leben DIESER Figur. Greif gelegentlich zu einem unerwarteten, milieuspezifischen Wort, einem echten Orts- oder Markennamen, einer exakten Uhrzeit. Meide die glatteste, wahrscheinlichste Vokabel.
        - WIEDERHOLUNG DARF SEIN: „sagte" darf mehrfach hintereinander stehen – kein Zwangs-Synonym-Karussell bei Redebegleitern („erwiderte/entgegnete/bemerkte" in Folge ist verboten).
        - SELEKTIVE SINNLICHKEIT & WETTER: Pro Moment EIN Sinneseindruck, gern ein unerwarteter – kein Geruch-Klang-Sicht-Inventar. Wetter und Umgebung spiegeln NICHT die Gefühlslage; es darf regnen, während jemand glücklich ist.
        - VERGLEICHS-KRÜCKE BEGRENZEN: „als hätte …", „als ob …", „als wäre …", „als würde …" sowie der Reflex-Vergleich „wie ein …" höchstens EINMAL pro Szene. Sonst das Konkrete unvermittelt hinstellen (statt „Ihre Hände zitterten, als hätte jemand die Kälte aufgedreht" lieber „Ihre Hände zitterten. Sie schob sie unter die Oberschenkel."). Keine vagen Innenschau-Formeln wie „etwas, das sie nicht benennen konnte/wollte", „etwas, das sie nicht in Worte fassen konnte" – benenne das Konkrete oder lass es weg.
        - MOTIV NICHT HÄMMERN: Ein abstraktes Themen-Substantiv (z.B. Kontrolle, Nähe, Schweigen, Protokoll) NICHT als Leitmotiv wiederholen, und das Thema NIE als abstrakten Begriff aussprechen. Zeig es an konkreten Dingen, benenne es nie.
        - KEINE WIEDERKEHRENDEN BEATS/GESTEN: Greife dieselbe Körpergeste oder Erzähl-Formel NIE als Reflex wieder auf. STRENG VERBOTEN als Standard-Beat (überstrapaziert, killt den Lesefluss): „öffnete den Mund und schloss ihn (wieder)", „drehte sich nicht um", die Formel „…", sagte sie. Keine Frage." und „etwas, das sie nicht [sehen/deuten/benennen] konnte". Jede emotionale Reaktion wird ANDERS und konkret gezeigt; variiere Gesten von Szene zu Szene.
        - HARTE FREQUENZ-LIMITS pro Szene (werden maschinell gezählt): Sätze, die mit „Nicht/Kein/Keine" beginnen: höchstens 1 (die Verneinungs-Rhetorik „Nicht X. Sondern Y." ist DAS Erkennungszeichen von KI-Prosa). Körpersignale (schlucken, Atem stocken/anhalten, Herz hämmern, Magen, zittern, kribbeln): zusammen höchstens 1. „leise/langsam/plötzlich/einfach": zusammen höchstens 2. Was ein Körpersignal sagen soll, zeigt stattdessen eine konkrete Handlung, ein Objekt oder ein Satz Dialog.
        - TELLING SPARSAM: Formeln wie „sie wusste, dass …", „sie kannte …", „etwas in …" nur selten. Statt zu behaupten, was eine Figur weiß oder fühlt, zeig die Handlung oder das konkrete Detail, aus dem es hervorgeht.
        - SELBSTCHECK vor der Ausgabe (still, nicht in den Text schreiben): Endet ein Absatz auf einer Deutung? Drei gleich lange Sätze in Folge? Ein Gefühl benannt statt gezeigt? Eine Trikola oder ein „nicht X, sondern Y"? Mehr als ein „als hätte/wäre/würde"? Ist bei jedem Absatz klar, wer handelt, was geschieht und was sich dadurch ändert? – umbauen. Gib nur die korrigierte Prosa aus.
        """
    }

    /// Bestseller-Page-Turner-Technik (Donald-Maass-Stil): erzeugt den Zwang
    /// weiterzulesen. Synthese aus einem Lektoren-Panel; wird beim Szenenschreiben
    /// zusätzlich zu `humanCraftRules` eingespeist.
    static var pageTurnerRules: String {
        """
        SOG / PAGE-TURNER (der Leser MUSS weiterlesen):
        - OFFENE SCHLEIFEN DOSIEREN: Halte die zentrale Frage des aktuellen Abschnitts lebendig, aber erlaube echte Antworten und kurze Ruhe. Nicht jede Szene muss eine neue Frage eröffnen.
        - SPANNUNGSSTRÖME: Äußere und zwischenmenschliche Spannung dürfen sich abwechseln; erzwinge nicht beide in jeder Szene.
        - MIKROSPANNUNG GEZIELT: Dialog, Entscheidung und widersprüchliche Absichten tragen Spannung. Reine Beobachtung oder Atmosphäre ist erlaubt, wenn sie Stimme, Orientierung oder Kontrast schafft und knapp bleibt.
        - WITHHOLDING KONKRET: Halte gezielt EINE BENANNTE Information zurück, kein diffuses „etwas, das nicht stimmte". Eine Andeutung bleibt höchstens zweimal vage, dann wird sie schärfer oder benannt.
        - VERZÖGERUNG: Springe nie sofort zur Lösung. Beinahe-Momente (fast berührt, fast gesagt, dann unterbrochen); romantische UND Plot-Auflösung bewusst hinauszögern.
        - EINSTIEG UND ENDE VARIIEREN: Beginne mit der frühestmöglichen interessanten Handlung. Enden dürfen Wendung, Entscheidung, Erkenntnis, emotionale Verschiebung oder ein prägnantes konkretes Bild sein. Wiederhole denselben Endtyp nicht mechanisch.
        - DIALOG DOPPELBÖDIG: Figuren reden über A und meinen B. Kein reiner Informations-Dialog ohne mitschwingende Beziehungsebene.
        - STAKES KONKRET: Übersetze jede abstrakte Gefahr in persönlichen Verlust (ein Mensch, ein Zuhause, die Zukunft mit dem Love Interest) und benenne ihn früh.
        """
    }

    /// „Fesseln-Garantie" aus einem Lektoren-Panel (Vergleich fesselndes vs.
    /// langweiliges echtes Kapitel): verhindert, dass eine Szene in schöne, aber
    /// ereignislose Stimmung versackt. Ergänzt `pageTurnerRules`.
    static var gripRules: String {
        """
        FESSELN GARANTIEREN (jede Szene zieht; das steht ÜBER schöner Sprache – eine sprachlich perfekte Szene ohne Vorwärtsbewegung ist ein Fehler):
        - SZENEN-GATE (vorab benennen, sonst nicht schreiben): WILL = was die Perspektivfigur konkret und benennbar will (kein Lebensgefühl wie „Nähe spüren", sondern ein Ziel wie „herausfinden, was X verbirgt"); WIDERSTAND = wer oder was es aktiv verweigert (eine lügende Person, eine Frist, eine Bedrohung); VERLUST = was sie konkret verliert, wenn sie scheitert. Fehlt eins, ist es ein Stimmungsbild, kein Vorgang.
        - LAGE-DELTA (Pflicht): Die Lage am Szenenende MUSS gegenüber dem Anfang verschoben oder verschärft sein – in WISSEN, MACHT/STATUS, RISIKO oder BINDUNG. Streich-Test: Ändert die Szene nichts am Buch, ist sie ein Zustand statt eines Vorgangs – umbauen. (Falsch: „will raus" → „will raus, jetzt gespürt". Richtig: „Verdacht" → „Beweis plus zerstörtes Vertrauen".)
        - VERÄNDERUNG STATT LEERLAUF: Eine Szene verändert mindestens Wissen, Beziehung, Entscheidung, Risiko oder Selbstbild. Eine Enthüllung ist eine Möglichkeit, keine Pflichtformel.
        - DETAILS MIT FUNKTION: Prominente Details tragen Orientierung, Figur, Atmosphäre oder Handlung. Nicht jedes Detail muss als Indiz aufgeladen werden.
        - STIMMUNGS-BUDGET: Höchstens etwa 15–20 % reine Atmosphäre/Innenschau pro Szene; nie mehrere reine Stimmungsabsätze ohne Statusverschiebung hintereinander.
        - MOTIV ESKALIERT: Ein Leitmotiv (Regen, Schweigen, ein Objekt) höchstens zweimal explizit benennen; beim zweiten Mal muss es die Lage verschärfen (neue Drohung oder Information), nicht nur bestätigen.
        - SCHLUSS MIT FUNKTION: Die letzte Zeile setzt den beabsichtigten Nachklang oder Vorwärtsimpuls. Sie darf eine Frage öffnen, eine Entscheidung festnageln oder einen ruhigen emotionalen Beat abschließen; entscheidend ist die passende Wirkung, nicht ein Pflicht-Cliffhanger.
        - EINSATZ STEIGT: Der konkrete Einsatz steigt über das Buch tendenziell; nicht dreimal in Folge derselbe niedrige Einsatz.
        """
    }

    /// Konzeptphasen-Vertrag, der verhindert, dass aus einem Liebesroman/Erotik-Roman
    /// ein Thriller mit Job-Plot (und einem Stalker als „Love Interest") wird.
    /// Greift VOR der ersten Szene; leer für andere Genres.
    static func romanceGenreContract(_ genre: String) -> String {
        let g = genre.lowercased()
        let isRomance = g.contains("liebes") || g.contains("romance")
            || g.contains("erotik") || g.contains("erotic") || g.contains("spicy")
            || g.contains("new adult")
        guard isRomance else { return "" }
        return """

        GENRE-VERTRAG LIEBESROMAN/EROTIK (verbindlich fürs Konzept):
        - Die zentrale dramatische Frage MUSS eine Beziehungsfrage sein („Finden A und B zueinander / bleiben sie zusammen, obwohl …?"). Verboten als Kernfrage: „Wird das Netz/die Firma/die Stadt gerettet?", „Wird der Täter gefasst?", „Überlebt sie?".
        - Streich-Test: Bliebe nach dem Entfernen der Liebesgeschichte ein funktionierender Plot übrig, ist das Konzept falsch. Äußerer Konflikt (Beruf, Krise, Gefahr) ist nur Bühne und Druckmittel, das die beiden zusammenzwingt, nie Selbstzweck.
        - Der dunkle Moment ist ein Beziehungskonflikt (Stolz, Angst vor Nähe, Missverständnis, Vertrauensbruch), nicht Bombe, Anzeige oder Tod.
        - Der Love Interest wird als rootbare Figur angelegt: eine Wunde, aktive Fürsorge, Respekt vor ihrer Autonomie, eine eigene anziehende Eigenschaft, selbst begehrt. Kein Stalker, kein heimliches Beobachten.
        - Die Heldin ist Subjekt mit eigenem, aktivem Begehren (POV-Symmetrie), nie nur Objekt.
        - Pflicht-Ende: emotional erfülltes Happy End (HEA oder HFN).
        """
    }

    static func genreCraft(_ genre: String) -> String {
        let g = genre.lowercased()
        if g.contains("thriller") || g.contains("krimi") {
            return "GENRE-HANDWERK: Hohes Tempo. Spannung durch Wissensvorsprung oder -rückstand des Lesers. Jede Szene endet mit einem Haken. Kurze Sätze in Actionmomenten."
        }
        if g.contains("erotik") || g.contains("erotic") || g.contains("dark romance") || g.contains("spicy") {
            return "GENRE-HANDWERK: Die BEZIEHUNG der Hauptfiguren ist der Motor, nicht ein externer Thriller- oder Job-Plot. Jede Szene mit dem Love Interest bewegt das Paar um EINEN Schritt (Anziehung, Rückschlag, Verletzlichkeit, Begehren, Bruch, Wiederannäherung). Der Love Interest ist rootbar: begehrenswert, verletzlich, mit aktiver Fürsorge für die Heldin und Respekt vor ihrer Autonomie (er handelt MIT ihr, nie heimlich AN ihr) – KEIN Stalker/Täter; heimliches Beobachten, Schlaf-Überwachen oder jemanden „studieren wie ein Krankheitsbild“ ist nicht romantisch, sondern ein Genre-Fehler. Chemie ist gegenseitig: pro Begegnung mindestens ein Begehrens-Detail aus Sicht der Heldin. Slow Burn – Sehnsucht aus noch nicht eingelöster Nähe (Beinahe-Berührung, das Ungesagte, Wollen/Zögern/Erlauben); Gefahr ersetzt NIE die erotische Spannung. Intime und erotische Szenen sind ausdrücklich erwünscht und dürfen explizit und körperlich ausgeschrieben werden, auf Bestseller-Niveau (Fifty-Shades-Stil): einvernehmlich zwischen Erwachsenen, geschmackvoll, sinnlich (Haut, Temperatur, Geruch, Druck, Stimme), nie vulgär, klinisch oder als Körperteil-Inventar, auch in der Hitze aus der inneren Perspektive mit Subtext. Fachjargon nur Kulisse, max. 1-2 Sachbegriffe pro Szene. Keine illegalen oder nicht-einvernehmlichen Inhalte, keine Minderjährigen."
        }
        if g.contains("liebes") || g.contains("romance") {
            return "GENRE-HANDWERK: Die LIEBESGESCHICHTE ist die Haupthandlung, nicht Beiwerk. Die zentrale Frage ist eine Beziehungsfrage (Finden die beiden zueinander, bleiben sie es?), kein Kriminalfall, keine Sabotage, kein Beruf. Faustregel: Ließe sich der Liebes-Strang herausschneiden und der Plot bliebe intakt, ist es kein Liebesroman. Jede Szene mit dem Love Interest bewegt das Paar um EINEN benennbaren Schritt (erster Funke, Anziehung gegen Widerstand, erzwungene Nähe, Verletzlich-Werden, Vertrauen, Begehren, Missverständnis, Geständnis, Bruch, Wiederannäherung); der dunkle Moment ist ein Beziehungs-Bruch (Stolz, Angst vor Nähe, Missverständnis), KEINE Bombe und keine Anzeige. Der Love Interest ist rootbar: eine menschliche Wunde, aktive Fürsorge für die Heldin, Respekt vor ihrer Autonomie (er handelt MIT ihr, nie heimlich AN ihr), eine eigene anziehende Eigenschaft, und er wird selbst begehrt. VERBOTEN als Romantik: heimliches Beobachten, Schlaf-Überwachen, Ausspähen, jemanden „studieren wie ein Krankheitsbild“ – das ist ein Stalker-Muster und ein Genre-Fehler, kein Reiz. Chemie ist wechselseitig und körperlich verankert: pro Begegnung mindestens EIN Wärme-/Begehrens-Detail aus Sicht der Heldin (sein Geruch, wie er den Kopf neigt, ihr Blick, der zu lange hält). Slow Burn: Sehnsucht aus noch nicht eingelöster Nähe; Gefahr ersetzt NIE die emotionale Spannung. Fachjargon des Berufs nur Kulisse, max. 1-2 Sachbegriffe pro Szene. Dialoge leben vom Ungesagten; das Thema wird nie ausgesprochen. Pflicht-Ende: emotional erfülltes Happy End (HEA oder HFN)."
        }
        if g.contains("romantasy") {
            return "GENRE-HANDWERK: Romantasy = große Romanze IN einer fantastischen Welt. Beide Achsen tragen gleichberechtigt: ein in EINEM Satz fassbares Magie-/Welt-Konzept UND eine Beziehung mit echter Chemie, die den emotionalen Sog liefert. Der Love Interest ist rootbar und begehrenswert (KEIN Stalker), Sehnsucht und Begehren treiben mit, die fantastische Bedrohung erhöht den persönlichen Einsatz. Welt durch konkrete Details im Handlungsfluss zeigen, nie durch Infodumps. Pflicht: ein emotional erfülltes Ende für das Paar."
        }
        if g.contains("fantasy") || g.contains("science") || g.contains("dystop") || g.contains("steampunk") || g.contains("märchen") {
            return "GENRE-HANDWERK: Die Welt durch konkrete Details im Handlungsfluss zeigen – niemals durch Erklärabsätze oder Infodumps. Regeln der Welt konsequent einhalten."
        }
        if g.contains("horror") {
            return "GENRE-HANDWERK: Bedrohung andeuten statt zeigen. Atmosphäre über Sinneseindrücke und Stille aufbauen. Ruhe vor jeder Eskalation."
        }
        if g.contains("histor") {
            return "GENRE-HANDWERK: Epochendetails beiläufig einweben (Gegenstände, Gerüche, Umgangsformen). Sprache zeitgemäß färben, ohne antiquiert zu wirken."
        }
        return "GENRE-HANDWERK: Erzeuge in jeder Szene einen klaren Spannungsbogen mit spürbarer Wendung."
    }

    static func draftScene(language: String, style: String, tonality: String,
                           perspective: String, tense: String, genre: String,
                           bookTitle: String, chapterNumber: Int, chapterTitle: String,
                           chapterGoal: String, sceneNumber: Int,
                           sceneGoal: String, sceneLocation: String, sceneTime: String,
                           sceneObstacle: String, sceneTurn: String, scenePerspective: String,
                           charactersSummary: String, styleRules: String,
                           storySoFar: String, previousSceneEnding: String,
                           isFirstScene: Bool, isFinalScene: Bool,
                           targetWords: Int, bookSignature: String = "", spiceLevel: Int = 0,
                           genreBrief: String = "", positionBlock: String = "",
                           catalogAvoidance: String = "", manuscriptAvoidance: String = "",
                           researchContext: String = "", canonicalStory: String = "") -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionDraftSection(language: language, style: style, tonality: tonality,
                                           genre: genre, bookTitle: bookTitle,
                                           chapterNumber: chapterNumber, chapterTitle: chapterTitle,
                                           chapterGoal: chapterGoal, sectionNumber: sceneNumber,
                                           sectionGoal: sceneGoal, sectionKind: sceneLocation,
                                           sequence: sceneTime, readerObstacle: sceneObstacle,
                                           takeaway: sceneTurn, priorContent: storySoFar,
                                           targetWords: targetWords, isFirst: isFirstScene,
                                           isFinal: isFinalScene, researchContext: researchContext,
                                           manuscriptAvoidance: manuscriptAvoidance)
        }
        var positionNote = ""
        if isFirstScene {
            positionNote = """

            WICHTIG – ERSTE SZENE DES BUCHES:
            Der erste Satz ist der wichtigste des gesamten Romans (Amazon-Leseprobe!). \
            Er muss sofort fesseln: eine Störung der Normalität, eine Frage im Kopf des Lesers. \
            Etabliere Hauptfigur und Stimmung auf der ersten Seite – ohne Vorgeplänkel.
            """
        } else if isFinalScene {
            positionNote = """

            WICHTIG – LETZTE SZENE DES BUCHES (diese Anweisung hat VORRANG vor allen \
            Sog-/Cliffhanger-Regeln oben):
            Löse den zentralen Konflikt emotional befriedigend auf und SCHLIESSE alle im Buch \
            benannten offenen Fragen (oder übergib sie ausdrücklich einem Folgeband). Greife ein \
            Bild oder Motiv vom Anfang des Buches wieder auf. Ein ruhiger Ausklang ist erlaubt \
            und erwünscht. Der Schlusssatz muss nachhallen – er öffnet KEINE neue Frage. \
            Kein Cliffhanger.
            """
        }
        if !positionBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            positionNote += "\n\(positionBlock)\n"
        }

        var transition = ""
        if !previousSceneEnding.isEmpty {
            transition = """

            WÖRTLICHES ENDE DER VORHERIGEN SZENE:
            „…\(previousSceneEnding)“
            Setze die Szene unmittelbar fort, ohne das Geschehene zu wiederholen.
            """
        }

        let trimmedSignature = bookSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        let signatureBlock = trimmedSignature.isEmpty ? "" : "\n\(trimmedSignature)\n"
        let spiceDirective = SpiceLevel.generationDirective(spiceLevel)
        let spiceBlock = spiceDirective.isEmpty ? "" : "\n\(spiceDirective)\n"
        let manuscriptAvoidanceBlock = manuscriptAvoidance.isEmpty ? "" : """

        WÖRTLICHE SPERRLISTE AUS DIESEM MANUSKRIPT:
        \(manuscriptAvoidance)
        Keinen dieser Sätze oder Beats wiederholen oder nur kosmetisch umstellen.
        Reagiere an dieser Stelle konkret aus Figur, Ort und Handlung heraus.
        """

        return """
        Schreibe Szene \(sceneNumber) aus Kapitel \(chapterNumber) ("\(chapterTitle)") des Romans "\(bookTitle)".

        SPRACHE: Schreibe ausschließlich auf \(language).
        STIL: \(style); Tonalität: \(tonality); Erzählperspektive: \(scenePerspective.isEmpty ? perspective : scenePerspective); Zeitform: \(tense).
        STILREGELN: \(styleRules.truncated(to: 600))
        \(signatureBlock)\(spiceBlock)
        \(genreDirectiveBlock(genreBrief))
        \(catalogAvoidance)
        \(manuscriptAvoidanceBlock)
        \(ContentSafetyFilter.promptDirective)
        VERBINDLICHER BUCHKANON (jede Aussage muss damit vereinbar sein):
        \(canonicalStory.truncated(to: 7000))
        Erfinde oder ändere keine Verwandtschaft, Besitzverhältnisse, Todesfälle, Vorgeschichte,
        Berufe, Namen oder Rollen. Ist ein Detail nicht festgelegt, lasse es offen statt eine
        scheinbar passende Tatsache hinzuzuerfinden.
        KAPITELZIEL: \(chapterGoal)
        SZENE:
        - Ort: \(sceneLocation)
        - Zeit: \(sceneTime)
        - Ziel: \(sceneGoal)
        - Hindernis: \(sceneObstacle)
        - Wendung am Ende: \(sceneTurn)
        - Zielumfang: ca. \(targetWords) Wörter

        Langform-Pflicht: Schreibe die Szene aus, nicht als Zusammenfassung. Nimm den Zielumfang ernst:
        Konflikt, Wahrnehmung, Subtext, kleine Entscheidungen und Konsequenzen müssen auf der Seite stattfinden.

        FIGUREN (Merkmale sind KANONISCH – Alter, Beruf, Beziehungen nie verändern):
        \(charactersSummary.truncated(to: 2000))

        BISHERIGE HANDLUNG:
        \(storySoFar.isEmpty ? "Dies ist der Anfang des Buches." : storySoFar.truncated(to: 8000))
        \(transition)
        HANDWERK (die GESCHICHTE steht im Vordergrund – Technik dient ihr, nie umgekehrt):
        - KLARHEIT VOR SCHÖNHEIT: Der Leser muss der Szene mühelos folgen und sich auf sie einlassen können. Schreibe verständlich; verrätsle oder überlade nichts, was die Handlung trägt.
        - BILDER STRENG RATIONIEREN: HÖCHSTENS ein bis zwei wirklich starke Bilder/Metaphern in der GANZEN Szene. Alles andere klar und nüchtern erzählen. Nicht jeder innere Zustand bekommt ein Bild – sonst stumpft die Wirkung ab und am Ende wirkt nichts mehr intensiv.
        - HANDELN STATT GRÜBELN: Die Figur tut konkrete Dinge (fragt, sucht, ruft an, konfrontiert, entscheidet, handelt) statt überwiegend innerlich zu reagieren. Innere Erschütterung kurz halten.
        - KÖRPERSIGNALE SPARSAM UND VARIIERT: Zittern, Herzklopfen, zugeschnürte Kehle, „den Mund öffnen und wieder schließen" nur selten – nicht in jeder Szene dieselben Reaktionen.
        - DIALOG BEILÄUFIG UND ECHT: Verletzendes klingt beiläufig und präzise, nicht wie ein ausgesprochenes Romanthema. Eine Figur sagt das Thema des Buches NIE direkt aus. Lieber härter und glaubwürdiger als perfekt formuliert.
        - THEMA NIEMALS ERKLÄREN: Die emotionale Bedeutung wird gezeigt, nie zusammengefasst oder ausbuchstabiert („nicht X, sondern Y" als Deutung ist verboten). Vertraue darauf, dass der Leser sie selbst erschließt.
        - Beginne mitten in der Handlung; halte den Einstieg kurz und komm schnell zum Kern der Szene. Keine Wetter- oder Aufwach-Eröffnung.
        - Szenenstruktur: Ziel → Konflikt → Wendung. Tiefe Perspektive der Perspektivfigur (keine Information, die sie nicht haben kann). Zeigen statt behaupten – Emotion NIE benennen („sie war wütend" ist verboten).
        - KEINE ZUSATZ-ENTHÜLLUNG: Erfinde weder Schlüssel, Brief, Zettel, Notiz, Foto, Tagebuch, Waffe,
          Silhouette, Beobachter noch anderes Fundstück als zusätzlichen Haken. Die Szene endet
          ausschließlich mit der oben geplanten Wendung. Ist dort kein Fundstück genannt, gibt es keines.
          Auch gewöhnliche Gegenstände (Besteck, Kleidung, Werkzeug, Möbel) bleiben gewöhnlich: kein
          auffälliges, neues, verändertes oder unerklärlich platziertes Objekt als Ersatz-Rätsel.
          Niemand war heimlich im Haus, beobachtet die Figur oder hinterlässt Spuren, sofern der
          Szenenplan das nicht ausdrücklich und genresicher festlegt.
          Türen, Fenster und Gegenstände verändern ihren Zustand nicht unerklärt zwischen Szenen.
        - Konkrete, spezifische Details statt generischer. Variiere Satzlänge und Rhythmus wie in einem Bestseller: Lesefluss vor Kunstfertigkeit, nicht jede Zeile „literarisch" aufladen.
        \(humanCraftRules)
        - KEINE WIEDERHOLUNGEN: Greife keine Bilder, Metaphern, Formulierungen oder Motive aus der bisherigen Handlung wieder auf; erkläre etablierte Fakten nie ein zweites Mal. Ein starkes Symbol nur SELTEN erwähnen, nicht in jeder Szene.
        \(isFinalScene
            ? "- AUSZAHLUNG: Alle offenen Fragen werden hier beantwortet – der letzte Satz hallt nach, statt eine neue Frage zu öffnen."
            : """
              - SOG (dezent): Halte mindestens eine offene Frage aktiv und nutze Mikro-Spannung, aber nie auf Kosten der Verständlichkeit. Pro Szene höchstens EINE neue Figur oder Enthüllung, nicht mehrere gleichzeitig.
              - Der letzte Satz gibt einen Grund zum Weiterlesen, ohne aufgesetzt oder programmatisch zu wirken.
              \(pageTurnerRules)
              \(gripRules)
              """)
        \(genreCraft(genre))
        \(positionNote)
        Gib AUSSCHLIESSLICH den fertigen Prosatext der Szene aus. Übernimm NIEMALS
        Anweisungen, Labels (z.B. „Ort:", „Ziel:", „Zielumfang"), Überschriften oder
        Hinweise aus diesem Auftrag in den Text – schreibe ausschließlich die Geschichte selbst.
        REINER FLIESSTEXT: keine Markdown-Formatierung (kein *, **, _, #, keine Aufzählungen),
        keine Sternchen, keine Emojis, keine Szenen-Überschriften. Betonung entsteht durch
        Wortwahl, nicht durch Sonderzeichen. Nur normale Wörter und Satzzeichen.
        """
    }

    static func summarizeScene(text: String) -> String {
        """
        Fasse die folgende Romanszene in 2-3 Sätzen zusammen. Nenne Figuren, Ort, \
        was passiert, was sich verändert hat und welche neuen Fakten oder Enthüllungen \
        etabliert wurden. Füge danach GENAU eine Zeile an: \
        „OFFEN: <die in dieser Szene neu geöffnete Frage oder das gegebene Versprechen>" – \
        falls nichts Neues geöffnet wurde: „OFFEN: -". Gib NUR Zusammenfassung + OFFEN-Zeile aus.

        \(text.truncated(to: 8000))
        """
    }

    /// Verdichtet ein abgeschlossenes Kapitel für das Langstrecken-Gedächtnis.
    static func condenseChapter(chapterNumber: Int, chapterTitle: String, sceneSummaries: String) -> String {
        """
        Verdichte die folgenden Szenen-Zusammenfassungen von Kapitel \(chapterNumber) \
        („\(chapterTitle)“) auf maximal 2 Sätze: Was ist passiert, und welche neuen \
        Fakten oder Wendungen wurden etabliert? Gib NUR die Verdichtung aus.

        \(sceneSummaries.truncated(to: 4000))
        """
    }

    /// Erzeugt einen echten, inhaltsbezogenen Kapiteltitel aus der Kapitel-
    /// Zusammenfassung – als Ersatz für generische Platzhalter („Aufbruch N").
    static func chapterTitle(bookTitle: String, genre: String, chapterNumber: Int, summary: String) -> String {
        """
        Finde EINEN kurzen, kreativen Kapiteltitel für Kapitel \(chapterNumber) des Romans \
        „\(bookTitle)" (Genre: \(genre)). Worum es in diesem Kapitel geht:
        \(summary.truncated(to: 700))

        Regeln: Der Titel ist ein konkretes Bild, ein Versprechen oder eine Frage aus DIESEM \
        Kapitel (2 bis 5 Wörter), macht neugierig und verrät die Auflösung NICHT. STRENG VERBOTEN: \
        „Kapitel N", „Teil N", Phasennamen (Aufbruch/Eskalation/Krise/Auflösung), Durchnummerierung, \
        blasse Abstrakta. Keine Anführungszeichen, kein Gedankenstrich, keine Erklärung.

        Gib AUSSCHLIESSLICH den Titel aus, sonst nichts.
        """
    }

    static func reviseChapter(language: String, style: String, tonality: String,
                              chapterNumber: Int, chapterTitle: String, text: String,
                              genreBrief: String = "", charactersSummary: String = "",
                              previousEnding: String = "", nextOpening: String = "",
                              overusedPhrases: String = "", endingNote: String = "",
                              targetWords: Int = 0, researchContext: String = "") -> String {
        if genreBrief.contains("SACHBUCH") || genreBrief.contains("FAKTEN- UND QUELLENINTEGRITÄT") {
            return nonfictionRevision(language: language, style: style, tonality: tonality,
                                      chapterNumber: chapterNumber, chapterTitle: chapterTitle,
                                      text: text, genreBrief: genreBrief,
                                      overusedPhrases: overusedPhrases, targetWords: targetWords,
                                      researchContext: researchContext)
        }
        // Kontext-Blöcke: Die Revision lief bisher völlig blind (ohne Genre, Figuren,
        // Nachbarkapitel) – sie konnte Fakten verfälschen, den Genre-Ton abkühlen und
        // Kapitel-Anschlüsse/Cliffhanger zerschreiben.
        let charactersBlock = charactersSummary.isEmpty ? "" :
            "\nFIGUREN (kanonisch – Namen und Fakten NICHT verändern):\n\(charactersSummary.truncated(to: 1200))\n"
        let seamBlock: String
        if previousEnding.isEmpty && nextOpening.isEmpty {
            seamBlock = ""
        } else {
            seamBlock = """

            ANSCHLUSS (inhaltlich unverändert lassen):
            \(previousEnding.isEmpty ? "" : "So endet das VORIGE Kapitel – der Kapitelanfang muss weiterhin nahtlos daran anschließen: „…\(previousEnding)“")
            \(nextOpening.isEmpty ? "" : "So beginnt das NÄCHSTE Kapitel – das Kapitelende (inkl. seines Hakens) muss weiterhin dorthin führen: „\(nextOpening)…“")
            """
        }
        let overusedBlock = overusedPhrases.isEmpty ? "" : """

            BEREITS ÜBERSTRAPAZIERTE FORMULIERUNGEN DIESES BUCHES \
            (hier jede durch eine frische, konkrete Alternative ersetzen, nie wiederverwenden):
            \(overusedPhrases)
        """
        let endingBlock = endingNote.isEmpty ? "" : "\n\(endingNote)\n"
        let isOversized = ChapterRevisionSizing.isOversized(
            sourceWords: text.wordCount,
            targetWords: targetWords
        )
        let lengthDirective = isOversized ? """
        Verdichte dieses überlange Kapitel auf ca. \(targetWords) Wörter (zulässig: 75–130 % des Ziels). \
        Halte dabei die Handlung vollständig: Streiche Redundanz, doppelte Gedanken, wiederholte \
        Reaktionen und unnötige Umwege, aber keine Ereignisse, Hinweise, Wendungen oder Anschlüsse.
        """ : "Behalte den Umfang bei (±10%)."
        return """
        Überarbeite Kapitel \(chapterNumber) ("\(chapterTitle)") eines Romans.
        Sprache: \(language). Stil: \(style), Tonalität: \(tonality).
        \(genreDirectiveBlock(genreBrief))
        Verbessere Satzrhythmus, Wortwiederholungen, schwache Verben, Füllwörter und \
        Dialogfluss. Streiche Filterwörter (sehen, hören, spüren, bemerken), wo die \
        Wahrnehmung direkt gezeigt werden kann. Behalte Handlung, Reihenfolge der \
        Ereignisse und Perspektive bei. \(lengthDirective) Szenentrenner (***) müssen \
        exakt erhalten bleiben. Der Genre-Ton (z. B. Hitze/Spannung) darf beim \
        Glätten NICHT abkühlen.
        \(charactersBlock)\(seamBlock)\(overusedBlock)\(endingBlock)
        Wende beim Überarbeiten zusätzlich diese Regeln an (entferne KI-typische Muster aktiv):
        \(humanCraftRules)

        Gib NUR den vollständigen überarbeiteten Kapiteltext aus, ohne Überschrift und ohne Kommentare.

        TEXT:
        \(text)
        """
    }

    static func consistencyCheck(bookTitle: String, summaries: String, characters: String,
                                 isNonfiction: Bool = false) -> String {
        if isNonfiction {
            return """
            Prüfe das Sachbuch "\(bookTitle)" auf sachliche Widersprüche, unklare Begriffe,
            fehlerhafte Reihenfolge, Redundanz, fehlende Voraussetzungen, nicht umsetzbare Schritte,
            absolute Versprechen und unbelegte Tatsachenbehauptungen. Fehlende Belege niemals erfinden.

            INHALTSÜBERSICHT:
            \(summaries.truncated(to: 10000))

            Antworte je Problem exakt:
            PROBLEM|Schweregrad (Info/Warnung/Fehler/Kritisch)|Bereich|Beschreibung|Empfehlung
            Wenn es keine Probleme gibt: KEINE PROBLEME
            """
        }
        return """
        Prüfe die folgende Kapitelübersicht des Romans "\(bookTitle)" auf Widersprüche: \
        Zeitlinie, Figurenwissen, Orte, Logik der Ereignisse, offene Handlungsfäden.

        FIGUREN:
        \(characters.truncated(to: 1500))

        HANDLUNGSÜBERSICHT:
        \(summaries.truncated(to: 10000))

        Gib für jedes gefundene Problem GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        PROBLEM|Schweregrad (Info/Warnung/Fehler/Kritisch)|Bereich|Beschreibung|Empfehlung

        Wenn es keine Probleme gibt, antworte mit: KEINE PROBLEME
        """
    }

    static func kdpMetadata(title: String, author: String, authorBio: String = "", genre: String,
                            audience: String, synopsis: String, language: String, tropes: String = "",
                            spiceLevel: Int = 0) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionKDPMetadata(title: title, author: author, authorBio: authorBio,
                                         genre: genre, audience: audience, synopsis: synopsis,
                                         language: language)
        }
        let authorBlock = authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nAutorprofil für Tonalität/Markenstimme:\n\(authorBio.truncated(to: 800))\n"
        let tropesLine = tropes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nTropes (in KEYWORDS und VERKAUFSTEXT als gesuchte Begriffe natürlich aufgreifen): \(tropes)"
        let spiceLine = SpiceLevel.kdpGuidance(spiceLevel)
        return """
        Erstelle Amazon-KDP-Metadaten für das Buch "\(title)" von \(author).
        Genre: \(genre) | Zielgruppe: \(audience) | Sprache: \(language)\(tropesLine)\(spiceLine)
        \(authorBlock)

        Inhalt:
        \(synopsis.truncated(to: 3000))

        Keine Hinweise auf KI, AI, künstliche Intelligenz, Automatisierung, Tools oder NovelForge
        in Verkaufstext, Keywords oder Kategorien. Die Ausgabe muss wie professionelle Verlagsmetadaten wirken.

        Optimiere TITEL, UNTERTITEL und KEYWORDS für die Amazon-KDP-/Kindle-SUCHE, damit das Buch
        bei den gesuchten Begriffen möglichst weit oben rankt – ohne Keyword-Spam, ohne unleserliche Titel.

        Antworte exakt in diesem Format:
        VERKAUFSTITEL: [klickstarker Verkaufstitel für Amazon KDP, 2-6 Wörter, als Thumbnail im \
        Suchergebnis sofort lesbar, neugierig machend (offene Frage/Spannung), emotional und POLARISIEREND \
        (Tabu-Reiz, Anschuldigung oder gefährliches Versprechen – ein Titel, zu dem jeder sofort ein \
        Gefühl hat; nett/gefällig wird überscrollt). Nur Alltagswörter. PFLICHT: Der \
        Titel muss zum TATSÄCHLICHEN Inhalt oben und zum Genre „\(genre)" passen – er verspricht genau \
        das, was das Buch liefert (KEIN irreführender Clickbait, der eine andere Geschichte oder ein \
        anderes Genre vorgaukelt). Wenn es natürlich passt, ein gesuchtes Genre-/Trope-Wort enthalten. \
        Darf vom Originaltitel "\(title)" abweichen, wenn er stärker verkauft UND besser zum Inhalt passt. \
        Keine Anführungszeichen.]
        UNTERTITEL: [SEO-Untertitel – das wichtigste Such-Feld bei KDP. Trage die 1-2 stärksten \
        Suchbegriffe, die echte Leser tippen, VORN (Genre + Trope + Lesernutzen), 5-12 Wörter, \
        natürlich lesbar, KEIN Keyword-Stuffing; eine Zeile.]
        VERKAUFSTEXT: [150-200 Wörter Amazon-Produktbeschreibung in kurzen, scanbaren Absätzen \
        (keine Textwand, keine Markdown-Symbole): erste Zeile ein eigenständiger, zugkräftiger \
        Tagline-Hook, der ein zentrales Suchwort natürlich aufgreift; dann 2-3 kurze Absätze mit \
        steigenden Stakes und emotionalem Sog; eine kaufauslösende Schlusszeile; danach EINE \
        "Für Fans von …"-Zeile mit 1-2 genre-typischen Lese-Erlebnissen/Tropes (KEINE fremden \
        Buchtitel oder Autorennamen). Keine Spoiler. Keine verbotenen Begriffe wie "Bestseller" oder "kostenlos".]
        KEYWORDS: [genau 7 Backend-Suchbegriffe, die das KDP-Ranking treiben – Long-Tail-Phrasen, \
        wie echte Käufer suchen, je 2-4 Wörter, durch Kommas getrennt. Mische Genre+Trope, \
        Stimmung/Heat, Zielleser und Setting. Keine nackten Einzelwörter, keine doppelten \
        Wortstämme, keine Autorennamen oder Titel fremder Werke.]
        KATEGORIEN: [3 ECHTE Amazon-Kindle-Kategorien (keine erfundenen Pfade), eine pro Zeile, \
        Format: Oberkategorie > Unterkategorie. Wähle möglichst spezifische Nischen-Unterkategorien \
        des Genres, in denen der Bestseller-Rang erreichbar ist (z.B. "Liebesromane > Zeitgenössisch", \
        "Krimis & Thriller > Psychothriller", "Fantasy > Romantasy"). Bevorzuge 2 Nische + 1 breiter.]
        """
    }

    /// Judge/Polish-Pass: macht einen vorhandenen KDP-Verkaufstext verkaufsstärker.
    static func kdpBlurbPolish(blurb: String, title: String, genre: String,
                               audience: String, language: String) -> String {
        """
        Du bist ein Spitzen-Texter für Amazon-KDP-Klappentexte und Conversion-Profi.
        Mach den folgenden Verkaufstext für „\(title)" (Genre: \(genre), Zielgruppe: \(audience))
        spürbar verkaufsstärker.

        STÄRKE GEZIELT:
        - Packender Hook bereits in der ersten Zeile (Frage, Spannung, Versprechen).
        - Steigende Stakes, emotionaler Sog, eine klare kaufauslösende Schlusszeile.
        - Konkrete Bilder statt Floskeln; kein Spoiler.
        - Kurze, scanbare Absätze (keine Textwand); erste Zeile als eigenständiger Tagline-Hook.
        - Schließe mit EINER "Für Fans von …"-Zeile (genre-typische Tropes/Lese-Erlebnisse, \
        KEINE fremden Buchtitel oder Autorennamen).
        - Keine verbotenen Begriffe ("Bestseller", "kostenlos"); keine Hinweise auf KI/AI/Automatisierung.
        - Sprache: \(language).

        AKTUELLER TEXT:
        \(blurb)

        Gib NUR den verbesserten Verkaufstext aus: 150-200 Wörter, reiner Fließtext,
        keine Überschriften, keine Anführungszeichen, keine Kommentare oder Meta-Hinweise.
        """
    }

    /// Dedizierter viraler Titel-Generator: liefert mehrere klickstarke, spannende
    /// Buchtitel, die auf Amazon KDP / BookTok auffallen.
    static func viralTitles(genre: String, premise: String, language: String) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return nonfictionTitles(genre: genre, premise: premise, language: language, count: 10)
        }
        let genreLine = genre.trimmingCharacters(in: .whitespaces).isEmpty ? "" : "Genre: \(genre)\n"
        let premiseLine = premise.trimmingCharacters(in: .whitespaces).isEmpty
            ? "" : "Worum es geht: \(premise.truncated(to: 600))\n"
        return """
        Erfinde 8 VIRALE, klickstarke Buchtitel auf \(language), die sofort neugierig machen,
        spannend sind und gelesen werden wollen.
        \(genreLine)\(premiseLine)
        PFLICHT je Titel:
        - EXTREM stark und viral: stoppt den Daumen beim Scrollen, macht sofort süchtig, BookTok-würdig – keine braven, schwachen Titel. ZUGLEICH wie ein echter, professionell verlegter Bestseller: idiomatisches Deutsch, beim ersten Lesen sofort verständlich (viral heißt NICHT kryptisch).
        - POLARISIEREND: löst sofort eine emotionale Reaktion aus (Tabu, Anschuldigung, moralisches Dilemma, gefährliches Versprechen) – ein Titel, zu dem jeder eine Meinung hat. Nett und gefällig wird überscrollt.
        - 2-6 Wörter, als Amazon-KDP-Thumbnail sofort lesbar. Nur Alltagswörter, die jeder kennt.
        - Offene Frage / Spannung / starkes Versprechen — ein Sog, der zum Klicken zwingt, aber NIE gewollt, kryptisch oder rätselhaft.
        - Emotional aufgeladen, konkretes und verständliches Bild; BookTok-tauglich.
        - STRENG VERBOTEN (klingt „komisch"/künstlich): kryptische oder prätentiöse Titel, synästhetische oder paradoxe Wort-Collagen, Wörter, die zusammen keinen Sinn ergeben.
        - KEINE Berufs-/Ort-Klischees ("Die Bäckerin von …"), keine Anführungszeichen,
          keine Erklärungen, keine zwei austauschbaren Allerweltstitel.

        Gib NUR die 8 Titel aus, je einen pro Zeile, jeweils beginnend mit "TITEL: ".
        """
    }

    /// Schlägt bankfähige, auf Amazon KDP gesuchte Tropes für ein Genre vor.
    static func tropeSuggestions(genre: String, premise: String) -> String {
        let premiseLine = premise.trimmingCharacters(in: .whitespaces).isEmpty
            ? "" : "Worum es geht: \(premise.truncated(to: 400))\n"
        return """
        Nenne 8 bankfähige, auf Amazon KDP aktiv gesuchte Tropes für das Genre \(genre.isEmpty ? "Roman" : genre),
        die die Zielgruppe sucht und kauft.
        \(premiseLine)
        Je Trope 1-4 Wörter (z.B. Enemies to Lovers, Slow Burn, Grumpy Sunshine, unzuverlässige
        Erzählerin, Found Family, zweite Chance). Keine Erklärungen, eine pro Zeile.
        """
    }

    /// Erzeugt fertige, kopierbare Bildgenerierungs-Prompts (ChatGPT/DALL·E) für das
    /// Buchcover – exakt auf dieses Buch zugeschnitten.
    static func coverImagePrompts(title: String, author: String, genre: String, subgenre: String,
                                  language: String, mood: String, storySignals: String) -> String {
        """
        Du bist Art-Director für meistverkaufte Amazon-KDP-Buchcover und schreibst
        Bildgenerierungs-Prompts, die ein Autor direkt in ChatGPT/DALL·E einfügt, um sein
        Cover-Bild erzeugen zu lassen. Schreibe die Prompts auf ENGLISCH (beste Bildmodell-Ergebnisse).

        BUCH
        Titel: \(title)
        Autor: \(author)
        Genre: \(genre)\(subgenre.isEmpty ? "" : " / \(subgenre)")
        Sprache des Buches: \(language)
        Visuelle Stimmung: \(mood)
        Story-Signale (Prämisse, Thema, Konflikt, Symbol):
        \(storySignals)

        REGELN für jeden Prompt
        - Portrait 2:3 front cover, optimiert für Amazon-KDP-Thumbnail und Vollansicht.
        - Illustration/Artwork ONLY: absolut KEIN Text, keine Buchstaben, kein Titel, kein Autorname,
          keine Zahlen, keine Logos, keine Wasserzeichen im Bild.
        - Klare, ruhige Negativräume im oberen Drittel (für späteren Titel) und unteren Viertel (Autor).
        - Ein starker Fokuspunkt, der den zentralen Konflikt / das Schlüsselsymbol / die emotionale
          Wunde des Buches transportiert – nicht generisch, sondern unverwechselbar für DIESES Buch.
        - Hochwertig, cinematic, professionell – kein billiger KI-Glow, keine verformten Gesichter/Hände.
        - Keine Hinweise auf KI, AI oder Automatisierung.

        Liefere GENAU 3 unterschiedliche, eigenständige Cover-Konzepte. Antworte exakt in diesem Format:
        PROMPT 1: [vollständiger, eigenständiger englischer Bild-Prompt, 60-120 Wörter, sofort einfügbar]
        PROMPT 2: [zweites, deutlich anderes Konzept – andere Bildidee/Komposition]
        PROMPT 3: [drittes, deutlich anderes Konzept]
        """
    }

    static func proofread(language: String, text: String) -> String {
        let quoteRule = language == "Deutsch"
            ? "Verwende durchgehend deutsche Anführungszeichen („…“). "
            : "Achte auf konsistente, sprachtypische Anführungszeichen. "
        return """
        Korrigiere den folgenden Romantext (Sprache: \(language)): Rechtschreibung, \
        Grammatik, Zeichensetzung, Tippfehler, doppelte Wörter, inkonsistente \
        Anführungszeichen. \(quoteRule)Ändere NICHT den Stil und NICHT den Inhalt. \
        Szenentrenner (***) müssen exakt erhalten bleiben. \
        Gib NUR den vollständigen korrigierten Text aus, ohne Kommentare.

        TEXT:
        \(text)
        """
    }

    /// Einmalige Nachbesserung deutlich zu kurzer Szenen (Qualitäts-Gate).
    /// Erweitert ein KOMPLETTES Kapitel auf mehr Umfang, OHNE die Handlung zu verändern –
    /// Kontext (bisherige Handlung, Figuren/Welt, Genre) hält alles konsistent und sinnvoll.
    static func expandChapter(language: String, style: String, genre: String, bookTitle: String,
                              chapterNumber: Int, chapterTitle: String, currentText: String,
                              targetWords: Int, charactersSummary: String, storySoFar: String,
                              genreBrief: String = "") -> String {
        return """
        Erweitere Kapitel \(chapterNumber) ("\(chapterTitle)") des Romans "\(bookTitle)" auf ca. \(targetWords) Wörter, OHNE die Handlung zu verändern.
        Sprache: \(language). Stil: \(style). Genre: \(genre).
        \(genreDirectiveBlock(genreBrief))
        ABSOLUT VERBINDLICH (sonst ergibt das Buch keinen Sinn mehr):
        - Alle Ereignisse, Entscheidungen, Enthüllungen und der Ausgang des Kapitels bleiben EXAKT gleich. Erfinde NICHTS hinzu, was der bisherigen oder folgenden Handlung widerspricht.
        - Figuren, Namen, Beziehungen, Orte, Tageszeit und der Zeitablauf bleiben konsistent mit den Vorgaben.
        - Der erste und der letzte Beat des Kapitels bleiben inhaltlich erhalten (sauberer Anschluss an die Nachbarkapitel).
        - Erweitere durch TIEFE, nicht durch Wiederholung: Szenen voll ausspielen statt zusammenfassen; mehr konkrete Sinnesdetails, Dialog mit Subtext, sparsame innere Reaktion, kleine zum Beat passende Zwischenmomente, Atmosphäre und Tempo-Wechsel. KEINE Füllsätze, nichts doppelt erzählen, das Thema nie ausbuchstabieren.
        - Reiner deutscher Fließtext, keine Markdown-Symbole, keine Überschriften, keine Meta-Kommentare.

        FIGUREN/WELT (konsistent halten):
        \(charactersSummary.truncated(to: 1500))

        BISHERIGE HANDLUNG (für Kontinuität, nicht wiederholen):
        \(storySoFar.isEmpty ? "Dies ist das erste Kapitel." : storySoFar.truncated(to: 6000))

        AKTUELLER KAPITELTEXT (erweitern, Handlung bewahren):
        \(currentText.truncated(to: 30000))

        Gib NUR den vollständigen erweiterten Kapiteltext aus.
        """
    }

    static func expandScene(language: String, style: String, text: String, targetWords: Int,
                            charactersSummary: String = "", previousSceneEnding: String = "",
                            genreBrief: String = "") -> String {
        // Vorher lief die Nachbesserung der SCHWÄCHSTEN Szenen ausgerechnet ohne Kontext
        // und ohne Handwerksregeln – und lud mit „Innenleben vertiefen" genau zu den
        // KI-Floskeln ein, die überall sonst verboten sind.
        let charactersBlock = charactersSummary.isEmpty ? "" :
            "\nFIGUREN (kanonisch, konsistent halten):\n\(charactersSummary.truncated(to: 1000))\n"
        let anchorBlock = previousSceneEnding.isEmpty ? "" :
            "\nDIE SZENE MUSS WEITER NAHTLOS AN DIESES VORSZENEN-ENDE ANSCHLIESSEN:\n„…\(previousSceneEnding)“\n"
        return """
        Die folgende Romanszene ist zu kurz. Erweitere sie auf ca. \(targetWords) Wörter, \
        OHNE die Handlung zu verändern: Spiele Momente voll aus (konkrete Handlung, Dialog \
        mit Subtext, spezifische Sinnesdetails) statt zusammenzufassen. Füge keine neuen \
        Ereignisse oder Figuren hinzu. Innere Reaktionen SPARSAM – keine Floskel-Innenschau.
        Sprache: \(language). Stil: \(style).
        \(genreDirectiveBlock(genreBrief))\(charactersBlock)\(anchorBlock)
        \(humanCraftRules)
        Gib NUR den vollständigen erweiterten Szenentext aus, ohne Kommentare.

        SZENE:
        \(text)
        """
    }

    /// Lektor-Chat: Frage zum Buch beantworten oder Wunsch besprechen.
    static func editorChat(instruction: String, bookContext: String) -> String {
        """
        Du bist der Lektor des folgenden Romans und hilfst dem Autor. Antworte konkret, \
        ehrlich und auf Deutsch. Wenn der Autor eine Änderung an einem bestimmten Kapitel \
        wünscht, sage ihm, dass er das Kapitel links auswählen kann, damit du es direkt \
        überarbeitest. Halte dich kurz.

        BUCH:
        \(bookContext)

        AUTOR: \(instruction)
        """
    }

    /// Lektor-Revision: ein Kapitel exakt nach dem Wunsch des Autors überarbeiten.
    static func editorRevise(instruction: String, chapterTitle: String, language: String, currentText: String) -> String {
        """
        Überarbeite das folgende Kapitel „\(chapterTitle)“ eines Romans GENAU nach diesem Wunsch des Autors:
        WUNSCH: \(instruction)

        Behalte Handlung, Figuren und Kontinuität bei; ändere nur, was der Wunsch verlangt. \
        Schreibe lebendige Prosa auf \(language), Bestseller-Niveau, ohne Floskeln und ohne \
        Gedankenstriche als Stilmittel. Gib AUSSCHLIESSLICH den vollständigen überarbeiteten \
        Kapiteltext aus – keine Anweisungen, Labels, Überschriften oder Erklärungen.

        AKTUELLER KAPITELTEXT:
        \(currentText)
        """
    }

    /// Manuskript-Audit nach dem Proofreading: findet nur echte Reparaturfälle.
    static func repairAudit(bookTitle: String, summaries: String, characters: String,
                            qualityReports: String, tropes: String = "",
                            isNonfiction: Bool = false) -> String {
        if isNonfiction {
            return """
            Prüfe das Sachbuch "\(bookTitle)" nach dem Korrektorat auf reparaturpflichtige Stellen:
            sachliche Widersprüche, unklare Begriffe, Redundanz, fehlende Zwischenschritte,
            ungeeignete Beispiele, nicht umsetzbare Anweisungen, unbelegte Gewissheiten, erfundene
            Quellen/Statistiken und absolute Erfolgs-, Heilungs- oder Einkommensversprechen.
            Fehlende Quellen werden mit [QUELLE PRÜFEN] markiert, niemals erfunden.

            KAPITEL:
            \(summaries)
            BERICHTE:
            \(qualityReports.isEmpty ? "Keine Befunde." : qualityReports)

            Antworte nur mit einer Zeile pro Befund:
            REPAIR|Schweregrad|Kapitel|Fehlerquelle/Bereich|Problem|Konkrete Reparaturanweisung
            Wenn alles stimmig ist: KEINE REPARATUR NÖTIG
            """
        }
        let tropesBlock = tropes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" :
            "\n        - TROPE-LIEFERUNG prüfen: Werden die zugesagten Tropes (\(tropes)) deutlich und befriedigend eingelöst? Fehlt oder verpufft ein Trope, ist das reparaturpflichtig (Fehlerquelle: Trope) – Anweisung: den betroffenen Moment so schärfen, dass der Trope spürbar geliefert wird."
        return """
        Prüfe den Roman „\(bookTitle)" nach dem Proofreading auf echte reparaturpflichtige Stellen.
        Suche Widersprüche in Zeitlinie, Figurenwissen, Motivation, Schauplätzen, Kontinuität,
        Stilbrüche, Wiederholungen, Logiklöcher und unklare Kausalität.

        WICHTIG:
        - Melde nur Probleme, die im Text wirklich repariert werden müssen.
        - Keine Geschmackskommentare und keine allgemeinen Schreibratschläge.
        - Benenne die konkrete Fehlerquelle: Zeitlinie, Figurenwissen, Motivation, Logik,
          Wiederholung, Stilbruch, Perspektive oder Anschlussfehler.
        - Formuliere die Reparaturanweisung so, dass sie automatisch behoben werden kann.
        - Wenn alles stimmig ist, antworte exakt: KEINE REPARATUR NÖTIG
        - Wenn ein Problem klar einem Kapitel zuordenbar ist, nenne dieses Kapitel.
        - Wenn ein Problem mehrere Kapitel betrifft, schreibe eine eigene REPAIR-Zeile pro
          betroffenem Kapitel, damit die App diese Kapitel automatisch korrigieren kann.
        - Nutze "Gesamtmanuskript" nur, wenn keine konkrete Textreparatur möglich ist.
        - Stütze Befunde zu Wortlaut, Anschluss und Kontinuität auf die mitgelieferten Textauszüge.
        - ENDE-ABNAHME (Pflicht): Prüfe die LETZTEN beiden Kapitel besonders streng – wird die
          zentrale Frage des Buches klar beantwortet? Bleiben benannte offene Fäden ungelöst
          (die OFFEN-Punkte der Handlungsübersicht)? Wirkt das Ende gehetzt, abrupt oder surreal?
          Bei Liebesromanen: Gibt es eine emotionale Auszahlung (HEA/HFN)? Jeder Mangel am Ende
          ist reparaturpflichtig (Fehlerquelle: Logik oder Motivation) – schwache Enden sind der
          häufigste Grund für schlechte Rezensionen.\(tropesBlock)
        - Prüfe AUCH die Lesesog-/Bestseller-Qualität: ein schwaches Kapitel-Ende ohne Haken/
          Cliffhanger, flache oder durchhängende Spannung, ein nicht eingelöstes Genre-Versprechen
          oder ein zäher Einstieg sind reparaturpflichtig (Fehlerquelle: Spannung). Reparaturanweisung
          dann: Kapitel-Schluss zu einem Sog/Haken schärfen bzw. Stakes/Spannung der Stelle anheben –
          ohne Fakten, Figuren oder Struktur zu ändern.

        KAPITEL (Zusammenfassung + echter Textauszug):
        \(summaries)

        FIGUREN:
        \(characters.isEmpty ? "Keine Figurenliste vorhanden." : characters)

        BISHERIGE QUALITÄTSBERICHTE:
        \(qualityReports.isEmpty ? "Keine Befunde." : qualityReports)

        Antworte ausschließlich in diesem Format, eine Zeile pro Befund:
        REPAIR|Schweregrad|Kapitel|Fehlerquelle/Bereich|Problem|Konkrete Reparaturanweisung

        Schweregrad ist Kritisch, Fehler, Warnung oder Info.
        Kapitel ist z.B. "Kapitel 7" oder "Gesamtmanuskript".
        """
    }

    /// Gezielte Reparatur eines Kapitels nach einem Audit-Befund.
    static func repairChapter(language: String, bookTitle: String, chapterNumber: Int,
                              chapterTitle: String, issue: RepairIssue, chapterText: String,
                              isNonfiction: Bool = false) -> String {
        if isNonfiction {
            return """
            Repariere Kapitel \(chapterNumber) "\(chapterTitle)" aus dem Sachbuch "\(bookTitle)".
            Sprache: \(language)
            Befund: \(issue.area) | \(issue.problem)
            Auftrag: \(issue.instruction)

            Behebe gezielt die betroffene Stelle und notwendige Anschlüsse. Erhalte funktionierende
            Erklärungen, Reihenfolge, Beispiele, Übungen und Abschnittstrenner. Erfinde niemals Fakten,
            Quellen, Studien, Statistiken oder Zitate. Fehlt ein notwendiger Beleg, markiere [QUELLE PRÜFEN].
            Gib nur den vollständigen reparierten Kapiteltext aus.

            KAPITELTEXT:
            \(chapterText)
            """
        }
        return """
        Repariere Kapitel \(chapterNumber) „\(chapterTitle)" aus dem Roman „\(bookTitle)".
        Sprache: \(language)

        BEFUND:
        Fehlerquelle: \(issue.area)
        Problem: \(issue.problem)
        Reparaturanweisung: \(issue.instruction)

        Arbeite chirurgisch: Behebe zuerst die Fehlerquelle, dann repariere NUR die betroffene Stelle und die direkt notwendigen
        Anschlussformulierungen. Schreibe nicht das ganze Kapitel neu, ändere keine funktionierenden
        Szenen, erfinde keine neuen Nebenplots und verschiebe keine Kapitelstruktur. Erhalte Stimme,
        Tempo, Figuren und vorhandene Dramaturgie. Liefere Proofreader-Qualität: glatt, konsistent,
        veröffentlichungsreif, ohne Kommentare und ohne Meta-Hinweise.

        Gib trotzdem den vollständigen reparierten Kapiteltext aus, damit die App ihn speichern kann.

        KAPITELTEXT:
        \(chapterText)
        """
    }

    /// „Blick ins Buch"-Optimierung: macht den Anfang (Amazon-Leseprobe) zu maximalem Lesesog.
    static func openingHook(language: String, bookTitle: String, genre: String, chapterText: String) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return """
            Überarbeite den Anfang der Amazon-Leseprobe des Sachbuchs "\(bookTitle)" auf \(language).
            Der Leser erkennt auf der ersten Seite sein konkretes Problem, den realistischen Nutzen
            des Buches und erhält früh eine kleine verwertbare Erkenntnis. Kein dramatischer Roman-Hook,
            keine Angstwerbung, keine Erfolgs- oder Heilungsgarantie und kein langes Vorwort.
            Erhalte Fakten, Grenzen und Inhalt. Erfinde keine Quellen oder Statistiken.
            Gib nur den vollständigen überarbeiteten Kapiteltext aus.

            KAPITELTEXT:
            \(chapterText)
            """
        }
        return """
        Überarbeite den ANFANG (Blick ins Buch / Amazon-Leseprobe) von „\(bookTitle)"
        (Genre: \(genre), Sprache: \(language)) zu unwiderstehlichem Lesesog. Die ersten Sätze
        entscheiden über den Kauf.

        PFLICHT:
        - Erste Zeile = sofortiger Hook (Spannung, Frage, Irritation, starke Stimme). KEIN Wetter,
          kein Aufwachen, kein Info-Dump, kein Prolog-Geschwafel.
        - Sofort eine konkrete Figur in einem konkreten Moment mit etwas auf dem Spiel.
        - Zeigen statt erklären; eigene, sofort erkennbare Erzählstimme; konkrete Sinnesdetails.
        - Eine Spannungsfrage, die zum Weiterlesen zwingt, bleibt am Ende des Auszugs offen.
        - Erhalte Figuren, Setting, Fakten und Handlung des Kapitels – ändere NUR Anziehung/Sog
          und Formulierung, nicht das Geschehen.
        - Reine Prosa, keine Überschriften, keine Kommentare, keine Meta-Hinweise.

        KAPITELTEXT:
        \(chapterText)

        Gib den vollständigen, überarbeiteten Kapiteltext aus.
        """
    }

    /// Serie/Read-Through: baut am Ende des letzten Kapitels einen Cliffhanger + Teaser aufs
    /// nächste Buch ein – der stärkste Hebel, damit Leser den Folgeband kaufen.
    static func cliffhangerTeaser(language: String, bookTitle: String, genre: String,
                                  seriesName: String, chapterText: String) -> String {
        if BookContentType.infer(from: genre) == .nonfiction {
            return """
            Überarbeite das Ende des Sachbuchs "\(bookTitle)" auf \(language) für eine Reihe.
            Der Lernweg dieses Bandes bleibt vollständig abgeschlossen. Füge am Ende einen kurzen,
            sachlichen Ausblick hinzu, welches weiterführende Problem ein nächster Band vertiefen kann,
            ohne künstlichen Cliffhanger, Verkaufsdruck oder unerfülltes Versprechen.
            Gib nur den vollständigen überarbeiteten Kapiteltext aus.

            KAPITELTEXT:
            \(chapterText)
            """
        }
        let seriesLine = seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "" : "Reihe: \(seriesName)\n"
        return """
        Überarbeite das ENDE des letzten Kapitels von „\(bookTitle)" (Genre: \(genre), Sprache:
        \(language)) so, dass es Lust auf den nächsten Band macht (Read-Through auf Kindle).
        \(seriesLine)
        PFLICHT:
        - Der eigene Handlungsbogen DIESES Buches bleibt befriedigend abgeschlossen – kein Betrug am Leser.
        - Setze GANZ AM ENDE einen starken Haken/Cliffhanger: eine neue Bedrohung, offene Frage oder
          Wendung, die klar auf einen Folgeband zeigt – emotional, konkret.
        - Ändere keine Fakten/Figuren; erweitere/schärfe nur das Ende.
        - Reine Prosa, keine Überschriften, keine Meta-Hinweise wie „Fortsetzung folgt".

        KAPITELTEXT (letztes Kapitel):
        \(chapterText)

        Gib den vollständigen, überarbeiteten Kapiteltext aus.
        """
    }

    private static func nonfictionBrief(title: String, genre: String, subgenre: String?,
                                        language: String) -> String {
        let fullGenre = [genre, subgenre].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
        return """
        SACHBUCH-DIREKTIVE (verbindlich)
        TITEL: \(title)
        KATEGORIE: \(fullGenre)
        SPRACHE: \(language)
        LESERPROBLEM: [welches konkrete Problem der Leser lösen will]
        NUTZENVERSPRECHEN: [realistische, beobachtbare Veränderung nach der Lektüre]
        ZIELGRUPPE UND VORWISSEN: [präzise]
        METHODE: [roter Faden und praktischer Ansatz]
        PFLICHTELEMENTE: [Beispiele, Übungen, Checklisten, Zusammenfassungen]
        TON: [klar, respektvoll, konkret, ohne Belehrung]
        ABGRENZUNG: [was das Buch ausdrücklich nicht verspricht oder behandelt]
        \(NonfictionSafety.directive(genre: genre))
        """
    }

    private static func nonfictionConcept(title: String, genre: String, subgenre: String?,
                                          language: String, style: String, tonality: String,
                                          audience: String, pageCount: Int, ideaSeed: String,
                                          researchContext: String) -> String {
        let fullGenre = [genre, subgenre].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " / ")
        return """
        Entwickle ein fundiertes, praktisch nutzbares Sachbuchkonzept.
        Titel: \(title) | Kategorie: \(fullGenre) | Sprache: \(language)
        Stil: \(style) | Ton: \(tonality) | Zielgruppe: \(audience)
        Zielumfang: ca. \(pageCount) Seiten
        Ausgangsidee: \(ideaSeed.isEmpty ? "frei entwickeln" : ideaSeed)

        \(researchContext)

        Das Buch löst ein konkretes Leserproblem. Definiere Ausgangslage, realistische Transformation,
        Vorwissen, Grenzen, Kernmethode und den praktischen Weg. Keine Romanhandlung, erfundenen Figuren
        oder künstliche Cliffhanger. Plane nur Inhalte, die verantwortbar erklärt werden können.
        \(NonfictionSafety.directive(genre: genre, premise: ideaSeed))

        Antworte exakt mit diesen Labels:
        PRÄMISSE: [Leserproblem und Nutzenversprechen in 1-2 Sätzen]
        LOGLINE: [ein klarer Verkaufssatz ohne Garantie]
        EXPOSÉ: [5-8 Sätze: Ausgangslage, Methode, Lernweg, Anwendung und Ergebnis]
        HAUPTKONFLIKT: [größtes praktisches Hindernis des Lesers]
        THEMA: [1-3 Wörter]
        ZIELGRUPPE: [Vorwissen, Situation und Bedarf]
        """
    }

    private static func nonfictionArchitecture(title: String, genre: String, style: String,
                                               concept: String, pageCount: Int, chapterCount: Int,
                                               genreBrief: String, researchContext: String) -> String {
        """
        SACHBUCH-ARCHITEKTUR
        Erstelle die vollständige Wissens- und Lernarchitektur für "\(title)".
        Kategorie: \(genre) | Stil: \(style) | ca. \(pageCount) Seiten / \(chapterCount) Kapitel

        KONZEPT:
        \(concept)
        \(genreDirectiveBlock(genreBrief))
        \(researchContext)
        \(NonfictionSafety.directive(genre: genre, premise: concept))

        Ordne den Inhalt kausal: Orientierung und Begriffe, Grundlagen, Kernmethode, schrittweise
        Anwendung, typische Hindernisse und Fehler, Vertiefung, Transfer in den Alltag, nachhaltiger
        Umsetzungsplan. Jedes Kapitel muss auf Vorwissen aufbauen und einen eigenständigen Nutzen haben.
        Plane konkrete Beispiele, Übungen, Checklisten und Kapitelzusammenfassungen. Vermeide Redundanz,
        Füllkapitel und bloße Motivation ohne anwendbaren Inhalt. Markiere alle Punkte, für die vor
        Veröffentlichung aktuelle oder fachliche Quellen geprüft werden müssen, mit [QUELLE PRÜFEN].
        Schreibe als klar gegliederte Gesamtarchitektur.
        """
    }

    private static func nonfictionChapterPlan(title: String, genre: String, architecture: String,
                                              chapterCount: Int, wordsPerChapter: Int,
                                              sectionsPerChapter: Int, genreBrief: String) -> String {
        """
        Plane GENAU \(chapterCount) Kapitel für das \(genre) "\(title)" mit durchschnittlich
        \(wordsPerChapter) Wörtern. Jedes Kapitel enthält mindestens \(sectionsPerChapter) sinnvolle
        Abschnitte, aber Länge und Rhythmus dürfen nach Lernbedarf variieren.

        \(architecture.truncated(to: 7000))
        \(genreDirectiveBlock(genreBrief))

        Regeln: klare Lernprogression, keine Wiederholung, pro Kapitel ein messbares Lernziel,
        mindestens ein konkretes Beispiel oder eine Anwendung und ein umsetzbarer Abschluss.
        Kapitelüberschriften sind klar und nutzenorientiert, nicht reißerisch.

        Gib exakt eine Zeile pro Kapitel aus:
        KAPITEL|Nummer|Titel|Lernziel des Kapitels|Zentrales Leserhindernis|Konkretes Ergebnis
        """
    }

    private static func nonfictionSectionPlan(bookTitle: String, chapterNumber: Int,
                                              chapterTitle: String, chapterGoal: String,
                                              chapterChallenge: String, architecture: String,
                                              targetWords: Int, sectionCount: Int,
                                              isFinalChapter: Bool) -> String {
        """
        Plane mindestens \(sectionCount) Abschnitte für Kapitel \(chapterNumber) "\(chapterTitle)"
        aus "\(bookTitle)". Lernziel: \(chapterGoal). Leserhindernis: \(chapterChallenge).
        Zielumfang: \(targetWords) Wörter.
        SACHBUCH-ARCHITEKTUR: \(architecture.truncated(to: 3500))

        Jeder Abschnitt erfüllt genau eine Funktion: erklären, demonstrieren, anwenden, reflektieren,
        Fehler vermeiden oder zusammenfassen. Baue vom Einfachen zum Anspruchsvollen auf. Das Kapitel
        endet mit einem konkreten Ergebnis, einer CHECKLISTE, Übung oder nächsten Handlung, nicht mit
        einem Roman-Cliffhanger. \(isFinalChapter ? "Das Schlusskapitel bündelt den Transfer in einen realistischen Umsetzungsplan." : "")

        Gib exakt eine Zeile pro Abschnitt aus:
        SZENE|Nummer|Leser|Abschnittstyp|Reihenfolge|Lernziel|Typisches Hindernis|Take-away oder Anwendung
        """
    }

    private static func nonfictionDraftSection(language: String, style: String, tonality: String,
                                                genre: String, bookTitle: String,
                                                chapterNumber: Int, chapterTitle: String,
                                                chapterGoal: String, sectionNumber: Int,
                                                sectionGoal: String, sectionKind: String,
                                                sequence: String, readerObstacle: String,
                                                takeaway: String, priorContent: String,
                                                targetWords: Int, isFirst: Bool, isFinal: Bool,
                                                researchContext: String,
                                                manuscriptAvoidance: String) -> String {
        let avoidanceBlock = manuscriptAvoidance.isEmpty ? "" : """

        WÖRTLICHE SPERRLISTE AUS DEM BISHERIGEN MANUSKRIPT:
        \(manuscriptAvoidance)
        Keinen dieser Sätze erneut verwenden. Formuliere jede Erklärung, Überleitung und
        Handlungsaufforderung konkret für diesen Abschnitt.
        """
        return """
        Schreibe Abschnitt \(sectionNumber) aus Kapitel \(chapterNumber) "\(chapterTitle)" des
        Sachbuchs "\(bookTitle)". Sprache: \(language), Stil: \(style), Ton: \(tonality).
        Kapitelziel: \(chapterGoal)
        Abschnittsfunktion: \(sectionKind) | Reihenfolge: \(sequence)
        Lernziel: \(sectionGoal) | Leserhindernis: \(readerObstacle)
        Take-away: \(takeaway) | Zielumfang: ca. \(targetWords) Wörter
        \(isFirst ? "Einstieg: Problem und unmittelbaren Nutzen ohne langes Vorwort klarmachen." : "")
        \(isFinal ? "Abschluss: Erkenntnisse bündeln und in einen realistischen nächsten Schritt überführen." : "")

        BISHERIGER INHALT:
        \(priorContent.truncated(to: 8000))

        \(researchContext.truncated(to: 6_000))
        \(avoidanceBlock)

        Schreibe klar, konkret und respektvoll. Erkläre Begriffe beim ersten Auftreten. Verwende
        anschauliche, eindeutig illustrative Beispiele, praktische Schritte und bei passender Funktion
        eine ÜBUNG oder CHECKLISTE. Keine redundanten Motivationsfloskeln, keine Romanhandlung und keine
        künstlichen Cliffhanger. Fakten, Studien, Statistiken, Zitate und Quellen niemals erfinden.
        Quellenabhängige Tatsachen direkt mit ihrer vorhandenen [Qn]-Nummer belegen. Verwende nur
        Nummern aus der Quellenbasis; allgemeine Übergänge und eigene praktische Anleitungen brauchen
        keinen Scheinbeleg. Eine Quelle nie weiter auslegen, als ihr Auszug trägt.
        \(NonfictionSafety.directive(genre: genre))

        Gib ausschließlich den fertigen Buchtext dieses Abschnitts aus, ohne Meta-Kommentar oder Markdown.
        """
    }

    private static func nonfictionRevision(language: String, style: String, tonality: String,
                                           chapterNumber: Int, chapterTitle: String, text: String,
                                           genreBrief: String, overusedPhrases: String,
                                           targetWords: Int, researchContext: String) -> String {
        """
        Überarbeite Kapitel \(chapterNumber) "\(chapterTitle)" eines Sachbuchs auf \(language).
        Stil: \(style), Ton: \(tonality), Zielumfang: ca. \(targetWords) Wörter.
        \(genreBrief)
        \(researchContext.truncated(to: 5_000))

        Prüfe roten Faden, Verständlichkeit, sachliche Widersprüche, Redundanz, Umsetzbarkeit,
        Zielgruppennutzen und saubere Trennung von Fakten, Meinung und Beispiel. Entferne unbelegte
        Gewissheiten, erfundene Quellen/Statistiken und absolute Versprechen. Fehlende aktuelle Belege
        nicht erfinden, sondern mit [QUELLE PRÜFEN] markieren. Erhalte inhaltlich notwendige Schritte,
        Beispiele, Übungen und Abschnittstrenner.
        Prüfe alle [Qn]-Verweise gegen die Quellenbasis und erfinde keine neue Quellennummer.
        Überstrapazierte Formulierungen: \(overusedPhrases.isEmpty ? "keine gemeldet" : overusedPhrases)

        Gib nur den vollständigen überarbeiteten Kapiteltext aus.
        TEXT:
        \(text)
        """
    }

    private static func nonfictionKDPMetadata(title: String, author: String, authorBio: String,
                                              genre: String, audience: String, synopsis: String,
                                              language: String) -> String {
        """
        Erstelle seriöse Amazon-KDP-Metadaten für das \(genre) "\(title)" von \(author).
        Zielgruppe: \(audience) | Sprache: \(language)
        Inhalt: \(synopsis.truncated(to: 3500))
        Autorprofil: \(authorBio.truncated(to: 700))

        Titel und Untertitel benennen Problem, Zielgruppe, Methode und realistischen Nutzen klar.
        Kein Clickbait, Keyword-Spam, "Bestseller", Heilungs-, Erfolgs- oder Einkommensversprechen.
        Keine erfundenen Qualifikationen oder Belege. Keine Hinweise auf Produktionswerkzeuge.

        Antworte exakt:
        VERKAUFSTITEL: [klarer, glaubwürdiger Haupttitel]
        UNTERTITEL: [natürlicher suchnaher Untertitel mit Zielgruppe und Nutzen]
        VERKAUFSTEXT: [150-220 Wörter: Problem, Nutzen, Inhalt, Anwendung, klare Kaufentscheidung]
        KEYWORDS: [genau 7 unterschiedliche Long-Tail-Suchbegriffe]
        KATEGORIEN: [3 passende, spezifische Amazon-Kindle-Kategorien, je eine Zeile]
        """
    }
}

// MARK: - Parser für strukturierte Agenten-Antworten

struct ConceptResult {
    var premise = ""
    var logline = ""
    var synopsis = ""
    var mainConflict = ""
    var theme = ""
    var audience = ""
}

enum AuthorBioParser {
    static func parse(_ text: String) -> [String] {
        var results: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.uppercased().hasPrefix("BIO|") else { continue }
            let bio = String(line.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            if bio.wordCount >= 20, !results.contains(bio) { results.append(bio) }
        }
        return Array(results.prefix(3))
    }
}

enum AuthorBioQuality {
    private static let factMarkers = [
        "studiert", "studium", "abschluss", "ausbildung", "ausgebildet", "beruf",
        "arbeitet", "wohnort", "wohnt", "lebt in", "mutter", "vater", "kinder",
        "jahre erfahrung", "langjährig", "ausgezeichnet", "preisgekrönt", "bestseller",
        "veröffentlicht", "experte", "expertin", "coach", "therapeut", "therapeutin",
        "arzt", "ärztin", "aus eigener erfahrung", "kennt aus eigener"
    ]

    static func isGrounded(_ bio: String, facts: String) -> Bool {
        let candidate = normalize(bio)
        let provided = normalize(facts)
        guard bio.wordCount >= 20, bio.wordCount <= 120 else { return false }
        return factMarkers.allSatisfy { marker in
            !candidate.contains(marker) || provided.contains(marker)
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

enum ConceptParser {
    private static let labelMap: [String: String] = [
        "PRÄMISSE": "premise", "PRAEMISSE": "premise", "PREMISE": "premise",
        "LOGLINE": "logline",
        "EXPOSÉ": "synopsis", "EXPOSE": "synopsis", "SYNOPSIS": "synopsis",
        "HAUPTKONFLIKT": "mainConflict",
        "THEMA": "theme", "THEME": "theme",
        "ZIELGRUPPE": "audience"
    ]

    static func parse(_ text: String) -> ConceptResult {
        var sections: [String: String] = [:]
        var currentKey: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let cleaned = rawLine
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)

            var matched = false
            for (label, key) in labelMap {
                if cleaned.uppercased().hasPrefix(label + ":") {
                    let value = String(cleaned.dropFirst(label.count + 1)).trimmingCharacters(in: .whitespaces)
                    sections[key] = value
                    currentKey = key
                    matched = true
                    break
                }
            }
            if !matched, let key = currentKey, !cleaned.isEmpty {
                let existing = sections[key] ?? ""
                sections[key] = existing.isEmpty ? cleaned : existing + "\n" + cleaned
            }
        }

        var result = ConceptResult()
        result.premise = sections["premise"] ?? ""
        result.logline = sections["logline"] ?? ""
        result.synopsis = sections["synopsis"] ?? ""
        result.mainConflict = sections["mainConflict"] ?? ""
        result.theme = sections["theme"] ?? ""
        result.audience = sections["audience"] ?? ""
        return result
    }
}

struct KDPMetadataResult {
    var salesTitle = ""
    var subtitle = ""
    var salesDescription = ""
    var keywords = ""
    var categories = ""
}

enum KDPMetadataParser {
    static func parse(_ text: String) -> KDPMetadataResult {
        let labels = ["VERKAUFSTITEL", "UNTERTITEL", "VERKAUFSTEXT", "KEYWORDS", "KATEGORIEN"]
        var sections: [String: String] = [:]
        var currentLabel: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let cleaned = rawLine
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)

            var matched = false
            for label in labels {
                if cleaned.uppercased().hasPrefix(label + ":") {
                    let value = String(cleaned.dropFirst(label.count + 1)).trimmingCharacters(in: .whitespaces)
                    sections[label] = value
                    currentLabel = label
                    matched = true
                    break
                }
            }
            if !matched, let label = currentLabel, !cleaned.isEmpty {
                let existing = sections[label] ?? ""
                sections[label] = existing.isEmpty ? cleaned : existing + "\n" + cleaned
            }
        }

        var result = KDPMetadataResult()
        result.salesTitle = sections["VERKAUFSTITEL"] ?? ""
        result.subtitle = sections["UNTERTITEL"] ?? ""
        result.salesDescription = sections["VERKAUFSTEXT"] ?? ""
        result.keywords = cappedKeywords(sections["KEYWORDS"] ?? "")
        result.categories = cappedCategories(sections["KATEGORIEN"] ?? "")
        return result
    }

    /// KDP erlaubt max. 7 Keyword-Slots: trimmen, leere/doppelte entfernen, auf 7 kappen.
    static func cappedKeywords(_ raw: String) -> String {
        var seen = Set<String>()
        let items = raw.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        return items.prefix(7).joined(separator: ", ")
    }

    /// KDP-Kategorien: eine pro Zeile, leere/doppelte entfernen, auf 3 kappen.
    static func cappedCategories(_ raw: String) -> String {
        var seen = Set<String>()
        let items = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        return items.prefix(3).joined(separator: "\n")
    }
}

struct RepairIssue {
    let severity: Severity
    let chapterNumber: Int?
    let area: String
    let problem: String
    let instruction: String
}

enum QualityReleasePolicy {
    static func isBlockingReport(autoFixed: Bool, severity: Severity) -> Bool {
        !autoFixed && (severity == .critical || severity == .error)
    }
}

enum RepairIssueParser {
    static func isConclusiveAuditResponse(_ text: String) -> Bool {
        !parse(text).isEmpty
            || text.localizedCaseInsensitiveContains("KEINE REPARATUR NÖTIG")
    }

    static func parse(_ text: String) -> [RepairIssue] {
        var result: [RepairIssue] = []
        for line in text.components(separatedBy: .newlines) {
            guard let pipe = line.firstIndex(of: "|") else { continue }
            let head = String(line[..<pipe])
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t-•·.)("))
                .uppercased()
            guard head.hasPrefix("REPAIR") else { continue }

            let payload = String(line[line.index(after: pipe)...])
            let parts = payload.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "**", with: "")
            }
            guard parts.count >= 5 else { continue }
            let problem = parts[3]
            let instruction = parts.dropFirst(4).joined(separator: " | ")
            guard !problem.isEmpty, !instruction.isEmpty else { continue }

            result.append(RepairIssue(
                severity: severity(from: parts[0]),
                chapterNumber: chapterNumber(from: parts[1]),
                area: parts[2].isEmpty ? "Allgemein" : parts[2],
                problem: problem,
                instruction: instruction
            ))
        }
        return result
    }

    /// Modelle fassen gelegentlich einen Widerspruch über mehrere Kapitel als
    /// `Gesamtmanuskript` zusammen. Für die automatische Reparatur wird daraus ein
    /// identischer, kapitelgenauer Auftrag pro ausdrücklich genannter Kapitelnummer.
    static func expandingGlobalChapterReferences(_ issues: [RepairIssue]) -> [RepairIssue] {
        issues.flatMap { issue in
            guard issue.chapterNumber == nil else { return [issue] }
            let source = issue.problem + " " + issue.instruction
            guard let expression = try? NSRegularExpression(
                pattern: #"(?i)\bkapitel\s+(\d+)\b"#
            ) else { return [issue] }
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            var seen = Set<Int>()
            let chapters = expression.matches(in: source, range: range).compactMap { match -> Int? in
                guard let numberRange = Range(match.range(at: 1), in: source),
                      let number = Int(source[numberRange]),
                      seen.insert(number).inserted else { return nil }
                return number
            }
            guard !chapters.isEmpty else { return [issue] }
            return chapters.map { chapterNumber in
                RepairIssue(
                    severity: issue.severity,
                    chapterNumber: chapterNumber,
                    area: issue.area,
                    problem: issue.problem,
                    instruction: issue.instruction
                )
            }
        }
    }

    private static func severity(from text: String) -> Severity {
        let lowered = text.lowercased()
        if lowered.contains("krit") { return .critical }
        if lowered.contains("fehler") || lowered.contains("hoch") { return .error }
        if lowered.contains("warn") || lowered.contains("mittel") { return .warning }
        return .info
    }

    private static func chapterNumber(from text: String) -> Int? {
        if text.lowercased().contains("gesamt") { return nil }
        // Nur die ERSTE Zahlengruppe nehmen: "Kapitel 12-14" -> 12, "Kap. 3 (S. 40)" -> 3.
        // Sonst würden alle Ziffern verkettet (1214/340) und der Befund verpufft.
        guard let range = text.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(text[range])
    }
}

struct PlannedChapter {
    let number: Int
    let title: String
    let goal: String
    let conflict: String
}

struct PlannedScene {
    let number: Int
    let perspective: String
    let location: String
    let time: String
    let goal: String
    let obstacle: String
    let turn: String
}

struct ParsedCharacter {
    let name: String
    let role: String
    let age: String
    let occupation: String
    let goal: String
    let fear: String
    let weakness: String
    var speech: String = ""
    var appearance: String = ""
    var relationships: String = ""
    var canonicalFacts: String = ""
}

struct ParsedIssue {
    let severity: Severity
    let area: String
    let message: String
    let recommendation: String
}

struct ParsedIdea {
    let title: String
    let genre: String
    let premise: String
}

enum StructureParser {

    /// Parst eine Liste viraler Titel (eine pro Zeile, mit/ohne "TITEL:"-Präfix,
    /// Nummerierung, Bullets oder Anführungszeichen). Dedupliziert, max. 10.
    static func parseTitleLines(_ text: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        let strip = CharacterSet(charactersIn: "\"'„“”»«*#-– ")
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: #"^\s*titel\s*:\s*"#, with: "",
                                             options: [.regularExpression, .caseInsensitive])
            line = line.replacingOccurrences(of: #"^\s*\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            line = line.trimmingCharacters(in: strip)
            guard line.count >= 2, line.count <= 70 else { continue }
            if seen.insert(line.lowercased()).inserted {
                out.append(line)
                if out.count >= 10 { break }
            }
        }
        return out
    }

    /// Zerlegt eine Zeile "MARKER|a|b|c" in ihre Felder. Toleriert führende
    /// Aufzählungszeichen, Markdown-Reste UND vom Modell eingefügte Nummern oder
    /// Doppelpunkte hinter dem Marker (z.B. "IDEE 1|…", "- **KAPITEL**: |…").
    /// Ohne diese Toleranz verwirft die Pipeline gültige Plan-Zeilen und die
    /// Qualitäts-Gates lassen die Produktion fälschlich scheitern.
    private static func fields(in line: String, marker: String) -> [String]? {
        guard let pipe = line.firstIndex(of: "|") else { return nil }
        let head = String(line[..<pipe])
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t-•·.)("))
            .uppercased()
        let upperMarker = marker.uppercased()
        guard head.hasPrefix(upperMarker) else { return nil }
        // Verhindert Falschtreffer wie "IDEENKERN" für Marker "IDEE":
        // direkt nach dem Marker darf kein weiterer Buchstabe folgen.
        let remainder = head.dropFirst(upperMarker.count)
        if let next = remainder.first, next.isLetter { return nil }

        let payload = String(line[line.index(after: pipe)...])
        return payload.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "**", with: "")
        }
    }

    /// Entfernt ein führendes reines Nummern-Feld. Modelle liefern die Nummer mal
    /// als eigenes Feld ("KAPITEL|1|Titel"), mal inline am Marker ("KAPITEL 1|Titel",
    /// dann von fields() bereits geschluckt). Dieses Angleichen sorgt dafür, dass
    /// Titel/Ziel/… in BEIDEN Fällen am selben Index liegen.
    private static func droppingLeadingNumber(_ parts: [String]) -> [String] {
        guard let first = parts.first, !first.isEmpty else { return parts }
        let isPureNumber = first.allSatisfy { $0.isNumber || $0 == "." || $0 == ")" || $0 == "#" }
        return isPureNumber ? Array(parts.dropFirst()) : parts
    }

    static func parseChapters(_ text: String) -> [PlannedChapter] {
        var result: [PlannedChapter] = []
        for line in text.components(separatedBy: .newlines) {
            guard let raw = fields(in: line, marker: "KAPITEL") else { continue }
            let parts = droppingLeadingNumber(raw)
            let title = parts.first ?? ""
            guard !title.isEmpty else { continue }
            // Emotionaler Schritt (4. Feld) wird ins Ziel gefaltet – so fließt der geplante
            // Gefühlsbogen ohne Schema-Änderung automatisch in Szenenplan und Prosa-Prompt.
            var goal = parts.count > 1 ? parts[1] : ""
            if parts.count > 3, !parts[3].isEmpty {
                goal += goal.isEmpty ? parts[3] : " – Emotionaler Schritt: \(parts[3])"
            }
            result.append(PlannedChapter(
                number: result.count + 1, // fortlaufend nummerieren, Modell-Nummern können lückenhaft sein
                title: title,
                goal: goal,
                conflict: parts.count > 2 ? parts[2] : ""
            ))
        }
        return entdoppelteTitel(result)
    }

    /// Macht fast gleiche Kapitelüberschriften auseinander.
    ///
    /// An zwei echten Büchern beobachtet: „Das Knirschen unter den Schuhen" / „Das
    /// Knirschen unter ihren Schuhen" und „Mira, die im Spiegel schrie" / „Mira, die im
    /// Spiegel wartete". Im Inhaltsverzeichnis fällt so etwas jedem Leser sofort auf.
    /// Der Wiederholungsschutz prüfte bisher nur den Fließtext, nie die Überschriften.
    ///
    /// Wird eine Überschrift als Dublette erkannt, tritt das Kapitelziel an ihre Stelle –
    /// ein Kapitel ohne eigene Überschrift wäre schlimmer als eine schlichte.
    static func entdoppelteTitel(_ kapitel: [PlannedChapter]) -> [PlannedChapter] {
        /// Inhaltstragende Wörter einer Überschrift, klein und ohne Füllwörter.
        func kern(_ titel: String) -> Set<String> {
            let stopp: Set<String> = ["der", "die", "das", "ein", "eine", "einer", "und", "oder",
                                      "von", "dem", "den", "des", "im", "in", "auf", "mit", "für",
                                      "ihr", "ihre", "ihren", "sein", "seine", "seinen", "nicht"]
            return Set(titel.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 3 && !stopp.contains($0) })
        }

        var ergebnis: [PlannedChapter] = []
        var gesehen: [Set<String>] = []
        for k in kapitel {
            let jetzt = kern(k.title)
            // Überschneidung von 60 % oder mehr gilt als Dublette – so wurden beide
            // beobachteten Fälle erkannt, ohne echte Motivketten zu zerstören.
            let dublette = !jetzt.isEmpty && gesehen.contains { alt in
                guard !alt.isEmpty else { return false }
                let gemeinsam = Double(alt.intersection(jetzt).count)
                return gemeinsam / Double(max(alt.count, jetzt.count)) >= 0.6
            }
            if dublette {
                // Aus dem Kapitelziel eine eigene Überschrift bilden (erste sinnvolle
                // Wortgruppe), sonst die Nummer – Hauptsache nicht zweimal dasselbe.
                let ausZiel = k.goal
                    .components(separatedBy: CharacterSet(charactersIn: ".,;–-"))
                    .first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let ersatz = ausZiel.count >= 8 ? String(ausZiel.prefix(48)) : "Kapitel \(k.number)"
                ergebnis.append(PlannedChapter(number: k.number, title: ersatz,
                                               goal: k.goal, conflict: k.conflict))
                gesehen.append(kern(ersatz))
            } else {
                ergebnis.append(k)
                gesehen.append(jetzt)
            }
        }
        return ergebnis
    }

    static func parseScenes(_ text: String) -> [PlannedScene] {
        var result: [PlannedScene] = []
        for line in text.components(separatedBy: .newlines) {
            guard let raw = fields(in: line, marker: "SZENE") else { continue }
            let parts = droppingLeadingNumber(raw)
            guard !parts.isEmpty else { continue }
            result.append(PlannedScene(
                number: result.count + 1,
                perspective: parts.first ?? "",
                location: parts.count > 1 ? parts[1] : "",
                time: parts.count > 2 ? parts[2] : "",
                goal: parts.count > 3 ? parts[3] : "",
                obstacle: parts.count > 4 ? parts[4] : "",
                turn: parts.count > 5 ? parts[5] : ""
            ))
        }
        return result
    }

    static func parseCharacters(_ text: String) -> [ParsedCharacter] {
        var result: [ParsedCharacter] = []
        for line in text.components(separatedBy: .newlines) {
            guard let parts = fields(in: line, marker: "FIGUR"), !parts.isEmpty else { continue }
            let name = parts[0]
            guard !name.isEmpty else { continue }
            result.append(ParsedCharacter(
                name: name,
                role: parts.count > 1 ? parts[1] : "Nebenfigur",
                age: parts.count > 2 ? parts[2] : "",
                occupation: parts.count > 3 ? parts[3] : "",
                goal: parts.count > 4 ? parts[4] : "",
                fear: parts.count > 5 ? parts[5] : "",
                weakness: parts.count > 6 ? parts[6] : "",
                speech: parts.count > 7 ? parts[7] : "",
                appearance: parts.count > 8 ? parts[8] : "",
                relationships: parts.count > 9 ? parts[9] : "",
                canonicalFacts: parts.count > 10 ? parts[10] : ""
            ))
        }
        return result
    }

    static func parseIdeas(_ text: String) -> [ParsedIdea] {
        var result: [ParsedIdea] = []
        for line in text.components(separatedBy: .newlines) {
            guard let parts = fields(in: line, marker: "IDEE"), parts.count >= 3 else { continue }
            guard !parts[0].isEmpty else { continue }
            result.append(ParsedIdea(title: parts[0], genre: parts[1], premise: parts[2]))
        }
        return result
    }

    static func parseIssues(_ text: String) -> [ParsedIssue] {
        var result: [ParsedIssue] = []
        for line in text.components(separatedBy: .newlines) {
            guard let parts = fields(in: line, marker: "PROBLEM"), parts.count >= 2 else { continue }
            let severityText = parts[0].lowercased()
            let severity: Severity
            if severityText.contains("krit") {
                severity = .critical
            } else if severityText.contains("fehler") || severityText.contains("hoch") {
                severity = .error
            } else if severityText.contains("warn") || severityText.contains("mittel") {
                severity = .warning
            } else {
                severity = .info
            }
            result.append(ParsedIssue(
                severity: severity,
                area: parts.count > 1 ? parts[1] : "Allgemein",
                message: parts.count > 2 ? parts[2] : parts[1],
                recommendation: parts.count > 3 ? parts[3] : ""
            ))
        }
        return result
    }
}
