"""Raumklang je Sektor (assets/audio/sfx/amb_s1..9.wav): nahtlose 12-s-Schleifen aus gefiltertem Rauschen und Brummen, komplett synthetisch.
Aufruf: python3 tools/audio/gen_ambience.py"""
import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf

SR = 22050
N = SR * 12

def band(x, lo, hi):
    return sosfilt(butter(2, [lo, hi], btype="band", fs=SR, output="sos"), x)

def loop_noise(rng, lo, hi):
    """Rauschen, dessen Enden überblendet sind, damit die Schleife keine Naht hat."""
    x = band(rng.standard_normal(N + SR), lo, hi)
    fade = np.linspace(0, 1, SR)
    x[:SR] = x[:SR] * fade + x[N:N + SR] * (1 - fade)
    return x[:N]

def hum(f, depth, rate):
    t = np.arange(N) / SR
    f = round(f * 12) / 12            # ganze Schwingungen je Schleife
    rate = round(rate * 12) / 12
    return np.sin(2 * np.pi * f * t) * (1 - depth + depth * np.sin(2 * np.pi * rate * t))

# Sektor: (Rausch-Bänder [lo, hi, Pegel], Brummen [Hz, Tiefe, Rate, Pegel])
SPEC = {1: ([(200, 1800, 0.25)], [(55, 0.2, 0.25, 0.20)]),                                     # Stadtrauschen
        2: ([(800, 5000, 0.14)], [(82, 0.5, 0.5, 0.16), (164, 0.5, 0.33, 0.08)]),              # Neonsummen in Schluchten
        3: ([(120, 900, 0.34)], [(48, 0.4, 1.0, 0.26), (97, 0.7, 2.0, 0.10)]),                 # Maschinenstampfen
        4: ([(400, 2400, 0.30)], [(110, 0.6, 0.17, 0.10)]),                                    # Polarwind
        5: ([(60, 500, 0.45)], [(41, 0.5, 0.25, 0.22)]),                                       # Lavagrollen
        6: ([(150, 1100, 0.40)], [(62, 0.8, 0.17, 0.14)]),                                     # Wasserströmung
        7: ([(300, 2600, 0.22)], [(73, 0.3, 0.5, 0.14), (146, 0.4, 0.25, 0.08)]),              # Verkehrsknoten
        8: ([(1500, 6500, 0.10), (100, 700, 0.24)], [(55, 0.6, 0.08, 0.10)]),                  # Urwald bei Nacht
        9: ([(70, 400, 0.30)], [(36, 0.7, 0.08, 0.30), (73, 0.8, 0.17, 0.10)])}                # Singularität

for sector, (noises, hums) in SPEC.items():
    rng = np.random.default_rng(sector)
    x = np.zeros(N)
    for lo, hi, g in noises:
        y = loop_noise(rng, lo, hi)
        x += y / np.abs(y).max() * g
    for f, depth, rate, g in hums:
        x += hum(f, depth, rate) * g
    x = x / np.abs(x).max() * 0.7
    sf.write("assets/audio/sfx/amb_s%d.wav" % sector, x, SR, subtype="PCM_16")
