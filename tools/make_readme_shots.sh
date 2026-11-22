#!/usr/bin/env bash
# Erzeugt die Bilder der README (docs/media/de|en/<name>.jpg, 1280×720) aus dem echten Spiel in 1080p, je Deutsch und Englisch.
# Unsichtbar über gamescope; eigene Datenordner, damit kein Spielstand berührt wird. Nach sichtbaren Änderungen an Spiel oder Menüs erneut ausführen.
# Aufruf: tools/make_readme_shots.sh [Zielordner für Zwischenbilder] [nur,diese,namen]
set -u
TMP=${1:-$(mktemp -d)}
ONLY=${2:-}
mkdir -p "$TMP/xdg/data" "$TMP/xdg/config" "$TMP/xdg/cache"
export XDG_DATA_HOME="$TMP/xdg/data" XDG_CONFIG_HOME="$TMP/xdg/config" XDG_CACHE_HOME="$TMP/xdg/cache"

# Name | Bildnummer | Aufrufparameter (Flüge mit Autopilot, feste 60 Bilder/s, damit jedes Bild gleich wird; --hover zieht den Zeiger
# der unsichtbaren Aufnahme aus der Ecke, sonst zeigt das Menü den Tooltip des Knopfs darunter)
SHOTS=(
	"neon|700|--level=22 --autopilot --seed=1"
	"sector1|700|--level=5 --autopilot --seed=1"
	"sector3|700|--level=29 --autopilot --seed=1"
	"lava|700|--level=45 --autopilot --seed=1"
	"sector6|1300|--level=60 --autopilot --seed=1"
	"emergency|1300|--level=62 --autopilot --seed=1"
	"night|900|--shift --shift-map=8 --autopilot --seed=1 --no-brief"
	"tutorial|420|--level=tutorial"
	"menu|150|--scene=menu --hover=900,40@5"
	"garage|150|--scene=garage --hover=900,40@5"
	"workshop|400|--level=11 --debug-bay"
	"overtime|90|--ot=cross --ot-etappe=4 --ot-xp=99999 --ot-perks=scanner --hover=900,40@5"
	"overtime_fly|880|--ot=fly --ot-level=s4_03 --ot-curses=crooked,hotjet --ot-etappe=3 --autopilot --seed=1"
)

want() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }

for lang in de en; do
	for spec in "${SHOTS[@]}"; do
		IFS='|' read -r name frames args <<< "$spec"
		want "$name" || continue
		# shellcheck disable=SC2086
		timeout -k 3 120 gamescope --backend headless -W 1920 -H 1080 -w 1920 -h 1080 -- godot --path . -w --resolution 1920x1080 -- \
			$args --lang="$lang" --fixed-fps 60 --shot="$TMP/${lang}_${name}.png" --frames="$frames" >/dev/null 2>&1
	done
	if want editor; then
		timeout -k 3 120 gamescope --backend headless -W 1920 -H 1080 -w 1920 -h 1080 -- godot --path . -w --resolution 1920x1080 \
			-s tools/readme_editor_shot.gd -- --level-id=s6_05 --out="$TMP/${lang}_editor.png" --lang="$lang" >/dev/null 2>&1
	fi
done

python3 - "$TMP" <<'PY'
import glob, os, sys
from PIL import Image
n = 0
for f in sorted(glob.glob(sys.argv[1] + "/*_*.png")):
    lang, name = os.path.basename(f)[:-4].split("_", 1)
    if lang not in ("de", "en"):
        continue
    Image.open(f).convert("RGB").resize((1280, 720), Image.LANCZOS).save("docs/media/%s/%s.jpg" % (lang, name), quality=88)
    n += 1
print(n, "Bilder nach docs/media/de|en")
PY
