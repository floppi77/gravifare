"""Prüft die erzeugten Sprachclips per lokaler Spracherkennung (faster-whisper) gegen den Sollwert.
Nutzt nur bereits lokal vorhandene Modelle (kein Download). Aufruf:
    HF_HOME=<cache> <python-mit-faster-whisper> tools/audio/verify_voice.py [--model small]
Ergebnis: Treffer je Clip, Gesamtquote; Exit-Code 1 bei Abweichungen."""
import argparse, glob, json, os, re, sys, unicodedata
from faster_whisper import WhisperModel

import difflib
DIG = {"de": ["null", "eins", "zwei", "drei", "vier", "funf", "sechs", "sieben", "acht", "neun"],
       "en": ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]}

def norm(t, lang="en"):
    t = unicodedata.normalize("NFKD", t.lower())
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    words = []
    for w in t.split():
        words.append(DIG[lang][int(w)] if w.isdigit() and int(w) < 10 else w)
    return " ".join(words)

ap = argparse.ArgumentParser(); ap.add_argument("--model", default="small"); a = ap.parse_args()
manifest = json.load(open("assets/audio/voice/manifest.json"))["clips"]
model = WhisperModel(a.model, device=os.environ.get("WHISPER_DEVICE", "cpu"), compute_type="int8" if os.environ.get("WHISPER_DEVICE", "cpu") == "cpu" else "float16", local_files_only=True)
bad = 0; total = 0
accent = {}   # Hinweis auf englisch gefärbtes Deutsch: "bitte" wird als bitter/better/bitta erkannt
for key, meta in sorted(manifest.items()):
    lang = key.split("/")[0]
    segs, _ = model.transcribe(f"assets/audio/voice/{key}.ogg", language=lang, beam_size=5)
    got = norm(" ".join(s.text for s in segs), lang); want = norm(meta["text"], lang)
    sim = difflib.SequenceMatcher(None, got.replace(" ", ""), want.replace(" ", "")).ratio()
    # Alternativschreibweisen
    ok = sim >= 0.88   # kleine Schreibabweichungen der Erkennung (bitter/bitte) erlaubt
    total += 1
    if lang == "de" and "dest" in key:
        v = key.split("/")[1].split("_")[0]
        hit = any(w in got.split() for w in ("bitter", "better", "bitta", "bidder", "beta", "bitte r"))
        accent.setdefault(v, [0, 0]); accent[v][0] += int(hit); accent[v][1] += 1
    if not ok:
        bad += 1
        print(f"ABWEICHUNG {key}: erwartet {want!r}, erkannt {got!r} (Ähnlichkeit {sim:.2f})")
print(f"{total - bad}/{total} Clips verständlich erkannt")
for v, (h, n) in sorted(accent.items()):
    print(f"Akzent-Hinweis deutsche Stimme {v}: {h}/{n} Clips mit 'bitte' als bitter/better erkannt")
sys.exit(1 if bad else 0)
