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
        Entwickle 5 eigenständige, kommerziell durchschlagende Buchideen \
        (Genre-Schwerpunkt: \(genre.isEmpty ? "frei wählbar" : genre), Sprache: \(language)). \
        Ziel sind Bücher, über die Leser online reden und die sie weiterempfehlen (BookTok/Amazon-Bestseller-Niveau) – \
        jede Idee braucht einen frischen, überraschenden Dreh und einen klaren zentralen Konflikt. \
        Keine Klischee-Plots, keine Nacherzählung bestehender Werke.
        \(memoryBlock)
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

        TITEL-PFLICHT – kreativ, kurz, unverwechselbar:
        – Maximal 2–6 Wörter, eingängig und merkfähig; er soll beim Scrollen STOPPEN lassen.
        – Erzeuge sofort eine Frage, ein Bild, einen Widerspruch oder ein starkes Versprechen
          (dramatische Zuspitzung, Gefahr, Begehren, Schuld, ein aufgeladenes Objekt oder ein markanter Ort).
        – VERBOTEN: austauschbare Berufs-Titel wie "Die Imkerin von X", "Der Kassierer aus Y",
          "Das Schweigen der Imkerin", "Das Geheimnis der Bäckerin"; ebenso blasse Abstrakta
          ("Liebe und Hoffnung") und Titel, die nur einen Beruf + Ort nennen.
        – Jeder der 5 Titel muss anders klingen – kein gemeinsames Schema, keine Nummerierung.

        Gib für JEDE Idee GENAU eine Zeile in diesem Format aus (Felder mit | getrennt):
        IDEE|Titel|Genre|Prämisse in 2 Sätzen – Satz 1 ist der High-Concept-Hook, Satz 2 nennt Konflikt und Einsatz

        Keine weiteren Erklärungen.
        """
    }

    /// Genre-spezifischer "viraler Winkel": welches Thema/welcher Trope in diesem Genre
    /// Mundpropaganda und KDP-Verkäufe treibt, plus der passende Titel-Klang mit
    /// originellen Beispieltiteln (NICHT abgeschrieben, NICHT die verbotenen Berufs-Klischees).
    /// Bewusst getrennt von `genreCraft` (das die Prosa beim Schreiben steuert).
    static func genreViralAngle(_ genre: String) -> String {
        let g = genre.lowercased()
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
        if g.contains("fantasy") || g.contains("science") || g.contains("sci-fi") || g.contains("dystop") {
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

        VERBINDLICH: Titel und Genre sind fest vorgegeben. Entwickle das Konzept so, dass es \
        exakt zum Titel „\(title)" und zum Genre „\(genreLine)" passt und den Titel erzählerisch \
        einlöst – er soll nach der Lektüre sinnfällig und treffend wirken. Ändere oder ersetze den \
        Titel NICHT und weiche nicht ins Genre-Fremde ab.
        \(genreCraft(genre))
        Nimm das Genre ernst: Die Kernerwartung des Genres steht im Zentrum der Handlung. Die \
        Geschichte kreist NICHT um einen Beruf/Arbeitsplatz als Hauptthema; ein Beruf ist höchstens \
        Kulisse. Bei Liebesroman/Erotik treiben Beziehung und Begehren den Plot (mit der Hitze, die \
        das Genre verlangt), nicht ein nebenbei erzähltes Alltagsleben.
        \(romanceGenreContract(genre))

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
    /// Synthese aus zwei Experten-Modulen (Stimme/Subtext + Lexik/Rhythmus).
    /// Bricht gezielt die statistischen und lexikalischen Muster, an denen
    /// KI-Detektoren maschinell erzeugte Prosa erkennen (Burstiness/Perplexität),
    /// OHNE die literarische Qualität oder Lesbarkeit zu senken.
    static var humanCraftRules: String {
        """
        MENSCHLICH SCHREIBEN – DAMIT ES NICHT NACH KI KLINGT (diese Regeln stehen über dem reinen Glattschreiben; erzähl die Szene trotzdem vollständig zu Ende und kommentiere sie nie):
        - SATZLÄNGE BRUTAL STREUEN: Niemals drei Sätze in Folge mit ähnlicher Länge. Nach einem langen Schachtelsatz (25+ Wörter) folgt ein Satz mit drei bis fünf Wörtern oder ein verbloses Fragment („Kein Licht. Nirgends."). Pro Szene mindestens zwei sehr kurze Sätze unter vier Wörtern.
        - ABSATZLÄNGE VARIIEREN: Keine zwei gleich langen Absätze hintereinander. Setze mindestens einen Ein-Satz-Absatz als Akzent.
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
        - SELBSTCHECK vor der Ausgabe (still, nicht in den Text schreiben): Endet ein Absatz auf einer Deutung? Drei gleich lange Sätze in Folge? Ein Gefühl benannt statt gezeigt? Eine Trikola oder ein „nicht X, sondern Y"? Mehr als ein „als hätte/wäre/würde"? – umbauen. Gib nur die korrigierte Prosa aus.
        """
    }

    /// Konzeptphasen-Vertrag, der verhindert, dass aus einem Liebesroman/Erotik-Roman
    /// ein Thriller mit Job-Plot (und einem Stalker als „Love Interest") wird.
    /// Greift VOR der ersten Szene; leer für andere Genres.
    static func romanceGenreContract(_ genre: String) -> String {
        let g = genre.lowercased()
        let isRomance = g.contains("liebes") || g.contains("romance")
            || g.contains("erotik") || g.contains("erotic") || g.contains("spicy")
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
            Setze die Szene unmittelbar fort, ohne das Geschehene zu wiederholen.
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
        HANDWERK (die GESCHICHTE steht im Vordergrund – Technik dient ihr, nie umgekehrt):
        - KLARHEIT VOR SCHÖNHEIT: Der Leser muss der Szene mühelos folgen und sich auf sie einlassen können. Schreibe verständlich; verrätsle oder überlade nichts, was die Handlung trägt.
        - BILDER STRENG RATIONIEREN: HÖCHSTENS ein bis zwei wirklich starke Bilder/Metaphern in der GANZEN Szene. Alles andere klar und nüchtern erzählen. Nicht jeder innere Zustand bekommt ein Bild – sonst stumpft die Wirkung ab und am Ende wirkt nichts mehr intensiv.
        - HANDELN STATT GRÜBELN: Die Figur tut konkrete Dinge (fragt, sucht, ruft an, konfrontiert, entscheidet, handelt) statt überwiegend innerlich zu reagieren. Innere Erschütterung kurz halten.
        - KÖRPERSIGNALE SPARSAM UND VARIIERT: Zittern, Herzklopfen, zugeschnürte Kehle, „den Mund öffnen und wieder schließen" nur selten – nicht in jeder Szene dieselben Reaktionen.
        - DIALOG BEILÄUFIG UND ECHT: Verletzendes klingt beiläufig und präzise, nicht wie ein ausgesprochenes Romanthema. Eine Figur sagt das Thema des Buches NIE direkt aus. Lieber härter und glaubwürdiger als perfekt formuliert.
        - THEMA NIEMALS ERKLÄREN: Die emotionale Bedeutung wird gezeigt, nie zusammengefasst oder ausbuchstabiert („nicht X, sondern Y" als Deutung ist verboten). Vertraue darauf, dass der Leser sie selbst erschließt.
        - Beginne mitten in der Handlung; halte den Einstieg kurz und komm schnell zum Kern der Szene. Keine Wetter- oder Aufwach-Eröffnung.
        - Szenenstruktur: Ziel → Konflikt → Wendung. Tiefe Perspektive der Perspektivfigur (keine Information, die sie nicht haben kann). Zeigen statt behaupten – Emotion NIE benennen („sie war wütend" ist verboten).
        - Konkrete, spezifische Details statt generischer. Variiere Satzlänge und Rhythmus wie in einem Bestseller: Lesefluss vor Kunstfertigkeit, nicht jede Zeile „literarisch" aufladen.
        \(humanCraftRules)
        - KEINE WIEDERHOLUNGEN: Greife keine Bilder, Metaphern, Formulierungen oder Motive aus der bisherigen Handlung wieder auf; erkläre etablierte Fakten nie ein zweites Mal. Ein starkes Symbol nur SELTEN erwähnen, nicht in jeder Szene.
        - SOG (dezent): Halte mindestens eine offene Frage aktiv und nutze Mikro-Spannung, aber nie auf Kosten der Verständlichkeit. Pro Szene höchstens EINE neue Figur oder Enthüllung, nicht mehrere gleichzeitig.
        - Der letzte Satz gibt einen Grund zum Weiterlesen, ohne aufgesetzt oder programmatisch zu wirken.
        \(genreCraft(genre))
        \(positionNote)
        Gib AUSSCHLIESSLICH den fertigen Prosatext der Szene aus. Übernimm NIEMALS
        Anweisungen, Labels (z.B. „Ort:", „Ziel:", „Zielumfang"), Überschriften oder
        Hinweise aus diesem Auftrag in den Text – schreibe ausschließlich die Geschichte selbst.
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
        exakt erhalten bleiben.

        Wende beim Überarbeiten zusätzlich diese Regeln an (entferne KI-typische Muster aktiv):
        \(humanCraftRules)

        Gib NUR den vollständigen überarbeiteten Kapiteltext aus, ohne Überschrift und ohne Kommentare.

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
            result.append(PlannedChapter(
                number: result.count + 1, // fortlaufend nummerieren, Modell-Nummern können lückenhaft sein
                title: title,
                goal: parts.count > 1 ? parts[1] : "",
                conflict: parts.count > 2 ? parts[2] : ""
            ))
        }
        return result
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
