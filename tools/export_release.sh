#!/usr/bin/env bash
# Baut die Release-Dateien für Linux, Windows und macOS nach build/release/ (Godot-Vorlagen 4.7.2 nötig).
# Exportiert aus einer Kopie ohne addons/, tools/, tests/ und docs/; die Einträge der Editor-Anbindung werden dort aus project.godot entfernt,
# das Arbeitsverzeichnis bleibt unberührt. Jede Plattform kommt als ZIP mit Lizenztexten, dazu SHA256SUMS.txt.
# Aufruf aus der Projektwurzel: tools/export_release.sh [Version]     (Standard: Version aus export_presets.cfg)
set -eu
VER=${1:-$(sed -n 's/^application\/short_version="\(.*\)"$/\1/p' export_presets.cfg)}
MENU_VER=$(sed -n 's/^const VERSION := "\([^"]*\)".*$/\1/p' src/core/flow.gd)
[ "$MENU_VER" = "$VER" ] || { echo "Flow.VERSION in src/core/flow.gd ($MENU_VER) passt nicht zu $VER (Anzeige im Hauptmenü)" >&2; exit 1; }
OUT=build/release
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rsync -a --exclude .git --exclude .venv --exclude build --exclude scratch --exclude addons --exclude docs --exclude tests --exclude tools ./ "$WORK"/
sed -i '/^_mcp_game_helper=/d; /^\[editor_plugins\]$/,/^\[/{/^\[editor_plugins\]$/d; /^\[/!d}' "$WORK/project.godot"
sed -i 's|^\[rendering\]$|[rendering]\n\ntextures/vram_compression/import_etc2_astc=true|' "$WORK/project.godot"      # macOS (universal/arm64) verlangt ASTC, nur in der Exportkopie
rm -rf "$OUT"
mkdir -p "$OUT/stage"
# Windows-Icon: Godot trägt es per rcedit (unter Linux über Wine) in die Exe ein. rcedit wird geprüft geladen und
# in einer eigenen Editor-Konfiguration eingetragen, die Einstellungen des Nutzers bleiben unberührt.
RCEDIT_SHA256=3e7801db1a5edbec91b49a24a094aad776cb4515488ea5a4ca2289c400eade2a
RCEDIT=${RCEDIT:-$HOME/.cache/gravifare/rcedit-x64.exe}
if ! { [ -f "$RCEDIT" ] && echo "$RCEDIT_SHA256  $RCEDIT" | sha256sum -c - >/dev/null 2>&1; }; then
	mkdir -p "$(dirname "$RCEDIT")"
	curl -fsSL -o "$RCEDIT" https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe
	echo "$RCEDIT_SHA256  $RCEDIT" | sha256sum -c - >/dev/null || { echo "rcedit: Prüfsumme stimmt nicht" >&2; exit 1; }
fi
command -v wine >/dev/null || { echo "Wine fehlt (für das Windows-Icon nötig)" >&2; exit 1; }
export XDG_CONFIG_HOME="$WORK/.cfg"
mkdir -p "$XDG_CONFIG_HOME/godot"
printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/windows/rcedit = "%s"\nexport/windows/wine = "%s"\n' "$RCEDIT" "$(command -v wine)" > "$XDG_CONFIG_HOME/godot/editor_settings-4.7.tres"
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
cp LICENSE LICENSE-ASSETS.md THIRD_PARTY_NOTICES.md THIRD_PARTY_LICENSES.md CREDITS.md "$LIC/"
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
# Sicherheitsnetz: keine Spielstände, Einstellungen oder Läufe im Paket (die liegen sonst nur unter user://)
python3 -I - "$ABS" <<'P'
import glob, re, sys, zipfile
bad = []
for f in glob.glob(sys.argv[1] + "/*.zip"):
	for n in zipfile.ZipFile(f).namelist():
		if re.search(r"save_\d|\.sav$|settings\.cfg|controls\.cfg|replays|\.bad|\.tmp$|user_data", n, re.I):
			bad.append(f + ": " + n)
if bad:
	sys.exit("Spielstanddaten im Paket:\n" + "\n".join(bad))
print("Pakete enthalten keine Spielstände.")
P
(cd "$OUT" && sha256sum *.zip > SHA256SUMS.txt)
ls -la "$OUT"
