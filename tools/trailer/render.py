#!/usr/bin/env python3
"""Rendert den Trailer: python3 tools/trailer/render.py <de|en> [Start Ende] (Sekunden, für Abschnitte/Proben)
Liest die Aufnahmen aus ~/.cache/gravifare-trailer/clips (siehe tools/trailer/README.md), Ausgabe: Videoabschnitte in
~/.cache/gravifare-trailer/out/<lang>/, danach `python3 tools/trailer/mux.py <lang>`."""
import os, sys, subprocess, multiprocessing as mp
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import engine
from engine import W, H, FPS
engine.CLIPS = os.path.expanduser(os.environ.get("GF_TRAILER_CLIPS", "~/.cache/gravifare-trailer/clips_v3"))
OUT = os.path.expanduser("~/.cache/gravifare-trailer/out")
import timeline


def frame_at(tl, t, lang, cache):
    """Ein fertiges Bild (uint8) zur Zeit t."""
    img = None
    x = None
    for sh in tl.shots_at(t):
        key = id(sh["shot"])
        s = sh["shot"]
        u = t - sh["t0"]
        im = s.render(min(u, s.dur))
        g = engine.grade(im, s.grade)
        if x is None:
            x = g
        else:   # Überblendung
            a = sh["mix"](t)
            x = x * (1 - a) + g * a
        last = s
    if x is None:
        x = np.zeros((H, W, 3), np.float32)
        last = None
    fx = tl.fx(t)
    x = engine.bloom(x, fx.get("bloom", last.bloom if last else 0.3) )
    x = tl.post(x, t, lang)
    x = engine.aberrate(x, fx.get("ca", last.ca if last else 0.5))
    x = engine.vignette(x, fx.get("vig", 0.55))
    x = engine.grain(x, fx.get("grain", 0.010), int(t * FPS))
    if fx.get("flash", 0) > 0:
        x = x + fx["flash"] * np.array(fx.get("flash_col", (1, 1, 1)), np.float32)
    x = tl.titles(x, t, lang)
    x = tl.bars(x, t)
    return (np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8)


def work(args):
    lang, a, b, idx = args
    tl = timeline.build(lang)
    os.makedirs(f"{OUT}/{lang}", exist_ok=True)
    path = f"{OUT}/{lang}/seg_{idx:03d}.mp4"
    enc = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-preset", "fast", "-crf", "14", "-pix_fmt", "yuv420p", "-g", "60", path], stdin=subprocess.PIPE)
    n0, n1 = int(round(a * FPS)), int(round(b * FPS))
    for n in range(n0, n1):
        enc.stdin.write(frame_at(tl, n / FPS, lang, None).tobytes())
    enc.stdin.close()
    enc.wait()
    tl.close()
    return path


if __name__ == "__main__":
    lang = sys.argv[1]
    tl = timeline.build(lang)
    a = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    b = float(sys.argv[3]) if len(sys.argv) > 3 else tl.total
    step = 3.0
    segs = []
    t = a
    while t < b - 1e-6:
        segs.append((lang, t, min(t + step, b), len(segs)))
        t += step
    if os.path.isdir(f"{OUT}/{lang}"):
        for f in os.listdir(f"{OUT}/{lang}"):
            if f.startswith("seg_"):
                os.remove(f"{OUT}/{lang}/{f}")
    tl.close()
    with mp.get_context("spawn").Pool(min(12, len(segs))) as p:
        for r in p.imap(work, segs):
            print(r, flush=True)
    lst = f"{OUT}/{lang}/list.txt"
    open(lst, "w").write("".join(f"file '{OUT}/{lang}/seg_{i:03d}.mp4'\n" for i in range(len(segs))))
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", f"{OUT}/{lang}/video.mp4"], check=True)
    print("fertig", f"{OUT}/{lang}/video.mp4")
