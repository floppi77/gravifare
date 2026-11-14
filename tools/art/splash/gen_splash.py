"""Erzeugt die Bilder des Startbildschirms nach assets/art/splash/:
  godot_logo.png  – offizielles Godot-Logo (Pressekit, „Large horizontal logo, colored for dark backgrounds“),
                    unverändert gerastert (Seitenverhältnis bleibt). Quelle: godot_logo_large_color_dark.svg
                    (https://godotengine.org/press/, © 2017 Andrea Calabró, CC BY 4.0).
  logo_halo.png   – weicher blauer Schein hinter dem GraviFare-Logo (aus dessen Alphakanal, weichgezeichnet).
Aufruf (im Projektordner): python3 tools/art/splash/gen_splash.py   (braucht rsvg-convert, Pillow, NumPy)"""
import io, os, subprocess
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "splash")
LOGO_CROP = (13, 210, 1762, 636)      # sichtbarer Bereich von assets/art/logo.png (Alpha > 24); splash.gd nutzt dieselben Werte
GODOT_H = 200                          # 32 Spieleinheiten hoch × 6 (2160p) ≈ 192 px, etwas Reserve

def godot_logo():
    png = subprocess.run(["rsvg-convert", "-h", str(GODOT_H), os.path.join(HERE, "godot_logo_large_color_dark.svg")],
                         capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    im.save(os.path.join(OUT, "godot_logo.png"), optimize=True)
    return im.size

def halo():
    lg = Image.open(os.path.join(ROOT, "assets", "art", "logo.png")).convert("RGBA").crop(LOGO_CROP)
    q = 4                                                    # Viertelauflösung reicht für einen weichen Schein
    pad = 40
    a = lg.getchannel("A").resize((lg.width // q, lg.height // q), Image.LANCZOS)
    canvas = Image.new("L", (a.width + 2 * pad, a.height + 2 * pad), 0)
    canvas.paste(a, (pad, pad))
    blur = canvas.filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.6))
    out = Image.new("RGBA", canvas.size, (40, 140, 255, 0))
    out.putalpha(blur)
    out.save(os.path.join(OUT, "logo_halo.png"), optimize=True)
    return out.size, pad * q

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("godot_logo.png", godot_logo())
    print("logo_halo.png", halo())
