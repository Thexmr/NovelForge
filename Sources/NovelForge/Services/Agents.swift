import Foundation

/// Namen der spezialisierten Agenten – erscheinen im Agenten-Monitor und im Protokoll.
enum AgentName {
    static let input = "Input Agent"
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
    static let copyright = "Copyright Checker"
    static let kdpFormatter = "KDP Formatter"
    static let exporter = "Export Agent"
}

// MARK: - Prompt-Vorlagen
// Alle Prompts arbeiten mit reinen Strings (keine SwiftData-Objekte),
// damit sie threadsicher außerhalb des MainActors verwendet werden können.

enum PromptFactory {

    /// Drei kommerziell vielversprechende Buchideen für den Wizard.
    static func bookIdeas(genre: String, language: String, avoidanceBrief: String = "") -> String {
        let memoryBlock = avoidanceBrief.isEmpty ? "" : "\n\(avoidanceBrief)\n"
        return """
        Entwickle 3 eigenständige, kommerziell vielversprechende Buchideen \
        (Genre-Schwerpunkt: \(genre.isEmpty ? "frei wählbar" : genre), Sprache: \(language)). \
        Jede Idee braucht einen frischen Dreh und einen klaren zentralen Konflikt – \
        keine Klischee-Plots, keine Anlehnung an bestehende Werke.
        \(memoryBlock)
        Bestseller-Pflicht: Jede Idee braucht eine sofort verständliche Zielgruppe, ein starkes Versprechen,
        eine emotionale Kernwunde der Hauptfigur, Eskalation mit hohem Einsatz und einen Hook, der als
        Amazon-KDP-Leseprobe schon auf Seite 1 funktioniert.

        Gib für JEDE Idee GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        IDEE|Titel|Genre|Prämisse in 2 Sätzen mit klarem Konflikt

        Keine weiteren Erklärungen.
        """
    }

    static func concept(title: String, genre: String, subgenre: String?, language: String,
                        style: String, tonality: String, audience: String,
                        perspective: String, tense: String, pageCount: Int,
                        ideaSeed: String) -> String {
        var genreLine = genre
        if let subgenre, !subgenre.isEmpty {
            genreLine += " / \(subgenre)"
        }
        var seedBlock = ""
        if !ideaSeed.isEmpty {
            seedBlock = "\nIDEENKERN (verbindlicher Ausgangspunkt, weiterentwickeln statt ersetzen):\n\(ideaSeed)\n"
        }
        return """
        Entwickle ein eigenständiges Buchkonzept (keine Nachahmung geschützter Werke).
        \(seedBlock)
        Titel: \(title)
        Genre: \(genreLine)
        Sprache des Buches: \(language)
        Stilprofil: \(style)
        Tonalität: \(tonality)
        Zielgruppe: \(audience)
        Erzählperspektive: \(perspective), Zeitform: \(tense)
        Zielumfang: ca. \(pageCount) Seiten

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
                     pageCount: Int, chapterCount: Int) -> String {
        """
        Erstelle den vollständigen Plot für den Roman "\(title)".
        Genre: \(genre) | Stil: \(style) | Umfang: ca. \(pageCount) Seiten in \(chapterCount) Kapiteln.

        Konzept:
        \(concept)

        Baue den Plot nach bewährter Bestseller-Dramaturgie in drei Akten:
        - Eröffnungsbild und Alltag mit Riss (0–10%)
        - Auslösendes Ereignis, das die Normalität zerstört (ca. 10%)
        - Erster Wendepunkt – es gibt kein Zurück mehr (ca. 25%)
        - Steigende Komplikationen mit wechselnden Teilerfolgen (25–50%)
        - Mittelpunkt-Umkehr: ein Sieg oder eine Niederlage, die alles neu rahmt (50%)
        - Die Schlinge zieht sich zu, der Preis steigt (50–75%)
        - Tiefpunkt: Alles scheint verloren (ca. 75%)
        - Entscheidung und finale Konfrontation (75–90%)
        - Höhepunkt (ca. 90%) und Auflösung mit emotionalem Nachklang

        Zusätzlich:
        - Formuliere die zentrale dramatische Frage in einem Satz.
        - Webe mindestens eine Nebenhandlung ein, die den Hauptplot am Ende verstärkt.
        - Platziere offene Fragen (Open Loops), die erst spät beantwortet werden – sie halten den Leser im Buch.
        - Jede Figur trifft Entscheidungen unter Druck; keine passiven Zufälle als Plotmotor.
        - Plane Kapitelenden so, dass Neugier, Sorge oder Erwartung offen bleiben.
        - Der Umfang muss tragfähig für den Zielumfang sein: keine Kurzgeschichten-Struktur für lange KDP-Romane.

        Schreibe als zusammenhängenden, klar gegliederten Text.
        """
    }

    static func characters(title: String, genre: String, plot: String) -> String {
        """
        Entwickle das Figurenensemble für den Roman "\(title)" (Genre: \(genre)).

        Plot:
        \(plot.truncated(to: 4000))

        Erstelle den Protagonisten, den Antagonisten und 3-5 wichtige Nebenfiguren.
        Gib für JEDE Figur GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        FIGUR|Name|Rolle|Alter|Beruf|Ziel|Angst|Schwäche

        Danach darfst du zu jeder Figur 2-3 Sätze Hintergrund ergänzen.
        """
    }

    static func chapterPlan(title: String, genre: String, plot: String,
                            chapterCount: Int, wordsPerChapter: Int,
                            scenesPerChapter: Int = 4) -> String {
        """
        Plane die Kapitelstruktur für den Roman "\(title)" (Genre: \(genre)).
        Es sollen GENAU \(chapterCount) Kapitel mit je ca. \(wordsPerChapter) Wörtern sein.
        Plane so, dass jedes Kapitel später in mindestens \(scenesPerChapter) eigenständige Szenen zerlegt werden kann.
        Langform-Pflicht: Der Konflikt muss groß genug für alle \(chapterCount) Kapitel sein; keine Abkürzungen,
        keine summarischen Sprünge, kein Kurzgeschichtenbogen mit künstlicher Streckung.

        Plot:
        \(plot.truncated(to: 6000))

        Regeln für Bestseller-Kapitelstruktur:
        - JEDES Kapitel endet mit einem Haken: offene Frage, Bedrohung, Enthüllung oder folgenschwere Entscheidung.
        - Variiere das Tempo: Auf intensive Kapitel folgt ein ruhigeres mit Charaktertiefe – nie zwei gleiche hintereinander.
        - Jedes Kapitel hat genau ein klares Ziel und treibt den Hauptplot messbar voran. Keine Füllkapitel.

        Gib für JEDES Kapitel GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        KAPITEL|Nummer|Titel|Ziel des Kapitels|Zentraler Konflikt

        Keine weiteren Erklärungen. Die Kapitel müssen den kompletten Plot von Anfang bis Auflösung abdecken.
        """
    }

    static func scenePlan(bookTitle: String, chapterNumber: Int, chapterTitle: String,
                          chapterGoal: String, chapterConflict: String,
                          perspective: String, plotContext: String, targetWords: Int,
                          scenesPerChapter: Int = 4) -> String {
        """
        Plane die Szenen für Kapitel \(chapterNumber) ("\(chapterTitle)") des Romans "\(bookTitle)".
        Kapitelziel: \(chapterGoal)
        Kapitelkonflikt: \(chapterConflict)
        Standard-Erzählperspektive: \(perspective)
        Gesamtumfang des Kapitels: ca. \(targetWords) Wörter.

        Plotkontext:
        \(plotContext.truncated(to: 3000))

        Plane mindestens \(scenesPerChapter) Szenen (bei Bedarf mehr, aber nicht weniger).
        Für 500-Seiten-Langform braucht jede Szene eine eigene dramatische Funktion:
        neues Ziel, neue Reibung, neue Information, veränderte Beziehung oder verschärfter Einsatz.
        Die LETZTE Szene des Kapitels muss mit einem starken Haken
        enden (Feld „Wendung am Szenenende" entsprechend zugespitzt) – der Leser darf das
        Buch am Kapitelende nicht weglegen können.

        Gib für JEDE Szene GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        SZENE|Nummer|Perspektive|Ort|Zeit|Ziel der Szene|Hindernis|Wendung am Szenenende

        Keine weiteren Erklärungen.
        """
    }

    /// Genre-spezifische Handwerksregeln auf Bestseller-Niveau.
    static func genreCraft(_ genre: String) -> String {
        let g = genre.lowercased()
        if g.contains("thriller") || g.contains("krimi") {
            return "GENRE-HANDWERK: Hohes Tempo. Spannung durch Wissensvorsprung oder -rückstand des Lesers. Jede Szene endet mit einem Haken. Kurze Sätze in Actionmomenten."
        }
        if g.contains("liebes") || g.contains("romance") {
            return "GENRE-HANDWERK: Emotionale Innenwelt im Zentrum. Anziehung UND Hindernis müssen in jeder Begegnung spürbar sein. Dialoge leben von dem, was NICHT gesagt wird."
        }
        if g.contains("fantasy") || g.contains("science") {
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
                           targetWords: Int) -> String {
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

            WICHTIG – LETZTE SZENE DES BUCHES:
            Löse den zentralen Konflikt emotional befriedigend auf. Greife ein Bild oder Motiv \
            vom Anfang des Buches wieder auf. Der Schlusssatz muss nachhallen. Kein Cliffhanger.
            """
        }

        var transition = ""
        if !previousSceneEnding.isEmpty {
            transition = """

            WÖRTLICHES ENDE DER VORHERIGEN SZENE:
            „…\(previousSceneEnding)“
            Knüpfe nahtlos daran an – ohne das Geschehene zu wiederholen oder zusammenzufassen.
            """
        }

        return """
        Schreibe Szene \(sceneNumber) aus Kapitel \(chapterNumber) ("\(chapterTitle)") des Romans "\(bookTitle)".

        SPRACHE: Schreibe ausschließlich auf \(language).
        STIL: \(style); Tonalität: \(tonality); Erzählperspektive: \(scenePerspective.isEmpty ? perspective : scenePerspective); Zeitform: \(tense).
        STILREGELN: \(styleRules.truncated(to: 600))

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

        FIGUREN:
        \(charactersSummary.truncated(to: 1200))

        BISHERIGE HANDLUNG:
        \(storySoFar.isEmpty ? "Dies ist der Anfang des Buches." : storySoFar.truncated(to: 8000))
        \(transition)
        HANDWERK (Bestseller-Standard, strikt einhalten):
        - Beginne mitten in der Bewegung – kein Aufwärmen, keine Wetter- oder Aufwach-Eröffnung.
        - Szenenstruktur: Ziel → Konflikt → Wendung. Die Wendung verändert die Lage spürbar.
        - Tiefe Perspektive: Bleibe kompromisslos im Kopf der Perspektivfigur. Keine Information, die sie nicht haben kann.
        - Zeigen statt behaupten: Emotionen über Körperreaktion, Handlung und Dialog. Niemals benennen („sie war wütend“ ist verboten).
        - Dialog mit Subtext: Figuren sagen selten direkt, was sie wollen. Jede Replik hat eine Absicht.
        - Konkrete, spezifische Details statt generischer Beschreibungen (nicht „ein Auto“, sondern „der rostige Kombi“).
        - Variiere Satzlänge und Rhythmus: kurze Sätze für Tempo, längere für Atmosphäre.
        - VERBOTENE FLOSKELN: „ein Schauer lief ihr über den Rücken“, „sie atmete tief durch“, „die Zeit schien stillzustehen“, „nichts würde mehr sein wie zuvor“, „ein Lächeln umspielte seine Lippen“, inflationäres „plötzlich“.
        - KEINE WIEDERHOLUNGEN: Greife keine Bilder, Metaphern, Formulierungen oder Szenenaufbauten aus der bisherigen Handlung wieder auf. Erkläre bereits etablierte Fakten nie ein zweites Mal. Jede Szene zeigt etwas Neues – neue Information, neuer Aspekt eines Schauplatzes, neue Beziehungsdynamik.
        - SOG-TECHNIKEN (Page-Turner): Halte stets mindestens eine offene Frage aktiv; beantworte alte Fragen erst, wenn neue aufgeworfen sind. Mikro-Spannung auch in ruhigen Momenten (Reibung zwischen Figuren, unausgesprochene Bedrohung, Zeitdruck). Nutze dramatische Ironie, wo der Leser mehr weiß als die Figur.
        - Der letzte Satz der Szene muss einen Grund zum Weiterlesen geben.
        \(genreCraft(genre))
        \(positionNote)
        Keine Überschriften, keine Meta-Kommentare – gib NUR den Prosatext der Szene aus.
        """
    }

    static func summarizeScene(text: String) -> String {
        """
        Fasse die folgende Romanszene in 2-3 Sätzen zusammen. Nenne Figuren, Ort, \
        was passiert, was sich verändert hat und welche neuen Fakten oder Enthüllungen \
        etabliert wurden. Gib NUR die Zusammenfassung aus.

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

    static func reviseChapter(language: String, style: String, tonality: String,
                              chapterNumber: Int, chapterTitle: String, text: String) -> String {
        """
        Überarbeite Kapitel \(chapterNumber) ("\(chapterTitle)") eines Romans.
        Sprache: \(language). Stil: \(style), Tonalität: \(tonality).

        Verbessere Satzrhythmus, Wortwiederholungen, schwache Verben, Füllwörter und \
        Dialogfluss. Streiche Filterwörter (sehen, hören, spüren, bemerken), wo die \
        Wahrnehmung direkt gezeigt werden kann. Behalte Handlung, Reihenfolge der \
        Ereignisse, Perspektive und Umfang bei (±10%). Szenentrenner (***) müssen \
        exakt erhalten bleiben. Gib NUR den vollständigen überarbeiteten Kapiteltext \
        aus, ohne Überschrift und ohne Kommentare.

        TEXT:
        \(text)
        """
    }

    static func consistencyCheck(bookTitle: String, summaries: String, characters: String) -> String {
        """
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
                            audience: String, synopsis: String, language: String) -> String {
        let authorBlock = authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : "\nAutorprofil für Tonalität/Markenstimme:\n\(authorBio.truncated(to: 800))\n"
        return """
        Erstelle Amazon-KDP-Metadaten für das Buch "\(title)" von \(author).
        Genre: \(genre) | Zielgruppe: \(audience) | Sprache: \(language)
        \(authorBlock)

        Inhalt:
        \(synopsis.truncated(to: 3000))

        Keine Hinweise auf KI, AI, künstliche Intelligenz, Automatisierung, Tools oder NovelForge
        in Verkaufstext, Keywords oder Kategorien. Die Ausgabe muss wie professionelle Verlagsmetadaten wirken.

        Antworte exakt in diesem Format:
        VERKAUFSTEXT: [150-200 Wörter Amazon-Produktbeschreibung: packender Hook in der \
        ersten Zeile, dann Konflikt und Einsatz, am Ende ein kaufauslösender Abschluss. \
        Keine Spoiler. Keine verbotenen Begriffe wie "Bestseller" oder "kostenlos". Reiner Fließtext.]
        KEYWORDS: [genau 7 Suchbegriffe, durch Kommas getrennt, je 1-3 Wörter; keine \
        Autorennamen oder Titel fremder Werke, nicht nur "Buch" oder "Roman" allein]
        KATEGORIEN: [3 passende Amazon-Kategorien, eine pro Zeile, Format: Oberkategorie > Unterkategorie]
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
    static func expandScene(language: String, style: String, text: String, targetWords: Int) -> String {
        """
        Die folgende Romanszene ist zu kurz. Erweitere sie auf ca. \(targetWords) Wörter, \
        OHNE die Handlung zu verändern: Vertiefe Sinneseindrücke, das Innenleben der \
        Perspektivfigur und die Dialoge. Füge keine neuen Ereignisse oder Figuren hinzu. \
        Sprache: \(language). Stil: \(style).
        Gib NUR den vollständigen erweiterten Szenentext aus, ohne Kommentare.

        SZENE:
        \(text)
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
    var salesDescription = ""
    var keywords = ""
    var categories = ""
}

enum KDPMetadataParser {
    static func parse(_ text: String) -> KDPMetadataResult {
        let labels = ["VERKAUFSTEXT", "KEYWORDS", "KATEGORIEN"]
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
        result.salesDescription = sections["VERKAUFSTEXT"] ?? ""
        result.keywords = sections["KEYWORDS"] ?? ""
        result.categories = sections["KATEGORIEN"] ?? ""
        return result
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

    /// Zerlegt eine Zeile "MARKER|a|b|c" in ihre Felder. Toleriert führende
    /// Aufzählungszeichen und Markdown-Reste.
    private static func fields(in line: String, marker: String) -> [String]? {
        guard let range = line.range(of: marker + "|") else { return nil }
        let payload = String(line[range.upperBound...])
        return payload.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "**", with: "")
        }
    }

    static func parseChapters(_ text: String) -> [PlannedChapter] {
        var result: [PlannedChapter] = []
        for line in text.components(separatedBy: .newlines) {
            guard let parts = fields(in: line, marker: "KAPITEL"), parts.count >= 2 else { continue }
            let title = parts.count > 1 ? parts[1] : ""
            guard !title.isEmpty else { continue }
            result.append(PlannedChapter(
                number: result.count + 1, // fortlaufend nummerieren, Modell-Nummern können lückenhaft sein
                title: title,
                goal: parts.count > 2 ? parts[2] : "",
                conflict: parts.count > 3 ? parts[3] : ""
            ))
        }
        return result
    }

    static func parseScenes(_ text: String) -> [PlannedScene] {
        var result: [PlannedScene] = []
        for line in text.components(separatedBy: .newlines) {
            guard let parts = fields(in: line, marker: "SZENE"), parts.count >= 2 else { continue }
            result.append(PlannedScene(
                number: result.count + 1,
                perspective: parts.count > 1 ? parts[1] : "",
                location: parts.count > 2 ? parts[2] : "",
                time: parts.count > 3 ? parts[3] : "",
                goal: parts.count > 4 ? parts[4] : "",
                obstacle: parts.count > 5 ? parts[5] : "",
                turn: parts.count > 6 ? parts[6] : ""
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
                weakness: parts.count > 6 ? parts[6] : ""
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
