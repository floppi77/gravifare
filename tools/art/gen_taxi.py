"""Das Taxi in jeder Pixelgröße des Spiels (Runde 71).

Das Spiel skaliert ganzzahlig: 720p = 2, 1080p = 3, 1440p = 4, 1800p = 5, 2160p = 6 Bildschirmpunkte je Welteinheit. Bisher gab es das Taxi
nur in 3 Punkten je Einheit (78 × 48); bei 1440p wurde es auf 4/3 gestreckt, jeder dritte Bildpunkt doppelt so breit. Hier ist das Taxi
deshalb als Form in Einheiten beschrieben (26 × 16) und wird für jede Skalierung eigens gerastert: harte Kanten, feste Farbrampen,
Kontur und Kleinteile (Augen, Lampen, Fugen) in ganzen Bildpunkten. Mehr Bildpunkte zeigen mehr Einzelheiten statt gröberer Klötze.

Ausgabe (Aufruf aus der Projektwurzel: python3 tools/art/gen_taxi.py):
   assets/art/taxi.png, taxi_<lack>.png      78 × 48 (3 Punkte je Einheit; Garage, Werkstatt, Menü, Zwischenflug, Finale)
   assets/art/taxi_sizes/<lack>.png          156 × 320: die Größen 2, 3, 4, 5, 6 untereinander (Höhen 32, 48, 64, 80, 96), fürs Level
   assets/art/taxi_cockpit_empty.png         78 × 48: nur die Pixel, die der Fahrer verdeckt (leere Kuppel im Finale der Nachtschicht)
   mit „preview <Ordner>“ zusätzlich Kontrollbilder dorthin.
Lackierungen entstehen aus den Lackflächen (nicht mehr über den Farbton erraten): Mütze, Haut und Glut bleiben, wie sie sind.
Licht kommt von oben, die Spiegelung der Kuppel sitzt oben links. Fester Aufbau ohne Zufall, die Ausgabe ist bitgleich. Eigene Arbeit."""
import colorsys, os, sys
import numpy as np
from PIL import Image

W, H = 26, 16
SCALES = (2, 3, 4, 5, 6)
OUT = os.environ.get("GF_TAXI_OUT", "assets/art/")            # Entwürfe: GF_TAXI_OUT=<Ordner>/ schreibt dorthin statt ins Spiel


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], float)


OL = hexc("#0c0f24")
# Lack: Glanz, hell, Grundton, mittel, Schatten, tief, tiefst
PAINT = [hexc(c) for c in ("#fff7c2", "#ffe671", "#ffcd33", "#f7aa22", "#e0811b", "#bb5c17", "#8c3d14")]
STEEL = [hexc(c) for c in ("#eef1ff", "#c9cfee", "#9aa3cf", "#6f779f", "#4f567f", "#363b61", "#1c2040")]
GLASS = [hexc(c) for c in ("#ffffff", "#d6f9f9", "#a5eaee", "#73d5df", "#4bb6ca", "#2f8fa8")]
SK, SKD, CHEEK, MOUTH = hexc("#f2c29b"), hexc("#d9a585"), hexc("#f59a9a"), hexc("#8a3a3a")
UNIH, UNI, UNID = hexc("#4a5bb0"), hexc("#2d3a7a"), hexc("#1f2856")
SHIRT, TIE = hexc("#f0f3ff"), hexc("#ff4d6d")
CAPH, CAP, CAPD, BRIM, BRIMD = hexc("#ffa868"), hexc("#ff7a2e"), hexc("#e05a1c"), hexc("#ffb070"), hexc("#8a3410")
BADGE, BADGED, INK = hexc("#fff3b0"), hexc("#e8b84a"), hexc("#1a1f4a")
BAND_W, BAND_D, BAND_WS, BAND_DS = hexc("#ffffff"), hexc("#1c2040"), hexc("#c9cfee"), hexc("#12142e")

# Maße in Einheiten (u = Abstand von der Mitte, y von oben)
DOME_Y, DOME_R, DOME_BASE = 5.05, 4.6, 7.25
HULL_HALF, HULL_Y, HULL_RISE = 10.9, 8.2, 4.7
BAND_HALF = 9.0
POD = (10.2, 12.5, 5.7, 11.0)          # u0, u1, y0, y1
BRAKE_U = 7.2


def hull_top(a):
    """Oberkante des Rumpfs: runde Schultern, die zu den Kapseln hin abfallen."""
    return HULL_Y - HULL_RISE * np.sqrt(np.clip(1.0 - (a / HULL_HALF) ** 3, 0.0, 1.0))


def belly_bot(a, y0):
    """Unterkante: flache Wanne mit runden Ecken."""
    return y0 + 2.35 * np.sqrt(np.clip(1.0 - (a / HULL_HALF) ** 3, 0.0, 1.0))


def grow(mask, n):
    """Maske um n Bildpunkte erweitern (über die Kanten, nicht über die Ecken)."""
    g = mask.copy()
    for _ in range(n):
        k = g.copy()
        k[1:, :] |= g[:-1, :]; k[:-1, :] |= g[1:, :]
        k[:, 1:] |= g[:, :-1]; k[:, :-1] |= g[:, 1:]
        g = k
    return g


class Canvas:
    def __init__(self, n):
        self.n = n
        self.w, self.h = W * n, H * n
        self.t = max(1, int(n / 3.0 + 0.5))                       # Strichstärke in Bildpunkten: 1 bis 1440p, darüber 2
        xs = (np.arange(self.w) + 0.5) / n
        ys = (np.arange(self.h) + 0.5) / n
        self.X, self.Y = np.meshgrid(xs, ys)
        self.U = self.X - W / 2.0
        self.A = np.abs(self.U)
        self.col = np.zeros((self.h, self.w, 3), float)
        self.on = np.zeros((self.h, self.w), bool)
        self.paint = np.zeros((self.h, self.w), bool)             # Lackfläche (wird je Lackierung umgefärbt)
        self.part = np.zeros((self.h, self.w), np.uint8)          # 1 Rumpf, 2 Kuppel, 3 Kapsel, 4 Düse, 5 Flosse

    def put(self, mask, c, paint=False, part=0):
        self.col[mask] = c
        self.on |= mask
        self.paint[mask] = paint
        if part:
            self.part[mask] = part

    def px(self, v):
        return int(round(v * self.n))

    def rows(self, y, count):
        """Zeilenmaske: `count` Bildpunktzeilen ab der Zeile bei y (Einheiten)."""
        r0 = self.px(y)
        m = np.zeros((self.h, self.w), bool)
        m[max(r0, 0):max(r0 + count, 0), :] = True
        return m

    def box(self, u0, y0, wpx, hpx, both=True):
        """Rechteck in ganzen Bildpunkten, linke obere Ecke bei (u0, y0) in Einheiten; `both` spiegelt es auf die rechte Seite."""
        c0 = self.px(u0 + W / 2.0)
        r0 = self.px(y0)
        m = np.zeros((self.h, self.w), bool)
        m[r0:r0 + hpx, c0:c0 + wpx] = True
        if both:
            m |= m[:, ::-1]
        return m

    def centered(self, y0, wpx, hpx):
        """Rechteck mittig auf der Symmetrieachse (Breite wird gerade gemacht)."""
        half = max(1, wpx // 2)
        r0 = self.px(y0)
        m = np.zeros((self.h, self.w), bool)
        m[r0:r0 + hpx, self.w // 2 - half:self.w // 2 + half] = True
        return m


def render(n, driver=True):
    c = Canvas(n)
    X, Y, U, A, t = c.X, c.Y, c.U, c.A, c.t
    tu = t / n                                                     # Strichstärke in Einheiten
    P, S, G = PAINT, STEEL, GLASS
    D = np.sqrt(U ** 2 + (Y - DOME_Y) ** 2)

    # --- Flossen an den Enden (hinter den Kapseln) ---------------------------------------------------------------------------------------
    fin = (A >= 11.0) & (A <= 12.5) & (Y <= 6.6) & (Y >= 3.9 + (12.5 - A) * 0.3) & ((Y - 6.3) >= -(A - 11.0) * 1.75)
    c.put(fin, P[3], True, 5)
    c.put(fin & ((Y - 6.3) < -(A - 11.0) * 1.75 + tu * 1.9), P[1], True)          # Lichtkante an der Schräge
    c.put(fin & (A > 12.5 - tu), P[4], True)

    # --- Seitenkapseln (der Rumpf überdeckt ihre Innenseite) -----------------------------------------------------------------------
    u0, u1, y0, y1 = POD
    r = 1.0
    dx = np.maximum(np.abs(A - (u0 + u1) * 0.5) - ((u1 - u0) * 0.5 - r), 0.0)
    dy = np.maximum(np.abs(Y - (y0 + y1) * 0.5) - ((y1 - y0) * 0.5 - r), 0.0)
    pod = np.sqrt(dx ** 2 + dy ** 2) <= r
    c.put(pod, S[3], False, 3)
    c.put(pod & (Y < y0 + 1.0), S[2])
    c.put(pod & (Y < y0 + tu + 0.15), S[0])
    c.put(pod & (Y > y1 - 1.1), S[4])
    c.put(pod & (A > u1 - max(tu, 0.3)), S[4])
    for gy in (6.95, 9.7):                                         # Kühlrippen: Nut mit Lichtkante darunter
        c.put(pod & c.rows(gy, t), S[5])
        c.put(pod & c.rows(gy + tu, t) & (A < u1 - 0.3), S[1])
    sock = pod & (A >= 11.55) & (Y >= 7.4) & (Y < 8.6)
    c.put(sock, S[6])
    rc = c.px(8.0)
    nzh = max(1, c.px(0.34))
    nz = np.zeros(Y.shape, bool)
    nz[rc - nzh:rc + nzh, :] = True
    c.put(sock & nz & (A >= 11.9), hexc("#4fd0ff"))                # Lenkdüse
    if n >= 3:
        c.put(sock & nz & (A >= 12.5 - max(tu, 0.3)) & (Y > 8.0 - tu) & (Y < 8.0 + tu), hexc("#e8fbff"))

    # --- Rumpf oben: runde Schultern ---------------------------------------------------------------------------------------------------
    yt = hull_top(A)
    band0 = 8.0 + tu                                               # Oberkante des Schachbrettbands (darüber die Zierleiste)
    band1 = band0 + 2.0
    up = (A <= HULL_HALF) & (Y >= yt) & (Y < 8.0)
    tt = np.where(up, (Y - yt) / np.maximum(8.0 - yt, 0.01), 0.0)
    lvl = np.full(Y.shape, 1)
    lvl[tt > 0.44] = 2
    lvl[tt > 0.76] = 3
    lvl[A > 8.9] += 1
    lvl[A > 10.1] += 1
    lvl[(D < DOME_R + 0.7) & (Y < 7.9)] += 1                       # Schatten rund um die Kuppel
    lvl = np.clip(lvl, 0, 5)
    for i in range(6):
        c.put(up & (lvl == i), P[i], True, 1)
    shine = up & (Y - yt >= tu) & (Y - yt < 2.0 * tu) & (A > 5.9) & (A < 8.9)    # Glanzlinie knapp unter der Oberkante, folgt der Wölbung
    c.put(shine & (U < 0), P[0], True)
    if n >= 3:
        c.put(shine & (U > 0) & (A < 7.6), P[0], True)
    if n >= 4:                                                     # Nieten über der Zierleiste
        for uu in (-9.2, -6.2, 6.2, 9.2):
            c.put(c.box(uu, 7.35, 1, 1, False) & up, P[4], True)

    # --- Zierleiste, Schachbrettband, Lichtkante ---------------------------------------------------------------------------------------
    mid = (A <= HULL_HALF) & (Y >= 8.0) & (Y < band1 + tu)
    side = np.where(A > 10.0, 5, 4)
    for i in (4, 5):
        c.put(mid & (side == i), P[i], True, 1)
    c.put(mid & (Y < band0), P[6], True)
    band = mid & (Y >= band0) & (Y < band1) & (A <= BAND_HALF)
    row = np.floor(Y - band0 + 1e-6).astype(int)
    chk = (np.floor(X + 1e-6).astype(int) + row) % 2 == 0
    far = A > BAND_HALF - 1.0
    c.put(band & chk & ~far, BAND_W); c.put(band & ~chk & ~far, BAND_D)
    c.put(band & chk & far, BAND_WS); c.put(band & ~chk & far, BAND_DS)
    if n >= 3:
        c.put(band & chk & (Y < band0 + tu) & ~far, hexc("#dfe3f5"))               # Schatten der Zierleiste auf den weißen Feldern
    c.put(mid & (Y >= band1) & (A <= 9.9), P[1], True)            # helle Lippe unter dem Band

    # --- Bauch --------------------------------------------------------------------------------------------------------------------------------
    by0 = band1 + tu
    yb = belly_bot(A, by0)
    belly = (A <= HULL_HALF) & (Y >= by0) & (Y <= yb)
    t2 = np.where(belly, (Y - by0) / np.maximum(yb - by0, 0.01), 0.0)
    bl = np.full(Y.shape, 4)
    bl[t2 > 0.45] = 5
    bl[t2 > 0.82] = 6
    bl[(A > 9.4) & (bl < 6)] += 1
    for i in (4, 5, 6):
        c.put(belly & (bl == i), P[i], True, 1)

    # --- Düse unten -------------------------------------------------------------------------------------------------------------------------
    fy = 12.25
    fl = (A <= 4.2) & (Y >= fy) & (Y < fy + 0.67)
    bell_half = 3.7 - 0.6 * (Y - fy - 0.67) / 2.2
    bell = (Y >= fy + 0.67) & (Y <= 15.2) & (A <= bell_half)
    ux = U / np.maximum(np.where(fl, 4.2, bell_half), 0.1)
    sl = np.full(Y.shape, 3)
    sl[ux < -0.72] = 4
    sl[(ux >= -0.5) & (ux < -0.12)] = 1
    sl[(ux >= -0.12) & (ux < 0.4)] = 2
    sl[ux >= 0.72] = 5
    for i in range(1, 6):
        c.put(bell & (sl == i), S[i], False, 4)
        c.put(fl & (sl == i), S[max(i - 1, 1)], False, 4)
    c.put(fl & (Y < fy + tu), S[0])
    c.put(bell & (Y > 15.2 - tu), S[5])
    cav = (A <= 2.0) & (Y >= 13.5) & (Y <= 15.2)
    c.put(cav, S[6])
    c.put(c.centered(14.5, c.px(2.8), max(1, c.px(0.5))) & cav, hexc("#e8452c"))   # Restglut (bleibt bei jeder Lackierung rot)
    c.put(c.centered(14.5, c.px(1.2), max(1, c.px(0.5))) & cav, hexc("#ff7a5a"))

    # --- Bremsdüsen auf den Schultern, Positionslampen -----------------------------------------------------------------------------
    bw = max(2, c.px(0.66))
    ny = float(hull_top(np.array(BRAKE_U))) - 0.4
    nub = c.box(-BRAKE_U - bw / (2.0 * n), ny, bw, max(2, c.px(0.67)))
    c.put(nub, S[4], False, 1)
    c.put(nub & c.rows(ny, t), S[1])
    ls = max(2, int(round(0.9 * n)))
    under = c.col.copy()
    for sign, body, hi, lo in ((-1, hexc("#ff4d6d"), hexc("#ffd0d8"), hexc("#b02a48")), (1, hexc("#5dff9a"), hexc("#dcffe9"), hexc("#23b060"))):
        m = c.box(-9.4 - ls / (2.0 * n), 6.2, ls, ls, False)
        if sign > 0:
            m = m[:, ::-1]
        rr, cc = np.where(m)
        r0_, c0_ = rr.min(), cc.min()
        keep = c.paint[r0_:r0_ + ls, c0_:c0_ + ls].copy()
        c.put(m, body)
        c.col[r0_ + ls - max(1, ls // 3):r0_ + ls, c0_:c0_ + ls] = lo
        hs = max(1, ls // 3)
        c.col[r0_:r0_ + hs, c0_:c0_ + hs] = hi
        if ls >= 4:                                                # runde Ecken: dort bleibt der Lack sichtbar
            for (ry, rx) in ((0, 0), (0, ls - 1), (ls - 1, 0), (ls - 1, ls - 1)):
                c.col[r0_ + ry, c0_ + rx] = under[r0_ + ry, c0_ + rx]
                c.paint[r0_ + ry, c0_ + rx] = keep[ry, rx]

    # --- Kuppel -------------------------------------------------------------------------------------------------------------------------------
    glass = (D <= DOME_R) & (Y < DOME_BASE)
    L = (-U * 0.6 - (Y - DOME_Y) * 0.8) / DOME_R
    gl = np.full(Y.shape, 3)
    gl[L > 0.1] = 2
    gl[L > 0.55] = 1
    gl[L < -0.4] = 4
    gl[(D > DOME_R - 0.55) & (gl < 5)] += 1
    for i in range(1, 6):
        c.put(glass & (gl == i), G[min(i, 5)], False, 2)
    if driver:
        _driver(c, glass)
    th = np.arctan2(Y - DOME_Y, U)
    c.put(glass & (D > 3.3) & (D < 4.0) & (th > -2.85) & (th < -2.3), G[0])     # Spiegelung oben links
    c.put(glass & (D > 3.3) & (D < 4.0) & (th > -3.08) & (th < -2.97), G[0])
    c.put(glass & (D > 3.5) & (D < 4.0) & (th > 0.3) & (th < 0.6), G[1])          # Gegenlicht unten rechts
    c.put(glass & (D > DOME_R - tu), G[5])                         # Glasrand
    # Kragen: Chromring am Fuß der Kuppel
    ch = max(2, c.px(0.55))
    col_r0 = c.px(DOME_BASE) - ch // 2
    collar = np.zeros(Y.shape, bool)
    collar[col_r0:col_r0 + ch, :] = True
    collar &= A <= float(np.sqrt(DOME_R ** 2 - (DOME_BASE - DOME_Y) ** 2)) + 0.1
    c.put(collar, S[2], False, 2)
    c.put(collar & c.rows(col_r0 / n, t), S[0])
    c.put(collar & c.rows((col_r0 + ch - t) / n, t), S[4])

    # --- Fugen zwischen den Teilen, Kontur --------------------------------------------------------------------------------------------
    for front, back in ((2, 1), (1, 3), (3, 5), (1, 5), (4, 1)):
        edge = grow(c.part == front, t) & (c.part == back)
        c.put(edge, OL)
    ring = grow(c.on, t) & ~c.on
    c.col[ring] = OL
    alpha = c.on | ring
    return c.col.copy(), alpha, c.paint & c.on


def _driver(c, glass):
    """Fahrer in der Kuppel: Melone mit Abzeichen, Gesicht, Uniform mit Kragen und Krawatte (Farben wie driver.png)."""
    n, t, U, A, Y = c.n, c.t, c.U, c.A, c.Y
    tu = t / n
    body = glass & (((U / 3.6) ** 2 + ((Y - 9.2) / 3.0) ** 2) <= 1.0)
    c.put(body, UNI)
    c.put(body & (((U / 3.6) ** 2 + ((Y - 9.2 - tu) / 3.0) ** 2) > 1.0), UNIH)
    c.put(body & (A > 2.4), UNID)
    c.put(glass & (A <= 0.62) & (Y >= 6.0) & (Y < 6.5), SKD)                       # Hals
    shirt = glass & (Y >= 6.25) & (A <= (7.2 - Y) * 0.85)
    c.put(shirt, SHIRT)
    c.put(c.centered(6.5, 2, max(1, c.px(0.6))) & glass, TIE)
    head = glass & (((U / 2.1) ** 2 + ((Y - 4.8) / 1.55) ** 2) <= 1.0)
    c.put(head, SK)
    c.put(head & (Y > 5.8), SKD)
    c.put(glass & (A >= 2.05) & (A < 2.42) & (Y >= 4.5) & (Y < 5.15), SKD)         # Ohren
    # Augen: dunkle Pupillen, ab 1440p mit Glanzpunkt oben links
    pw = 1 if n < 4 else 2
    eh = 1 if n < 3 else (2 if n < 6 else 3)
    ey = 4.35 if n > 3 else 4.0                                   # 1080p: eine Zeile höher, sonst laufen Auge, Mundwinkel und Mund zu einer Linie zusammen
    ex = 0.8 if n != 3 else 1.1                                   # … und einen Punkt weiter außen
    eye = c.box(-ex - pw / (2.0 * n), ey, pw, eh, False)
    c.put(eye | eye[:, ::-1], INK)
    if n >= 4:
        gm = c.box(-ex - pw / (2.0 * n), ey, 1, 1, False)
        c.put(gm | np.roll(gm[:, ::-1], -(pw - 1), axis=1), hexc("#ffffff"))
    cs = max(1, c.px(0.34))
    c.put(c.box(-1.5 - cs / (2.0 * n), 5.15 if n > 2 else 5.0, cs, max(1, cs - (1 if cs > 1 else 0))), CHEEK)
    mh = 1 if n < 5 else 2
    mw = max(2, c.px(0.8) // 2 * 2)
    my = 5.4 if n > 2 else 5.0
    c.put(c.centered(my, mw, mh), MOUTH)
    if n >= 3:                                                     # Lächeln: Mundwinkel eine Zeile höher
        r0 = c.px(my) - 1
        for cc in (c.w // 2 - mw // 2 - 1, c.w // 2 + mw // 2):
            c.col[r0, cc] = MOUTH
    # Melone
    cy = 3.45 if n > 2 else 3.0                                   # 720p: Krempe eine Zeile höher, sonst verdeckt sie die Augen
    dome = glass & (Y < cy) & (((U / 2.05) ** 2 + ((Y - cy - 0.05) / 1.85) ** 2) <= 1.0)
    c.put(dome, CAP)
    c.put(dome & ((-U * 0.45 - (Y - cy)) > 1.25) & (U < 0.6), CAPH)
    c.put(dome & (U > 1.2), CAPD)
    bh = max(2, c.px(0.55))
    brim = np.zeros(Y.shape, bool)
    r0 = c.px(cy)
    brim[r0:r0 + bh, :] = True
    brim &= glass & (A <= 2.7)
    c.put(brim, BRIM)
    c.put(brim & c.rows((r0 + bh - t) / n, t), BRIMD)
    if n >= 4:
        c.put(head & c.rows((r0 + bh) / n, 1), SKD)                # Schatten der Krempe auf der Stirn
    bw = max(2, c.px(1.0) // 2 * 2)
    bhh = max(2, c.px(0.75))
    badge = c.centered(cy - 1.05, bw, bhh) & glass
    c.put(badge, BADGE)
    c.put(badge & c.rows(cy - 1.05 + (bhh - 1) / n, 1), BADGED)
    if n >= 3:
        c.put(c.centered(cy - 1.05 + (bhh // 2 - (1 if bhh > 2 else 0)) / n, 2, max(1, bhh // 3)) & badge, INK)


# --- Lackierungen ---------------------------------------------------------------------------------------------------------------------
SKINS = (("neon", 318, 1.0, 1.0), ("mint", 150, 0.9, 1.0), ("night", 225, 0.9, 0.78), ("sunset", 8, 1.0, 1.0), ("candy", 178, 0.85, 1.05),
         ("gold", 46, 0.7, 1.12), ("sky", 198, 0.55, 1.1), ("platinum", 215, 0.12, 1.18))


def recolor(col, paint, hue, smul, vmul):
    """Lackflächen umfärben: Farbton um den neuen Grundton, Sättigung und Helligkeit skaliert (wie bisher in gen_art.taxi_skins)."""
    out = col.copy()
    cache = {}
    for y, x in zip(*np.where(paint)):
        k = tuple(col[y, x])
        if k not in cache:
            h, s, v = colorsys.rgb_to_hsv(k[0] / 255.0, k[1] / 255.0, k[2] / 255.0)
            r, g, b = colorsys.hsv_to_rgb((hue / 360.0 + (h - 0.12) * 0.5) % 1.0, min(max(s * smul, 0.0), 1.0), min(max(v * vmul, 0.0), 1.0))
            cache[k] = (r * 255.0, g * 255.0, b * 255.0)
        out[y, x] = cache[k]
    return out


def image(col, alpha):
    a = np.zeros(col.shape[:2] + (4,), np.uint8)
    a[..., :3] = np.clip(np.round(col), 0, 255).astype(np.uint8)
    a[..., 3] = np.where(alpha, 255, 0)
    a[~alpha] = 0
    return Image.fromarray(a)


def skins(n):
    """{Name: Bild} aller Lackierungen in der Größe n."""
    col, alpha, paint = render(n)
    out = {"std": image(col, alpha)}
    for name, hue, sm, vm in SKINS:
        out[name] = image(recolor(col, paint, hue, sm, vm), alpha)
    wasp = recolor(col, paint, 235, 0.35, 0.28)                    # Wespe: dunkler Rumpf mit gelben Streifen, je 2 Einheiten breit
    xx = np.arange(W * n)[None, :] // (2 * n)
    stripes = paint & (xx % 2 == 0)
    wasp[stripes] = col[stripes]
    out["wasp"] = image(wasp, alpha)
    return out


def main():
    os.makedirs(OUT + "taxi_sizes", exist_ok=True)
    by_scale = {n: skins(n) for n in SCALES}
    for name in by_scale[3]:
        by_scale[3][name].save(OUT + "taxi_%s.png" % name)
        sheet = Image.new("RGBA", (W * max(SCALES), H * sum(SCALES)), (0, 0, 0, 0))
        y = 0
        for n in SCALES:
            sheet.paste(by_scale[n][name], (0, y))
            y += H * n
        sheet.save(OUT + "taxi_sizes/%s.png" % name)
    by_scale[3]["std"].save(OUT + "taxi.png")
    col, alpha, _ = render(3)                                      # leere Kuppel: nur die Pixel, die sich ohne Fahrer ändern
    bare, balpha, _ = render(3, driver=False)
    diff = np.any(np.round(col) != np.round(bare), axis=2) & balpha
    image(bare, diff).save(OUT + "taxi_cockpit_empty.png")
    print("Taxi: %d Lackierungen in den Größen %s" % (len(by_scale[3]), ", ".join(str(n) for n in SCALES)))
    if len(sys.argv) > 2 and sys.argv[1] == "preview":
        d = sys.argv[2]
        os.makedirs(d, exist_ok=True)
        k = 60                                                     # alle Größen auf gleiche Bildgröße vergrößert (ganzzahlig)
        sheet = Image.new("RGBA", (W * k * 2 + 30, H * k * 3 + 40), (36, 40, 74, 255))
        for i, n in enumerate(SCALES):
            im = by_scale[n]["std"].resize((W * n * (k // n), H * n * (k // n)), Image.NEAREST)
            sheet.alpha_composite(im, (10 + (i % 2) * (W * k + 10), 10 + (i // 2) * (H * k + 10)))
        sheet.save(os.path.join(d, "sizes.png"))
        row = Image.new("RGBA", (W * 6 * 5 + 60, H * 6 * 2 + 30), (36, 40, 74, 255))
        for i, name in enumerate(by_scale[6]):
            row.alpha_composite(by_scale[6][name], (10 + (i % 5) * (W * 6 + 10), 10 + (i // 5) * (H * 6 + 10)))
        row.resize((row.width * 2, row.height * 2), Image.NEAREST).save(os.path.join(d, "skins.png"))


if __name__ == "__main__":
    main()
