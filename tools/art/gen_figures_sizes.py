"""ENTWURF (Runde 72, Schritt 4): alle 14 Fahrgast-Figuren als Formen in Einheiten, je Pixelgröße 2–6 eigens gerastert (wie gen_taxi.py das Taxi).

Nur Entwurf: schreibt nach scratch/figuren/ (GF_FIG_OUT), nie nach assets/. Nichts davon ist im Spiel.
Die Figurendaten (Haut, Haar, Kleidung, Zubehör, Frisur) stammen aus tools/art/aseprite/gen_figures.py (Quelltext wird nur gelesen), die Bilder
des Blatts sind dieselben zehn wie in assets/art/passengers.png: 0–1 Warten (1 = Blinzeln, Körper 1 Punkt tiefer), 2–3 Winken, 4–9 Laufen nach rechts.
Die Formen sind auf einer Fläche von 8 × 12 Einheiten entworfen und werden auf ein Bild von 7 × 10 Einheiten gerastert (im Spiel bisher 6,8 × 10,2 aus 24 × 36 Punkten verkleinert, das ging in keiner Größe auf). Licht oben links, harte Kanten, feste Farbrampen, Kontur in ganzen Bildpunkten
(1 bis Größe 4, darüber 2); Kleinteile (Augenglanz, Wangen, Spange, Haarsträhnen) kommen mit mehr Bildpunkten. Fester Aufbau ohne Zufall.
Ausgabe: je Figur ein Streifen je Größe, das ganze Blatt je Größe untereinander (figuren_sizes.png, 70 · n × 140 · n je Größe), Vergleichsbilder.
Aufruf aus der Projektwurzel:  python3 tools/art/gen_figures_sizes.py            (Entwurf nach scratch/figuren/)
                               python3 tools/art/gen_figures_sizes.py --install  (zusätzlich assets/art/passengers_sizes.png)"""
import math, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sizekit import SIZES, stack, stroke

W, H = 8, 12                       # Entwurfsfläche in Einheiten (die Formen sind in diesen Koordinaten beschrieben)
IW, IH = 7, 10                     # Bild im Spiel: 7 × 10 Einheiten (bisher 6,8 × 10,2 aus 8 × 12 verkleinert, das geht in keiner Größe auf)
OUT = os.environ.get("GF_FIG_OUT", "scratch/figuren/")


def _load_fig():
    """FIG und ORDER aus gen_figures.py lesen, ohne das Modul auszuführen (es legt Ordner an)."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aseprite", "gen_figures.py")
    src = open(p, encoding="utf-8").read()
    a = src.index("FIG = {")
    b = src.index("ORDER = ")
    b = src.index("\n", b)
    ns = {}
    exec(src[a:b], ns)  # nosec B102 - eigene Datei im Repo (FIG besteht aus dict()-Aufrufen, literal_eval geht nicht)
    return ns["FIG"], ns["ORDER"]


FIG, _ORDER_GEN = _load_fig()
# Zeilenfolge des Fahrgastblatts = PassengerActor.LOOK_VOICE (Zeilen 0–3 sind die ursprünglichen Figuren)
ORDER = ["f0", "m0", "m2", "f6", "f1", "f2", "f3", "f4", "f5", "m1", "m3", "m4", "m5", "m6"]


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], float)


def lit(c, f):
    return np.clip(c * f, 0, 255)


def mix(a, b, t):
    return a * (1 - t) + b * t


OL = hexc("#0c0f24")
SHOE, SHOE_H = hexc("#10142b"), hexc("#3a4170")
INK, GLINT, MOUTH = hexc("#1a1f4a"), hexc("#ffffff"), hexc("#8a3a3a")
WHITE = hexc("#ffffff")


def ramp4(base, hi=None):
    """Vier Stufen hell → dunkel um eine Grundfarbe."""
    hi = hi if hi is not None else lit(base, 1.22)
    return [mix(hi, WHITE, 0.0) if False else lit(hi, 1.0), base, lit(base, 0.78), lit(base, 0.58)]


class Cv:
    def __init__(self, n):
        self.n = n
        self.t = stroke(n)
        self.w, self.h = IW * n, IH * n
        xs = (np.arange(self.w) + 0.5) / n * (W / IW)                  # Lage der Bildpunktmitte auf der Entwurfsfläche
        ys = (np.arange(self.h) + 0.5) / n * (H / IH)
        self.X, self.Y = np.meshgrid(xs, ys)
        self.col = np.zeros((self.h, self.w, 3))
        self.on = np.zeros((self.h, self.w), bool)
        self.dy = 0.0

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
            cond = ((yi > Y) != (yj > Y)) & (X < (xj - xi) * (Y - yi) / (yj - yi + 1e-12) + xi)
            inside ^= cond
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
        """Rechteck in ganzen Bildpunkten ab (u0, y0) in Einheiten."""
        c0, r0 = int(round(u0 * self.n * IW / W)), int(round(y0 * self.n * IH / H))
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + hpx, 0), max(c0, 0):max(c0 + wpx, 0)] = True
        return m

    def px(self, v):
        return max(1, int(round(v * self.n * IW / W)))


def ramp_put(c, m, ramp, t, steps=4):
    idx = np.clip((t * steps).astype(int), 0, steps - 1)
    for i in range(steps):
        c.put(m & (idx == i), ramp[min(i, len(ramp) - 1)])


def grow(mask, n):
    g = mask.copy()
    for _ in range(n):
        k = g.copy()
        k[1:, :] |= g[:-1, :]; k[:-1, :] |= g[1:, :]
        k[:, 1:] |= g[:, :-1]; k[:, :-1] |= g[:, 1:]
        g = k
    return g


class Look:
    """Farben und Maße einer Figur aus den Daten von gen_figures.py."""

    def __init__(self, F):
        self.F = F
        self.acc = F.get("acc", [])
        self.style = F["hair_style"]
        self.skin = ramp4(hexc(F["skin"]), lit(hexc(F["skin"]), 1.1))
        self.hair = ramp4(hexc(F["hair"]), hexc(F["hair_hi"]))
        self.hair = [self.hair[0], mix(hexc(F["hair_hi"]), hexc(F["hair"]), 0.55), hexc(F["hair"]), lit(hexc(F["hair"]), 0.68)]
        self.top = ramp4(hexc(F["top"]))
        self.inner = hexc(F["inner"]) if F.get("inner") else None
        self.legs = hexc(F["legs"]) if F.get("legs") else None
        self.skirt = hexc(F["skirt"]) if F.get("skirt") else None
        self.dress = bool(F.get("dress"))
        self.cap = ramp4(hexc(F["cap"])) if F.get("cap") else None
        self.wd = F.get("width", 0) / 3.0                 # breiter/schmaler in Einheiten
        self.hy = -F.get("height", 0) / 3.0               # kleiner/gebeugt: Kopf und Rumpf tiefer
        self.old = "cane" in self.acc or self.style == "bun_curly"
        self.alien = "antenna" in self.acc
        self.dark = F["skin"] in ("#7a4e36", "#8a5a3c")
        self.blush = hexc("#5fb0c8") if self.alien else (hexc("#d46a5a") if self.dark else hexc("#f59a9a"))


# ----------------------------------------------------------------------------------------------------------------------------------
# Vorderansicht
# ----------------------------------------------------------------------------------------------------------------------------------
def front(n, L, pose, k):
    c = Cv(n)
    tu = c.t / n
    F, acc = L.F, L.acc
    wave = pose == "wave"
    blink = pose == "idle" and k == 1
    dy = L.hy + (1.0 / 3.0 if blink else 0.0)
    X, Y = c.X, c.Y - dy                                          # Kopf und Rumpf sind um dy nach unten verschoben (Y: Lage im Körper)
    Yg = c.Y                                                      # Boden und Füße bleiben
    U = X - 4.0
    A = np.abs(U)
    cx = 4.0
    sk, tp = L.skin, L.top
    # --- Zubehör hinter dem Körper (Koffer usw. in der Hand, nur ohne Winken)
    hold_r = ("suitcase" in acc or "briefcase" in acc or "cane" in acc) and not wave
    # --- Beine und Schuhe
    skirted = L.dress or (L.skirt is not None)
    for s in (-1, 1):
        lx = cx + s * 1.3
        leg = (np.abs(X - lx) <= 0.5) & (Yg >= 9.9) & (Yg < 11.2)
        c.put(leg, sk[2] if skirted else (L.legs if s < 0 else lit(L.legs, 0.78)))
        if not skirted and s > 0:
            pass
        shoe = c.ell(lx, 11.35, 1.15, 0.62) & (Yg > 10.7)
        c.put(shoe, SHOE)
        c.put(shoe & (Yg < 10.7 + max(tu, 0.3)), SHOE_H)
    # --- Kleidung: Rumpf, Kleid, Rock
    hw = 2.05 + L.wd
    top_y = 5.95
    if L.dress:
        hem = 10.25
        half = 2.2 + (np.clip(Y, top_y, hem) - top_y) / (hem - top_y) * 0.95
        body = (A <= half) & (Y >= top_y) & (Y < hem)
        tt = np.clip((Y - top_y) / (hem - top_y), 0, 1)
        tone = np.clip(0.45 * (U + half) / (2 * half) + 0.35 * tt + (tt > 0.88) * 0.25, 0, 1)
        ramp_put(c, body, tp, tone)
        c.put(body & (Y >= hem - max(tu, 0.3)) & (A < half - 0.2), tp[3])
        torso = body
    else:
        sup = ((A / hw) ** 4 + ((Y - 7.55) / 1.6) ** 4) <= 1.0
        torso = sup & (Y >= top_y)
        tt = np.clip((Y - top_y) / 3.2, 0, 1)
        tone = np.clip(0.5 * (U + hw) / (2 * hw) + 0.3 * tt, 0, 1)
        ramp_put(c, torso, tp, tone)
        if L.skirt is not None:
            long = F.get("height", 0) < 0
            sy1 = 10.65 if long else 10.0
            skhalf = 2.0 + (np.clip(Y, 8.2, sy1) - 8.2) / (sy1 - 8.2) * 0.9
            skm = (A <= skhalf) & (Y >= 8.2) & (Y < sy1)
            sramp = ramp4(L.skirt)
            tone_s = np.clip(0.45 * (U + skhalf) / (2 * skhalf) + 0.3 * (Y - 8.2) / (sy1 - 8.2), 0, 1)
            ramp_put(c, skm, sramp, tone_s)
            c.put(skm & (Y >= sy1 - max(tu, 0.3)), sramp[3])
            torso = torso | skm
    if "dress" and L.dress:
        pass
    if L.inner is not None and not L.dress:                                         # Hemd/Bluse: Streifen in der Mitte
        inn = torso & (A < 0.65) & (Y < 8.7)
        c.put(inn, lit(L.inner, 1.0))
        c.put(inn & (U < -0.1), lit(L.inner, 0.88))
        c.put(torso & (np.abs(A - 0.72) < max(0.2, tu * 0.8)) & (Y < 8.7), tp[3])      # Revers
    elif not L.dress:
        c.put(torso & (A < 0.9) & (Y >= top_y) & (Y < top_y + max(tu * 1.4, 0.3)), tp[0])   # Kragenlicht
    if "tie" in acc:
        c.put(torso & (A < 0.2) & (Y < 8.2) & (Y > 6.0), hexc("#c8283a"))
        c.put(torso & (A < 0.1) & (U < 0) & (Y < 8.0) & (Y > 6.0), hexc("#e84a5a"))
    if "bowtie" in acc:
        c.put(c.rect(3.35, 6.05, 4.65, 6.65) & torso, hexc("#c8283a"))
        c.put(c.rect(3.4, 6.05, 3.75, 6.3) & torso, hexc("#ff7a8a"))
    if "flannel" in acc:
        for xx in (-1.3, 0.0, 1.3):
            c.put(torso & (np.abs(U - xx) < max(0.17, tu * 0.7)), tp[3])
        c.put(torso & (np.abs(Y - 7.1) < max(0.17, tu * 0.7)), tp[3])
    if "hoodie" in acc:
        c.put(torso & (np.abs(Y - 8.4) < max(0.17, tu * 0.7)) & (A < 1.2), tp[3])
        for s in (-1, 1):
            c.put(c.box(4 + s * 0.45 - 0.02, 6.15, 1, c.px(0.35)) & torso, hexc("#fff0b0"))
    # --- Arme
    aw = 0.58 + (0.05 if L.wd > 0 else 0.0)
    shx = hw + 0.05
    sl = tp[2]
    arm_l_pts = ((cx - shx + 0.1, 6.55 + dy), (cx - shx - 0.3, 8.75 + dy))
    c.put(c.cap(arm_l_pts[0], arm_l_pts[1], aw), sl)
    c.put(c.cap(arm_l_pts[0], (arm_l_pts[0][0] - 0.1, arm_l_pts[1][1] - 0.9), aw * 0.9), tp[1])
    hand_l = (cx - shx - 0.3, 9.1 + dy)
    c.put(c.ell(hand_l[0], hand_l[1], 0.5, 0.52), sk[1])
    hr = (cx + shx - 0.1, 6.55 + dy)
    if not wave:
        arm_r = c.cap(hr, (cx + shx + 0.3, 8.75 + dy), aw)
        c.put(arm_r, tp[2])
        hand_r = (cx + shx + 0.3, 9.1 + dy)
        c.put(c.ell(hand_r[0], hand_r[1], 0.5, 0.52), sk[2])
    # Zubehör an der Hand
    if "suitcase" in acc and not wave:
        hx, hy = hand_r
        c.put(c.rect(hx - 0.6, hy + 0.1, hx + 0.9, hy + 2.3), hexc("#7a4a2a"))
        c.put(c.rect(hx - 0.6, hy + 0.1, hx + 0.9, hy + 0.1 + max(tu, 0.3)), hexc("#a8703c"))
        c.put(c.rect(hx - 0.6, hy + 1.15, hx + 0.9, hy + 1.15 + max(tu, 0.3)), hexc("#c9a060"))
        c.put(c.rect(hx - 0.6, hy + 2.3 - max(tu, 0.3), hx + 0.9, hy + 2.3), hexc("#4a2a18"))
        c.put(c.rect(hx - 0.15, hy - 0.45, hx + 0.45, hy + 0.1), hexc("#3a2a18"))
        c.put(c.ell(hx, hy, 0.5, 0.5), sk[2])
    if "briefcase" in acc and not wave:
        hx, hy = hand_r
        c.put(c.rect(hx - 0.6, hy + 0.15, hx + 0.9, hy + 1.55), hexc("#1e1e2a"))
        c.put(c.rect(hx - 0.6, hy + 0.15, hx + 0.9, hy + 0.15 + max(tu, 0.3)), hexc("#4a4a60"))
        c.put(c.box(hx + 0.1, hy + 0.85, 1, 1), hexc("#d8b860"))
        c.put(c.ell(hx, hy, 0.5, 0.5), sk[2])
    if "cane" in acc and not wave:
        hx, hy = hand_r
        c.put(c.rect(hx + 0.1, hy, hx + 0.1 + max(0.3, tu * 1.0), 11.7), hexc("#6a4a2a"))
        c.put(c.rect(hx - 0.35, hy - 0.1, hx + 0.1 + max(0.3, tu), hy + max(0.3, tu)), hexc("#8a6a3a"))
        c.put(c.ell(hx, hy, 0.5, 0.5), sk[2])
    if "handbag" in acc:
        hx, hy = hand_l
        c.put(c.cap((hx - 0.2, hy - 1.2), (hx, hy), 0.1), hexc("#8a3a5a"))
        c.put(c.rect(hx - 1.0, hy + 0.1, hx + 0.7, hy + 1.5), hexc("#c84a7a"))
        c.put(c.rect(hx - 1.0, hy + 0.1, hx + 0.7, hy + 0.1 + max(tu, 0.3)), hexc("#ff8ab0"))
        c.put(c.box(hx - 0.1, hy + 0.75, 1, 1), hexc("#ffe14a"))
        c.put(c.ell(hx, hy, 0.5, 0.5), sk[1])
    # --- Kopf
    head_front(c, L, pose, k, blink, dy)
    # --- winkender Arm vor dem Haar
    if wave:
        up = 0.0 if k == 0 else 0.33
        hand = (cx + 3.0 + up * 0.4, 3.0 + dy - up)
        c.put(c.cap((cx + 2.0, 6.65 + dy), (hand[0] - 0.1, hand[1] + 0.9), aw + 0.04), tp[2])
        c.put(c.cap((cx + 2.0, 6.65 + dy), (cx + 2.55, 5.0 + dy), aw + 0.04), tp[1])
        c.put(c.ell(hand[0], hand[1], 0.62, 0.66), sk[0])
        if "bracelet" in acc:
            pass
    return finish(c)


def head_front(c, L, pose, k, blink, dy):
    n = c.n
    tu = c.t / n
    X, Y = c.X, c.Y - dy
    U = X - 4.0
    A = np.abs(U)
    sk, hr = L.skin, L.hair
    acc, st = L.acc, L.style
    # Haar hinten
    back = None
    top_h = 3.5
    if st in ("long", "long_side"):
        back = c.ell(4, 3.5, 2.85, 2.65) | c.ell(4 - 2.15, 5.4, 0.8, 1.95) | c.ell(4 + 2.15, 5.4, 0.8, 1.95)
        if st == "long_side":
            back = c.ell(4, 3.5, 2.85, 2.65) | c.ell(4 - 2.2, 5.6, 0.8, 2.2) | c.ell(4 + 2.2, 5.6, 0.8, 2.2)
    elif st == "bob":
        back = c.ell(4, 3.5, 2.85, 2.65) | (c.rect(1.15, 3.5, 2.8, 6.3) | c.rect(5.2, 3.5, 6.85, 6.3)) & ((((A - 2.0) / 0.85) ** 2 + ((Y - 5.0) / 1.45) ** 2) <= 1.0)
    elif st == "ponytail":
        back = c.ell(4, 3.5, 2.6, 2.45) | c.ell(4 - 2.15, 4.7, 0.7, 1.2) | c.ell(4 + 2.15, 4.7, 0.7, 1.2)
        back |= c.ell(6.4, 2.4, 0.95, 0.95) | c.cap((6.5, 2.8), (6.9, 5.2), 0.55)
    elif st in ("bun", "bun_curly"):
        back = c.ell(4, 3.65, 2.5, 2.4) | c.ell(4 - 2.1, 4.9, 0.6, 1.0) | c.ell(4 + 2.1, 4.9, 0.6, 1.0) | c.ell(4, 0.95, 1.0, 0.75)
        if st == "bun_curly":
            for ux in (-2.2, -0.75, 0.75, 2.2):
                back |= c.ell(4 + ux, 2.0, 0.55, 0.5)
    elif st == "short":
        back = c.ell(4, 3.5, 2.5, 2.3) | c.ell(4 - 2.15, 4.4, 0.55, 0.9) | c.ell(4 + 2.15, 4.4, 0.55, 0.9)
    elif st == "messy":
        back = c.ell(4, 3.55, 2.6, 2.3) | c.ell(4 - 2.15, 4.5, 0.55, 0.9) | c.ell(4 + 2.15, 4.5, 0.55, 0.9)
        for bx, by in ((2.55, 1.2), (3.55, 0.85), (4.7, 0.85), (5.6, 1.25)):
            back |= c.ell(bx, by, 0.55, 0.55)
    elif st == "side":
        back = c.ell(4, 3.5, 2.55, 2.3) | c.ell(4 - 2.15, 4.4, 0.5, 0.8) | c.ell(4 + 2.15, 4.4, 0.5, 0.8)
    elif st == "buzz":
        back = c.ell(4, 3.55, 2.4, 2.1)
    elif st == "bald":
        back = c.ell(4 - 2.1, 4.8, 0.5, 0.85) | c.ell(4 + 2.1, 4.8, 0.5, 0.85)
    elif st == "cap":
        back = c.ell(4, 3.6, 2.6, 2.3) & (Y > 3.4) & (A > 1.8)
        back |= c.ell(4 - 2.2, 4.8, 0.55, 0.9) | c.ell(4 + 2.2, 4.8, 0.55, 0.9)
    elif st == "flatcap":
        back = c.ell(4 - 2.2, 4.6, 0.6, 1.0) | c.ell(4 + 2.2, 4.6, 0.6, 1.0)
    if back is not None:
        tone_h = np.clip(0.5 * (U + 2.8) / 5.6 + 0.5 * (Y - 0.8) / 6.0, 0, 1)
        if st == "bald":
            tone_h = np.full_like(tone_h, 0.5)
        ramp_put(c, back, hr, tone_h)
    # Gesicht
    face = c.ell(4, 4.55, 1.95, 1.85)
    skin_tone = L.skin
    c.put(face, skin_tone[1])
    c.put(face & (X > 4.6) & (Y > 5.2), skin_tone[2])
    if st == "bald":
        c.put(c.ell(4, 3.2, 2.0, 2.0) & (Y < 3.0), skin_tone[1])
        c.put(c.ell(4, 3.2, 2.0, 2.0) & (Y < 3.0) & (U > 0.4), skin_tone[2])
        c.put(c.box(3.0, 1.9, c.px(0.5), max(1, int(0.34 * n))), skin_tone[0])
    # Pony / Mütze
    fr = None
    if st in ("long", "bob"):
        fr = face & (Y < 3.7 + 0.25 * A)
    elif st == "long_side":
        fr = face & (Y < 3.1 + 0.55 * np.clip(U + 1.3, 0, 2.5))
    elif st == "ponytail":
        fr = face & (Y < 3.55 + 0.2 * A)
    elif st in ("bun", "bun_curly"):
        fr = face & (Y < 3.4 + 0.15 * A)
    elif st == "short":
        fr = face & (Y < 3.3 + 0.55 * np.clip(U + 0.2, 0, 2.5)) | (face & (Y < 3.0))
    elif st == "messy":
        fr = face & (Y < 3.25 + 0.35 * np.abs(U + 0.5))
    elif st == "side":
        fr = face & (Y < 3.35 + 0.5 * np.clip(U + 1.5, 0, 2.5))
    elif st == "buzz":
        fr = face & (Y < 3.25 + 0.1 * A)
    if fr is not None:
        c.put(fr, hr[2])
        if st in ("long", "bob", "long_side", "ponytail"):
            c.put(fr & (Y < 3.1) & (U < -0.3), hr[1])
        if st == "side":
            c.put(c.rect(1.9, 3.5, 2.5, 5.0) & face, hr[0])                                 # graue Schläfen
    if st == "cap":
        capc = L.cap
        dome = c.ell(4, 3.3, 2.6, 2.1) & (Y < 3.75)
        tone_c = np.clip(0.55 * (U + 2.6) / 5.2 + 0.45 * (Y - 1.2) / 2.5, 0, 1)
        ramp_put(c, dome, capc, tone_c)
        brim = c.rect(1.75, 3.65, 6.25, 3.65 + max(0.55, tu * 1.5)) & ((((X - 4) / 2.6) ** 2) <= 1.0)
        c.put(brim, capc[2])
        c.put(brim & (Y < 3.65 + max(tu, 0.3)), capc[0])
        c.put(dome & (Y > 1.6) & (Y < 1.6 + max(tu, 0.3)) & (U < 0.5), capc[0])
        c.put(c.rect(1.6, 3.65, 6.4, 3.95) & face & False, capc[2])
    elif st == "flatcap":
        capc = L.cap
        topc = c.ell(4, 2.9, 2.55, 1.35) & (Y < 3.25)
        tone_c = np.clip(0.55 * (U + 2.6) / 5.2 + 0.45 * (Y - 1.5) / 1.8, 0, 1)
        ramp_put(c, topc, capc, tone_c)
        c.put(c.rect(1.5, 3.2, 6.5, 3.2 + max(0.35, tu * 1.1)) & ((((X - 4) / 2.55) ** 2) <= 1.0), capc[2])
        c.put(c.rect(1.75, 1.75, 5.2, 1.75 + max(tu, 0.3)) & topc, capc[0])
    if st == "bun_curly":
        for ux in (-2.2, -0.75, 0.75, 2.2):
            pass
    if st in ("long", "long_side", "ponytail", "bun", "bun_curly", "bob", "short", "messy") and n >= 5:
        c.put(back & (A > 1.2) & (A < 1.5) & (Y > 2.0) & (Y < 4.2) & (U < 0), hr[0])         # Strähne im Licht
    # Ohren (nur bei kurzem Haar sichtbar)
    # Augen
    ex = 0.82
    ew = 1 if n < 4 else 2
    eh = max(1, int(round(0.62 * n)))
    ey = 4.15 + dy
    sun = "sunglasses" in acc
    if sun:
        gl = c.rect(4 - 1.65, 4.05 + dy, 4 + 1.65, 4.05 + dy + max(0.5, 0.55)) & face
        c.put(gl, hexc("#1a1a2a"))
        for s in (-1, 1):
            c.put(c.box(4 + s * 1.05, 4.05 + dy, 1, 1), hexc("#8a8ab0"))
    elif blink:
        for s in (-1, 1):
            c.put(c.box(4 + s * ex - ew / (2.0 * n), ey + 0.3, ew, 1), OL)
    else:
        for s in (-1, 1):
            e = c.box(4 + s * ex - ew / (2.0 * n), ey, ew, eh)
            c.put(e, INK)
            if n >= 4:
                c.put(c.box(4 + s * ex - ew / (2.0 * n), ey, 1, 1), GLINT)
    if "glasses" in acc or "glasses_big" in acc:
        big = "glasses_big" in acc
        g = hexc("#2a2a3a") if big else hexc("#dfe4ff")
        lens = hexc("#bfe6ff")
        for s in (-1, 1):
            cxl = 4 + s * 0.92
            ring = c.rect(cxl - 0.62, ey - 0.3, cxl + 0.62, ey + 0.95)
            inner = c.rect(cxl - 0.62 + max(tu, 0.17), ey - 0.3 + max(tu, 0.17), cxl + 0.62 - max(tu, 0.17), ey + 0.95 - max(tu, 0.17))
            c.put(ring & ~inner, g)
            if big:
                c.put(inner, lens)
                if not blink:
                    c.put(c.box(4 + s * ex - ew / (2.0 * n), ey, ew, eh), INK)
        c.put(c.rect(3.7, ey, 4.3, ey + max(tu, 0.3)), g)
    # Wangen, Sommersprossen
    if n >= 3:
        cs = max(1, int(round(0.4 * n)))
        for s in (-1, 1):
            c.put(c.box(4 + s * 1.45 - cs / (2.0 * n), 5.0 + dy, cs, max(1, cs - 1)) & face, L.blush)
    if "freckles" in acc and n >= 3:
        for ux in (-1.15, -0.8, 0.8, 1.15):
            c.put(c.box(4 + ux, 4.75 + dy, 1, 1), hexc("#d08860"))
    # Mund / Bart / Schnurrbart
    mw = max(2, int(round(0.7 * n)) // 2 * 2)
    open_m = pose == "wave"
    my = 5.45 + dy
    r0 = int(round(my * n * IH / H))
    if "beard" in acc:
        bd = (face & (Y > 4.95)) | c.ell(4, 5.5, 1.95, 1.2) & (Y > 4.8)
        c.put(bd & (A < 2.05) & ~((A < 0.9) & (Y < 5.25)), hr[2])
        c.put(c.ell(4, 5.5, 1.95, 1.2) & (Y > 5.0) & (U < -0.3), hr[1]) if False else None
        mm = c.box(4 - 0.45, 5.45 + dy, c.px(0.9), max(1, int(0.34 * n) if open_m else 1))
        c.put(mm & face, hexc("#7a2a3a") if open_m else hexc("#c86a5a"))
    elif "mustache" in acc or "mustache_white" in acc:
        mc = hexc("#e8e8f0") if "mustache_white" in acc else lit(hr[2], 1.0)
        c.put(c.rect(4 - 1.0, 4.95 + dy, 4 + 1.0, 4.95 + dy + max(tu, 0.3)) & face, mc)
        c.put(c.box(4 - 1.0, 4.95 + dy, 1, 2) & face, mc)
        c.put(c.box(4 + 1.0 - 1.0 / n, 4.95 + dy, 1, 2) & face, mc)
        if open_m:
            c.put(c.box(4 - 0.3, 5.45 + dy, c.px(0.6), max(1, int(0.34 * n))) & face, hexc("#7a2a3a"))
    else:
        mouth = np.zeros((c.h, c.w), bool)
        mh = max(1, int(round(0.34 * n)) if open_m else 1)
        mouth[r0:r0 + mh, c.w // 2 - mw // 2:c.w // 2 + mw // 2] = True
        c.put(mouth & face, MOUTH if open_m else lit(sk[2], 0.7))
        if n >= 3 and not open_m:
            for cc in (c.w // 2 - mw // 2 - 1, c.w // 2 + mw // 2):
                if 0 <= r0 - 1 < c.h and face[r0 - 1, cc]:
                    c.col[r0 - 1, cc] = lit(sk[2], 0.7)
    # Zubehör am Kopf
    if "clip" in acc:
        cw = max(2, int(round(0.62 * n)))
        clip = c.box(2.45 - cw / n, 1.45 + dy, cw, max(2, int(round(0.62 * n))))
        c.put(clip & back, hexc("#ffd23a"))
        if n >= 3:
            c.put(c.box(2.45 - cw / n, 1.45 + dy, 1, 1) & back, hexc("#fff1a0"))
    if "headphones" in acc:
        band = (np.abs(((X - 4) / 2.75) ** 2 + ((Y - 3.3) / 2.5) ** 2 - 1.0) < 0.17) & (Y < 3.6)
        c.put(band, hexc("#1a1a2a"))
        for s in (-1, 1):
            c.put(c.rect(4 + s * 2.55 - 0.45, 3.9, 4 + s * 2.55 + 0.45, 5.0), hexc("#2ad0e0"))
            c.put(c.rect(4 + s * 2.55 - 0.45, 3.9, 4 + s * 2.55 + 0.45, 3.9 + max(tu, 0.3)), hexc("#9af0f8"))
    if "antenna" in acc:
        for s in (-1, 1):
            c.put(c.cap((4 + s * 0.8, 1.1), (4 + s * 1.8, 0.45), 0.1 + tu * 0.3), hexc("#22223d"))
            c.put(c.ell(4 + s * 1.95, 0.5, 0.42, 0.4), hexc("#b6ff6a"))
            c.put(c.box(4 + s * 1.95 - 0.3, 0.2, 1, 1), hexc("#f0ffd0"))
    if st == "ponytail":
        c.put(c.ell(6.0, 2.0, 0.28, 0.28), hexc("#ff6aa0"))


# ----------------------------------------------------------------------------------------------------------------------------------
# Seitenansicht (Laufen nach rechts)
# ----------------------------------------------------------------------------------------------------------------------------------
def ik(hip, foot, l1, l2):
    hx, hy = hip
    fx, fy = foot
    dx, dy = fx - hx, fy - hy
    dist = min(math.hypot(dx, dy), l1 + l2 - 0.01)
    a = math.atan2(dy, dx)
    cc = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    b = math.acos(max(-1, min(1, cc)))
    ang = a - b
    return (hx + math.cos(ang) * l1, hy + math.sin(ang) * l1)


def side(n, L, k):
    c = Cv(n)
    tu = c.t / n
    F, acc = L.F, L.acc
    X, Y = c.X, c.Y
    sk, tp = L.skin, L.top
    ph = k / 6.0 * 2 * math.pi
    old = L.old
    bob = (1.0 / 3.0 if k in (1, 4) else 0.0) + L.hy
    lean = 0.33 if F.get("height", 0) < 0 else 0.0
    stride = 1.07 if old else 1.5
    hip = (3.85, 8.35 + bob - L.hy)
    skirted = L.dress or L.skirt is not None

    def foot(p):
        return (3.85 + math.cos(p) * stride, 11.5 - max(0.0, math.sin(p)) * (0.5 if old else 0.85))

    legc = sk[2] if skirted else L.legs
    legs = [(foot(ph + math.pi), lit(legc, 0.8) if not skirted else sk[3]), (foot(ph), legc)]
    arm_sw = math.cos(ph) * (0.6 if old else 1.0)
    sh_ = (3.85 + lean, 6.15 + bob)
    carry = "suitcase" in acc or "briefcase" in acc

    def arm_pts(sw):
        el = (sh_[0] - sw * 0.5, sh_[1] + 1.5)
        hd = (sh_[0] - sw, sh_[1] + 2.85)
        return el, hd

    def draw_arm(sw, col, hand):
        el, hd = arm_pts(sw)
        c.put(c.cap(sh_, el, 0.5), col)
        c.put(c.cap(el, hd, 0.48), col)
        c.put(c.ell(hd[0], hd[1] + 0.1, 0.47, 0.5), hand)
        return hd

    # hinterer Arm und Zubehör
    if carry:
        hd = draw_arm(1.4 + math.cos(ph) * 0.2, tp[3], sk[3])
        hx, hy = hd
        if "suitcase" in acc:
            c.put(c.rect(hx - 1.4, hy + 0.7, hx + 0.4, hy + 3.0), hexc("#6a3e22"))
            c.put(c.rect(hx - 1.4, hy + 0.7, hx + 0.4, hy + 0.7 + max(tu, 0.3)), hexc("#94602f"))
            c.put(c.rect(hx - 1.4, hy + 1.75, hx + 0.4, hy + 1.75 + max(tu, 0.3)), hexc("#b08a50"))
        else:
            c.put(c.rect(hx - 1.4, hy + 0.7, hx + 0.4, hy + 2.2), hexc("#1e1e2a"))
            c.put(c.rect(hx - 1.4, hy + 0.7, hx + 0.4, hy + 0.7 + max(tu, 0.3)), hexc("#4a4a60"))
    else:
        draw_arm(-arm_sw, tp[3], sk[3])
    # Beine
    for i, (ft, col) in enumerate(legs):
        kn = ik(hip, ft, 1.67, 1.73)
        c.put(c.cap(hip, kn, 0.48), col)
        c.put(c.cap(kn, (ft[0], ft[1] - 0.3), 0.45), col)
        shoe = c.cap((ft[0] - 0.3, ft[1] - 0.05), (ft[0] + 0.65, ft[1] - 0.05), 0.48) & (Y > ft[1] - 0.55)
        c.put(shoe, SHOE)
        if i == 1:
            c.put(shoe & (Y < ft[1] - 0.2), SHOE_H)
    # Rumpf
    bw = 1.7 + max(L.wd, 0.0)
    cxb = 3.9 + lean
    if L.dress:
        hem = 10.2
        half = 1.75 + (np.clip(Y - bob, 5.95, hem) - 5.95) / (hem - 5.95) * 0.7
        body = (np.abs(X - cxb) <= half) & (Y - bob >= 5.95) & (Y - bob < hem)
        tt = np.clip((Y - bob - 5.95) / (hem - 5.95), 0, 1)
        tone = np.clip(0.55 * (X - (cxb - half)) / (2 * half) + 0.35 * tt + (tt > 0.88) * 0.25, 0, 1)
        ramp_put(c, body, tp, tone)
        torso = body
    else:
        body = (((np.abs(X - cxb)) / bw) ** 4 + ((Y - bob - 7.55) / 1.6) ** 4) <= 1.0
        body &= Y - bob >= 5.95
        tt = np.clip((Y - bob - 5.95) / 3.2, 0, 1)
        tone = np.clip(0.55 * (X - (cxb - bw)) / (2 * bw) + 0.3 * tt, 0, 1)
        ramp_put(c, body, tp, tone)
        torso = body
        if L.skirt is not None:
            long = F.get("height", 0) < 0
            sy1 = 10.65 if long else 10.0
            skhalf = 1.7 + (np.clip(Y - bob, 8.2, sy1) - 8.2) / (sy1 - 8.2) * 0.7
            skm = (np.abs(X - cxb) <= skhalf) & (Y - bob >= 8.2) & (Y - bob < sy1)
            sramp = ramp4(L.skirt)
            ramp_put(c, skm, sramp, np.clip(0.5 * (X - (cxb - skhalf)) / (2 * skhalf) + 0.3 * (Y - bob - 8.2) / (sy1 - 8.2), 0, 1))
            c.put(skm & (Y - bob >= sy1 - max(tu, 0.3)), sramp[3])
            torso = torso | skm
    if L.inner is not None and not L.dress:
        c.put(torso & (X > cxb + bw - 0.8) & (Y - bob < 8.7), L.inner)
    if "tie" in acc:
        c.put(torso & (X > cxb + bw - 0.55) & (X < cxb + bw - 0.15) & (Y - bob < 8.0) & (Y - bob > 6.0), hexc("#c8283a"))
    if "bowtie" in acc:
        c.put(c.rect(cxb + bw - 0.9, 6.1 + bob, cxb + bw - 0.1, 6.65 + bob) & torso, hexc("#c8283a"))
    if "flannel" in acc:
        c.put(torso & (np.abs(X - cxb) < max(0.17, tu * 0.7)), tp[3])
        c.put(torso & (np.abs(Y - bob - 7.1) < max(0.17, tu * 0.7)), tp[3])
    if "hoodie" in acc:
        c.put(torso & (np.abs(Y - bob - 8.4) < max(0.17, tu * 0.7)), tp[3])
    if "handbag" in acc:
        c.put(c.rect(cxb + bw - 0.6, 7.2 + bob, cxb + bw + 1.0, 8.7 + bob), hexc("#c84a7a"))
        c.put(c.rect(cxb + bw - 0.6, 7.2 + bob, cxb + bw + 1.0, 7.2 + bob + max(tu, 0.3)), hexc("#ff8ab0"))
        c.put(c.cap((cxb + bw - 0.4, 6.1 + bob), (cxb + bw - 0.5, 7.2 + bob), 0.09), hexc("#8a3a5a"))
    # Kopf im Profil
    head_side(c, L, k, bob, lean)
    # vorderer Arm
    hd = draw_arm(arm_sw, tp[2], sk[1])
    if "cane" in acc:
        hx, hy = hd
        c.put(c.rect(hx + 0.3, hy, hx + 0.3 + max(0.3, tu), 11.7), hexc("#6a4a2a"))
        c.put(c.rect(hx - 0.35, hy - 0.1, hx + 0.3 + max(0.3, tu), hy + max(0.3, tu)), hexc("#8a6a3a"))
        c.put(c.ell(hx, hy + 0.1, 0.47, 0.5), sk[1])
    return finish(c)


def head_side(c, L, k, bob, lean):
    n = c.n
    tu = c.t / n
    X, Y = c.X, c.Y
    sk, hr = L.skin, L.hair
    acc, st = L.acc, L.style
    hx = lean
    head = c.ell(4.5 + hx, 4.3 + bob, 1.8, 1.9)
    c.put(head, sk[1])
    crescent = head & ~c.ell(4.3 + hx, 3.9 + bob, 1.65, 1.6) & (X > 4.4 + hx) & (Y > 4.5 + bob)
    c.put(crescent, sk[2])
    nose = c.ell(6.25 + hx, 4.75 + bob, 0.32, 0.3) if n >= 3 else c.box(6.1 + hx, 4.7 + bob, 1, 1)
    c.put(nose, sk[1])
    Yb = Y - bob
    Xh = X - hx
    line = 3.0 + 0.3 * np.maximum(Xh - 4.4, 0)
    tone_h = np.clip(0.4 * (Xh - 1.5) / 4.0 + 0.6 * (Yb - 1.5) / 5.8, 0, 1)
    hair = None
    fringe = head & (Yb < line) & (Xh > 3.2)
    if st in ("long", "long_side"):
        cap_ = c.ell(4.15 + hx, 3.55 + bob, 2.15, 2.15)
        hair = (cap_ & ((Xh < 4.5) | (Yb < line))) | (c.ell(3.0 + hx, 4.6 + bob, 1.0, 1.9) & (Xh < 3.9)) | c.ell(2.95 + hx, 6.1 + bob, 0.95, 1.2)
        if st == "long_side":
            hair |= c.ell(2.95 + hx, 6.8 + bob, 0.95, 1.4)
    elif st == "bob":
        cap_ = c.ell(4.15 + hx, 3.55 + bob, 2.15, 2.15)
        hair = (cap_ & ((Xh < 4.5) | (Yb < line))) | (c.ell(3.0 + hx, 4.7 + bob, 1.05, 1.5) & (Xh < 4.0))
    elif st == "ponytail":
        cap_ = c.ell(4.1 + hx, 3.5 + bob, 2.0, 2.0)
        sw = 0.3 * math.sin(k / 6.0 * 2 * math.pi)
        hair = (cap_ & ((Xh < 4.4) | (Yb < line))) | c.cap((2.7 + hx, 2.7 + bob), (1.6 + hx, 4.6 + bob + sw), 0.55) | c.ell(2.6 + hx, 2.6 + bob, 0.8, 0.8)
    elif st in ("bun", "bun_curly"):
        cap_ = c.ell(4.15 + hx, 3.6 + bob, 2.1, 2.1)
        hair = (cap_ & ((Xh < 4.5) | (Yb < line))) | (c.ell(3.1 + hx, 4.6 + bob, 0.8, 1.1) & (Xh < 3.9)) | c.ell(3.0 + hx, 1.5 + bob, 0.95, 0.85)
    elif st == "short":
        cap_ = c.ell(4.15 + hx, 3.5 + bob, 2.1, 2.0)
        hair = (cap_ & ((Xh < 4.5) | (Yb < line))) | (c.ell(3.2 + hx, 4.5 + bob, 0.85, 1.0) & (Xh < 3.9))
    elif st == "messy":
        cap_ = c.ell(4.15 + hx, 3.5 + bob, 2.15, 2.05)
        hair = (cap_ & ((Xh < 4.5) | (Yb < line))) | (c.ell(3.2 + hx, 4.5 + bob, 0.85, 1.0) & (Xh < 3.9))
        for bx, by in ((3.0, 1.3), (4.1, 1.0), (5.2, 1.3)):
            hair |= c.ell(bx + hx, by + bob, 0.55, 0.55)
    elif st == "side":
        cap_ = c.ell(4.15 + hx, 3.5 + bob, 2.1, 2.0)
        hair = (cap_ & ((Xh < 4.4) | (Yb < line))) | (c.ell(3.3 + hx, 4.3 + bob, 0.7, 0.8) & (Xh < 3.9))
    elif st == "buzz":
        cap_ = c.ell(4.15 + hx, 3.5 + bob, 2.0, 1.85)
        hair = cap_ & ((Xh < 4.3) | (Yb < line - 0.2))
    elif st == "bald":
        hair = c.ell(3.4 + hx, 4.7 + bob, 0.6, 0.9) & (Xh < 4.0)
    if hair is not None:
        ramp_put(c, hair | (fringe if st not in ("bald", "buzz", "cap", "flatcap") else np.zeros_like(fringe)), hr, tone_h)
        if st in ("long", "long_side", "bob", "ponytail"):
            c.put(fringe & (Yb > line - 0.5) & (Xh > 4.4), hr[2])
    if st == "cap":
        capc = L.cap
        dome = c.ell(4.1 + hx, 3.4 + bob, 2.3, 2.1) & (Yb < 3.75)
        ramp_put(c, dome, capc, np.clip(0.55 * (Xh - 1.8) / 4.6 + 0.45 * (Yb - 1.3) / 2.5, 0, 1))
        brim = c.rect(4.0 + hx, 3.65 + bob, 7.0 + hx, 3.65 + bob + max(0.5, tu * 1.4))
        c.put(brim, capc[2])
        c.put(brim & (Y < 3.65 + bob + max(tu, 0.3)), capc[0])
        c.put(c.ell(3.1 + hx, 4.7 + bob, 0.65, 0.9) & (Xh < 3.9), hr[2])
    elif st == "flatcap":
        capc = L.cap
        topc = c.ell(4.0 + hx, 2.9 + bob, 2.4, 1.3) & (Yb < 3.2)
        ramp_put(c, topc, capc, np.clip(0.55 * (Xh - 1.6) / 4.8 + 0.45 * (Yb - 1.6) / 1.7, 0, 1))
        c.put(c.rect(3.6 + hx, 3.15 + bob, 6.9 + hx, 3.15 + bob + max(0.35, tu * 1.1)), capc[2])
        c.put(c.ell(3.1 + hx, 4.6 + bob, 0.65, 0.95) & (Xh < 3.9), hr[2])
    if st == "bald":
        c.put(c.box(4.0 + hx, 1.95 + bob, c.px(0.5), max(1, int(0.34 * n))), sk[0])
    if n >= 4 and st in ("short", "messy", "buzz", "bald", "side", "cap", "flatcap"):
        c.put(c.box(3.95 + hx, 4.55 + bob, max(1, n // 3), max(1, n // 3)), sk[2])               # Ohr
    # Auge, Brille, Wange, Mund
    ex, ey = 5.15 + hx, 4.0 + bob
    ew = 1 if n < 4 else 2
    eh = max(1, int(round(0.62 * n)))
    if "sunglasses" in acc:
        c.put(c.rect(ex - 1.4, ey, ex + 0.9, ey + 0.55), hexc("#1a1a2a"))
    else:
        c.put(c.box(ex, ey, ew, eh), INK)
        if n >= 4:
            c.put(c.box(ex, ey, 1, 1), GLINT)
    if "glasses" in acc or "glasses_big" in acc:
        big = "glasses_big" in acc
        g = hexc("#2a2a3a") if big else hexc("#dfe4ff")
        ring = c.rect(ex - 0.35, ey - 0.3, ex + 1.0, ey + 1.0)
        inner = c.rect(ex - 0.35 + max(tu, 0.17), ey - 0.3 + max(tu, 0.17), ex + 1.0 - max(tu, 0.17), ey + 1.0 - max(tu, 0.17))
        c.put(ring & ~inner, g)
        if big:
            c.put(inner, hexc("#bfe6ff"))
            c.put(c.box(ex, ey, ew, eh), INK)
        c.put(c.rect(3.7 + hx, ey, ex - 0.3, ey + max(tu, 0.3)), g)
    if n >= 3:
        cs = max(1, int(round(0.4 * n)))
        c.put(c.box(4.6 + hx, 4.85 + bob, cs, max(1, cs - 1)), L.blush)
    if "freckles" in acc and n >= 3:
        c.put(c.box(4.95 + hx, 4.75 + bob, 1, 1), hexc("#d08860"))
    if "beard" in acc:
        c.put(head & (Yb > 4.95) & (Xh > 3.6), hr[2])
        c.put(c.ell(5.0 + hx, 5.6 + bob, 1.2, 0.9) & (Xh > 3.7), hr[2])
    elif "mustache" in acc or "mustache_white" in acc:
        mc = hexc("#e8e8f0") if "mustache_white" in acc else hr[2]
        c.put(c.rect(5.0 + hx, 4.95 + bob, 6.55 + hx, 4.95 + bob + max(tu * 1.3, 0.3)), mc)
    else:
        c.put(c.box(5.4 + hx, 5.45 + bob, max(1, int(round(0.45 * n))), 1), lit(sk[2], 0.7))
    # Zubehör am Kopf
    if "clip" in acc:
        cw = max(2, int(round(0.62 * n)))
        c.put(c.box(4.75 + hx, 1.55 + bob, cw, cw) & hair if hair is not None else np.zeros_like(c.on), hexc("#ffd23a"))
        if n >= 3 and hair is not None:
            c.put(c.box(4.75 + hx, 1.55 + bob, 1, 1) & hair, hexc("#fff1a0"))
    if "headphones" in acc:
        c.put(c.rect(3.6 + hx, 3.6 + bob, 4.5 + hx, 4.85 + bob), hexc("#2ad0e0"))
        c.put(c.rect(3.6 + hx, 3.6 + bob, 4.5 + hx, 3.6 + bob + max(tu, 0.3)), hexc("#9af0f8"))
        c.put(c.cap((4.05 + hx, 1.4 + bob), (4.05 + hx, 3.6 + bob), max(0.1, tu * 0.4)), hexc("#1a1a2a"))
    if "antenna" in acc:
        for ux, tx in ((3.8, 2.8), (4.9, 6.0)):
            c.put(c.cap((ux + hx, 1.45 + bob), (tx + hx, 0.5 + bob), max(0.1, tu * 0.4)), hexc("#22223d"))
            c.put(c.ell(tx + hx, 0.55 + bob, 0.42, 0.4), hexc("#b6ff6a"))
    if st == "ponytail":
        c.put(c.ell(2.75 + hx, 2.55 + bob, 0.28, 0.28), hexc("#ff6aa0"))


def finish(c):
    ring = grow(c.on, c.t) & ~c.on
    c.col[ring] = OL
    alpha = c.on | ring
    a = np.zeros((c.h, c.w, 4), np.uint8)
    a[..., :3] = np.clip(np.round(c.col), 0, 255).astype(np.uint8)
    a[..., 3] = np.where(alpha, 255, 0)
    a[~alpha] = 0
    return Image.fromarray(a)


FRAMES = [("idle", 0), ("idle", 1), ("wave", 0), ("wave", 1)] + [("walk", k) for k in range(6)]


def render(n, vid, frame):
    L = Look(FIG[vid])
    pose, k = FRAMES[frame]
    return side(n, L, k) if pose == "walk" else front(n, L, pose, k)


def main():
    os.makedirs(OUT, exist_ok=True)
    old = Image.open("assets/art/passengers.png").convert("RGBA")
    sheets = {}
    for n in SIZES:
        sh = Image.new("RGBA", (10 * IW * n, IH * n * len(ORDER)), (0, 0, 0, 0))
        for r, vid in enumerate(ORDER):
            for j in range(10):
                sh.paste(render(n, vid, j), (j * IW * n, r * IH * n))
        sheets[n] = sh
    stack(sheets).save(OUT + "figuren_sizes.png")
    if "--install" in sys.argv:
        stack(sheets).save("assets/art/passengers_sizes.png")
    k = 4
    for r, vid in enumerate(ORDER):                                   # je Figur: alle Größen untereinander, alle 10 Bilder
        rows = [sheets[n].crop((0, r * IH * n, 10 * IW * n, (r + 1) * IH * n)) for n in SIZES]
        im = Image.new("RGBA", (70 * 6 * k + 20, sum(x.height * k + 8 for x in rows) + 8), (48, 52, 90, 255))
        y = 8
        for x in rows:
            im.alpha_composite(x.resize((x.width * k, x.height * k), Image.NEAREST), (10, y))
            y += x.height * k + 8
        im.save(OUT + "fig_%s_neu.png" % vid)
    # Vergleich alt | neu: Größe 4 und 5 (ungleichmäßig gestreckt im Spiel heute), Frames 0, 2, 4, 7
    for n in (4, 5):
        sel = (0, 2, 4, 7)
        cw, ch = IW * n * 3, IH * n * 3
        im = Image.new("RGBA", (len(ORDER) * 0 + len(sel) * 2 * cw // 1 + 20, len(ORDER) * (ch + 6) + 10), (48, 52, 90, 255))
        for r, vid in enumerate(ORDER):
            for i, f in enumerate(sel):
                alt = old.crop((f * 24, r * 36, f * 24 + 24, r * 36 + 36)).resize((IW * n, IH * n), Image.NEAREST)
                new = sheets[n].crop((f * IW * n, r * IH * n, (f + 1) * IW * n, (r + 1) * IH * n))
                im.alpha_composite(alt.resize((alt.width * 3, alt.height * 3), Image.NEAREST), (10 + i * 2 * cw, 5 + r * (ch + 6)))
                im.alpha_composite(new.resize((new.width * 3, new.height * 3), Image.NEAREST), (10 + i * 2 * cw + cw, 5 + r * (ch + 6)))
        im.save(OUT + "vergleich_alt_neu_n%d.png" % n)
    # alle Figuren, Stehen und Laufen, Größe 6 vergrößert
    big = Image.new("RGBA", (len(ORDER) * (IW * 6 * 3 + 6) + 6, 2 * (IH * 6 * 3 + 6) + 6), (48, 52, 90, 255))
    for r, vid in enumerate(ORDER):
        for q, f in enumerate((0, 4)):
            new = sheets[6].crop((f * IW * 6, r * IH * 6, (f + 1) * IW * 6, (r + 1) * IH * 6))
            big.alpha_composite(new.resize((new.width * 3, new.height * 3), Image.NEAREST), (6 + r * (IW * 6 * 3 + 6), 6 + q * (IH * 6 * 3 + 6)))
    big.save(OUT + "alle_figuren_n6.png")
    print("Figuren (Entwurf) nach", OUT)


if __name__ == "__main__":
    main()
