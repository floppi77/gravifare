class_name OvertimeIcon
extends Control
## Kleine Pixel-Symbole der Sonderschicht (im Pixelraster gezeichnet, keine Bilddatei): Ausstattung nach Bereich mit Rahmen in der Farbe der
## Seltenheit, Zwischenfälle nach Art (Taxi, Anzeige, Level, Geld) als Warnzeichen.

const RAR_COLOR := {"c": Color("#e6ecff"), "r": Color("#5ab8ff"), "l": Color("#ffd23a")}
const CAT_COLOR := {"jets": Color("#ff9a3a"), "fuel": Color("#ffcb3d"), "hull": Color("#35c8e0"), "land": Color("#7dff9a"), "guest": Color("#ff7ad9"),
	"life": Color("#ff5a6e"), "run": Color("#a9b8ff"), "legend": Color("#ffe14a"),
	"sim": Color("#ff6a5a"), "ui": Color("#ff9a3a"), "level": Color("#ffcb3d"), "econ": Color("#ff7ad9")}
## 7×7-Muster je Symbol ('#' Farbe, '+' hell)
const GLYPH := {
	"jets": ["...#...", "..###..", "..#+#..", ".##+##.", ".#+++#.", "..#+#..", "...#..."],
	"fuel": ["...#...", "..###..", ".##+##.", ".#+++#.", ".#+++#.", ".##+##.", "..###.."],
	"hull": [".#####.", ".#+++#.", ".#+++#.", ".#+++#.", "..#+#..", "..#+#..", "...#..."],
	"land": ["..###..", ".#####.", "..#.#..", "..#.#..", ".#...#.", ".#...#.", "##...##"],
	"guest": ["..###..", "..#+#..", "..###..", ".#####.", "#.###.#", "..#.#..", "..#.#.."],
	"life": [".##.##.", "#++#++#", "#+++++#", "#+++++#", ".#+++#.", "..#+#..", "...#..."],
	"run": ["#######", "#+...+#", "#.....#", "#..+..#", "#.....#", "#+...+#", "#######"],
	"legend": ["...#...", "...#...", "#######", ".#+++#.", "..#+#..", ".#.#.#.", "#.....#"],
	"sim": ["...#...", "..#+#..", "..#+#..", ".#.+.#.", ".#.+.#.", "#.....#", "###+###"],
	"ui": ["#######", "#+..#.#", "#.+#..#", "#..#+.#", "#.#..+#", "#######", "..###.."],
	"level": ["...#...", "..#+#..", "..###..", ".#+++#.", ".#####.", "#+++++#", "#######"],
	"econ": [".#####.", "#+...+#", "#.###.#", "#.....#", "#.###.#", "#+...+#", ".#####."],
}

var kind := "perk"          # "perk" oder "curse"
var cat := "run"
var rar := "c"

func _draw() -> void:
	var g: Array = GLYPH.get(cat, GLYPH.run)
	var col: Color = CAT_COLOR.get(cat, Color.WHITE)
	var px := floorf(minf(size.x, size.y) / 9.0)
	px = maxf(px, 1.0)
	var off := (size - Vector2(9, 9) * px) * 0.5
	off = Vector2(roundf(off.x), roundf(off.y))
	if kind == "perk":
		var rc: Color = RAR_COLOR.get(rar, Color.WHITE)
		draw_rect(Rect2(off, Vector2(9, 9) * px), Color("#0c0f24"))
		draw_rect(Rect2(off, Vector2(9, 9) * px), rc, false, px)
	for y in 7:
		var row: String = g[y]
		for x in 7:
			var ch := row[x]
			if ch == ".":
				continue
			var c := col.lightened(0.5) if ch == "+" else col
			draw_rect(Rect2(off + Vector2(x + 1, y + 1) * px, Vector2(px, px)), c)
