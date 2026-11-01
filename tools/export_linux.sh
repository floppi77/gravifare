#!/usr/bin/env bash
# Baut den Linux-Export nach build/linux/ (Godot-Vorlagen 4.7.2 nötig) und legt die Lizenztexte bei.
# Exportiert aus einer Kopie ohne addons/, tools/, tests/ und docs/; die Einträge der Editor-Anbindung werden dort aus project.godot entfernt,
# das Arbeitsverzeichnis bleibt unberührt. Am Ende prüft das Skript, dass nichts davon im Build steckt.
# Aufruf aus der Projektwurzel: tools/export_linux.sh
set -eu
OUT=build/linux
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
rsync -a --exclude .git --exclude .venv --exclude build --exclude addons --exclude docs --exclude tests --exclude tools ./ "$WORK"/
sed -i '/^_mcp_game_helper=/d; /^\[editor_plugins\]$/,/^$/d' "$WORK/project.godot"
rm -rf "$OUT"
mkdir -p "$OUT/licenses"
ABS=$(pwd)/$OUT
godot --headless --path "$WORK" --import >/dev/null 2>&1 || true
godot --headless --path "$WORK" --export-release Linux "$ABS/gravifare.x86_64" 2>&1 | grep -E "^(ERROR|SCRIPT ERROR)" || true
[ -x "$OUT/gravifare.x86_64" ] || { echo "Export fehlgeschlagen" >&2; exit 1; }
if grep -aq "_mcp_game_helper" "$OUT/gravifare.x86_64"; then
	echo "Editor-Anbindung steckt im Build" >&2
	exit 1
fi
if git show HEAD:project.godot | grep -q "_mcp_game_helper\|godot_ai"; then
	echo "Warnung: Editor-Anbindung ist in project.godot committet" >&2
fi
cat > "$WORK/_license.gd" <<'G'
extends SceneTree
func _initialize() -> void:
	FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string(Engine.get_license_text())
	quit()
G
godot --headless --path "$WORK" -s "$WORK/_license.gd" -- "$ABS/licenses/GODOT_LICENSE.txt" >/dev/null 2>&1
cp THIRD_PARTY_LICENSES.md CREDITS.md "$OUT/licenses/"
for d in assets/fonts/*/; do
	cp "$d/OFL.txt" "$OUT/licenses/$(basename "$d")_OFL.txt"
done
ls -la "$OUT" "$OUT/licenses"
