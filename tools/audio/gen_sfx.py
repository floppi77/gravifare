"""Synthetisiert die Sound-Effekte des Spiels (eigene Arbeit, numpy -> 16-bit WAV, 44,1 kHz).
Aufruf: python3 tools/audio/gen_sfx.py   -> assets/audio/sfx/*.wav"""
import numpy as np, wave, os
SR = 44100
OUT = "assets/audio/sfx/"
rng = np.random.default_rng(5)

def save(name, x):
    x = np.clip(x, -1, 1)
    ch = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(OUT + name + ".wav", "wb") as w:
        w.setnchannels(ch); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32000).astype("<i2").tobytes())

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1):
    e = np.ones(n); na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr); return e
def lp(x, k):  # einfacher Tiefpass; k darf ein Array (zeitveränderlich) sein
    y = np.zeros_like(x); a = 0.0
    ka = np.broadcast_to(np.asarray(k, dtype=float), x.shape)
    for i in range(len(x)):
        a += ka[i] * (x[i] - a); y[i] = a
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
def pan(x, p):
    """Mono -> Stereo mit Gleichleistungs-Panorama (p: -1 links ... +1 rechts, auch als Array)."""
    ang = (np.asarray(p) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(ang), x * np.sin(ang)], axis=1)

def sos(x, kind, fc, order=2):
    from scipy import signal
    return signal.sosfilt(signal.butter(order, fc, btype=kind, fs=SR, output="sos"), x)

def saw_f(freq):
    """Sägezahn mit zeitveränderlicher Frequenz (Array)."""
    ph = np.cumsum(freq) / SR
    return 2.0 * (ph % 1.0) - 1.0

def reverb(st, seconds=1.8, decay=2.6, wet=0.28):
    from scipy import signal
    n = int(seconds * SR); tt = np.arange(n) / SR
    out = np.zeros_like(st)
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-tt * decay)
        ir = sos(ir, "lowpass", 4500)                       # dunkler Raum
        ir[:int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        out[:, ch] = signal.fftconvolve(st[:, ch], ir)[:len(st)] * (1.0 / np.sqrt(n / 300.0))
    return st * (1.0 - wet * 0.5) + out * wet

def pingpong(st, delay_s, fb=0.4, mix=0.35):
    d = int(delay_s * SR); out = st.copy()
    buf = st.copy()
    for k in range(1, 6):
        sh = np.zeros_like(st)
        sh[k * d:, 0] = st[:len(st) - k * d, 1 if k % 2 else 0]
        sh[k * d:, 1] = st[:len(st) - k * d, 0 if k % 2 else 1]
        out += sh * (fb ** k) * mix
    return out

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)

def transit():
    """8 s Weltraumflug in Stereo, zeitgenau zur Levelwechsel-Sequenz:
       0-2 s Aufstieg (Riser) beim Ausblenden, 2 s Einschlag, 2-5,6 s Flug (Pads, Arpeggio, Vorbeiflüge),
       5,6-8 s Abbremsen und Auflösung beim Anflug. Eigene Synthese, kein Fremdmaterial."""
    d = 8.0; tt = t(d); n = len(tt)
    st = np.zeros((n, 2))
    # --- Riser (0-2 s): Rauschsweep + Tonsweep + Subbass
    sweep_k = np.interp(tt, [0, 2.0], [0.01, 0.75])
    noise = lp(rng.standard_normal(n), sweep_k)
    noise = sos(noise - lp(noise, 0.004), "lowpass", 4200) * 0.55   # Bandpass-Charakter, nicht zu zischend
    r_env = np.interp(tt, [0, 0.2, 1.7, 2.0, 2.06], [0, 0.25, 1.0, 1.0, 0.0])
    riser_f = 110 * (1760 / 110) ** np.clip(tt / 2.0, 0, 1)
    tone = sos(saw_f(riser_f * (1 + 0.004 * np.sin(2 * np.pi * 6 * tt))), "lowpass", 3500) * 0.16
    sub = np.sin(2 * np.pi * np.cumsum(np.interp(tt, [0, 2.0], [38, 72])) / SR) * 0.45
    st += pan((noise * 0.9 + tone) * r_env, np.interp(tt, [0, 2.0], [-0.5, 0.5]))
    st += pan(sub * np.interp(tt, [0, 1.8, 2.05], [0, 0.8, 0]), 0.0)
    # --- Einschlag bei 2,0 s: Boom + Funkeln
    ti = np.clip(tt - 2.0, 0, None) * (tt >= 2.0)
    boom = np.sin(2 * np.pi * (52 + 70 * np.exp(-ti * 9)) * ti) * np.exp(-ti * 3.2) * (tt >= 2.0) * 0.9
    burst = sos(rng.standard_normal(n), "lowpass", 2500) * np.exp(-ti * 9) * (tt >= 2.0) * 0.5
    bell = np.sin(2 * np.pi * 1318 * ti + 2.2 * np.sin(2 * np.pi * 1976 * ti)) * np.exp(-ti * 4.0) * (tt >= 2.0) * 0.12
    st += pan(boom + burst, 0.0) + pan(bell, np.sin(ti * 3) * 0.6)
    # --- Pad-Akkorde: Am(add9) 2,0-3,8 und Fmaj7 3,8-5,6, danach Auflösung nach C(add9) ab 5,6
    chords = [(2.0, 3.9, [45, 52, 60, 64, 71]), (3.8, 5.7, [41, 48, 57, 60, 64]), (5.6, 8.0, [48, 55, 60, 64, 67, 74])]
    pad = np.zeros((n, 2))
    for (t0, t1, notes) in chords:
        L = int((t1 - t0) * SR); i0 = int(t0 * SR)
        x = np.arange(L) / SR
        env = np.minimum(1.0, x / 0.45) * np.clip((t1 - t0 - x) / 0.7, 0, 1)
        if t0 >= 5.6:
            env = np.minimum(1.0, x / 0.6) * np.clip((t1 - t0 - x) / 0.9, 0, 1) * 0.9
        for j, nn in enumerate(notes):
            for det, p in ((-6, -0.5), (0, 0.0), (6, 0.5)):
                f = midi(nn) * 2 ** (det / 1200.0)
                seg = saw_f(np.full(L, f)) * env * (0.045 if nn < 60 else 0.03)
                pad[i0:i0 + L] += pan(seg, p * (1 if j % 2 else -1))
    cutoff = 900 + 700 * np.sin(2 * np.pi * 0.3 * tt)
    for ch in range(2):
        pad[:, ch] = sos(pad[:, ch], "lowpass", 1700)
    st += pad
    # --- Arpeggio (16tel bei 140 bpm) 2,2-5,5 und Funkel-Auflösung 6,2-7,3
    step = 60.0 / 140.0 / 4.0
    pattern = [69, 72, 76, 81, 76, 72, 79, 76, 72, 69, 74, 77, 81, 77, 74, 72]
    arp = np.zeros((n, 2))
    k = 0; t0 = 2.2
    while t0 < 5.5:
        nn = pattern[k % len(pattern)] + (-4 if t0 > 3.9 else 0)     # zweiter Akkord tiefer (F)
        L = int(0.26 * SR); i0 = int(t0 * SR); x = np.arange(L) / SR
        f = midi(nn)
        seg = (saw_f(np.full(L, f)) * 0.6 + np.sign(np.sin(2 * np.pi * f * x)) * 0.4) * np.exp(-x * 13) * 0.07
        seg = sos(seg, "lowpass", 2400)
        arp[i0:i0 + L] += pan(seg, 0.35 * (1 if k % 2 else -1))
        t0 += step; k += 1
    t0 = 6.3
    for j, nn in enumerate([84, 88, 91, 96]):
        L = int(0.6 * SR); i0 = int(t0 * SR); x = np.arange(L) / SR
        arp[i0:i0 + L] += pan(np.sin(2 * np.pi * midi(nn) * x) * np.exp(-x * 5) * 0.05, -0.4 + 0.27 * j)
        t0 += step * 2
    st += pingpong(arp, 3 * step, 0.45, 0.45)
    # --- Antriebsdrohnen (steigt, hält, fällt beim Anflug)
    f_eng = np.interp(tt, [0, 2.0, 5.6, 8.0], [50, 110, 112, 62])
    eng = sos(saw_f(f_eng) + 0.5 * saw_f(f_eng * 1.005), "lowpass", 380) * 0.17
    eng += sos(rng.standard_normal(n), "lowpass", 260) * 0.06
    st += pan(eng * np.interp(tt, [0, 1.5, 2.3, 5.6, 7.2, 8.0], [0, 0.5, 1.0, 1.0, 0.55, 0.0]), 0.0)
    # --- Vorbeiflüge (Planeten) mit Doppler-Filter und Panorama links->rechts
    for t0, w, big in ((2.7, 0.9, 0.7), (3.95, 1.25, 1.0), (5.0, 0.8, 0.6)):
        env = np.exp(-((tt - t0) / (w * 0.33)) ** 2)
        k_t = 0.03 + 0.28 * np.clip((tt - t0) / w + 0.55, 0, 1) ** 2   # Hochlauf des Filters = Doppler
        sh = sos(lp(rng.standard_normal(n) * env, k_t), "lowpass", 3800) * 1.5 * big
        st += pan(sh * 0.42, np.clip((tt - t0) / w * 1.2, -1, 1))
    # --- Anflug-Abstieg (5,6-7,6)
    f_dn = np.interp(tt, [5.6, 7.6], [1500, 150])
    down = sos(saw_f(f_dn), "lowpass", 2200) * 0.09 * np.interp(tt, [5.5, 5.9, 7.0, 7.7], [0, 1, 0.45, 0])
    st += pan(down, np.interp(tt, [5.6, 7.6], [0.6, -0.2]))
    st = reverb(st)
    for ch in range(2):
        st[:, ch] = sos(st[:, ch], "lowpass", 9500)
    peak = np.abs(st).max()
    st = np.tanh(st / peak * 1.25) / np.tanh(1.25) * 0.88
    st[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))[:, None] ** 2
    save("transit", st)

def ui_move():
    tt = t(0.04); save("ui_move", np.sign(np.sin(2 * np.pi * 700 * tt)) * 0.15 * env(len(tt), 0.002, 0.02))
def ui_ok():
    tt = t(0.09); save("ui_ok", np.sin(2 * np.pi * 1000 * tt) * 0.3 * env(len(tt), 0.002, 0.04))

def pump_hit():
    """Metallisches Scheppern beim Rammen der Zapfsäule."""
    d = 0.55; tt = t(d)
    x = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * k) * a for f, k, a in ((220, 7, 0.5), (353, 9, 0.35), (611, 12, 0.25), (1090, 16, 0.15)))
    x += lp(rng.standard_normal(len(tt)), 0.5) * np.exp(-tt * 40) * 0.6
    save("pump_hit", x * 0.8)
def pump_boom():
    """Explosion der Tankstelle: Boom, Knistern, aufsteigendes Zischen."""
    d = 1.6; tt = t(d)
    boom = np.sin(2 * np.pi * (48 + 90 * np.exp(-tt * 7)) * tt) * np.exp(-tt * 2.6)
    burst = lp(rng.standard_normal(len(tt)), 0.4) * np.exp(-tt * 5.5) * 0.9
    crackle = (rng.random(len(tt)) > 0.992) * rng.standard_normal(len(tt)) * np.exp(-tt * 2.2) * 0.9
    hiss = lp(rng.standard_normal(len(tt)), 0.08) * np.exp(-((tt - 0.5) / 0.4) ** 2) * 0.25
    save("pump_boom", np.tanh((boom + burst + crackle + hiss) * 1.2) * 0.9)
def price_tick():
    """Kurzes zweistufiges Signal bei Preiswechsel."""
    x = np.concatenate([np.sin(2 * np.pi * f * t(0.06)) * 0.3 * env(int(0.06 * SR), 0.002, 0.03) for f in (880, 660)])
    save("price_tick", x)

def near_miss():
    """Kurzes tiefes Vorbeizischen (Zeitlupen-Moment)."""
    d = 0.7; tt = t(d)
    x = lp(rng.standard_normal(len(tt)), np.interp(tt, [0, 0.35, 0.7], [0.45, 0.04, 0.02])) * np.exp(-((tt - 0.25) / 0.2) ** 2) * 1.6
    x += np.sin(2 * np.pi * np.interp(tt, [0, 0.7], [300, 70]) * tt) * np.exp(-tt * 5) * 0.4
    save("near_miss", x * 0.8)
def perfect():
    """Kurzes aufsteigendes Glöckchen für eine perfekte Landung."""
    x = np.concatenate([np.sin(2 * np.pi * f * t(0.12)) * 0.22 * env(int(0.12 * SR), 0.004, 0.08) for f in (784, 988, 1319)])
    save("perfect", x)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (thrust_loop, side_loop, land, clunk, crash, hit, warn, coin, board, exit_open, transit, ui_move, ui_ok, pump_hit, pump_boom, price_tick, near_miss, perfect): f()
    print(sorted(os.listdir(OUT)))
