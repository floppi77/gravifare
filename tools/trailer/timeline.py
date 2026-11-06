"""Zeitleiste des Trailers (Schnitt, Titel, Effekte, Tonereignisse). Alle Zeiten in Sekunden, Raster: 132 BPM (Schlag 0,4545 s, Takt 1,818 s)."""
import os
import numpy as np
import engine
from engine import Shot, W, H, FPS, ease

BPM = 132.0
BEAT = 60.0 / BPM
BAR = BEAT * 4

TXT = {
    "de": {
        "gravity": "SCHWERKRAFT\nKENNT KEINE GNADE.",
        "taxi7": "Du bist Taxi 7.",
        "levels": "99 LEVEL",
        "handmade": "HANDGEMACHT.",
        "sectors": "9 SEKTOREN",
        "hazards": "TORE · HITZE · VERKEHR",
        "dark": "UND FINSTERNIS.",
        "teach": "FLUGLEHRER",
        "gate": "Das Tor ist offen. Flieg hindurch!",
        "land": "LANDEN.",
        "fuel": "TANKEN.",
        "survive": "ÜBERLEBEN.",
        "every": "JEDE LANDUNG ZÄHLT.",
        "tag": "Eine schwerelose Fahrt",
        "out": "Jetzt auf GitHub",
        "plat": "Windows · Linux · macOS",
        "built": "Gebaut mit Godot  ·  Built with Fish Audio",
        "good": "Viel Erfolg da draußen, Taxi 7.",
        "free": "Kostenlos für nicht-kommerzielle Nutzung",
    },
    "en": {
        "gravity": "GRAVITY\nSHOWS NO MERCY.",
        "taxi7": "You are Taxi 7.",
        "levels": "99 LEVELS",
        "handmade": "HANDMADE.",
        "sectors": "9 SECTORS",
        "hazards": "GATES · HEAT · TRAFFIC",
        "dark": "AND DARKNESS.",
        "teach": "FLIGHT INSTRUCTOR",
        "gate": "The gate is open. Fly through it!",
        "land": "LAND.",
        "fuel": "REFUEL.",
        "survive": "SURVIVE.",
        "every": "EVERY LANDING COUNTS.",
        "tag": "A weightless ride",
        "out": "Now on GitHub",
        "plat": "Windows · Linux · macOS",
        "built": "Made with Godot  ·  Built with Fish Audio",
        "good": "Good luck out there, Taxi 7.",
        "free": "Free for non-commercial use",
    },
}

_traces = {}


def events(clip):
    """(Landungen, Starts) in Sekunden aus der Taxi-Spur."""
    if clip not in _traces:
        rows = [l.split() for l in open(f"{engine.CLIPS}/{clip}.trace")]
        st = [int(r[3]) for r in rows]
        land = [i / FPS for i in range(1, len(st)) if st[i] == 1 and st[i - 1] == 0]
        off = [i / FPS for i in range(1, len(st)) if st[i] == 0 and st[i - 1] == 1]
        _traces[clip] = (land, off)
    return _traces[clip]


class Timeline:
    def __init__(self, lang):
        self.lang = lang
        self.T = TXT[lang]
        self.shots = []          # (t0, Shot)
        self.texts = []          # dict
        self.flashes = []        # (t, amp, decay, colour)
        self.pulses = []         # (t, strength) → Farbsaum/Bloom
        self.impacts = []
        self.risers = []
        self.whooshes = []
        self.ticks = []
        self.sfx = []
        self.voices = []
        self.cursor = 0.0
        self.total = 0.0
        self.drop = 0.0
        self.end_music = 0.0
        self.bars_spec = []      # (t0, t1, from_px, to_px)
        self.fades = []          # (t0, t1, from, to) Helligkeit
        self.custom = []

    # ---- Schnitt ----
    def add(self, shot, dur=None, t0=None, sfx_land=True):
        t0 = self.cursor if t0 is None else t0
        if dur is not None:
            shot.dur = dur
        self.shots.append((t0, shot))
        self.cursor = t0 + shot.dur
        if sfx_land:
            self._auto_sfx(t0, shot)
        return shot

    def _auto_sfx(self, t0, shot):
        land, off = events(shot.trace or shot.clip)
        end = shot.src_time(shot.dur)
        for lt in land:
            if shot.src <= lt <= end:
                # Ausgabezeit zur Quellzeit suchen
                u = self._inv(shot, lt)
                self.sfx.append((t0 + u, "land", 0.9))
        for ot in off:
            if shot.src <= ot <= end and ot - shot.src > 0.2:
                u = self._inv(shot, ot)
                self.sfx.append((t0 + u, "gear", 0.5))

    @staticmethod
    def _inv(shot, ts):
        lo, hi = 0.0, shot.dur
        for _ in range(30):
            mid = (lo + hi) / 2
            if shot.src_time(mid) < ts:
                lo = mid
            else:
                hi = mid
        return (lo + hi) / 2

    def pre(self, clip):
        """Aufnahmen ohne Bedienfeld gibt es je Sprache (en_n_…, en_trans); die mit Bedienfeld heißen h_… und h_en_…."""
        return "en_" + clip if self.lang == "en" and (clip.startswith("n_") or clip == "trans") else clip

    def landing(self, clip, n, dur, frac=0.7, speed=1.0, zoom=2.0, **kw):
        """Ausschnitt, in dem die n-te Landung bei Anteil `frac` der Dauer passiert."""
        clip = self.pre(clip)
        land, _ = events(clip)
        lt = land[min(n, len(land) - 1)]       # die Aufnahmen je Sprache können sich um eine Landung unterscheiden
        src = max(lt - dur * speed * frac, 0.0)
        return Shot(clip, src, dur, speed=speed, zoom=zoom, **kw)

    def text(self, key, t0, t1, size=150, cy=540, kind="slam", style=None, **kw):
        self.texts.append(dict(key=key, t0=t0, t1=t1, size=size, cy=cy, kind=kind, style=style or {}, **kw))

    # ---- Abfragen ----
    def shots_at(self, t):
        out = []
        for t0, s in self.shots:
            if t0 <= t < t0 + s.dur:
                out.append({"shot": s, "t0": t0, "mix": lambda tt: 1.0})
        return out

    def fx(self, t):
        f = {}
        fl = 0.0
        col = (1, 1, 1)
        for (t0, amp, dec, c) in self.flashes:
            if t >= t0:
                v = amp * np.exp(-(t - t0) / dec)
                if v > fl:
                    fl, col = v, c
        f["flash"] = fl
        f["flash_col"] = col
        p = 0.0
        for (t0, s) in self.pulses:
            if t >= t0:
                p = max(p, s * np.exp(-(t - t0) / 0.14))
        f["ca"] = 0.7 + 9.0 * p
        f["bloom"] = 0.38 + 0.5 * p
        f["vig"] = 0.55 + 0.35 * (1 - ease((t - 1.0) / 3.0)) * (1 if t < self.drop else 0)
        return f

    def post(self, x, t, lang):
        a = 1.0
        for (t0, t1, v0, v1) in sorted(self.fades):
            if t >= t0:
                a = v0 + (v1 - v0) * ease((t - t0) / max(t1 - t0, 1e-6))
        return x * a

    def bars(self, x, t):
        h = 0.0
        for (t0, t1, a, b) in self.bars_spec:
            if t >= t0:
                h = a + (b - a) * ease((t - t0) / max(t1 - t0, 1e-6))
        n = int(round(h))
        if n > 0:
            x[:n] = 0
            x[H - n:] = 0
        return x

    def titles(self, x, t, lang):
        for d in self.texts:
            if not (d["t0"] <= t <= d["t1"]):
                continue
            u = t - d["t0"]
            dur = d["t1"] - d["t0"]
            txt = self.T[d["key"]] if d["key"] in self.T else d["key"]
            st = dict(d["style"])
            font = st.pop("font", engine.FONT_T)
            layer = engine.text_layer(txt, d["size"], font=font, **st)
            a = min(u / 0.12, 1.0) * min((dur - u) / 0.22, 1.0)
            sc = 1.0
            dx = 0
            if d["kind"] == "slam":
                sc = 1.0 + 0.5 * np.exp(-u / 0.07) + 0.03 * u / dur
            elif d["kind"] == "drift":
                sc = 1.0 + 0.04 * u / dur
            elif d["kind"] == "fade":
                a = min(u / 0.6, 1.0) * min((dur - u) / 0.5, 1.0)
            if d["kind"] == "slam" and u < 0.12:
                dx = int(np.sin(u * 200) * 14)
            x = engine.put(x, layer, d["cy"], max(a, 0.0), dx, sc)
        for (kind, t0, t1) in self.custom:
            if kind == "logo" and t0 <= t <= t1:
                u = t - t0
                a = min(u / 0.5, 1.0) * min((t1 - t) / 0.6, 1.0)
                lay = engine.logo_layer(1100)
                x = engine.put(x, lay, 400, a, 0, 1.12 - 0.12 * ease(u / 2.0))
                sweep = (u - 0.6) / 1.2          # Glanzstreifen läuft einmal über das Logo
                if 0.0 <= sweep <= 1.0:
                    xs = int(250 + sweep * 1420)
                    x[:, :] = x  # keine Änderung am Rest
                    ys, ye = 235, 565
                    band = np.zeros((ye - ys, W), np.float32)
                    cols = np.arange(W)
                    band += np.exp(-((cols - xs) / 38.0) ** 2)[None, :] * 0.55
                    mask = np.zeros((ye - ys, W), np.float32)
                    sub = lay[:, :, 3]
                    off = int(400 - lay.shape[0] / 2)
                    for_rows = (np.arange(ye - ys) + ys - off).clip(0, lay.shape[0] - 1)
                    mask = sub[for_rows, :] * (lay[for_rows, :, :3].max(2) > 0.35)
                    x[ys:ye] += (band * mask * a)[..., None] * 0.9
        return x

    def close(self):
        for _, s in self.shots:
            s.close()



def build(lang):
    tl = Timeline(lang)
    D = 8 * BAR
    tl.drop = D
    tl.mutes = []
    tl.end_music = 36.0 * BAR
    L = tl.landing
    H = "h_" if lang == "de" else "h_en_"       # Aufnahmen mit Bedienfeld gibt es je Sprache

    def mont(items, dur, speed=1.6, zoom=2.0, frac=0.7, **kw):
        for clip, n in items:
            tl.add(L(clip, n, dur, frac=frac, speed=speed, zoom=zoom, **kw))

    # ---------- Akt 1: Einleitung (Balken, düster) ----------
    tl.bars_spec += [(0.0, 0.0, 150, 150), (D, D + 0.3, 150, 0)]
    tl.fades.append((0.0, 1.6, 0.0, 1.0))
    tl.add(Shot(tl.pre("trans"), 1.2, 2 * BAR, speed=0.8, zoom=1.5, cam="fix", fix=(640, 420), fix_to=(1280, 420), nearest=False, bloom=0.55, grade=(1.1, 1.1, (0.95, 0.97, 1.05))), sfx_land=False)
    tl.text("gravity", 0.9, 2 * BAR - 0.15, size=165, cy=540, kind="drift")
    first = events(tl.pre("n_s1_01"))[0][0]
    tl.add(Shot(tl.pre("n_s1_01"), first - 2 * BAR * 0.8 * 0.8, 2 * BAR, speed=0.8, zoom=[(0, 2.4), (2 * BAR, 3.0)], at=(0.5, 0.62), grade=(1.1, 1.1, (0.97, 0.98, 1.04))))
    tl.text("taxi7", 2 * BAR + 0.25, 4 * BAR - 0.2, size=120, cy=880, kind="fade", style=dict(fill=(240, 244, 255), glow=(90, 160, 255)))
    # Montage mit steigendem Tempo
    mont([("n_s3_04", 0)], BAR, speed=1.5)
    mont([("n_s5_04", 1)], BAR, speed=1.5)
    mont([("n_s6_05", 1), ("n_s7_03", 0)], BAR / 2, speed=1.6)
    mont([("n_s8_03", 1), ("n_s9_10", 1), ("n_s4_05", 1)], BEAT, speed=1.6, frac=0.6)
    tl.risers.append((4 * BAR, D - BEAT - 4 * BAR))
    tl.mutes.append((D - BEAT, D))
    tl.whooshes += [4 * BAR, 6 * BAR, D - BEAT]
    # ---------- Akt 2: Drop ----------
    def hit(t, flash=0.8, amp=1.0, impact=True):
        tl.flashes.append((t, flash, 0.10, (1, 1, 1)))
        tl.pulses.append((t, amp))
        if impact:
            tl.impacts.append(t)
    tl.cursor = D
    hit(D, 0.95)
    mont([("n_s1_01", 1)], BAR)
    tl.text("levels", D, D + BAR, size=190, kind="slam")
    mont([("n_s2_04", 1)], BAR)
    tl.text("handmade", 9 * BAR, 10 * BAR, size=190, kind="slam", style=dict(fill=(255, 224, 140), glow=(255, 160, 40))); hit(9 * BAR, 0.5, 0.8, False)
    mont([("n_s3_04", 1)], BAR)
    tl.text("sectors", 10 * BAR, 11 * BAR, size=190, kind="slam"); hit(10 * BAR, 0.5, 0.8, False)
    mont([("n_s4_05", 0)], BAR)
    mont([("n_s5_04", 0)], BAR)
    tl.text("hazards", 12 * BAR, 13 * BAR, size=140, kind="slam"); hit(12 * BAR, 0.5, 0.8, False)
    mont([("n_s6_05", 0)], BAR)
    mont([("n_s7_05", 1), ("n_s7_03", 1)], BAR / 2)
    mont([("n_s8_03", 0)], BAR, zoom=2.0)
    tl.text("dark", 15 * BAR, 16 * BAR, size=150, kind="slam", style=dict(fill=(190, 225, 255), glow=(60, 130, 255))); hit(15 * BAR, 0.5, 0.8, False)
    # Zwischenspiel: Fluglehrer (HUD-Aufnahme, ruhiger)
    B1 = 16 * BAR
    hit(B1, 0.6, 0.6)
    tl.add(L(H + "s1_01", 1, 2 * BAR, frac=0.8, speed=1.0, zoom=[(0, 1.0), (2 * BAR, 1.35)], at=(0.5, 0.55), grade=(1.12, 1.08, (1.0, 1.0, 1.02))))
    voice_gate = ("i0_tut_gate", 0.95)
    tl.voices.append((B1 + 0.25, voice_gate[0], voice_gate[1]))
    tl.text("teach", B1 + 0.2, B1 + 2.9, size=44, cy=858, kind="fade", style=dict(font=engine.FONT_B, fill=(255, 207, 51), glow=(255, 150, 30), spacing=6))
    tl.text("gate", B1 + 0.25, B1 + 2.9, size=58, cy=925, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255)))
    # zweite Hälfte
    mont([(H + "s3_04", 0)], BAR, zoom=[(0, 1.0), (BAR, 1.3)])
    mont([(H + "s5_04", 1)], BAR, zoom=[(0, 1.0), (BAR, 1.3)])
    tl.add(Shot(tl.pre("trans"), 6.0, BAR, speed=1.0, zoom=[(0, 1.0), (BAR, 1.25)], cam="fix", fix=(1200, 500), bloom=0.55), sfx_land=False)
    tl.text("land", 20 * BAR, 21 * BAR, size=170, kind="slam"); hit(20 * BAR, 0.5, 0.8, False)
    mont([("n_s9_05", 0)], BAR)
    tl.text("fuel", 21 * BAR, 22 * BAR, size=170, kind="slam"); hit(21 * BAR, 0.5, 0.8, False)
    mont([("n_s9_10", 0)], BAR)
    tl.text("survive", 22 * BAR, 23 * BAR, size=170, kind="slam", style=dict(fill=(255, 120, 90), glow=(255, 60, 30))); hit(22 * BAR, 0.5, 0.8, False)
    mont([("n_s6_05", 2)], BAR)
    # ---------- Akt 3: Steigerung ----------
    tl.cursor = 24 * BAR
    hit(24 * BAR, 0.8, 1.0)
    tl.text("every", 24 * BAR, 25.9 * BAR, size=120, kind="slam", style=dict(fill=(255, 255, 255), glow=(255, 190, 60)))
    mont([("n_s7_03", 2), ("n_s8_03", 2), ("n_s9_05", 1), ("n_s5_04", 2)], BAR / 2, speed=1.7, zoom=2.5)
    mont([("n_s3_04", 2), ("n_s2_04", 2), ("n_s4_05", 3), ("n_s6_05", 2)], BAR / 2, speed=1.7, zoom=3.0)
    mont([("n_s7_05", 0), ("n_s8_03", 3), ("n_s9_10", 2), ("n_s5_04", 3), ("n_s1_01", 2), ("n_s2_04", 0), ("n_s3_04", 0), ("n_s4_05", 2)], BEAT, speed=1.8, zoom=3.0, frac=0.6)
    for i in range(8):
        tl.pulses.append((28 * BAR + i * BEAT, 0.6))
    # Finale: Zeitlupe, perfekte Landung
    F = 30 * BAR
    land_n = 1
    clip = tl.pre("n_s1_01")
    lt = events(clip)[0][land_n]
    fin = Shot(clip, lt - 1.5, 2 * BAR, speed=[(0, 1.0), (0.8, 1.0), (1.4, 0.25), (2 * BAR, 0.25)], zoom=[(0, 2.0), (1.6, 3.4), (2 * BAR, 4.0)], at=(0.5, 0.6), sigma=0.3, bloom=0.6)
    t_fin = tl.cursor
    tl.add(fin)
    touch = t_fin + tl._inv(fin, lt)
    tl.risers.append((touch - 1.9, 1.9))
    tl.flashes.append((touch, 0.55, 0.16, (1.0, 0.95, 0.8)))
    tl.pulses.append((touch, 0.9))
    tl.sfx.append((touch, "perfect", 0.9))
    tl.voices.append((touch + 0.15, "f0_soft", 0.95))
    # ---------- Schluss: Logo ----------
    E = tl.cursor              # = 32 Takte
    tl.drop_end = E
    tl.fades.append((E - 0.05, E, 1.0, 0.0))
    tl.impacts.append(E + 0.35)
    tl.flashes.append((E + 0.35, 0.7, 0.14, (0.7, 0.85, 1.0)))
    tl.pulses.append((E + 0.35, 1.0))
    end = E + 11.0
    still = engine.Still("assets/art/bg_s1.png", end - E, zoom=(1.0, 1.15), center=(960, 540), dim=0.6, grade=(1.05, 1.08, (0.95, 0.98, 1.06)))
    tl.add(still, t0=E, sfx_land=False)
    tl.fades.append((E + 0.2, E + 0.7, 0.0, 1.0))
    tl.custom.append(("logo", E + 0.35, end - 1.6))
    tl.text("tag", E + 1.6, end - 1.6, size=84, cy=700, kind="fade", style=dict(font=engine.FONT_T, fill=(235, 240, 255), glow=(90, 150, 255), spacing=5))
    tl.text("out", E + 5.2, end - 1.3, size=60, cy=826, kind="fade", style=dict(font=engine.FONT_B, fill=(255, 207, 51), glow=(255, 150, 30), spacing=4))
    tl.text("github.com/floppi77/gravifare", E + 5.2, end - 1.3, size=64, cy=900, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255)))
    tl.text("plat", E + 5.6, end - 1.3, size=40, cy=968, kind="fade", style=dict(font=engine.FONT_B, fill=(190, 205, 235), glow=(60, 90, 160), spacing=3))
    tl.text("built", E + 7.2, end - 1.3, size=34, cy=1030, kind="fade", style=dict(font=engine.FONT_B, fill=(150, 165, 200), glow=(40, 60, 110), spacing=2))
    tl.fades.append((end - 1.4, end, 1.0, 0.0))
    good = {"de": ("i0_tut_done", 2.99), "en": ("i0_tut_done", 2.42)}[lang]
    tl.voices.append((E + 2.4, "tut_done_tail", 0.95))
    tl.tail_from = good[1]
    tl.total = end
    tl.end_music = end - 1.2
    return tl
