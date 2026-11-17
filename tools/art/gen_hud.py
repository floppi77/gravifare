"""Instrumente des HUD (Runde 73): Gehäuse und Symbole der Tank- und der Hüllenanzeige, je Pixelgröße eigens gerastert.

Jede Anzeige ist 68 × 12 Einheiten groß: links die Kappe mit dem Symbol (Zapfsäule bzw. Schild), rechts das Sichtfenster (50 × 6 Einheiten ab
x = 15, y = 3). Die Füllung selbst zeichnet das Spiel (src/game/hud_gauges.gd), weil ihre Farbe vom Zustand abhängt; dieses Blatt liefert, was
fest ist:

  Reihe 0  Tank, hinten:   Gehäuse, Kappe, leeres Fenster, darunter Teilstriche (25/50/75 %) und die rote Reservemarke (letzte 10 %)
  Reihe 1  Tank, vorn:     Messstriche und Glanz über der Füllung
  Reihe 2  Hülle, hinten:  Gehäuse, Kappe, leeres Fenster, darunter die Marke des kritischen Bereichs (bis 35 %)
  Reihe 3  Hülle, vorn:    schräge Fugen, die die Füllung in zehn Panzerplatten teilen
  Reihe 4  Symbole:        Zapfsäule (x 0–12) und Schild (x 12–24), weiß mit Graustufen – das Spiel färbt sie in der Zustandsfarbe

Ein Block ist damit 68 × 60 Einheiten groß. `assets/art/hud_gauges_sizes.png` legt die Blöcke der Größen 2, 3, 4, 5, 6 untereinander
(Blattformat wie beim Taxi, siehe src/core/pixel_scale.gd). Formen stehen in Einheiten und werden je Bildpunkt an dessen Mitte entschieden;
Kontur, Fugen und Teilstriche haben je Größe eine feste Zahl Bildpunkte (1 bis 1440p, darüber 2).

Aufruf aus der Projektwurzel:  python3 tools/art/gen_hud.py            Entwurf an anderen Ort: GF_HUD_OUT=<ordner>/ python3 tools/art/gen_hud.py
Kein Zufall, die Ausgabe ist bitgleich. Eigene Arbeit, keine Fremdassets."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from sizekit import SIZES, stack

OUT = os.environ.get("GF_HUD_OUT", "assets/art/")
W, H = 68, 12                        # eine Anzeige in Einheiten
ROWS = 5
CAP = 12.0                           # Breite der Kappe mit dem Symbol
WIN = (15.0, 3.0, 65.0, 9.0)         # Sichtfenster: x0, y0, x1, y1  (muss zu hud_gauges.gd passen)
PLATES = 10                          # Panzerplatten der Hüllenanzeige
SLANT = 2.0                          # Schräge der Plattenfugen in Einheiten über die Fensterhöhe
RADIUS = 2.6
FUEL_RESERVE = 0.10                  # rote Marke: letzte 10 % des Tanks
HULL_CRIT = 0.35                     # Marke des kritischen Bereichs der Hülle


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OL = hexc("#060817")
RIM_HI, RIM_LO = hexc("#5a66ad"), hexc("#262d5c")
BODY_HI, BODY, BODY_LO = hexc("#2b3468"), hexc("#1b2149"), hexc("#131835")
CAP_HI, CAP_C, CAP_LO = hexc("#3d4990"), hexc("#28306a"), hexc("#1b2150")
WELL = hexc("#04050f")
GLASS = hexc("#0a0d20")
TICK = hexc("#8f9ad6")
FUEL_MARK = hexc("#c93a3a")
HULL_MARK = hexc("#b23c96")


class Cv:
    """Zeichenfläche einer Anzeige in der Pixelgröße n. Masken entstehen aus der Lage der Bildpunktmitten in Einheiten."""

    def __init__(self, n, w=W, h=H):
        self.n, self.w, self.h = n, int(w * n), int(h * n)
        self.t = max(1, int(n / 3.0 + 0.5))
        xs = (np.arange(self.w) + 0.5) / n
        ys = (np.arange(self.h) + 0.5) / n
        self.X, self.Y = np.meshgrid(xs, ys)
        self.px = np.zeros((self.h, self.w, 4), np.uint8)

    def put(self, mask, col):
        self.px[mask] = col

    def blend(self, mask, col):
        """Halbdurchsichtig über Vorhandenes legen (einfaches Überblenden, auch auf leerem Grund)."""
        a = col[3] / 255.0
        dst = self.px[mask].astype(float)
        da = dst[:, 3:4] / 255.0
        oa = a + da * (1.0 - a)
        rgb = (np.array(col[:3], float) * a + dst[:, :3] * da * (1.0 - a)) / np.maximum(oa, 1e-6)
        self.px[mask] = np.concatenate([np.round(rgb), np.round(oa * 255.0)], axis=1).astype(np.uint8)

    def rect(self, x0, y0, x1, y1):
        return (self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1)

    def cols(self, x, count):
        """Senkrechter Streifen aus `count` Bildpunktspalten ab der Spalte bei x (Einheiten)."""
        c0 = int(np.floor(x * self.n + 0.5))
        m = np.zeros((self.h, self.w), bool)
        m[:, max(c0, 0):max(c0 + count, 0)] = True
        return m

    def rows(self, y, count):
        r0 = int(np.floor(y * self.n + 0.5))
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + count, 0), :] = True
        return m

    def image(self):
        return Image.fromarray(self.px, "RGBA")


def shrink(mask, k=1):
    """Maske um k Bildpunkte abtragen (4er-Nachbarschaft)."""
    m = mask.copy()
    for _ in range(k):
        p = np.pad(m, 1, constant_values=False)
        m = p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return m


def grow(mask, k=1):
    m = mask.copy()
    for _ in range(k):
        p = np.pad(m, 1, constant_values=False)
        m = p[1:-1, 1:-1] | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return m


def housing(c):
    """Abgerundetes Gehäuse über die ganze Fläche."""
    r = RADIUS
    dx = np.maximum(np.maximum(r - c.X, c.X - (W - r)), 0.0)
    dy = np.maximum(np.maximum(r - c.Y, c.Y - (H - r)), 0.0)
    return dx * dx + dy * dy <= r * r


def window(c):
    return c.rect(*WIN)


def back(n, kind):
    """Gehäuse mit Kappe, leerem Fenster und den Marken unter dem Fenster."""
    c = Cv(n)
    t = c.t
    hs = housing(c)
    inner = shrink(hs, t)
    core = shrink(inner, t)
    cap = c.X < CAP
    # Fläche: Kappe heller als der Körper, je drei Töne von oben nach unten
    c.put(hs, OL)
    top = c.Y < 2.0
    bot = c.Y >= H - 2.0
    c.put(inner & ~cap, BODY)
    c.put(inner & ~cap & top, BODY_HI)
    c.put(inner & ~cap & bot, BODY_LO)
    c.put(inner & cap, CAP_C)
    c.put(inner & cap & (c.Y < 4.0), CAP_HI)
    c.put(inner & cap & (c.Y >= H - 3.0), CAP_LO)
    # Fase: oben und links hell, unten und rechts dunkel
    ring = inner & ~core
    up = np.zeros_like(ring)
    up[t:, :] = inner[:-t, :]
    left = np.zeros_like(ring)
    left[:, t:] = inner[:, :-t]
    c.put(ring, RIM_LO)
    c.put(ring & (~up | ~left), RIM_HI)
    # Trennfuge zwischen Kappe und Körper, rechts daneben eine helle Kante
    c.put(inner & c.cols(CAP, t), OL)
    c.put(core & c.cols(CAP + t / float(n), t), BODY_HI)
    # Fenster: dunkle Fassung, innen das leere Glas
    win = window(c)
    c.put(grow(win, t), WELL)
    c.put(win, GLASS)
    # Marken unter dem Fenster
    x0, _, x1, y1 = WIN
    span = x1 - x0
    my0 = y1 + 0.5
    mark = (c.Y >= my0) & (c.Y < my0 + 1.0)
    if kind == "fuel":
        for f in (0.25, 0.5, 0.75):
            c.put(mark & c.cols(x0 + span * f - t / (2.0 * n), t), TICK)
        c.put(mark & (c.X >= x0) & (c.X < x0 + span * FUEL_RESERVE), FUEL_MARK)
    else:
        c.put(mark & (c.X >= x0) & (c.X < x0 + span * HULL_CRIT), HULL_MARK)
        for k in range(1, PLATES):                       # kleine Niete unter jeder Plattenfuge
            if k / float(PLATES) > HULL_CRIT:
                c.put(c.rows(my0 + 0.5 - t / (2.0 * n), t) & c.cols(x0 + span * k / PLATES - t / (2.0 * n), t), TICK)
    return c.image()


def seam_col(n, k, row):
    """Linke Bildpunktspalte der k-ten Plattenfuge in der Bildpunktzeile `row` des Fensters (0 = oberste). Gleiche Rechnung wie im Spiel."""
    x0, y0, x1, y1 = WIN
    rows = int(round((y1 - y0) * n))
    lean = SLANT * (0.5 - (row + 0.5) / rows)
    return int(np.floor((x0 + (x1 - x0) * k / PLATES + lean) * n + 0.5))


def front(n, kind):
    """Was über der Füllung liegt: beim Tank Messstriche und Glanz, bei der Hülle die Plattenfugen."""
    c = Cv(n)
    t = c.t
    win = window(c)
    x0, y0, x1, y1 = WIN
    span = x1 - x0
    if kind == "fuel":
        low = c.Y >= y0 + (y1 - y0) * 0.5
        for f in (0.25, 0.5, 0.75):
            c.blend(win & low & c.cols(x0 + span * f - t / (2.0 * n), t), hexc("#04050f", 150))
        c.blend(win & c.rows(y0, t), hexc("#ffffff", 46))                        # Glaskante oben
        c.blend(win & c.rows(y1 - t / float(n), t), hexc("#000000", 70))          # Schatten am Boden
    else:
        rows = int(round((y1 - y0) * n))
        r0 = int(round(y0 * n))
        for k in range(1, PLATES):
            for r in range(rows):
                col = seam_col(n, k, r)
                c.px[r0 + r, col:col + t] = GLASS
                hl = np.zeros((c.h, c.w), bool)
                hl[r0 + r, col + t:col + t + 1] = True
                c.blend(hl & win, hexc("#ffffff", 56))
        c.blend(win & c.rows(y1 - t / float(n), t), hexc("#000000", 70))
    return c.image()


def icons(n):
    """Zapfsäule und Schild, weiß mit Graustufen (das Spiel färbt sie ein)."""
    c = Cv(n)
    t = c.t
    X, Y = c.X, c.Y
    w1, w2, w3 = hexc("#ffffff"), hexc("#c9c9c9"), hexc("#8e8e8e")
    # --- Zapfsäule (Feld 0–12): Säule mit Anzeigefenster und Sockel, rechts der dünne Schlauch mit hängender Zapfpistole
    body = c.rect(2.0, 2.5, 6.5, 9.5)
    c.put(body, w1)
    c.put(body & (X >= 5.5), w2)
    c.px[c.rect(3.0, 3.5, 5.5, 5.5)] = (0, 0, 0, 0)                               # Anzeigefenster
    c.put(c.rect(1.5, 9.5, 7.0, 10.5), w2)                                        # Sockel
    hose = c.cols(9.5 - t / float(n), t) & (Y >= 4.5) & (Y < 9.0)                 # Schlauch hoch
    hose |= c.rows(9.0 - t / float(n), t) & (X >= 6.5) & (X < 9.5)                # … unten zur Säule
    c.put(hose, w2)
    c.put(c.rect(7.5, 2.5, 10.0, 4.5) & (X + Y >= 10.5 + 0.0), w1)                # Zapfpistole, Spitze zeigt nach links unten
    c.put(c.rect(7.5, 4.5, 8.5, 5.5), w1)
    # --- Schild (Feld 12–24)
    u = X - 18.0
    hw = np.where(Y <= 6.0, 3.5, 3.5 * np.sqrt(np.clip(1.0 - ((Y - 6.0) / 4.6) ** 2, 0.0, 1.0)))
    sh = (np.abs(u) < hw) & (Y >= 2.3) & (Y < 10.6)
    c.put(sh, w1)
    c.put(sh & (u >= 0.0), w2)
    edge = sh & ~shrink(sh, t)
    c.put(edge & (u >= 0.0) & (Y > 6.0), w3)
    inner = shrink(sh, t + max(1, n // 3))
    c.put(inner & (u < 0.0), w2)                                                  # eingelassenes Feld: Hälften getauscht
    c.put(inner & (u >= 0.0), w1)
    return c.image()


def block(n):
    img = Image.new("RGBA", (W * n, H * n * ROWS), (0, 0, 0, 0))
    for i, part in enumerate([back(n, "fuel"), front(n, "fuel"), back(n, "hull"), front(n, "hull"), icons(n)]):
        img.paste(part, (0, i * H * n))
    return img


def main():
    stack({n: block(n) for n in SIZES}).save(OUT + "hud_gauges_sizes.png")
    print("hud_gauges_sizes.png", W * max(SIZES), H * ROWS * sum(SIZES))


if __name__ == "__main__":
    main()
