#!/bin/bash
# Baut NovelForge als fertiges macOS-App-Bundle: build/NovelForge.app
# Aufruf: ./Scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Release-Build …"
swift build -c release

APP="build/NovelForge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/NovelForge "$APP/Contents/MacOS/NovelForge"

# App-Icon mitbündeln. Ohne CFBundleIconFile + .icns zeigt Finder/Dock das
# generische App-Platzhalter-Icon – das neue Markenzeichen wäre unsichtbar.
if [ -f "Assets/AppIcon.icns" ]; then
  cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
  echo "  ⚠ Assets/AppIcon.icns fehlt – App erscheint mit Standard-Icon."
fi

# KDP-Upload-Sidecar mitbündeln (Node/Puppeteer).
#
# Die Abhängigkeiten werden bei Bedarf HIER installiert. Vorher verlangte das Skript
# ein manuelles `npm install` – wurde das vergessen, entstand eine App, die aussieht
# wie fertig, deren KDP-Upload aber wortlos mit „Abhängigkeiten fehlen" abbricht.
# Genau das war der Zustand dieser Arbeitskopie.
if [ -d "kdp-sidecar" ]; then
  if [ ! -d "kdp-sidecar/node_modules" ]; then
    if command -v npm >/dev/null 2>&1; then
      echo "▸ Sidecar-Abhängigkeiten fehlen – installiere sie …"
      (cd kdp-sidecar && npm install --omit=dev --no-audit --no-fund >/dev/null 2>&1) \
        || echo "  ⚠ npm install fehlgeschlagen – der KDP-Upload bleibt deaktiviert."
    else
      echo "  ⚠ Node/npm nicht gefunden – der KDP-Upload bleibt deaktiviert."
      echo "    Nachrüsten: brew install node, danach dieses Skript erneut ausführen."
    fi
  fi

  echo "▸ Bündle KDP-Sidecar …"
  mkdir -p "$APP/Contents/Resources/kdp-sidecar"
  cp kdp-sidecar/index.js kdp-sidecar/package.json "$APP/Contents/Resources/kdp-sidecar/" 2>/dev/null || true
  if [ -d "kdp-sidecar/node_modules" ]; then
    cp -R kdp-sidecar/node_modules "$APP/Contents/Resources/kdp-sidecar/node_modules"
    echo "  ✓ Sidecar einsatzbereit ($(find kdp-sidecar/node_modules -maxdepth 1 -type d | wc -l | tr -d ' ') Pakete)"
  else
    echo "  ⚠ Sidecar ohne Abhängigkeiten gebündelt – KDP-Upload ist in dieser App deaktiviert."
  fi
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>de</string>
    <key>CFBundleDisplayName</key>
    <string>NovelForge</string>
    <key>CFBundleExecutable</key>
    <string>NovelForge</string>
    <key>CFBundleIdentifier</key>
    <string>com.novelforge.app</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NovelForge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.1.3</string>
    <key>CFBundleVersion</key>
    <string>45</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026. Alle Rechte vorbehalten.</string>
</dict>
</plist>
PLIST

# Ad-hoc-Signatur, damit die App lokal ohne Umwege startet.
codesign --force -s - "$APP" 2>/dev/null || true

echo "✓ Fertig: $APP"
echo "  Installation: NovelForge.app in den Programme-Ordner ziehen."
echo "  Erster Start (unsignierter Download): Rechtsklick → Öffnen."
