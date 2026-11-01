"""Soundtrack im Klang der Heimcomputer, komplett selbst erzeugt (keine Fremdsamples):
  * SID (C64): Stimmen werden wie im Tracker im 50-Hz-Takt gesteuert (Wellenform-, Puls-, Arpeggio- und Vibrato-Tabellen),
    12-Bit-Oszillatoren mit kombinierten Wellenformen, Hard-Sync, Ringmodulation, ADSR-Hüllkurve und resonantem Filter.
  * Paula (Amiga): selbst erzeugte Instrumente werden auf 8 Bit und niedrige Abtastraten reduziert und ohne Interpolation abgespielt,
    wie im ProTracker; vier Kanäle mit Stereo-Verteilung, Akkorde als Akkord-Samples, Ton-Effekte im 50-Hz-Takt.
Die Stücke sind von Hand notiert (THEMES unten). Schichten: A = Bass, Schlagzeug, Harmonie (läuft immer), B = Melodie, C = Spannung.
Alles stereo, 44,1 kHz, nahtlos loopbar. Aufruf: python3 tools/audio/gen_music.py [thema ...]   -> assets/audio/music/<thema>_<A|B|C>.ogg"""
import os, re, subprocess, sys
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from scipy.signal import butter, lfilter, resample_poly, sosfilt

SR = 44100
OS = 2                  # interne Überabtastung der Chips
OR = SR * OS
TICK = OR // 50         # ein Tracker-Takt (50 Hz)
OUT = "assets/audio/music/"
TAIL = 3 * SR           # Nachklang, der am Schleifenanfang wieder eingemischt wird
TARGET_LUFS = -15.5     # Lautheit von Grundschicht plus Melodie: alle Stücke gleich laut
SCALES = {"minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
          "harm": [0, 2, 3, 5, 7, 8, 11], "major": [0, 2, 4, 5, 7, 9, 11], "mixo": [0, 2, 4, 5, 7, 9, 10], "lydian": [0, 2, 4, 6, 7, 9, 11]}
DEG = "TUVWXYZ0123456789abcde"   # Melodie-Zeichen: 0 = Grundton, 7 = Oktave, Z = Stufe darunter; "." halten, "-" Pause

def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)

def tri_lfo(x):
    return 2.0 * np.abs(2.0 * (x % 1.0) - 1.0) - 1.0

# ------------------------------------------------------------------ SID
SID = {  # wave: Wellenform oder Tabelle je 50-Hz-Takt; ptab: Tonhöhe je Takt; a/d/s/r wie ADSR
 "pulse":  dict(wave="p", pw=0.30, pwd=0.16, pwp=90, a=0.004, d=0.5, s=0.62, r=0.22, vib=(0.22, 7, 14), amp=0.42),
 "hollow": dict(wave="p", pw=0.12, pwd=0.06, pwp=60, a=0.004, d=0.35, s=0.5, r=0.2, vib=(0.18, 6, 12), amp=0.36),
 "saw":    dict(wave="s", a=0.004, d=0.6, s=0.7, r=0.2, vib=(0.2, 6, 16), amp=0.40),
 "flute":  dict(wave="t", a=0.03, d=0.4, s=0.85, r=0.3, vib=(0.3, 7, 18), amp=0.62),
 "sync":   dict(wave="y", syn=(1.5, 3.6, 40), a=0.004, d=0.6, s=0.7, r=0.2, vib=(0.2, 6, 16), amp=0.36),
 "ring":   dict(wave="r", ring=2.51, a=0.002, d=0.7, s=0.3, r=0.35, amp=0.5),
 "metal":  dict(wave="ps", pw=0.4, a=0.002, d=0.5, s=0.6, r=0.2, vib=(0.15, 6, 14), amp=0.9),
 "bass":   dict(wave="p", pw=0.22, pwd=0.1, pwp=120, a=0.002, d=0.22, s=0.55, r=0.05, amp=0.55),
 "bsaw":   dict(wave="s", a=0.002, d=0.2, s=0.6, r=0.05, amp=0.55),
 "btri":   dict(wave="t", a=0.002, d=0.4, s=0.8, r=0.06, amp=0.95),
 "pad":    dict(wave="p", pw=0.5, pwd=0.32, pwp=220, a=0.09, d=1.5, s=0.75, r=0.6, amp=0.26),
 "stab":   dict(wave="s", a=0.002, d=0.13, s=0.1, r=0.1, amp=0.34),
 "arp":    dict(wave="p", pw=0.2, a=0.001, d=0.09, s=0.12, r=0.08, amp=0.24),
 "arpt":   dict(wave="t", a=0.001, d=0.14, s=0.2, r=0.1, amp=0.42),
 "chord":  dict(wave="p", pw=0.35, pwd=0.15, pwp=80, a=0.003, d=0.3, s=0.5, r=0.1, tick=2, amp=0.26),
 "kick":   dict(wave="t", ptab=[34, 24, 15, 9, 5, 2, 0], a=0.001, d=0.16, s=0.0, r=0.02, amp=1.15, fixed=31),
 "snare":  dict(wave=["p", "n", "n", "n", "n", "n", "n", "n"], ptab=[12, 8, 40, 40, 40, 39, 38, 37], a=0.001, d=0.17, s=0.0, r=0.03, amp=0.62, fixed=52, pw=0.5),
 "hat":    dict(wave="n", a=0.001, d=0.035, s=0.0, r=0.01, amp=0.21, fixed=103),
 "ohat":   dict(wave="n", a=0.001, d=0.2, s=0.0, r=0.05, amp=0.2, fixed=103),
 "tom":    dict(wave="t", ptab=[12, 8, 5, 3, 2, 1, 0], a=0.001, d=0.2, s=0.0, r=0.03, amp=0.8),
 "crash":  dict(wave="n", a=0.001, d=1.3, s=0.0, r=0.2, amp=0.22, fixed=98),
 "riser":  dict(wave="n", a=1.6, d=0.1, s=0.9, r=0.05, amp=0.13, fixed=88),
}

def sid_note(n, gate, m, inst, vel, seed, tick_n):
    t_f = n // TICK + 2
    fi = np.arange(t_f)
    semis = np.full(t_f, float(inst.get("fixed", m)))
    if "ptab" in inst:
        tab = np.array(inst["ptab"], dtype=float)
        semis += tab[np.minimum(fi, len(tab) - 1)]
    if "arpg" in inst:
        tab = np.array(inst["arpg"], dtype=float)
        semis += tab[(fi // inst.get("tick", 1)) % len(tab)]
    if "vib" in inst:
        d, rate, delay = inst["vib"]
        semis += d * tri_lfo(fi / (rate * 2.0)) * np.clip((fi - delay) / 10.0, 0.0, 1.0)
    f = np.repeat(midi_hz(semis), TICK)[:n]
    cum = np.cumsum(f) / OR
    ph = cum % 1.0
    wave = inst.get("wave", "p")
    wt = wave if isinstance(wave, list) else [wave]
    out = np.zeros(n)
    pw = inst.get("pw", 0.5) + inst.get("pwd", 0.0) * tri_lfo(fi / float(inst.get("pwp", 100)) + (seed % 7) * 0.13)
    pw_s = np.repeat(pw, TICK)[:n]
    wi = np.repeat(np.minimum(fi, len(wt) - 1), TICK)[:n]
    for k, w in enumerate(wt):
        mask = wi == k
        if not mask.any():
            continue
        p = ph[mask]
        saw = (p * 4095.0).astype(np.int32)
        tri = (np.where(p < 0.5, p * 2.0, 2.0 - p * 2.0) * 4095.0).astype(np.int32)
        pul = np.where(p < pw_s[mask], 4095, 0)
        if w == "s":
            v = saw
        elif w == "t":
            v = tri
        elif w == "p":
            v = pul
        elif w == "ps":                         # kombinierte Wellenformen: digitale UND-Verknüpfung wie im Chip
            v = pul & saw
        elif w == "ts":
            v = tri & saw
        elif w == "pt":
            v = pul & tri
        elif w == "n":
            tb = np.random.default_rng(seed).integers(0, 4096, 8192)
            v = tb[(cum[mask] * 16.0).astype(np.int64) % 8192]
        elif w == "y":                          # Hard-Sync: Sägezahn wird vom Grundton neu gestartet, Formant wandert
            a, b, frames = inst["syn"]
            r = np.repeat(a + (b - a) * np.clip(fi / float(frames), 0.0, 1.0), TICK)[:n][mask]
            v = (((p * r) % 1.0) * 4095.0).astype(np.int32)
        elif w == "r":                          # Ringmodulation: Dreieck mit dem Vorzeichen einer zweiten Stimme
            sq = np.where(((cum[mask] * inst["ring"]) % 1.0) < 0.5, 1, -1)
            v = ((tri - 2048) * sq + 2048).astype(np.int32)
        else:
            v = pul
        out[mask] = v / 2047.5 - 1.0
    t = np.arange(n) / OR
    a, d, s, r = inst["a"], inst["d"], inst["s"], inst["r"]
    env = np.where(t < a, t / a, s + (1.0 - s) * np.exp(-(t - a).clip(0.0) / (d / 3.5)))
    if gate < n:
        lvl = env[gate - 1] if gate > 0 else 0.0
        env[gate:] = lvl * np.exp(-(t[gate:] - t[gate]) / (r / 3.5))
    env = np.floor(env * 255.0) / 255.0        # 8-Bit-Hüllkurve
    return out * env * vel * inst.get("amp", 0.4)

def biquad(cut, q, mode):
    w = 2.0 * np.pi * min(cut, SR * 0.45) / SR
    al = np.sin(w) / (2.0 * q)
    c = np.cos(w)
    if mode == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif mode == "bp":
        b = [al, 0.0, -al]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a0 = 1 + al
    return np.array(b) / a0, np.array([1.0, -2 * c / a0, (1 - al) / a0])

def sweep_filter(x, cut, q, mode="lp"):
    """Filter mit Grenzfrequenz je 50-Hz-Takt (wie die Register des SID); die Vorspannung verzerrt leicht wie beim 6581."""
    block = SR // 50
    y = np.zeros_like(x)
    zi = np.zeros(2)
    x = np.tanh(x * 1.5) / 1.5
    for i in range(0, len(x), block):
        b, a = biquad(float(cut[min(i // block, len(cut) - 1)]), q, mode)
        y[i:i + block], zi = lfilter(b, a, x[i:i + block], zi=zi)
    return y

def render_sid(notes, total):
    """Einstimmige Stimme: Ein neuer Ton schneidet den alten ab."""
    buf = np.zeros(total * OS)
    notes = sorted(notes, key=lambda e: e[0])
    for i, (st, ln, m, name, vel) in enumerate(notes):
        inst = SID[name] if isinstance(name, str) else name
        s = st * OS
        nxt = notes[i + 1][0] * OS if i + 1 < len(notes) else total * OS
        room = min(nxt - s, int(s + (ln + 2.4 * SR) * OS) - s, total * OS - s)
        gate = int(ln * OS * inst.get("gate", 0.92))
        if room < 64:
            continue
        buf[s:s + room] += sid_note(room, min(gate, room), m, inst, vel, i * 31 + st % 977, 1)
    return resample_poly(buf, 1, OS)

# ------------------------------------------------------------------ Paula: Instrumente werden erst als Klang gebaut, dann auf 8 Bit reduziert
def saw(f, n, sr, ph0=0.0):
    return 2.0 * ((ph0 + np.cumsum(np.broadcast_to(f, (n,))) / sr) % 1.0) - 1.0

def lp(x, cut, order=2, sr=SR):
    return sosfilt(butter(order, cut, btype="low", fs=sr, output="sos"), x)

def hp(x, cut, order=2, sr=SR):
    return sosfilt(butter(order, cut, btype="high", fs=sr, output="sos"), x)

def bp(x, lo, hi, sr=SR):
    return sosfilt(butter(2, [lo, hi], btype="band", fs=sr, output="sos"), x)

def pluck(f, dur, seed, bright=0.5, damp=0.996):
    n = int(dur * SR)
    L = max(2, int(SR / f - 0.5))
    x = np.zeros(n)
    rng = np.random.default_rng(seed)
    x[:L] = lp(rng.uniform(-1, 1, L), 600 + 9000 * bright)
    a = np.zeros(L + 2)
    a[0] = 1.0
    a[L] = -damp / 2.0
    a[L + 1] = -damp / 2.0
    return lfilter([1.0], a, x)

def ensemble(freqs, dur, voices, spread, cut, seed, attack=0.2):
    n = int(dur * SR)
    rng = np.random.default_rng(seed)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f0 in freqs:
        for v in range(voices):
            d = 2.0 ** (spread * (v - (voices - 1) / 2.0) / 12.0)
            vib = 1.0 + 0.0022 * np.sin(2 * np.pi * rng.uniform(3.8, 5.6) * t + rng.uniform(0, 6))
            out += saw(f0 * d * vib, n, SR, rng.uniform(0, 1))
    out = lp(out, cut)
    return out * np.minimum(1.0, t / attack)

def loop_fade(x, start, length, fade):
    """Schleife ohne Knacken: Ende wird in den Schleifenanfang überblendet."""
    end = start + length
    k = np.linspace(0.0, 1.0, fade)
    y = x[:end].copy()
    y[end - fade:end] = x[end - fade:end] * (1 - k) + x[start - fade:start] * k
    return y

def to8(x, rate, m, loop=None, gain=0.97):
    """Auf die Abtastrate des Instruments bringen und auf 8 Bit reduzieren wie im Amiga-Sampler."""
    y = resample_poly(x, rate, SR)
    y = y / max(np.abs(y).max(), 1e-6) * gain
    return dict(data=np.round(y * 127.0) / 127.0, rate=float(rate), root=m,
                loop=None if loop is None else (int(loop[0] * rate / SR), int(loop[1] * rate / SR)))

def chip_loop(shape, m=72):
    L = 32
    p = np.arange(L) / L
    w = {"saw": 2 * p - 1, "pulse": np.where(p < 0.3, 1.0, -1.0), "square": np.where(p < 0.5, 1.0, -1.0), "tri": 4 * np.abs(p - 0.5) - 1,
         "organ": np.sin(2 * np.pi * p) + 0.6 * np.sin(4 * np.pi * p) + 0.4 * np.sin(6 * np.pi * p) + 0.25 * np.sin(8 * np.pi * p)}[shape]
    w = w / np.abs(w).max()
    rate = midi_hz(m) * L
    return dict(data=np.round(w * 127.0) / 127.0, rate=float(rate), root=m, loop=(0, L))

def bank():
    b = {}
    t = lambda d: np.arange(int(d * SR)) / SR
    rng = np.random.default_rng(7)
    # Schlagzeug
    x = t(0.42); f = 46 + 150 * np.exp(-x * 42)
    k = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 7.5)
    k[:90] += rng.uniform(-1, 1, 90) * np.linspace(0.5, 0, 90)
    b["kick"] = to8(np.tanh(k * 1.8), 16574, 60)
    x = t(0.3)
    sn = (np.sin(2 * np.pi * 186 * x) * 0.7 + np.sin(2 * np.pi * 332 * x) * 0.4) * np.exp(-x * 24) + bp(rng.uniform(-1, 1, len(x)), 900, 8200) * 1.6 * np.exp(-x * 13)
    b["snare"] = to8(np.tanh(sn * 1.4), 16574, 60)
    x = t(0.12)
    mt = sum(np.sign(np.sin(2 * np.pi * f * x)) for f in (2460, 3210, 4010, 5430, 6250, 8230))
    b["hat"] = to8(hp(mt + rng.uniform(-1, 1, len(x)) * 2, 6500) * np.exp(-x * 62), 22050, 60)
    x = t(0.5)
    mt = sum(np.sign(np.sin(2 * np.pi * f * x)) for f in (2460, 3210, 4010, 5430, 6250, 8230))
    b["ohat"] = to8(hp(mt + rng.uniform(-1, 1, len(x)) * 2, 6000) * np.exp(-x * 9), 22050, 60)
    x = t(0.55); f = 96 * (0.72 + 0.5 * np.exp(-x * 13))
    b["tom"] = to8(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 7) + lp(rng.uniform(-1, 1, len(x)), 2600) * 0.3 * np.exp(-x * 22), 16574, 60)
    x = t(1.6)
    mt = sum(np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) for f in rng.uniform(1800, 9000, 60))
    b["crash"] = to8(hp(mt * 0.2 + rng.uniform(-1, 1, len(x)), 2600) * np.exp(-x * 3.0), 22050, 60)
    x = t(0.5)
    b["clap"] = to8(bp(rng.uniform(-1, 1, len(x)), 800, 4400) * (np.exp(-x * 16) + 0.8 * np.exp(-((x - 0.016) % 0.012) * 300) * (x < 0.04)), 16574, 60)
    x = t(0.7); c = sum(np.sin(2 * np.pi * f * x + 2.5 * np.exp(-x * 7) * np.sin(2 * np.pi * f * 1.41 * x)) for f in (312, 777, 1460, 2310))
    b["anvil"] = to8(c * np.exp(-x * 7), 16574, 60)                 # Industrie: Metallschlag
    x = t(1.4); f = 66 * (0.8 + 0.4 * np.exp(-x * 9))
    b["taiko"] = to8(np.tanh(1.5 * (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 3.4) + lp(rng.uniform(-1, 1, len(x)), 900) * 0.5 * np.exp(-x * 30))), 16574, 60)
    # Bässe
    n = pluck(midi_hz(36), 2.2, 1, 0.95, 0.997)
    b["slap"] = to8(np.tanh(hp(n, 60) * 3.2) + bp(n, 1400, 5200) * 1.3 * np.exp(-t(2.2)[:len(n)] * 26), 16574, 36)
    n = pluck(midi_hz(36), 2.5, 2, 0.45, 0.998)
    b["fingerb"] = to8(lp(np.tanh(n * 2.0), 2600), 11025, 36)
    x = t(2.0); f0 = midi_hz(36)
    env = 300 + 1900 * np.exp(-x * 11)
    raw = saw(f0, len(x), SR) * 0.7 + saw(f0 * 1.004, len(x), SR, 0.3) * 0.7
    y = sweep_filter(np.concatenate([raw, np.zeros(0)]), env[::882], 3.2)
    b["sbass"] = to8(np.tanh(y * 2.4) * np.minimum(1, (2.0 - x) * 8), 11025, 36)
    x = t(2.0)
    period = int(round(SR / float(midi_hz(36))))
    b["sub"] = to8(np.sin(2 * np.pi * midi_hz(36) * x) + 0.3 * np.sin(4 * np.pi * midi_hz(36) * x), 11025, 36, loop=(SR // 2, period * 40))
    # Flächen als Akkord-Samples (wie im Modul: ein Kanal, ganzer Akkord)
    for nm, iv in (("maj", (0, 4, 7, 12)), ("min", (0, 3, 7, 12)), ("sus", (0, 7, 12, 19))):
        fr = [midi_hz(48 + i) for i in iv]
        s = bp(ensemble(fr, 3.6, 5, 0.1, 3600, 11, 0.25), 180, 6000)
        b["str_" + nm] = to8(loop_fade(s, SR, int(2.4 * SR), int(0.5 * SR)), 16574, 48, loop=(SR, int(2.4 * SR)))
        src = ensemble(fr, 3.6, 5, 0.14, 7000, 12, 0.28)
        vo = bp(src, 500, 900) * 1.3 + bp(src, 980, 1350) * 0.9 + bp(src, 2300, 3000) * 0.35
        b["choir_" + nm] = to8(loop_fade(vo, SR, int(2.4 * SR), int(0.5 * SR)), 16574, 48, loop=(SR, int(2.4 * SR)))
        x = t(0.8)
        env = 500 + 3800 * np.exp(-x * 9)
        y = sweep_filter(ensemble(fr, 0.8, 3, 0.09, 12000, 13, 0.006), env[::882], 1.1)
        b["brass_" + nm] = to8(y * np.exp(-x * 2.6), 16574, 48)
        x = t(0.9)
        hit = ensemble(fr, 0.9, 5, 0.12, 6500, 14, 0.003) * np.exp(-x * 5.0) + rng.uniform(-1, 1, len(x)) * 0.4 * np.exp(-x * 28)
        b["orch_" + nm] = to8(hit, 16574, 48)
        x = t(1.6)
        ep = sum(np.sin(2 * np.pi * f * x + 1.4 * np.exp(-x * 4) * np.sin(2 * np.pi * f * x)) + 0.25 * np.exp(-x * 24) * np.sin(2 * np.pi * f * 14 * x) for f in fr[:3])
        b["ep_" + nm] = to8(ep * np.exp(-x * 2.4), 16574, 48)
    # Gitarren
    def gtr(iv, dur, damp, seed):
        o = sum(pluck(midi_hz(40 + i), dur, seed + i, 0.8, damp) for i in iv)
        return bp(np.tanh(hp(o, 90) * 7.0), 110, 3800) + bp(np.tanh(hp(o, 90) * 7.0), 1200, 3000) * 0.4
    b["power"] = to8(loop_fade(gtr((0, 7, 12), 2.2, 0.9992, 21), int(1.0 * SR), int(0.9 * SR), int(0.2 * SR)), 16574, 40, loop=(int(1.0 * SR), int(0.9 * SR)))
    b["mute"] = to8(gtr((0, 7, 12), 0.5, 0.975, 25), 16574, 40)
    # Melodie-Instrumente
    x = t(2.4)
    y = np.tanh((saw(midi_hz(60) * (1 + 0.003 * np.sin(2 * np.pi * 5.2 * x)), len(x), SR) + saw(midi_hz(60) * 1.003, len(x), SR, 0.4)) * 4.0)
    b["glead"] = to8(loop_fade(bp(y, 180, 4200), int(0.8 * SR), int(1.3 * SR), int(0.25 * SR)), 16574, 60, loop=(int(0.8 * SR), int(1.3 * SR)))
    x = t(1.8); f0 = midi_hz(72)
    b["bell"] = to8(np.sin(2 * np.pi * f0 * x + 2.2 * np.exp(-x * 5) * np.sin(2 * np.pi * f0 * 3.5 * x)) * np.exp(-x * 2.6), 22050, 72)
    x = t(2.2); f0 = midi_hz(72)
    fl = np.sin(2 * np.pi * f0 * x + 0.3 * np.sin(2 * np.pi * 5.0 * x)) + 0.22 * np.sin(4 * np.pi * f0 * x) + bp(rng.uniform(-1, 1, len(x)), 1500, 5000) * 0.09
    b["flute"] = to8(loop_fade(fl * np.minimum(1, x / 0.05), int(0.8 * SR), int(1.1 * SR), int(0.25 * SR)), 22050, 72, loop=(int(0.8 * SR), int(1.1 * SR)))
    x = t(2.2); f0 = midi_hz(60)
    sft = ensemble([f0], 2.2, 3, 0.09, 3400, 31, 0.02)
    b["softlead"] = to8(loop_fade(sft, int(0.8 * SR), int(1.1 * SR), int(0.25 * SR)), 16574, 60, loop=(int(0.8 * SR), int(1.1 * SR)))
    x = t(1.2); f0 = midi_hz(60)
    env = 700 + 3400 * np.exp(-x * 7)
    b["horn"] = to8(sweep_filter(ensemble([f0], 1.2, 3, 0.08, 12000, 33, 0.012), env[::882], 1.0) * np.exp(-x * 1.2), 16574, 60, loop=None)
    for sh in ("saw", "pulse", "square", "tri", "organ"):
        b["chip_" + sh] = chip_loop(sh)
    return b

BANK = {}

PAULA = {  # Spielweise je Instrument: Lautstärke (0..1), Vibrato (Halbtöne, Takte je Halbwelle, Verzögerung), Ausblenden (Takte), ganz kurz = Staccato
 "lead_chip": dict(smp="chip_saw", vol=0.48, vib=(0.2, 6, 14), fade=70),
 "lead_sq":   dict(smp="chip_pulse", vol=0.42, vib=(0.2, 6, 14), fade=60),
 "lead_tri":  dict(smp="chip_tri", vol=0.62, vib=(0.22, 7, 16), fade=80),
 "lead_organ": dict(smp="chip_organ", vol=0.46, vib=(0.14, 6, 18), fade=120),
 "glead":     dict(smp="glead", vol=0.56, vib=(0.3, 6, 12), fade=0),
 "softlead":  dict(smp="softlead", vol=0.5, vib=(0.14, 7, 18), fade=0),
 "horn":      dict(smp="horn", vol=0.6, vib=(0.12, 7, 20), fade=0),
 "flute":     dict(smp="flute", vol=0.56, vib=(0.14, 7, 16), fade=0),
 "bell":      dict(smp="bell", vol=0.62),
 "slap":      dict(smp="slap", vol=0.8),
 "fingerb":   dict(smp="fingerb", vol=0.9),
 "sbass":     dict(smp="sbass", vol=0.82),
 "sub":       dict(smp="sub", vol=1.0),
 "power":     dict(smp="power", vol=0.66),
 "mute":      dict(smp="mute", vol=0.74),
}

def paula_note(n, ln, m, name, vel):
    p = dict(PAULA.get(name, dict(smp=name, vol=0.7)))
    smp = BANK[p["smp"]]
    frames = n // TICK + 2
    fi = np.arange(frames)
    semis = np.full(frames, float(m))
    if "vib" in p:
        d, rate, delay = p["vib"]
        semis += d * tri_lfo(fi / (rate * 2.0)) * np.clip((fi - delay) / 10.0, 0, 1)
    inc = np.repeat(smp["rate"] / OR * 2.0 ** ((semis - smp["root"]) / 12.0), TICK)[:n]
    pos = np.cumsum(inc) - inc[0]
    data = smp["data"]
    if smp["loop"] is not None:
        ls, ll = smp["loop"]
        over = pos >= ls + ll
        if over.any():
            pos[over] = ls + (pos[over] - ls) % ll
    else:
        over = pos >= len(data) - 1
        if over.any():
            cut = int(np.argmax(over))
            n = cut
            pos = pos[:cut]
    if n <= 0:
        return np.zeros(0)
    v = data[pos.astype(np.int64)]            # keine Interpolation: der Klang des Paula-Chips
    vol = np.full(frames, p.get("vol", 0.7) * vel)
    if p.get("fade"):
        vol = vol * np.maximum(0.25, 1.0 - fi / float(p["fade"]) * 0.75)
    vol = np.round(vol * 64.0) / 64.0
    e = np.repeat(vol, TICK)[:n]
    if ln < n:                                 # Ton aus: kurzes Ausblenden wie ein Lautstärke-Slide
        e = e.copy()
        e[ln:] *= np.maximum(0.0, 1.0 - np.arange(n - ln) / (0.03 * OR))
    return v * e

def render_paula(notes, total):
    buf = np.zeros(total * OS)
    notes = sorted(notes, key=lambda e: e[0])
    for i, (st, ln, m, name, vel) in enumerate(notes):
        s = st * OS
        nxt = notes[i + 1][0] * OS if i + 1 < len(notes) else total * OS
        room = min(nxt - s, total * OS - s, int((ln + 0.5 * SR) * OS))
        if room < 32:
            continue
        x = paula_note(room, ln * OS, m, name, vel)
        fade = min(len(x), 60)
        if fade > 0:
            x[-fade:] *= np.linspace(1.0, 0.0, fade)
        buf[s:s + len(x)] += x
    b, a = butter(1, 7600, fs=OR)              # analoger Ausgangsfilter des Amiga
    return resample_poly(lfilter(b, a, buf), 1, OS)

# ------------------------------------------------------------------ Partitur
def pat(*bars):
    s = "".join(bars).replace(" ", "")
    assert len(s) % 16 == 0, (len(s), s)
    return s

def degree_midi(key, scale, d):
    sc = SCALES[scale]
    return key + sc[d % 7] + 12 * (d // 7)

def chord_kind(scale, d):
    sc = SCALES[scale]
    third = (sc[(d + 2) % 7] + (12 if (d % 7) + 2 > 6 else 0)) - sc[d % 7]
    return "maj" if third == 4 else "min"

def notes_from(line, start, step, key, scale, inst, vel, base=12):
    out = []
    cur = None
    for i, c in enumerate(line):
        if c == ".":
            continue
        if cur is not None:
            out.append((cur[0], (start + i * step) - cur[0], cur[1], inst, vel))
            cur = None
        if c != "-":
            cur = (start + i * step, degree_midi(key + base, scale, DEG.index(c) - 7))
    if cur is not None:
        out.append((cur[0], (start + len(line) * step) - cur[0], cur[1], inst, vel))
    return out

def build(th):
    key, scale, bpm = th["key"], th["scale"], th["bpm"]
    step = int(round(SR * 60.0 / bpm / 4.0))
    order = th.get("order", "AABA")
    bars = sum(len(th["chords"][s]) for s in order)
    total = bars * 16 * step
    ch = {k: [] for k in ("bass", "drum", "harm", "lead", "tense", "tdrum")}
    chip = th["chip"]
    bar = 0
    seen = {}
    for si, sec in enumerate(order):
        chords = th["chords"][sec]
        seen[sec] = seen.get(sec, 0) + 1
        repeat = seen[sec]
        last_sec = si == len(order) - 1
        bp_ = th.get("bass_" + sec, th["bass"])
        dk, ds, dh = [th.get(n + "_" + sec, th[n]) for n in ("kick", "snare", "hat")]
        lead_lines = th.get("lead_" + sec)
        if last_sec and "lead_end" in th:
            lead_lines = th["lead_end"]
        elif repeat == 2 and ("lead_" + sec + "2") in th:
            lead_lines = th["lead_" + sec + "2"]
        if lead_lines:
            ln = "".join(lead_lines).replace(" ", "")
            assert len(ln) == len(chords) * 16, (th["name"], sec, len(ln))
            ch["lead"] += notes_from(ln, bar * 16 * step, step, key, scale, th["lead"], 1.0, th.get("lead_oct", 12))
        for b, deg in enumerate(chords):
            t0 = (bar + b) * 16 * step
            root = degree_midi(key - th.get("bass_oct", 12 if key >= 44 else 0), scale, deg)
            cur = None
            bpat = bp_[(b % (len(bp_) // 16)) * 16:][:16]
            for i, c in enumerate(bpat):
                if c == ".":
                    continue
                if cur is not None:
                    ch["bass"].append((cur[0], t0 + i * step - cur[0], cur[1], th["bassi"], cur[2]))
                    cur = None
                if c != "-":
                    off = {"r": 0, "o": 12, "f": 7 if chord_kind(scale, deg) else 7, "t": SCALES[scale][(deg + 2) % 7] - SCALES[scale][deg % 7], "s": 10, "R": 0}[c]
                    if c == "t" and off < 0:
                        off += 12
                    cur = (t0 + i * step, root + off, 1.0 if i % 4 == 0 or c == "R" else 0.8)
            if cur is not None:
                ch["bass"].append((cur[0], t0 + 16 * step - cur[0], cur[1], th["bassi"], cur[2]))
            fill = b == len(chords) - 1 and th.get("fill", True)
            kick, snare, hat = [d[(b % (len(d) // 16)) * 16:][:16] for d in (dk, ds, dh)]
            if si == 0 and b < 4:             # Einstieg: noch ohne Becken
                hat = "-" * 16
            if sec == order[-2] and order.count(sec) == 1 and 4 <= b < 6 and not th.get("nobreak"):
                kick = "-" * 16               # Luft im Mittelteil: zwei Takte ohne Bassdrum
            for i in range(16):
                t = t0 + i * step
                if fill and i >= 12:
                    if i % 2 == 0 or th.get("fill_fast"):
                        ch["drum"].append((t, step, key + 12 - (i - 12) * 2, "tom", 0.9))
                    continue
                if kick[i] == "x":
                    ch["drum"].append((t, step * 2, 36, th.get("kicki", "kick"), 1.0))
                elif snare[i] == "x":
                    ch["drum"].append((t, step * 2, 60, th.get("snarei", "snare"), 1.0))
                elif snare[i] == "g":
                    ch["drum"].append((t, step * 2, 60, th.get("snarei", "snare"), 0.45))
                elif hat[i] in "xo":
                    ch["drum"].append((t, step, 60, "ohat" if hat[i] == "o" else "hat", 0.8 if i % 4 else 1.0))
            hm = th.get("harm")
            kind = chord_kind(scale, deg)
            if hm == "hold":                  # gehaltene Fläche
                nx = chords[b + 1] if b + 1 < len(chords) else None
                if b == 0 or chords[b - 1] != deg:
                    span = 1
                    while b + span < len(chords) and chords[b + span] == deg:
                        span += 1
                    m = degree_midi(key + th.get("harm_oct", 0), scale, deg)
                    if chip == "paula":
                        ch["harm"].append((t0, span * 16 * step, m, th["harmi"] + "_" + kind, th.get("harmv", 1.0)))
                    else:
                        third = degree_midi(key + th.get("harm_oct", 0), scale, deg + 2)
                        ch["harm"].append((t0, span * 16 * step, third, th["harmi"], th.get("harmv", 1.0)))
            elif hm and hm != "none":         # Akkord-Rhythmus
                hp_ = hm.replace(" ", "")
                for i, c in enumerate(hp_[(b % (len(hp_) // 16)) * 16:][:16]):
                    if c == "x":
                        m = degree_midi(key + th.get("harm_oct", 0), scale, deg)
                        if chip == "paula":
                            nm = th["harmi"] if th["harmi"] in ("power", "mute") else th["harmi"] + "_" + kind
                            ch["harm"].append((t0 + i * step, step * 3, m, nm, th.get("harmv", 1.0)))
                        else:
                            third = 4 if kind == "maj" else 3
                            inst = dict(SID[th["harmi"]])
                            inst["arpg"] = [0, third, 7]
                            ch["harm"].append((t0 + i * step, step * 3, m, inst, th.get("harmv", 1.0)))
            # C: Spannung: Arpeggio-Figur, zusätzliche Schläge, Becken zu Abschnittsbeginn
            ar = th.get("arp")
            if ar:
                ar = ar.replace(" ", "")
                tones = [deg, deg + 2, deg + 4, deg + 7, deg + 9, deg + 11]
                for i, c in enumerate(ar[(b % (len(ar) // 16)) * 16:][:16]):
                    if c.isdigit():
                        ch["tense"].append((t0 + i * step, step * 2, degree_midi(key + th.get("arp_oct", 12), scale, tones[int(c)]), th["arpi"], 0.85))
            tk = th.get("tkick", "x---x---x---x---")
            for i, c in enumerate(tk[:16]):
                if c == "x":
                    ch["tdrum"].append((t0 + i * step, step * 2, 36, th.get("tkicki", "kick"), 0.9))
            th_ = th.get("that", "--x---x---x---x-")
            for i, c in enumerate(th_[:16]):
                if c == "x":
                    ch["tdrum"].append((t0 + i * step, step, 60, "ohat" if chip == "sid" else th.get("thati", "hat"), 0.7))
            if b == 0:
                ch["tdrum"].append((t0, step * 8, 60, "crash", 0.9))
        bar += len(chords)
    return ch, step, total, bars

def level(x, db):
    """Kanal auf Zielpegel bringen (gemessen, solange er klingt): So bleibt die Melodie in jedem Stück vorn und der Bass dröhnt nie."""
    k = 2048
    n = len(x) // k
    if n == 0:
        return x
    e = np.sqrt((x[:n * k].reshape(n, k) ** 2).mean(1))
    if e.max() < 1e-7:
        return x
    act = e[e > e.max() * 0.03]
    return x * 10 ** (db / 20.0) / float(np.sqrt((act ** 2).mean()))

MIX = {"bass": -15.0, "drum": -16.5, "harm": -21.0, "lead": -14.0, "tense": -21.0, "tdrum": -24.0}

def pan(x, p):
    return np.stack([x * (1.0 - max(p, 0.0)), x * (1.0 + min(p, 0.0))])

def wrap(x, total):
    y = x[:, :total].copy()
    t = x[:, total:]
    y[:, :t.shape[1]] += t
    return y

def echo(x, delay, gain, cross=True):
    y = x.copy()
    for k, g in ((1, gain), (2, gain * gain)):
        d = delay * k
        src = x[::-1] if cross and k % 2 == 1 else x
        y[:, d:] += src[:, :-d] * g
    return y

def mixstems(th):
    ch, step, total, bars = build(th)
    full = total + TAIL
    if th["chip"] == "sid":
        def voice(name, p=0.0):
            return render_sid(ch[name], full)
        bass = voice("bass")
        cut = bass_cut(th, step, total, full)
        if th.get("bass_filter", True):
            bass = sweep_filter(bass, cut, th.get("res", 2.2), "lp") * 1.25
        harm = voice("harm")
        if th.get("harm_filter", True) and th.get("harm"):
            n = full // (SR // 50) + 2
            lfo = 0.5 + 0.5 * np.sin(2.0 * np.pi * np.arange(n) / (n * 2.0 / max(bars / 8, 1)) )
            harm = sweep_filter(harm, 500.0 + 2600.0 * lfo ** 2, 1.8, "lp") * 1.2
        lead = voice("lead")
        if th.get("lead_filter"):
            n = full // (SR // 50) + 2
            harm_c = np.full(n, float(th["lead_filter"]))
            lead = sweep_filter(lead, harm_c, 1.2, "lp") * 1.15
        drum = voice("drum")
        tense = voice("tense")
        tdrum = voice("tdrum")
        bass, drum, harm, lead, tense, tdrum = [level(x, MIX[k] + th.get("mix", {}).get(k, 0.0)) for x, k in ((bass, "bass"), (drum, "drum"), (harm, "harm"), (lead, "lead"), (tense, "tense"), (tdrum, "tdrum"))]
        A = pan(bass, 0.0) + pan(drum, 0.0) + pan(harm, -0.2)
        B = pan(lead, 0.14)
        C = pan(tense, -0.25) + pan(tdrum, 0.15)
    else:
        bass = render_paula(ch["bass"], full)
        drum = render_paula(ch["drum"], full)
        harm = render_paula(ch["harm"], full)
        lead = render_paula(ch["lead"], full)
        tense = render_paula(ch["tense"], full)
        tdrum = render_paula(ch["tdrum"], full)
        bass, drum, harm, lead, tense, tdrum = [level(x, MIX[k] + th.get("mix", {}).get(k, 0.0)) for x, k in ((bass, "bass"), (drum, "drum"), (harm, "harm"), (lead, "lead"), (tense, "tense"), (tdrum, "tdrum"))]
        A = pan(bass, -0.28) + pan(drum, 0.3) + pan(harm, -0.5)
        B = pan(lead, 0.5)
        C = pan(tense, 0.55) + pan(tdrum, -0.35)
    if th.get("echo"):
        B = echo(B, th["echo"] * step, 0.34)
        C = echo(C, th["echo"] * step, 0.25)
    A, B, C = wrap(A, total), wrap(B, total), wrap(C, total)
    # gemeinsame Lautheit: Zusammenspiel aller Schichten bleibt unter der Aussteuerung, Verhältnis der Schichten bleibt erhalten
    allsum = A + B + C
    g = 10 ** ((TARGET_LUFS - lufs(A + B)) / 20.0)
    peak = float(np.abs(allsum).max()) * g
    if peak > 0.92:
        g *= 0.92 / peak
    return {"A": A * g, "B": B * g, "C": C * g}

def lufs(x):
    """Integrierte Lautheit (EBU R128) über ffmpeg."""
    r = subprocess.run(["ffmpeg", "-nostats", "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-af", "ebur128", "-f", "null", "-"],
        input=np.clip(x.T, -4.0, 4.0).astype("<f4").tobytes(), capture_output=True)
    return float(re.findall(rb"I:\s+(-?[\d.]+) LUFS", r.stderr)[-1])

def bass_cut(th, step, total, full):
    n = full // (SR // 50) + 2
    t = np.arange(n) * (SR // 50)
    base = th.get("cut", 700.0)
    depth = th.get("cut_d", 1200.0)
    bars16 = 16 * step
    cyc = (t / (bars16 * th.get("cut_bars", 4))) % 1.0
    return base + depth * (0.5 - 0.5 * np.cos(2.0 * np.pi * cyc))

def write_ogg(path, x):
    tmp = path[:-4] + ".raw"
    d = np.clip(x.T, -1.0, 1.0)
    (d * 32000.0).astype("<i2").tofile(tmp)
    q = "3" if np.abs(d).max() > 1e-4 else "0"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", tmp, "-c:a", "libvorbis", "-q:a", q, path], check=True)
    os.remove(tmp)

from music_score import THEMES        # die Stücke stehen in music_score.py

def job(name):
    if not BANK:
        BANK.update(bank())
    th = dict(THEMES[name], name=name)
    st = mixstems(th)
    for k, x in st.items():
        write_ogg("%s%s_%s.ogg" % (OUT, name, k), x)
    return "%s: %s, %.0f s" % (name, th["chip"], st["A"].shape[1] / SR)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(THEMES)
    with ProcessPoolExecutor(8) as ex:
        for line in ex.map(job, names):
            print(line, flush=True)
