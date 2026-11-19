"""Polnische Sprachausgabe (Runde 85) mit Fish Audio Drama 3 (FP8) über einen lokal laufenden `drama serve` – Qwen3-TTS kann kein Polnisch.

1. --refs: Je Figur eine polnische Referenzstimme. Drama spricht den Referenztext ohne Vorlage (zufälliger, muttersprachlicher Sprecher);
   unter mehreren Seeds wird der genommen, dessen mittlere Tonlage im Zielbereich der Figur liegt und den die Spracherkennung versteht.
   Ablage: tools/audio/passenger_refs/pl/<stimme>.ogg (Fahrgäste, Tankwart, Zentrale) und assets/audio/voice/ref/i0_pl.wav (Fluglehrer).
2. --lines: alle polnischen Zeilen außer der Flugschule (die macht gen_voice_drama.py --lang pl): Fahrgäste f0–f6/m0–m6, Tankwart t0,
   Zentrale d0 (mit Funk-Effekt), Einspieler i0_vid_*. Server dafür mit den Referenzen aus Schritt 1 starten (--print-serve).
Jeder Clip wird mit faster-whisper (medium, lokal) gegen den Untertitel geprüft und bei Abweichung mit neuem Seed wiederholt.
Aufruf (Projektwurzel): .venv/tts/bin/python tools/audio/gen_voice_pl.py --refs | --print-serve <ordner> | --lines [--only f0 d0] [--force]
Lizenz der Ausgabe: Fish Audio Community License („Built with Fish Audio“ in den Credits)."""
import argparse, io, json, os, shlex, subprocess, sys, wave
import numpy as np

sys.path.insert(0, "tools/audio")
import voice_lang
from gen_voice_drama import speak, finish, OUT
from passenger_voices import REF_TEXT, TARGET_F0, direction

REFS = "tools/audio/passenger_refs/pl"
LEHRER_REF = "assets/audio/voice/ref/i0_pl.wav"
LEHRER_TEXT = "Witaj w szkole lotniczej. Jestem twoim instruktorem lotu i wyjaśnię ci wszystko, co musisz wiedzieć, żeby pilotować taksówkę. Słuchaj uważnie i trzymaj dysze równo."
# Zielbereich der mittleren Grundfrequenz (Hz) und Stimmbeschreibung als Regieanweisung (Drama übernimmt Haltung und Tempo daraus).
FIG = {
    "f0": ((205, 260), "[młoda kobieta, jasny, ciepły, wesoły głos]"),
    "f1": ((170, 212), "[kobieta po trzydziestce, niższy, spokojny, pewny siebie głos]"),
    "m0": ((98, 132), "[mężczyzna po trzydziestce, głęboki, spokojny, ciepły baryton]"),
    "m1": ((90, 125), "[starszy mężczyzna, głęboki, ciepły, lekko zachrypnięty głos]"),
    "t0": ((85, 125), "[stary pracownik stacji benzynowej, gruby, chrapliwy, zrzędliwy głos]"),
    "d0": ((165, 215), "[dyspozytorka po czterdziestce, spokojny, opanowany, lekko ironiczny głos]"),
    "i0": ((100, 140), "[doświadczony instruktor lotniczy, spokojny, wyraźny, przyjazny męski głos]"),
    **{vk: (TARGET_F0[vk], d) for vk, d in {
        "f2": "[nastolatka, wysoki, podekscytowany głos]", "f3": "[kobieta pod trzydziestkę, niski, zadymiony alt]",
        "f4": "[bizneswoman, wyraźny, stanowczy, lekko nosowy głos]", "f5": "[starsza pani, ciepły, lekko drżący głos]",
        "f6": "[kobieta około trzydziestki, miękki, łagodny, rozmarzony głos]", "m2": "[chłopak, jasny tenor, podekscytowany]",
        "m3": "[mężczyzna po czterdziestce, bardzo głęboki, dudniący bas]", "m4": "[mężczyzna pod trzydziestkę, nerwowy, szybki, lekko nosowy głos]",
        "m5": "[mężczyzna po czterdziestce, gładki głos spikera, precyzyjny]", "m6": "[bardzo stary mężczyzna, cienki, łamiący się głos]"}.items()},
}
# „Chciałbym“ ist die männliche Form: ohne Vorlage wählt Drama dann fast immer eine Männerstimme. Die Disponentin bekommt die weibliche Form.
# Das tatsächlich gesprochene Transkript liegt als <stimme>.txt neben der Referenz (für --print-serve).
REF_TEXT_F = "Dzień dobry! Chciałabym dotrzeć jeszcze dziś, więc proszę lecieć szybko, ale bezpiecznie. Bardzo dziękuję za podwiezienie."
FEMININE_TEXT = {"d0"}
T0_DIR = "[gderliwie, z naciskiem]"
D0_DIR = "[spokojnie, rzeczowo, jak przez radio]"
VID_DIR = "[spokojnie i wyraźnie, objaśniająco, jak doświadczony instruktor lotniczy]"


def decode(b):
    with wave.open(io.BytesIO(b)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0, w.getframerate()


def median_f0(x, sr):
    import librosa
    y = librosa.resample(x, orig_sr=sr, target_sr=16000)
    f0, voiced, _ = librosa.pyin(y, fmin=60, fmax=450, sr=16000)
    f0 = f0[voiced & ~np.isnan(f0)]
    return float(np.median(f0)) if len(f0) > 5 else 0.0


def make_refs(server, only, tries, force):
    """Referenzen ohne Vorlage: bester Seed nach Tonlage und Verständlichkeit."""
    os.makedirs(REFS, exist_ok=True)
    used = []
    for vk, ((lo, hi), desc) in FIG.items():
        if only and vk not in only:
            continue
        dst = LEHRER_REF if vk == "i0" else f"{REFS}/{vk}.ogg"
        if os.path.exists(dst) and not force:
            continue
        text = LEHRER_TEXT if vk == "i0" else (REF_TEXT_F if vk in FEMININE_TEXT else REF_TEXT["pl"])
        best = None
        for k in range(tries):
            seed = 4100 + 97 * k + 7 * len(vk) + ord(vk[0]) + int(vk[1])
            y, sr = decode(speak(server, None, desc + " " + text, seed))
            f = median_f0(y, sr)
            ok, got, sim = voice_lang.check(y, sr, text, "pl", threshold=0.85)
            miss = 0.0 if lo <= f <= hi else min(abs(f - lo), abs(f - hi))
            score = miss + (0 if ok else 200) + sum(15 for g in used if abs(g - f) < 3)       # möglichst unterschiedliche Stimmen (nur fast gleiche Tonlage zählt)
            print(f"  {vk} Seed {seed}: {f:.0f} Hz (Ziel {lo}-{hi}), Erkennung {sim:.2f}", flush=True)
            if best is None or score < best[0]:
                best = (score, y, sr, f, sim)
            if score == 0:
                break
        _, y, sr, f, sim = best
        used.append(f)
        y = y / max(1e-6, np.abs(y).max()) * 0.85
        idx = np.where(np.abs(y) > 0.02)[0]
        y = y[max(0, idx[0] - int(0.05 * sr)): idx[-1] + int(0.25 * sr)]
        tmp = dst if dst.endswith(".wav") else dst[:-4] + ".wav"
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
        if not dst.endswith(".wav"):
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", dst], check=True)
            os.remove(tmp)
        if vk != "i0":
            open(f"{REFS}/{vk}.txt", "w", encoding="utf-8").write(text)
        print(f"Referenz pl/{vk}: {len(y) / sr:.1f} s, {f:.0f} Hz, Erkennung {sim:.2f}", flush=True)


def print_serve(workdir):
    os.makedirs(workdir, exist_ok=True)
    args = []
    for vk in FIG:
        if vk == "i0":
            args += ["--voice", f"lehrer_pl={LEHRER_REF}={LEHRER_TEXT}"]
            continue
        wav = f"{workdir}/pl_{vk}.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{REFS}/{vk}.ogg", "-ar", "24000", "-ac", "1", wav], check=True)
        tp = f"{REFS}/{vk}.txt"
        text = open(tp, encoding="utf-8").read().strip() if os.path.exists(tp) else REF_TEXT["pl"]
        args += ["--voice", f"{vk}_pl={wav}={text}"]
    print(" ".join(shlex.quote(a) for a in args))


def jobs():
    """(Stimme, Server-Stimme, Schlüssel, Untertitel, Regieanweisung) aller polnischen Zeilen außer der Flugschule."""
    from gen_voice import LINES
    vl = json.load(open("data/voice_lines.json", encoding="utf-8"))
    pas = dict(LINES["pl"]["lines"]); pas.update(vl["passenger_extra"]["pl"])
    out = []
    for vk in ["f0", "f1", "m0", "m1", "f2", "f3", "f4", "f5", "f6", "m2", "m3", "m4", "m5", "m6"]:
        for key, text in pas.items():
            out.append((vk, f"{vk}_pl", key, text, direction(key, "pl")))
    for vk in ("m0", "f0"):                        # Runde 86: seltener Gast „floppi“ und Level 42
        for key, text in vl.get(vk, {}).get("pl", {}).items():
            out.append((vk, f"{vk}_pl", key, text, "[ciepło, serdecznie]" if key == "floppi_thanks" else "[spokojnie, tajemniczo]"))
    for key, text in vl["t0"]["pl"].items():
        out.append(("t0", "t0_pl", key, text, T0_DIR))
    for key, text in vl["d0"]["pl"].items():
        out.append(("d0", "d0_pl", key, text, D0_DIR))
    for key, text in vl["i0"]["pl"].items():
        if key.startswith("vid_"):
            out.append(("i0", "lehrer_pl", key, text, VID_DIR))
    return out


def make_lines(server, only, force, tries):
    from gen_voice import radio
    mp = OUT + "/manifest.json"
    manifest = json.load(open(mp, encoding="utf-8"))
    os.makedirs(f"{OUT}/pl", exist_ok=True)
    weak = []
    for vk, voice, key, text, d in jobs():
        if only and vk not in only:
            continue
        dest = f"{OUT}/pl/{vk}_{key}.ogg"
        if os.path.exists(dest) and not force:
            continue
        say = voice_lang.spoken(text, "pl")
        thr = 0.85 if len(text) > 60 else 0.88
        best = None
        for attempt in range(tries):
            y, sr = decode(speak(server, voice, (d + " " + say).strip(), 31 + attempt * 13 + len(key)))
            ok, got, sim = voice_lang.check(y, sr, text, "pl", threshold=thr)
            print(f"  pl/{vk}_{key} Versuch {attempt + 1}: {'ok' if ok else 'verworfen'} ({sim:.2f}) {got[:60]!r}", flush=True)
            if best is None or sim > best[0]:
                best = (sim, y, sr)
            if ok:
                break
        sim, y, sr = best
        if sim < 0.6:
            weak.append(f"pl/{vk}_{key} ({sim:.2f}) NICHT geschrieben")
            continue
        if sim < thr:
            weak.append(f"pl/{vk}_{key} ({sim:.2f}) schwach")
        if vk == "d0":
            y = radio(y, sr)
        dur = finish(y, sr, "pl", dest)
        manifest["clips"][f"pl/{vk}_{key}"] = {"text": text, "seconds": round(dur, 2), "engine": "drama3-fp8"}
        json.dump(manifest, open(mp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"pl/{vk}_{key}: {dur:.2f}s", flush=True)
    print("\nAuffällige Clips:\n" + "\n".join(weak) if weak else "\nAlle Clips ok.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--refs", action="store_true"); ap.add_argument("--lines", action="store_true"); ap.add_argument("--print-serve", default="")
    ap.add_argument("--only", nargs="*", default=[]); ap.add_argument("--force", action="store_true"); ap.add_argument("--tries", type=int, default=6)
    ap.add_argument("--server", default="http://127.0.0.1:18733/v1/speak")
    a = ap.parse_args()
    if a.print_serve:
        print_serve(a.print_serve)
    elif a.refs:
        make_refs(a.server, a.only, max(a.tries, 8), a.force)      # Frauenstimmen ohne Vorlage sind selten: bei Bedarf --tries 24
    elif a.lines:
        make_lines(a.server, a.only, a.force, a.tries)


if __name__ == "__main__":
    main()
