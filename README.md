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

## Export

- **EPUB 3** mit Navigationsdokument (nav), NCX-Fallback, korrektem
  `mimetype`-Eintrag (erster, unkomprimierter ZIP-Eintrag) und BCP-47-Sprachcode
- **PDF** mit echter Seitenumbruch-Logik (mehrseitige Kapitel), Titel-,
  Copyright- und Inhaltsverzeichnis-Seiten
- **DOCX** (WordprocessingML)
- **Berichte**: KDP-Formatbericht, Produktionsprotokoll, KI-Offenlegung
- Zielordner: `~/Documents/NovelForge/<Projekttitel>/` („Im Finder zeigen“ in der App)

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

## Technik

- macOS 14.0+, Swift 5.9+, SwiftUI, SwiftData
- Keine externen Abhängigkeiten

```bash
cd NovelForge
swift build
swift run NovelForge
```

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
