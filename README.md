# NovelForge – Autonome KI-Buchproduktion für macOS

Eine native macOS-App (SwiftUI + SwiftData), die Bücher vollautomatisch produziert:
von der Idee über Konzept, Plot, Figuren, Kapitel- und Szenenplanung bis zu
Rohfassung, Revision, Korrektorat und Export – mit einem einzigen Klick.

## Funktionsweise

Nach dem 5-Schritte-Assistenten („Neues Buch“) startet die Pipeline sofort und
arbeitet alle Phasen autonom ab. Jede Phase ist **idempotent**: Bereits erledigte
Arbeit (geplante Kapitel, geschriebene Szenen, überarbeitete Kapitel) wird beim
Fortsetzen übersprungen. Pausieren, Fortsetzen und ein hartes Kostenlimit sind
jederzeit möglich – ohne doppelte API-Kosten.

### Pipeline-Phasen

1. **Projektanlage & Input-Validierung** (lokal, inkl. Copyright-Heuristik)
2. **Konzeptentwicklung** – Prämisse, Logline, Exposé, Thema (KI, strukturiert geparst)
3. **Strukturplanung** – vollständiger Plot + Figurenensemble in der Story Bible
4. **Kapitelplanung** – KI plant Titel, Ziel und Konflikt jedes Kapitels
5. **Szenenplanung** – KI plant 3–5 Szenen pro Kapitel (Perspektive, Ort, Ziel, Hindernis, Wendung)
6. **Rohfassung** – Szene für Szene, mit fortlaufenden Kontext-Zusammenfassungen
   für Kontinuität über das gesamte Buch
7. **Kapitelrevision** – KI-Lektorat pro Kapitel (mit Schutz vor Textverlust)
8. **Gesamtlektorat** – Konsistenzprüfung über alle Kapitel (Zeitlinie, Figuren, Logik)
9. **Korrektorat** – Rechtschreibung/Grammatik pro Kapitel
10. **Copyright-Prüfung** – lokale Risikoanalyse
11. **KDP-Formatierung** – Qualitätsbewertung (Struktur, Figuren, Stil, Konsistenz, Format)
12. **Export** – EPUB, PDF, DOCX nach `~/Documents/NovelForge/<Titel>/`

### Die 14 Agenten

Input Agent · Concept Agent · Plot Architect · Character Architect ·
Chapter Planner · Scene Planner · Draft Writer · Context Summarizer ·
Chapter Reviser · Consistency Checker · Proofreader · Copyright Checker ·
KDP Formatter · Export Agent

Alle Schritte sind live im **Agenten-Monitor** sichtbar (Status, Dauer, Tokens, Fehler).

## KI-Provider

| Provider | Status | Hinweise |
|---|---|---|
| OpenAI | ✅ implementiert | gpt-4o, gpt-4o-mini, gpt-4-turbo |
| Anthropic Claude | ✅ implementiert | claude-opus-4-8, claude-sonnet-4-6, claude-haiku-4-5 (Messages API) |
| Ollama (lokal) | ✅ implementiert | kostenlos, z.B. llama3.1, qwen2.5 |
| Kimi/Moonshot | ✅ implementiert | OpenAI-kompatibel |
| Benutzerdefiniert | ✅ implementiert | beliebige OpenAI-kompatible Endpunkte |

- Automatische Wiederholversuche mit Backoff bei Rate Limits und Netzwerkfehlern
- Token-Zählung und laufende **Kostenschätzung** mit hartem Limit pro Projekt
- Verbindungstest pro Provider in den Einstellungen

## Sicherheit

- API-Keys liegen **ausschließlich in der macOS Keychain** – sie werden nie in
  UserDefaults oder Projektdateien geschrieben (die Provider-Konfiguration wird
  ohne Key serialisiert).
- Manuskripte und Projekte bleiben lokal (SwiftData).
- Prompts gehen nur an den vom Nutzer gewählten Provider.

## Export (KDP-konform)

- **EPUB 3** mit Verlags-Stylesheet (Blocksatz, Erstzeileneinzug, zentrierte
  Szenentrenner), Navigationsdokument (nav), NCX-Fallback, korrektem
  `mimetype`-Eintrag, BCP-47-Sprachcode und `dc:description`
- **PDF im echten Buchsatz**: KDP-Trim-Größen (5×8, 5,5×8,5, 6×9 Zoll),
  Spiegelränder mit Bundsteg nach offizieller KDP-Tabelle (abhängig von der
  Seitenzahl), Blocksatz mit Erstzeileneinzug, Seitenzahlen, Kapitel- und
  Szenentrenner-Satz, Titel-/Copyright-/Inhaltsseiten
- **DOCX** mit echten Formatvorlagen (styles.xml: Title, Heading 1, Scene Break),
  Blocksatz und Erstzeileneinzug
- **KDP-Metadaten**: automatisch generierter Verkaufstext (Produktbeschreibung),
  7 Keywords und Kategorie-Vorschläge – bereit zum Einfügen bei der Veröffentlichung
- **Berichte**: KDP-Formatbericht, Produktionsprotokoll, KI-Offenlegung
- Zielordner: `~/Documents/NovelForge/<Projekttitel>/` („Im Finder zeigen“ in der App)

## Schreibqualität (Bestseller-Methodik)

- **Dramaturgie**: Der Plot wird nach bewährter 3-Akt-Beat-Struktur gebaut
  (auslösendes Ereignis ~10 %, erster Wendepunkt ~25 %, Mittelpunkt-Umkehr 50 %,
  Tiefpunkt ~75 %, Höhepunkt ~90 %) – inklusive Nebenhandlung und Open Loops.
- **Kapitel-Hooks**: Jedes Kapitel endet planmäßig mit einem Haken (Frage,
  Bedrohung, Enthüllung oder Entscheidung); das Tempo wechselt bewusst.
- **Page-Turner-Techniken** im Szenen-Prompt: ständig mindestens eine offene
  Frage, Mikro-Spannung in ruhigen Momenten, dramatische Ironie, Zeitdruck.
- **Handwerk**: Szenenstruktur Ziel → Konflikt → Wendung, tiefe Perspektive,
  Subtext-Dialoge, Verbotsliste für KI-Floskeln, Genre-Vorgaben (Thriller,
  Romance, Fantasy, Horror, Historisch), Sonderbehandlung der ersten Szene
  (Amazon-Leseprobe!) und des Finales.
- **Nahtlose Übergänge**: Jede Szene erhält das wörtliche Ende der Vorszene
  plus die Zusammenfassungen der bisherigen Handlung.
- **Qualitäts-Gate**: Deutlich zu kurze Szenen werden automatisch einmal
  vertieft und erweitert; verbleibende Abweichungen werden protokolliert.

## Geschwindigkeit

Unabhängige Arbeitsschritte laufen parallel (Szenenplanung, Kapitelrevision,
Korrektorat – je 3 Anfragen gleichzeitig, lokales Ollama seriell). Die
Rohfassung bleibt bewusst sequenziell, damit jede Szene auf der vorigen
aufbaut. Token-Abrechnung und Kostenlimit gelten auch für parallele Anfragen.

## CI

GitHub Actions baut jeden Push auf einem macOS-Runner (`swift build`),
siehe `.github/workflows/build.yml`.

## UI

- **Dashboard** – Statistiken, Live-Produktionsbanner, zuletzt abgeschlossene Bücher
- **Projekte** – Liste mit Status, Fortschritt, Kontextmenü (Starten/Fortsetzen/Löschen),
  Detailansicht mit Qualitätsmetriken
- **Produktion** – Live-Fortschritt mit Phasen-Checkliste, Kapitel/Szenen-Zähler,
  Token-/Kostenanzeige, Restzeitschätzung, Pause & Abbruch
- **Agenten-Monitor** – alle Pipeline-Schritte in Echtzeit, filterbar
- **Manuskript** – Lesen (Serifen-Typografie) / Bearbeiten / Vergleichen (Rohfassung vs. final)
- **Story Bible** – Figuren, Orte, Plot, Stilregeln
- **Export** – Formate, Berichte, automatisch berechnete Qualitätsmetriken
- **Einstellungen** – Vorgaben, Erscheinungsbild (wird live angewendet),
  Provider-Verwaltung, Datenschutz

## Qualitätsmetriken

Werden automatisch aus echten Projektdaten berechnet (keine Platzhalter):

- **Struktur** – Anteil Kapitel mit Ziel und geplanten Szenen
- **Figuren** – Vollständigkeit des Figurenensembles
- **Stil** – Anteil Szenen innerhalb ±25 % der Zielwortzahl
- **Konsistenz** – abzüglich gefundener Widersprüche aus dem Gesamtlektorat
- **KDP-Format** – Abweichung vom Zielumfang

## Dauerproduktion (Unlimited-Modus)

Unter **Produktion → „Dauerproduktion starten"** erfindet NovelForge eigene
Buchideen und produziert Buch für Buch in den Ausgabeordner – **endlos, bis
Stopp gedrückt wird** (optional mit Obergrenze). Konfigurierbar: Genre und
Stil (fest oder „Zufällig" für Abwechslung), Seiten pro Buch, Formate,
Kostenlimit **pro Buch**, Ausgabeordner. Schlägt ein Buch fehl, wird es
protokolliert (und bleibt fortsetzbar) – die Dauerproduktion macht
automatisch mit dem nächsten Buch weiter.

Für maximale Auslastung kann der Auto-Modus **1 bis 10 Bücher parallel**
produzieren. Jedes parallele Buch läuft in einem getrennten Worker mit eigenem
Projektfortschritt, eigenem Kostenlimit pro Buch und fortsetzbarem Speicherstand.

## Installation

### macOS (fertige App)

1. Im Repo unter **Actions → letzter grüner Lauf → Artifacts** die Datei
   `NovelForge-macOS.zip` herunterladen und entpacken.
2. `NovelForge.app` in den Programme-Ordner ziehen.
3. Erster Start: **Rechtsklick → Öffnen** (die App ist nicht notariell
   beglaubigt, da ohne Apple-Developer-Zertifikat gebaut).

### macOS (selbst bauen)

```bash
./Scripts/build-app.sh     # erzeugt build/NovelForge.app
# oder klassisch:
swift run NovelForge
```

Voraussetzungen: macOS 14.0+, Xcode 15+ bzw. Swift 5.9+.

### Windows

**Nicht verfügbar.** NovelForge ist eine native macOS-App (SwiftUI, SwiftData,
PDFKit, Keychain) – diese Frameworks existieren nur auf Apple-Plattformen.
Eine Windows-Version wäre kein Port, sondern eine vollständige
Neuentwicklung in einem plattformübergreifenden Framework und damit ein
eigenes Projekt.

## Technik

- macOS 14.0+, Swift 5.9+, SwiftUI, SwiftData
- Keine externen Abhängigkeiten

### Projektstruktur

```
Sources/NovelForge/
├── Models/          Project, StoryBible, Chapter, Pipeline, Provider
├── Services/        ProviderGateway, Agents (Prompts+Parser), PipelineOrchestrator,
│                    ExportEngine, KeychainService, ProviderStore
├── UI/              ContentView, DashboardView, NewBookWizardView,
│                    ManuscriptView, AgentMonitorView, SettingsView
└── Utils/           Helpers (Validierung, Qualitätsmetriken, Formatierung)
```

## Fehlerbehandlung

Jeder Fehler wird kategorisiert (API-Key, Provider, Netzwerk, Rate Limit,
Kostenlimit, Ollama, Kontextlänge …) und mit konkreter Handlungsempfehlung
angezeigt. Schlägt eine Produktion fehl, bleibt der gesamte Fortschritt
erhalten und kann mit einem Klick fortgesetzt werden.

## Hinweis

NovelForge erzeugt ein professionell strukturiertes, geprüftes und formatiertes
Manuskript – garantiert aber keinen kommerziellen Erfolg. Die Veröffentlichung
(z. B. bei Amazon KDP) bleibt beim Nutzer; die App veröffentlicht nichts
automatisch. Die Copyright-Prüfung ist eine interne Heuristik ohne juristische
Garantie.

## Lizenz

Copyright © 2026. Alle Rechte vorbehalten.
