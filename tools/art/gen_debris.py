"""Trümmer als ganze Pixelbilder (Runde 70): drei Wrackteile statt der flachen Kachelplatte.

Die Trümmer der Level sind 16 × 32 oder 32 × 16 Einheiten groß (48 × 96 bzw. 96 × 48 Bildpunkte, 1 Bildpunkt = 1/3 Einheit). Für genau diese
Größen gibt es je drei Motive: 0 Frachtcontainer (Wellblech, Farbband, Brandloch), 1 Rumpfplatte (Plattenfugen, geborstenes Bullauge,
freiliegende Träger), 2 Solarpaneel (Zellen, Risse, fehlende Zelle). Andere Größen (Gemeinschaftslevel) setzt das Spiel weiter aus dem
Kachelblatt movers.png zusammen. Jedes Bild füllt die Trefferfläche ganz aus: dunkle Kontur, abgeschrägte Ecken und der orange Warnrand
bleiben wie bisher, das Motiv liegt innen. Licht von oben links wie bei Taxi und Haltestellen; die liegende Fassung ist eigens gezeichnet,
nicht gedreht.

Blatt `assets/art/debris.png` (240 × 144, Größe 3): stehend je 48 × 96 bei x = 0, 48, 96 (y = 0); liegend je 96 × 48 bei x = 144, y = 0, 48, 96;
ein quadratisches Stück 48 × 48 (Containermitte) bei x = 0, y = 96.
Runde 72: jede Pixelgröße n (2–6) wird eigens gerastert, `assets/art/debris_sizes.png` legt die fünf Blätter (je 80n × 48n) untereinander. Die Formen
stehen weiter in Entwurfspunkten (3 je Einheit); Flächen werden je Bildpunkt aus der Lage in Einheiten bestimmt, Linien, Nieten und Kleinteile
haben je Größe eine feste Zahl Bildpunkte (1 bis 1440p, darüber 2). Bei n = 3 entsteht genau das bisherige Blatt.
Aufruf aus der Projektwurzel:  python3 tools/art/gen_debris.py        Fester Zufall, die Ausgabe ist bitgleich. Eigene Arbeit, keine Fremdassets."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from sizekit import SIZES, stack

S, L = 48, 96                # kurze und lange Seite in Entwurfspunkten (3 je Einheit)
OUT = "assets/art/debris.png"
OUT_SIZES = "assets/art/debris_sizes.png"
N = 3                        # Pixelgröße, die gerade gebaut wird (sheet setzt sie)


def W(v):
    """Länge in Entwurfspunkten → Bildpunkte der Größe N, mindestens 1."""
    return max(1, int(math.floor(v * N / 3.0 + 0.5)))


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
IN = 4                       # ab diesem Randabstand (Entwurfspunkte) beginnt das Motiv (Kontur 1, Warnrand 2, Fuge 1)


class Pic:
    """Ein Wrackteil in der Pixelgröße N. a = Lage auf der langen Achse, b = auf der kurzen, in Entwurfspunkten (3 je Einheit); x, y = Bildpunkt.

    Zwei Arten zu setzen: `put`/`get` je Bildpunkt (Flächen, Entwurfslage aus dem Mittelpunkt des Bildpunkts) und `dput`/`pa` als Block aus
    Bildpunkten für einen Entwurfspunkt (Linien, Nieten, Kleinteile: gleiche Größe überall, mindestens ein Bildpunkt)."""

    def __init__(self, vert):
        self.vert = vert
        self.f = N / 3.0
        self.w, self.h = ((S, L) if vert else (L, S))
        self.w, self.h = self.w * N // 3, self.h * N // 3
        self.im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.inpx = W(IN)

    def dd(self, v):
        """Entwurfspunkt, in dem der Mittelpunkt des Bildpunkts v liegt."""
        return int(math.floor((v + 0.5) / self.f))

    def ab(self, x, y):
        a, b = self.dd(x), self.dd(y)
        return (b, a) if self.vert else (a, b)

    def xy(self, a, b):
        return (b, a) if self.vert else (a, b)

    def edge(self, x, y):
        return min(x, y, self.w - 1 - x, self.h - 1 - y)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.edge(x, y) >= self.inpx

    def put(self, x, y, c):
        if self.inside(x, y):
            self.im.putpixel((x, y), c)

    def get(self, x, y):
        return self.im.getpixel((x, y))

    def dput(self, x, y, c, w=1, h=1):
        """Block für die Entwurfspunkte x … x+w-1, y … y+h-1 (Bildlage x, y): feste Größe je Entwurfspunkt, Anfang auf dem Raster."""
        x0, y0 = int(math.floor(x * self.f + 0.5)), int(math.floor(y * self.f + 0.5))
        for yy in range(y0, y0 + max(1, int(math.floor(h * self.f + 0.5)))):
            for xx in range(x0, x0 + max(1, int(math.floor(w * self.f + 0.5)))):
                self.put(xx, yy, c)

    def pa(self, a, b, c, wa=1, wb=1):
        x, y = self.xy(a, b)
        if self.vert:
            self.dput(x, y, c, wb, wa)
        else:
            self.dput(x, y, c, wa, wb)

    def dget(self, x, y):
        return self.get(int(math.floor(x * self.f + 0.5)), int(math.floor(y * self.f + 0.5)))

    def shade(self, x, y, t, to=INK):
        if self.inside(x, y):
            self.im.putpixel((x, y), mix(self.get(x, y), to, t))

    def frame(self):
        """Kontur, abgeschrägte Ecken, oranger Warnrand (oben/links hell, unten/rechts dunkel), Fuge. Breiten in Bildpunkten der Größe N."""
        cut, inn, w2, w3 = W(CUT) if CUT > 1 else 1, W(IN), W(2), W(3)
        for y in range(self.h):
            for x in range(self.w):
                dl, dr, dt, db = x, self.w - 1 - x, y, self.h - 1 - y
                corners = ((dl, dt), (dr, dt), (dl, db), (dr, db))
                if any(p + q < cut for p, q in corners):
                    self.im.putpixel((x, y), (0, 0, 0, 0))
                    continue
                d = min(dl, dr, dt, db)
                if d >= inn and not any(p + q < inn + w2 for p, q in corners):
                    continue
                lit = min(dt, dl) <= min(db, dr)
                if d == 0 or any(p + q == cut for p, q in corners):
                    c = OL
                elif d <= w2 or any(p + q <= cut + w3 for p, q in corners):
                    c = (RIM_HI if d == 1 else RIM) if lit else (RIM if d == 1 else RIM_LO)
                else:
                    c = INK
                self.im.putpixel((x, y), c)

    def rivet(self, x, y, hi, lo):
        """Niete aus 2 × 2 Entwurfspunkten (Bildlage x, y)."""
        m = mix(hi, lo, 0.5)
        self.dput(x, y, hi)
        self.dput(x + 1, y, m)
        self.dput(x, y + 1, m)
        self.dput(x + 1, y + 1, lo)

    def hole(self, cx, cy, r, seed, glow=True):
        """Brandloch: unregelmäßiger Rand, dunkles Inneres, Ruß außen herum, etwas Glut. Mittelpunkt und Radius in Entwurfspunkten."""
        f = self.f
        rim = max(1.2, 1.0 / f)                                     # Randbreite: mindestens ein Bildpunkt
        span = int(math.ceil((r + 7) * f))
        px0, py0 = int(math.floor(cx * f + 0.5)), int(math.floor(cy * f + 0.5))
        for y in range(py0 - span, py0 + span + 1):
            for x in range(px0 - span, px0 + span + 1):
                if not self.inside(x, y):
                    continue
                X, Y = (x + 0.5) / f - 0.5, (y + 0.5) / f - 0.5       # Entwurfslage des Bildpunkts
                ang = math.atan2(Y - cy, X - cx)
                rr = r * (0.78 + 0.22 * math.sin(ang * 3.0 + seed) + 0.16 * math.sin(ang * 7.0 + seed * 2.3))
                d = math.hypot(X - cx, Y - cy)
                if d <= rr - rim:
                    self.im.putpixel((x, y), hexc("#0d1022") if hsh(x, y, seed) > 0.25 else hexc("#181c36"))
                elif d <= rr:
                    lit = (X - cx) + (Y - cy) > 0                   # die untere rechte Lochkante fängt das Licht
                    self.im.putpixel((x, y), mix(self.get(x, y), hexc("#e9eefc"), 0.55) if lit else INK)
                elif d <= rr + 6.0:
                    t = (1.0 - (d - rr) / 6.0) * (0.62 if hsh(x, y, seed + 3) > 0.3 else 0.38)
                    self.shade(x, y, t)
        if glow:
            for k in range(5):
                gx = cx + int(round((hsh(k, seed, 11) - 0.5) * r * 1.2))
                gy = cy + int(round((hsh(k, seed, 12) - 0.5) * r * 1.2))
                if math.hypot(gx - cx, gy - cy) < r * 0.6:
                    self.dput(gx, gy, EMBER_HI if k == 0 else EMBER)

    def crack(self, x, y, steps, seed, col, dx=1, dy=1):
        for k in range(steps):
            self.dput(x, y, col)
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

    def hits(self, v, pred):
        """Wahr, wenn irgendein Entwurfspunkt, den der Bildpunkt v überdeckt, `pred` erfüllt (dünne Linien gehen bei kleinen Größen nicht verloren)."""
        lo = int(math.floor(v / self.f + 1e-9))
        hi = max(lo, int(math.ceil((v + 1) / self.f - 1e-9)) - 1)
        return any(pred(i) for i in range(lo, hi + 1))


def container(vert):
    """Frachtcontainer: Wellblech quer zur Länge, Endrahmen mit Eckbeschlägen, türkises Farbband mit Kennung, Brandloch, Delle."""
    p = Pic(vert)
    body, hi, lo, dk = hexc("#5d6a8e"), hexc("#8a98bf"), hexc("#434d6c"), hexc("#2a3049")
    band, band_hi, band_lo = hexc("#2fa89c"), hexc("#6fe0d2"), hexc("#1f746e")
    rail, rail_hi = hexc("#4a5474"), hexc("#7b88ad")
    nx = p.w if not vert else p.h                           # Bildpunkte entlang der langen Achse
    nb = p.h if not vert else p.w                           # … quer dazu
    for ap in range(nx):
        for bp in range(nb):
            a, b = p.dd(ap), p.dd(bp)
            wave = lambda m: p.hits(ap, lambda i: i % 6 == m)
            ph = 0 if wave(0) else (5 if wave(5) else (4 if wave(4) else 1))            # Wellblech: je Rippe heller Grat, Fläche, Schattenkante
            c = hi if ph == 0 else (lo if ph == 4 else (dk if ph == 5 else body))
            if 34 <= a < 52:                                # Farbband quer über die Mitte, abgeplatzt
                c = band_hi if ph == 0 else (band_lo if ph in (4, 5) else band)
                if hsh(a, b, 21) > 0.86 or (hsh(a // 2, b // 2, 22) > 0.9):
                    c = hi if ph == 0 else (lo if ph >= 4 else body)
            if a < IN + 7 or a >= L - IN - 7:               # Endrahmen
                c = rail
                e = (a - IN) if a < L // 2 else (L - 1 - IN - a)
                if p.hits(ap, lambda i: ((i - IN) if i < L // 2 else (L - 1 - IN - i)) == 0):
                    c = rail_hi
                elif p.hits(ap, lambda i: ((i - IN) if i < L // 2 else (L - 1 - IN - i)) == 6):
                    c = dk
            x, y = (bp, ap) if vert else (ap, bp)
            p.put(x, y, c)
    for bp in range(nb):                                    # Längsholme an beiden Seiten
        for ap in range(nx):
            if p.hits(bp, lambda i: i in (IN, S - IN - 1)):
                c = rail_hi if p.hits(bp, lambda i: i == IN) else dk
            elif p.hits(bp, lambda i: i in (IN + 1, S - IN - 2)):
                c = rail
            else:
                continue
            p.put(*((bp, ap) if vert else (ap, bp)), c)
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
        p.dput(x, y, dk)
        p.dput(x, y + 1, hi) if not vert else p.dput(x + 1, y, hi)
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
    sh = W(1)
    for y in range(p.h):                                    # Fugen: dunkle Linie, daneben (unten/rechts) Lichtkante
        for x in range(p.w):
            ax = (y if vert else x)
            bx = (x if vert else y)
            if p.hits(ax, lambda i: i % 16 == 8) or p.hits(bx, lambda i: i == 24):
                p.put(x, y, dk)
    for y in range(p.h):
        for x in range(p.w):
            ax = (y if vert else x)
            bx = (x if vert else y)
            if p.hits(ax, lambda i: i % 16 == 8) or p.hits(bx, lambda i: i == 24):
                continue
            # Lichtkante: unmittelbar hinter (unten/rechts) einer Fuge
            px_, py_ = x - sh, y - sh
            if px_ >= 0 and py_ >= 0:
                ax2 = (py_ if vert else px_)
                bx2 = (px_ if vert else py_)
                if (p.hits(ax2, lambda i: i % 16 == 8) or p.hits(bx2, lambda i: i == 24)) and p.inside(x, y):
                    p.im.putpixel((x, y), mix(p.get(x, y), hi, 0.5))
    for a in range(8, L, 16):
        for b in (8, 20, 28, 40):
            x, y = p.xy(a + 2, b)
            p.rivet(x, y, hi, dk)
    # freiliegende Träger am Ende a > 70: dunkles Inneres mit Gitter
    nx = p.h if vert else p.w
    nb = p.w if vert else p.h
    for ap in range(nx):
        for bp in range(nb):
            a, b = p.dd(ap), p.dd(bp)
            edge_a = lambda bb: 72 + int(round(3.0 * math.sin(bb * 0.45) + 2.5 * hsh(bb // 2, 0, 51)))
            ea = edge_a(b)
            x, y = (bp, ap) if vert else (ap, bp)
            if a >= ea:
                c = hexc("#111427")
                if p.hits(ap, lambda i: any((i + j) % 9 == 0 or (i - j) % 9 == 0 for j in range(b, b + 1))):
                    c = hexc("#59607c")                      # Diagonalstreben
                elif p.hits(ap, lambda i: any((i + j) % 9 == 1 or (i - j) % 9 == 1 for j in range(b, b + 1))):
                    c = hexc("#2a2f47")
                if p.hits(bp, lambda i: i in (IN + 2, S - IN - 3, 23)) or p.hits(ap, lambda i: i in (80, 88)):
                    c = hexc("#7d86a6")                      # Gurte und Spanten
                elif p.hits(bp, lambda i: i in (IN + 3, S - IN - 2, 24)) or p.hits(ap, lambda i: i in (81, 89)):
                    c = hexc("#3a4059")
                p.put(x, y, c)
            elif p.hits(ap, lambda i: i == ea - 1):
                p.put(x, y, hexc("#c5cbe0"))                # Bruchkante fängt das Licht
            elif p.hits(ap, lambda i: i == ea - 2):
                p.put(x, y, dk)
    # Bullauge
    cx, cy = p.xy(30, 24)
    f = p.f
    for y in range(int((cy - 11) * f), int((cy + 12) * f) + 1):
        for x in range(int((cx - 11) * f), int((cx + 12) * f) + 1):
            X, Y = (x + 0.5) / f - 0.5, (y + 0.5) / f - 0.5
            d = math.hypot(X - cx, Y - cy)
            if d <= 6.5:
                c = hexc("#16264f")
                if (X - cx) + (Y - cy) < -5:
                    c = hexc("#2c4688")                      # Spiegelung oben links
                p.put(x, y, c)
            elif d <= 9.5:
                lit = (X - cx) + (Y - cy) < 0
                c = hexc("#c2c8dc") if lit else hexc("#4a4f66")
                if d > 8.5:
                    c = dk
                p.put(x, y, c)
    for k, (dx, dy) in enumerate(((1, 1), (-1, 1), (1, -1))):
        p.crack(cx, cy, 6, 60 + k, hexc("#dfe8ff"), dx, dy)
    for k in range(4):                                      # Bolzen am Ring
        ang = math.pi / 4 + k * math.pi / 2
        p.dput(int(round(cx + 8 * math.cos(ang))), int(round(cy + 8 * math.sin(ang))), hexc("#eef2ff"))
    for k in range(18):                                     # lose Leitung quer über die Platte
        a = 50 + k
        b = 12 + int(round(3.0 * math.sin(k * 0.5)))
        x, y = p.xy(a, b)
        p.dput(x, y, hexc("#39c0b0"))
        p.dput(x + (1 if vert else 0), y + (0 if vert else 1), hexc("#1f746e"))
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
    cb = (S - 2 * b0 - 4) / nb                              # 4 Entwurfspunkte Sammelschiene
    missing = (4, 0)
    cracked = {(1, 2): 70, (5, 1): 71, (2, 0): 72}
    for ia in range(na):
        for ib in range(nb):
            a1 = int(round(a0 + ia * ca)) + 1
            a2 = int(round(a0 + (ia + 1) * ca)) - 1
            off = 4 if ib >= 2 else 0                       # Schiene zwischen zweiter und dritter Reihe
            b1 = int(round(b0 + ib * cb)) + 1 + off
            b2 = int(round(b0 + (ib + 1) * cb)) - 1 + off
            # Zelle als Fläche: Bildpunkte, deren Mitte in [a1, a2] × [b1, b2] liegt; Raster, Glanz und Kanten als Linien/Blöcke darüber
            for ap in range(int(a1 * f_(p)), int((a2 + 1) * f_(p)) + 1):
                for bp in range(int(b1 * f_(p)), int((b2 + 1) * f_(p)) + 1):
                    a, b = p.dd(ap), p.dd(bp)
                    if not (a1 <= a <= a2 and b1 <= b <= b2):
                        continue
                    x, y = (bp, ap) if vert else (ap, bp)
                    xd, yd = p.xy(a, b)
                    if (ia, ib) == missing:
                        c = hexc("#0f1226")
                        if p.hits(ap, lambda i: i - a1 == (b - b1) + 2 or (i - a1) + (b - b1) == 7):
                            c = hexc("#c96a2a") if (a + b) % 3 else hexc("#39c0b0")       # Drähte
                        p.put(x, y, c)
                        continue
                    c = cell
                    if p.hits(ap, lambda i: (i - a1) % 4 == 0) or p.hits(bp, lambda i: (i - b1) % 4 == 0):
                        c = cell_lo                         # feines Leiterraster
                    if p.hits(ap + bp, lambda i: i % 23 in (0, 1)) if False else ((xd + yd) % 23) in (0, 1):
                        c = cell_hi                         # Glanzstreifen schräg über das ganze Paneel
                    if p.hits(ap, lambda i: i == a1) or p.hits(bp, lambda i: i == b1):
                        c = grid if hsh(x, y, 80) > 0.3 else cell_hi   # helle Kante oben/links je Zelle
                    p.put(x, y, c)
            if (ia, ib) in cracked:
                x, y = p.xy(a1 + 2, b1 + 1)
                p.crack(x, y, 10, cracked[(ia, ib)], hexc("#e6f0ff"))
                p.crack(x + 3, y + 2, 5, cracked[(ia, ib)] + 9, hexc("#e6f0ff"), 1, -1)
    bm = int(round(b0 + 2 * cb)) + 1
    last_a = -1
    for ap in range(int(IN * f_(p)), int((L - IN) * f_(p))):  # Sammelschiene; die Nieten kommen mitten hinein, die nächsten Zeilen überdecken ihre untere Hälfte (wie bisher)
        a = p.dd(ap)
        for k in range(3):
            c = steel_hi if k == 0 else (steel if k == 1 else steel_lo)
            for bp in range(int(math.floor((bm + k) * f_(p) + 0.5)), int(math.floor((bm + k + 1) * f_(p) + 0.5)) or 1):
                p.put(*((bp, ap) if vert else (ap, bp)), c)
        if a != last_a and a % 12 == 6:
            x, y = p.xy(a, bm)
            p.rivet(x, y, hexc("#eef2ff"), steel_lo)
        last_a = a
    inn = W(IN)
    for y in range(p.h):                                    # Rahmen: Lichtkante innen oben/links, Schatten unten/rechts
        for x in range(p.w):
            e = p.edge(x, y) - inn
            if e == 0:
                lit = min(x, y) <= min(p.w - 1 - x, p.h - 1 - y)
                p.put(x, y, steel_hi if lit else steel_lo)
            elif e in range(W(2), W(2) + W(1)):
                p.put(x, y, steel_lo)
    for (a, b) in ((IN + 1, IN + 1), (L - IN - 3, IN + 1), (IN + 1, S - IN - 3), (L - IN - 3, S - IN - 3)):
        x, y = p.xy(a, b)
        p.rivet(x, y, hexc("#eef2ff"), steel_lo)
    x, y = p.xy(80, 34)
    p.hole(x, y, 5, 9)
    p.frame()
    return p.im


def f_(p):
    return p.f


def crate():
    """Quadratisches Stück (16 × 16 Einheiten): Mittelteil des Containers mit dem Farbband, eigener Rahmen."""
    p = Pic(False)
    p.w = p.h = S * N // 3
    p.im = container(False).crop((24 * N // 3, 0, 24 * N // 3 + S * N // 3, S * N // 3))
    p.frame()
    return p.im


def sheet(n=3):
    """Ein Blatt in der Größe n (Aufbau wie debris.png, mit 16n/32n statt 48/96)."""
    global N
    N = n
    s, l = S * n // 3, L * n // 3
    out = Image.new("RGBA", (3 * s + l, 3 * s), (0, 0, 0, 0))
    for i, fn in enumerate((container, hull, solar)):
        out.paste(fn(True), (i * s, 0))
        out.paste(fn(False), (3 * s, i * s))
    out.paste(crate(), (0, l))
    return out


def main():
    sheets = {n: sheet(n) for n in SIZES}
    sheets[3].save(OUT)
    stack(sheets).save(OUT_SIZES)
    print("->", OUT, sheets[3].size, "und", OUT_SIZES)


if __name__ == "__main__":
    main()
