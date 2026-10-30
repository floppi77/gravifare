"""Erzeugt die Musik des Spiels: je Sektor (s1..s9) und fürs Menü (menu) ein nahtlos loopbares Thema aus drei
synchronen Schichten (Stems): A = Basis (Pad + Bass), B = Bewegung (Arpeggio/Lead mit Delay), C = Spannung (Drums,
Riser, Akzente). Alles eigene Synthese (NumPy/SciPy), eigene Kompositionen, 12 Takte je Thema.
Aufruf: python3 tools/audio/gen_music.py [thema ...]   -> assets/audio/music/<thema>_<A|B|C>.ogg"""
import os, subprocess, sys, wave
import numpy as np
from scipy import signal

SR = 44100
OUT = "assets/audio/music/"
SCALES = {"minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
          "harm": [0, 2, 3, 5, 7, 8, 11], "major": [0, 2, 4, 5, 7, 9, 11]}
# Thema: Tempo, Grundton (MIDI), Skala, Akkordfolge (Stufen, 1 Takt je Akkord), Muster, Klangfarbe, Besonderheit
THEMES = {
 "menu": dict(bpm=92,  root=48, scale="major",    prog=[0, 4, 5, 3], bass="half",   arp="updown", kick="half", hats=8,  cut=1800, lead="saw",    extra=None),
 "s1":   dict(bpm=100, root=45, scale="minor",    prog=[0, 5, 2, 6], bass="roots8", arp="updown", kick="four", hats=8,  cut=1500, lead="saw",    extra=None),
 "s2":   dict(bpm=118, root=42, scale="minor",    prog=[0, 3, 5, 4], bass="sync",   arp="up16",   kick="four", hats=16, cut=2200, lead="square", extra="neon"),
 "s3":   dict(bpm=88,  root=38, scale="minor",    prog=[0, 6, 0, 5], bass="half",   arp="skip",   kick="break", hats=8, cut=1100, lead="square", extra="clank"),
 "s4":   dict(bpm=96,  root=40, scale="phrygian", prog=[0, 1, 0, 6], bass="pulse16", arp="skip",  kick="break", hats=8, cut=1700, lead="saw",    extra="wobble"),
 "s5":   dict(bpm=128, root=36, scale="minor",    prog=[0, 5, 6, 0], bass="pulse16", arp="up16",  kick="four", hats=16, cut=2400, lead="saw",    extra="anvil"),
 "s6":   dict(bpm=84,  root=43, scale="dorian",   prog=[0, 3, 0, 6], bass="half",   arp="updown", kick="half", hats=8,  cut=1300, lead="saw",    extra="tide"),
 "s7":   dict(bpm=124, root=35, scale="minor",    prog=[0, 5, 3, 6], bass="sync",   arp="up16",   kick="four", hats=16, cut=2600, lead="square", extra="neon"),
 "s8":   dict(bpm=76,  root=37, scale="minor",    prog=[0, 3, 0, 4], bass="half",   arp="skip",   kick="half", hats=8,  cut=900,  lead="saw",    extra="sparse"),
 "s9":   dict(bpm=110, root=45, scale="harm",     prog=[0, 3, 4, 5], bass="roots8", arp="updown", kick="four", hats=16, cut=2000, lead="saw",    extra="epic"),
}
BARS = 12
rng = np.random.default_rng(11)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)
def sos(x, kind, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype=kind, fs=SR, output="sos"), x)
def saw(f, n, det=0.0):
    ph = (np.arange(n) / SR * f * (1 + det)) % 1.0
    return 2 * ph - 1
def square(f, n):
    return np.sign(np.sin(2 * np.pi * f * np.arange(n) / SR))
def env_ad(n, a, d):
    x = np.arange(n) / SR
    return np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-x / d)
def put(dst, start, sig):
    s = int(start)
    if s >= len(dst): return
    e = min(len(dst), s + len(sig)); dst[s:e] += sig[:e - s]
def deg_midi(root, scale, deg):
    return root + SCALES[scale][deg % 7] + 12 * (deg // 7)

def reverb(x, seconds=1.6, decay=2.8, wet=0.22):
    n = int(seconds * SR); t = np.arange(n) / SR
    ir = sos(rng.standard_normal(n) * np.exp(-t * decay), "lowpass", 4200)
    ir[:int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
    ir /= np.sqrt((ir ** 2).sum())
    return x * (1 - wet * 0.4) + signal.fftconvolve(x, ir)[:len(x)] * wet * 3.0

def pingpong(st, delay, fb=0.42, mix=0.4):
    d = int(delay * SR); out = st.copy()
    for k in range(1, 6):
        sh = np.zeros_like(st)
        sh[k * d:, 0] = st[:len(st) - k * d, 1 if k % 2 else 0]
        sh[k * d:, 1] = st[:len(st) - k * d, 0 if k % 2 else 1]
        out += sh * (fb ** k) * mix
    return out

def pan(x, p):
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)

def kick(n=int(0.35 * SR)):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * (45 + 90 * np.exp(-t * 28)) * t) * np.exp(-t * 11) * 1.0
def snare(n=int(0.28 * SR)):
    t = np.arange(n) / SR
    return (sos(rng.standard_normal(n), "bandpass", [1200, 7000]) * 0.9 + np.sin(2 * np.pi * 185 * t) * 0.5) * np.exp(-t * 16)
def hat(n=int(0.08 * SR), open_=False):
    t = np.arange(n if not open_ else int(0.25 * SR)) / SR
    return sos(rng.standard_normal(len(t)), "highpass", 7000) * np.exp(-t * (60 if not open_ else 14))
def metal(n=int(0.5 * SR)):
    t = np.arange(n) / SR
    return sum(np.sin(2 * np.pi * f * t) * a for f, a in ((523, 0.5), (871, 0.35), (1341, 0.3), (2113, 0.2))) * np.exp(-t * 7)

def render(name, th):
    spb = 60.0 / th["bpm"]; step = spb / 4.0                   # 16tel
    bar = 4 * spb; N = int(BARS * bar * SR); tail = int(3.0 * SR)
    L = N + tail
    A = np.zeros((L, 2)); B = np.zeros((L, 2)); C = np.zeros((L, 2))
    root, sc = th["root"], th["scale"]
    for b in range(BARS):
        d = th["prog"][b % 4]
        t0 = b * bar
        tones = [d, d + 2, d + 4]
        # ---- A: Pad (Dreiklang, 3 verstimmte Sägen, Hüllkurve über den Takt) + Bass
        nbar = int(bar * SR) + int(0.8 * SR)
        x = np.arange(nbar) / SR
        envp = np.minimum(1.0, x / 0.5) * np.clip((bar + 0.7 - x) / 0.7, 0, 1)
        pad = np.zeros(nbar)
        for k, tv in enumerate(tones):
            f = midi(deg_midi(root + 12, sc, tv))
            for det in (-0.006, 0.0, 0.006):
                pad += saw(f, nbar, det) * 0.05
        if th["extra"] == "tide":
            envp *= 0.75 + 0.25 * np.sin(2 * np.pi * x / (bar * 2))
        pad = sos(pad * envp, "lowpass", th["cut"])
        put(A, t0 * SR, pan(pad, 0.0))
        bm = midi(deg_midi(root - 12, sc, d))
        pat = {"roots8": [0, 2, 4, 6, 8, 10, 12, 14], "sync": [0, 3, 6, 8, 11, 14], "pulse16": list(range(16)), "half": [0, 8]}[th["bass"]]
        for s_i in pat:
            ln = int((step * (2 if th["bass"] in ("roots8",) else (1 if th["bass"] == "pulse16" else 3.5))) * SR)
            oct_up = 12 if (th["bass"] in ("roots8", "sync") and s_i % 4 == 2) else 0
            f = midi(deg_midi(root - 12, sc, d)) * (2 ** (oct_up / 12))
            bx = (saw(f, ln) * 0.55 + np.sin(2 * np.pi * f * np.arange(ln) / SR) * 0.7)
            bx = sos(bx, "lowpass", 420) * env_ad(ln, 0.005, step * 3.0 if th["bass"] != "pulse16" else step * 1.2)
            if th["extra"] == "wobble":
                bx *= 0.65 + 0.35 * np.sin(2 * np.pi * 4.0 * np.arange(ln) / SR)
            put(A, (t0 + s_i * step) * SR, pan(bx * 0.55, 0.0))
        # ---- B: Arpeggio + Motiv
        arp_tones = [d, d + 2, d + 4, d + 7, d + 9, d + 11, d + 14]
        pat_b = {"updown": [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 0, 1], "up16": [0, 1, 2, 3, 4, 5, 4, 3] * 2,
                 "skip": [0, 2, 1, 3, 2, 4, 3, 5, 4, 2, 3, 1, 2, 0, 1, 3]}[th["arp"]]
        stride = 1 if th["arp"] != "updown" and th["hats"] == 16 else 2
        if th["extra"] == "sparse": stride = 4
        for s_i in range(0, 16, stride):
            ix = pat_b[(s_i // stride) % len(pat_b)] if stride == 1 else pat_b[(s_i // stride) % len(pat_b)]
            f = midi(deg_midi(root + 12, sc, arp_tones[ix % len(arp_tones)]))
            ln = int(step * 4 * SR)
            sig = (saw(f, ln) if th["lead"] == "saw" else square(f, ln)) * env_ad(ln, 0.003, step * 2.2) * 0.16
            sig = sos(sig, "lowpass", 3600)
            put(B, (t0 + s_i * step) * SR, pan(sig, 0.4 * (1 if (s_i // stride) % 2 else -1)))
        if b % 2 == 0:       # Motiv-Ton in der Höhe, jeden zweiten Takt
            f = midi(deg_midi(root + 24, sc, d + (4 if b % 4 else 2)))
            ln = int(1.6 * spb * SR)
            sig = sos(saw(f, ln, 0.004) + saw(f, ln, -0.004), "lowpass", 2800) * env_ad(ln, 0.02, spb * 0.9) * 0.1
            put(B, (t0 + 0 * step) * SR, pan(sig, 0.0))
    # ---- C: Drums, Hats, Riser, Besonderheiten
    kicks = {"four": [0, 4, 8, 12], "half": [0, 10], "break": [0, 6, 10]}[th["kick"]]
    for b in range(BARS):
        t0 = b * bar
        for s_i in kicks: put(C, (t0 + s_i * step) * SR, pan(kick() * 0.9, 0.0))
        for s_i in (4, 12): put(C, (t0 + s_i * step) * SR, pan(snare() * 0.55, 0.05))
        hs = range(0, 16, 2) if th["hats"] == 8 else range(0, 16)
        for s_i in hs:
            acc = 1.0 if s_i % 4 == 2 else 0.55
            put(C, (t0 + s_i * step) * SR, pan(hat(open_=(s_i == 14 and b % 2)) * 0.22 * acc, 0.3))
        if th["extra"] in ("anvil", "clank", "epic") and b % 2 == 0:
            for s_i in (4, 12):
                put(C, (t0 + s_i * step) * SR, pan(metal() * (0.22 if th["extra"] != "clank" else 0.3), -0.25))
        if b % 4 == 3:       # Riser im letzten Viertel jedes 4er-Blocks
            n = int(spb * SR); tt = np.arange(n) / SR
            ris = sos(rng.standard_normal(n), "bandpass", [600, 6000]) * (tt / tt[-1]) ** 2 * 0.35
            put(C, (t0 + 3 * spb) * SR, pan(ris, 0.0))
    stems = {}
    for key, buf, wet, peak in (("A", A, 0.30, 0.45), ("B", B, 0.26, 0.32), ("C", C, 0.12, 0.38)):
        if key == "B": buf = pingpong(buf, step * 3, 0.42, 0.45)
        for ch in range(2): buf[:, ch] = reverb(buf[:, ch], wet=wet)
        # nahtlos: Ausklang hinter dem Loop-Ende auf den Anfang addieren
        loop = buf[:N].copy(); loop[:tail] += buf[N:N + tail] if (N + tail) <= L else 0
        loop = np.tanh(loop / max(np.abs(loop).max(), 1e-6) * 1.2) / np.tanh(1.2) * peak
        stems[key] = loop
    return stems

def write_ogg(path, x):
    tmp = path[:-4] + ".wav"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32000).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.remove(tmp)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(THEMES)
    for name in names:
        stems = render(name, THEMES[name])
        for key, x in stems.items():
            write_ogg(f"{OUT}{name}_{key}.ogg", x)
        rms = {k: float(np.sqrt((v ** 2).mean())) for k, v in stems.items()}
        seam = {k: float(np.abs(v[-1] - v[0]).max()) for k, v in stems.items()}
        print(f"{name}: {len(stems['A']) / SR:.1f} s  RMS {rms}  Naht {seam}", flush=True)
