"""Erzeugt die Pixel-Art-Assets des Vertical Slice (Sektor 1 Sternenhafen, Taxi, Fahrgast).
Aufruf: python3 tools/art/gen_art.py   -> schreibt nach assets/art/
Alle Grafiken sind eigenständig per Code gezeichnet (keine Fremdassets)."""
import random
from PIL import Image, ImageDraw

OUT = "assets/art/"

def hexc(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)

# --- Sektor-1-Palette (Sternenhafen): Indigo, Petrol, warmes Orange als Akzent
P = dict(
    rock_d=hexc("#1b1f3a"), rock_m=hexc("#262c52"), rock_l=hexc("#323a6b"), rock_h=hexc("#4a5596"),
    edge=hexc("#6f7fd0"), edge_hi=hexc("#a9b8ff"),
    pad=hexc("#14304a"), pad_l=hexc("#2fd2c6"), pad_lo=hexc("#17847f"),
    fuel=hexc("#47220f"), fuel_l=hexc("#ff9f2e"), fuel_hi=hexc("#ffd37a"),
    spike=hexc("#e8506e"), spike_d=hexc("#8f2a45"),
)

def tiles():
    img = Image.new("RGBA", (16 * 8, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    for v in range(4):  # Fels-Varianten
        ox = v * 16
        d.rectangle([ox, 0, ox + 15, 15], fill=P["rock_m"])
        for _ in range(26):
            x, y = rnd.randrange(16), rnd.randrange(16)
            d.point((ox + x, y), fill=rnd.choice([P["rock_d"], P["rock_l"], P["rock_d"]]))
        for _ in range(2):  # Plattenfugen
            x, y = rnd.randrange(3, 13), rnd.randrange(3, 13)
            d.line([ox + x, y, ox + x + rnd.randrange(2, 5), y], fill=P["rock_d"])
        d.point((ox + rnd.randrange(16), rnd.randrange(16)), fill=P["rock_h"])
    # Pad (4): Metallplatte mit Leuchtleiste
    ox = 4 * 16
    d.rectangle([ox, 0, ox + 15, 15], fill=P["pad"])
    d.rectangle([ox, 0, ox + 15, 1], fill=P["pad_l"])
    d.rectangle([ox, 2, ox + 15, 2], fill=P["pad_lo"])
    for x in (2, 10): d.rectangle([ox + x, 6, ox + x + 3, 9], fill=P["rock_l"])
    d.line([ox, 15, ox + 15, 15], fill=P["rock_d"])
    # Tankpad (5)
    ox = 5 * 16
    d.rectangle([ox, 0, ox + 15, 15], fill=P["fuel"])
    d.rectangle([ox, 0, ox + 15, 1], fill=P["fuel_l"])
    for x in range(0, 16, 8):
        d.polygon([(ox + x, 15), (ox + x + 4, 15), (ox + x + 8, 5), (ox + x + 4, 5)], fill=P["fuel_l"])
    d.rectangle([ox, 2, ox + 15, 2], fill=P["fuel_hi"])
    # Dornen (6)
    ox = 6 * 16
    d.rectangle([ox, 12, ox + 15, 15], fill=P["spike_d"])
    for x in range(0, 16, 4):
        d.polygon([(ox + x, 12), (ox + x + 2, 2), (ox + x + 4, 12)], fill=P["spike"])
    # Ausgang (7): Torraster
    ox = 7 * 16
    d.rectangle([ox, 0, ox + 15, 15], fill=(0, 0, 0, 0))
    for y in (0, 15): d.rectangle([ox, y, ox + 15, y], fill=P["pad_l"])
    img.save(OUT + "tiles_s1.png")

def taxi():
    # 32x20, Mittelpunkt (16,10). Karosserie gelb/orange, Kanzel cyan.
    W, H = 32, 20
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    out = hexc("#10142b"); yl = hexc("#ffc83a"); yd = hexc("#e08a1e"); yh = hexc("#fff0a0")
    gl = hexc("#7ef0ee"); gd = hexc("#2a9fb0"); mt = hexc("#6a6f94"); md = hexc("#3a3e60")
    # Rumpf (Kapsel)
    d.rounded_rectangle([3, 3, 28, 14], radius=5, fill=out)
    d.rounded_rectangle([4, 4, 27, 13], radius=4, fill=yl)
    d.rectangle([5, 11, 26, 13], fill=yd)
    d.line([8, 5, 22, 5], fill=yh)
    # Kanzel
    d.rounded_rectangle([10, 2, 21, 9], radius=3, fill=out)
    d.rounded_rectangle([11, 3, 20, 8], radius=2, fill=gl)
    d.rectangle([11, 7, 20, 8], fill=gd)
    d.point((13, 4), fill=(255, 255, 255, 255)); d.point((14, 4), fill=(255, 255, 255, 255))
    # Taxi-Schachbrettband
    for i, x in enumerate(range(6, 26, 2)):
        d.rectangle([x, 10, x + 1, 10], fill=out if i % 2 else (255, 255, 255, 255))
    # Düsen links/rechts, unten
    d.rectangle([0, 6, 3, 10], fill=out); d.rectangle([1, 7, 3, 9], fill=mt)
    d.rectangle([28, 6, 31, 10], fill=out); d.rectangle([28, 7, 30, 9], fill=mt)
    d.rectangle([11, 14, 20, 16], fill=out); d.rectangle([12, 14, 19, 15], fill=md)
    d.rectangle([14, 15, 17, 16], fill=mt)
    # Positionslicht
    d.point((4, 5), fill=hexc("#ff4d6d")); d.point((27, 5), fill=hexc("#5dff9a"))
    img.save(OUT + "taxi.png")

def passenger():
    # 8x12, drei Varianten nebeneinander (Hautton/Kleidung)
    img = Image.new("RGBA", (8 * 4, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    looks = [("#f2c29b", "#d0467a", "#3a2a52"), ("#a8714f", "#3fb68b", "#1c1c30"),
             ("#e9b58c", "#e8a33a", "#552a1c"), ("#8fd0c8", "#7a6bd8", "#22223d")]
    for i, (skin, cloth, hair) in enumerate(looks):
        ox = i * 8
        d.rectangle([ox + 2, 0, ox + 5, 1], fill=hexc(hair))
        d.rectangle([ox + 2, 2, ox + 5, 4], fill=hexc(skin))
        d.point((ox + 3, 3), fill=hexc("#10142b")); d.point((ox + 5, 3), fill=hexc("#10142b"))
        d.rectangle([ox + 1, 5, ox + 6, 9], fill=hexc(cloth))
        d.rectangle([ox + 2, 10, ox + 3, 11], fill=hexc("#10142b")); d.rectangle([ox + 4, 10, ox + 5, 11], fill=hexc("#10142b"))
    img.save(OUT + "passengers.png")

def background():
    W, H = 640, 360
    rnd = random.Random(21)
    far = Image.new("RGBA", (W, H))
    px = far.load()
    top, bot = hexc("#0a0c1f"), hexc("#2b1f4d")
    for y in range(H):
        t = (y / H) ** 1.4
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(W): px[x, y] = c
    # Dither-Band am Horizont
    for y in range(190, 250):
        for x in range(W):
            if (x + y) % 2 == 0 and rnd.random() < (y - 190) / 120:
                px[x, y] = hexc("#3a2a63")
    d = ImageDraw.Draw(far)
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(H - 80)
        d.point((x, y), fill=rnd.choice([hexc("#ffffff"), hexc("#a9b8ff"), hexc("#ffd9a0"), hexc("#6f7fd0")]))
    # Planet
    cx, cy, r = 470, 96, 46
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hexc("#e07a3a"))
    d.ellipse([cx - r + 6, cy - r + 6, cx + r, cy + r], fill=hexc("#f3a05a"))
    d.ellipse([cx - r + 2, cy - r + 2, cx + r - 18, cy + r - 18], fill=hexc("#c9622e"))
    d.ellipse([cx - r - 20, cy - 6, cx + r + 22, cy + 8], outline=hexc("#ffd9a0"))
    far.save(OUT + "bg_s1_far.png")
    # Nahe Silhouetten (Raumhafen-Skyline), transparent, kachelbar horizontal
    near = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(near)
    x = 0
    sil, sil2 = hexc("#151a38"), hexc("#1d2348")
    while x < W:
        w = rnd.randrange(18, 46); h = rnd.randrange(40, 150)
        d.rectangle([x, H - h - 40, x + w, H], fill=sil)
        for wy in range(H - h - 34, H - 44, 8):
            for wx in range(x + 3, x + w - 3, 6):
                if rnd.random() < 0.22:
                    d.rectangle([wx, wy, wx + 1, wy + 2], fill=hexc("#ffcf6a") if rnd.random() < 0.7 else hexc("#59e0d6"))
        if rnd.random() < 0.5:
            d.line([x + w // 2, H - h - 40, x + w // 2, H - h - 54], fill=sil2)
            d.point((x + w // 2, H - h - 55), fill=hexc("#ff4d6d"))
        x += w + rnd.randrange(0, 8)
    near.save(OUT + "bg_s1_near.png")

if __name__ == "__main__":
    import os; os.makedirs(OUT, exist_ok=True)
    tiles(); taxi(); passenger(); background()
    print("Assets geschrieben nach", OUT)
