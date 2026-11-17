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
   python3 tools/art/gen_movers.py sizes    -> assets/art/movers_sizes.png: dieselben Stücke für die Pixelgrößen 2–6 untereinander (Runde 72;
                                               Kachel 4 Einheiten = 4·n Bildpunkte, Maße der Details werden je Größe umgesetzt, bei n = 3 das Blatt oben)
   python3 tools/art/gen_movers.py flat     -> Notlösung ohne Aseprite: alle Ebenen direkt zusammengesetzt nach assets/art/movers.png
Eigene Arbeit, keine Fremdassets."""
import math, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from sizekit import SIZES, stack

P = 12                       # Kantenlänge einer Kachel in Bildpunkten
COLS, ROWS = 10, 3
WS = "build/aseprite-workspace/gf_movers/"
OUT = "assets/art/movers.png"
OUT_SIZES = "assets/art/movers_sizes.png"
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
SLI = dict(body=hexc("#2f3a74"), hi=hexc("#5868b4"), lo=hexc("#1d2552"), dk=hexc("#10143a"),
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


def W(v, n):
    """Länge in Bildpunkten der Größe 3 (1 Punkt = 1/3 Einheit) → Bildpunkte der Größe n, mindestens 1."""
    return max(1, int(math.floor(v * n / 3.0 + 0.5)))


def rect_of(u0, u1, v0, v1, n):
    """Entwurfspunkte u0..u1 × v0..v1 (einschließlich, Größe 3) → Bildpunktbereiche der Größe n (mindestens ein Bildpunkt je Richtung)."""
    f = n / 3.0
    def rng(a, b):
        lo = int(math.floor(a * f + 0.5))
        return lo, lo + max(1, int(math.floor((b - a + 1) * f + 0.5))) - 1        # gleich lange Spanne = gleich viele Bildpunkte
    return rng(u0, u1), rng(v0, v1)


def inside(x, y, u0, u1, v0, v1, n):
    (xa, xb), (ya, yb) = rect_of(u0, u1, v0, v1, n)
    return xa <= x <= xb and ya <= y <= yb


def px(kind, dl, dr, dt, db, u, v, var, n=3):
    """Ein Bildpunkt eines Hindernisses in der Größe n. dl/dr/dt/db = Abstand zum linken/rechten/oberen/unteren Rand (0 = äußerster Punkt),
    u, v = Lage in der Kachel. Alle Maße stehen in Bildpunkten der Größe 3 und werden mit W()/rect_of() umgesetzt.
    Gibt (body, detail, outline) zurück, jeweils ein RGBA oder None."""
    k = KINDS[kind]
    P = 4 * n
    cut = W(k["cut"], n) if k["cut"] > 1 else 1
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
    rim_w = 1 if kind == 2 else W(2, n)
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
    d3, d4 = W(3, n), W(4, n)
    def at(pts):                                        # Entwurfspunkte (u, v) der Größe 3
        return any(inside(u, v, a, a, b, b, n) for a, b in pts)
    # Art-spezifische Einzelheiten
    if kind == 0:                                       # Trümmer: Gruben und Späne, in der zweiten Füllung Risse und eine Niete
        if d >= d4 and var == 0:
            if at(((7, 6), (8, 6), (7, 7), (3, 9))):
                det = k["dk"]
            elif at(((8, 7), (4, 3))):
                det = k["hi"]
        if d >= d3 and var == 1:
            crack = ((2, 9), (3, 8), (4, 8), (5, 7), (6, 6), (7, 6), (8, 5), (9, 3), (10, 2))
            if at(crack):
                det = k["dk"]
            elif at(((3, 9), (5, 8), (7, 7), (9, 4))):
                det = k["lo"]
            elif at(((5, 2),)):
                det = k["rim_hi"]
            elif at(((6, 2), (5, 3), (6, 3))):
                det = k["dk"]
    elif kind == 1:                                     # Schieber: schwere Panzerplatten mit Fase, Bolzen bzw. Lüftungsschlitzen, Warnstreifen unten
        if d >= d3:
            if v == P - 1 or u == P - 1:
                det = k["dk"]                           # Fuge zwischen den Platten
            elif v == 0 or u == 0:
                det = k["hi"]                           # Lichtkante oben/links
            elif v == P - 2 or u == P - 2:
                det = k["lo"]                           # Schattenkante unten/rechts
            elif var == 0:
                if at(((2, 2), (8, 2), (2, 8), (8, 8))):
                    det = k["rim_hi"]                   # vier Bolzen je Platte
                elif at(((3, 3), (9, 3), (3, 9), (9, 9))):
                    det = k["dk"]
            elif any(inside(u, v, 2, 8, r, r, n) for r in (3, 5, 7)):
                det = k["dk"]                           # Lüftungsschlitze
            elif any(inside(u, v, 2, 8, r, r, n) for r in (4, 6, 8)):
                det = mix(k["body"], k["hi"], 0.5)
        if 1 <= db <= W(8, n) and dl >= 1 and dr >= 1:
            stripe = ((u + db) % (4 * n)) < 2 * n       # Warnstreifen, 45 Grad, Periode 4 Einheiten
            det = k["rim"] if stripe else k["dk"]
            if db == W(8, n):
                det = k["rim_lo"] if stripe else OL
            if stripe and db == 1:
                det = k["rim_lo"]
    else:                                               # Plattform: türkise Landeleiste oben, Lüftungsschlitze
        s8 = W(8, n)
        if 1 <= dt <= s8 and dl >= 1 and dr >= 1 and not (dl + dt < d3 or dr + dt < d3):
            if dt == 1:
                det = k["strip_hi"]
            elif dt == s8:
                det = k["strip_lo"]
            else:
                det = k["strip"]
                if max(2, W(2, n)) <= dt <= max(W(3, n), 2) and (u % (2 * n)) == 0:       # kleine Markierungen auf der Leiste
                    det = k["strip_hi"]
        elif d >= d3 and dt > W(9, n) and var == 0 and inside(u, v, 1, 9, 5, 6, n):
            det = k["dk"]

    return body, det, None


def cell(kind, col, n=3):
    """Kachel: Ebenen body, detail, outline als Bilder (4 Einheiten = 4n Bildpunkte)."""
    P = 4 * n
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
            res = px(kind, dl, dr, dt, db, x, y, var, n)
            for i in range(3):
                if res[i] is not None:
                    layers[i].putpixel((x, y), res[i])
    return layers


def sheet(n=3):
    P = 4 * n
    out = [Image.new("RGBA", (COLS * P, ROWS * P), (0, 0, 0, 0)) for _ in range(3)]
    for kind in range(ROWS):
        for col in range(COLS):
            for i, im in enumerate(cell(kind, col, n)):
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
    elif mode == "sizes":                              # je Pixelgröße gerastert (Runde 72): die fünf Blätter untereinander, 40 × 12 Einheiten je Größe
        stack({n: flatten(sheet(n)) for n in SIZES}).save(OUT_SIZES)
        print("->", OUT_SIZES)


if __name__ == "__main__":
    main()
