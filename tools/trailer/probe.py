#!/usr/bin/env python3
"""Einzelbilder der Zeitleiste als Kontaktbogen: python3 tools/trailer/probe.py <lang> <out.png> t1 t2 ... (aufsteigend)"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import engine
engine.CLIPS = os.path.expanduser(os.environ.get("GF_TRAILER_CLIPS", "~/.cache/gravifare-trailer/clips_v2"))
import timeline, render
from PIL import Image, ImageDraw
lang, out = sys.argv[1], sys.argv[2]
ts = [float(a) for a in sys.argv[3:]]
tl = timeline.build(lang)
ims = []
for t in ts:
    im = Image.fromarray(render.frame_at(tl, t, lang, None)).resize((640, 360), Image.LANCZOS)
    ImageDraw.Draw(im).text((8, 6), f"{t:.2f}", fill=(255, 255, 0))
    ims.append(im)
cols = 3
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (640 * cols, 360 * rows))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * 640, (i // cols) * 360))
sheet.save(out)
tl.close()
