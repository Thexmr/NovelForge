# Manueller Geschichtenauftrag

## Ziel

Im Assistenten fuer ein einzelnes Buch kann der Nutzer zwischen `Genre waehlen` und
`Geschichte vorgeben` umschalten. Im zweiten Modus beschreibt er die gewuenschte
Geschichte frei. NovelForge erkennt Genre und Subgenre, entwickelt daraus einen
vollstaendigen Roman bis 500 Seiten und behandelt alle ausdruecklichen Vorgaben als
verbindlich.

Das System verspricht keine Verkaufszahlen oder objektive Perfektion. Es erzwingt aber
die vorhandenen Qualitaets-, Kontinuitaets-, Stil-, Rechtschreib- und Exportpruefungen.

## Bedienung

Der erste Wizard-Schritt erhaelt eine segmentierte Auswahl:

- `Genre waehlen`: bisheriger Ablauf bleibt unveraendert.
- `Geschichte vorgeben`: ein grosser Textbereich nimmt Figuren, Ausgangslage,
  Pflichtmomente, Wendungen und Ende in natuerlicher Sprache auf.

Im Geschichtenmodus sind Genre, Subgenre und Titel zunaechst `Automatisch`. Eine
Analyse-Schaltflaeche erzeugt:

- Hauptgenre und optionales Mischgenre,
- drei bis fuenf eigenstaendige Titelvorschlaege,
- eine kurze Praemisse,
- eine geordnete Liste verbindlicher Story-Beats,
- Hinweise auf echte Widersprueche oder unklare Angaben.

Der Nutzer sieht die Analyse vor dem Start und darf Genre, Subgenre, Titel und Beats
bearbeiten. Die Originaleingabe bleibt separat und unveraendert gespeichert. Ohne
erfolgreiche Analyse oder mit ungeloesten harten Widerspruechen kann die Produktion
nicht starten. Kleine Schreibfehler in der Eingabe sind kein Blocker.

## Datenmodell

`BookProfile` erhaelt additive, migrationsfreundliche Felder mit leeren Standardwerten:

- `authorStoryBrief`: unveraenderte Originaleingabe des Nutzers,
- `storyRequirements`: normalisierter, geordneter Pflichtvertrag,
- `storyBriefAnalysis`: gespeicherte Analyse fuer Anzeige und Resume,
- `storyBriefMode`: kennzeichnet den manuellen Geschichtenmodus.

Bestehende Projekte bleiben gueltig. Leere neue Felder bedeuten den bisherigen Ablauf.
Die abgeleitete Praemisse bleibt in `premise`, damit vorhandene Agenten kompatibel
bleiben.

## KI-Analysevertrag

Die Analyse liefert ein strikt parsbares Format. Jeder erkannte Fakt wird einer Klasse
zugeordnet:

- Figur und Beziehung,
- Ausgangslage,
- Muss-Ereignis am Anfang,
- Muss-Ereignis im Mittelteil,
- Muss-Ereignis am Ende,
- unveraenderliche Folge oder Zustand,
- kreativer Freiraum.

Explizite Angaben wie Alter, Verwandtschaft, Verlust, Wiederfinden, Tod, Rettung,
Zeitfolge und Ort duerfen nicht still veraendert werden. Unbekannte Details werden als
Freiraum markiert. Genreerkennung darf ein Hauptgenre und ein sekundares Mischgenre
waehlen; die Nutzerauswahl hat immer Vorrang.

## Produktionsvertrag

Der Pflichtvertrag wird in alle handlungsveraendernden Phasen eingespeist:

- Konzept und Expose,
- Story Bible und Figurenanlage,
- Plot-, Kapitel- und Szenenplanung,
- Rohfassung,
- Kontinuitaets- und Reparaturagenten,
- Schlussaudit und Golden Eval.

Die Seitenzahl steuert Kapitel- und Szenenarchitektur. Laenge entsteht durch kausale
Nebenhandlungen, Figurenentwicklung, Konfliktfolgen und szenische Ausarbeitung, nicht
durch Wiederholung oder Fuelltext.

Vor der Rohfassung prueft ein deterministischer Vertragscheck, ob jeder Pflicht-Beat in
Plot und Kapitelplan verankert ist. Nach der Manuskriptrevision prueft ein semantischer
Audit, ob die Vorgaben erzaehlt und nicht widersprochen wurden. Fehlende oder
widersprochene Beats fuehren zu gezielter Kapitelreparatur; sie duerfen nicht als
fertiges Buch exportiert werden.

## Fehler und Fortsetzen

Analyseantworten werden validiert und hoechstens begrenzt erneut angefordert. Ein
Providerfehler erhaelt eine klare Meldung und laesst die Nutzereingabe unangetastet.
Alle Analyseergebnisse und Pflicht-Beats werden vor Produktionsbeginn gespeichert, damit
Pause, App-Neustart und Resume denselben Vertrag verwenden.

Die Analyse selbst startet keine Buchproduktion. Erst `Produktion starten` legt das
Projekt an und startet die bestehende Pipeline.

## Tests

- Parser und Validierung fuer Genre, Titel, Praemisse und geordnete Pflicht-Beats.
- Persistenz und Migration bestehender Projekte.
- Originaleingabe bleibt bytegetreu erhalten.
- Nutzer-Override gewinnt gegen KI-Genre und KI-Titel.
- Anfang/Mitte/Ende sowie Alter, Beziehung und finales Schicksal bleiben im Plot.
- Mischgenres werden korrekt gespeichert und in Genre-Regeln eingespeist.
- 500 Seiten erzeugen eine passende Langformarchitektur ohne Prompt-Aufblaehung.
- Resume verwendet denselben Vertrag und plant nicht neu gegen bestehende Prosa.
- Export wird bei fehlenden oder widersprochenen Pflichtmomenten blockiert.
- Wizard-Smoketest fuer beide Modi, kleine und grosse Fenster sowie reduzierte Bewegung.
- Echter kleiner Cloud-Test vom Freitext bis zu mehreren gespeicherten Szenen.

## Nicht enthalten

- Keine automatische Veraenderung bereits geschriebener Altprojekte in den neuen Modus.
- Keine Garantie fuer Bestsellerstatus oder konkrete KDP-Verkaeufe.
- Kein ungefragter Live-Upload zu Amazon KDP.
