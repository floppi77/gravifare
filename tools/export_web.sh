#!/usr/bin/env bash
# Baut die Browser-Fassung (Godot-Web, ohne Threads: läuft auf itch.io ohne besondere Server-Header) nach build/web/
# und packt sie als build/release/GraviFare-<Version>-web.zip zum Hochladen (itch.io: „HTML“, index.html im ZIP-Wurzelverzeichnis).
# Nur Englisch: die Sprachausgabe der übrigen Sprachen bleibt draußen (Größe), das Spiel bietet im Browser nur Englisch an (Loc.available).
# Exportiert aus einer Kopie wie tools/export_release.sh; das Arbeitsverzeichnis bleibt unberührt.
# Aufruf aus der Projektwurzel: tools/export_web.sh [Version]
set -eu
VER=${1:-$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' export_presets.cfg)}
OUT=build/web
ZIP=build/release/GraviFare-$VER-web.zip
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rsync -a --exclude .git --exclude .venv --exclude build --exclude scratch --exclude addons --exclude docs --exclude tests --exclude tools ./ "$WORK"/
sed -i '/^_mcp_game_helper=/d; /^\[editor_plugins\]$/,/^\[/{/^\[editor_plugins\]$/d; /^\[/!d}' "$WORK/project.godot"
for l in de fr es it pt pl ref; do rm -rf "$WORK/assets/audio/voice/$l"; done
# Ton wie auf dem Desktop: alles über Godots eigenen Mischer („Stream“). Im Browser-Standard „Sample“ spielten Effekte und Stimmen
# stumm (die Busse SFX/Voice entstehen erst zur Laufzeit in Sfx._ready, die Sample-Wiedergabe des Browsers kennt sie nicht).
python3 -I - "$WORK/project.godot" <<'P'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
line = "general/default_playback_type.web=0"
if "[audio]" in s:
	s = s.replace("[audio]\n", "[audio]\n\n" + line + "\n", 1)
else:
	s = s.rstrip("\n") + "\n\n[audio]\n\n" + line + "\n"
open(p, "w", encoding="utf-8").write(s)
P
grep -q "^general/default_playback_type.web=0" "$WORK/project.godot" || { echo "Ton-Einstellung fehlt in der Exportkopie" >&2; exit 1; }
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
rm -rf "$OUT"
mkdir -p "$OUT" build/release
ABS=$(pwd)/$OUT
godot --headless --path "$WORK" --export-release "Web" "$ABS/index.html" 2>&1 | grep -E "^(ERROR|SCRIPT ERROR)" || true
[ -e "$OUT/index.html" ] || { echo "Web-Export fehlgeschlagen" >&2; exit 1; }
if grep -aq "_mcp_game_helper" "$OUT"/*.pck; then
	echo "Editor-Anbindung steckt im Build (Web)" >&2
	exit 1
fi
rm -f "$ZIP"
(cd "$OUT" && python3 -I -c "
import os, zipfile
with zipfile.ZipFile('../../$ZIP', 'w', zipfile.ZIP_DEFLATED) as z:
    for f in sorted(os.listdir('.')):
        z.write(f, f)
")
ls -la "$OUT" "$ZIP"
