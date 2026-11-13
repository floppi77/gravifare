"""Level 99 (Thema t99, „Endloser Aufstieg“): endlose Steigerung ohne Auflösung, im Klang von t19, nahtlos loopbar (Runde 66).
6 Abschnitte à 4 Takte (VI – iv – V – V, nie die Tonika), jeder Abschnitt einen Ganzton höher (Rückung); nach 6 Abschnitten eine Oktave.
Alle Tonhöhen in Oktavschichten mit Gewicht nur nach absoluter Tonhöhe (Shepard): die Schleife schließt ohne Sprung nach unten.
Gegen „schief“: Echo endet an jedem Tonartwechsel (kein Nachklang der alten Tonart), wenig Vibrato, Melodie ohne übermäßige Sekunde.
Treibender: 138 BPM, galoppierender Oktavbass, 16tel-Becken, Snare-Wirbel und Tom-Lauf vor jedem Wechsel.
Aufruf (aus der Projektwurzel): python3 tools/audio/gen_music_99.py   -> assets/audio/music/t99_<A|B|C>.ogg
Optional: --preview <datei.ogg> schreibt zusätzlich die Mischung zweimal hintereinander (Schleifenstelle prüfen)."""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_music as gm
from music_score import THEMES

SEG = 6                        # Abschnitte (je ein Ganzton, zusammen eine Oktave)
BARS = 4
BPM = 138
T19 = THEMES["t19"]

# Zwei Vier-Takt-Phrasen (Motiv aus t19), über VI – iv – V – V; enden auf Grundton bzw. Leitton der Dominante
PHRASES = [["7...4...7...9... a.......9.......", "8...6...8...b... a.......b......."],
           ["c.......b...9... 7...9...a.......", "b...a...9...8... d..............."]]

def segment_theme(s):
    th = dict(T19)
    th.update(name="p99", key=38 + 2 * s, bpm=BPM, order="ZS", chords={"Z": [], "S": [5, 3, 4, 4]}, lead_S=PHRASES[s % 2],
              fill=True, fill_fast=True, nobreak=True,
              bass="r.ror.ror.ror.ro",
              kick="x---x---x---x---", snare="----x-------x---" * 3 + "----x---x-x-xxxx", hat="xxxxxxxxxxxxxxxx",
              arp="0123432101234321", tkick="x-x-x-x-x-x-x-x-", that="--x---x---x---x-")
    return th

def collect():
    allch = {k: [] for k in ("bass", "drum", "harm", "lead", "tense", "tdrum")}
    step = seg_len = None
    for s in range(SEG):
        ch, step, seg_len, bars = gm.build(segment_theme(s))
        for k, lst in ch.items():
            for (st, ln, m, inst, vel) in lst:
                allch[k].append((st + s * seg_len, ln, m, inst, vel))
    return allch, step, seg_len

def shepard(notes, total, center, sigma, layers=(-24, -12, 0, 12, 24)):
    out = None
    for k in layers:
        lay = []
        for (st, ln, m, inst, vel) in notes:
            p = m + k
            w = float(np.exp(-0.5 * ((p - center) / sigma) ** 2))
            if w > 0.03 and 26 <= p <= 96:
                lay.append((st, ln, p, inst, vel * w))
        if lay:
            x = gm.render_paula(lay, total)
            out = x if out is None else out + x
    return out

def gated_echo(x, delay, gain, seg_len, total):
    """Echo, dessen Wiederholungen an jedem Tonartwechsel abbrechen (kurz ausgeblendet), damit nichts in der alten Tonart nachklingt."""
    wet = gm.echo(x, delay, gain) - x
    mask = np.ones(x.shape[1])
    hold = 2 * delay
    fade = int(0.02 * gm.SR)
    for b in range(0, x.shape[1], seg_len):
        a0 = max(b - fade, 0)
        mask[a0:b] = np.linspace(1.0, 0.0, b - a0)
        mask[b:b + hold] = 0.0
        e = min(b + hold + fade, len(mask))
        mask[b + hold:e] = np.linspace(0.0, 1.0, e - (b + hold))
    return x + wet * mask

def main():
    gm.PAULA["glead"] = dict(gm.PAULA["glead"], vib=(0.08, 6, 16))     # wenig Vibrato: Oktavschichten schweben sonst gegeneinander
    gm.BANK.update(gm.bank())
    ch, step, seg_len = collect()
    total = seg_len * SEG
    full = total + gm.TAIL
    bass = shepard(ch["bass"], full, 41.0, 6.0, (-12, 0, 12))
    harm = shepard(ch["harm"], full, 55.0, 7.0)
    lead = shepard(ch["lead"], full, 67.0, 6.5)
    tense = shepard(ch["tense"], full, 74.0, 7.0)
    drum = gm.render_paula(ch["drum"], full)
    tdrum = gm.render_paula(ch["tdrum"], full)
    L = gm.level
    mix = dict(gm.MIX, drum=-15.0, tdrum=-21.0)
    bass, drum, harm, lead, tense, tdrum = [L(x, mix[k]) for x, k in ((bass, "bass"), (drum, "drum"), (harm, "harm"), (lead, "lead"), (tense, "tense"), (tdrum, "tdrum"))]
    A = gm.pan(bass, -0.2) + gm.pan(drum, 0.25) + gm.pan(harm, -0.45)
    B = gated_echo(gm.pan(lead, 0.45), 3 * step, 0.22, seg_len, full)
    C = gated_echo(gm.pan(tense, 0.5) + gm.pan(tdrum, -0.3), 3 * step, 0.18, seg_len, full)
    # Nachklang am Schleifenende kurz abklingen lassen: Töne der letzten Tonart würden im Anfang reiben
    tail_mask = np.ones(full)
    tail_mask[total:] = np.exp(-np.arange(full - total) / (0.04 * gm.SR))
    A = gm.wrap(A * tail_mask, total)
    B = gm.wrap(B * tail_mask, total)
    C = gm.wrap(C * tail_mask, total)
    g = 10 ** ((gm.TARGET_LUFS - gm.lufs(A + B)) / 20.0)
    peak = float(np.abs(A + B + C).max()) * g
    if peak > 0.92:
        g *= 0.92 / peak
    A, B, C = A * g, B * g, C * g
    os.makedirs(gm.OUT, exist_ok=True)
    for k, x in (("A", A), ("B", B), ("C", C)):
        gm.write_ogg("%st99_%s.ogg" % (gm.OUT, k), x)
    if "--preview" in sys.argv:
        m = A + B + C
        gm.write_ogg(sys.argv[sys.argv.index("--preview") + 1], np.concatenate([m, m], axis=1))
    print("Schleife %.1f s, %d Takte, Abschnitt %d Samples" % (total / gm.SR, SEG * BARS, seg_len))

if __name__ == "__main__":
    main()
