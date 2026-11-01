"""Begrenzt die Spitzen aller Effekte auf -1 dBFS (Sicherheitsabstand gegen Übersteuern). Aufruf: python3 tools/audio/limit_sfx.py"""
import glob
import numpy as np
import soundfile as sf

for f in sorted(glob.glob("assets/audio/sfx/*.wav")):
    x, sr = sf.read(f)
    # 4-fach überabgetastet schätzen, damit auch Spitzen zwischen den Samples zählen
    n = len(x)
    peak = np.abs(np.fft.irfft(np.fft.rfft(x, axis=0), n * 4, axis=0) * 4).max()
    if peak > 0.89:
        sf.write(f, x * (0.89 / peak), sr, subtype="PCM_16")
        print("%s: %+.1f dB" % (f, 20 * np.log10(0.89 / peak)))
