"""Tonspur des Trailers: Musikbett aus den Schichten des Spiel-Themas t14 (132 BPM), dazu Riser, Einschläge, Kicks, Spiel-Effekte
an den Stellen, an denen sie im Bild passieren, und Sprachzeilen des Spiels. Aufruf: python3 tools/trailer/audio.py <de|en>"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import sound
from sound import SR, Mix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BPM = 132.0
BEAT = 60.0 / BPM
BAR = BEAT * 4


def music_bed(total, drop):
    """Intro mit gefilterter Basisschicht, ab `drop` alle drei Schichten (Takt 16 des Stücks); danach Schleife."""
    st = [sound.load(f"{ROOT}/assets/audio/music/t14_{x}.ogg") for x in "ABC"]
    n = len(st[0])
    def loop(y, start_bar, seconds):
        i0 = int(start_bar * BAR * SR)
        idx = (np.arange(int(seconds * SR)) + i0) % n
        return y[idx]
    out = Mix(total)
    # Intro: Takt 8-15 des Stücks, nur A, Tiefpass öffnet sich, viel Hall
    intro = loop(st[0], 8, drop)
    t = np.linspace(0, 1, len(intro))
    intro = sound.lowpass(intro, 300 + 7000 * t ** 2.2)
    intro = sound.reverb(intro, 3.0, 0.35)[:len(intro)]
    out.add(sound.fade(intro, 1.5, 0.05), 0.0, 0.85)
    # Hauptteil: ab Takt 16 des Stücks, alle Schichten
    body = (loop(st[0], 16, total - drop) * 0.8 + loop(st[1], 16, total - drop) * 1.0 + loop(st[2], 16, total - drop) * 0.9)
    out.add(body, drop, 1.0)
    return out.y


def kick(f=52.0, seconds=0.5):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    fr = f + 110 * np.exp(-t * 40)
    y = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 7.5)
    click = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 300) * 0.35
    return ((y + click)[:, None].repeat(2, 1) * 0.9).astype(np.float32)


def sfx(name):
    return sound.load(f"{ROOT}/assets/audio/sfx/{name}.wav")


def voice(lang, name):
    return sound.load(f"{ROOT}/assets/audio/voice/{lang}/{name}.ogg")


def build(lang, tl):
    total = tl.total + 3.5
    m = Mix(total)
    bed = music_bed(total, tl.drop)
    hits = [h for h in tl.impacts]
    kicks_from = tl.drop
    kt = [kicks_from + i * BEAT for i in range(int((tl.end_music - kicks_from) / BEAT))]
    bed = sound.sidechain(bed, kt, 0.35, 0.22)
    # Ende der Musik: hart abgeschnitten mit Hall-Schwanz
    for (t0, t1) in getattr(tl, "mutes", []):
        i0, i1 = int(t0 * SR), min(int(t1 * SR), len(bed))
        bed[i0:i1] *= np.linspace(0.6, 0.0, i1 - i0)[:, None] if i1 > i0 else 1
    cut = int(tl.end_music * SR)
    bed[cut:] = 0
    bed[cut - int(0.02 * SR):cut] *= np.linspace(1, 0, int(0.02 * SR))[:, None]
    m.add(bed, 0.0, 0.62)
    # Kicks im Hauptteil
    for t in kt:
        m.add(kick(), t, 0.55)
    # Drone der Einleitung
    m.add(sound.fade(sound.drone(tl.drop + 0.5, 41.0), 2.5, 0.4), 0.0, 0.22)
    for (t0, dur) in tl.risers:
        m.add(sound.riser(dur), t0, 0.5)
    for t in hits:
        m.add(sound.impact(3.2), t, 0.9)
    for t in tl.whooshes:
        m.add(sound.whoosh(0.7), t - 0.35, 0.35)
    for t in tl.ticks:
        m.add(sound.tick(), t, 0.4)
    for (t, name, g) in tl.sfx:
        m.add(sfx(name), t, g)
    for (t, name, g) in tl.voices:
        if name == "tut_done_tail":
            v = sound.load(f"{ROOT}/assets/audio/voice/{lang}/i0_tut_done.ogg", start=tl.tail_from)
        else:
            v = voice(lang, name)
        m.add(sound.reverb(v, 1.2, 0.12)[:len(v) + SR // 2] if name == "tut_done_tail" else v, t, g)
    # Schluss: kurzer Nachhall über alles ab Logo
    y = m.y
    y = sound.normalize(y, 0.97)
    return y


