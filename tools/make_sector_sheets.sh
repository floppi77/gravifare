#!/usr/bin/env bash
# Erzeugt je Sektor ein Übersichtsbild (docs/levels/sektor_<n>.jpg): alle elf Level im echten Spiel mit großer Levelnummer und Name.
# Dunkle Level werden aufgehellt (--dark=0), damit der Grundriss erkennbar ist. Unsichtbar über gamescope, eigene Datenordner,
# kein Spielstand wird berührt. Nach Änderungen an Leveln oder Grafik erneut ausführen.
# Aufruf aus der Projektwurzel: tools/make_sector_sheets.sh [Zielordner für Zwischenbilder]
set -u
TMP=${1:-$(mktemp -d)}
mkdir -p "$TMP/xdg/data" "$TMP/xdg/config" "$TMP/xdg/cache" docs/levels
export XDG_DATA_HOME="$TMP/xdg/data" XDG_CONFIG_HOME="$TMP/xdg/config" XDG_CACHE_HOME="$TMP/xdg/cache"
shot() {
	local id=$1
	timeout -k 3 30 gamescope --backend headless -W 1280 -H 720 -- godot --path . -w --resolution 1280x720 -- --level="$id" --seed=1 --no-hud --dark=0 --shot="$TMP/$id.png" --frames=40 >/dev/null 2>&1
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
python3 tools/make_sector_sheets.py "$TMP"
