class_name BugIcon
extends RefCounted
## Käfer-Symbol für „Bug melden“: 13×13 Pixel, gezeichnet aus einer halben Vorlage (links + Mittelspalte), gespiegelt, in 3 Bildpunkten je Pixel
## (wie die übrige Menügrafik). Roter Panzer mit Mittelnaht und Punkten, dunkler Kopf, helle Beine und Fühler (auf dunklen Knöpfen sichtbar).

const HALF := [         # Spalten 0–6 (6 = Mitte); rechts gespiegelt
	"..a....",
	"...a...",
	"....hhh",
	"...hehh",
	"l.ossok",
	".lsSssk",
	"..sSksk",
	"llssssk",
	"..skssk",
	".lssssk",
	"l.ossok",
	"...ossk",
	".....oo",
]
const COLORS := {"a": Color("#d8deff"), "l": Color("#d8deff"), "h": Color("#2c3156"), "e": Color("#9fe6ff"), "o": Color("#a8202c"),
	"s": Color("#e5483e"), "S": Color("#ff9a80"), "k": Color("#1a1420")}

static var _cache: Dictionary = {}

## Bild des Käfers; `px` Bildpunkte je Pixel.
static func image(px := 3) -> Image:
	var n := HALF.size()
	var img := Image.create(13 * px, n * px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		var row: String = HALF[y]
		for x in 13:
			var ch := row[x] if x <= 6 else row[12 - x]
			if x > 6 and ch == "S":
				ch = "s"                      # Glanzlicht nur links
			if COLORS.has(ch):
				img.fill_rect(Rect2i(x * px, y * px, px, px), COLORS[ch])
	return img

static func texture(px := 3) -> Texture2D:
	if not _cache.has(px):
		_cache[px] = ImageTexture.create_from_image(image(px))
	return _cache[px]
