"""PROBE (Runde 72, Schritt 4): Fahrgast f0 als Formen in Einheiten, je Pixelgröße 2–6 eigens gerastert (wie gen_taxi.py das Taxi).

Nur ein Entwurf: schreibt nach scratch/figur_probe/, nie nach assets/. Nichts davon ist im Spiel.
Die Figur ist 8 × 12 Einheiten groß (wie ein Bild von passengers.png: 24 × 36 Punkte bei Größe 3). Bilder des Entwurfs:
   0 Stehen (Blick zum Taxi), 2 Winken, 4 Laufen (Schritt), 7 Laufen (anderer Schritt) – nach rechts blickend.
Aufruf aus der Projektwurzel:  python3 tools/art/gen_figure_probe.py
Licht von oben links, harte Kanten, feste Farbrampen, Kontur in ganzen Bildpunkten (1 bis Größe 4, darüber 2); Kleinteile (Augenglanz,
Wangen, Haarspange, Haarsträhnen, Saum) kommen erst mit mehr Bildpunkten. Fester Aufbau ohne Zufall."""
import os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sizekit import SIZES, stroke

W, H = 8, 12
OUT = os.environ.get("GF_PROBE_OUT", "scratch/figur_probe/")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], float)


OL = hexc("#0c0f24")
SKIN = [hexc(c) for c in ("#f9d9b8", "#f2c29b", "#d9a585", "#b8856a")]
HAIR = [hexc(c) for c in ("#8a64b0", "#6a4a8c", "#3a2a52", "#261a3a")]
DRESS = [hexc(c) for c in ("#f27aa8", "#d9467f", "#b0336a", "#80244e")]
SHOE, SHOE_H = hexc("#10142b"), hexc("#3a4170")
CLIP, CLIP_H = hexc("#ffd23a"), hexc("#fff1a0")
INK, GLINT, CHEEK, MOUTH = hexc("#1a1f4a"), hexc("#ffffff"), hexc("#f59a9a"), hexc("#8a3a3a")


class Cv:
    def __init__(self, n):
        self.n = n
        self.t = stroke(n)
        self.w, self.h = W * n, H * n
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

    def poly(self, pts):
        """Gefülltes Vieleck (gerade Kanten), pro Bildpunktmitte geprüft."""
        m = np.zeros((self.h, self.w), bool)
        X, Y = self.X, self.Y
        inside = np.zeros_like(m)
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            cond = ((yi > Y) != (yj > Y)) & (X < (xj - xi) * (Y - yi) / (yj - yi + 1e-12) + xi)
            inside ^= cond
            j = i
        return inside

    def cap(self, p, q, r):
        """Kapsel (Strich mit rundem Ende) von p nach q, Radius r."""
        px, py = p
        qx, qy = q
        dx, dy = qx - px, qy - py
        L2 = dx * dx + dy * dy + 1e-12
        u = np.clip(((self.X - px) * dx + (self.Y - py) * dy) / L2, 0, 1)
        return (self.X - (px + u * dx)) ** 2 + (self.Y - (py + u * dy)) ** 2 <= r * r

    def box(self, u0, y0, wpx, hpx):
        """Rechteck in ganzen Bildpunkten ab (u0, y0) in Einheiten (u0 von der linken Kante)."""
        c0, r0 = int(round(u0 * self.n)), int(round(y0 * self.n))
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + hpx, 0), max(c0, 0):max(c0 + wpx, 0)] = True
        return m


def grow(mask, n):
    g = mask.copy()
    for _ in range(n):
        k = g.copy()
        k[1:, :] |= g[:-1, :]; k[:-1, :] |= g[1:, :]
        k[:, 1:] |= g[:, :-1]; k[:, :-1] |= g[:, 1:]
        g = k
    return g


def shade_tone(c, m, x0, y0, x1, y1, lo=0.0, hi=1.0):
    """Lichtwert 0 (hell, oben links) … 1 (dunkel, unten rechts) innerhalb eines Kastens."""
    t = ((c.X - x0) / (x1 - x0) * 0.45 + (c.Y - y0) / (y1 - y0) * 0.55)
    return np.clip(t, lo, hi)


def ramp_put(c, m, ramp, t, steps):
    """Fläche m mit fester Rampe (Liste dunkel→hell nicht nötig: ramp[0] hell … ramp[-1] dunkel), t in 0…1 in `steps` Stufen."""
    idx = np.clip((t * steps).astype(int), 0, steps - 1)
    for i in range(steps):
        c.put(m & (idx == i), ramp[min(i, len(ramp) - 1)])


# ---------------------------------------------------------------------------------------------------------------------------------------
def front(n, wave):
    c = Cv(n)
    t, tu = c.t, c.t / n
    X, Y = c.X, c.Y
    A = np.abs(X - 4.0)
    U = X - 4.0
    # Schuhe und Beine
    for s in (-1, 1):
        shoe = c.ell(4 + s * 1.3, 11.35, 1.15, 0.62) & (Y > 10.7)
        c.put(shoe, SHOE)
        c.put(shoe & (Y < 10.7 + max(tu, 0.3)), SHOE_H)
        leg = (np.abs(X - (4 + s * 1.3)) <= 0.5) & (Y >= 10.0) & (Y < 11.1)
        c.put(leg, SKIN[2])
    # Kleid: Glockenform, Schultern y 6.0, Saum y 10.25
    top, hem = 6.0, 10.25
    half = 2.2 + (np.clip(Y, top, hem) - top) / (hem - top) * 0.95
    dress = (A <= half) & (Y >= top) & (Y < hem)
    tt = np.clip((Y - top) / (hem - top), 0, 1)
    tone = np.clip(0.45 * (U + half) / (2 * half) + 0.35 * tt + (tt > 0.88) * 0.25, 0, 1)
    ramp_put(c, dress, DRESS, tone, 4)
    c.put(dress & (Y >= hem - max(tu, 0.3)) & (A < half - 0.2), DRESS[3])               # Saum
    if n >= 4:
        c.put(dress & (Y >= top + tu) & (Y < top + 2 * tu) & (A < 1.0), DRESS[0])        # Kragenlicht
    # Arme (links am Körper, rechts am Körper oder hoch zum Winken)
    sl = c.cap((1.85, 6.4), (1.55, 8.9), 0.62)
    c.put(sl & ~dress, DRESS[2]) if False else None
    arm_l = c.cap((1.95, 6.5), (1.55, 8.8), 0.62)
    arm_l = arm_l & ((X < 4 - 1.35) | (Y > 7.6)) | (c.cap((1.95, 6.5), (1.55, 8.4), 0.62))
    c.put(arm_l, DRESS[1])
    c.put(c.ell(1.55, 9.15, 0.55, 0.55), SKIN[1])                                       # Hand links
    if wave:
        pass
    else:
        arm_r = c.cap((6.05, 6.5), (6.45, 8.8), 0.62)
        c.put(arm_r, DRESS[2])
        c.put(c.ell(6.45, 9.15, 0.55, 0.55), SKIN[2])
    # Kopf: Haar hinten, Gesicht, Pony, Spange
    hair_back = c.ell(4, 3.5, 2.85, 2.65) | c.ell(4 - 2.15, 5.4, 0.8, 1.95) | c.ell(4 + 2.15, 5.4, 0.8, 1.95)
    tone_h = np.clip(0.5 * (U + 2.8) / 5.6 + 0.5 * (Y - 1.0) / 6.3, 0, 1)
    ramp_put(c, hair_back, HAIR, tone_h, 4)
    face = c.ell(4, 4.55, 1.95, 1.85)
    c.put(face, SKIN[1])
    c.put(face & (X > 4.6) & (Y > 5.2), SKIN[2])
    c.put(face & (Y < 3.7 + 0.25 * np.abs(U)), HAIR[2])                                   # Pony
    c.put(face & (Y < 3.7 + 0.25 * np.abs(U)) & (Y < 3.1) & (U < -0.3), HAIR[1])
    if n >= 5:                                                                           # Haarsträhne im Licht
        c.put(hair_back & (A > 1.2) & (A < 1.5) & (Y > 2.2) & (Y < 4.4) & (U < 0), HAIR[0])
    # Gesicht
    ex = 0.82
    ew = 1 if n < 4 else 2
    eh = max(1, int(round(0.62 * n)))
    ey = 4.15
    for s in (-1, 1):
        e = c.box(4 + s * ex - ew / (2.0 * n), ey, ew, eh)
        c.put(e, INK)
        if n >= 4:
            c.put(c.box(4 + s * ex - ew / (2.0 * n), ey, 1, 1), GLINT)
    if n >= 3:
        cs = max(1, int(round(0.4 * n)))
        for s in (-1, 1):
            c.put(c.box(4 + s * 1.45 - cs / (2.0 * n), 5.0, cs, max(1, cs - 1)), CHEEK)
    mw = max(2, int(round(0.7 * n)) // 2 * 2)
    mh = max(1, int(round(0.34 * n)) if wave else 1)
    mouth = np.zeros((c.h, c.w), bool)
    r0 = int(round(5.45 * n))
    mouth[r0:r0 + mh, c.w // 2 - mw // 2:c.w // 2 + mw // 2] = True
    c.put(mouth & face, MOUTH)
    if n >= 3 and not wave:
        for cc in (c.w // 2 - mw // 2 - 1, c.w // 2 + mw // 2):
            if face[r0 - 1, cc]:
                c.col[r0 - 1, cc] = MOUTH
    # Haarspange
    cw = max(2, int(round(0.62 * n)))
    clip = c.box(2.45 - cw / n, 1.45, cw, max(2, int(round(0.62 * n))))
    c.put(clip & hair_back, CLIP)
    if n >= 3:
        c.put(c.box(2.45 - cw / n, 1.45, 1, 1) & hair_back, CLIP_H)
    if wave:                                                                             # Arm hoch, vor dem Haar
        c.put(c.cap((6.0, 6.6), (7.05, 3.9), 0.62), DRESS[2])
        c.put(c.cap((6.0, 6.6), (6.6, 5.0), 0.62), DRESS[1])
        c.put(c.ell(7.2, 3.1, 0.62, 0.66), SKIN[0])
    return finish(c)


def side(n, phase):
    """Laufen nach rechts. phase 0: Schritt (Beine weit), phase 1: Beine kreuzen sich."""
    c = Cv(n)
    tu = c.t / n
    X, Y = c.X, c.Y
    sway = 0.0 if phase == 0 else 0.25
    # Beine
    hipx, hipy = 3.85, 9.6
    if phase == 0:
        legs = (((2.75, 11.5), SKIN[3]), ((5.0, 11.45), SKIN[2]))
    else:
        legs = (((3.6, 11.5), SKIN[3]), ((4.3, 11.5), SKIN[2]))
    for (fx, fy), col in legs:
        c.put(c.cap((hipx, hipy), (fx, fy - 0.45), 0.42), col)
        sh = c.cap((fx - 0.25, fy), (fx + 0.55, fy), 0.46) & (Y > fy - 0.35)
        c.put(sh, SHOE)
        c.put(sh & (Y < fy - 0.15), SHOE_H)
    # Kleid (schmaler von der Seite)
    top, hem = 6.0, 10.2
    cx = 3.9 + sway
    half = 1.75 + (np.clip(Y, top, hem) - top) / (hem - top) * 0.7
    dress = (np.abs(X - cx) <= half) & (Y >= top) & (Y < hem)
    tt = np.clip((Y - top) / (hem - top), 0, 1)
    tone = np.clip(0.55 * (X - (cx - half)) / (2 * half) + 0.35 * tt + (tt > 0.88) * 0.25, 0, 1)
    ramp_put(c, dress, DRESS, tone, 4)
    # Arm vorn (schwingt)
    if phase == 0:
        arm = c.cap((4.3, 6.5), (5.2, 8.7), 0.55)
        hand = (5.25, 9.0)
    else:
        arm = c.cap((4.3, 6.5), (3.8, 8.7), 0.55)
        hand = (3.75, 9.0)
    c.put(arm, DRESS[1])
    c.put(c.ell(hand[0], hand[1], 0.5, 0.5), SKIN[1])
    # Kopf im Profil: erst Gesicht (ganze Ellipse), dann das Haar darüber mit schräger Haarlinie – keine senkrechte Kante im Gesicht
    head = c.ell(4.5, 4.3, 1.8, 1.9)
    c.put(head, SKIN[1])
    crescent = head & ~c.ell(4.3, 3.9, 1.65, 1.6) & (X > 4.4) & (Y > 4.5)                 # schmaler Schatten an Kinn und Wange
    c.put(crescent, SKIN[2])
    nose = c.ell(6.25, 4.75, 0.32, 0.3) if n >= 3 else c.box(6.1, 4.7, 1, 1)
    c.put(nose, SKIN[1])
    line = 3.0 + 0.3 * np.maximum(X - 4.4, 0)                                            # flache Haarlinie über der Stirn
    cap = c.ell(4.15, 3.55, 2.15, 2.15)                                                  # runde Haube auf dem Kopf
    back = c.ell(3.0, 4.6, 1.0, 1.9) & (X < 3.9)                                         # Haar fällt hinten über den Rücken
    tail = c.ell(2.95, 6.1, 0.95, 1.2)
    hair = (cap & ((X < 4.5) | (Y < line))) | back | tail
    tone_h = np.clip(0.4 * (X - 1.5) / 4.0 + 0.6 * (Y - 1.5) / 5.8, 0, 1)
    fringe = head & (Y < line) & (X > 3.2)
    ramp_put(c, hair | fringe, HAIR, tone_h, 4)
    c.put(fringe & (Y > line - 0.5) & (X > 4.4), HAIR[2])
    if n >= 4:
        c.put(c.box(3.95, 4.55, max(1, n // 3), max(1, n // 3)), SKIN[2])                 # Ohr
    ew = 1 if n < 4 else 2
    eh = max(1, int(round(0.62 * n)))
    e = c.box(5.15, 4.0, ew, eh)
    c.put(e, INK)
    if n >= 4:
        c.put(c.box(5.15, 4.0, 1, 1), GLINT)
    if n >= 3:
        cs = max(1, int(round(0.4 * n)))
        c.put(c.box(4.6, 4.85, cs, max(1, cs - 1)), CHEEK)
    c.put(c.box(5.4, 5.45, max(1, int(round(0.45 * n))), 1), MOUTH)
    cw = max(2, int(round(0.62 * n)))                                                    # Spange wie vorn auf der sichtbaren Seite, oben am Haaransatz
    clip = c.box(4.75, 1.55, cw, cw)
    c.put(clip & (hair | fringe), CLIP)
    if n >= 3:
        c.put(c.box(4.75, 1.55, 1, 1) & (hair | fringe), CLIP_H)
    return finish(c)


def finish(c):
    ring = grow(c.on, c.t) & ~c.on
    c.col[ring] = OL
    alpha = c.on | ring
    a = np.zeros((c.h, c.w, 4), np.uint8)
    a[..., :3] = np.clip(np.round(c.col), 0, 255).astype(np.uint8)
    a[..., 3] = np.where(alpha, 255, 0)
    a[~alpha] = 0
    return Image.fromarray(a)


FRAMES = (("Stehen", lambda n: front(n, False), 0), ("Winken", lambda n: front(n, True), 2), ("Schritt", lambda n: side(n, 0), 4), ("Schritt 2", lambda n: side(n, 1), 7))


def main():
    os.makedirs(OUT, exist_ok=True)
    old = Image.open("assets/art/passengers.png").convert("RGBA")
    k = 4                                                       # Anzeige: jeder Bildpunkt als 4 × 4 Punkte (ganzzahlig), Größen erscheinen im richtigen Verhältnis
    pad = 12
    cw, ch = W * 6 * k, H * 6 * k
    sheet = Image.new("RGBA", (pad + len(FRAMES) * (2 * cw + 2 * pad), pad + len(SIZES) * (ch + pad)), (48, 52, 90, 255))
    for r, n in enumerate(SIZES):
        for i, (name, fn, old_frame) in enumerate(FRAMES):
            new = fn(n)
            alt = old.crop((old_frame * 24, 0, old_frame * 24 + 24, 36)).resize((W * n, H * n), Image.NEAREST)   # so zeigt das Spiel das Bild heute bei Größe n
            x0 = pad + i * (2 * cw + 2 * pad)
            y0 = pad + r * (ch + pad)
            sheet.alpha_composite(alt.resize((alt.width * k, alt.height * k), Image.NEAREST), (x0, y0))
            sheet.alpha_composite(new.resize((new.width * k, new.height * k), Image.NEAREST), (x0 + cw + pad // 2, y0))
            new.save(os.path.join(OUT, "f0_%s_n%d.png" % (name.replace(" ", "_"), n)))
    sheet.save(os.path.join(OUT, "vergleich_alt_neu.png"))
    # große Ansicht der neuen Figur: alle Größen nebeneinander, 1 Einheit = 16 Anzeigepunkte (ganzzahlig je Größe nur bei 2, 4: sonst 1:1 hochskaliert auf gleiche Höhe)
    big = Image.new("RGBA", (len(FRAMES) * (W * 40 + 20) + 20, len(SIZES) * 0 + H * 40 + 20), (48, 52, 90, 255))
    for i, (name, fn, _) in enumerate(FRAMES):
        im = fn(6)
        big.alpha_composite(im.resize((W * 40, H * 40), Image.NEAREST), (20 + i * (W * 40 + 20), 10))
    big.save(os.path.join(OUT, "neu_n6_gross.png"))
    print("Probe nach", OUT)


if __name__ == "__main__":
    main()
