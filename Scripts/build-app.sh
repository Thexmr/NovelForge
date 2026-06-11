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
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NovelForge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
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
