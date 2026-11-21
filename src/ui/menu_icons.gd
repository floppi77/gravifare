class_name MenuIcons
extends RefCounted
## Kleine Pixel-Symbole für die Symbolknöpfe unten rechts im Hauptmenü (wie BugIcon: 13×13 Pixel, 3 Bildpunkte je Pixel):
## Spielstand (Diskette) und Ko-fi (Tasse mit Herz).

const SLOT := [
	"kkkkkkkkkkkk.",
	"kbbbwwwwwbbkk",
	"kbbbwwwkwbbbk",
	"kbbbwwwkwbbbk",
	"kbbbwwwwwbbbk",
	"kbbbbbbbbbbbk",
	"kbbbbbbbbbbbk",
	"kbllllllllbbk",
	"kbleeeeeelbbk",
	"kbllllllllbbk",
	"kbleeeeeelbbk",
	"kbllllllllbbk",
	"kkkkkkkkkkkkk",
]
const KOFI := [
	".....r.r.....",
	"....rrrrr....",
	".....rrr.....",
	"......r......",
	".............",
	"wwwwwwwwww...",
	"wcccccccwwww.",
	"wcccccccw..w.",
	"wcccccccw..w.",
	"wcccccccwwww.",
	".wcccccw.....",
	"..wwwww......",
	"kkkkkkkkkkk..",
]
const COLORS := {"k": Color("#1a1420"), "b": Color("#3a7ae0"), "w": Color("#e8ecff"), "l": Color("#c9cfee"), "e": Color("#8a93c9"),
	"r": Color("#ff5e5b"), "c": Color("#c9873a")}

static var _cache: Dictionary = {}

static func texture(name: String, px := 3) -> Texture2D:
	var key := "%s%d" % [name, px]
	if not _cache.has(key):
		var rows: Array = SLOT if name == "slot" else KOFI
		var img := Image.create(13 * px, rows.size() * px, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			var row: String = rows[y]
			for x in mini(13, row.length()):
				if COLORS.has(row[x]):
					img.fill_rect(Rect2i(x * px, y * px, px, px), COLORS[row[x]])
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
