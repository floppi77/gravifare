"""Trümmer als ganze Pixelbilder (Runde 70): drei Wrackteile statt der flachen Kachelplatte.

Die Trümmer der Level sind 16 × 32 oder 32 × 16 Einheiten groß (48 × 96 bzw. 96 × 48 Bildpunkte, 1 Bildpunkt = 1/3 Einheit). Für genau diese
Größen gibt es je drei Motive: 0 Frachtcontainer (Wellblech, Farbband, Brandloch), 1 Rumpfplatte (Plattenfugen, geborstenes Bullauge,
freiliegende Träger), 2 Solarpaneel (Zellen, Risse, fehlende Zelle). Andere Größen (Gemeinschaftslevel) setzt das Spiel weiter aus dem
Kachelblatt movers.png zusammen. Jedes Bild füllt die Trefferfläche ganz aus: dunkle Kontur, abgeschrägte Ecken und der orange Warnrand
bleiben wie bisher, das Motiv liegt innen. Licht von oben links wie bei Taxi und Haltestellen; die liegende Fassung ist eigens gezeichnet,
nicht gedreht.

Blatt `assets/art/debris.png` (240 × 144): stehend je 48 × 96 bei x = 0, 48, 96 (y = 0); liegend je 96 × 48 bei x = 144, y = 0, 48, 96;
ein quadratisches Stück 48 × 48 (Containermitte) bei x = 0, y = 96.
Aufruf aus der Projektwurzel:  python3 tools/art/gen_debris.py        Fester Zufall, die Ausgabe ist bitgleich. Eigene Arbeit, keine Fremdassets."""
import math
from PIL import Image

S, L = 48, 96                # kurze und lange Seite in Bildpunkten
OUT = "assets/art/debris.png"


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3)) + (255,)


def hsh(u, v, s=0):
    n = (u * 73856093) ^ (v * 19349663) ^ (s * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


OL = hexc("#0c0f24")
RIM_HI, RIM, RIM_LO = hexc("#ffcf6e"), hexc("#ffb02e"), hexc("#c9701a")
INK = hexc("#161a30")
EMBER, EMBER_HI = hexc("#ff7a2a"), hexc("#ffd070")
CUT = 2
IN = 4                       # ab diesem Randabstand beginnt das Motiv (Kontur 1, Warnrand 2, Fuge 1)


class Pic:
    """Ein Wrackteil. a = Lage auf der langen Achse (0 … L-1), b = auf der kurzen (0 … S-1); x, y = Bildpunkt."""

    def __init__(self, vert):
        self.vert = vert
        self.w, self.h = (S, L) if vert else (L, S)
        self.im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

    def ab(self, x, y):
        return (y, x) if self.vert else (x, y)

    def xy(self, a, b):
        return (b, a) if self.vert else (a, b)

    def edge(self, x, y):
        return min(x, y, self.w - 1 - x, self.h - 1 - y)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.edge(x, y) >= IN

    def put(self, x, y, c):
        if self.inside(x, y):
            self.im.putpixel((x, y), c)

    def get(self, x, y):
        return self.im.getpixel((x, y))

    def pa(self, a, b, c):
        x, y = self.xy(a, b)
        self.put(x, y, c)

    def shade(self, x, y, t, to=INK):
        if self.inside(x, y):
            self.im.putpixel((x, y), mix(self.get(x, y), to, t))

    def frame(self):
        """Kontur, abgeschrägte Ecken, oranger Warnrand (oben/links hell, unten/rechts dunkel), Fuge."""
        for y in range(self.h):
            for x in range(self.w):
                dl, dr, dt, db = x, self.w - 1 - x, y, self.h - 1 - y
                corners = ((dl, dt), (dr, dt), (dl, db), (dr, db))
                if any(p + q < CUT for p, q in corners):
                    self.im.putpixel((x, y), (0, 0, 0, 0))
                    continue
                d = min(dl, dr, dt, db)
                if d >= IN and not any(p + q < IN + 2 for p, q in corners):
                    continue
                lit = min(dt, dl) <= min(db, dr)
                if d == 0 or any(p + q == CUT for p, q in corners):
                    c = OL
                elif d <= 2 or any(p + q <= CUT + 3 for p, q in corners):
                    c = (RIM_HI if d == 1 else RIM) if lit else (RIM if d == 1 else RIM_LO)
                else:
                    c = INK
                self.im.putpixel((x, y), c)

    def rivet(self, x, y, hi, lo):
        self.put(x, y, hi)
        self.put(x + 1, y, mix(hi, lo, 0.5))
        self.put(x, y + 1, mix(hi, lo, 0.5))
        self.put(x + 1, y + 1, lo)

    def hole(self, cx, cy, r, seed, glow=True):
        """Brandloch: unregelmäßiger Rand, dunkles Inneres, Ruß außen herum, etwas Glut."""
        for y in range(cy - r - 7, cy + r + 8):
            for x in range(cx - r - 7, cx + r + 8):
                if not self.inside(x, y):
                    continue
                ang = math.atan2(y - cy, x - cx)
                rr = r * (0.78 + 0.22 * math.sin(ang * 3.0 + seed) + 0.16 * math.sin(ang * 7.0 + seed * 2.3))
                d = math.hypot(x - cx, y - cy)
                if d <= rr - 1.2:
                    self.im.putpixel((x, y), hexc("#0d1022") if hsh(x, y, seed) > 0.25 else hexc("#181c36"))
                elif d <= rr:
                    lit = (x - cx) + (y - cy) > 0             # die untere rechte Lochkante fängt das Licht
                    self.im.putpixel((x, y), mix(self.get(x, y), hexc("#e9eefc"), 0.55) if lit else INK)
                elif d <= rr + 6.0:
                    t = (1.0 - (d - rr) / 6.0) * (0.62 if hsh(x, y, seed + 3) > 0.3 else 0.38)
                    self.shade(x, y, t)
        if glow:
            for k in range(5):
                gx = cx + int(round((hsh(k, seed, 11) - 0.5) * r * 1.2))
                gy = cy + int(round((hsh(k, seed, 12) - 0.5) * r * 1.2))
                if math.hypot(gx - cx, gy - cy) < r * 0.6:
                    self.put(gx, gy, EMBER_HI if k == 0 else EMBER)

    def crack(self, x, y, steps, seed, col, dx=1, dy=1):
        for k in range(steps):
            self.put(x, y, col)
            h = hsh(k, seed, 5)
            if h < 0.45:
                x += dx
            elif h < 0.9:
                y += dy
            else:
                x += dx
                y += dy

    def grain(self, seed, lo, hi, amount=0.1):
        for y in range(self.h):
            for x in range(self.w):
                if self.inside(x, y):
                    h = hsh(x, y, seed)
                    if h > 1.0 - amount:
                        self.im.putpixel((x, y), mix(self.get(x, y), hi, 0.35))
                    elif h < amount:
                        self.im.putpixel((x, y), mix(self.get(x, y), lo, 0.4))


def container(vert):
    """Frachtcontainer: Wellblech quer zur Länge, Endrahmen mit Eckbeschlägen, türkises Farbband mit Kennung, Brandloch, Delle."""
    p = Pic(vert)
    body, hi, lo, dk = hexc("#5d6a8e"), hexc("#8a98bf"), hexc("#434d6c"), hexc("#2a3049")
    band, band_hi, band_lo = hexc("#2fa89c"), hexc("#6fe0d2"), hexc("#1f746e")
    for a in range(L):
        for b in range(S):
            ph = a % 6                                      # Wellblech: je Rippe heller Grat, Fläche, Schattenkante
            c = hi if ph == 0 else (lo if ph == 4 else (dk if ph == 5 else body))
            if 34 <= a < 52:                                # Farbband quer über die Mitte, abgeplatzt
                c = band_hi if ph == 0 else (band_lo if ph in (4, 5) else band)
                if hsh(a, b, 21) > 0.86 or (hsh(a // 2, b // 2, 22) > 0.9):
                    c = hi if ph == 0 else (lo if ph >= 4 else body)
            if a < IN + 7 or a >= L - IN - 7:               # Endrahmen
                c = hexc("#4a5474")
                e = (a - IN) if a < L // 2 else (L - 1 - IN - a)
                if e == 0:
                    c = hexc("#7b88ad")
                elif e == 6:
                    c = dk
            p.pa(a, b, c)
    for b in range(IN, S - IN):                             # Längsholme an beiden Seiten
        for a in range(L):
            if b in (IN, S - IN - 1):
                p.pa(a, b, hexc("#7b88ad") if b == IN else dk)
            elif b in (IN + 1, S - IN - 2):
                p.pa(a, b, hexc("#4a5474"))
    for a0 in (IN + 2, L - IN - 5):                         # Eckbeschläge und Nieten in den Endrahmen
        for b0 in (IN + 2, S - IN - 5):
            for da in range(3):
                for db_ in range(3):
                    p.pa(a0 + da, b0 + db_, hexc("#c9d2ea") if (da + db_) == 0 else (dk if (da == 2 or db_ == 2) else hexc("#95a2c6")))
        for b0 in (16, 23, 30):
            x, y = p.xy(a0 + 1, b0)
            p.rivet(x, y, hexc("#c9d2ea"), dk)
    for i, a0 in enumerate((39, 43, 47)):                   # Kennung: drei dunkle Blöcke auf dem Farbband
        for da in range(3):
            for db_ in range(5 if i != 1 else 3):
                if hsh(a0 + da, db_, 31) > 0.12:
                    p.pa(a0 + da, 12 + db_, hexc("#123a3a"))
    for k in range(9):                                      # Delle: Knick mit Lichtkante
        x, y = p.xy(62 + k, 30 + (k * 2) // 3)
        p.put(x, y, dk)
        p.put(x + (0 if vert else 0), y + 1, hi) if not vert else p.put(x + 1, y, hi)
    cx, cy = p.xy(74, 17)
    p.hole(cx, cy, 8, 3)
    p.grain(41, dk, hexc("#aab6d8"), 0.025)
    p.frame()
    return p.im


def hull(vert):
    """Rumpfplatte: Plattenfugen mit Nieten, geborstenes Bullauge, an einem Ende freiliegende Träger, Leitung."""
    p = Pic(vert)
    body, hi, lo, dk = hexc("#72788f"), hexc("#a3a9be"), hexc("#555a70"), hexc("#34384c")
    for y in range(p.h):
        for x in range(p.w):
            a, b = p.ab(x, y)
            c = body
            if (a // 16 + b // 20) % 2 == 1:
                c = mix(body, lo, 0.35)                     # Platten leicht verschieden getönt
            p.put(x, y, c)
    for y in range(p.h):                                    # Fugen: dunkle Linie, daneben (unten/rechts) Lichtkante
        for x in range(p.w):
            a, b = p.ab(x, y)
            if a % 16 == 8 or b == 24:
                p.put(x, y, dk)
                p.put(x + 1, y + 1, mix(p.get(x + 1, y + 1), hi, 0.5) if p.inside(x + 1, y + 1) and p.get(x + 1, y + 1) != dk else dk)
    for a in range(8, L, 16):
        for b in (8, 20, 28, 40):
            x, y = p.xy(a + 2, b)
            p.rivet(x, y, hi, dk)
    # freiliegende Träger am Ende a > 70: dunkles Inneres mit Gitter
    for y in range(p.h):
        for x in range(p.w):
            a, b = p.ab(x, y)
            edge_a = 72 + int(round(3.0 * math.sin(b * 0.45) + 2.5 * hsh(b // 2, 0, 51)))
            if a >= edge_a:
                c = hexc("#111427")
                if (a + b) % 9 == 0 or (a - b) % 9 == 0:
                    c = hexc("#59607c")                      # Diagonalstreben
                if (a + b) % 9 == 1 or (a - b) % 9 == 1:
                    c = hexc("#2a2f47")
                if b in (IN + 2, S - IN - 3, 23) or a in (80, 88):
                    c = hexc("#7d86a6")                      # Gurte und Spanten
                if b in (IN + 3, S - IN - 2, 24) or a in (81, 89):
                    c = hexc("#3a4059")
                p.put(x, y, c)
            elif a == edge_a - 1:
                p.put(x, y, hexc("#c5cbe0"))                # Bruchkante fängt das Licht
            elif a == edge_a - 2:
                p.put(x, y, dk)
    # Bullauge
    cx, cy = p.xy(30, 24)
    for y in range(cy - 11, cy + 12):
        for x in range(cx - 11, cx + 12):
            d = math.hypot(x - cx, y - cy)
            if d <= 6.5:
                c = hexc("#16264f")
                if (x - cx) + (y - cy) < -5:
                    c = hexc("#2c4688")                      # Spiegelung oben links
                p.put(x, y, c)
            elif d <= 9.5:
                lit = (x - cx) + (y - cy) < 0
                c = hexc("#c2c8dc") if lit else hexc("#4a4f66")
                if d > 8.5:
                    c = dk
                p.put(x, y, c)
    for k, (dx, dy) in enumerate(((1, 1), (-1, 1), (1, -1))):
        p.crack(cx, cy, 6, 60 + k, hexc("#dfe8ff"), dx, dy)
    for k in range(4):                                      # Bolzen am Ring
        ang = math.pi / 4 + k * math.pi / 2
        p.put(int(round(cx + 8 * math.cos(ang))), int(round(cy + 8 * math.sin(ang))), hexc("#eef2ff"))
    for k in range(18):                                     # lose Leitung quer über die Platte
        a = 50 + k
        b = 12 + int(round(3.0 * math.sin(k * 0.5)))
        x, y = p.xy(a, b)
        p.put(x, y, hexc("#39c0b0"))
        p.put(x + (1 if vert else 0), y + (0 if vert else 1), hexc("#1f746e"))
    x, y = p.xy(12, 12)
    p.hole(x, y, 4, 7, glow=False)
    p.grain(42, dk, hexc("#c5cbe0"), 0.03)
    p.frame()
    return p.im


def solar(vert):
    """Solarpaneel: Stahlrahmen, Sammelschiene in der Mitte, blaue Zellen mit Raster, Risse, eine fehlende Zelle mit Drähten."""
    p = Pic(vert)
    steel, steel_hi, steel_lo = hexc("#69708a"), hexc("#a9b0c8"), hexc("#3d4258")
    cell, cell_hi, cell_lo, grid = hexc("#1f3a86"), hexc("#3f67d0"), hexc("#152758"), hexc("#7da2ff")
    for y in range(p.h):
        for x in range(p.w):
            p.put(x, y, steel)
    a0, b0 = IN + 3, IN + 3
    na, nb = 7, 3                                           # Zellen entlang und quer
    ca = (L - 2 * a0) / na
    cb = (S - 2 * b0 - 4) / nb                              # 4 Bildpunkte Sammelschiene
    missing = (4, 0)
    cracked = {(1, 2): 70, (5, 1): 71, (2, 0): 72}
    for ia in range(na):
        for ib in range(nb):
            a1 = int(round(a0 + ia * ca)) + 1
            a2 = int(round(a0 + (ia + 1) * ca)) - 1
            off = 4 if ib >= 2 else 0                       # Schiene zwischen zweiter und dritter Reihe
            b1 = int(round(b0 + ib * cb)) + 1 + off
            b2 = int(round(b0 + (ib + 1) * cb)) - 1 + off
            for a in range(a1, a2 + 1):
                for b in range(b1, b2 + 1):
                    x, y = p.xy(a, b)
                    if (ia, ib) == missing:
                        c = hexc("#0f1226")
                        if (a - a1) == (b - b1) + 2 or (a - a1) + (b - b1) == 7:
                            c = hexc("#c96a2a") if (a + b) % 3 else hexc("#39c0b0")       # Drähte
                        p.put(x, y, c)
                        continue
                    c = cell
                    if (a - a1) % 4 == 0 or (b - b1) % 4 == 0:
                        c = cell_lo                         # feines Leiterraster
                    if ((x + y) % 23) in (0, 1):
                        c = cell_hi                         # Glanzstreifen schräg über das ganze Paneel
                    if x == (p.xy(a1, b1)[0]) or y == (p.xy(a1, b1)[1]):
                        c = grid if hsh(x, y, 80) > 0.3 else cell_hi   # helle Kante oben/links je Zelle
                    p.put(x, y, c)
            if (ia, ib) in cracked:
                x, y = p.xy(a1 + 2, b1 + 1)
                p.crack(x, y, 10, cracked[(ia, ib)], hexc("#e6f0ff"))
                p.crack(x + 3, y + 2, 5, cracked[(ia, ib)] + 9, hexc("#e6f0ff"), 1, -1)
    for a in range(IN, L - IN):                             # Sammelschiene
        bm = int(round(b0 + 2 * cb)) + 1
        for k in range(3):
            p.pa(a, bm + k, steel_hi if k == 0 else (steel if k == 1 else steel_lo))
        if a % 12 == 6:
            x, y = p.xy(a, bm)
            p.rivet(x, y, hexc("#eef2ff"), steel_lo)
    for y in range(p.h):                                    # Rahmen: Lichtkante innen oben/links, Schatten unten/rechts
        for x in range(p.w):
            e = p.edge(x, y) - IN
            if e == 0:
                lit = min(x, y) <= min(p.w - 1 - x, p.h - 1 - y)
                p.put(x, y, steel_hi if lit else steel_lo)
            elif e == 2:
                p.put(x, y, steel_lo)
    for (a, b) in ((IN + 1, IN + 1), (L - IN - 3, IN + 1), (IN + 1, S - IN - 3), (L - IN - 3, S - IN - 3)):
        x, y = p.xy(a, b)
        p.rivet(x, y, hexc("#eef2ff"), steel_lo)
    x, y = p.xy(80, 34)
    p.hole(x, y, 5, 9)
    p.frame()
    return p.im


def crate():
    """Quadratisches Stück (16 × 16 Einheiten): Mittelteil des Containers mit dem Farbband, eigener Rahmen."""
    p = Pic(False)
    p.w = p.h = S
    p.im = container(False).crop((24, 0, 24 + S, S))
    p.frame()
    return p.im


def main():
    sheet = Image.new("RGBA", (3 * S + L, 3 * S), (0, 0, 0, 0))
    for i, fn in enumerate((container, hull, solar)):
        sheet.paste(fn(True), (i * S, 0))
        sheet.paste(fn(False), (3 * S, i * S))
    sheet.paste(crate(), (0, L))
    sheet.save(OUT)
    print("->", OUT, sheet.size)


if __name__ == "__main__":
    main()
