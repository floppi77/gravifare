"""Runde 72, Schritt 4: Leben-Symbole des HUD (kleines Taxi) in jeder Pixelgröße, aus den Formen von gen_taxi.py.

Die bisherigen life_<lack>.png (32 × 20 Punkte) zeigen noch das alte Taxi und werden im HUD auf 10,67 × 6,67 Einheiten gezeichnet (geht in keiner
Größe auf). Hier wird das neue Taxi (26 × 16 Einheiten) als Formen auf 10 × 6 Einheiten gerastert: je Größe n (2–6) 10n × 6n Bildpunkte, harte
Kanten, dieselben Farbrampen und Lackierungen wie das große Taxi, Kontur 1 Bildpunkt bis Größe 4, darüber 2, ohne Kleinteile (Fahrer, Nieten,
Lampen fallen bei dieser Größe weg, die Kuppel zeigt nur einen Kopf).

Schreibt Vergleichsbilder nach scratch/leben/ (GF_LIFE_OUT), mit --install zusätzlich assets/art/life_sizes.png (10 Lackierungen nebeneinander à 10 Einheiten,
die fünf Größen untereinander: 100 × 120 Einheiten, 600 × 120 Bildpunkte).
Aufruf aus der Projektwurzel:  python3 tools/art/gen_life_icons_sizes.py [--install]"""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sizekit import SIZES, stack
import gen_taxi as T

IW, IH = 10, 6
OUT = os.environ.get("GF_LIFE_OUT", "scratch/leben/")
SKIN_ORDER = ["std", "neon", "mint", "night", "sunset", "candy", "gold", "sky", "platinum", "wasp"]


class IconCanvas(T.Canvas):
    """Taxi-Zeichenfläche (26 × 16 Einheiten) auf 10 × 6 Einheiten gerastert: N Bildpunkte je Einheit des Symbols."""

    def __init__(self, N):
        self.N = N
        self.nx = IW * N / float(T.W)                         # Bildpunkte je Taxi-Einheit waagerecht
        self.ny = IH * N / float(T.H)
        self.n = self.nx
        self.t = max(1, int(N / 3.0 + 0.5))                   # Strichstärke in Bildpunkten: 1 bis Größe 4, darüber 2
        self.w, self.h = IW * N, IH * N
        xs = (np.arange(self.w) + 0.5) / self.nx
        ys = (np.arange(self.h) + 0.5) / self.ny
        self.X, self.Y = np.meshgrid(xs, ys)
        self.U = self.X - T.W / 2.0
        self.A = np.abs(self.U)
        self.col = np.zeros((self.h, self.w, 3), float)
        self.on = np.zeros((self.h, self.w), bool)
        self.paint = np.zeros((self.h, self.w), bool)
        self.part = np.zeros((self.h, self.w), np.uint8)

    def px(self, v):
        return int(round(v * self.nx))

    def ell(self, cx, cy, rx, ry):
        return ((self.X - cx) / rx) ** 2 + ((self.Y - cy) / ry) ** 2 <= 1.0

    def rect(self, x0, y0, x1, y1):
        return (self.X >= x0) & (self.X < x1) & (self.Y >= y0) & (self.Y < y1)

    def rows(self, y, count):
        r0 = int(round(y * self.ny))
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + count, 0), :] = True
        return m

    def box(self, u0, y0, wpx, hpx, both=True):
        c0 = int(round((u0 + T.W / 2.0) * self.nx))
        r0 = int(round(y0 * self.ny))
        m = np.zeros((self.h, self.w), bool)
        m[r0:r0 + hpx, c0:c0 + wpx] = True
        if both:
            m |= m[:, ::-1]
        return m

    def centered(self, y0, wpx, hpx):
        half = max(1, wpx // 2)
        r0 = int(round(y0 * self.ny))
        m = np.zeros((self.h, self.w), bool)
        m[r0:r0 + hpx, self.w // 2 - half:self.w // 2 + half] = True
        return m


def render_small():
    """Größe 2 (20 × 12 Bildpunkte): die Formen des großen Taxis würden hier ineinanderlaufen (Kapseln, Lampen, Düsen, Fahrer), deshalb eigens
    vereinfacht: Rumpf, Kuppel mit Kopf, Schachbrettband, Bauchwanne, Düse, Seitenkapseln als schmale Stummel."""
    c = IconCanvas(2)
    X, Y, A = c.X, c.Y, c.A
    P, S, G = T.PAINT, T.STEEL, T.GLASS
    hull = c.ell(13.0, 8.6, 9.9, 3.9)
    tone = np.clip((Y - 4.8) / 7.6, 0, 1)
    idx = np.clip((tone * 4).astype(int), 0, 3)
    for i, col in enumerate((P[1], P[2], P[4], P[5])):
        c.put(hull & (idx == i), col)
        c.paint |= hull & (idx == i)
    c.put(c.rect(3.0, 8.0, 23.0, 8.5) & hull, P[6]); c.paint[c.rect(3.0, 8.0, 23.0, 8.5) & hull] = True
    for k in range(9):                                                   # Schachbrettband: Felder von 2 Einheiten, zwei Bildpunkte hoch
        band = c.rect(4.0 + k * 2.0, 9.0, 6.0 + k * 2.0, 10.4) & hull
        c.put(band, T.BAND_W if k % 2 == 0 else T.BAND_D); c.paint[band] = False
    dome = c.ell(13.0, 5.6, 4.0, 3.6) & (Y < 7.6)
    c.put(dome, G[2]); c.paint[dome] = False
    c.put(dome & (X < 12.0) & (Y < 5.0), G[0])
    c.put(c.ell(13.0, 6.0, 1.7, 1.5) & dome, T.SK)                        # Kopf des Fahrers
    c.put(c.rect(11.0, 4.5, 15.0, 5.5) & dome, T.CAP)
    belly = c.ell(13.0, 11.2, 6.0, 1.8) & (Y > 10.3)
    c.put(belly, P[5]); c.paint[belly] = True
    nozzle = c.rect(11.0, 12.0, 15.0, 14.6)
    c.put(nozzle, S[4]); c.paint[nozzle] = False
    c.put(c.rect(12.0, 13.6, 14.0, 14.6), T.hexc("#e8452c"))
    for sgn in (-1, 1):
        pod = c.rect(13.0 + sgn * 11.6 - 0.8, 7.6, 13.0 + sgn * 11.6 + 0.8, 9.8)
        c.put(pod, S[3]); c.paint[pod] = False
    ring = T.grow(c.on, c.t) & ~c.on
    c.col[ring] = T.OL
    return c.col.copy(), c.on | ring, c.paint & c.on


def render(N):
    """Symbol-Taxi in der Größe N: (Farben, Alpha, Lackmaske)."""
    if N == 2:
        return render_small()
    old = T.Canvas
    T.Canvas = lambda _n: IconCanvas(N)
    try:
        return T.render(IW * N / float(T.W), driver=True)
    finally:
        T.Canvas = old


def skins(N):
    col, alpha, paint = render(N)
    out = {"std": T.image(col, alpha)}
    for name, hue, sm, vm in T.SKINS:
        out[name] = T.image(T.recolor(col, paint, hue, sm, vm), alpha)
    wasp = T.recolor(col, paint, 235, 0.35, 0.28)
    xx = np.arange(IW * N)[None, :] // max(1, int(round(2 * N * IW / float(T.W))))        # Streifen je 2 Taxi-Einheiten
    wasp[paint & (xx % 2 == 0)] = col[paint & (xx % 2 == 0)]
    out["wasp"] = T.image(wasp, alpha)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    by = {N: skins(N) for N in SIZES}
    sheets = {}
    for N in SIZES:
        sh = Image.new("RGBA", (IW * N * len(SKIN_ORDER), IH * N), (0, 0, 0, 0))
        for i, nm in enumerate(SKIN_ORDER):
            sh.paste(by[N][nm], (i * IW * N, 0))
        sheets[N] = sh
    sheet = stack(sheets)
    sheet.save(OUT + "life_sizes.png")
    if "--install" in sys.argv:
        sheet.save("assets/art/life_sizes.png")
    # Vergleich: alt (so zeigt das HUD heute die 32 × 20 Punkte, auf 10,67 × 6,67 Einheiten gestreckt) über neu, je Größe eine Doppelzeile
    k = 6
    rows = []
    for N in SIZES:
        top = Image.new("RGBA", (IW * N * len(SKIN_ORDER) + 4 * len(SKIN_ORDER), IH * N), (0, 0, 0, 0))
        bot = Image.new("RGBA", top.size, (0, 0, 0, 0))
        for i, nm in enumerate(SKIN_ORDER):
            old = Image.open("assets/art/life_%s.png" % nm).convert("RGBA").resize((round(32 * N / 3.0), round(20 * N / 3.0)), Image.NEAREST)
            top.alpha_composite(old, (i * (IW * N + 4), 0))
            bot.alpha_composite(by[N][nm], (i * (IW * N + 4), 0))
        rows.append((top, bot))
    W = max(r[0].width for r in rows) * k // 2 + 20
    Hh = sum((r[0].height * 2 + 10) * k // 2 for r in rows) + 20
    im = Image.new("RGBA", (W, Hh), (48, 52, 90, 255))
    y = 10
    for top, bot in rows:
        for part in (top, bot):
            z = part.resize((part.width * k // 2, part.height * k // 2), Image.NEAREST) if (k // 2) >= 1 else part
            im.alpha_composite(z, (10, y))
            y += z.height + 4
        y += 6
    im.save(OUT + "vergleich_alt_neu.png")
    # große Ansicht der Größe 6 (std)
    big = Image.new("RGBA", (IW * 6 * 12 * 2 + 20, IH * 6 * 12 + 20), (48, 52, 90, 255))
    for i, N in enumerate((4, 6)):
        z = by[N]["std"].resize((IW * N * 12, IH * N * 12), Image.NEAREST)
        big.alpha_composite(z, (10 + i * (IW * 4 * 12 + 20), 10))
    big.save(OUT + "std_gross.png")
    print("Entwurf nach", OUT)


if __name__ == "__main__":
    main()
