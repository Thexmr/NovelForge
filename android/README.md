# NovelForge für Android (v0.1)

Smartphone-optimierte Neuimplementierung der autonomen KI-Buchproduktion in
Kotlin + Jetpack Compose. **Eigenständiges Projekt** – dieser Ordner ist so
abgekapselt, dass er 1:1 in ein eigenes Repo (`novelforge-android`)
verschoben werden kann.

## Funktionsumfang v0.1

- **Autonome Pipeline** (Portierung der macOS-Logik): Konzept → Plot →
  Figuren → Kapitelplan → Szenenplan → Rohfassung → Kapitelrevision →
  Korrektorat → KDP-Metadaten → EPUB-Export
- **Bestseller-Handwerk**: identische Prompts wie auf macOS (3-Akt-Beats,
  Kapitel-Hooks, Page-Turner-Techniken, Anti-Floskeln, Genre-Regeln,
  Langstrecken-Gedächtnis mit Kapitel-Digests, Qualitäts-Gate für zu kurze
  Szenen)
- **Unlimited-Modus**: Foreground-Service erfindet eigene Buchideen und
  produziert Buch für Buch – **bis Stopp gedrückt wird**; läuft auch, wenn
  die App im Hintergrund ist
- **Resume-fähig**: Jede Szene wird sofort gespeichert; abgebrochene Bücher
  setzen exakt dort fort
- **Provider**: OpenAI, Anthropic Claude, Ollama (im Heimnetz!), Kimi,
  eigener OpenAI-kompatibler Endpunkt – API-Keys verschlüsselt im Android
  Keystore
- **Export**: spezifikationskonformes EPUB 3 (mimetype als erster,
  unkomprimierter ZIP-Eintrag, nav + NCX) + TXT nach
  `Android/data/com.novelforge.android/files/NovelForge/<Titel>/`
- **UI**: Bottom-Navigation (Bücher / Produktion / Einstellungen),
  Buch-Reader, Fortschritt mit Phase/Tokens, Onboarding-Hinweise

## Installation

**APK aus der CI**: GitHub → Actions → Workflow „Android" → Artifacts →
`NovelForge-Android-APK` herunterladen, auf das Gerät übertragen,
Installation aus unbekannten Quellen erlauben.

**Selbst bauen** (Android Studio oder CLI):

```bash
cd android
gradle wrapper --gradle-version 8.7   # einmalig, oder Android Studio nutzen
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

## Bewusste v0.1-Entscheidungen

- JSON-Datei-Persistenz statt Room (kein Codegen → maximal stabile Builds);
  Datenmodell ist 1:1 migrierbar
- Sequenzielle Pipeline (akku- und ratelimit-schonend auf dem Smartphone)
- Kein PDF/DOCX-Export (EPUB ist der KDP-Weg; Print-Satz bleibt Aufgabe der
  macOS-App) – Roadmap: Teilen-Intent, PDF, Konsistenzprüfung, Kostenlimit-UI

## Hinweis Dauerbetrieb

Der Unlimited-Modus läuft als Foreground-Service mit Benachrichtigung.
Für lange Läufe: Gerät ans Ladegerät und für NovelForge die
Akku-Optimierung deaktivieren (Einstellungen → Apps → NovelForge → Akku).
