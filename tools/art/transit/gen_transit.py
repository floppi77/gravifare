"""Bausteine der Zwischenflug-Hintergründe (Runde 68): Nebel (isotropes fbm), Sterne, Kugeln, Leuchthöfe, Ebenen (Lay),
Pixelstil (Bayer-Raster). Die Sektorbilder setzt gen_layers.py daraus zusammen; s5() und s9() liefern hier den Grund
von Sektor 5 (Sonne) und 9 (Schwarzes Loch mit Gravitationslinse).
Leinwand 3200×1080 = Einheiten x -213⅓..853⅓, y 0..360 (1 Einheit = 3 px); der 16:9-Rahmen ist x 0..640.
Eigenständig per Code erzeugt, keine Fremdassets. Gerenderte Blender-Ebenen liegen in TRANSIT_RENDER (siehe build.sh)."""
import sys, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import map_coordinates

W, H, FX, U = 3200, 1080, 640, 3
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
UX = (XX - FX) / U          # Einheiten, 0..640 im 16:9-Rahmen (Ultrawide: -107..747)
UY = YY / U
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

def C(h):
    h = h.lstrip("#"); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)

def fbm(seed, octaves=5, base=3, w=W, h=H):
    """Isotropes fbm: je Oktave weißes Rauschen, Gauß-geglättet (keine achsparallelen Kanten), bilinear hochskaliert."""
    from scipy.ndimage import gaussian_filter, zoom
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32); amp = 1.0
    for o in range(octaves):
        n = base * 2 ** o                       # Strukturen je Bildhöhe
        gh = max(8, n * 4); gw = max(8, int(gh * w / h))
        g = gaussian_filter(rng.standard_normal((gh, gw)).astype(np.float32), 2.0, mode="wrap")
        g /= g.std() + 1e-6
        up = zoom(g, (h / gh, w / gw), order=1)[:h, :w]
        if up.shape != (h, w):
            up = np.pad(up, ((0, h - up.shape[0]), (0, w - up.shape[1])), mode="edge")
        out += up * amp; amp *= 0.5
    out = (out - out.mean()) / (out.std() + 1e-6)
    return (0.5 + out * 0.14).astype(np.float32)

def warped(seed, strength=60.0, octaves=5, base=3):
    n = fbm(seed, octaves, base)
    dx = (fbm(seed + 101, 4, 2) - 0.5) * strength * 2
    dy = (fbm(seed + 202, 4, 2) - 0.5) * strength * 2
    return map_coordinates(n, [np.clip(YY + dy, 0, H - 1), np.clip(XX + dx, 0, W - 1)], order=1).astype(np.float32)

def band(n, lo, hi):
    return np.clip((n - lo) / (hi - lo), 0, 1)

def ss(x):
    x = np.clip(x, 0, 1); return x * x * (3 - 2 * x)

def vgrad(stops):
    """stops: [(y_unit, hex)] -> Bild"""
    ys = [s[0] for s in stops]
    cols = np.array([C(s[1]) for s in stops])
    col = np.stack([np.interp(UY[:, 0], ys, cols[:, k]) for k in range(3)], -1)
    return np.repeat(col[:, None, :], W, axis=1).astype(np.float32)

class Lay:
    """Transparente Tiefenebene: vormultiplizierte Farbe P und Deckung A. f = Mitziehfaktor (Parallaxe)."""
    def __init__(self, name, f):
        self.name, self.f = name, f
        self.P = np.zeros((H, W, 3), np.float32); self.A = np.zeros((H, W), np.float32)
    def light(self, g):          # additives Licht (Leuchthof): Farbe addieren, Deckung nach Helligkeit
        self.P += g
        a = np.clip(g.max(-1) / 255.0, 0, 1)
        self.A = 1 - (1 - self.A) * (1 - a)

def add(img, mask, col, k=1.0):
    g = mask[..., None] * C(col)[None, None, :] * k
    if isinstance(img, Lay): img.light(g)
    else: img += g

def over(img, mask, col, a=1.0):
    m = (mask * a)[..., None]
    c = C(col) if isinstance(col, str) else col
    img[:] = img * (1 - m) + c * m

def dist(cx, cy):
    return np.sqrt((UX - cx) ** 2 + (UY - cy) ** 2)

def glow(cx, cy, r, p=2.0):
    return np.exp(-(dist(cx, cy) / r) ** p)

def ramp(t, stops):
    ps = [s[0] for s in stops]; cols = np.array([C(s[1]) for s in stops])
    return np.stack([np.interp(t, ps, cols[:, k]) for k in range(3)], -1).astype(np.float32)

def sphere(img, cx, cy, r, light, stops, tex=None, tex_k=0.25, rim=None, rim_k=0.6, bands=7, amb=0.06):
    """Beleuchtete Kugel, Licht in Stufen (Pixel-Art). light = (lx, ly) Richtung zur Lichtquelle."""
    d = dist(cx, cy); inside = d <= r
    nx = (UX - cx) / r; ny = (UY - cy) / r
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    lx, ly = light; lz = 0.35; ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lit = np.clip((nx * lx + ny * ly + nz * lz) / ln, 0, 1)
    if tex is not None:
        lit = np.clip(lit * (1 - tex_k + tex_k * 2 * tex), 0, 1)
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    q = np.floor(lit * bands + thr * 0.9) / bands
    col = ramp(np.clip(q + amb, 0, 1), stops)
    if isinstance(img, Lay):
        img.P[inside] = col[inside]; img.A[inside] = 1.0
    else:
        img[inside] = col[inside]
    if rim is not None:
        edge = np.clip(1 - (r - d) / (r * 0.08), 0, 1) * inside * np.clip(lit * 2.5, 0, 1)
        add(img, edge * rim_k, rim)
    return inside

def stars(img, seed, n, box=None, bright=1.0, cols=("#9fb0ff", "#e8ecff", "#ffe9c0")):
    rng = np.random.default_rng(seed)
    for i in range(n):
        x = rng.integers(0, W); y = rng.integers(0, H)
        b = rng.random() ** 2.2 * 150 * bright + 25
        c = C(cols[rng.integers(0, len(cols))]) / 255.0
        img[y, x] = np.maximum(img[y, x], c * b)
        if b > 120 and rng.random() < 0.35:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= y + dy < H and 0 <= x + dx < W:
                    img[y + dy, x + dx] = np.maximum(img[y + dy, x + dx], c * b * 0.45)

def text_calm(img, k=0.38):
    """Untere Mitte (Funkspruch, Titelkarte) beruhigen: abdunkeln."""
    q = ((UX - 320) / 300) ** 2 + ((UY - 320) / 95) ** 2
    m = np.exp(-q * q * 1.2)
    if isinstance(img, Lay): img.P *= (1 - k * m)[..., None]
    else: img *= (1 - k * m)[..., None]

def poly_layer(polys):
    """[(punkte_in_einheiten, (r,g,b,a))] -> RGBA-Array (gezeichnet ohne Kantenglättung)."""
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    for pts, col in polys:
        d.polygon([(FX + x * U, y * U) for x, y in pts], fill=col)
    return np.asarray(lay).astype(np.float32)

def comp(img, lay):
    a = lay[..., 3:4] / 255.0
    if isinstance(img, Lay):
        img.P = img.P * (1 - a) + lay[..., :3] * a; img.A = a[..., 0] + img.A * (1 - a[..., 0])
    else:
        img[:] = img * (1 - a) + lay[..., :3] * a

def finish_lay(lay, name, levels=28):
    """Ebene speichern: gerade Farbe (P/A) in Stufen mit Bayer-Raster, Deckung in 12 Stufen gerastert."""
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    A = np.clip(lay.A, 0, 1)
    col = np.where(A[..., None] > 1e-3, lay.P / np.maximum(A[..., None], 1e-3), 0)
    q = np.floor(np.clip(col, 0, 255) / (255 / levels) + thr[..., None]) * (255 / levels)
    aq = np.floor(A * 12 + thr * 0.999) / 12
    aq = np.where(A < 0.02, 0, aq)
    out = np.concatenate([np.clip(q, 0, 255), (np.clip(aq, 0, 1) * 255)[..., None]], -1).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(name)

def finish(img, name, levels=28):
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    q = np.floor(np.clip(img, 0, 255) / (255 / levels) + thr[..., None]) * (255 / levels)
    Image.fromarray(np.clip(q, 0, 255).astype(np.uint8)).convert("RGBA").save(name)


LAY = os.environ.get("TRANSIT_RENDER", os.path.expanduser("~/.cache/gravifare-transit"))

def layer(name):
    a = np.asarray(Image.open(os.path.join(LAY, name)).convert("RGBA")).astype(np.float32)
    return a

def bloom(img, lay, sigma, k, thr=0.0, tint=None):
    from scipy.ndimage import gaussian_filter
    a = lay[..., 3:4] / 255.0
    b = lay[..., :3] * a
    if thr > 0:
        lum = b.max(-1, keepdims=True)
        b = b * np.clip((lum - thr) / (255 - thr), 0, 1)
    if tint is not None:
        b = b.mean(-1, keepdims=True) * (C(tint) / 255.0)
    g = np.stack([gaussian_filter(b[..., i], sigma * U) for i in range(3)], -1)
    if isinstance(img, Lay): img.light(g * k)
    else: img += g * k

def gradmap(lay, stops):
    """Ebene einfärben: Helligkeit -> Farbrampe (Alpha bleibt)."""
    lum = (lay[..., 0] * 0.3 + lay[..., 1] * 0.55 + lay[..., 2] * 0.15) / 255.0
    out = lay.copy(); out[..., :3] = ramp(lum, stops); return out

def pixelize(lay, levels=10):
    """Ebene auf Pixelstil bringen: Farbstufen mit Bayer-Raster, Alpha hart."""
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    out = lay.copy()
    out[..., :3] = np.floor(lay[..., :3] / (255 / levels) + thr[..., None] * 0.85) * (255 / levels)
    out[..., 3] = np.where(lay[..., 3] > 110, 255, np.where(lay[..., 3] > 40, np.where(thr > 0.5, 255, 0), 0))
    return out

def rot(px, py, a):
    c, s = math.cos(a), math.sin(a); return px * c - py * s, px * s + py * c

# ---------------------------------------------------------------- Sektor 1 Sternenhafen
def s1():
    img = vgrad([(0, "#060818"), (120, "#0d1030"), (215, "#24163e"), (360, "#2a1838")])
    n = warped(11, 80)
    add(img, band(n, 0.50, 0.75) * ss((240 - UY) / 120), "#4a2266", 0.55)
    add(img, band(warped(12, 70), 0.55, 0.8) * ss((200 - UY) / 150), "#1e3c80", 0.5)
    stars(img, 1, 420)
    # Anflugschneise: Leuchtbojen zur Hafenstation
    for i in range(16):
        t = i / 15.0
        x = 20 + 250 * t; y = 36 + 22 * t - 14 * math.sin(t * math.pi)
        col = ["#ff4a4a", "#50ff90", "#f0f4ff"][i % 3]
        add(img, glow(x, y, 0.7), col, 1.4)
        add(img, glow(x, y, 3.5), col, 0.28)
    lay = layer("s1_harbor.png")
    bloom(img, lay, 1.6, 0.5, thr=150)
    comp(img, pixelize(lay, 22))
    bloom(img, lay, 1.2, 0.35, thr=170)            # Stadtlichter, Positionslichter
    # Dämmerungssaum am Horizont (links golden, rechts violett) und Sonnenaufgang
    R, cy0 = 1100.0, 236.0
    d = dist(320, cy0 + R) - R
    hue = np.clip(UX / 640.0, 0, 1)
    saum = ramp(hue, [(0, "#ffb060"), (0.45, "#ff7a8a"), (1, "#a070ff")])
    edge = np.clip(1 - np.abs(d + 0.8) / 1.4, 0, 1)
    img += (edge * 0.7)[..., None] * saum
    up = (d >= 0) * np.exp(-d / 12.0) * (0.45 + 0.55 * np.exp(-((UX - 120) / 220) ** 2))
    img += (up * 0.5)[..., None] * saum
    sx = 128.0; sy = cy0 + R - math.sqrt(R * R - (sx - 320) ** 2)
    add(img, glow(sx, sy, 7), "#fff2c8", 1.1)
    add(img, glow(sx, sy, 30), "#ffb060", 0.45)
    streak = np.exp(-((UY - sy) / 0.9) ** 2) * np.exp(-np.abs(UX - sx) / 150)
    add(img, streak, "#ffd8a0", 0.7)
    text_calm(img, 0.15)
    return img

# ---------------------------------------------------------------- Sektor 2 Neonschluchten
def crystal(cx, cy, length, width, ang, cols):
    """Länglicher Kristall (Sechseck-Prisma von der Seite): 3 Facetten."""
    hl, hw = length / 2, width / 2
    tip = hl * 0.28
    def P(px, py):
        x, y = rot(px, py, ang); return (cx + x, cy + y)
    mid = [P(-hl, 0), P(-hl + tip, -hw), P(hl - tip, -hw), P(hl, 0), P(hl - tip, hw), P(-hl + tip, hw)]
    top = [P(-hl, 0), P(-hl + tip, -hw), P(hl - tip, -hw), P(hl, 0), P(hl - tip, -hw * 0.15), P(-hl + tip, -hw * 0.15)]
    hi = [P(-hl + tip, -hw), P(hl - tip, -hw), P(hl - tip * 1.3, -hw * 0.7), P(-hl + tip * 1.3, -hw * 0.7)]
    return [(mid, cols[0]), (top, cols[1]), (hi, cols[2])]

def s2():
    img = vgrad([(0, "#0a0418"), (180, "#140828"), (360, "#0c0518")])
    n1 = warped(21, 120); n2 = warped(22, 90)
    add(img, band(n1, 0.52, 0.78), "#a02a8a", 0.55)
    add(img, band(n2, 0.56, 0.80), "#1a8aa8", 0.45)
    add(img, band(n1, 0.70, 0.86), "#ff60c8", 0.35)
    add(img, band(warped(23, 60, 6, 6), 0.62, 0.8) * band(n2, 0.4, 0.6), "#60f0ff", 0.25)
    stars(img, 2, 380, cols=("#ffb0f0", "#e8ecff", "#a0f8ff"))
    text_calm(img, 0.3)
    lay = layer("s2_crystals.png")
    bloom(img, lay, 9, 0.55)                      # Leuchthof der Kristalle auf dem Nebel
    comp(img, pixelize(lay, 14))
    bloom(img, lay, 2.0, 0.35, thr=150)           # Glanz an den Spitzen
    return img

# ---------------------------------------------------------------- Sektor 3 Schrottgürtel
def s3():
    img = vgrad([(0, "#071418"), (180, "#0c2026"), (360, "#100c0a")])
    n = warped(31, 90)
    add(img, band(n, 0.48, 0.78), "#1a5a5a", 0.6)
    add(img, band(warped(32, 70), 0.6, 0.82) * ss(UY / 200), "#7a4020", 0.45)
    stars(img, 3, 300, bright=0.8)
    add(img, np.exp(-((UY - (70 + 0.10 * (UX - 320))) / 34) ** 2), "#2a5050", 0.35)     # Staub im Gürtel
    text_calm(img, 0.3)
    lay = layer("s3_scrap.png")
    lay[..., :3] = np.clip(lay[..., :3] * 1.45 + 6, 0, 255)          # Schrott etwas heller als das Rohbild
    comp(img, pixelize(lay, 16))
    bloom(img, lay, 2.5, 0.5, thr=170)            # Fenster und Glanzkanten
    # glühende Splitter (Schweißfunken)
    rng = np.random.default_rng(36)
    for i in range(36):
        x = rng.uniform(-100, 740); y = 70 + 0.10 * (x - 320) + 14 * math.sin(x / 90) + rng.normal(0, 22)
        if 132 < y < 222: continue
        add(img, glow(x, y, 0.55), "#ffb060", 1.1)
        add(img, glow(x, y, 2.5), "#ff7020", 0.15)
    return img

# ---------------------------------------------------------------- Sektor 4 Magnetfeld
def s4():
    img = vgrad([(0, "#050a18"), (200, "#0a1828"), (360, "#060c16")])
    add(img, band(warped(41, 80), 0.55, 0.8), "#163a5a", 0.5)
    stars(img, 4, 380, cols=("#b0e0ff", "#e8f4ff", "#d0fff0"))
    # Polarlicht-Vorhänge: Fußlinie wellt sich, Strahlen nach oben, Saum unten hell
    rng = np.random.default_rng(42)
    for k, (base_y, amp, freq, ph, cA, cB, gain) in enumerate([
            (120, 22, 1 / 95, 0.0, "#40ffa0", "#8040ff", 1.0),
            (95, 16, 1 / 70, 2.0, "#30d8c0", "#c050ff", 0.55)]):
        foot = base_y + amp * np.sin(UX * freq * 2 * math.pi / 6.3 + ph) + 8 * np.sin(UX / 23 + ph * 3)
        above = foot - UY                       # >0 oberhalb der Fußlinie
        rng_r = np.random.default_rng(43 + k)
        from scipy.ndimage import gaussian_filter1d
        r1 = gaussian_filter1d(rng_r.standard_normal(W), 2.5); r1 /= r1.std()
        r2 = gaussian_filter1d(rng_r.standard_normal(W), 14.0); r2 /= r2.std()
        rx1 = 0.5 + 0.11 * r1 + 0.16 * r2                      # unregelmäßige Strahlen, nur x-abhängig
        sway = (UY / 360.0) * 18 * np.sin(UX / 60 + k)        # Strahlen leicht geneigt/gewellt
        rays = map_coordinates(np.repeat(rx1[None, :], H, 0), [YY, np.clip(XX + sway * U, 0, W - 1)], order=1)
        streak = 0.3 + 0.9 * band(rays, 0.38, 0.85)
        height = 70 + 50 * fbm(45 + k, 3, 2)
        a = (above > 0) * np.exp(-np.clip(above, 0, None) / height) * streak
        a += np.exp(-(np.clip(above, 0, None) / 3.0) ** 2) * (above > -12) * np.exp(-np.clip(-above, 0, None) / 4.0) * 0.8 * streak       # heller Saum, nach unten weich auslaufend
        a *= ss((UX + 100) / 120) * ss((470 - UX) / 170)
        col = ramp(np.clip(above / 90, 0, 1), [(0, cA), (0.5, "#40c0ff"), (1, cB)])
        img += (a * gain * 0.75)[..., None] * col
    # Eiskristalle funkeln
    for i in range(60):
        x = rng.uniform(-100, 740); y = rng.uniform(140, 360)
        if 90 < x < 550 and y > 225: continue
        add(img, glow(x, y, 0.55), "#e0faff", 1.0)
    text_calm(img, 0.3)
    lay = layer("s4_magnetar.png")
    bloom(img, lay, 5, 0.45)                      # Feldlinien leuchten in den Raum
    comp(img, pixelize(lay, 22))
    bloom(img, lay, 1.4, 0.55, thr=120)
    # Polstrahlen entlang der Magnetachse
    cx, cy = 548.0, 66.0
    ax = np.array([0.38, -1.0]); ax /= np.linalg.norm(ax)
    for sgn in (1, -1):
        px, py = UX - cx, UY - cy
        along = (px * ax[0] + py * ax[1]) * sgn
        across = np.abs(-px * ax[1] + py * ax[0])
        wdt = 0.8 + along * 0.07
        reach = 55.0 if sgn < 0 else 75.0             # der untere Strahl endet vor dem Flugband
        beam = (along > 3) * np.exp(-(across / wdt) ** 2) * np.exp(-np.clip(along, 0, None) / (reach * 0.45)) * ss((reach - along) / 20)
        add(img, beam, "#a8e8ff", 1.0)
        add(img, (along > 3) * np.exp(-(across / (wdt * 4)) ** 2) * np.exp(-np.clip(along, 0, None) / (reach * 0.4)), "#5070ff", 0.3)
    add(img, glow(cx, cy, 14), "#a0e0ff", 0.55)
    add(img, glow(cx, cy, 60), "#4060c0", 0.25)
    return img

# ---------------------------------------------------------------- Sektor 5 Sonnenschmiede
def s5():
    img = vgrad([(0, "#1a0604"), (200, "#140404"), (360, "#080202")])
    n = warped(51, 110)
    add(img, band(n, 0.45, 0.8), "#601408", 0.6)
    add(img, band(warped(52, 80), 0.6, 0.85), "#a03010", 0.35)
    stars(img, 5, 160, bright=0.6, cols=("#ffd0a0", "#ffe8d0"))
    # Riesensonne links oben, angeschnitten
    cx, cy, r = -20.0, 20.0, 150.0
    d = dist(cx, cy)
    add(img, np.exp(-np.clip(d - r, 0, None) / 30) * (d > r), "#ff6a20", 0.8)
    add(img, np.exp(-np.clip(d - r, 0, None) / 110) * (d > r), "#a02a08", 0.6)
    # Korona-Strahlen
    ang = np.arctan2(UY - cy, UX - cx)
    cor = band(fbm(53, 4, 3, w=W, h=H), 0.3, 0.8)
    spikes = 0.5 + 0.5 * np.sin(ang * 23 + fbm(54, 3, 2) * 8)
    add(img, (d > r) * np.exp(-np.clip(d - r, 0, None) / 55) * spikes * cor, "#ffa040", 0.5)
    inside = d <= r
    # Granulation: Konvektionszellen (Voronoi), Supergranulation (fbm), Sonnenflecken mit Halbschatten
    from scipy.spatial import cKDTree
    rngg = np.random.default_rng(55)
    npts = 30000
    pa = rngg.uniform(0, 2 * math.pi, npts); pr = r * np.sqrt(rngg.uniform(0, 1.04, npts))
    pts = np.stack([cx + np.cos(pa) * pr, cy + np.sin(pa) * pr], 1)
    iy, ix = np.nonzero(inside)
    q = np.stack([UX[iy, ix], UY[iy, ix]], 1)
    dd2, _ = cKDTree(pts).query(q, k=2)
    cellv = np.zeros_like(UX); cellv[iy, ix] = np.clip((dd2[:, 1] - dd2[:, 0]) / 1.2, 0, 1) ** 0.6
    lim = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
    gran = 0.3 * cellv + 0.7 * fbm(55, 6, 10)
    spots = np.zeros_like(UX)
    for (sx_, sy_, sr) in ((60, 55, 7), (72, 62, 4), (25, 110, 5.5), (95, 15, 3.5)):
        ds = dist(sx_, sy_) / sr
        spots += np.clip(1.2 - ds, 0, 1) * 0.55 + (ds < 0.55) * 0.45
    t = np.clip(lim * 0.75 + (gran - 0.5) * 0.75 + 0.15 - np.clip(spots, 0, 1) * 0.85 * lim, 0, 1)
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    t = np.floor(t * 8 + thr * 0.9) / 8
    sun = ramp(t, [(0, "#7a1a04"), (0.35, "#d84a10"), (0.65, "#ff9a30"), (0.9, "#ffd870"), (1, "#fff4c0")])
    img[inside] = sun[inside]
    # Protuberanzen: Bögen am Rand
    for a0, span, h_, w_ in ((0.25, 0.22, 34, 3.2), (0.9, 0.16, 22, 2.5), (1.35, 0.25, 40, 3.0)):
        a1, a2 = a0 - span / 2, a0 + span / 2
        p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1)); p2 = (cx + r * math.cos(a2), cy + r * math.sin(a2))
        mid = ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
        out = (math.cos(a0), math.sin(a0))
        rad = math.dist(p1, p2) / 2
        ccx, ccy = mid
        dd = dist(ccx, ccy)
        # Bogen: Halbellipse nach außen
        lx = (UX - ccx) * out[1] - (UY - ccy) * out[0]
        ly = (UX - ccx) * out[0] + (UY - ccy) * out[1]
        e = np.sqrt((lx / rad) ** 2 + (ly / h_) ** 2)
        fil = fbm(56 + int(a0 * 10), 5, 10)
        arc = np.exp(-((e - 1) * h_ / (w_ * (1.0 + 2.2 * fil))) ** 2) * (ly > -2) * ~inside      # Gasbogen, ungleich dick
        arc *= band(fil, 0.3, 0.55) * (0.6 + 0.4 * band(fbm(59, 4, 18), 0.35, 0.65))                # zerfasert, mit Lücken
        add(img, arc, "#ff6a20", 0.85)
        add(img, arc * band(fil, 0.5, 0.7), "#ffd890", 0.5)
        add(img, np.exp(-np.clip(e - 1, 0, None) * 4) * (e > 0.6) * (ly > 0) * ~inside * 0.25, "#ff4010", 0.6)
    # Rauchschwaden vor dem Rand (dunkel)
    smoke = band(warped(57, 140), 0.55, 0.8) * ss((UY - 120) / 140)
    img *= (1 - 0.55 * smoke)[..., None]
    # Glutfunken
    rng = np.random.default_rng(58)
    for i in range(120):
        x = rng.uniform(-100, 740); y = rng.uniform(60, 360)
        if 90 < x < 550 and y > 225: continue
        if 150 < y < 205 and rng.random() < 0.6: continue
        b = rng.uniform(0.5, 1.3)
        add(img, glow(x, y, 0.5), "#ffb040", b)
        if rng.random() < 0.3:
            add(img, np.exp(-((UY - y) / 0.5) ** 2) * (UX < x) * (UX > x - 4) * 1.0, "#ff6020", 0.5)
    text_calm(img, 0.35)
    lay = layer("s5_forge.png")
    bloom(img, lay, 5, 0.35, thr=120)
    comp(img, pixelize(lay, 20))
    bloom(img, lay, 1.5, 0.6, thr=170)            # Schmelzglut, Spiegel, Barren
    return img

# ---------------------------------------------------------------- Sektor 6 Gezeitenorbit
def s6():
    img = vgrad([(0, "#03122a"), (200, "#04182e"), (360, "#020a18")])
    add(img, band(warped(61, 100), 0.5, 0.78), "#0a4a7a", 0.55)
    add(img, band(warped(62, 70), 0.62, 0.84), "#10a0a8", 0.3)
    stars(img, 6, 300, cols=("#a0e0ff", "#e8f8ff"))
    # Lichtschächte von oben (wie Licht durch Wasser)
    ang = 0.22
    sh = band(np.asarray(Image.fromarray(fbm(63, 5, 3)[0:1, :].repeat(H, 0), mode="F")), 0.55, 0.8)
    shx = map_coordinates(sh, [YY, np.clip(XX + UY * math.tan(ang) * U, 0, W - 1)], order=1)
    add(img, shx * np.exp(-UY / 170), "#40b8ff", 0.35)
    # Gezeitenschleier zwischen Mond und Planet
    add(img, np.exp(-(((UY - (70 - 30 * np.sin(np.clip((UX - 105) / 365, 0, 1) * math.pi))) / 12) ** 2)) * ss((UX - 120) / 60) * ss((480 - UX) / 60), "#20a0c0", 0.2)
    # Atmosphärenhof des Ozeanplaneten (Tagseite links)
    cx, cy, r = 585.0, 30.0, 120.0
    d = dist(cx, cy)
    side = np.clip(0.25 + (-(UX - cx) / r) * 0.8, 0, 1)
    add(img, (d > r) * np.exp(-(d - r) / 9) * side, "#50c8ff", 0.75)
    add(img, (d > r) * np.exp(-(d - r) / 35) * side, "#1a6ab0", 0.35)
    rng = np.random.default_rng(67)
    for i in range(40):
        x = rng.uniform(-100, 740); y = rng.uniform(0, 360)
        if (90 < x < 550 and y > 225) or 150 < y < 205: continue
        add(img, glow(x, y, 0.55), "#c0f8ff", 0.8)
    text_calm(img, 0.3)
    lay = layer("s6_ocean.png")
    comp(img, pixelize(lay, 22))
    bloom(img, lay, 2.0, 0.5, thr=200)            # Sonnenglitzern, Eisbrocken
    return img

# ---------------------------------------------------------------- Sektor 7 Transitknoten
def s7():
    img = vgrad([(0, "#140c22"), (150, "#2a1a2a"), (260, "#1a1020"), (360, "#0c0812")])
    n = warped(71, 110)
    m = band(n, 0.45, 0.75) * (1 - 0.6 * ss((UY - 200) / 100))
    add(img, m, "#c08850", 0.55)
    add(img, band(n, 0.62, 0.82) * (1 - ss((UY - 210) / 80)), "#ffe0a0", 0.45)
    add(img, band(warped(72, 60, 6, 5), 0.62, 0.8) * (1 - ss((UY - 180) / 80)), "#fff0d0", 0.25)
    stars(img, 7, 200, bright=0.7, cols=("#fff0c0", "#ffe0e0"))
    add(img, glow(430, 78, 150), "#ffb060", 0.12)
    # Verkehrsschneisen: Lichterketten zur Station
    lanes = [((-110, 30), (300, 46)), ((-110, 120), (318, 96)), ((750, 150), (560, 104)), ((750, 20), (560, 48))]
    for (x0, y0), (x1, y1) in lanes:
        steps = 34
        for i in range(steps):
            t = i / steps
            x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t + 10 * math.sin(t * math.pi)
            if 150 < y < 205: continue
            col = "#fff0b0" if i % 2 == 0 else "#ff9a50"
            add(img, glow(x, y, 0.6), col, 1.1)
    # Türme der Wolkenstadt unten links/rechts (Silhouette)
    rng = np.random.default_rng(73)
    polys = []
    for side in (-1, 1):
        for i in range(9):
            x = (40 if side < 0 else 600) + rng.uniform(-60, 60)
            hgt = rng.uniform(30, 90); w = rng.uniform(4, 9)
            polys.append(([(x - w, 360), (x - w, 360 - hgt), (x - w * 0.3, 360 - hgt - w * 2), (x + w * 0.3, 360 - hgt - w * 2), (x + w, 360 - hgt), (x + w, 360)], (34, 22, 34, 255)))
    comp(img, poly_layer(polys))
    for pts, _ in polys:
        tx = (pts[2][0] + pts[3][0]) / 2; ty = pts[2][1]
        add(img, glow(tx, ty - 1, 0.7), "#ffd070", 1.2)
        add(img, glow(tx, ty - 1, 4), "#ffb040", 0.2)
    cloud = band(warped(74, 50, 5, 4), 0.45, 0.65) * ss((UY - 290) / 40)
    add(img, cloud * (1 - 0.7 * ss((UX - 100) / 60) * ss((540 - UX) / 60)), "#7a5a6a", 0.4)
    text_calm(img, 0.35)
    lay = layer("s7_station.png")
    bloom(img, lay, 6, 0.18)
    comp(img, pixelize(lay, 18))
    bloom(img, lay, 1.6, 0.6, thr=200)            # Fenster, Positionslichter
    return img

# ---------------------------------------------------------------- Sektor 8 Schattenring
def s8():
    img = vgrad([(0, "#020a06"), (200, "#04120c"), (360, "#020604")])
    add(img, band(warped(81, 100), 0.52, 0.8), "#0c3a24", 0.55)
    add(img, band(warped(82, 70), 0.62, 0.84), "#1a6a50", 0.3)
    stars(img, 8, 340, cols=("#c0ffd8", "#e8fff0"))
    cx, cy, r = 205.0, 78.0, 66.0
    # Gegenlicht-Hof um den Planeten (Streulicht der Sonne dahinter)
    d = dist(cx, cy); ang = np.arctan2(UY - cy, UX - cx)
    lay = layer("s8_eclipse.png")
    a = lay[..., 3] / 255.0
    lum = (lay[..., :3].max(-1) / 255.0) * a
    hy, hx = np.unravel_index(np.argmax(lum * (lum > 0.9) + lum * 0.001), lum.shape)
    sx, sy = (hx - FX) / U, hy / U                  # hellste Stelle am Rand = Sonne lugt hervor
    hot = math.atan2(sy - cy, sx - cx)
    da = np.abs(np.angle(np.exp(1j * (ang - hot))))
    rimk = 0.25 + 0.75 * np.exp(-(da / 0.9) ** 2)
    add(img, (d > r) * np.exp(-(d - r) / 16) * rimk, "#20a070", 0.45)
    add(img, (d > r) * np.exp(-(d - r) / 55) * rimk, "#0c5a3a", 0.35)
    # Dschungelmond oben rechts
    sphere(img, 560, 60, 26, (-1.0, -0.6), [(0, "#020804"), (0.35, "#0c3a1a"), (0.7, "#2a8a3a"), (1, "#b0f0a0")], fbm(85, 6, 10), 0.45, "#a0ffb0", 0.4)
    # einzelne Sporen, nur abseits des Planeten
    rng = np.random.default_rng(84)
    for i in range(70):
        x = rng.uniform(-100, 740); y = rng.uniform(0, 360)
        if (90 < x < 550 and y > 225) or (150 < y < 205 and rng.random() < 0.7) or math.hypot(x - cx, y - cy) < r * 1.6: continue
        c = "#60ff90" if rng.random() < 0.7 else "#40e0ff"
        add(img, glow(x, y, 0.6), c, rng.uniform(0.4, 0.9))
        add(img, glow(x, y, 3.0), c, 0.1)
    text_calm(img, 0.3)
    # Planet + Ring aus Blender, grün eingefärbt
    g = gradmap(lay, [(0, "#010302"), (0.06, "#04140c"), (0.18, "#0c3a22"), (0.4, "#2a9a60"), (0.7, "#90ffc8"), (1, "#f4fff8")])
    comp(img, pixelize(g, 20))
    bloom(img, g, 3.0, 0.5, thr=160)
    # Diamantring-Funke
    add(img, glow(sx, sy, 2.2), "#ffffff", 1.6)
    add(img, glow(sx, sy, 10), "#a0ffd0", 0.55)
    st = np.exp(-((UY - sy) / 0.7) ** 2) * np.exp(-np.abs(UX - sx) / 110)
    st += np.exp(-((UX - sx) / 0.7) ** 2) * np.exp(-np.abs(UY - sy) / 14)
    add(img, st, "#d0ffe8", 0.6)
    return img

# ---------------------------------------------------------------- Sektor 9 Singularitätsrand
def s9():
    img = vgrad([(0, "#05040f"), (200, "#08061a"), (360, "#04030c")])
    n1 = warped(91, 120); n2 = warped(92, 90)
    add(img, band(n1, 0.5, 0.8), "#4a1a6a", 0.6)
    add(img, band(n2, 0.58, 0.84), "#1a2a8a", 0.5)
    add(img, band(n1, 0.7, 0.88), "#c04a8a", 0.35)
    stars(img, 9, 700, cols=("#c0c0ff", "#ffffff", "#ffd8b0"))
    text_calm(img, 0.3)
    # Gravitationslinse: Hintergrund im Umfeld des Lochs nach der Ablenkungskarte umsortieren
    mp = np.load(os.path.join(LAY, "bh_map.npy")); x0, y0, x1, y1 = np.load(os.path.join(LAY, "bh_box.npy"))
    mx, my, esc = mp
    hh0, ww0 = mx.shape
    ubx = (np.arange(x0, x0 + ww0) + 0.5 - FX) / U; uby = (np.arange(y0, y0 + hh0) + 0.5) / U
    ubx, uby = np.meshgrid(ubx, uby)
    rr = np.hypot(ubx - 470.0, (uby - 100.0) * 1.1)
    wl = ss((78.0 - rr) / 42.0)                        # Linsenwirkung läuft zum Kastenrand hin aus (keine Kante)
    mx = ubx + (mx - ubx) * wl; my = uby + (my - uby) * wl
    esc = np.where(wl > 0.999, esc, 1.0) * 1.0
    srcx = np.clip(FX + mx * U, 0, W - 1); srcy = np.clip(my * U, 0, H - 1)
    sub = np.stack([map_coordinates(img[..., k], [srcy, srcx], order=1) for k in range(3)], -1)
    # sanft einblenden am Kastenrand
    hh, ww = sub.shape[:2]
    fy = np.minimum(np.arange(hh), np.arange(hh)[::-1])[:, None]; fx = np.minimum(np.arange(ww), np.arange(ww)[::-1])[None, :]
    f = np.clip(np.minimum(fx, fy) / 40.0, 0, 1)[..., None] * esc[..., None]
    img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - f) + sub * f
    lay = np.load(os.path.join(LAY, "bh_layer.npy"))
    lay8 = np.concatenate([lay[..., :3] * 255, lay[..., 3:4] * 255], -1).astype(np.float32)
    add(img, glow(470, 100, 120), "#ff7030", 0.10)
    bloom(img, lay8, 7, 0.35)
    # Scheibe: weich überblenden (halbdurchsichtiger Außenrand), Farbstufen per Raster
    thr = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    a = lay[..., 3:4]
    c = np.floor(lay[..., :3] * 255 / (255 / 20) + thr[..., None] * 0.85) * (255 / 20)
    img[:] = img * (1 - a) + c * a
    bloom(img, lay8, 1.8, 0.45, thr=200)
    return img
