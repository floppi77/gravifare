"""Misst die mittlere Grundfrequenz (Median, pyin) je Fahrgast-Stimme und Sprache, um zu belegen, dass die Stimmen verschieden klingen.
Aufruf (Projektwurzel, Python mit librosa):  .venv/tts/bin/python tools/audio/voice_pitch.py [f0 f2 …]"""
import glob, os, sys, collections
import numpy as np, librosa

want = sys.argv[1:]
res = collections.defaultdict(list)
for f in sorted(glob.glob("assets/audio/voice/*/[fm][0-9]_*.ogg")):
    lang = f.split("/")[-2]
    v = os.path.basename(f).split("_")[0]
    if want and v not in want:
        continue
    y, sr = librosa.load(f, sr=16000)
    f0, voiced, _ = librosa.pyin(y, fmin=60, fmax=450, sr=sr)
    f0 = f0[voiced & ~np.isnan(f0)]
    if len(f0) > 5:
        res[(lang, v)].append(np.median(f0))
for (lang, v), xs in sorted(res.items()):
    print(f"{lang} {v}: {np.median(xs):6.1f} Hz  ({len(xs)} Clips)")
