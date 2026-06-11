package com.novelforge.android.ai

/**
 * Prompt-Vorlagen – 1:1-Portierung der macOS-Version
 * (Bestseller-Dramaturgie, Page-Turner-Handwerk, strikt parsebare Formate).
 */
object Prompts {

    fun genreCraft(genre: String): String {
        val lowered = genre.lowercase()
        return when {
            lowered.contains("thriller") || lowered.contains("krimi") ->
                "GENRE-HANDWERK: Hohes Tempo. Spannung durch Wissensvorsprung oder -rückstand des Lesers. Jede Szene endet mit einem Haken."
            lowered.contains("liebes") || lowered.contains("romance") ->
                "GENRE-HANDWERK: Emotionale Innenwelt im Zentrum. Anziehung UND Hindernis in jeder Begegnung spürbar. Dialoge leben vom Ungesagten."
            lowered.contains("fantasy") || lowered.contains("science") ->
                "GENRE-HANDWERK: Die Welt durch konkrete Details im Handlungsfluss zeigen – keine Infodumps. Weltregeln konsequent einhalten."
            lowered.contains("horror") ->
                "GENRE-HANDWERK: Bedrohung andeuten statt zeigen. Atmosphäre über Sinneseindrücke. Ruhe vor jeder Eskalation."
            lowered.contains("histor") ->
                "GENRE-HANDWERK: Epochendetails beiläufig einweben. Sprache zeitgemäß färben, ohne antiquiert zu wirken."
            else -> "GENRE-HANDWERK: Erzeuge in jeder Szene einen klaren Spannungsbogen mit spürbarer Wendung."
        }
    }

    fun bookIdeas(genre: String, language: String) = """
        Entwickle 3 eigenständige, kommerziell vielversprechende Buchideen (Genre-Schwerpunkt: ${genre.ifEmpty { "frei wählbar" }}, Sprache: $language). Jede Idee braucht einen frischen Dreh und einen klaren zentralen Konflikt – keine Klischee-Plots, keine Anlehnung an bestehende Werke.

        Gib für JEDE Idee GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        IDEE|Titel|Genre|Prämisse in 2 Sätzen mit klarem Konflikt

        Keine weiteren Erklärungen.
    """.trimIndent()

    fun concept(title: String, genre: String, language: String, style: String,
                pages: Int, ideaSeed: String): String {
        val seed = if (ideaSeed.isEmpty()) ""
        else "\nIDEENKERN (verbindlicher Ausgangspunkt, weiterentwickeln statt ersetzen):\n$ideaSeed\n"
        return """
            Entwickle ein eigenständiges Buchkonzept (keine Nachahmung geschützter Werke).
            $seed
            Titel: $title
            Genre: $genre
            Sprache des Buches: $language
            Stilprofil: $style
            Zielumfang: ca. $pages Seiten

            Antworte ausschließlich in diesem Format (Labels exakt so verwenden):
            PRÄMISSE: [1-2 Sätze]
            LOGLINE: [Ein Satz]
            EXPOSÉ: [5-8 Sätze, die den kompletten Handlungsbogen umreißen]
            HAUPTKONFLIKT: [1-2 Sätze]
            THEMA: [1-3 Wörter]
            ZIELGRUPPE: [Kurze Beschreibung]
        """.trimIndent()
    }

    fun plot(title: String, genre: String, style: String, concept: String,
             pages: Int, chapterCount: Int) = """
        Erstelle den vollständigen Plot für den Roman "$title".
        Genre: $genre | Stil: $style | Umfang: ca. $pages Seiten in $chapterCount Kapiteln.

        Konzept:
        ${concept.take(4000)}

        Baue den Plot nach bewährter Bestseller-Dramaturgie in drei Akten:
        - Eröffnungsbild und Alltag mit Riss (0–10%)
        - Auslösendes Ereignis (ca. 10%)
        - Erster Wendepunkt – kein Zurück mehr (ca. 25%)
        - Steigende Komplikationen mit wechselnden Teilerfolgen (25–50%)
        - Mittelpunkt-Umkehr, die alles neu rahmt (50%)
        - Die Schlinge zieht sich zu (50–75%)
        - Tiefpunkt: Alles scheint verloren (ca. 75%)
        - Entscheidung und finale Konfrontation (75–90%)
        - Höhepunkt (ca. 90%) und Auflösung mit emotionalem Nachklang

        Webe mindestens eine Nebenhandlung ein und platziere offene Fragen (Open Loops),
        die erst spät beantwortet werden. Schreibe als klar gegliederten Text.
    """.trimIndent()

    fun characters(title: String, genre: String, plot: String) = """
        Entwickle das Figurenensemble für den Roman "$title" (Genre: $genre).

        Plot:
        ${plot.take(4000)}

        Erstelle den Protagonisten, den Antagonisten und 3-5 wichtige Nebenfiguren.
        Gib für JEDE Figur GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        FIGUR|Name|Rolle|Alter|Beruf|Ziel|Angst|Schwäche
    """.trimIndent()

    fun chapterPlan(title: String, genre: String, plot: String,
                    chapterCount: Int, wordsPerChapter: Int) = """
        Plane die Kapitelstruktur für den Roman "$title" (Genre: $genre).
        Es sollen GENAU $chapterCount Kapitel mit je ca. $wordsPerChapter Wörtern sein.

        Plot:
        ${plot.take(6000)}

        Regeln für Bestseller-Kapitelstruktur:
        - JEDES Kapitel endet mit einem Haken: offene Frage, Bedrohung, Enthüllung oder Entscheidung.
        - Variiere das Tempo: Auf intensive Kapitel folgt ein ruhigeres mit Charaktertiefe.
        - Jedes Kapitel treibt den Hauptplot messbar voran. Keine Füllkapitel.

        Gib für JEDES Kapitel GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        KAPITEL|Nummer|Titel|Ziel des Kapitels|Zentraler Konflikt

        Keine weiteren Erklärungen.
    """.trimIndent()

    fun scenePlan(bookTitle: String, chapterNumber: Int, chapterTitle: String,
                  chapterGoal: String, chapterConflict: String, plot: String,
                  targetWords: Int) = """
        Plane die Szenen für Kapitel $chapterNumber ("$chapterTitle") des Romans "$bookTitle".
        Kapitelziel: $chapterGoal
        Kapitelkonflikt: $chapterConflict
        Gesamtumfang des Kapitels: ca. $targetWords Wörter.

        Plotkontext:
        ${plot.take(3000)}

        Plane 3 bis 5 Szenen. Die LETZTE Szene des Kapitels muss mit einem starken Haken enden.

        Gib für JEDE Szene GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        SZENE|Nummer|Perspektive|Ort|Zeit|Ziel der Szene|Hindernis|Wendung am Szenenende

        Keine weiteren Erklärungen.
    """.trimIndent()

    fun draftScene(
        language: String, style: String, genre: String, bookTitle: String,
        chapterNumber: Int, chapterTitle: String, chapterGoal: String,
        sceneNumber: Int, sceneGoal: String, sceneLocation: String, sceneTime: String,
        sceneObstacle: String, sceneTurn: String, scenePerspective: String,
        charactersSummary: String, storySoFar: String, previousSceneEnding: String,
        isFirstScene: Boolean, isFinalScene: Boolean, targetWords: Int
    ): String {
        val position = when {
            isFirstScene -> "\nWICHTIG – ERSTE SZENE DES BUCHES: Der erste Satz ist der wichtigste des gesamten Romans (Amazon-Leseprobe!). Er muss sofort fesseln. Etabliere Hauptfigur und Stimmung auf der ersten Seite – ohne Vorgeplänkel.\n"
            isFinalScene -> "\nWICHTIG – LETZTE SZENE DES BUCHES: Löse den zentralen Konflikt emotional befriedigend auf. Greife ein Motiv vom Anfang wieder auf. Der Schlusssatz muss nachhallen. Kein Cliffhanger.\n"
            else -> ""
        }
        val transition = if (previousSceneEnding.isEmpty()) ""
        else "\nWÖRTLICHES ENDE DER VORHERIGEN SZENE:\n„…$previousSceneEnding“\nKnüpfe nahtlos daran an – ohne das Geschehene zu wiederholen.\n"

        return """
            Schreibe Szene $sceneNumber aus Kapitel $chapterNumber ("$chapterTitle") des Romans "$bookTitle".

            SPRACHE: Schreibe ausschließlich auf $language.
            STIL: $style; Erzählperspektive: $scenePerspective.

            KAPITELZIEL: $chapterGoal
            SZENE:
            - Ort: $sceneLocation
            - Zeit: $sceneTime
            - Ziel: $sceneGoal
            - Hindernis: $sceneObstacle
            - Wendung am Ende: $sceneTurn
            - Zielumfang: ca. $targetWords Wörter

            FIGUREN:
            ${charactersSummary.take(1200)}

            BISHERIGE HANDLUNG:
            ${storySoFar.ifEmpty { "Dies ist der Anfang des Buches." }.take(8000)}
            $transition
            HANDWERK (Bestseller-Standard, strikt einhalten):
            - Beginne mitten in der Bewegung – kein Aufwärmen.
            - Szenenstruktur: Ziel → Konflikt → Wendung. Die Wendung verändert die Lage spürbar.
            - Tiefe Perspektive: Bleibe kompromisslos im Kopf der Perspektivfigur.
            - Zeigen statt behaupten: Emotionen über Körper, Handlung und Dialog – nie benennen.
            - Dialog mit Subtext: Figuren sagen selten direkt, was sie wollen.
            - Konkrete, spezifische Details statt generischer Beschreibungen.
            - Variiere Satzlänge und Rhythmus.
            - VERBOTENE FLOSKELN: „ein Schauer lief ihr über den Rücken“, „sie atmete tief durch“, „die Zeit schien stillzustehen“, „nichts würde mehr sein wie zuvor“, inflationäres „plötzlich“.
            - KEINE WIEDERHOLUNGEN: Keine Bilder, Metaphern oder Szenenaufbauten aus der bisherigen Handlung wiederholen. Etablierte Fakten nie erneut erklären.
            - SOG-TECHNIKEN: Stets mindestens eine offene Frage aktiv halten. Mikro-Spannung auch in ruhigen Momenten. Dramatische Ironie nutzen.
            - Der letzte Satz der Szene muss einen Grund zum Weiterlesen geben.
            ${genreCraft(genre)}
            $position
            Keine Überschriften, keine Meta-Kommentare – gib NUR den Prosatext der Szene aus.
        """.trimIndent()
    }

    fun summarizeScene(text: String) = """
        Fasse die folgende Romanszene in 2-3 Sätzen zusammen. Nenne Figuren, Ort, was passiert, was sich verändert hat und welche neuen Fakten etabliert wurden. Gib NUR die Zusammenfassung aus.

        ${text.take(8000)}
    """.trimIndent()

    fun condenseChapter(number: Int, title: String, sceneSummaries: String) = """
        Verdichte die folgenden Szenen-Zusammenfassungen von Kapitel $number („$title“) auf maximal 2 Sätze: Was ist passiert, welche neuen Fakten oder Wendungen wurden etabliert? Gib NUR die Verdichtung aus.

        ${sceneSummaries.take(4000)}
    """.trimIndent()

    fun expandScene(language: String, style: String, text: String, targetWords: Int) = """
        Die folgende Romanszene ist zu kurz. Erweitere sie auf ca. $targetWords Wörter, OHNE die Handlung zu verändern: Vertiefe Sinneseindrücke, Innenleben und Dialoge. Keine neuen Ereignisse. Sprache: $language. Stil: $style.
        Gib NUR den vollständigen erweiterten Szenentext aus.

        SZENE:
        $text
    """.trimIndent()

    fun reviseChapter(language: String, style: String, chapterNumber: Int,
                      chapterTitle: String, text: String) = """
        Überarbeite Kapitel $chapterNumber ("$chapterTitle") eines Romans.
        Sprache: $language. Stil: $style.

        Verbessere Satzrhythmus, Wortwiederholungen, schwache Verben, Füllwörter und Dialogfluss. Streiche Filterwörter, wo die Wahrnehmung direkt gezeigt werden kann. Behalte Handlung, Reihenfolge, Perspektive und Umfang bei (±10%). Szenentrenner (***) exakt erhalten. Gib NUR den vollständigen überarbeiteten Kapiteltext aus.

        TEXT:
        $text
    """.trimIndent()

    fun proofread(language: String, text: String): String {
        val quoteRule = if (language == "Deutsch")
            "Verwende durchgehend deutsche Anführungszeichen („…“). " else ""
        return """
            Korrigiere den folgenden Romantext (Sprache: $language): Rechtschreibung, Grammatik, Zeichensetzung, Tippfehler, doppelte Wörter. ${quoteRule}Ändere NICHT den Stil und NICHT den Inhalt. Szenentrenner (***) exakt erhalten. Gib NUR den vollständigen korrigierten Text aus.

            TEXT:
            $text
        """.trimIndent()
    }

    fun kdpMetadata(title: String, author: String, genre: String,
                    synopsis: String, language: String) = """
        Erstelle Amazon-KDP-Metadaten für das Buch "$title" von $author.
        Genre: $genre | Sprache: $language

        Inhalt:
        ${synopsis.take(3000)}

        Antworte exakt in diesem Format:
        VERKAUFSTEXT: [150-200 Wörter Amazon-Produktbeschreibung: packender Hook, Konflikt und Einsatz, kaufauslösender Abschluss. Keine Spoiler, keine Begriffe wie "Bestseller".]
        KEYWORDS: [genau 7 Suchbegriffe, durch Kommas getrennt]
        KATEGORIEN: [3 passende Amazon-Kategorien, eine pro Zeile, Format: Oberkategorie > Unterkategorie]
    """.trimIndent()
}
