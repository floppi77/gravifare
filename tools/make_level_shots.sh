#!/usr/bin/env bash
# Erzeugt die Vorschaubilder der Levelauswahl (assets/art/levels/<id>.jpg, 480×270) aus dem echten Spiel, ohne HUD.
# Unsichtbar über gamescope; eigene Datenordner, damit kein Spielstand berührt wird. Nach Änderungen an Leveln oder Grafik erneut ausführen.
# Aufruf: tools/make_level_shots.sh [Zielordner für Zwischenbilder]
set -u
TMP=${1:-$(mktemp -d)}
mkdir -p "$TMP/xdg/data" "$TMP/xdg/config" "$TMP/xdg/cache" assets/art/levels
export XDG_DATA_HOME="$TMP/xdg/data" XDG_CONFIG_HOME="$TMP/xdg/config" XDG_CACHE_HOME="$TMP/xdg/cache"
shot() {
	local id=$1
	timeout -k 3 30 gamescope --backend headless -W 1280 -H 720 -- godot --path . -w --resolution 1280x720 -- --level="$id" --seed=1 --no-hud --shot="$TMP/$id.png" --frames=40 >/dev/null 2>&1
}
for try in 1 2 3; do
	n=0
	for f in data/levels/*.json; do
		id=$(basename "$f" .json)
		[ -f "$TMP/$id.png" ] && continue
		shot "$id" &
		n=$((n + 1))
		if [ $((n % 4)) -eq 0 ]; then wait; fi
	done
	wait
done
python3 - "$TMP" <<'PY'
import glob, os, sys
from PIL import Image
for f in sorted(glob.glob(sys.argv[1] + "/*.png")):
    im = Image.open(f).convert("RGB").resize((480, 270), Image.LANCZOS)
    im.save("assets/art/levels/%s.jpg" % os.path.basename(f)[:-4], quality=88)
print(len(glob.glob("assets/art/levels/*.jpg")), "Bilder")
PY
