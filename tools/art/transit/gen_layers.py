"""Zwischenflug-Hintergründe je Zielsektor als Grund + Tiefenebenen (Parallaxe, Runde 68).
Aufruf: python3 gen_layers.py <ausgabeordner> [sektoren…]   (Normalfall über build.sh)
Ausgabe: transit_sN_base.png und transit_sN_<ebene>.png. Namen und Mitziehfaktoren (L.f) müssen zu
TransitionView.LAYERS passen (Test „Zwischenflug-Hintergründe“)."""
import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_transit import *
from gen_transit import s9 as s9_full


def nebula_s1(img):
    n = warped(11, 80)
    add(img, band(n, 0.50, 0.75) * ss((240 - UY) / 120), "#4a2266", 0.55)
    add(img, band(warped(12, 70), 0.55, 0.8) * ss((200 - UY) / 150), "#1e3c80", 0.5)


def s1():
    base = vgrad([(0, "#060818"), (120, "#0d1030"), (215, "#24163e"), (360, "#2a1838")])
    nebula_s1(base); stars(base, 1, 520)
    giant = Lay("giant", 0.03); home = Lay("home", 0.05); harbor = Lay("harbor", 0.11)
    g = layer("s1_giant.png"); comp(giant, pixelize(g, 22)); bloom(giant, g, 4, 0.15)
    h = layer("s1_home.png"); comp(home, pixelize(h, 22)); bloom(home, h, 1.2, 0.35, thr=170)
    R, cy0 = 1100.0, 236.0
    d = dist(320, cy0 + R) - R
    saum = ramp(np.clip(UX / 640.0, 0, 1), [(0, "#ffb060"), (0.45, "#ff7a8a"), (1, "#a070ff")])
    home.light((np.clip(1 - np.abs(d + 0.8) / 1.4, 0, 1) * 0.7)[..., None] * saum)
    home.light(((d >= 0) * np.exp(-d / 12.0) * (0.45 + 0.55 * np.exp(-((UX - 120) / 220) ** 2)) * 0.5)[..., None] * saum)
    sx = 128.0; sy = cy0 + R - math.sqrt(R * R - (sx - 320) ** 2)
    add(home, glow(sx, sy, 7), "#fff2c8", 1.1); add(home, glow(sx, sy, 30), "#ffb060", 0.45)
    add(home, np.exp(-((UY - sy) / 0.9) ** 2) * np.exp(-np.abs(UX - sx) / 150), "#ffd8a0", 0.7)
    text_calm(home, 0.15)
    hb = layer("s1_harbor.png"); comp(harbor, pixelize(hb, 22)); bloom(harbor, hb, 1.4, 0.5, thr=150)
    text_calm(base, 0.15)
    return base, [giant, home, harbor]


def s2():
    base = vgrad([(0, "#0a0418"), (180, "#140828"), (360, "#0c0518")])
    n1 = warped(21, 120); n2 = warped(22, 90)
    add(base, band(n1, 0.52, 0.78), "#a02a8a", 0.55); add(base, band(n2, 0.56, 0.80), "#1a8aa8", 0.45)
    add(base, band(n1, 0.70, 0.86), "#ff60c8", 0.35)
    add(base, band(warped(23, 60, 6, 6), 0.62, 0.8) * band(n2, 0.4, 0.6), "#60f0ff", 0.25)
    stars(base, 2, 460, cols=("#ffb0f0", "#e8ecff", "#a0f8ff")); text_calm(base, 0.3)
    cr = Lay("crystals", 0.10)
    lay = layer("s2_crystals.png")
    bloom(cr, lay, 9, 0.55); comp(cr, pixelize(lay, 14)); bloom(cr, lay, 2.0, 0.35, thr=150)
    return base, [cr]


def s3():
    base = vgrad([(0, "#071418"), (180, "#0c2026"), (360, "#100c0a")])
    n = warped(31, 90)
    add(base, band(n, 0.48, 0.78), "#1a5a5a", 0.6)
    add(base, band(warped(32, 70), 0.6, 0.82) * ss(UY / 200), "#7a4020", 0.45)
    stars(base, 3, 360, bright=0.8)
    add(base, np.exp(-((UY - (70 + 0.10 * (UX - 320))) / 34) ** 2), "#2a5050", 0.35)
    text_calm(base, 0.3)
    wreck = Lay("wreck", 0.05); scrap = Lay("scrap", 0.12)
    for L, name in ((wreck, "s3_wreck.png"), (scrap, "s3_scrap.png")):
        lay = layer(name); lay[..., :3] = np.clip(lay[..., :3] * 1.45 + 6, 0, 255)
        comp(L, pixelize(lay, 16)); bloom(L, lay, 2.5, 0.5, thr=170)
    rng = np.random.default_rng(36)
    for i in range(44):
        x = rng.uniform(-200, 840); y = 70 + 0.10 * (x - 320) + 14 * math.sin(x / 90) + rng.normal(0, 22)
        if 132 < y < 222: continue
        add(scrap, glow(x, y, 0.55), "#ffb060", 1.1); add(scrap, glow(x, y, 2.5), "#ff7020", 0.15)
    return base, [wreck, scrap]


def aurora(img, fade_right=470):
    from scipy.ndimage import gaussian_filter1d
    for k, (base_y, amp, freq, ph, cA, cB, gain) in enumerate([
            (120, 22, 1 / 95, 0.0, "#40ffa0", "#8040ff", 1.0),
            (95, 16, 1 / 70, 2.0, "#30d8c0", "#c050ff", 0.55)]):
        foot = base_y + amp * np.sin(UX * freq * 2 * math.pi / 6.3 + ph) + 8 * np.sin(UX / 23 + ph * 3)
        above = foot - UY
        rng_r = np.random.default_rng(43 + k)
        r1 = gaussian_filter1d(rng_r.standard_normal(W), 2.5); r1 /= r1.std()
        r2 = gaussian_filter1d(rng_r.standard_normal(W), 14.0); r2 /= r2.std()
        rx1 = 0.5 + 0.11 * r1 + 0.16 * r2
        sway = (UY / 360.0) * 18 * np.sin(UX / 60 + k)
        rays = map_coordinates(np.repeat(rx1[None, :], H, 0), [YY, np.clip(XX + sway * U, 0, W - 1)], order=1)
        streak = 0.3 + 0.9 * band(rays, 0.38, 0.85)
        height = 70 + 50 * fbm(45 + k, 3, 2)
        a = (above > 0) * np.exp(-np.clip(above, 0, None) / height) * streak
        a += np.exp(-(np.clip(above, 0, None) / 3.0) ** 2) * (above > -12) * np.exp(-np.clip(-above, 0, None) / 4.0) * 0.8 * streak
        a *= ss((UX + 210) / 120) * ss((fade_right - UX) / 170)
        col = ramp(np.clip(above / 90, 0, 1), [(0, cA), (0.5, "#40c0ff"), (1, cB)])
        img += (a * gain * 0.75)[..., None] * col


def s4():
    base = vgrad([(0, "#050a18"), (200, "#0a1828"), (360, "#060c16")])
    add(base, band(warped(41, 80), 0.55, 0.8), "#163a5a", 0.5)
    stars(base, 4, 460, cols=("#b0e0ff", "#e8f4ff", "#d0fff0"))
    aurora(base)
    rng = np.random.default_rng(42)
    for i in range(60):
        x = rng.uniform(-200, 840); y = rng.uniform(140, 360)
        if 90 < x < 550 and y > 225: continue
        add(base, glow(x, y, 0.55), "#e0faff", 1.0)
    text_calm(base, 0.3)
    mag = Lay("magnetar", 0.04); moon = Lay("moon", 0.09)
    lay = layer("s4_magnetar.png")
    bloom(mag, lay, 5, 0.45); comp(mag, pixelize(lay, 22)); bloom(mag, lay, 1.4, 0.55, thr=120)
    cx, cy = 548.0, 66.0
    ax = np.array([0.38, -1.0]); ax /= np.linalg.norm(ax)
    for sgn in (1, -1):
        px, py = UX - cx, UY - cy
        along = (px * ax[0] + py * ax[1]) * sgn
        across = np.abs(-px * ax[1] + py * ax[0])
        wdt = 0.8 + along * 0.07
        reach = 55.0 if sgn < 0 else 75.0
        beam = (along > 3) * np.exp(-(across / wdt) ** 2) * np.exp(-np.clip(along, 0, None) / (reach * 0.45)) * ss((reach - along) / 20)
        add(mag, beam, "#a8e8ff", 1.0)
        add(mag, (along > 3) * np.exp(-(across / (wdt * 4)) ** 2) * np.exp(-np.clip(along, 0, None) / (reach * 0.4)), "#5070ff", 0.3)
    add(mag, glow(cx, cy, 14), "#a0e0ff", 0.55); add(mag, glow(cx, cy, 60), "#4060c0", 0.25)
    m = layer("s4_moon.png"); comp(moon, pixelize(m, 22)); bloom(moon, m, 2, 0.5, thr=150)
    return base, [mag, moon]


def s5():
    # Sonne, Korona, Protuberanzen, Rauch: alles fern -> Grund (aus dem bisherigen Generator)
    from gen_transit import s5 as s5_old
    import gen_transit as gt
    orig_layer = gt.layer
    gt.layer = lambda name: np.zeros((H, W, 4), np.float32)          # Schmiede-Ebene dort leer lassen
    rng_state = None
    base = s5_old()
    gt.layer = orig_layer
    forge = Lay("forge", 0.08); embers = Lay("embers", 0.16)
    lay = layer("s5_forge.png")
    bloom(forge, lay, 5, 0.35, thr=120); comp(forge, pixelize(lay, 20)); bloom(forge, lay, 1.5, 0.6, thr=170)
    rng = np.random.default_rng(59)
    for i in range(90):
        x = rng.uniform(-200, 840); y = rng.uniform(60, 360)
        if 90 < x < 550 and y > 225: continue
        if 150 < y < 205 and rng.random() < 0.6: continue
        add(embers, glow(x, y, 0.55), "#ffb040", rng.uniform(0.6, 1.4))
        add(embers, np.exp(-((UY - y) / 0.5) ** 2) * (UX < x) * (UX > x - 5), "#ff6020", 0.5)
    return base, [forge, embers]


def s6():
    base = vgrad([(0, "#03122a"), (200, "#04182e"), (360, "#020a18")])
    add(base, band(warped(61, 100), 0.5, 0.78), "#0a4a7a", 0.55)
    add(base, band(warped(62, 70), 0.62, 0.84), "#10a0a8", 0.3)
    stars(base, 6, 380, cols=("#a0e0ff", "#e8f8ff"))
    ang = 0.22
    sh = band(np.asarray(Image.fromarray(fbm(63, 5, 3)[0:1, :].repeat(H, 0), mode="F")), 0.55, 0.8)
    shx = map_coordinates(sh, [YY, np.clip(XX + UY * math.tan(ang) * U, 0, W - 1)], order=1)
    add(base, shx * np.exp(-UY / 170), "#40b8ff", 0.35)
    text_calm(base, 0.3)
    planet = Lay("planet", 0.03); moon = Lay("moon", 0.08)
    cx, cy, r = 585.0, 30.0, 120.0
    d = dist(cx, cy)
    side = np.clip(0.25 + (-(UX - cx) / r) * 0.8, 0, 1)
    add(planet, (d > r) * np.exp(-(d - r) / 9) * side, "#50c8ff", 0.75)
    add(planet, (d > r) * np.exp(-(d - r) / 35) * side, "#1a6ab0", 0.35)
    p = layer("s6_planet.png"); comp(planet, pixelize(p, 22)); bloom(planet, p, 2.0, 0.5, thr=200)
    add(moon, np.exp(-(((UY - (70 - 30 * np.sin(np.clip((UX - 105) / 365, 0, 1) * math.pi))) / 12) ** 2)) * ss((UX - 120) / 60) * ss((480 - UX) / 60), "#20a0c0", 0.2)
    m = layer("s6_moon.png"); comp(moon, pixelize(m, 22)); bloom(moon, m, 2.0, 0.6, thr=180)
    return base, [planet, moon]


def s7():
    base = vgrad([(0, "#140c22"), (150, "#2a1a2a"), (260, "#1a1020"), (360, "#0c0812")])
    n = warped(71, 110)
    add(base, band(n, 0.45, 0.75) * (1 - 0.6 * ss((UY - 200) / 100)), "#c08850", 0.55)
    add(base, band(n, 0.62, 0.82) * (1 - ss((UY - 210) / 80)), "#ffe0a0", 0.45)
    add(base, band(warped(72, 60, 6, 5), 0.62, 0.8) * (1 - ss((UY - 180) / 80)), "#fff0d0", 0.25)
    stars(base, 7, 260, bright=0.7, cols=("#fff0c0", "#ffe0e0"))
    add(base, glow(430, 78, 150), "#ffb060", 0.12)
    text_calm(base, 0.35)
    station = Lay("station", 0.06); city = Lay("city", 0.13)
    lay = layer("s7_station.png")
    bloom(station, lay, 6, 0.18); comp(station, pixelize(lay, 18)); bloom(station, lay, 1.6, 0.6, thr=200)
    rng = np.random.default_rng(73)
    polys = []
    for side in (-1, 1):
        for i in range(12):
            x = (0 if side < 0 else 640) + rng.uniform(-150, 110) * (1 if side < 0 else -1)
            hgt = rng.uniform(30, 90); w = rng.uniform(4, 9)
            polys.append(([(x - w, 360), (x - w, 360 - hgt), (x - w * 0.3, 360 - hgt - w * 2), (x + w * 0.3, 360 - hgt - w * 2), (x + w, 360 - hgt), (x + w, 360)], (34, 22, 34, 255)))
    comp(city, poly_layer(polys))
    for pts, _ in polys:
        tx = (pts[2][0] + pts[3][0]) / 2; ty = pts[2][1]
        add(city, glow(tx, ty - 1, 0.7), "#ffd070", 1.2); add(city, glow(tx, ty - 1, 4), "#ffb040", 0.2)
    cloud = band(warped(74, 50, 5, 4), 0.45, 0.65) * ss((UY - 290) / 40)
    cm = cloud * (1 - 0.7 * ss((UX - 100) / 60) * ss((540 - UX) / 60))
    city.P = city.P * (1 - cm[..., None] * 0.5) + (cm * 0.5)[..., None] * C("#7a5a6a")
    city.A = cm * 0.5 + city.A * (1 - cm * 0.5)
    return base, [station, city]


def s8():
    base = vgrad([(0, "#020a06"), (200, "#04120c"), (360, "#020604")])
    add(base, band(warped(81, 100), 0.52, 0.8), "#0c3a24", 0.55)
    add(base, band(warped(82, 70), 0.62, 0.84), "#1a6a50", 0.3)
    stars(base, 8, 420, cols=("#c0ffd8", "#e8fff0"))
    text_calm(base, 0.3)
    planet = Lay("planet", 0.03); moon = Lay("moon", 0.06); spores = Lay("spores", 0.15)
    cx, cy, r = 205.0, 78.0, 66.0
    lay = layer("s8_planet.png")
    a = lay[..., 3] / 255.0
    lum = (lay[..., :3].max(-1) / 255.0) * a
    hy, hx = np.unravel_index(np.argmax(lum * (lum > 0.9) + lum * 0.001), lum.shape)
    sx, sy = (hx - FX) / U, hy / U
    hot = math.atan2(sy - cy, sx - cx)
    d = dist(cx, cy); ang = np.arctan2(UY - cy, UX - cx)
    da = np.abs(np.angle(np.exp(1j * (ang - hot))))
    rimk = 0.25 + 0.75 * np.exp(-(da / 0.9) ** 2)
    add(planet, (d > r) * np.exp(-(d - r) / 16) * rimk, "#20a070", 0.45)
    add(planet, (d > r) * np.exp(-(d - r) / 55) * rimk, "#0c5a3a", 0.35)
    g = gradmap(lay, [(0, "#010302"), (0.06, "#04140c"), (0.18, "#0c3a22"), (0.4, "#2a9a60"), (0.7, "#90ffc8"), (1, "#f4fff8")])
    comp(planet, pixelize(g, 20)); bloom(planet, g, 3.0, 0.5, thr=160)
    add(planet, glow(sx, sy, 2.2), "#ffffff", 1.6); add(planet, glow(sx, sy, 10), "#a0ffd0", 0.55)
    st = np.exp(-((UY - sy) / 0.7) ** 2) * np.exp(-np.abs(UX - sx) / 110) + np.exp(-((UX - sx) / 0.7) ** 2) * np.exp(-np.abs(UY - sy) / 14)
    add(planet, st, "#d0ffe8", 0.6)
    sphere(moon, 560, 60, 26, (-1.0, -0.6), [(0, "#020804"), (0.35, "#0c3a1a"), (0.7, "#2a8a3a"), (1, "#b0f0a0")], fbm(85, 6, 10), 0.45, "#a0ffb0", 0.4)
    rng = np.random.default_rng(84)
    for i in range(90):
        x = rng.uniform(-200, 840); y = rng.uniform(0, 360)
        if (90 < x < 550 and y > 225) or (150 < y < 205 and rng.random() < 0.7) or math.hypot(x - cx, y - cy) < r * 1.6: continue
        c = "#60ff90" if rng.random() < 0.7 else "#40e0ff"
        add(spores, glow(x, y, 0.6), c, rng.uniform(0.4, 0.9)); add(spores, glow(x, y, 3.0), c, 0.1)
    return base, [planet, moon, spores]


def s9():
    return s9_full(), []


GENS = {1: s1, 2: s2, 3: s3, 4: s4, 5: s5, 6: s6, 7: s7, 8: s8, 9: s9}
if __name__ == "__main__":
    out = sys.argv[1]
    which = [int(a) for a in sys.argv[2:]] or list(range(1, 10))
    for s in which:
        base, lays = GENS[s]()
        finish(base, f"{out}/transit_s{s}_base.png")
        for L in lays:
            finish_lay(L, f"{out}/transit_s{s}_{L.name}.png")
        print("ok", s, [["base", 0.012]] + [[L.name, L.f] for L in lays])
