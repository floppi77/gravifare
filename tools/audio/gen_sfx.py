"""Synthetisiert die Sound-Effekte des Spiels (eigene Arbeit, numpy -> 16-bit WAV, 44,1 kHz).
Aufruf: python3 tools/audio/gen_sfx.py   -> assets/audio/sfx/*.wav"""
import numpy as np, wave, os
SR = 44100
OUT = "assets/audio/sfx/"
rng = np.random.default_rng(5)

def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(OUT + name + ".wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32000).astype("<i2").tobytes())

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1):
    e = np.ones(n); na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr); return e
def lp(x, k):  # einfacher Tiefpass
    y = np.zeros_like(x); a = 0
    for i, v in enumerate(x): a += k * (v - a); y[i] = a
    return y

def thrust_loop():
    d = 1.0; n = int(SR * d)
    noise = lp(rng.standard_normal(n), 0.12) * 1.6
    rumble = np.sin(2 * np.pi * 55 * t(d)) * 0.4 + np.sin(2 * np.pi * 82 * t(d)) * 0.2
    x = (noise * 0.6 + rumble) * 0.5
    # nahtlos: Überblendung Ende->Anfang
    f = int(0.05 * SR); x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f); x = x[:-f]
    save("thrust", x)
def side_loop():
    d = 1.0; n = int(SR * d)
    x = lp(rng.standard_normal(n), 0.25) * 0.5
    f = int(0.05 * SR); x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f); x = x[:-f]
    save("side", x * 0.6)
def land():
    d = 0.35; tt = t(d)
    x = np.sin(2 * np.pi * (140 - 80 * tt / d) * tt) * np.exp(-tt * 14) + lp(rng.standard_normal(len(tt)), 0.3) * np.exp(-tt * 25) * 0.5
    save("land", x * 0.9)
def clunk():
    d = 0.3; tt = t(d)
    x = np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 18) + np.sign(np.sin(2 * np.pi * 400 * tt)) * np.exp(-tt * 60) * 0.3
    save("gear", x * 0.7)
def crash():
    d = 0.9; tt = t(d)
    x = lp(rng.standard_normal(len(tt)), 0.35) * np.exp(-tt * 5) * 1.2 + np.sin(2 * np.pi * 50 * tt) * np.exp(-tt * 6)
    save("crash", x * 0.9)
def hit():
    d = 0.25; tt = t(d)
    x = lp(rng.standard_normal(len(tt)), 0.4) * np.exp(-tt * 18) + np.sin(2 * np.pi * 110 * tt) * np.exp(-tt * 20)
    save("hit", x * 0.9)
def warn():
    d = 0.25; tt = t(d)
    x = np.sign(np.sin(2 * np.pi * 880 * tt)) * 0.25 * env(len(tt), 0.003, 0.05)
    save("warn", x)
def coin():
    x = np.concatenate([np.sign(np.sin(2 * np.pi * f * t(0.07))) * 0.25 * env(int(0.07 * SR), 0.002, 0.03) for f in (988, 1319)])
    save("coin", x)
def board():
    d = 0.3; tt = t(d)
    x = np.sin(2 * np.pi * (500 + 700 * tt / d) * tt) * 0.4 * env(len(tt), 0.01, 0.1)
    save("board", x)
def exit_open():
    x = np.concatenate([np.sin(2 * np.pi * f * t(0.1)) * 0.35 * env(int(0.1 * SR), 0.005, 0.05) for f in (523, 659, 784, 1047)])
    save("exit", x)
def ui_move():
    tt = t(0.04); save("ui_move", np.sign(np.sin(2 * np.pi * 700 * tt)) * 0.15 * env(len(tt), 0.002, 0.02))
def ui_ok():
    tt = t(0.09); save("ui_ok", np.sin(2 * np.pi * 1000 * tt) * 0.3 * env(len(tt), 0.002, 0.04))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (thrust_loop, side_loop, land, clunk, crash, hit, warn, coin, board, exit_open, ui_move, ui_ok): f()
    print(sorted(os.listdir(OUT)))
