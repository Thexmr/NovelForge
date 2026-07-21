#!/bin/bash
# Baut einen 1-Klick-Installer NovelForge.dmg (Fenster mit App-Symbol + Verweis
# auf den Programme-Ordner → App per Drag&Drop installieren).
# Aufruf: ./Scripts/build-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/NovelForge.app"
DMG="build/NovelForge.dmg"
STAGE="build/dmg-stage"
VOL="NovelForge"

# App bei Bedarf bauen (build-app.sh bündelt auch den KDP-Sidecar).
if [ ! -d "$APP" ]; then
  echo "▸ App-Bundle fehlt – baue es zuerst …"
  ./Scripts/build-app.sh
fi

echo "▸ Staging vorbereiten …"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
# ditto erhält Symlinks/Rechte/Signatur im Bundle korrekt.
ditto "$APP" "$STAGE/NovelForge.app"
# Drag-Ziel: Verknüpfung auf /Applications.
ln -s /Applications "$STAGE/Programme"

echo "▸ DMG erzeugen (komprimiert) …"
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

rm -rf "$STAGE"
SIZE=$(du -h "$DMG" | cut -f1)
echo "✓ Fertig: $DMG ($SIZE)"
echo "  Installation: DMG öffnen → NovelForge.app auf 'Programme' ziehen."
echo "  Erststart (unsigniert): Rechtsklick → Öffnen (Gatekeeper)."
