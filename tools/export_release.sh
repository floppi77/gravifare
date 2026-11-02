#!/usr/bin/env bash
# Baut die Release-Dateien für Linux, Windows und macOS nach build/release/ (Godot-Vorlagen 4.7.2 nötig).
# Exportiert aus einer Kopie ohne addons/, tools/, tests/ und docs/; die Einträge der Editor-Anbindung werden dort aus project.godot entfernt,
# das Arbeitsverzeichnis bleibt unberührt. Jede Plattform kommt als ZIP mit Lizenztexten, dazu SHA256SUMS.txt.
# Aufruf aus der Projektwurzel: tools/export_release.sh [Version]     (Standard: Version aus export_presets.cfg)
set -eu
VER=${1:-$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' export_presets.cfg)}
OUT=build/release
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rsync -a --exclude .git --exclude .venv --exclude build --exclude addons --exclude docs --exclude tests --exclude tools ./ "$WORK"/
sed -i '/^_mcp_game_helper=/d; /^\[editor_plugins\]$/,/^$/d' "$WORK/project.godot"
rm -rf "$OUT"
mkdir -p "$OUT/stage"
ABS=$(pwd)/$OUT
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true

cat > "$WORK/_license.gd" <<'G'
extends SceneTree
func _initialize() -> void:
	FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string(Engine.get_license_text())
	quit()
G
LIC=$ABS/stage/licenses
mkdir -p "$LIC"
godot --headless --path "$WORK" -s "$WORK/_license.gd" -- "$LIC/GODOT_LICENSE.txt" >/dev/null 2>&1
cp THIRD_PARTY_LICENSES.md CREDITS.md "$LIC/"
for d in assets/fonts/*/; do
	cp "$d/OFL.txt" "$LIC/$(basename "$d")_OFL.txt"
done

pack() {   # Verzeichnis, ZIP-Datei (anlegen oder erweitern)
	python3 -I - "$1" "$2" <<'P'
import os, sys, zipfile
src, dst = sys.argv[1:3]
with zipfile.ZipFile(dst, "a", zipfile.ZIP_DEFLATED) as z:
	for root, _, files in os.walk(src):
		for f in files:
			p = os.path.join(root, f)
			z.write(p, os.path.relpath(p, src))
P
}
build() {   # Preset, Dateiname im Export, ZIP-Name (macOS: Godot liefert schon ein ZIP mit der App)
	local dir="$ABS/stage/$1"
	mkdir -p "$dir"
	godot --headless --path "$WORK" --export-release "$1" "$dir/$2" 2>&1 | grep -E "^(ERROR|SCRIPT ERROR)" || true
	[ -e "$dir/$2" ] || { echo "Export $1 fehlgeschlagen" >&2; exit 1; }
	if grep -aq "_mcp_game_helper" "$dir/$2"; then
		echo "Editor-Anbindung steckt im Build ($1)" >&2
		exit 1
	fi
	mkdir -p "$ABS/stage/extra/$1"
	cp -r "$LIC" "$ABS/stage/extra/$1/licenses"
	cp README.md "$ABS/stage/extra/$1/README.md"
	if [ "$1" = macOS ]; then
		cp "$dir/$2" "$ABS/$3"
	else
		pack "$dir" "$ABS/$3"
	fi
	pack "$ABS/stage/extra/$1" "$ABS/$3"
}
build Linux gravifare.x86_64 "GraviFare-$VER-linux-x86_64.zip"
build Windows gravifare.exe "GraviFare-$VER-windows-x86_64.zip"
build macOS GraviFare.zip "GraviFare-$VER-macos-universal.zip"
rm -rf "$ABS/stage"
(cd "$OUT" && sha256sum *.zip > SHA256SUMS.txt)
ls -la "$OUT"
