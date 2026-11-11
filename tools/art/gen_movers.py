"""Trümmer, Schieber und fahrende Plattformen als Pixelgrafik (Runde 57).

Die Hindernisse sind verschieden groß (Trümmer 16×32 und 32×16 Einheiten, Schieber 32×32 und 48×32, Plattformen 64–96 × 16), deshalb gibt es
kein Bild je Größe, sondern ein Kachelblatt: je Art neun Stücke (Ecken, Kanten, Füllung) plus eine zweite Füllung, 12 × 12 Bildpunkte
(= 4 Einheiten, 1 Bildpunkt = 1/3 Einheit = 1 Bildschirmpunkt bei 1080p). Das Spiel setzt daraus jede Größe zusammen (`props_view._draw_mover_box`).

Blatt `assets/art/movers.png`, 10 Spalten × 3 Zeilen à 12 px:
   Spalten  0 oben links, 1 oben, 2 oben rechts, 3 links, 4 Füllung A, 5 rechts, 6 unten links, 7 unten, 8 unten rechts, 9 Füllung B
   Zeilen   0 Trümmer (grauer Brocken, oranger Warnrand), 1 Schieber (blauer Block, gelb-schwarzer Warnstreifen unten),
            2 Plattform (Platte mit türkiser Landeleiste)

Schritte (aus der Projektwurzel):
   python3 tools/art/gen_movers.py pre      -> build/aseprite-workspace/gf_movers/{body,detail,outline}.png (Ebenen des Blatts)
   aseprite -b --script tools/art/aseprite/build_movers.lua   -> movers.aseprite (Ebenen body, detail, outline) und movers_flat.png
   python3 tools/art/gen_movers.py export   -> kopiert movers_flat.png nach assets/art/movers.png
   python3 tools/art/gen_movers.py flat     -> Notlösung ohne Aseprite: alle Ebenen direkt zusammengesetzt nach assets/art/movers.png
Eigene Arbeit, keine Fremdassets."""
import os, shutil, sys
from PIL import Image

P = 12                       # Kantenlänge einer Kachel in Bildpunkten
COLS, ROWS = 10, 3
WS = "build/aseprite-workspace/gf_movers/"
OUT = "assets/art/movers.png"
BIG = 99                     # „weit weg vom Rand“


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OL = hexc("#0c0f24")


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3)) + (255,)


def hsh(u, v, s=0):
    """Fester Zufall je Bildpunkt innerhalb der Kachel (die Kacheln wiederholen sich, das Muster auch)."""
    n = (u * 73856093) ^ (v * 19349663) ^ (s * 83492791)
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# --- Farben je Art -------------------------------------------------------------------------------------------------------------------------
DEB = dict(body=hexc("#3b3f5e"), hi=hexc("#555b82"), lo=hexc("#2a2d47"), dk=hexc("#1c1e33"),
           rim_hi=hexc("#ffcf6e"), rim=hexc("#ffb02e"), rim_lo=hexc("#c9701a"), cut=2)
SLI = dict(body=hexc("#232a52"), hi=hexc("#38427a"), lo=hexc("#171c3c"), dk=hexc("#0f1330"),
           rim_hi=hexc("#fff0a0"), rim=hexc("#ffc23a"), rim_lo=hexc("#c98f1a"), cut=1)
PAD = dict(body=hexc("#2a3266"), hi=hexc("#3f4a8c"), lo=hexc("#1c2250"), dk=hexc("#12173a"),
           rim_hi=hexc("#c4cdff"), rim=hexc("#7f8fe0"), rim_lo=hexc("#566098"), cut=1,
           strip_hi=hexc("#c8fff8"), strip=hexc("#35e0d2"), strip_lo=hexc("#1f9c94"))
KINDS = [DEB, SLI, PAD]


def side_of(dl, dr, dt, db):
    """Nächster Rand: 'T', 'L', 'B' oder 'R' (bei Gleichstand oben/links, dort sitzt das Licht)."""
    m = min(dl, dr, dt, db)
    if dt == m:
        return "T"
    if dl == m:
        return "L"
    if db == m:
        return "B"
    return "R"


def px(kind, dl, dr, dt, db, u, v, var):
    """Ein Bildpunkt eines Hindernisses. dl/dr/dt/db = Abstand zum linken/rechten/oberen/unteren Rand (0 = äußerster Punkt).
    Gibt (body, detail, outline) zurück, jeweils ein RGBA oder None."""
    k = KINDS[kind]
    cut = k["cut"]
    # abgeschnittene Ecken: ein Brocken ist kein Lineal
    for a, b in ((dl, dt), (dr, dt), (dl, db), (dr, db)):
        if a + b < cut:
            return None, None, None
    d = min(dl, dr, dt, db)
    corner_edge = any(a + b == cut for a, b in ((dl, dt), (dr, dt), (dl, db), (dr, db)))
    if d == 0 or corner_edge:
        return None, None, OL
    side = side_of(dl, dr, dt, db)
    lit = side in ("T", "L")
    rim_w = 1 if kind == 2 else 2
    body = det = None
    # Warnrand
    if d <= rim_w:
        body = k["rim_hi"] if (lit and d == 1) else (k["rim"] if lit or d == 1 else k["rim_lo"])
        if not lit and d == rim_w and rim_w > 1:
            body = k["rim_lo"]
        if kind == 2 and not lit:
            body = k["rim_lo"]
    else:
        body = k["body"]
        e = d - rim_w                                   # Abstand zum Rand der Fläche
        if e == 1:
            body = k["hi"] if lit else k["lo"]          # Kantenlicht innen
        elif hsh(u, v, kind) > 0.82:
            body = mix(k["body"], k["hi"], 0.4)         # leichtes Korn
        elif hsh(u, v, kind + 7) > 0.88:
            body = mix(k["body"], k["lo"], 0.55)
    # Art-spezifische Einzelheiten
    if kind == 0:                                       # Trümmer: Gruben und Späne, in der zweiten Füllung Risse und eine Niete
        if d >= 4 and var == 0:
            if (u, v) in ((7, 6), (8, 6), (7, 7), (3, 9)):
                det = k["dk"]
            elif (u, v) in ((8, 7), (4, 3)):
                det = k["hi"]
        if d >= 3 and var == 1:
            crack = {(2, 9), (3, 8), (4, 8), (5, 7), (6, 6), (7, 6), (8, 5), (9, 3), (10, 2)}
            if (u, v) in crack:
                det = k["dk"]
            elif (u, v) in {(3, 9), (5, 8), (7, 7), (9, 4)}:
                det = k["lo"]
            elif (u, v) == (5, 2):
                det = k["rim_hi"]
            elif (u, v) in ((6, 2), (5, 3), (6, 3)):
                det = k["dk"]
    elif kind == 1:                                     # Schieber: Plattenfugen, Nieten, Warnstreifen unten
        if d >= 3 and (v == 0 or (u == 0 and var == 0)):
            det = k["lo"]
        if d >= 4 and (u, v) in ((2, 3), (9, 3)) and var == 0:
            det = k["rim_hi"]
        if db in range(1, 9) and dl >= 1 and dr >= 1:
            stripe = ((u + db) % 12) < 6
            det = k["rim"] if stripe else k["dk"]
            if db == 8:
                det = k["rim_lo"] if stripe else OL
            if stripe and db == 1:
                det = k["rim_lo"]
    else:                                               # Plattform: türkise Landeleiste oben, Lüftungsschlitze
        if 1 <= dt <= 8 and dl >= 1 and dr >= 1 and not (dl + dt < 3 or dr + dt < 3):
            if dt == 1:
                det = k["strip_hi"]
            elif dt == 8:
                det = k["strip_lo"]
            else:
                det = k["strip"]
                if dt in (2, 3) and (u % 6) == 0:       # kleine Markierungen auf der Leiste
                    det = k["strip_hi"]
        elif d >= 3 and dt > 9 and var == 0 and v in (5, 6) and 1 <= u <= 9:
            det = k["dk"]

    return body, det, None


def cell(kind, col):
    """Kachel: Ebenen body, detail, outline als Bilder."""
    layers = [Image.new("RGBA", (P, P), (0, 0, 0, 0)) for _ in range(3)]
    ct = col in (0, 1, 2)
    cb = col in (6, 7, 8)
    cl = col in (0, 3, 6)
    cr = col in (2, 5, 8)
    var = 1 if col == 9 else 0
    for y in range(P):
        for x in range(P):
            dl = x if cl else BIG
            dr = (P - 1 - x) if cr else BIG
            dt = y if ct else BIG
            db = (P - 1 - y) if cb else BIG
            res = px(kind, dl, dr, dt, db, x, y, var)
            for i in range(3):
                if res[i] is not None:
                    layers[i].putpixel((x, y), res[i])
    return layers


def sheet():
    out = [Image.new("RGBA", (COLS * P, ROWS * P), (0, 0, 0, 0)) for _ in range(3)]
    for kind in range(ROWS):
        for col in range(COLS):
            for i, im in enumerate(cell(kind, col)):
                out[i].paste(im, (col * P, kind * P))
    return out


def flatten(layers):
    base = Image.new("RGBA", layers[0].size, (0, 0, 0, 0))
    for im in layers:
        base.alpha_composite(im)
    return base


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "pre"
    if mode == "pre":
        os.makedirs(WS, exist_ok=True)
        for name, im in zip(("body", "detail", "outline"), sheet()):
            im.save(WS + name + ".png")
        print("Ebenen nach", WS)
    elif mode == "export":
        shutil.copy(WS + "movers_flat.png", OUT)
        print("->", OUT)
    elif mode == "flat":
        flatten(sheet()).save(OUT)
        print("->", OUT, "(ohne Aseprite)")


if __name__ == "__main__":
    main()
