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
        "gates": "TORE.",
        "heat": "HITZE.",
        "magnets": "MAGNETE.",
        "traffic": "VERKEHR.",
        "dark": "UND FINSTERNIS.",
        "teach": "FLUGLEHRER",
        "gate": "Das Tor ist offen. Flieg hindurch!",
        "land": "LANDEN.",
        "fuel": "TANKEN.",
        "survive": "ÜBERLEBEN.",
        "journey": "VON SEKTOR\nZU SEKTOR.",
        "every": "JEDE LANDUNG ZÄHLT.",
        "tag": "Eine schwerelose Fahrt",
        "out": "Jetzt auf itch.io",
        "url": "floppi77.itch.io/gravifare",
        "plat": "Windows · Linux · macOS  ·  Controller & Tastatur",
        "langs": "Deutsch · English · Français · Español · Italiano · Português · Polski",
        "built": "Gebaut mit Godot  ·  Built with Fish Audio",
        "upgrade": "AUFRÜSTEN.",
        "workshop": "WERKSTATT  ·  DÜSEN · HÜLLE · FAHRWERK · SCHEINWERFER",
        "build": "BAU DEINE\nEIGENEN LEVEL.",
        "editor": "LEVEL-EDITOR  ·  TESTFLUG  ·  TEILEN",
    },
    "en": {
        "gravity": "GRAVITY\nSHOWS NO MERCY.",
        "taxi7": "You are Taxi 7.",
        "levels": "99 LEVELS",
        "handmade": "HANDMADE.",
        "sectors": "9 SECTORS",
        "gates": "GATES.",
        "heat": "HEAT.",
        "magnets": "MAGNETS.",
        "traffic": "TRAFFIC.",
        "dark": "AND DARKNESS.",
        "teach": "FLIGHT INSTRUCTOR",
        "gate": "The gate is open. Fly through it!",
        "land": "LAND.",
        "fuel": "REFUEL.",
        "survive": "SURVIVE.",
        "journey": "SECTOR\nTO SECTOR.",
        "every": "EVERY LANDING COUNTS.",
        "tag": "A weightless ride",
        "out": "Out now on itch.io",
        "url": "floppi77.itch.io/gravifare",
        "plat": "Windows · Linux · macOS  ·  Controller & keyboard",
        "langs": "Deutsch · English · Français · Español · Italiano · Português · Polski",
        "built": "Made with Godot  ·  Built with Fish Audio",
        "upgrade": "UPGRADE.",
        "workshop": "WORKSHOP  ·  JETS · HULL · GEAR · HEADLIGHT",
        "build": "BUILD YOUR\nOWN LEVELS.",
        "editor": "LEVEL EDITOR  ·  TEST FLIGHT  ·  SHARE",
    },
}

# Sektornamen wie im Spiel (für die Sektor-Parade)
import json as _json
_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
for _lg in TXT:
    _d = _json.load(open(f"{_ROOT}/data/i18n/{_lg}.json", encoding="utf-8"))
    for _i in range(1, 10):
        TXT[_lg][f"sec{_i}"] = _d[f"SECTOR_{_i}"].upper()

_traces = {}



def events(clip):
    """(Landungen, Starts) in Sekunden aus der Taxi-Spur."""
    if clip not in _traces:
        rows = [l.split() for l in open(f"{engine.CLIPS}/{clip}.trace")]
        fps = engine.clip_info(clip)[2]                  # Zeitlupen-Aufnahmen: 240 Zeilen je Spielsekunde
        st = [int(r[3]) for r in rows]
        land = [i / fps for i in range(1, len(st)) if st[i] == 1 and st[i - 1] == 0]
        off = [i / fps for i in range(1, len(st)) if st[i] == 0 and st[i - 1] == 1]
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
        return "en_" + clip if self.lang == "en" and (clip.startswith(("n_", "f_", "trans", "slow_")) or clip in ("ws", "ed")) else clip

    def landing(self, clip, n, dur, frac=0.7, speed=1.0, zoom=2.0, **kw):
        assert speed == int(speed), "nur ganze Tempi (1×, 2×): Zwischenwerte bräuchten Überblendung und ruckeln"
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
        f["ca"] = 0.3 + 9.0 * p          # Ruhe: kein Farbsaum (rundet auf 0 px), nur bei Schlägen
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



# Quellzeiten (Sekunden) in den Aufnahmen von clips_v4, an Kontaktbögen der Rohaufnahmen ausgesucht (sheet.py):
# jeweils ein Moment, in dem genau das im Bild ist, was der Text darüber sagt.
SPOT = {
    "gates": ("n_s2_04", 16.8),     # Taxi an den Wandertoren
    "heat": ("n_s5_01", 11.3),      # Taxi neben der Hitzezone
    "magnets": ("n_s4_05", 15.2),   # Taxi im Feld eines Magneten
    "traffic": ("n_s7_05", 3.3),   # Taxi zwischen Fremdfahrzeugen
    "dark": ("n_s9_10", 16.0),      # dunkles Level
    "beam": ("n_s5_04", 21.4),      # Plasmastrahl
    "neon": ("n_s2_11", 10.0),      # Leuchtreklame
    "gate_open": ("h_s1_01", 25.82), # Ausgangstor öffnet sich (mit Bedienfeld)
    "trans2": 2.7, "trans5": 2.9, "trans9": 2.9,  # Zwischenflug: das Taxi kreuzt das Bild von x≈560 (2,6 s) bis x≈1880 (5,4 s) auf Höhe y≈420
}
# Werkstatt-Aufnahme (ws_trailer.tscn, 60 fps): Tafel öffnet bei Frame 134, Käufe bei Frame 244 und 354 (im Protokoll SHOP/BUY nachgeprüft)
WS_SHOP = 134 / 60.0
WS_BUYS = (244 / 60.0, 354 / 60.0)
# Editor-Aufnahme (ed_trailer.tscn): Frames, in denen ein Strich bzw. ein Objekt beginnt
ED_STROKES = (31, 53, 75, 91, 103, 113, 123, 157, 179, 201, 223)


def build(lang):
    tl = Timeline(lang)
    D = 4 * BAR                                   # Drop nach vier Takten: das Taxi ist ab dem ersten Bild zu sehen
    tl.drop = D
    tl.mutes = []
    L = tl.landing
    H = "h_" if lang == "de" else "h_en_"

    def mont(items, dur, speed=2.0, zoom=2.0, frac=0.7, **kw):
        for clip, n in items:
            tl.add(L(clip, n, dur, frac=frac, speed=speed, zoom=zoom, **kw))

    def spot(key, dur, zoom=((0, 1.8), None), at=(0.5, 0.7), speed=1.0, **kw):
        clip, t = SPOT[key]
        z0 = zoom[0][1]
        zk = [(0, z0), (dur, min(z0 * 1.12, 2.0))]       # bis 2 = 1:1 aus der 4K-Aufnahme, nie vergrößert
        return tl.add(Shot(tl.pre(clip) if not clip.startswith("h_") else (H + clip[2:]), t, dur, speed=speed, zoom=zk, at=at, **kw))

    def hit(t, flash=0.8, amp=1.0, impact=True):
        tl.flashes.append((t, flash, 0.10, (1, 1, 1)))
        tl.pulses.append((t, amp))
        if impact:
            tl.impacts.append(t)

    def slam(key, t, size=190, **st):
        tl.text(key, t, t + BAR, size=size, kind="slam", style=st)
        hit(t, 0.5, 0.8, False)

    # ---------- Kaltstart (Balken): Zwischenflug, dann das Taxi groß ----------
    tl.bars_spec += [(0.0, 0.0, 130, 130), (D, D + 0.3, 130, 0)]
    tl.fades.append((0.0, 0.5, 0.0, 1.0))
    tl.add(Shot(tl.pre("trans2"), SPOT["trans2"], BAR * 1.5, speed=1.0, zoom=[(0, 1.6), (BAR * 1.5, 1.9)], cam="fix", fix=(720, 430), fix_to=(1560, 430), nearest=False, bloom=0.55,
                grade=(1.12, 1.08, (1.0, 0.97, 1.05))), sfx_land=False)
    tl.text("gravity", 0.35, BAR * 1.5 - 0.1, size=150, cy=540, kind="drift")
    first = events(tl.pre("n_s1_01"))[1][0]          # erster Start in Level 1: Nahaufnahme des Taxis (ganzzahliger Zoom, scharf)
    tl.add(Shot(tl.pre("n_s1_01"), max(first - 1.0, 0.0), BAR * 1.5, speed=1.0, zoom=3.0, at=(0.5, 0.56), grade=(1.1, 1.08, (1.0, 0.98, 1.03))), sfx_land=False)
    tl.text("taxi7", BAR * 1.5 + 0.15, 3 * BAR - 0.1, size=110, cy=900, kind="fade", style=dict(fill=(240, 244, 255), glow=(90, 160, 255)))
    mont([("n_s3_04", 0), ("n_s6_05", 1)], BAR / 4 * 1.0, speed=2.0, zoom=2.0)
    tl.cursor = 3.5 * BAR
    mont([("n_s8_03", 1), ("n_s9_05", 1)], BAR / 4, speed=2.0, zoom=2.0)
    tl.risers.append((1.5 * BAR, D - BEAT - 1.5 * BAR))
    tl.mutes.append((D - BEAT, D))
    tl.whooshes += [1.5 * BAR, 3 * BAR, D - BEAT]

    # ---------- Drop ----------
    tl.cursor = D
    hit(D, 0.95)
    mont([("n_s1_01", 2)], BAR)
    tl.text("levels", D, D + BAR, size=190, kind="slam")
    mont([("n_s2_04", 1)], BAR)
    slam("handmade", D + BAR, fill=(255, 224, 140), glow=(255, 160, 40))
    # Sektor-Parade: jede Welt ein Drittel Takt, Name klein darunter
    P0 = D + 2 * BAR
    slam("sectors", P0, size=170)
    parade = [("n_s1_01", 0), ("n_s2_11", 1), ("n_s3_04", 2), ("n_s4_05", 2), ("n_s5_04", 1), ("n_s6_05", 2), ("n_s7_05", 1), ("n_s8_03", 2), ("n_s9_10", 1)]
    for k, (clip, n) in enumerate(parade):
        t0 = P0 + k * BAR / 3
        tl.cursor = t0
        tl.add(L(clip, n, BAR / 3, frac=0.55, speed=1.0, zoom=2.0))
        tl.text(f"sec{k + 1}", t0 + 0.02, t0 + BAR / 3 - 0.02, size=54, cy=985, kind="drift", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255), spacing=5))
        tl.pulses.append((t0, 0.35))
    # Gefahren: Text über einem Bild, auf dem genau das zu sehen ist
    G0 = P0 + 3 * BAR
    tl.cursor = G0
    spot("gates", BAR); slam("gates", G0)
    spot("heat", BAR, at=(0.36, 0.42)); slam("heat", G0 + BAR, fill=(255, 190, 110), glow=(255, 90, 30))
    spot("magnets", BAR); slam("magnets", G0 + 2 * BAR, fill=(255, 140, 220), glow=(200, 60, 255))
    spot("traffic", BAR); slam("traffic", G0 + 3 * BAR, fill=(180, 235, 255), glow=(60, 150, 255))
    spot("dark", BAR); slam("dark", G0 + 4 * BAR, size=150, fill=(190, 225, 255), glow=(60, 130, 255))
    # Zwischenspiel: Fluglehrer (mit Bedienfeld, ruhiger)
    B1 = G0 + 5 * BAR
    tl.cursor = B1
    hit(B1, 0.6, 0.6)
    gclip, gt = SPOT["gate_open"]
    tl.add(Shot(H + gclip[2:], gt, 2 * BAR, zoom=[(0, 1.0), (2 * BAR, 1.3)], cam="fix", fix=(960, 400), fix_to=(960, 330), grade=(1.12, 1.08, (1.0, 1.0, 1.02))), sfx_land=False)
    tl.voices.append((B1 + 0.25, "i0_tut_gate", 0.95))
    tl.text("teach", B1 + 0.2, B1 + 2.9, size=44, cy=858, kind="fade", style=dict(font=engine.FONT_B, fill=(255, 207, 51), glow=(255, 150, 30), spacing=6))
    tl.text("gate", B1 + 0.25, B1 + 2.9, size=58, cy=925, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255)))
    # Landen, Tanken, Überleben
    C0 = B1 + 2 * BAR
    tl.cursor = C0
    tl.add(L(H + "s3_04", 1, BAR, frac=0.75, speed=1.0, zoom=[(0, 1.5), (BAR, 2.0)], at=(0.5, 0.74)))
    slam("land", C0, size=170)
    tl.add(L("f_s9_05", 0, BAR, frac=0.45, speed=1.0, zoom=[(0, 1.8), (BAR, 2.0)], at=(0.5, 0.74)))
    slam("fuel", C0 + BAR, size=170)
    spot("beam", BAR, zoom=((0, 1.8), None), at=(0.45, 0.28))       # Strahl feuert unter dem Taxi (20,6–23,2 s)
    slam("survive", C0 + 2 * BAR, size=170, fill=(255, 120, 90), glow=(255, 60, 30))
    # Von Sektor zu Sektor: zwei Zwischenflüge (Blender-Hintergründe der Zielsektoren)
    J0 = C0 + 3 * BAR
    tl.cursor = J0
    hit(J0, 0.6, 0.7)
    for k, key in enumerate(("trans5", "trans9")):
        tl.add(Shot(tl.pre(key), SPOT[key], BAR, speed=1.0, zoom=[(0, 1.8), (BAR, 1.95)], cam="fix", fix=(840, 400), fix_to=(1480, 400), nearest=False, bloom=0.55), sfx_land=False)
        tl.pulses.append((J0 + k * BAR, 0.5))
    tl.text("journey", J0 + 0.05, J0 + 2 * BAR - 0.15, size=150, kind="drift", style=dict(fill=(235, 240, 255), glow=(120, 90, 255)))
    tl.whooshes += [J0 + 0.2, J0 + BAR + 0.2]
    # ---------- Werkstatt und Level-Editor (je zwei Takte) ----------
    W0 = J0 + 2 * BAR
    tl.cursor = W0
    hit(W0, 0.6, 0.7)
    ws = tl.pre("ws")
    ws_speed = 2.0
    ws_src = WS_SHOP - 0.6
    tl.add(Shot(ws, ws_src, 2 * BAR, speed=ws_speed, zoom=[(0, 1.12), (2 * BAR, 1.0)], cam="fix", fix=(960, 560), nearest=False, bloom=0.4,
                grade=(1.08, 1.05, (1.0, 1.0, 1.0))), sfx_land=False)
    for b in WS_BUYS:
        u = (b - ws_src) / ws_speed
        if 0.0 <= u <= 2 * BAR:
            tl.sfx.append((W0 + u, "coin", 0.8))
            tl.pulses.append((W0 + u, 0.35))
    tl.text("upgrade", W0, W0 + BAR, size=170, cy=210, kind="slam", style=dict(fill=(255, 214, 120), glow=(255, 140, 40)))
    tl.text("workshop", W0 + 0.5, W0 + 2 * BAR - 0.1, size=40, cy=1000, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(255, 150, 30), spacing=4))
    E0 = W0 + 2 * BAR
    tl.cursor = E0
    hit(E0, 0.5, 0.7)
    ed = tl.pre("ed")
    ed_speed, ed_src = 1.0, 0.35
    tl.add(Shot(ed, ed_src, 2 * BAR, speed=ed_speed, zoom=[(0, 1.2), (2 * BAR, 1.27)], cam="fix", fix=(800, 455), nearest=False, bloom=0.35,
                grade=(1.06, 1.05, (1.0, 1.0, 1.02))), sfx_land=False)
    for f in ED_STROKES:
        u = (f / 60.0 - ed_src) / ed_speed
        if 0.0 <= u <= 2 * BAR:
            tl.ticks.append(E0 + u)
    tl.text("build", E0, E0 + 1.2 * BAR, size=140, kind="slam", style=dict(fill=(150, 240, 255), glow=(40, 150, 255)))
    tl.text("editor", E0 + 0.5, E0 + 2 * BAR - 0.1, size=46, cy=1000, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255), spacing=4))
    # ---------- Steigerung ----------
    S0 = E0 + 2 * BAR
    tl.cursor = S0
    hit(S0, 0.8, 1.0)
    tl.text("every", S0, S0 + 1.9 * BAR, size=120, kind="slam", style=dict(fill=(255, 255, 255), glow=(255, 190, 60)))
    mont([("n_s7_04", 1), ("n_s8_03", 3), ("n_s9_05", 2), ("n_s5_04", 2)], BAR / 2, speed=2.0, zoom=2.0)
    mont([("n_s3_04", 3), ("n_s2_11", 2), ("n_s4_05", 3), ("n_s6_05", 3)], BAR / 2, speed=2.0, zoom=2.0)
    mont([("n_s7_05", 2), ("n_s8_03", 4), ("n_s9_10", 2), ("n_s5_01", 1), ("n_s1_01", 2), ("n_s2_04", 2), ("n_s3_04", 4), ("n_s4_05", 0)], BEAT, speed=2.0, zoom=2.0, frac=0.6)
    for i in range(8):
        tl.pulses.append((S0 + 4 * BAR + i * BEAT, 0.6))
    # Finale: Zeitlupe, perfekte Landung
    clip = tl.pre("slow_n_s1_01")                    # 240 Bilder je Spielsekunde: die Zeitlupe besteht aus echten Einzelbildern
    lt = events(clip)[0][1]
    fin = Shot(clip, lt - 1.5, 2 * BAR, speed=[(0, 1.0), (0.8, 1.0), (1.4, 0.25), (2 * BAR, 0.25)], zoom=[(0, 2.0), (1.6, 2.6), (2 * BAR, 3.0)], at=(0.5, 0.6), sigma=0.3, bloom=0.6)
    t_fin = tl.cursor
    tl.add(fin)
    touch = t_fin + tl._inv(fin, lt)
    tl.risers.append((touch - 1.9, 1.9))
    tl.flashes.append((touch, 0.55, 0.16, (1.0, 0.95, 0.8)))
    tl.pulses.append((touch, 0.9))
    tl.sfx.append((touch, "land_perfect", 0.9))
    tl.voices.append((touch + 0.15, "f0_soft", 0.95))
    # ---------- Schluss: Logo über dem Menübild (Planet und Stadt) ----------
    E = tl.cursor
    tl.drop_end = E
    tl.fades.append((E - 0.05, E, 1.0, 0.0))
    tl.impacts.append(E + 0.35)
    tl.flashes.append((E + 0.35, 0.7, 0.14, (0.7, 0.85, 1.0)))
    tl.pulses.append((E + 0.35, 1.0))
    end = E + 11.5
    still = engine.Still("assets/art/bg_s1.png", end - E, zoom=(1.0, 1.12), center=(960, 540), dim=0.55, grade=(1.05, 1.08, (0.95, 0.98, 1.06)))
    tl.add(still, t0=E, sfx_land=False)
    tl.fades.append((E + 0.2, E + 0.7, 0.0, 1.0))
    tl.custom.append(("logo", E + 0.35, end - 1.6))
    tl.text("tag", E + 1.6, end - 1.6, size=84, cy=690, kind="fade", style=dict(font=engine.FONT_T, fill=(235, 240, 255), glow=(90, 150, 255), spacing=5))
    tl.text("out", E + 4.6, end - 1.3, size=60, cy=800, kind="fade", style=dict(font=engine.FONT_B, fill=(255, 207, 51), glow=(255, 150, 30), spacing=4))
    tl.text("url", E + 4.6, end - 1.3, size=64, cy=872, kind="fade", style=dict(font=engine.FONT_B, fill=(245, 248, 255), glow=(70, 120, 255)))
    tl.text("plat", E + 5.2, end - 1.3, size=36, cy=940, kind="fade", style=dict(font=engine.FONT_B, fill=(190, 205, 235), glow=(60, 90, 160), spacing=3))
    tl.text("langs", E + 5.6, end - 1.3, size=32, cy=990, kind="fade", style=dict(font=engine.FONT_B, fill=(190, 205, 235), glow=(60, 90, 160), spacing=2))
    tl.text("built", E + 7.0, end - 1.3, size=30, cy=1040, kind="fade", style=dict(font=engine.FONT_B, fill=(150, 165, 200), glow=(40, 60, 110), spacing=2))
    tl.fades.append((end - 1.4, end, 1.0, 0.0))
    good = {"de": ("i0_tut_done", 2.99), "en": ("i0_tut_done", 2.42)}[lang]
    tl.voices.append((E + 2.4, "tut_done_tail", 0.95))
    tl.tail_from = good[1]
    tl.total = end
    tl.end_music = end - 1.2
    return tl
