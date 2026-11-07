"""Grundformen Runde 2: Haltestellen je Sektor (72×60, Tür und Lampenmast wie bisher), Leben-Symbol (30×18), Statistik-Symbole (16×16).
Haltestellen als Blatt mit 4 px Abstand (Kontur läuft nicht ineinander): base = Wandfläche flach (wird in Aseprite schattiert), top = Details."""
import os, sys, math
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "build/aseprite-workspace/gf_polish/round2/")      # nie nach assets/; Aufruf: python3 tools/art/aseprite/gen_round2.py .
os.makedirs(OUT, exist_ok=True)
def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
def sh(c, f): return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)
OL = hexc("#0c0f24")
W, H, GAP = 72, 60, 4

# Sektor: Wandfarbe (schattiert), Dachfarbe, Akzent, Stil
SH = {
 1: dict(wall="#34407e", roof="#5a68b4", acc="#35e0d2", style="port"),
 2: dict(wall="#3a2466", roof="#5a3a9a", acc="#ff4dd8", style="neon"),
 3: dict(wall="#8a4a2a", roof="#6a5a4a", acc="#ffb060", style="scrap"),
 4: dict(wall="#4a7a9a", roof="#e8f4ff", acc="#8affd0", style="ice"),
 5: dict(wall="#3a2a2a", roof="#9a3a2a", acc="#ff7a30", style="forge"),
 6: dict(wall="#1f6a6a", roof="#2a8a8a", acc="#60d8ff", style="tide"),
 7: dict(wall="#c8b48a", roof="#8a6a3a", acc="#ffe0a0", style="transit"),
 8: dict(wall="#4a3a2a", roof="#2f5a2a", acc="#60ffb0", style="jungle"),
 9: dict(wall="#24203a", roof="#3a3466", acc="#ffa060", style="void"),
}

def door(d):
    d.rectangle([27, 22, 44, H - 1], fill=OL)
    for y in range(24, H):
        t = (y - 24) / (H - 25)
        c = tuple(int(a + (b - a) * t) for a, b in zip((255, 246, 208), (255, 184, 90))) + (255,)
        d.line([29, y, 42, y], fill=c)
    d.rectangle([29, 24, 42, 27], fill=hexc("#7a5a2a"))

def bench(d, col="#c9871f"):
    for bx in (6, 48):
        d.rectangle([bx, 44, bx + 17, 47], fill=hexc(col)); d.rectangle([bx, 47, bx + 17, 48], fill=sh(hexc(col), 0.6))
        d.rectangle([bx + 2, 48, bx + 3, 56], fill=OL); d.rectangle([bx + 14, 48, bx + 15, 56], fill=OL)

def sign(d, col="#ffcb3d"):
    d.rectangle([30, 9, 41, 13], fill=OL); d.rectangle([31, 10, 40, 12], fill=hexc(col))

def shelter(n):
    S = SH[n]; wall, roof, acc = hexc(S["wall"]), hexc(S["roof"]), hexc(S["acc"])
    base = Image.new("RGBA", (W, H)); b = ImageDraw.Draw(base)
    top = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(top)
    st = S["style"]
    # Wand (flach) – Form je Stil
    if st == "tide":
        b.rounded_rectangle([3, 12, W - 4, H - 1], radius=8, fill=wall)
    elif st == "transit":
        b.rectangle([3, 14, W - 4, H - 1], fill=wall)
    else:
        b.rectangle([3, 12, W - 4, H - 1], fill=wall)
    # Fugen / Oberflächen
    if st == "port":
        for x in range(8, W - 6, 9): d.line([x, 19, x, H - 2], fill=sh(wall, 0.65))
    elif st == "neon":
        for x in range(8, W - 6, 9): d.line([x, 19, x, H - 2], fill=sh(wall, 0.7))
        d.line([3, H - 3, W - 4, H - 3], fill=acc); d.line([3, H - 2, W - 4, H - 2], fill=sh(acc, 0.6))
    elif st == "scrap":
        for x in range(4, W - 4, 3): d.line([x, 19, x, H - 2], fill=sh(wall, 0.72) if (x // 3) % 2 else sh(wall, 1.12))
        for (x0, y0, x1, y1, c) in ((6, 30, 20, 40, "#6a7a8a"), (50, 22, 64, 30, "#9a6a3a"), (52, 48, 66, 56, "#5a6a5a")):
            d.rectangle([x0, y0, x1, y1], fill=hexc(c)); d.rectangle([x0, y0, x1, y1], outline=sh(hexc(c), 0.6))
            for px, py in ((x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)): d.point((px, py), fill=hexc("#d8d0c0"))
    elif st == "ice":
        for x in range(8, W - 6, 9): d.line([x, 19, x, H - 2], fill=sh(wall, 0.75))
        d.rectangle([3, H - 4, W - 4, H - 1], fill=hexc("#e8f4ff")); d.line([3, H - 4, W - 4, H - 4], fill=hexc("#ffffff"))
    elif st == "forge":
        for x in range(8, W - 6, 9): d.line([x, 19, x, H - 2], fill=sh(wall, 0.6))
        for vy in (52, 55):
            d.line([6, vy, 22, vy], fill=acc); d.line([49, vy, 65, vy], fill=acc)
    elif st == "tide":
        for cx in (14, 57):
            d.ellipse([cx - 8, 22, cx + 8, 38], fill=hexc("#b8c4d0")); d.ellipse([cx - 6, 24, cx + 6, 36], fill=hexc("#1d4a6a"))
            d.ellipse([cx - 5, 25, cx - 1, 29], fill=hexc("#8ae8ff"))
        for (x, y) in ((5, 56), (8, 52), (63, 55), (66, 50)):
            d.line([x, y, x, H - 1], fill=hexc("#ff7a8a")); d.point((x - 1, y + 1), fill=hexc("#ff7a8a")); d.point((x + 1, y + 2), fill=hexc("#ff7a8a"))
        for (x, y) in ((22, 20), (50, 16), (47, 12)):
            d.ellipse([x, y, x + 2, y + 2], outline=hexc("#c8f4ff"))
    elif st == "transit":
        for x in (5, W - 7):
            d.rectangle([x, 16, x + 2, H - 1], fill=sh(wall, 0.7)); d.line([x, 16, x, H - 1], fill=sh(wall, 1.15))
        d.rectangle([48, 20, 66, 30], fill=hexc("#1a1a22"));
        for i, c in enumerate(("#ffe14a", "#5dff9a", "#ffe14a")):
            d.line([50, 22 + i * 3, 50 + 6 + i * 3, 22 + i * 3], fill=hexc(c))
        d.ellipse([8, 20, 20, 32], fill=hexc("#f4ecd8")); d.ellipse([8, 20, 20, 32], outline=hexc("#8a6a3a"))
        d.line([14, 26, 14, 22], fill=OL); d.line([14, 26, 17, 26], fill=OL)
    elif st == "jungle":
        for y in range(16, H - 1, 4): d.line([3, y, W - 4, y], fill=sh(wall, 0.7))
        leaf = hexc("#3f8a3a"); leaf2 = hexc("#6ac85a")
        for (x0, ln) in ((4, 18), (12, 10), (60, 22), (66, 14), (24, 6), (46, 8)):
            for k in range(ln):
                xx = x0 + round(math.sin(k * 0.7) * 1.2)
                d.point((xx, 18 + k), fill=leaf if k % 3 else leaf2)
                if k % 4 == 0: d.point((xx + 1, 18 + k), fill=leaf2)
        for mx in (8, 20, 52, 63):
            d.rectangle([mx, H - 4, mx + 1, H - 2], fill=hexc("#e8e0c0")); d.rectangle([mx - 1, H - 6, mx + 2, H - 5], fill=acc)
    elif st == "void":
        d.line([3, 30, W - 4, 30], fill=acc); d.line([3, 31, W - 4, 31], fill=sh(acc, 0.5))
        for x in range(10, W - 6, 12): d.line([x, 19, x, H - 2], fill=sh(wall, 1.4))
    door(d)
    bench(d, "#8a6a4a" if st in ("scrap", "jungle") else ("#c8d4e8" if st == "ice" else ("#3a3a46" if st in ("forge", "void") else "#c9871f")))
    # Glas
    if st not in ("tide", "transit"):          # Gezeitenorbit hat Bullaugen, Transitknoten Uhr und Anzeigetafel statt Scheiben
        gl = hexc(S["acc"], 60) if st != "port" else hexc("#7ef0ee", 70)
        for gx in (5, 49):
            d.rectangle([gx, 20, gx + 17, 42], fill=gl)
    # Dach
    if st == "port":
        d.polygon([(0, 14), (6, 4), (W - 7, 4), (W - 1, 14)], fill=sh(roof, 0.8)); d.polygon([(2, 14), (7, 6), (W - 8, 6), (W - 3, 14)], fill=roof)
        d.rectangle([0, 14, W - 1, 17], fill=hexc("#232a5a")); d.rectangle([2, 17, W - 3, 18], fill=acc)
    elif st == "neon":
        d.polygon([(0, 14), (8, 6), (W - 9, 6), (W - 1, 14)], fill=roof)
        d.rectangle([0, 14, W - 1, 17], fill=sh(roof, 0.6)); d.rectangle([1, 17, W - 2, 18], fill=acc)
        for (x, h, c) in ((6, 9, "#8affff"), (11, 6, "#ff8af0"), (58, 8, "#8affff"), (63, 11, "#c88aff"), (52, 5, "#ff8af0")):
            d.polygon([(x - 2, 7), (x, 7 - h), (x + 2, 7)], fill=hexc(c)); d.line([x, 7 - h + 1, x, 6], fill=hexc("#ffffff"))
    elif st == "scrap":
        d.polygon([(0, 16), (4, 5), (W - 3, 8), (W - 1, 16)], fill=roof)
        for x in range(2, W - 2, 4): d.line([x, 7 + x // 24, x, 15], fill=sh(roof, 0.7))
        d.rectangle([0, 15, W - 1, 18], fill=sh(roof, 0.55)); d.point((20, 9), fill=hexc("#d8d0c0")); d.point((50, 10), fill=hexc("#d8d0c0"))
    elif st == "ice":
        d.polygon([(0, 14), (6, 5), (W - 7, 5), (W - 1, 14)], fill=hexc("#6a9ab8"))
        d.rounded_rectangle([-1, 2, W, 12], radius=5, fill=roof); d.line([3, 3, W - 5, 3], fill=hexc("#ffffff"))
        d.rectangle([0, 14, W - 1, 17], fill=hexc("#2a4a6a")); d.rectangle([2, 17, W - 3, 18], fill=acc)
        for (x, l) in ((4, 5), (10, 3), (17, 6), (25, 3), (47, 4), (54, 6), (61, 3), (67, 5)):
            d.polygon([(x - 1, 18), (x + 1, 18), (x, 18 + l)], fill=hexc("#dff6ff"))
    elif st == "forge":
        d.polygon([(0, 14), (6, 4), (W - 7, 4), (W - 1, 14)], fill=roof)
        d.rectangle([10, 1, 26, 6], fill=hexc("#1d3a7a"))
        for x in range(11, 26, 3): d.line([x, 1, x, 6], fill=hexc("#4a7ad8"))
        d.line([10, 3, 26, 3], fill=hexc("#4a7ad8"))
        d.rectangle([0, 14, W - 1, 17], fill=hexc("#2a1a1a")); d.rectangle([2, 17, W - 3, 18], fill=acc)
    elif st == "tide":
        d.pieslice([4, 0, W - 5, 30], 180, 360, fill=roof); d.arc([6, 2, W - 7, 28], 200, 340, fill=sh(roof, 1.5))
        d.rectangle([2, 14, W - 3, 16], fill=sh(roof, 0.6)); d.rectangle([3, 16, W - 4, 17], fill=acc)
    elif st == "transit":
        d.polygon([(1, 16), (8, 6), (W - 9, 6), (W - 2, 16)], fill=roof)
        d.arc([10, 2, W - 11, 22], 180, 360, fill=hexc("#ffe0a0"))
        d.rectangle([0, 14, W - 1, 17], fill=sh(roof, 0.6)); d.rectangle([2, 17, W - 3, 18], fill=acc)
    elif st == "jungle":
        d.polygon([(0, 15), (8, 3), (W - 9, 3), (W - 1, 15)], fill=roof)
        for x in range(2, W - 2, 3): d.line([x, 5 + abs(x - 36) // 12, x + 1, 15], fill=sh(roof, 0.75 if x % 2 else 1.25))
        d.rectangle([0, 15, W - 1, 17], fill=hexc("#2a1f14")); d.rectangle([2, 17, W - 3, 18], fill=acc)
    elif st == "void":
        d.polygon([(0, 16), (14, 4), (W - 15, 4), (W - 1, 16)], fill=roof)
        d.line([14, 4, W - 15, 4], fill=acc); d.line([0, 16, 14, 4], fill=sh(acc, 0.7)); d.line([W - 1, 16, W - 15, 4], fill=sh(acc, 0.7))
        d.rectangle([0, 16, W - 1, 18], fill=hexc("#0c0a18")); d.line([2, 18, W - 3, 18], fill=acc)
    sign(d, "#ffcb3d")
    return base, top

shelters_b = Image.new("RGBA", ((W + GAP) * 9, H)); shelters_t = Image.new("RGBA", ((W + GAP) * 9, H))
for n in range(1, 10):
    b, t = shelter(n)
    shelters_b.alpha_composite(b, ((n - 1) * (W + GAP), 0)); shelters_t.alpha_composite(t, ((n - 1) * (W + GAP), 0))
shelters_b.save(OUT + "shelters_base.png"); shelters_t.save(OUT + "shelters_top.png")
p = shelters_b.copy(); p.alpha_composite(shelters_t); p.resize((p.width * 3, p.height * 3), Image.NEAREST).save(OUT + "shelters_raw.png")

# ------------------------------------------------------------------ Leben-Symbol (30×18 px = 10×6 Einheiten)
life = Image.new("RGBA", (30, 18)); d = ImageDraw.Draw(life)
d.ellipse([10, 0, 19, 9], fill=hexc("#6fe8ea")); d.point((12, 2), fill=hexc("#ffffff")); d.point((13, 2), fill=hexc("#ffffff"))
d.rectangle([13, 3, 16, 5], fill=hexc("#f2c29b")); d.rectangle([12, 2, 17, 3], fill=hexc("#ff7a2e"))
d.rounded_rectangle([3, 6, 26, 15], radius=4, fill=hexc("#ffcb3d"))
d.line([5, 7, 24, 7], fill=hexc("#ffe066")); d.line([4, 14, 25, 14], fill=hexc("#c8681c"))
for i, x in enumerate(range(5, 25, 2)):
    d.rectangle([x, 10, x + 1, 10], fill=OL if i % 2 else hexc("#ffffff")); d.rectangle([x, 11, x + 1, 11], fill=hexc("#ffffff") if i % 2 else OL)
d.rectangle([0, 9, 2, 12], fill=hexc("#7a80a8")); d.rectangle([27, 9, 29, 12], fill=hexc("#7a80a8"))
d.rectangle([11, 15, 18, 17], fill=hexc("#5a5f8a"))
life.save(OUT + "life_icon_raw.png")

# ------------------------------------------------------------------ Statistik-Symbole (16×16)
ICONS = ["levels", "medals", "deliveries", "perfect", "streak", "score", "credits", "crashes", "pump", "squash", "shift", "daily", "time"]
def icon(name):
    im = Image.new("RGBA", (16, 16)); d = ImageDraw.Draw(im)
    Y, Yd, C, R, Wt, G = hexc("#ffcb3d"), hexc("#c8881c"), hexc("#35e0d2"), hexc("#ff4d6d"), hexc("#f4f6ff"), hexc("#5dff9a")
    if name == "levels":
        d.rectangle([3, 2, 4, 14], fill=hexc("#c9cfee")); d.polygon([(5, 2), (13, 5), (5, 8)], fill=C)
    elif name == "medals":
        d.polygon([(4, 1), (7, 1), (9, 6), (6, 6)], fill=hexc("#3a7ae0")); d.polygon([(12, 1), (9, 1), (7, 6), (10, 6)], fill=R)
        d.ellipse([3, 6, 12, 15], fill=Y); d.ellipse([5, 8, 10, 13], fill=Yd); d.point((7, 10), fill=Y)
    elif name == "deliveries":
        d.ellipse([5, 1, 10, 6], fill=hexc("#f2c29b")); d.rounded_rectangle([3, 7, 12, 14], radius=2, fill=hexc("#d9467f"))
    elif name == "perfect":
        d.rectangle([1, 12, 14, 14], fill=C); d.line([3, 7, 6, 10], fill=G, width=2); d.line([6, 10, 12, 3], fill=G, width=2)
    elif name == "streak":
        for k, y0 in enumerate((10, 6, 2)):
            d.line([3, y0 + 4, 7, y0], fill=Y if k < 2 else hexc("#fff3b0"), width=2); d.line([7, y0, 11, y0 + 4], fill=Y if k < 2 else hexc("#fff3b0"), width=2)
    elif name == "score":
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5; r = 7 if i % 2 == 0 else 3
            pts.append((7.5 + math.cos(a) * r, 8 + math.sin(a) * r))
        d.polygon(pts, fill=Y)
    elif name == "credits":
        d.ellipse([1, 1, 14, 14], fill=Y); d.ellipse([3, 3, 12, 12], fill=Yd)
        d.arc([5, 4, 11, 11], 50, 310, fill=Y, width=2); d.line([8, 3, 8, 12], fill=Y)
    elif name == "crashes":
        pts = []
        for i in range(14):
            a = i * math.pi / 7; r = 7 if i % 2 == 0 else 3.5
            pts.append((7.5 + math.cos(a) * r, 7.5 + math.sin(a) * r))
        d.polygon(pts, fill=hexc("#ff8a2e")); d.ellipse([5, 5, 10, 10], fill=hexc("#fff3b0"))
    elif name == "pump":
        d.rectangle([3, 3, 10, 14], fill=hexc("#7a80a8")); d.rectangle([4, 4, 9, 7], fill=hexc("#1a1a2a")); d.line([5, 5, 8, 5], fill=G)
        d.line([10, 6, 13, 6], fill=OL); d.line([13, 6, 13, 12], fill=OL); d.rectangle([6, 9, 7, 11], fill=hexc("#ffa530"))
    elif name == "squash":
        d.ellipse([2, 2, 13, 13], fill=hexc("#f2c29b")); d.rectangle([5, 5, 6, 7], fill=OL); d.rectangle([9, 5, 10, 7], fill=OL)
        d.ellipse([6, 9, 9, 12], fill=hexc("#7a2a3a"))
    elif name == "shift":
        d.ellipse([2, 2, 13, 13], fill=hexc("#ffe9a0")); d.ellipse([5, 0, 16, 11], fill=(0, 0, 0, 0))
    elif name == "daily":
        d.rectangle([2, 3, 13, 14], fill=Wt); d.rectangle([2, 3, 13, 6], fill=R); d.rectangle([4, 1, 5, 4], fill=OL); d.rectangle([10, 1, 11, 4], fill=OL)
        for (x, y) in ((4, 8), (7, 8), (10, 8), (4, 11), (7, 11)): d.rectangle([x, y, x + 1, y + 1], fill=hexc("#3a4580"))
    elif name == "time":
        d.ellipse([1, 1, 14, 14], fill=Wt); d.ellipse([2, 2, 13, 13], outline=hexc("#3a4580")); d.line([7, 8, 7, 4], fill=OL); d.line([7, 8, 10, 8], fill=OL)
    return im
sheet = Image.new("RGBA", (16 * len(ICONS) + 2 * len(ICONS), 16))
for i, n in enumerate(ICONS):
    sheet.alpha_composite(icon(n), (i * 18, 0))
sheet.save(OUT + "stat_icons_raw.png")
print("ok")
