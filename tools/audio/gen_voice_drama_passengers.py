"""Erzeugt die Fahrgast-Zeilen der zehn zusätzlichen Stimmen (f2–f6, m2–m6; Deutsch und Englisch) mit Fish Audio Drama 3 (FP8) über einen lokal laufenden `drama serve`.
Texte: die Zeilen der Qwen-Stimme f0 aus assets/audio/voice/manifest.json (dieselben 22 Zeilen je Stimme). Stimmen: Referenzaufnahmen aus
tools/audio/passenger_refs/ (gen_passenger_refs.py). Jede Zeile wird mit lokaler Spracherkennung (faster-whisper) geprüft und bei Abweichung mit neuem Seed wiederholt.

Server vorher starten (Beispiel, Referenzen als WAV in einem Arbeitsordner):
  drama serve --experts fp8 --vram-reserve-gb 4.5 --addr 127.0.0.1:18733 --voice "f2_de=<ordner>/de_f2.wav=<Referenztext>" …   (siehe --print-serve)
Aufruf (Projektwurzel):  HF_HOME=<cache mit faster-whisper-medium> python3 tools/audio/gen_voice_drama_passengers.py [--lang de|en|both] [--only f2 m3] [--force] [--print-serve <ordner>]
Lizenz der Ausgabe: Fish Audio Community License („Built with Fish Audio“ in den Credits)."""
import argparse, difflib, json, os, re, shlex, subprocess, sys, unicodedata, wave
import numpy as np

sys.path.insert(0, "tools/audio")
from passenger_voices import VOICES, REF_TEXT, direction
from gen_voice_drama import speak, finish, OUT
import io

REFS = "tools/audio/passenger_refs"
SEED = 31
TRIES = 6
DIG = {"de": ["null", "eins", "zwei", "drei", "vier", "funf", "sechs", "sieben", "acht", "neun"],
       "en": ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]}

def norm(t, lang):
    t = unicodedata.normalize("NFKD", t.lower())
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    return [DIG[lang][int(w)] if w.isdigit() and int(w) < 10 else w for w in t.split()]

_asr = None
def check(y, sr, text, lang):
    """(ok, erkannt, Ähnlichkeit): keine Zusatzwörter (Lacher, Stottern), Ähnlichkeit >= 0,88."""
    global _asr
    import librosa
    if _asr is None:
        from faster_whisper import WhisperModel
        _asr = WhisperModel("medium", device="cpu", compute_type="int8", local_files_only=True)
    segs, _ = _asr.transcribe(librosa.resample(y.astype(np.float32), orig_sr=sr, target_sr=16000), language=lang, beam_size=5)
    got, want = norm(" ".join(s.text for s in segs), lang), norm(text, lang)
    sim = difflib.SequenceMatcher(None, "".join(got), "".join(want)).ratio()
    return sim >= 0.88 and len(got) <= len(want), " ".join(got), sim

def decode(wav_bytes):
    with wave.open(io.BytesIO(wav_bytes)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0, w.getframerate()

def print_serve(workdir):
    """Wandelt die OGG-Referenzen in WAV um und gibt den Startbefehl des Servers aus."""
    os.makedirs(workdir, exist_ok=True)
    args = []
    for vk, per in VOICES.items():
        for lang in per:
            wav = f"{workdir}/{lang}_{vk}.wav"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{REFS}/{lang}/{vk}.ogg", "-ar", "24000", "-ac", "1", wav], check=True)
            args += ["--voice", f"{vk}_{lang}={wav}={REF_TEXT[lang]}"]
    print("drama serve --experts fp8 --vram-reserve-gb 4.5 --addr 127.0.0.1:18733 " + " ".join(shlex.quote(a) for a in args))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="both"); ap.add_argument("--only", nargs="*", default=[]); ap.add_argument("--force", action="store_true")
    ap.add_argument("--keys", nargs="*", default=[], help="nur diese Zeilen, z. B. call angry dest_7")
    ap.add_argument("--server", default="http://127.0.0.1:18733/v1/speak"); ap.add_argument("--out", default=OUT)
    ap.add_argument("--print-serve", default="")
    a = ap.parse_args()
    if a.print_serve:
        print_serve(a.print_serve)
        return
    langs = ["de", "en"] if a.lang == "both" else [a.lang]
    mp = OUT + "/manifest.json"
    manifest = json.load(open(mp, encoding="utf-8"))
    weak = []
    for lang in langs:
        keys = [k.split("/")[1][3:] for k in manifest["clips"] if k.startswith(f"{lang}/f0_")]
        for vk in VOICES:
            if a.only and vk not in a.only:
                continue
            for key in keys:
                if a.keys and key not in a.keys:
                    continue
                dest = f"{a.out}/{lang}/{vk}_{key}.ogg"
                if os.path.exists(dest) and not a.force:
                    continue
                text = manifest["clips"][f"{lang}/f0_{key}"]["text"]
                best = None
                for attempt in range(TRIES):
                    y, sr = decode(speak(a.server, f"{vk}_{lang}", (direction(key, lang) + " " + text).strip(), SEED + attempt * 13 + len(key)))
                    ok, got, sim = check(y, sr, text, lang)
                    if best is None or sim > best[0]:
                        best = (sim, y, sr, got)
                    print(f"  {lang}/{vk}_{key} Versuch {attempt + 1}: {'ok' if ok else 'verworfen'} ({got!r}, {sim:.2f})", flush=True)
                    if ok:
                        break
                sim, y, sr, got = best
                if sim < 0.6:
                    weak.append(f"{lang}/{vk}_{key}: {got!r} ({sim:.2f}) NICHT geschrieben")
                    continue
                if sim < 0.88:
                    weak.append(f"{lang}/{vk}_{key}: {got!r} ({sim:.2f}) schwach")
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                dur = finish(y, sr, lang, dest)
                manifest["clips"][f"{lang}/{vk}_{key}"] = {"text": text, "seconds": round(dur, 2), "engine": "drama3-fp8"}
                json.dump(manifest, open(mp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
                print(f"{lang}/{vk}_{key}: {text!r} {dur:.2f}s", flush=True)
    print("\nAuffällige Clips:" if weak else "\nAlle Clips ok.")
    print("\n".join(weak))

if __name__ == "__main__":
    main()
