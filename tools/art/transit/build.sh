#!/usr/bin/env bash
# Zwischenflug-Hintergründe neu erzeugen (Runde 68):
#   1. Blender-Szenen je Sektor als Tiefenebenen rendern (bl/sN_*.py, Blender 5.x, Cycles; GPU empfohlen)
#   2. Schwarzes Loch per Strahlverfolgung (blackhole.py)
#   3. Nebel, Leuchthöfe, Pixelstil und Ebenen zusammensetzen (gen_layers.py) -> assets/art/transit/
# Zwischenstände liegen in $TRANSIT_RENDER (Standard ~/.cache/gravifare-transit), nicht im Repo.
set -euo pipefail
cd "$(dirname "$0")"
R=${TRANSIT_RENDER:-$HOME/.cache/gravifare-transit}
mkdir -p "$R"
for f in bl/s[1-8]_*.py; do
	s=$(basename "$f" | cut -c2)
	blender -b --factory-startup --python-exit-code 1 --python "$f" -- "$R/s${s}_{}.png"
done
python3 blackhole.py "$R"
TRANSIT_RENDER="$R" python3 gen_layers.py ../../../assets/art/transit "$@"
