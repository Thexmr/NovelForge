# NovelForge - KI-gestützte Buchproduktion für macOS

Eine native macOS-Anwendung zur autonomen KI-Buchproduktion mit professioneller Pipeline-Struktur.

## Features

### Kernfunktionen
- **Native macOS-App** mit SwiftUI
- **15 Pipeline-Phasen** von Konzept bis Export
- **16 spezialisierte KI-Agenten** für verschiedene Aufgaben
- **Story Bible** für permanente Konsistenz
- **Mehrsprachigkeit** (Deutsch, Englisch, Französisch, Spanisch)
- **Professioneller Export** (EPUB, PDF, DOCX)
- **KDP-Kompatible Formatierung**

### Pipeline-Phasen
1. Projektanlage & Input-Validierung
2. Konzeptentwicklung (Prämisse, Logline, Exposé)
3. Strukturplanung (Plot, Figuren, Welt)
4. Kapitelplanung
5. Szenenplanung
6. Rohfassung schreiben (szene für szene)
7. Kapitelrevision
8. Gesamtmanuskript-Revision
9. Stil- und Sprachrevision
10. Korrektorat
11. Konsistenzprüfung
12. Copyright-Risiko-Prüfung
13. KDP-Formatierung
14. Export
15. Abschlussbericht

### KI-Provider
- **OpenAI** (GPT-4o, GPT-4o-mini, GPT-4-turbo)
- **Ollama** (lokale Modelle)
- **Anthropic Claude** (vorbereitet)
- **Kimi/K2 Cloud** (vorbereitet)
- **Benutzerdefinierte APIs** (vorbereitet)

### Sicherheit
- API-Keys in macOS Keychain
- Keine unverschlüsselte Speicherung
- Lokale Datenverarbeitung möglich
- Transparente Datenschutzoptionen

## Architektur

### Datenmodell
- **Project**: Buchprojekt mit Metadaten
- **BookProfile**: Konzept und Zielgruppe
- **StoryBible**: Zentrale Wissensdatenbank
- **CharacterProfile**: Figuren mit Entwicklung
- **LocationProfile**: Schauplätze
- **Chapter**: Kapitel mit Versionen
- **Scene**: Szenen mit Status
- **PipelineJob**: Aufgaben mit Heartbeat
- **QualityReport**: Qualitätsprüfungen

### Services
- **ProviderGateway**: Einheitliche KI-Anbindung
- **AgentRuntime**: Agentenausführung
- **PipelineOrchestrator**: Pipeline-Steuerung
- **ExportEngine**: Export-Formatierung
- **KeychainService**: Sichere API-Key-Speicherung

### UI
- **Dashboard**: Übersicht und Statistiken
- **NewBookWizard**: 5-Schritte-Assistent
- **PipelineTimeline**: Fortschrittsanzeige
- **ManuscriptView**: 3-Ansichts-Modi
- **StoryBibleView**: Zentrale Datenbank
- **AgentMonitor**: Echtzeit-Überwachung
- **ExportView**: Formatauswahl und Berichte
- **SettingsView**: Umfassende Einstellungen

## Technische Details

### Voraussetzungen
- macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

### Installation

```bash
cd NovelForge
swift build
swift run NovelForge
```

### Projektstruktur
```
NovelForge/
├── Sources/NovelForge/
│   ├── Models/
│   │   ├── Project.swift
│   │   ├── StoryBible.swift
│   │   ├── Chapter.swift
│   │   ├── Pipeline.swift
│   │   └── Provider.swift
│   ├── Services/
│   │   ├── ProviderGateway.swift
│   │   ├── Agents.swift
│   │   ├── PipelineOrchestrator.swift
│   │   ├── ExportEngine.swift
│   │   └── KeychainService.swift
│   ├── UI/
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── NewBookWizardView.swift
│   │   ├── ManuscriptView.swift
│   │   ├── AgentMonitorView.swift
│   │   └── SettingsView.swift
│   ├── Utils/
│   │   └── Helpers.swift
│   └── NovelForgeApp.swift
└── Package.swift
```

## Entwicklungsreihenfolge

1. ✅ Projekt- und Datenmodell
2. ✅ Provider Gateway (OpenAI, Ollama)
3. ✅ Pipeline-Orchestrator
4. ✅ Agenten (Input, Concept, Plot, Character, Draft, Proofreader)
5. ✅ SwiftUI Interface
6. ✅ Export Engine (EPUB, PDF, DOCX)
7. ⚠️ Qualitätssystem (Scores, Berichte)
8. ⏳ Autonomer Produktionsmodus

## MVP-Status

### Implementiert
- [x] Native macOS-App mit SwiftUI
- [x] Projektanlage und Verwaltung
- [x] OpenAI und Ollama Provider
- [x] Konzept-, Plot- und Figuren-Agenten
- [x] Kapitel- und Szenenplanung
- [x] Draft Writer mit Kontext
- [x] Continuity Agent
- [x] Proofreader Agent
- [x] Manuskriptansicht (Lesen/Bearbeiten/Vergleichen)
- [x] Fortschrittsanzeige
- [x] Heartbeat-System
- [x] EPUB/PDF/DOCX Export
- [x] KDP-Basisbericht
- [x] Story Bible
- [x] Einstellungen
- [x] Keychain-Integration
- [x] Fehlerbehandlung

### Geplant
- [ ] Voll autonomer Produktionsmodus
- [ ] Kimi/K2 Cloud Integration
- [ ] Anthropic Claude Integration
- [ ] Komplexe Ähnlichkeitssuche
- [ ] Teamfunktionen
- [ ] Cloud-Sync
- [ ] Automatische Update-Prüfung

## Qualitätsmetriken

Die App verwendet interne Scores:
- **Struktur-Score**: Plotlogik und Kapitelstruktur
- **Figuren-Score**: Motivation und Entwicklung
- **Stil-Score**: Stiltreue und Satzrhythmus
- **Konsistenz-Score**: Widerspruchsfreiheit
- **KDP-Score**: Exportqualität

## Datenschutz

- Projekte und Manuskripte: **Lokal**
- API-Keys: **macOS Keychain**
- Prompts: **An Provider gesendet**
- Keine versteckte Datenweitergabe
- Optionale Deaktivierung von Cloud-Verarbeitung

## Lizenz

Copyright © 2024. Alle Rechte vorbehalten.

## Hinweis

Diese App kann ein professionell aufgebautes, sauber formatiertes und geprüftes Manuskript erzeugen, aber **keinen kommerziellen Erfolg oder Bestseller-Status garantieren**.

Die finale Veröffentlichung bei Amazon KDP bleibt beim Nutzer. Die App führt keine automatische Veröffentlichung durch.

## Fehlerbehandlung

Die App erkennt und kategorisiert Fehler:
- API-Key-Fehler
- Provider-Ausfälle
- Netzwerkprobleme
- Rate Limits
- Modellfehler
- Ollama-Verbindungsprobleme
- Dateifehler
- Kontextüberschreitungen
- Systemfehler

Jede Fehlermeldung enthält:
- Was ist passiert?
- Warum ist es passiert?
- Was kann der Nutzer tun?
- Welcher Provider/Modell ist betroffen?