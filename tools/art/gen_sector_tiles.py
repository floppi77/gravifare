"""Fels-Materialien der neun Sektoren (Runde 63): je Sektor ein eigenes Material passend zu Name und Hintergrund, dazu Kanten- und Eckkacheln nach
Nachbarschaft und Abwandlungen im Inneren. Schreibt assets/art/tiles_sN.png (768×144) und die Normal-Map tiles_sN_n.png.

Atlas (Kachel 48 px = 16 Einheiten, 3 px je Einheit):
  Zeile 0: 0–3 Innenflächen, 4 Plattform, 5 Tankpad, 6 Dornen (4–6 unverändert aus tiles_s1.png vor Runde 63: Funktionsfarben bleiben gleich),
           7–9 tiefe Innenflächen, 10–15 weitere Abwandlungen (selten, nur tief im Fels). Die Werkstatt nutzt weiter die Felder 0–9 dieser Zeile.
  Zeile 1: Randkacheln, Spalte = Maske der offenen Nachbarn (1 = oben, 2 = rechts, 4 = unten, 8 = links), 0 = Innenfläche ohne Merkmale.
  Zeile 2: 0–3 Innenecken (oben rechts, unten rechts, unten links, oben links) als Auflage, wenn nur der schräge Nachbar offen ist.
Das Grundmaterial ist kachelbar (Periode 48 px): Innen- und Randkacheln stoßen nahtlos aneinander; Merkmale der Abwandlungen bleiben 6 px vom Rand weg.
Eigene Arbeit, nur numpy/Pillow, fester Zufallssamen (Ausgabe bitgleich). Aufruf aus der Projektwurzel: python3 tools/art/gen_sector_tiles.py [Sektor …]"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw

T = 48
COLS, ROWS = 16, 3
OUT = "assets/art/"
FUNC = "tools/art/tiles_func.png"          # Plattform, Tankpad, Dornen (48×144 je Zeile): Funktionsfarben, unverändert für alle Sektoren
LEGACY_S1 = "tools/art/tiles_s1_legacy.png"  # Metallplatten des Sternenhafens (bisheriges tiles_s1.png, Felder 0–3 und 7–9)

def hexc(h):
    h = h.lstrip("#"); return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=float)

def pnoise(seed, beta=2.2, size=T):
    """Kachelbares Rauschen (periodisch in beiden Richtungen) über eine 1/f^beta-Filterung im Frequenzraum, normiert auf 0..1."""
    rng = np.random.default_rng(seed)
    w = rng.normal(size=(size, size))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(size)[:, None]; kx = np.fft.fftfreq(size)[None, :]
    k = np.sqrt(kx * kx + ky * ky); k[0, 0] = 1.0
    f *= 1.0 / k ** (beta / 2.0); f[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)

GRAIN = 0.11          # Pixelkörnung vor dem Stufen: Kanten zwischen den Tonstufen werden ausgefranst statt glatt (Pixel-Art)

def ramp(cols, v, seed=0):
    """Wert 0..1 auf eine Farbrampe (Liste von Hex-Farben, dunkel zuerst) abbilden, in festen Stufen (Pixel-Art statt Verlauf)."""
    c = np.array([hexc(x) for x in cols])
    v = v + (np.random.default_rng(seed + 77).random(v.shape) - 0.5) * GRAIN
    idx = np.clip((v * len(cols)).astype(int), 0, len(cols) - 1)
    return c[idx]

# ------------------------------------------------------------------ Materialien je Sektor
# base(seed) -> (rgb 48×48×3) kachelbar; feature(img, rng, k) zeichnet Merkmale der Abwandlung k (Abstand 6 px zum Rand)
# edge: Farben für Kanten (ink = Kontur, cap = Licht der Oberkante, side = Seitenfase, under = Unterseite)

def mat_metal(seed):
    return None      # Sternenhafen: bisherige Metallplatten (siehe LEGACY_S1)

def mat_crystal(seed):
    n = pnoise(seed, 2.6); m = pnoise(seed + 1, 1.6)
    v = np.clip(0.55 * n + 0.45 * m, 0, 1)
    rgb = ramp(["#140c26", "#1e1236", "#2a1a48", "#38245c", "#4a3270"], v, seed)
    vein = (np.abs(pnoise(seed + 2, 2.0) - 0.5) < 0.018)          # feine Leuchtadern
    rgb[vein] = hexc("#7a4ac8")
    return rgb

def mat_rust(seed):
    n = pnoise(seed, 2.4); s = pnoise(seed + 3, 1.2)
    streak = np.tile(pnoise(seed + 4, 3.0)[0:1, :], (T, 1))      # senkrechte Rostläufe
    v = np.clip(0.5 * n + 0.3 * s + 0.2 * streak, 0, 1)
    rgb = ramp(["#2a1610", "#3e2214", "#5a3018", "#77401c", "#93562a", "#a8703a"], v, seed)
    for y in (0, 47):                                             # Blechstoß mit Nieten an der Kachelgrenze (periodisch)
        rgb[y, :] = hexc("#2a1610")
    for x in range(6, 48, 12):
        for y in (2, 45):
            rgb[y, x] = hexc("#c08a52"); rgb[y + 1 if y == 2 else y - 1, x] = hexc("#2a1610")
    return rgb

def mat_icesteel(seed):
    n = pnoise(seed, 3.0)
    brush = np.tile(pnoise(seed + 5, 2.0)[:, 0:1], (1, T))       # waagrecht gebürstet
    v = np.clip(0.45 * n + 0.55 * brush, 0, 1)
    rgb = ramp(["#1c2a3a", "#26384c", "#30465c", "#3c566e", "#4a6880"], v, seed)
    frost = pnoise(seed + 6, 1.1) > 0.78
    rgb[frost] = rgb[frost] * 0.4 + hexc("#cfe6f5") * 0.6
    rgb[0, :] = hexc("#5a7890"); rgb[24, :] = hexc("#5a7890")     # Plattenstöße (Periode 24)
    rgb[23, :] = hexc("#16202c"); rgb[47, :] = hexc("#16202c")
    return rgb

def mat_basalt(seed):
    n = pnoise(seed, 2.8)
    yy, xx = np.mgrid[0:T, 0:T]
    col = ((xx + (yy // 16) * 8) % 16 == 0) | ((yy % 16 == 0) & (((xx + (yy // 16) * 8) // 16) % 2 == 0))       # Säulenfugen, versetzt
    v = np.clip(n, 0, 1)
    rgb = ramp(["#120e10", "#1c1618", "#262022", "#302a2a", "#3a3232"], v, seed)
    rgb[col] = hexc("#0a0708")
    return rgb

def mat_reefsteel(seed):
    n = pnoise(seed, 2.6)
    v = np.clip(n, 0, 1)
    rgb = ramp(["#0c2426", "#123234", "#184042", "#1e4e50", "#265c5c"], v, seed)
    rgb[0, :] = hexc("#2e6a68"); rgb[47, :] = hexc("#081a1c")     # Plattenstoß
    rgb[:, 0] = hexc("#2e6a68"); rgb[:, 47] = hexc("#081a1c")
    algae = pnoise(seed + 7, 1.4) > 0.72
    rgb[algae] = rgb[algae] * 0.45 + hexc("#2f7a3a") * 0.55
    return rgb

def mat_concrete(seed):
    n = pnoise(seed, 3.2)
    v = np.clip(n, 0, 1)
    rgb = ramp(["#2c2620", "#36302a", "#403a32", "#4a443a", "#544c42"], v, seed)
    yy, xx = np.mgrid[0:T, 0:T]
    grout = (yy % 12 == 11) | ((xx + (yy // 12 % 2) * 6) % 12 == 11)        # Fliesenraster mit versetzten Reihen (Periode 48)
    rgb[grout] = rgb[grout] * 0.55
    return rgb

def mat_stone(seed):
    n = pnoise(seed, 2.4)
    yy, xx = np.mgrid[0:T, 0:T]
    row = yy // 16
    off = np.array([0, 9, 4])[row]
    joint = (yy % 16 == 15) | (((xx + off) % 24) == 23)               # Quader, je Reihe versetzt (Periode 48)
    v = np.clip(n, 0, 1)
    rgb = ramp(["#141a16", "#1c241e", "#242e26", "#2c382e", "#344236"], v, seed)
    rgb[joint] = hexc("#0a0f0c")
    moss = pnoise(seed + 8, 1.3) > 0.7
    rgb[moss & ~joint] = rgb[moss & ~joint] * 0.5 + hexc("#2f6a3a") * 0.5
    return rgb

def mat_void(seed):
    n = pnoise(seed, 2.2)
    v = np.clip(n, 0, 1)
    rgb = ramp(["#07060e", "#0d0b18", "#141124", "#1b1730", "#231e3c"], v, seed)
    crack = np.abs(pnoise(seed + 9, 2.3) - 0.5) < 0.014
    rgb[crack] = hexc("#5a3aa8")
    return rgb

# Merkmale der Abwandlungen ------------------------------------------------
def f_crystal(d, rng, k):
    for _ in range(1 + k % 3):
        cx, cy = rng.integers(10, 38), rng.integers(12, 38)
        h = rng.integers(8, 14); w = rng.integers(3, 5)
        col = ["#3fd8ff", "#c060ff", "#8a6aff"][int(rng.integers(0, 3))]
        d.polygon([(cx - w, cy), (cx, cy - h), (cx + w, cy), (cx, cy + w)], fill=col)
        d.polygon([(cx - w, cy), (cx, cy - h), (cx, cy + w)], fill="#e8d8ff")
        d.line([(cx, cy - h), (cx, cy + w)], fill="#2a1a48")

def f_rust(d, rng, k):
    if k % 3 == 1:                                                   # Flickblech (nur in jeder dritten Abwandlung), schräg versetzt
        x0, y0 = int(rng.integers(7, 14)), int(rng.integers(8, 16)); w, h = int(rng.integers(22, 30)), int(rng.integers(16, 24))
        d.polygon([(x0, y0 + 2), (x0 + w, y0), (x0 + w - 1, y0 + h), (x0 + 1, y0 + h + 1)], fill=["#6a3a22", "#5a3418", "#7a4a2a"][k % 3], outline="#1e100a")
        for (px, py) in ((x0 + 2, y0 + 3), (x0 + w - 2, y0 + 2), (x0 + 3, y0 + h - 1), (x0 + w - 3, y0 + h - 2)):
            d.point((px, py), fill="#c8986a")
    elif k % 3 == 2:
        x, y = int(rng.integers(12, 32)), int(rng.integers(12, 32))
        d.ellipse([x, y, x + 4, y + 3], fill="#100806"); d.point((x + 1, y), fill="#a8703a")      # Rostloch

def f_icesteel(d, rng, k):
    for _ in range(2):
        x, y = rng.integers(8, 40), rng.integers(8, 40)
        d.rectangle([x, y, x + 2, y + 2], fill="#8aa4b8"); d.point((x, y), fill="#e8f6ff")
    if k % 2 == 0:
        x = rng.integers(10, 30); d.line([(x, 10), (x + 10, 10)], fill="#e8f6ff")    # Reifkante

def f_basalt(d, rng, k):
    x, y = rng.integers(10, 30), rng.integers(8, 16)
    pts = [(x, y)]
    for _ in range(4):
        x += int(rng.integers(-3, 4)); y += int(rng.integers(5, 8)); pts.append((x, min(y, 41)))
    d.line(pts, fill="#ff6a1a", width=1)
    for p in pts[1:-1]:
        d.point(p, fill="#ffd060")

def f_reef(d, rng, k):
    for _ in range(3 + k % 2):                                       # Seepocken
        x, y = rng.integers(8, 38), rng.integers(8, 38)
        d.ellipse([x, y, x + 3, y + 3], fill="#a8b8a0", outline="#3a4a3a")

def f_concrete(d, rng, k):
    x, y = rng.integers(8, 20), rng.integers(8, 20)
    d.line([(x, y), (x + 6, y + 5), (x + 9, y + 14), (x + 16, y + 18)], fill="#1e1a16")       # Riss
    if k % 2:
        d.rectangle([22, 22, 33, 33], fill="#5a6a7a")                # einzelne blaue Fliese
        d.line([(22, 22), (33, 22)], fill="#8a9aaa")

def f_stone(d, rng, k):
    for _ in range(2):
        x = rng.integers(8, 38)
        l = rng.integers(8, 20)
        d.line([(x, 8), (x + 1, 8 + l)], fill="#2f6a3a")             # Ranke
        d.point((x + 1, 8 + l), fill="#6ff0e0") if k % 2 else None

def f_void(d, rng, k):
    x, y = rng.integers(10, 36), rng.integers(10, 36)
    d.ellipse([x, y, x + 3, y + 3], fill="#a78cff")                  # Splitterlicht
    d.line([(x + 1, y + 4), (x - 2, y + 12)], fill="#5a3aa8")

def f_metal(d, rng, k):
    pass

SECTORS = {
    1: dict(mat=mat_metal, feat=f_metal, ink="#0c0f24", cap="#c4d0ff", side="#7f8fe0", under="#0c0f24"),
    2: dict(mat=mat_crystal, feat=f_crystal, ink="#08040f", cap="#d8a8ff", side="#7a4ac8", under="#0a0614"),
    3: dict(mat=mat_rust, feat=f_rust, ink="#120804", cap="#e0a060", side="#8a5a30", under="#140a06"),
    4: dict(mat=mat_icesteel, feat=f_icesteel, ink="#0a121a", cap="#eaf6ff", side="#8fb4cc", under="#0c1620"),
    5: dict(mat=mat_basalt, feat=f_basalt, ink="#060404", cap="#ff8a3a", side="#4a3a36", under="#080404"),
    6: dict(mat=mat_reefsteel, feat=f_reef, ink="#041214", cap="#7ae8c8", side="#3a8a82", under="#04100e"),
    7: dict(mat=mat_concrete, feat=f_concrete, ink="#120e0a", cap="#e0c890", side="#7a6a54", under="#100c08"),
    8: dict(mat=mat_stone, feat=f_stone, ink="#050806", cap="#6aa860", side="#3a4a3a", under="#040604"),
    9: dict(mat=mat_void, feat=f_void, ink="#030208", cap="#a78cff", side="#3a2f70", under="#040310"),
}

# ------------------------------------------------------------------ Kanten
def edge_tile(base, mask, cfg):
    """Randkachel: Grundmaterial plus Kontur, Fasen und abgerundete Außenecken an den offenen Seiten (mask: 1 oben, 2 rechts, 4 unten, 8 links)."""
    a = np.dstack([base.copy(), np.full((T, T), 255.0)])
    ink, cap, side, under = hexc(cfg["ink"]), hexc(cfg["cap"]), hexc(cfg["side"]), hexc(cfg["under"])
    n_, e_, s_, w_ = mask & 1, mask & 2, mask & 4, mask & 8
    def blend(region, col, k):
        a[region, :3] = a[region, :3] * (1 - k) + col * k
    yy, xx = np.mgrid[0:T, 0:T]
    if s_:
        blend((yy >= T - 7) & (yy < T - 2), under, 0.45)
        blend((yy >= T - 2), ink, 1.0)
    if e_:
        blend((xx >= T - 5) & (xx < T - 2), under, 0.35)
        blend((xx >= T - 2), ink, 1.0)
    if w_:
        blend((xx >= 2) & (xx < 4), side, 0.55)
        blend((xx < 2), ink, 1.0)
    if n_:
        blend((yy >= 2) & (yy < 4), cap, 0.85)
        blend((yy >= 4) & (yy < 6), cap, 0.30)
        blend((yy < 2), ink, 1.0)
    r = 5                                                            # Außenecken runden: Pixel außerhalb des Viertelkreises werden durchsichtig
    for (open_a, open_b, cx, cy) in ((n_, w_, r, r), (n_, e_, T - 1 - r, r), (s_, w_, r, T - 1 - r), (s_, e_, T - 1 - r, T - 1 - r)):
        if open_a and open_b:
            dx = xx - cx; dy = yy - cy
            quad = ((xx < cx) if cx < T / 2 else (xx > cx)) & ((yy < cy) if cy < T / 2 else (yy > cy))
            dist = np.sqrt(dx * dx + dy * dy)
            a[quad & (dist > r + 0.5), 3] = 0
            ring = quad & (dist > r - 1.6) & (dist <= r + 0.5)
            a[ring, :3] = ink
    return a

def inner_corner(which, cfg):
    """Innenecke als Auflage: Schräg-Nachbar offen, beide geraden Nachbarn Fels. which: 0 oben rechts, 1 unten rechts, 2 unten links, 3 oben links."""
    a = np.zeros((T, T, 4))
    ink, cap = hexc(cfg["ink"]), hexc(cfg["cap"])
    cx = T - 1 if which in (0, 1) else 0
    cy = 0 if which in (0, 3) else T - 1
    for d in range(3):
        for e in range(3 - d):
            x = cx - d if cx else cx + d
            y = cy + e if cy == 0 else cy - e
            a[y, x, :3] = ink if d + e < 2 else (cap if cy == 0 else ink * 1.4)
            a[y, x, 3] = 255
    return a

def normal_map(img):
    """Normal-Map wie gen_art.tiles_normal: Relief aus der Helligkeit, je Kachel getrennt."""
    from scipy.ndimage import gaussian_filter, sobel
    a = np.array(img).astype(float)
    out = np.zeros_like(a); out[..., 0] = 128; out[..., 1] = 128; out[..., 2] = 255; out[..., 3] = 255
    for r in range(ROWS):
        for c in range(COLS):
            tile = a[r * T:(r + 1) * T, c * T:(c + 1) * T]
            lum = (0.3 * tile[..., 0] + 0.59 * tile[..., 1] + 0.11 * tile[..., 2]) / 255.0
            h = gaussian_filter(lum, 0.8, mode="wrap" if r == 0 else "nearest")
            dx = sobel(h, axis=1, mode="nearest") / 8.0; dy = sobel(h, axis=0, mode="nearest") / 8.0
            nx, ny, nz = -dx * 3.0, dy * 3.0, np.ones_like(h)
            ln = np.sqrt(nx * nx + ny * ny + nz * nz)
            blk = (np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5) * 255.0
            blk[tile[..., 3] < 10] = (128, 128, 255)
            out[r * T:(r + 1) * T, c * T:(c + 1) * T, :3] = blk
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

def build(sector):
    cfg = SECTORS[sector]
    atlas = Image.new("RGBA", (COLS * T, ROWS * T), (0, 0, 0, 0))
    func = Image.open(FUNC).convert("RGBA")
    for i, c in enumerate((4, 5, 6)):
        atlas.paste(func.crop((i * T, 0, (i + 1) * T, T)), (c * T, 0))
    if sector == 1:
        legacy = Image.open(LEGACY_S1).convert("RGBA")
        base = np.array(legacy.crop((7 * T, 0, 8 * T, T))).astype(float)[..., :3]        # tiefes Paneel 7 als Grund der Randkacheln
        for c in (0, 1, 2, 3, 7, 8, 9):
            atlas.paste(legacy.crop((c * T, 0, (c + 1) * T, T)), (c * T, 0))
        for c in range(10, 16):
            atlas.paste(legacy.crop(((7 + c % 3) * T, 0, (8 + c % 3) * T, T)), (c * T, 0))
    else:
        base = cfg["mat"](sector * 1000)
        for c in (0, 1, 2, 3, 7, 8, 9) + tuple(range(10, 16)):
            im = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")
            if c not in (0, 7):                                     # 0 und 7 ohne Merkmale: ruhige Flächen
                rng = np.random.default_rng(sector * 100 + c)
                cfg["feat"](ImageDraw.Draw(im), rng, c)
            atlas.paste(im, (c * T, 0))
    for m in range(16):
        t = edge_tile(base, m, cfg) if m else np.dstack([base, np.full((T, T), 255.0)])
        atlas.paste(Image.fromarray(np.clip(t, 0, 255).astype(np.uint8), "RGBA"), (m * T, T))
    for k in range(4):
        atlas.paste(Image.fromarray(np.clip(inner_corner(k, cfg), 0, 255).astype(np.uint8), "RGBA"), (k * T, 2 * T))
    atlas.save(OUT + "tiles_s%d.png" % sector)
    normal_map(atlas).save(OUT + "tiles_s%d_n.png" % sector)
    print("tiles_s%d.png" % sector)

def prepare():
    """Einmalig: Funktionsfelder und Metallplatten aus dem bisherigen tiles_s1.png (480×48) sichern; danach wird tiles_s1.png neu geschrieben."""
    if os.path.exists(FUNC) and os.path.exists(LEGACY_S1):
        return
    old = Image.open(OUT + "tiles_s1.png").convert("RGBA")
    assert old.size == (480, 48), "tiles_s1.png ist schon im neuen Format; Sicherung fehlt"
    old.save(LEGACY_S1)
    f = Image.new("RGBA", (3 * T, T))
    for i, c in enumerate((4, 5, 6)):
        f.paste(old.crop((c * T, 0, (c + 1) * T, T)), (i * T, 0))
    f.save(FUNC)

if __name__ == "__main__":
    prepare()
    for s in ([int(a) for a in sys.argv[1:]] or range(1, 10)):
        build(s)
