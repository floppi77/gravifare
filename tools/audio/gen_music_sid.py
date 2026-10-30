"""Erzeugt die Musik des Spiels im Klang eines C64-SID-Chips (eigene Synthese, NumPy/SciPy, keine Samples):
Pulswellen mit PWM, Dreieck, Säge und Rauschen, schnelle Akkord-Arpeggien, Vibrato, SID-typischer Echo-Trick,
Dreieck-/Rauschen-Schlagzeug. Je Thema 32 Takte (4 Abschnitte à 8 Takte: A, A mit Variation, B, A mit Schluss) und
drei synchrone Schichten (Stems): A = Bass + Akkord-Arpeggio, B = Melodie + Gegenstimme, C = Schlagzeug.
Themen: menu und t00..t19 (ein Thema je 5 Level, siehe Music.theme_for_level). Mono, 32 kHz, nahtlos loopbar.
Aufruf: python3 tools/audio/gen_music_sid.py [thema ...]   -> assets/audio/music/<thema>_<A|B|C>.ogg"""
import os, subprocess, sys, wave
import numpy as np

SR = 32000
OUT = "assets/audio/music/"
BARS = 32
SCALES = {"minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10],
          "harm": [0, 2, 3, 5, 7, 8, 11], "major": [0, 2, 4, 5, 7, 9, 11], "mixo": [0, 2, 4, 5, 7, 9, 10],
          "lydian": [0, 2, 4, 6, 7, 9, 11]}

# Name: (Grundton MIDI, Skala, bpm, Akkordfolge A, Folge B, Folge Schluss, Bass, Lead-Klang, Arpeggio, Schlagzeug, Seed)
T = {
 "menu": (50, "major",  104, [0, 4, 5, 3], [3, 4, 2, 5], [3, 4, 0, 0], "oct",    "pulse", "up",    "four",  1),
 "t00":  (45, "dorian", 112, [0, 3, 0, 4], [5, 3, 4, 0], [3, 4, 5, 0], "oct",    "pulse", "up",    "four",  2),
 "t01":  (43, "minor",  120, [0, 5, 2, 6], [3, 4, 0, 0], [5, 6, 4, 0], "gallop", "saw",   "updown", "drive", 3),
 "t02":  (40, "mixo",   116, [0, 6, 3, 4], [5, 3, 6, 4], [3, 4, 0, 0], "roots8", "pulse", "up",    "four",  4),
 "t03":  (47, "minor",  126, [0, 3, 5, 4], [0, 6, 5, 4], [3, 6, 4, 0], "sync",   "pulse", "skip",  "drive", 5),
 "t04":  (38, "phrygian", 108, [0, 1, 0, 6], [3, 1, 4, 0], [1, 6, 4, 0], "walk",   "saw",   "skip",  "break", 6),
 "t05":  (44, "major",  124, [0, 4, 5, 3], [2, 5, 3, 4], [3, 4, 5, 0], "gallop", "pulse", "up",    "drive", 7),
 "t06":  (41, "minor",  100, [0, 6, 5, 6], [3, 2, 4, 0], [5, 4, 3, 0], "half",   "tri",   "updown", "half",  8),
 "t07":  (46, "dorian", 132, [0, 3, 6, 3], [4, 3, 5, 0], [3, 4, 5, 0], "sync",   "pulse", "up",    "drive", 9),
 "t08":  (39, "harm",   118, [0, 3, 4, 0], [5, 4, 3, 4], [5, 3, 4, 0], "gallop", "saw",   "skip",  "break", 10),
 "t09":  (42, "lydian", 110, [0, 1, 4, 0], [3, 4, 1, 5], [3, 4, 5, 0], "oct",    "pulse", "updown", "four",  11),
 "t10":  (36, "minor",  128, [0, 5, 3, 4], [0, 2, 6, 4], [5, 6, 4, 0], "pedal",  "saw",   "up",    "drive", 12),
 "t11":  (45, "mixo",   106, [0, 4, 6, 4], [3, 6, 4, 0], [3, 4, 5, 0], "walk",   "pulse", "skip",  "break", 13),
 "t12":  (40, "phrygian", 122, [0, 6, 1, 0], [3, 4, 1, 0], [6, 4, 3, 0], "gallop", "pulse", "up",    "drive", 14),
 "t13":  (48, "major",  114, [0, 5, 3, 4], [1, 4, 2, 5], [3, 4, 5, 0], "oct",    "tri",   "updown", "four",  15),
 "t14":  (37, "minor",  134, [0, 2, 3, 5], [4, 3, 5, 0], [3, 5, 4, 0], "pedal",  "saw",   "up",    "drive", 16),
 "t15":  (43, "dorian", 102, [0, 3, 6, 4], [5, 6, 3, 4], [3, 4, 5, 0], "half",   "pulse", "skip",  "half",  17),
 "t16":  (41, "harm",   130, [0, 3, 5, 4], [6, 5, 4, 0], [5, 6, 4, 0], "sync",   "saw",   "up",    "drive", 18),
 "t17":  (46, "lydian", 120, [0, 4, 1, 4], [3, 5, 1, 4], [3, 4, 5, 0], "gallop", "pulse", "updown", "four",  19),
 "t18":  (38, "minor",  136, [0, 6, 5, 4], [0, 3, 6, 4], [5, 6, 4, 0], "pedal",  "saw",   "up",    "drive", 20),
 "t19":  (45, "harm",   140, [0, 5, 3, 4], [6, 5, 3, 4], [5, 6, 4, 0], "gallop", "pulse", "up",    "drive", 21),
}

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)
def deg_midi(root, scale, deg):
    s = SCALES[scale]
    return root + s[deg % 7] + 12 * (deg // 7)

def noise(n, rate, rng):
    k = max(1, int(SR // rate))
    return np.repeat(rng.choice([-1.0, 1.0], size=n // k + 2), k)[:n]

def note(buf, start, dur, f0, kind, amp, a=0.003, d=0.12, s=0.55, r=0.02, vib=0.0, duty=0.5, pwm=0.0, pwm_rate=1.3, arp=None, arp_rate=24.0):
    start = int(start)
    n = min(int(dur), len(buf) - start)
    if n <= 8: return
    t = np.arange(n) / SR
    if arp is not None:
        fa = np.array(arp, dtype=float)
        f = fa[(t * arp_rate).astype(int) % len(fa)]
    else:
        f = np.full(n, f0)
    if vib: f = f * (1 + vib * np.sin(2 * np.pi * 5.7 * t) * np.clip((t - 0.06) / 0.15, 0, 1))
    ph = (np.cumsum(f) / SR) % 1.0
    if kind == "pulse":
        w = np.where(ph < (duty + pwm * np.sin(2 * np.pi * pwm_rate * t)), 1.0, -1.0)
    elif kind == "saw":
        w = 2 * ph - 1
    elif kind == "tri":
        w = 4 * np.abs(ph - 0.5) - 1
    else:
        w = np.zeros(n)
    env = np.minimum(1.0, t / max(a, 1e-4)) * (s + (1 - s) * np.exp(-np.maximum(t - a, 0) / d))
    dur_s = n / SR
    env *= np.clip((dur_s - t) / max(r, 1e-3), 0, 1)
    buf[start:start + n] += w * env * amp

def kick(buf, start, amp=0.9):
    n = int(0.16 * SR); t = np.arange(n) / SR
    f = 38 + 140 * np.exp(-t * 38)
    ph = np.cumsum(f) / SR % 1.0
    w = (4 * np.abs(ph - 0.5) - 1) * np.exp(-t * 16)
    put(buf, start, w * amp)

def snare(buf, start, rng, amp=0.6):
    n = int(0.2 * SR); t = np.arange(n) / SR
    w = noise(n, 11000, rng) * np.exp(-t * 20) * 0.85 + (4 * np.abs((np.cumsum(np.full(n, 190.0)) / SR) % 1.0 - 0.5) - 1) * np.exp(-t * 32) * 0.5
    put(buf, start, w * amp)

def hat(buf, start, rng, amp=0.22, open_=False):
    n = int((0.13 if open_ else 0.04) * SR); t = np.arange(n) / SR
    w = noise(n, 16000, rng) * np.exp(-t * (26 if open_ else 95))
    put(buf, start, np.diff(w, prepend=0.0) * amp * 1.2)

def tom(buf, start, f0, amp=0.5):
    n = int(0.14 * SR); t = np.arange(n) / SR
    f = f0 * (0.6 + 0.4 * np.exp(-t * 14))
    ph = np.cumsum(f) / SR % 1.0
    put(buf, start, (4 * np.abs(ph - 0.5) - 1) * np.exp(-t * 20) * amp)

def put(buf, start, sig):
    s = int(start)
    if s >= len(buf): return
    e = min(len(buf), s + len(sig)); buf[s:e] += sig[:e - s]

# ------------------------------------------------------------------ Komposition
RHYTHMS = [[0, 3, 6, 8, 10, 12, 14], [0, 2, 4, 6, 8, 11, 14], [0, 4, 6, 8, 12], [0, 2, 3, 6, 8, 10, 11, 14], [0, 6, 8, 14], [0, 3, 4, 8, 11, 12]]
OFFS = [-2, -1, -1, 0, 1, 1, 2, 3]

def make_phrase(rng, bars=4, base=7, sparse=False):
    """Phrase = je Takt Liste (Schritt, Länge, Stufe relativ zum Akkordgrundton)."""
    phrase = []
    pos = base
    for b in range(bars):
        rh = RHYTHMS[rng.integers(len(RHYTHMS))]
        if sparse: rh = rh[::2] or [0]
        bar = []
        for i, st in enumerate(rh):
            ln = (rh[i + 1] - st) if i + 1 < len(rh) else (16 - st)
            if st % 8 == 0:
                pos = min([0, 2, 4, 7, 9, 11], key=lambda c: abs(c - pos))
            else:
                pos += int(rng.choice(OFFS))
            pos = int(np.clip(pos, 0, 13))
            bar.append((st, max(1, min(ln, 6)), pos))
        phrase.append(bar)
    return phrase

def bass_pattern(kind):
    return {"oct": [(s, 2, 12 if (s // 2) % 2 else 0) for s in range(0, 16, 2)],
            "roots8": [(s, 2, 0) for s in range(0, 16, 2)],
            "gallop": [(s, 1 if (s % 4) else 2, 0) for s in (0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15)],
            "half": [(0, 7, 0), (8, 7, 0)],
            "sync": [(0, 3, 0), (3, 3, 0), (6, 2, 12), (8, 3, 0), (11, 3, 0), (14, 2, 12)],
            "walk": [(0, 4, 0), (4, 4, 7), (8, 4, 12), (12, 4, 7)],
            "pedal": [(s, 1, 0 if s % 4 else 0) for s in range(16)]}[kind]

def render(name):
    root, scale, bpm, pa, pb, pc, bass_k, lead_k, arp_k, drum_k, seed = T[name]
    rng = np.random.default_rng(seed * 7919)
    step = 60.0 / bpm / 4.0
    bar_n = int(round(16 * step * SR))
    N = BARS * bar_n
    A = np.zeros(N); B = np.zeros(N); C = np.zeros(N)
    st_n = lambda b, s: b * bar_n + int(s * step * SR)
    prog = []
    for sec in range(4):
        base = pb if sec == 2 else pa
        for rep in range(2):
            ch = list(base)
            if sec == 3 and rep == 1: ch = list(pc)
            prog += ch
    P1 = make_phrase(rng, 4, 7)
    P2 = make_phrase(rng, 4, 9)
    P3 = make_phrase(rng, 4, 11, sparse=True)
    # Variationen: zweite Wiederholung ändert den letzten Takt
    def vary(p):
        q = [list(x) for x in p]
        q[-1] = make_phrase(rng, 1, 7)[0]
        return q
    phrases = [P1, vary(P1), P2, vary(P2), P3, vary(P3), P1, [list(x) for x in P1[:3]] + [[(0, 14, 0)]]]
    bass_pat = bass_pattern(bass_k)
    for b in range(BARS):
        d = prog[b]
        sec = b // 8
        t0 = st_n(b, 0)
        # ---------------- A: Bass + Akkord-Arpeggio
        broot = deg_midi(root - 12, scale, d)
        for (s, ln, ol) in bass_pat:
            kind = "pulse" if bass_k != "half" else "tri"
            amp = 0.34 if sec != 1 else 0.38
            note(A, st_n(b, s), ln * step * SR * 0.92, midi(broot + ol), kind, amp, a=0.002, d=0.16, s=0.45, r=0.015, duty=0.28, pwm=0.12, pwm_rate=0.9)
        chord = [deg_midi(root + 12, scale, d + k) for k in (0, 2, 4)]
        arps = [midi(c) for c in chord] + ([midi(chord[0] + 12)] if arp_k != "up" else [])
        arate = 25.0 if sec != 2 else 16.67
        note(A, t0, bar_n, 0, "tri", 0.16, a=0.01, d=1.0, s=0.9, r=0.03, arp=arps, arp_rate=arate)
        # ---------------- B: Melodie (+ SID-Echo) und Gegenstimme
        ph = phrases[b // 4]
        for (s, ln, off) in ph[b % 4]:
            f = midi(deg_midi(root + 12, scale, d + off))
            dur = ln * step * SR * 0.95
            if lead_k == "pulse":
                kw = dict(kind="pulse", duty=0.5, pwm=0.28, pwm_rate=1.7)
            elif lead_k == "saw":
                kw = dict(kind="saw")
            else:
                kw = dict(kind="tri")
            note(B, st_n(b, s), dur, f, amp=0.30 if lead_k != "tri" else 0.4, a=0.004, d=0.35, s=0.7, r=0.03, vib=0.006, **kw)
            note(B, st_n(b, s + 3), dur, f, "pulse", 0.10, a=0.003, d=0.2, s=0.5, r=0.02, duty=0.125)     # Echo
        if sec in (1, 2) or (sec == 3 and b % 2 == 0):
            pat = {"up": [0, 1, 2, 3, 2, 1, 0, 1], "updown": [0, 1, 2, 3, 4, 3, 2, 1], "skip": [0, 2, 1, 3, 2, 4, 3, 1]}[arp_k]
            up = [midi(deg_midi(root + 24, scale, d + k)) for k in (0, 2, 4, 7, 9)]
            for s in range(0, 16, 2):
                note(B, st_n(b, s), 2 * step * SR, up[pat[(s // 2) % 8] % 5], "pulse", 0.10, a=0.002, d=0.08, s=0.3, r=0.01, duty=0.125)
        # ---------------- C: Schlagzeug
        kicks = {"four": (0, 4, 8, 12), "drive": (0, 4, 8, 12, 14), "break": (0, 6, 10, 13), "half": (0, 10)}[drum_k]
        snares = (4, 12) if drum_k != "half" else (8,)
        for s in kicks: kick(C, st_n(b, s))
        for s in snares: snare(C, st_n(b, s), rng)
        hstep = 2 if (drum_k in ("four", "half", "break") or sec == 0) else 1
        for s in range(0, 16, hstep):
            hat(C, st_n(b, s), rng, 0.2 if s % 4 else 0.28, open_=(s == 14 and b % 2 == 1))
        if b % 8 == 7:       # Wirbel am Ende jedes Abschnitts
            for k, s in enumerate((12, 13, 14, 15)):
                tom(C, st_n(b, s), 220 - 30 * k)
        if sec == 0 and b < 4:
            C[t0:t0 + bar_n] *= 0.6
    stems = {}
    for key, buf, rms_t in (("A", A, 0.17), ("B", B, 0.16), ("C", C, 0.11)):      # gleiche Lautheit je Schicht
        x = buf / max(float(np.sqrt((buf ** 2).mean())), 1e-6) * rms_t
        stems[key] = np.tanh(x * 1.6) / 1.6
    return stems

def write_ogg(path, x):
    tmp = path[:-4] + ".wav"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 30000).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "1", path], check=True)
    os.remove(tmp)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name in (sys.argv[1:] or list(T)):
        stems = render(name)
        for key, x in stems.items():
            write_ogg(f"{OUT}{name}_{key}.ogg", x)
        rms = {k: round(float(np.sqrt((v ** 2).mean())), 3) for k, v in stems.items()}
        print(f"{name}: {len(stems['A']) / SR:.1f} s  RMS {rms}", flush=True)
