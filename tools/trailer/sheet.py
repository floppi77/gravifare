#!/usr/bin/env python3
"""Kontaktbogen roher Aufnahmen: sheet.py <clip> <out.png> t1 t2 ... (Sekunden); markiert die Taxi-Position aus der Spur."""
import sys, os, subprocess
from PIL import Image, ImageDraw
C = os.path.expanduser(os.environ.get("GF_TRAILER_CLIPS", "~/.cache/gravifare-trailer/clips_v5"))
clip, out = sys.argv[1], sys.argv[2]
ts = [float(a) for a in sys.argv[3:]]
tr = [l.split() for l in open(f"{C}/{clip}.trace")] if os.path.exists(f"{C}/{clip}.trace") else []
pr = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=width,height,r_frame_rate", "-of", "csv=p=0", f"{C}/{clip}.avi"], capture_output=True, text=True).stdout.strip().split(",")
SW, SH, FR = int(pr[0]), int(pr[1]), eval(pr[2])
ims = []
for t in ts:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.3f}", "-i", f"{C}/{clip}.avi", "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    im = Image.frombytes("RGB", (SW, SH), raw[:SW * SH * 3]).resize((480, 270), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    i = int(round(t * FR))
    lab = f"{t:.1f}"
    if tr and i < len(tr):
        x, y, st = float(tr[i][1]) * 480 / SW, float(tr[i][2]) * 480 / SW, tr[i][3]
        d.ellipse([x - 10, y - 10, x + 10, y + 10], outline=(255, 0, 255), width=2)
        lab += f" st{st} hull{float(tr[i][6]):.0f}"
    d.text((6, 4), lab, fill=(255, 255, 0))
    ims.append(im)
cols = 4
rows = (len(ims) + cols - 1) // cols
sh = Image.new("RGB", (480 * cols, 270 * rows))
for k, im in enumerate(ims):
    sh.paste(im, ((k % cols) * 480, (k // cols) * 270))
sh.save(out)
