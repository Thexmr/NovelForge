# Korrektur-Ratsche und sicherer KDP-Upload

## Ziel

NovelForge uebernimmt die nachweislich wirksamen Schutzmechanismen aus KI Korrektur,
ohne dessen experimentelle Stilregeln oder Python-Laufzeit einzubauen. Gleichzeitig
wird der KDP-Entwurfsupload lokal und reproduzierbar pruefbar, ohne dass ein Testlauf
das echte KDP-Konto veraendert.

## Korrektur-Ratsche

Jede umfangreiche Romanrevision muss vor dem Speichern zwei Huerden bestehen:

1. Ein deterministischer Inhaltsschutz prueft Zahlen, Verneinungen, Erzaehlzeit,
   Perspektive, Dialogzeichen und auffaellig zusammengestrichene Gegenstandslisten.
2. Ein blinder Lesevergleich legt Original und Kandidat demselben unabhaengigen
   Lektormodell zweimal in vertauschter Reihenfolge vor. Der Prompt verraet nicht,
   welche Fassung bearbeitet wurde.

Nur wenn der Kandidat in beiden Reihenfolgen gewinnt, ersetzt er das Original. Bei
Gleichstand, widerspruechlichem Urteil, unlesbarer Antwort oder Providerfehler bleibt
das Original erhalten. Der Schutz gilt fuer Kapitelrevision, Anfangsoptimierung und
spaetere KI-Stilbereinigung. Satzreparaturen behalten zusaetzlich ihre bereits
eingebaute Nummern- und Dialogpruefung.

Die experimentellen KI-Korrektur-Regeln fuer Ankerwoerter, pauschale Klischees und
Rhythmus werden nicht uebernommen, weil ihre eigenen Messungen keinen stabilen Nutzen
zeigen.

## KDP-Upload

`dryRun` wird zu einem echten Offline-Preflight. Er validiert Jobdaten, EPUB, Cover,
Preis, Metadaten, Keyword- und Kategoriengrenzen und schreibt einen maschinenlesbaren
Status, startet aber weder Chrome noch KDP und legt keinen Titel an.

Ein echter Upload darf weiterhin nur einen Entwurf speichern und niemals den
Veroeffentlichen-Knopf betaetigen. Er gilt nur dann als vollstaendig erfolgreich, wenn
der Sidecar `ok: true`, keine offenen Pflichtfelder und eine plausible KDP-Entwurfs-URL
liefert. Ein gespeicherter, aber unvollstaendiger Entwurf wird als eigener Zustand mit
konkreten offenen Punkten gemeldet.

Vor jedem Lauf werden alte Statusdateien entfernt. Job- und Statusdateien werden nach
der Auswertung geloescht, damit Metadaten nicht unnoetig liegen bleiben. Login-Check und
Offline-Preflight sind nicht schreibend; ein echter Kontotest endet weiterhin vor der
Veroeffentlichung.

## Tests

- Inhaltsschutz fuer Zahlen, Verneinungen, Perspektive, Erzaehlzeit, Dialogzeichen und
  gestrichene Gegenstaende.
- Blindvergleich wertet beide Reihenfolgen korrekt aus und ist bei Uneinigkeit fail-safe.
- Bestehende Revisionen werden bei Gleichstand nicht verschlechtert.
- Node-Tests validieren gueltige und ungueltige Upload-Jobs.
- Offline-Dry-Run startet keinen Browser und erzeugt einen erfolgreichen Status.
- Sidecar-Ergebnisparser unterscheidet vollstaendig, unvollstaendig und fehlgeschlagen.
- Swift-Build, Logik-Probes, Sidecar-Tests, lokaler EPUB/Proof-Lauf und KDP-Offline-
  Preflight muessen bestehen.
- Ein echter Veroeffentlichungsklick ist nicht Bestandteil der Tests.
