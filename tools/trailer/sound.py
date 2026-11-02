"""Klangbausteine für den Trailer: Laden, Mischen, Hall und synthetische Effekte (Riser, Einschläge, Whooshes). 48 kHz stereo, float32."""
import subprocess
import numpy as np

SR = 48000


def load(path, start=0.0, dur=None):
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)] + (["-t", str(dur)] if dur else []) + ["-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def save(path, y):
    y = np.clip(y, -1.0, 1.0)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ac", "2", "-ar", str(SR), "-i", "-", path], input=y.astype(np.float32).tobytes(), check=True)


class Mix:
    def __init__(self, seconds):
        self.y = np.zeros((int(seconds * SR), 2), np.float32)

    def add(self, clip, t, gain=1.0, pan=0.0):
        if clip.ndim == 1:
            clip = np.stack([clip, clip], 1)
        i = int(t * SR)
        if i < 0:
            clip = clip[-i:]
            i = 0
        n = min(len(clip), len(self.y) - i)
        if n <= 0:
            return
        g = np.array([gain * (1 - max(pan, 0)), gain * (1 + min(pan, 0))], np.float32)
        self.y[i:i + n] += clip[:n] * g


def fade(y, a=0.0, b=0.0):
    y = y.copy()
    if a > 0:
        n = int(a * SR); y[:n] *= np.linspace(0, 1, n)[:, None]
    if b > 0:
        n = int(b * SR); y[-n:] *= np.linspace(1, 0, n)[:, None]
    return y


def lowpass(y, fc):
    """Einpoliger Tiefpass; fc darf ein Array (je Sample, z. B. Sweep) sein."""
    fc = np.broadcast_to(np.asarray(fc, np.float64), (len(y),))
    a = 1 - np.exp(-2 * np.pi * fc / SR)
    out = np.empty_like(y)
    s = np.zeros(y.shape[1], np.float64)
    for i in range(len(y)):
        s += a[i] * (y[i] - s)
        out[i] = s
    return out


def reverb(y, seconds=2.5, wet=0.3, seed=1, damp=3500.0):
    n = int(seconds * SR)
    rng = np.random.default_rng(seed)
    ir = rng.standard_normal((n, 2)).astype(np.float32) * np.exp(-np.linspace(0, 7, n))[:, None].astype(np.float32)
    ir = lowpass(ir, damp)
    ir /= np.abs(ir).sum(0, keepdims=True) * 0.05
    L = len(y) + n
    N = 1 << (L - 1).bit_length()
    out = np.zeros((L, 2), np.float32)
    for c in range(2):
        out[:, c] = np.fft.irfft(np.fft.rfft(y[:, c], N) * np.fft.rfft(ir[:, c], N), N)[:L]
    out = out[:len(y) + n] * wet
    res = np.zeros((L, 2), np.float32)
    res[:len(y)] += y * (1 - wet)
    return res + out


def noise(seconds, seed=0):
    return np.random.default_rng(seed).standard_normal((int(seconds * SR), 2)).astype(np.float32) * 0.35


def riser(seconds, f0=200.0, f1=9000.0, seed=3):
    """Aufsteigendes Rauschen mit Sinus-Sweep, schwillt an."""
    n = int(seconds * SR)
    t = np.linspace(0, 1, n)
    fc = f0 * (f1 / f0) ** (t ** 1.5)
    y = lowpass(noise(seconds, seed), fc)
    ph = np.cumsum(2 * np.pi * (fc * 0.5) / SR)
    y += (np.sin(ph) * 0.25)[:, None]
    return y * (t ** 2.2)[:, None].astype(np.float32)


def impact(seconds=3.0, f=48.0, seed=5):
    """Tiefer Einschlag: fallender Sinus, Rauschschlag, langer Nachhall."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    fr = f + 90 * np.exp(-t * 14)
    body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 1.6)
    snap = lowpass(noise(seconds, seed), 7000 * np.exp(-t * 6) + 300) * np.exp(-t * 9)[:, None]
    y = body[:, None] * 0.95 + snap * 0.7
    return reverb(y.astype(np.float32), 2.0, 0.25)[:n]


def whoosh(seconds=1.0, up=True, seed=7):
    n = int(seconds * SR)
    t = np.linspace(0, 1, n)
    env = np.sin(np.pi * t) ** 2
    fc = 300 + 7000 * (t if up else 1 - t) ** 1.2
    y = lowpass(noise(seconds, seed), fc) * env[:, None]
    return y.astype(np.float32)


def tick(t=0.05, f=1800.0):
    n = int(t * SR)
    x = np.arange(n) / SR
    return (np.sin(2 * np.pi * f * x) * np.exp(-x * 90))[:, None].repeat(2, 1).astype(np.float32) * 0.5


def drone(seconds, f=55.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    y = sum(np.sin(2 * np.pi * f * k * t + k) * (0.5 / k) for k in (1, 2, 3, 4))
    y = (y * (1 + 0.15 * np.sin(2 * np.pi * 0.2 * t)))[:, None].repeat(2, 1).astype(np.float32)
    return y


def sidechain(y, hits, depth=0.5, release=0.25):
    """Duckt y kurz nach jedem Zeitpunkt in hits (Sekunden)."""
    env = np.ones(len(y), np.float32)
    for h in hits:
        i = int(h * SR)
        n = int(release * SR)
        if i >= len(y):
            continue
        seg = 1 - depth * np.exp(-np.linspace(0, 5, n))
        m = min(n, len(y) - i)
        env[i:i + m] = np.minimum(env[i:i + m], seg[:m])
    return y * env[:, None]


def normalize(y, peak=0.95):
    return y * (peak / max(np.abs(y).max(), 1e-6))
