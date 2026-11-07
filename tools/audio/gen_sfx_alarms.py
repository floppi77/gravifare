"""Synthetisiert die Warntöne, die sich vom Tankalarm ("warn") unterscheiden (eigene Arbeit, numpy/scipy -> 16-bit WAV, 44,1 kHz):
  plasma_warn  (0,7 s) Plasmabrenner: Zündknall, Zischen das aufsteigt, elektrisches Brummen und Knistern (Strahl lädt auf)
  meteor_warn  Meteorit im Anflug: Rumpeln, das anschwillt, dazu Pfeifen und Rauschen (Einschlag kündigt sich an)
  exit_tick    tickende Uhr (Tick-Tack) für den Zeitdruck am Ausgang, langsam und schnell
Aufruf: python3 tools/audio/gen_sfx_alarms.py [Zielordner]   (Standard: build/sound_preview/)"""
import os, sys, wave
import numpy as np
from scipy import signal

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "build/sound_preview/"
rng = np.random.default_rng(11)

def save(name, x, peak=0.89):
    x = np.asarray(x, dtype=float)
    m = np.abs(x).max()
    if m > 0:
        x = x * (peak / m)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(OUT + name + ".wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32000).astype("<i2").tobytes())

def t(d): return np.arange(int(SR * d)) / SR
def band(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos"), x)
def lowp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="lowpass", fs=SR, output="sos"), x)
def highp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="highpass", fs=SR, output="sos"), x)
def smooth(a, b, tt, x0, x1):
    """Weiche Stufe von a nach b zwischen x0 und x1 (Sekunden)."""
    k = np.clip((tt - x0) / (x1 - x0), 0, 1)
    k = k * k * (3 - 2 * k)
    return a + (b - a) * k

def plasma_warn():
    d = 0.7; tt = t(d); n = len(tt); k = d / 1.25      # Dauer; die Verläufe unten sind auf 1,25 s ausgelegt und laufen mit k gestaucht
    noise = rng.standard_normal(n)
    # Zischen: drei Bänder, die nacheinander aufblenden (die Flamme wird heißer und heller)
    low = band(noise, 900, 2600) * smooth(0.9, 0.25, tt, 0.05 * k, 0.9 * k)
    mid = band(noise, 2600, 6000) * smooth(0.3, 1.0, tt, 0.0, 0.7 * k)
    hi = band(noise, 6000, 11000) * smooth(0.0, 0.45, tt, 0.2 * k, 1.0 * k)
    hiss = (low + mid + hi) * np.minimum(1.0, tt / 0.012) * smooth(0.55, 1.0, tt, 0.0, 0.9 * k)
    # Brummen: Sägezahn, der mit der Spannung ansteigt, 100-Hz-Netzbrummen-Charakter
    f = 100 + 60 * smooth(0, 1, tt, 0.0, 1.0 * k)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = lowp(signal.sawtooth(ph), 1200) * (0.55 + 0.45 * np.sin(2 * np.pi * 50 * tt))
    hum = saw * smooth(0.25, 0.7, tt, 0.0, 1.0 * k)
    # Knistern: Funken als kurze helle Klicks, anfangs selten, dann dichter
    crackle = np.zeros(n)
    rate = smooth(25, 110, tt, 0.0, 1.0 * k)
    p = rng.random(n) < rate / SR
    for i in np.flatnonzero(p):
        L = min(int(SR * rng.uniform(0.002, 0.007)), n - i)
        crackle[i:i + L] += highp(rng.standard_normal(L), 2500) * np.exp(-np.arange(L) / (L * 0.35)) * rng.uniform(0.4, 1.4)
    # Zündknall
    pop = highp(rng.standard_normal(n), 1500) * np.exp(-tt * 90) * 1.6 + np.sin(2 * np.pi * 140 * tt) * np.exp(-tt * 45) * 0.9
    x = hiss * 0.42 + hum * 0.85 + crackle * 0.4 + pop
    tail = np.minimum(1.0, (d - tt) / 0.12)
    save("plasma_warn", np.tanh(x * 1.1) * tail)

def meteor_warn():
    d = 1.5; tt = t(d); n = len(tt)
    noise = rng.standard_normal(n)
    # Rumpeln: tiefes Rauschen, das anschwillt und unregelmäßig bebt (Gestein)
    rumble = lowp(noise, 140, 3) * smooth(0.12, 1.0, tt, 0.0, 1.2)
    rumble *= 0.65 + 0.35 * np.sin(2 * np.pi * (9 + 6 * tt) * tt + 1.0 * np.sin(2 * np.pi * 3.1 * tt))
    sub = np.sin(2 * np.pi * (48 + 18 * smooth(0, 1, tt, 0, 1.3)) * tt) * smooth(0.0, 0.7, tt, 0.0, 1.2)
    # Anflug: Rauschen mit steigender Mitte, dazu ein Pfeifen, das beim Näherkommen tiefer fällt
    whoosh = band(noise, 500, 3800, 2) * smooth(0.0, 1.0, tt, 0.1, 1.25)
    fw = 2300 * np.exp(-tt * 1.15) + 260
    whistle = np.sin(2 * np.pi * np.cumsum(fw) / SR + 0.6 * np.sin(2 * np.pi * 7 * tt)) * smooth(0.0, 1.0, tt, 0.1, 1.2) ** 1.5
    x = rumble * 1.1 + sub * 0.5 + whoosh * 0.38 + whistle * 0.22
    fade = np.minimum(np.minimum(1.0, tt / 0.04), np.minimum(1.0, (d - tt) / 0.16))
    save("meteor_warn", np.tanh(x * 1.2) * fade)

def _tick(freq, body, decay, level):
    d = 0.12; tt = t(d); n = len(tt)
    click = highp(rng.standard_normal(n), 2200) * np.exp(-tt * 380) * 0.3
    tone = np.sin(2 * np.pi * freq * tt) * np.exp(-tt * decay) * 0.8
    wood = np.sin(2 * np.pi * body * tt) * np.exp(-tt * (decay * 0.55)) * 0.45
    return (click + tone + wood) * level

def exit_tick():
    # Tick-Tack: hoher Tick, etwas tieferes, weicheres Tack. Langsam: ein Paar pro Sekunde, schnell: vier Paare in einer Sekunde
    for name, pairs, gap in (("exit_tick", 1, 0.5), ("exit_tick_fast", 4, 0.125)):
        d = pairs * 2 * gap + 0.1
        x = np.zeros(int(SR * d))
        for k in range(pairs * 2):
            tick = _tick(2900, 820, 330, 1.0) if k % 2 == 0 else _tick(2150, 560, 260, 0.8)
            i = int(SR * gap * k)
            x[i:i + len(tick)] += tick[:len(x) - i]
        save(name, x)

if __name__ == "__main__":
    plasma_warn(); meteor_warn(); exit_tick()
    print(sorted(os.listdir(OUT)))
