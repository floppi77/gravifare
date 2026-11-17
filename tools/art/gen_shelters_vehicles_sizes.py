"""Runde 72, Schritt 4: Haltestellen und Verkehrsfahrzeuge als Formen in Einheiten, je Pixelgröße 2–6 eigens gerastert.

Entwürfe und Vergleichsbilder nach scratch/haltestellen/ und scratch/verkehr/ (GF_TRAFFIC_OUT); mit --install die Blätter für das Spiel.
  Haltestellen: 9 Stück (je Sektor eine) zu 20 × 17 Einheiten (im Spiel bisher aus 72 × 60 Punkten auf 20,4 × 17 verkleinert), nebeneinander
                 in einem Blatt (180 × 17 Einheiten je Größe, die fünf Größen untereinander).
  Verkehr:      5 Farben (blue, red, green, purple, silver) zu 26 × 16 Einheiten (wie das Taxi), nebeneinander (130 × 16 Einheiten je Größe).
Licht oben links, harte Kanten, feste Farbrampen, Kontur in ganzen Bildpunkten (1 bis Größe 4, darüber 2), Kleinteile je Größe. Fester Aufbau
ohne Zufall. Aufruf aus der Projektwurzel:  python3 tools/art/gen_shelters_vehicles_sizes.py            (Entwurf nach scratch/)
                               python3 tools/art/gen_shelters_vehicles_sizes.py --install  (zusätzlich assets/art/shelters_sizes.png, vehicles_sizes.png)"""
import math, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sizekit import SIZES, stack, stroke

OUT = os.environ.get("GF_TRAFFIC_OUT", "scratch/")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], float)


def lit(c, f):
    return np.clip(c * f, 0, 255)


def mix(a, b, t):
    return a * (1 - t) + b * t


OL = hexc("#0c0f24")


class Cv:
    def __init__(self, w, h, n):
        self.n, self.t, self.W, self.H = n, stroke(n), w, h
        self.w, self.h = w * n, h * n
        xs = (np.arange(self.w) + 0.5) / n
        ys = (np.arange(self.h) + 0.5) / n
        self.X, self.Y = np.meshgrid(xs, ys)
        self.col = np.zeros((self.h, self.w, 3))
        self.on = np.zeros((self.h, self.w), bool)

    def put(self, m, c):
        self.col[m] = c
        self.on |= m

    def ell(self, cx, cy, rx, ry):
        return ((self.X - cx) / rx) ** 2 + ((self.Y - cy) / ry) ** 2 <= 1.0

    def rect(self, x0, y0, x1, y1):
        return (self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1)

    def poly(self, pts):
        X, Y = self.X, self.Y
        inside = np.zeros((self.h, self.w), bool)
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            inside ^= ((yi > Y) != (yj > Y)) & (X < (xj - xi) * (Y - yi) / (yj - yi + 1e-12) + xi)
            j = i
        return inside

    def cap(self, p, q, r):
        px, py = p
        qx, qy = q
        dx, dy = qx - px, qy - py
        L2 = dx * dx + dy * dy + 1e-12
        u = np.clip(((self.X - px) * dx + (self.Y - py) * dy) / L2, 0, 1)
        return (self.X - (px + u * dx)) ** 2 + (self.Y - (py + u * dy)) ** 2 <= r * r

    def box(self, u0, y0, wpx, hpx):
        c0, r0 = int(round(u0 * self.n)), int(round(y0 * self.n))
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + hpx, 0), max(c0, 0):max(c0 + wpx, 0)] = True
        return m

    def px(self, v):
        return max(1, int(round(v * self.n)))


def ramp_put(c, m, ramp, t):
    steps = len(ramp)
    idx = np.clip((t * steps).astype(int), 0, steps - 1)
    for i in range(steps):
        c.put(m & (idx == i), ramp[i])


def ramp4(base):
    return [lit(base, 1.25), base, lit(base, 0.78), lit(base, 0.58)]


def ramp_dim(base):
    """Gedämpfte Rampe für Wände und Scheiben der Haltestellen (die Haltestellen sind dunkler als Taxi und Fahrzeuge)."""
    return [lit(base, 1.0), lit(base, 0.86), lit(base, 0.72), lit(base, 0.58)]


def grow(mask, n):
    g = mask.copy()
    for _ in range(n):
        k = g.copy()
        k[1:, :] |= g[:-1, :]; k[:-1, :] |= g[1:, :]
        k[:, 1:] |= g[:, :-1]; k[:, :-1] |= g[:, 1:]
        g = k
    return g


def finish(c):
    ring = grow(c.on, c.t) & ~c.on
    c.col[ring] = OL
    alpha = c.on | ring
    a = np.zeros((c.h, c.w, 4), np.uint8)
    a[..., :3] = np.clip(np.round(c.col), 0, 255).astype(np.uint8)
    a[..., 3] = np.where(alpha, 255, 0)
    a[~alpha] = 0
    return Image.fromarray(a)


# ----------------------------------------------------------------------------------------------------------------------------------
# Haltestellen (20 × 17 Einheiten)
# ----------------------------------------------------------------------------------------------------------------------------------
# roof/trim/wall/glass/bench: Farben; Besonderheiten je Sektor in shelter()
SHELTERS = [
    dict(roof="#4a5596", trim="#35e0d2", wall="#3a5a96", glass="#6a9ad0", bench="#c9871f"),                 # 1 Sternenhafen
    dict(roof="#6a3aa0", trim="#ff4fd8", wall="#5a2a80", glass="#8a4ab8", bench="#c9871f"),                 # 2 Kristallschlucht
    dict(roof="#6a5a40", trim="#7a6a4a", wall="#a85a2a", glass="#b86a3a", bench="#7a6a54"),                 # 3 Schrottplatz
    dict(roof="#eaf6ff", trim="#cfe6f5", wall="#5a9aa8", glass="#8ac0d0", bench="#cfd8e8"),                 # 4 Eisstation
    dict(roof="#a03a2a", trim="#ff7a1a", wall="#5a3020", glass="#6a3a28", bench="#2a2a30"),                 # 5 Magmawerk
    dict(roof="#2a8a8a", trim="#4fd8ff", wall="#1f7a7a", glass="#1f4a66", bench="#c9871f"),                 # 6 Riff
    dict(roof="#b89a60", trim="#e0c890", wall="#c8b48a", glass="#d8c8a0", bench="#c9871f"),                 # 7 Betonstadt
    dict(roof="#3a6a30", trim="#6aa860", wall="#4a6a40", glass="#5a8050", bench="#4a4a40"),                 # 8 Dschungel
    dict(roof="#3a3070", trim="#a78cff", wall="#2a2540", glass="#3a3050", bench="#2a2a3a"),                 # 9 Leere
]


def shelter(n, k):
    S = SHELTERS[k]
    c = Cv(20, 17, n)
    tu = c.t / n
    X, Y = c.X, c.Y
    A = np.abs(X - 10.0)
    roof_c, trim_c, wall_c, glass_c, bench_c = (hexc(S[q]) for q in ("roof", "trim", "wall", "glass", "bench"))
    # Bänke und Beine (unter dem Dach, hinter den Scheiben sichtbar)
    # Rückwand
    wall = c.rect(1.3, 4.2, 18.7, 17.0)
    tone = np.clip(0.55 * (Y - 4.2) / 12.8 + 0.25 * (X - 1.3) / 17.4, 0, 1)
    ramp_put(c, wall, ramp_dim(wall_c), tone)
    for sx in (-1, 1):                                                  # Glasflächen links und rechts der Tür
        g = c.rect(10 + sx * 2.7 - (3.2 if sx < 0 else 0.0) + (0.0 if sx < 0 else 0.0), 5.2, 10 + sx * 2.7 + (0.0 if sx < 0 else 3.2), 13.6) if False else None
    gl = c.rect(1.9, 5.3, 7.6, 13.6)
    gr = c.rect(12.4, 5.3, 18.1, 13.6)
    for g, sgn in ((gl, 1), (gr, -1)):
        ramp_put(c, g, ramp_dim(glass_c), np.clip(0.5 * (Y - 5.3) / 8.3 + 0.35 * (1 - sgn) / 2 * 0.0 + 0.2 * (X - 1.9) / 16.0, 0, 1))
        c.put(g & (Y < 5.3 + max(tu, 0.3)), lit(glass_c, 1.4))
        c.put(g & (Y > 13.6 - max(tu, 0.3)), lit(glass_c, 0.5))
        if n >= 4:                                                      # Spiegelstreifen
            c.put(g & (np.abs((X + Y * 0.6) % 4.2 - 1.0) < max(0.2, tu * 0.8)) & (Y < 11.5), lit(glass_c, 1.18))
    # Tür: dunkler Rahmen, Licht von innen
    door = c.rect(7.9, 6.7, 12.1, 17.0)
    c.put(door, hexc("#16172e"))
    inner = c.rect(8.5 if n < 3 else 8.45, 7.5, 11.5 if n < 3 else 11.55, 17.0)
    ramp_put(c, inner, [hexc("#fff6d0"), hexc("#ffe9a8"), hexc("#ffcf80"), hexc("#ffb85a")], np.clip((Y - 7.5) / 9.5, 0, 1))
    c.put(c.rect(7.9, 6.7, 12.1, 7.5), hexc("#7a5a2a"))                  # Sturz
    # Bänke
    for sx in (-1, 1):
        bx0 = 2.2 if sx < 0 else 13.6
        c.put(c.rect(bx0, 13.6, bx0 + 4.2, 14.7), bench_c)
        c.put(c.rect(bx0, 13.6, bx0 + 4.2, 13.6 + max(tu, 0.3)), lit(bench_c, 1.4))
        c.put(c.rect(bx0, 14.7, bx0 + 4.2, 14.7 + max(tu, 0.3)), lit(bench_c, 0.6))
        for lx in (bx0 + 0.4, bx0 + 3.4):
            c.put(c.rect(lx, 14.9, lx + 0.55, 17.0), hexc("#16172e"))
    # Dach: Trapez mit Rand, darunter Schattenband
    roof = c.poly([(0.0, 4.4), (2.2, 0.9), (17.8, 0.9), (20.0, 4.4)])
    ramp_put(c, roof, ramp4(roof_c), np.clip(0.55 * (Y - 0.9) / 3.5 + 0.3 * (X / 20.0), 0, 1))
    c.put(roof & (Y < 0.9 + max(tu * 1.3, 0.3)), lit(roof_c, 1.5))
    c.put(c.rect(0.0, 4.4, 20.0, 4.4 + max(0.6, tu * 1.6)), lit(roof_c, 0.55))
    c.put(c.rect(0.9, 4.4 + max(0.6, tu * 1.6), 19.1, 4.4 + max(0.6, tu * 1.6) + max(tu * 1.3, 0.3)), trim_c)        # Leuchtkante unter dem Dach
    # Schild über der Tür
    c.put(c.rect(8.15, 1.95, 11.85, 3.45), hexc("#16172e"))
    c.put(c.rect(8.55, 2.35, 11.45, 3.05), hexc("#ffcb3d"))
    # sektorspezifisch
    if k == 1:                                                           # Kristalle auf dem Dach
        for cxk, hk, col in ((3.8, 2.2, "#4fd8ff"), (5.0, 1.5, "#ff7ad8"), (14.8, 1.6, "#ff7ad8"), (16.0, 2.4, "#4fd8ff")):
            c.put(c.poly([(cxk - 0.5, 1.0), (cxk, 1.0 - hk), (cxk + 0.5, 1.0)]), hexc(col))
    if k == 2:                                                           # Bohlen, Blech mit Nieten
        for yy in (1.9, 2.9):
            c.put(roof & (np.abs(Y - yy) < max(0.17, tu * 0.7)), lit(roof_c, 0.6))
        c.put(c.rect(15.0, 10.0, 18.0, 13.2), hexc("#4a5a50"))
        for (qx, qy) in ((15.3, 10.3), (17.4, 10.3), (15.3, 12.6), (17.4, 12.6)):
            c.put(c.box(qx, qy, 1, 1), hexc("#c9d2ea"))
    if k == 3:                                                           # Schnee und Eiszapfen
        c.put(c.rect(0.2, 0.9, 19.8, 2.1) & roof, hexc("#ffffff"))
        for ix in (2.0, 4.2, 6.4, 13.6, 15.8, 18.0):
            c.put(c.poly([(ix - 0.35, 4.6), (ix, 6.4 + 0.5 * (ix % 3) * 0.3), (ix + 0.35, 4.6)]), hexc("#bfe6ff"))
    if k == 4:                                                           # Solarpaneel auf dem Dach
        sp = c.rect(13.2, 0.2, 17.8, 1.5)
        c.put(sp, hexc("#1f3a86"))
        for gx in (14.4, 15.6, 16.8):
            c.put(c.rect(gx, 0.2, gx + max(tu, 0.2), 1.5), hexc("#7da2ff"))
        c.put(c.rect(13.2, 0.2, 17.8, 0.2 + max(tu, 0.3)), hexc("#3f67d0"))
        for ix in (3.0, 5.0, 15.0, 17.0):
            c.put(c.rect(ix, 15.6, ix + 1.2, 15.6 + max(tu, 0.3)), hexc("#ff7a1a"))
    if k == 5:                                                           # Kuppel statt Trapez, Bullaugen, Korallen
        dome = c.ell(10, 4.6, 10.0, 4.1) & (Y < 4.4)
        ramp_put(c, dome, ramp4(roof_c), np.clip(0.55 * (Y - 0.5) / 3.9 + 0.3 * (X / 20.0), 0, 1))
        c.put(dome & (Y < 0.5 + max(tu * 1.5, 0.35)), lit(roof_c, 1.5))
        c.put(c.rect(8.15, 1.95, 11.85, 3.45), hexc("#16172e"))
        c.put(c.rect(8.55, 2.35, 11.45, 3.05), hexc("#ffcb3d"))
        for cxk in (4.7, 15.3):
            c.put(c.ell(cxk, 9.4, 2.35, 2.35), hexc("#cfe6f5"))
            c.put(c.ell(cxk, 9.4, 1.8, 1.8), hexc("#1f4a86"))
            c.put(c.ell(cxk - 0.4, 8.9, 0.7, 0.55), hexc("#6ab0ff"))
            if n >= 3:
                c.put(c.box(cxk + 0.6, 8.4, 1, 1), hexc("#ffffff"))
        for cxk in (1.4, 18.6):
            c.put(c.cap((cxk, 17.0), (cxk + (0.3 if cxk < 5 else -0.3), 15.0), 0.18), hexc("#ff7aa0"))
            c.put(c.ell(cxk + (0.3 if cxk < 5 else -0.3), 14.9, 0.4, 0.4), hexc("#ff9ac0"))
    if k == 6:                                                           # Uhr und Tafel
        c.put(c.ell(3.6, 9.2, 1.85, 1.85), hexc("#e8e0c8"))
        c.put(c.ell(3.6, 9.2, 1.45, 1.45), hexc("#faf6e8"))
        c.put(c.cap((3.6, 9.2), (3.6, 8.1), max(0.1, tu * 0.5)), hexc("#16172e"))
        c.put(c.cap((3.6, 9.2), (4.4, 9.7), max(0.1, tu * 0.5)), hexc("#16172e"))
        c.put(c.rect(13.0, 7.0, 18.4, 10.2), hexc("#16172e"))
        for i, yy in enumerate((7.8, 8.6, 9.4)):
            c.put(c.rect(13.5, yy, 13.5 + (3.4 if i != 1 else 2.2), yy + max(tu * 1.2, 0.3)), hexc("#6aff9a" if i != 2 else "#ffd23a"))
    if k == 7:                                                           # Moos, Ranken, leuchtende Pilze
        c.put(roof & (Y < 1.9) & (X > 2.0) & (X < 18.0), hexc("#4a8a3a"))
        for ix, ln in ((2.4, 3.4), (6.2, 2.4), (13.8, 2.6), (17.6, 3.6)):
            c.put(c.cap((ix, 4.6), (ix + 0.2, 4.6 + ln), max(0.12, tu * 0.5)), hexc("#2f6a3a"))
        for ix in (4.3, 15.7):
            c.put(c.box(ix, 16.0, 1, max(1, n // 3)), hexc("#6ff0e0"))
    if k == 8:                                                           # feine Leuchtlinie
        c.put(c.rect(0.9, 1.7, 19.1, 1.7 + max(tu, 0.3)), hexc("#ff7a1a"))
        c.put(c.rect(1.5, 16.2, 3.5, 16.2 + max(tu, 0.3)), trim_c)
        c.put(c.rect(16.5, 16.2, 18.5, 16.2 + max(tu, 0.3)), trim_c)
    return finish(c)


# ----------------------------------------------------------------------------------------------------------------------------------
# Verkehr: „Pendlergleiter“ (26 × 16 Einheiten, Blick nach rechts)
# ----------------------------------------------------------------------------------------------------------------------------------
CARS = {"red": "#e04a4a", "blue": "#4a7ad8", "green": "#4ac878", "purple": "#a060e0", "silver": "#dfe6f4"}      # Reihenfolge wie PropsView.PAINTS


def vehicle(n, name):
    base = hexc(CARS[name])
    c = Cv(26, 16, n)
    tu = c.t / n
    X, Y = c.X, c.Y
    hull_r = [lit(base, 1.12), lit(base, 0.95), lit(base, 0.75), lit(base, 0.55)]
    glass = [hexc("#bff6f6"), hexc("#73d5df"), hexc("#4bb6ca"), hexc("#2f8fa8")]
    # Unterbau (Kufe): flache graue Linse
    skirt = c.ell(13.0, 13.4, 8.6, 1.6) & (Y > 12.4)
    ramp_put(c, skirt, [hexc("#9aa3cf"), hexc("#6f779f"), hexc("#4f567f"), hexc("#363b61")], np.clip((Y - 12.4) / 2.6, 0, 1))
    # Heckflosse oben links
    fin = c.poly([(3.2, 6.0), (4.6, 0.9), (7.6, 0.9), (8.4, 6.0)])
    ramp_put(c, fin, hull_r, np.clip(0.5 * (Y - 0.9) / 5.1 + 0.3 * (X - 3.2) / 5.2, 0, 1))
    c.put(c.rect(4.8, 1.8, 7.0, 1.8 + max(tu * 1.4, 0.4)) & fin, hexc("#ffffff"))                       # Zeichen auf der Flosse
    c.put(c.rect(5.4, 1.8 + max(tu * 1.4, 0.4), 6.4, 3.3) & fin, hexc("#ffffff"))
    # Rumpf: lang gestreckt, vorn zugespitzt
    t_ = (np.abs(X - 12.6) / 12.4)
    hull = (t_ ** 2.6 + (np.abs(Y - 9.0) / 3.95) ** 2.2) <= 1.0
    hull &= (X < 25.6) & (Y > 5.05) & (Y < 12.95)
    tone = np.clip(0.6 * (Y - 5.05) / 7.9 + 0.3 * (X - 0.5) / 25.0, 0, 1)
    ramp_put(c, hull, hull_r, tone)
    c.put(hull & (Y < 4.2 + max(tu * 1.4, 0.3)) & (X > 2.5) & (X < 20.0), hull_r[0])               # Lichtkante oben
    # Kabinendach vorn (Glas), Fensterband
    cabin = c.poly([(14.2, 5.4), (15.6, 3.8), (19.6, 3.9), (23.8, 7.3), (24.6, 8.6), (14.2, 8.6)]) & ((Y < 8.6) | hull)
    ramp_put(c, cabin, glass, np.clip(0.55 * (Y - 3.4) / 5.2 + 0.25 * (X - 13.8) / 11.0, 0, 1))
    c.put(cabin & (np.abs((X - 13.8) * 0.8 + (Y - 3.6) * 1.0 - 4.0) < max(0.22, tu * 0.8)) & (Y < 7.0), hexc("#d6f9f9"))        # Spiegelung
    c.put(c.rect(13.7, 5.2, 14.0 + max(tu, 0.2), 8.6) & cabin, glass[3])                                              # Spante
    c.put(c.rect(14.6, 3.3, 20.2, 3.3 + max(tu, 0.3)) & cabin, glass[0])
    # Passagierfenster: vier Stück
    for i in range(4):
        wx = 5.4 + i * 2.15
        c.put(c.rect(wx, 6.2, wx + 1.55, 7.55), hexc("#1d2b5a"))
        c.put(c.rect(wx, 6.2, wx + 1.55, 6.2 + max(tu, 0.3)), hexc("#7aa0e8"))
    # Seitenlinie und Rumpfnaht
    c.put(c.rect(1.4, 9.1, 24.8, 9.1 + max(tu * 1.2, 0.3)) & hull, hexc("#f2f6ff"))
    c.put(c.rect(1.4, 9.1 + max(tu * 1.2, 0.3), 24.8, 9.1 + max(tu * 2.4, 0.6)) & hull, hull_r[3])
    if n >= 4:                                                            # Plattenfugen unten
        for fx in (6.0, 11.0, 16.0, 21.0):
            c.put(c.rect(fx, 9.9, fx + max(tu, 0.17), 12.2) & hull, hull_r[3])
    # Rücklicht, Frontlicht, Düse
    c.put(c.rect(0.5, 6.2, 1.5, 7.4) & hull | c.box(0.4, 6.2, max(1, c.px(0.9)), max(2, c.px(1.1))), hexc("#ff4d5a"))
    c.put(c.rect(24.2, 8.3, 25.7, 9.4) & hull, hexc("#fff6c0"))
    c.put(c.rect(0.4, 8.2, 1.9, 9.8) & hull, hexc("#e8a83a") if False else hull_r[3])
    return finish(c)


def sheet(fn, items, units, n):
    w, h = units
    out = Image.new("RGBA", (w * n * len(items), h * n), (0, 0, 0, 0))
    for i, it in enumerate(items):
        out.paste(fn(n, it), (i * w * n, 0))
    return out


def main():
    os.makedirs(OUT + "haltestellen", exist_ok=True)
    os.makedirs(OUT + "verkehr", exist_ok=True)
    sh = {n: sheet(shelter, range(9), (20, 17), n) for n in SIZES}
    stack(sh).save(OUT + "haltestellen/haltestellen_sizes.png")
    if "--install" in sys.argv:
        stack(sh).save("assets/art/shelters_sizes.png")
    vh = {n: sheet(vehicle, list(CARS), (26, 16), n) for n in SIZES}
    stack(vh).save(OUT + "verkehr/verkehr_sizes.png")
    if "--install" in sys.argv:
        stack(vh).save("assets/art/vehicles_sizes.png")
    old_sh = Image.open("assets/art/shelters.png").convert("RGBA")
    k = 3
    # Vergleich Haltestellen: je Größe eine Zeile, alt über neu (alt = heute im Spiel: 72 × 60 auf 20,4 × 17 Einheiten gestreckt)
    for n in (2, 4, 5):
        im = Image.new("RGBA", (9 * (20 * n * k + 8) + 8, 2 * (17 * n * k + 8) + 8), (48, 52, 90, 255))
        for i in range(9):
            alt = old_sh.crop((i * 76, 0, i * 76 + 72, 60)).resize((round(20.4 * n), 17 * n), Image.NEAREST)
            new = sh[n].crop((i * 20 * n, 0, (i + 1) * 20 * n, 17 * n))
            im.alpha_composite(alt.resize((alt.width * k, alt.height * k), Image.NEAREST), (8 + i * (20 * n * k + 8), 8))
            im.alpha_composite(new.resize((new.width * k, new.height * k), Image.NEAREST), (8 + i * (20 * n * k + 8), 16 + 17 * n * k))
        im.save(OUT + "haltestellen/vergleich_alt_neu_n%d.png" % n)
    big = Image.new("RGBA", (3 * (20 * 6 * 2 + 8) + 8, 3 * (17 * 6 * 2 + 8) + 8), (48, 52, 90, 255))
    for i in range(9):
        new = sh[6].crop((i * 120, 0, (i + 1) * 120, 102))
        big.alpha_composite(new.resize((new.width * 2, new.height * 2), Image.NEAREST), (8 + (i % 3) * (240 + 8), 8 + (i // 3) * (204 + 8)))
    big.save(OUT + "haltestellen/alle_n6.png")
    # Vergleich Verkehr
    for n in (2, 4, 5):
        im = Image.new("RGBA", (5 * (26 * n * k + 8) + 8, 2 * (16 * n * k + 8) + 8), (48, 52, 90, 255))
        for i, nm in enumerate(CARS):
            alt = Image.open("assets/art/vehicle_%s.png" % nm).convert("RGBA").resize((26 * n, 16 * n), Image.NEAREST)
            new = vh[n].crop((i * 26 * n, 0, (i + 1) * 26 * n, 16 * n))
            im.alpha_composite(alt.resize((alt.width * k, alt.height * k), Image.NEAREST), (8 + i * (26 * n * k + 8), 8))
            im.alpha_composite(new.resize((new.width * k, new.height * k), Image.NEAREST), (8 + i * (26 * n * k + 8), 16 + 16 * n * k))
        im.save(OUT + "verkehr/vergleich_alt_neu_n%d.png" % n)
    bigv = Image.new("RGBA", (26 * 6 * 3 + 16, 5 * (16 * 6 * 3 // 3 * 1 + 8) + 8), (48, 52, 90, 255))
    for i, nm in enumerate(CARS):
        new = vh[6].crop((i * 156, 0, (i + 1) * 156, 96))
        bigv.alpha_composite(new.resize((156 * 3, 96 * 3 // 3 * 1), Image.NEAREST) if False else new, (8, 8 + i * 104))
    bigv.save(OUT + "verkehr/alle_n6.png")
    print("Entwurf nach", OUT)


if __name__ == "__main__":
    main()
