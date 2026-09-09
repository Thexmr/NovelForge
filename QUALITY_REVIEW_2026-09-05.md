# NovelForge: Qualitaet und lokale Beschleunigung

Stand: 2026-09-05. Zielbuild: 2.3.1 (81).

## Behobene Softwarefehler

- Reparaturkritik und Text konnten aus unterschiedlichen Durchgaengen stammen.
  OpeningRevisionState uebernimmt oder behaelt beide jetzt gemeinsam.
- Ein verbesserter Anfang mit offenen inhaltlichen Befunden wurde als finalisiert
  und hart abgenommen gemeldet. Solche Fassungen bleiben jetzt Zwischenfassungen,
  mit offenem Bericht und Exportblocker bis zur erneuten Endabnahme.
- Ein vorangestelltes BESTANDEN konnte nachfolgende Fehler verdecken. Nur die
  vollstaendige, eindeutige Antwort BESTANDEN gilt jetzt als Freigabe.
- Einzelauftraege versprachen nach einem Fehler einen automatischen Neustart,
  obwohl dieser Pfad keinen Neustart plant. Die Meldung beschreibt jetzt den
  tatsaechlichen Zustand.
- Die Wortwahlpruefung ignorierte kurze Texte. Veraltete Woerter werden jetzt
  unabhaengig von der Textlaenge markiert; ueberlappende Marker zaehlen nicht doppelt.
- Die lokale Satzreparatur erhaelt konkrete Saetze mit veralteten Wendungen und
  vollstaendiger Interpunktion. Moderne, klare Sprache gilt auch fuer Fantasy und
  historische Romane. Stilhinweise ersetzen keine inhaltliche Lektoratspruefung.
- Der Testlaeufer kann einen uebergebenen API-Key im fluechtigen Speicher nutzen,
  ohne fuer jeden neuen Build eine Keychain-Freigabe anzufordern oder ihn zu speichern.

## Lokale Beschleunigung

LocalSentenceIndex indiziert Wort-Dreiergruppen. Wiederholungs- und
Nacherzaehlungspruefung vergleichen nur Saetze mit gemeinsamen Gruppen. Die
bisherige Aehnlichkeitsschwelle bleibt unveraendert. Der Index benoetigt keinen
API-Aufruf und kein lokales Sprachmodell.

Isolierter synthetischer Vergleich auf diesem Mac: 165 Suchfaelle gegen 10000
vorbereitete Saetze. Alle Ergebnisse identisch zur alten Suche. Alte Suche:
0,625 Sekunden; Indexaufbau und neue Suche: 0,010 Sekunden (rund 60-fach).
Das ist keine Messung der gesamten Buchproduktion und keine garantierte Laufzeit.

## Pruefungen

- LocalEditorialAssistantProbe: 28 Pruefungen bestanden.
- ProseRepetitionProbe: bestanden.
- NarrativeQualityProbe: bestanden.
- SpellingReleaseProbe: Rechtschreibung, Dialogtypografie und semantische
  Exportblocker einschliesslich Aufhebung nach Korrektur bestanden.
- LocalSentenceIndexProbe: identische Ergebnisse sowie leere und inkrementelle
  Faelle bestanden.
- KDP-Sidecar: 5 Tests bestanden, einschliesslich Offline-Dry-Run.
- Ein vollstaendiger neuer Buchlauf mit diesem Build und eine reale Uebertragung
  an Amazon sind durch diese Pruefungen nicht belegt.

## Befunde aus der installierten Projektdatenbank

Geprueft wurde eine SQLite-Sicherung, nicht durch Veraendern der Originalprojekte.

- Naehe, wenn niemand sieht: pausierter Kapitelplan; fehlender Midpoint,
  Hoehepunkt und nicht nachvollziehbare Anschluesse im Plan. Noch kein Manuskript.
- Bevor ich dir verzeihe: fehlgeschlagene Szene 8/2; gemeldeter Rollenwiderspruch.
  Der konkrete Text und Figurenkanon muessen vor einer Reparatur gemeinsam
  bewertet werden; die Fehlermeldung allein beweist keinen echten Widerspruch.
- Die Nacht jagt dich: 17 offene Fehler-/Kritisch-Berichte, unter anderem
  wiederholte Enthuellungen, raeumliche/zeitliche Logik, offene Figurenboegen und
  ein unklar aufgeloestes Ende. Vorliegende Gesamtbewertung: 5/10.

Diese alten Manuskripte wurden durch den Softwarebuild nicht automatisch
ueberarbeitet. Fehlerfreiheit, Bestseller-Erfolg und ein bestimmtes Ergebnis
bei GPTZero sind nicht nachgewiesen oder zugesichert.
