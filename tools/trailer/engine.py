"""Kompositor für den Trailer: schneidet Movie-Maker-Aufnahmen (1080p60, mit Taxi-Spur) zu einer Zeitleiste,
fährt eine Kamera am Taxi entlang, setzt Zeitlupe, Farbkorrektur, Bloom, Farbsäume, Vignette, Korn, Blitze, Balken und Titel.
Jeder Ausgabeframe hängt nur von der Zeit ab, deshalb lässt sich die Zeitleiste in Abschnitten parallel rechnen."""
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import gaussian_filter1d

W, H, FPS = 1920, 1080, 60
CLIPS = None   # Ordner der Aufnahmen, setzt render.py


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def keyframes(kf, u, default=1.0):
    """Stückweise linear (mit Glättung je Segment): kf = [(t, v), ...]; Zahl statt Liste = konstant."""
    if not isinstance(kf, (list, tuple)):
        return kf
    if u <= kf[0][0]:
        return kf[0][1]
    for (t0, v0), (t1, v1) in zip(kf, kf[1:]):
        if u <= t1:
            return v0 + (v1 - v0) * ease((u - t0) / max(t1 - t0, 1e-9))
    return kf[-1][1]


class Trace:
    def __init__(self, path, sigma=0.45):
        rows = [l.split() for l in open(path)]
        self.f = np.array([int(r[0]) for r in rows])
        self.x = np.array([float(r[1]) for r in rows])
        self.y = np.array([float(r[2]) for r in rows])
        self.state = np.array([int(r[3]) for r in rows])
        self.vx = np.array([float(r[4]) for r in rows])
        self.vy = np.array([float(r[5]) for r in rows])
        self.hull = np.array([float(r[6]) for r in rows])
        s = sigma * FPS
        self.sx = gaussian_filter1d(self.x, s, mode="nearest")
        self.sy = gaussian_filter1d(self.y, s, mode="nearest")

    def at(self, t, smooth=True):
        i = min(max(int(round(t * FPS)), 0), len(self.x) - 1)
        return (self.sx[i], self.sy[i]) if smooth else (self.x[i], self.y[i])


class Source:
    """Sequentieller Leser einer Aufnahme ab Zeit t0 (Sekunden), liefert Frames per Index."""
    def __init__(self, clip, t0, span):
        self.cmd = ["ffmpeg", "-v", "error", "-ss", f"{t0:.4f}", "-t", f"{span:.4f}", "-i", f"{CLIPS}/{clip}.avi", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
        self.p = subprocess.Popen(self.cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=W * H * 3 * 4)
        self.t0 = t0
        self.cache = {}
        self.next = 0
        self.last = None

    def frame(self, k):
        """k = Frameindex relativ zu t0; nur nicht fallend aufrufen."""
        while self.next <= k:
            raw = self.p.stdout.read(W * H * 3)
            if len(raw) < W * H * 3:
                break
            self.last = np.frombuffer(raw, np.uint8).reshape(H, W, 3)
            self.cache[self.next] = self.last
            self.next += 1
            for old in [i for i in self.cache if i < k - 2]:
                del self.cache[old]
        return self.cache.get(k, self.last)

    def close(self):
        try:
            self.p.kill()
        except Exception:
            pass


class Shot:
    """clip: Aufnahme; src: Startzeit in der Aufnahme; dur: Ausgabedauer; speed: Tempo (Zahl oder [(u, v)]);
    zoom: Zoom (Zahl oder [(u, z)]); cam: 'follow' (Taxi), 'fix' oder None; at: Taxi-Position im Bild (0..1);
    grade: (Sättigung, Kontrast, (r, g, b)-Faktoren); bloom, ca: Stärke; shake: Pixel."""
    def __init__(self, clip, src, dur, t0=0.0, speed=1.0, zoom=1.0, cam="follow", at=(0.5, 0.5), fix=(960, 540), grade=(1.08, 1.06, (1, 1, 1)),
                 bloom=0.35, ca=0.6, shake=0.0, nearest=True, sigma=0.45, trace=None, lead=0.0, fix_to=None):
        self.__dict__.update(locals())
        del self.__dict__["self"]
        self.trace_obj = Trace(f"{CLIPS}/{trace or clip}.trace", sigma) if cam == "follow" else None
        self.reader = None

    def src_time(self, u):
        if not isinstance(self.speed, (list, tuple)):
            return self.src + u * self.speed
        # Integral des (stückweise linearen) Tempos
        n = 64
        us = np.linspace(0, u, max(int(n * u / max(self.dur, 1e-6)) + 2, 2))
        return self.src + float(np.trapezoid([keyframes(self.speed, x) for x in us], us))

    def render(self, u):
        ts = self.src_time(u)
        span = self.dur * (max(keyframes(self.speed, x) for x in np.linspace(0, self.dur, 20)) if isinstance(self.speed, (list, tuple)) else self.speed) + 1.0
        if self.reader is None:
            self.reader = Source(self.clip, self.src, span + 0.5)
        k = (ts - self.src) * FPS
        k0 = int(np.floor(k))
        a = self.reader.frame(k0)
        fr = k - k0
        if fr > 0.02:
            b = self.reader.frame(k0 + 1)
            img = (a.astype(np.float32) * (1 - fr) + b.astype(np.float32) * fr).astype(np.uint8)
        else:
            img = a
        z = keyframes(self.zoom, u)
        if z > 1.0001 or self.cam == "fix" and z != 1.0:
            cw, ch = W / z, H / z
            if self.cam == "follow":
                px, py = self.trace_obj.at(ts + self.lead)
                cx = px - (self.at[0] - 0.5) * cw
                cy = py - (self.at[1] - 0.5) * ch
            else:
                cx, cy = self.fix
                if self.fix_to is not None:
                    k = min(max(u / max(self.dur, 1e-6), 0.0), 1.0)
                    cx, cy = cx + (self.fix_to[0] - cx) * k, cy + (self.fix_to[1] - cy) * k
            if self.shake:
                cx += np.sin(u * 91.0) * self.shake + np.sin(u * 57.0 + 1) * self.shake * 0.6
                cy += np.sin(u * 83.0 + 2) * self.shake + np.sin(u * 61.0) * self.shake * 0.6
            cx = min(max(cx, cw / 2), W - cw / 2)
            cy = min(max(cy, ch / 2), H - ch / 2)
            im = Image.fromarray(img).resize((W, H), Image.NEAREST if self.nearest and abs(z - round(z)) < 0.02 else Image.BICUBIC,
                                             box=(cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2))
            img = np.asarray(im)
        return img

    def close(self):
        if self.reader:
            self.reader.close()


def grade(img, g):
    sat, con, tint = g
    x = img.astype(np.float32) / 255.0
    luma = (x[..., 0] * 0.299 + x[..., 1] * 0.587 + x[..., 2] * 0.114)[..., None]
    x = luma + (x - luma) * sat
    x = (x - 0.5) * con + 0.5
    x = x * np.array(tint, np.float32)
    return np.clip(x, 0, 1)


def bloom(x, amount):
    if amount <= 0:
        return x
    small = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).resize((480, 270), Image.BOX)
    s = np.asarray(small).astype(np.float32) / 255.0
    lum = s.max(2, keepdims=True)
    s = s * np.clip((lum - 0.55) / 0.45, 0, 1)
    b = Image.fromarray((s * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
    b2 = Image.fromarray((s * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))
    glow = (np.asarray(b.resize((W, H), Image.BILINEAR)).astype(np.float32) + np.asarray(b2.resize((W, H), Image.BILINEAR)).astype(np.float32)) / 255.0
    return 1 - (1 - x) * (1 - np.clip(glow * amount, 0, 1))


def aberrate(x, px):
    k = int(round(px))
    if k == 0:
        return x
    out = x.copy()
    out[:, k:, 0] = x[:, :-k, 0]
    out[:, :-k, 2] = x[:, k:, 2]
    return out


_VIG = None


def vignette(x, strength):
    global _VIG
    if _VIG is None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
        _VIG = np.clip(r - 0.55, 0, 1) ** 1.6
    return x * (1 - strength * _VIG[..., None])


_GRAIN = None


def grain(x, amount, seed):
    global _GRAIN
    if _GRAIN is None:
        _GRAIN = np.random.default_rng(1234).standard_normal((24, H // 2, W // 2)).astype(np.float32)
    g = _GRAIN[seed % 24]
    g = np.repeat(np.repeat(g, 2, 0), 2, 1)
    return x + g[..., None] * amount


FONT_T = "assets/fonts/jersey10/Jersey10-Regular.ttf"
FONT_B = "assets/fonts/oxanium/Oxanium.ttf"
_TEXT = {}


def text_layer(text, size, font=FONT_T, fill=(255, 207, 51), outline=(8, 12, 40), glow=(255, 160, 40), spacing=0, width=None):
    """Vorgerendertes RGBA-Bild (Text mit Kontur und Leuchten), zentriert aufs Bild gelegt."""
    key = (text, size, font, fill, outline, glow, spacing, width)
    if key in _TEXT:
        return _TEXT[key]
    f = ImageFont.truetype(font, size)
    if font == FONT_B:
        try:
            f.set_variation_by_axes([700])
        except Exception:
            pass
    lines = text.split("\n")
    lh = int(size * 1.0)
    pad = 60
    im = Image.new("RGBA", (W, lh * len(lines) + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, ln in enumerate(lines):
        tw = d.textlength(ln, font=f) + spacing * max(len(ln) - 1, 0)
        x = (W - tw) / 2
        y = pad + i * lh
        if spacing:
            for ch in ln:
                d.text((x, y), ch, font=f, fill=fill, stroke_width=max(size // 18, 2), stroke_fill=outline)
                x += d.textlength(ch, font=f) + spacing
        else:
            d.text((x, y), ln, font=f, fill=fill, stroke_width=max(size // 18, 2), stroke_fill=outline)
    gl = Image.new("RGBA", im.size, (0, 0, 0, 0))
    mask = im.split()[3].filter(ImageFilter.GaussianBlur(size // 5))
    gl.paste(Image.new("RGBA", im.size, glow + (255,)), (0, 0), mask.point(lambda p: int(p * 0.9)))
    out = Image.alpha_composite(gl, im)
    arr = np.asarray(out).astype(np.float32) / 255.0
    _TEXT[key] = arr
    return arr


def put(x, layer, cy, a=1.0, dx=0, scale=1.0):
    """Legt ein Textbild mit Mittelpunkt bei cy (Pixel) auf das Bild, a = Deckkraft."""
    if a <= 0.001:
        return x
    if scale != 1.0:
        im = Image.fromarray((layer * 255).astype(np.uint8)).resize((int(layer.shape[1] * scale), int(layer.shape[0] * scale)), Image.BICUBIC)
        layer = np.asarray(im).astype(np.float32) / 255.0
    h, w = layer.shape[:2]
    y0 = int(cy - h / 2)
    x0 = int((W - w) / 2 + dx)
    ys, ye = max(y0, 0), min(y0 + h, H)
    xs, xe = max(x0, 0), min(x0 + w, W)
    if ys >= ye or xs >= xe:
        return x
    lay = layer[ys - y0:ye - y0, xs - x0:xe - x0]
    al = lay[..., 3:4] * a
    x[ys:ye, xs:xe] = x[ys:ye, xs:xe] * (1 - al) + lay[..., :3] * al
    return x


class Still:
    """Standbild mit Kamerafahrt (Ken Burns), gleiche Schnittstelle wie Shot."""
    trace = None
    clip = "still"

    def __init__(self, path, dur, zoom=(1.0, 1.15), center=(960, 540), grade=(1.0, 1.05, (1, 1, 1)), bloom=0.4, ca=0.5, dim=1.0):
        self.im = Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)
        self.dur, self.zoom, self.center, self.grade, self.bloom, self.ca, self.dim = dur, zoom, center, grade, bloom, ca, dim

    def src_time(self, u):
        return u

    def render(self, u):
        z = keyframes(self.zoom, u) if isinstance(self.zoom, list) else self.zoom[0] + (self.zoom[1] - self.zoom[0]) * u / max(self.dur, 1e-6)
        cw, ch = W / z, H / z
        cx = min(max(self.center[0], cw / 2), W - cw / 2)
        cy = min(max(self.center[1], ch / 2), H - ch / 2)
        out = self.im.resize((W, H), Image.BICUBIC, box=(cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2))
        a = np.asarray(out)
        return (a * self.dim).astype(np.uint8) if self.dim != 1.0 else a

    def close(self):
        pass


_LOGO = {}


def logo_layer(width):
    if width not in _LOGO:
        im = Image.open("assets/art/logo.png").convert("RGBA")
        h = int(im.height * width / im.width)
        im = im.resize((width, h), Image.LANCZOS)
        pad = 80
        canvas = Image.new("RGBA", (W, h + pad * 2), (0, 0, 0, 0))
        canvas.paste(im, ((W - width) // 2, pad), im)
        mask = canvas.split()[3].filter(ImageFilter.GaussianBlur(26))
        gl = Image.new("RGBA", canvas.size, (70, 150, 255, 0))
        gl.putalpha(mask.point(lambda p: int(p * 0.8)))
        out = Image.alpha_composite(gl, canvas)
        _LOGO[width] = np.asarray(out).astype(np.float32) / 255.0
    return _LOGO[width]
