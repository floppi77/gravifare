"""Erzeugt die Fahrgast-Sprachzeilen offline mit Qwen3-TTS (VoiceDesign, Apache-2.0) und schreibt OGG-Dateien.
Zur Laufzeit des Spiels wird KEINE KI benötigt – nur die fertigen Dateien in assets/audio/voice/.

Einrichtung (einmalig, projektlokal, nicht im Repo):
    uv venv .venv/tts --python 3.12 && uv pip install --python .venv/tts/bin/python qwen-tts==0.1.1 torch
Aufruf:
    .venv/tts/bin/python tools/audio/gen_voice.py [--only f0] [--lang de]
Stimmen sind Beschreibungen (keine realen Personen). Ausgabe: assets/audio/voice/<lang>/<stimme>_<zeile>.ogg
"""
import argparse, json, os, subprocess, sys
import numpy as np, soundfile as sf, torch

OUT = "assets/audio/voice"
MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"

VOICES = {  # Sprache -> Stimme -> (Beschreibung in der Sprache der Zeile, Seed). Beschreibung = erfundene Kunststimme.
    "de": {
        "f0": ("Eine junge Frau mit klarer, warmer, fröhlicher Stimme, mittlere Tonlage, locker und freundlich. Deutsche Muttersprachlerin, akzentfreies Standarddeutsch mit deutscher Aussprache.", 101),
        "f1": ("Eine Frau Mitte dreißig mit etwas tieferer, ruhiger, selbstsicherer Stimme, trocken-humorvoll. Deutsche Muttersprachlerin, akzentfreies Standarddeutsch mit deutscher Aussprache.", 202),
        "m0": ("Ein Mann Mitte dreißig mit tiefer, ruhiger, warmer Baritonstimme, entspannt und freundlich. Deutscher Muttersprachler, akzentfreies Standarddeutsch mit deutscher Aussprache.", 303),
        "m1": ("Ein älterer Mann mit tiefer, warmer, leicht rauer Stimme, gelassen und gutmütig. Deutscher Muttersprachler, akzentfreies Standarddeutsch mit deutscher Aussprache.", 404),
    },
    "en": {
        "f0": ("A young woman with a clear, warm, cheerful voice, medium pitch, upbeat and friendly, a little playful. Native English speaker with a neutral accent.", 101),
        "f1": ("A woman in her thirties with a slightly lower, calm and confident voice, relaxed and dry-humored delivery. Native English speaker with a neutral accent.", 202),
        "m0": ("A man in his mid-thirties with a deep, calm, warm baritone voice, relaxed and friendly, casual delivery. Native English speaker with a neutral accent.", 303),
        "m1": ("A middle-aged man with a deep, warm, slightly gravelly voice, easygoing and good-humored delivery. Native English speaker with a neutral accent.", 404),
    },
}
NUM_DE = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
NUM_EN = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
LINES = {
    "de": {"language": "German", "lines": {
        "call": "Hey Taxi!", "thanks": "Danke!", **{f"dest_{n}": f"Plattform {NUM_DE[n]}, bitte!" for n in range(1, 10)}}},
    "en": {"language": "English", "lines": {
        "call": "Hey Taxi!", "thanks": "Thanks!", **{f"dest_{n}": f"Platform {NUM_EN[n]}, please!" for n in range(1, 10)}}},
}

def trim(x, sr):
    """Führende Stille kappen; das Ende klingt natürlich aus: relative Schwelle (-46 dB zur Spitze), Nachlauf
    0,25 s und lange Cosinus-Ausblendung statt hartem Schnitt. Normalisierung erst danach (siehe main)."""
    peak = np.abs(x).max()
    if peak <= 0:
        return x
    idx = np.where(np.abs(x) > peak * 0.02)[0]
    idx_end = np.where(np.abs(x) > peak * 0.005)[0]
    a = max(0, idx[0] - int(0.05 * sr))
    b = min(len(x), idx_end[-1] + int(0.25 * sr))
    y = x[a:b].copy()
    n_in = int(0.012 * sr); n_out = min(len(y) // 2, int(0.18 * sr))
    y[:n_in] *= np.sin(np.linspace(0, np.pi / 2, n_in)) ** 2
    y[-n_out:] *= np.cos(np.linspace(0, np.pi / 2, n_out)) ** 2
    return np.concatenate([y, np.zeros(int(0.06 * sr), dtype=y.dtype)])

def norm(t, lang):
    import re, unicodedata
    dig = {"de": ["null", "eins", "zwei", "drei", "vier", "funf", "sechs", "sieben", "acht", "neun"],
           "en": ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]}
    t = unicodedata.normalize("NFKD", t.lower())
    t = "".join(c for c in t if not unicodedata.combining(c))
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    return [dig[lang][int(w)] if w.isdigit() and int(w) < 10 else w for w in t.split()]

_asr = None
def clip_ok(x, sr, text, lang):
    """Automatische Qualitätsprüfung: lokale Spracherkennung (faster-whisper medium, nur lokale Modelle).
    Akzeptiert nur Clips ohne Zusatzwörter (Lacher, Stottern) und mit Ähnlichkeit >= 0,88."""
    import difflib, librosa
    global _asr
    if _asr is None:
        from faster_whisper import WhisperModel
        _asr = WhisperModel(os.environ.get("WHISPER_MODEL_DIR", "medium"), device="cpu", compute_type="int8", local_files_only=True)
    y = librosa.resample(x.astype(np.float32), orig_sr=sr, target_sr=16000)
    segs, _ = _asr.transcribe(y, language=lang, beam_size=5)
    got = norm(" ".join(sg.text for sg in segs), lang); want = norm(text, lang)
    sim = difflib.SequenceMatcher(None, "".join(got), "".join(want)).ratio()
    return sim >= 0.88 and len(got) <= len(want), " ".join(got), sim

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=""); ap.add_argument("--lang", default=""); ap.add_argument("--force", action="store_true")
    ap.add_argument("--clip", action="append", default=[], help="nur diese Clips neu, z. B. de/f0_dest_5")
    ap.add_argument("--bump", type=int, default=0, help="Seed-Versatz für Wiederholungen")
    ap.add_argument("--validate", action="store_true", help="jeden Clip per Spracherkennung prüfen und bei Fehlern mit neuem Seed wiederholen")
    ap.add_argument("--tries", type=int, default=8)
    a = ap.parse_args()
    from qwen_tts import Qwen3TTSModel
    model = Qwen3TTSModel.from_pretrained(MODEL, device_map="cuda:0", dtype=torch.bfloat16)
    manifest = {"model": MODEL, "license": "Apache-2.0", "voices": {f"{l}/{k}": {"instruct": v[0], "seed": v[1]} for l, vs in VOICES.items() for k, v in vs.items()}, "clips": {}}
    for lang, cfg in LINES.items():
        if a.lang and a.lang != lang: continue
        os.makedirs(f"{OUT}/{lang}", exist_ok=True)
        for vk, (instruct, seed) in VOICES[lang].items():
            if a.only and a.only != vk: continue
            for key, text in cfg["lines"].items():
                dst = f"{OUT}/{lang}/{vk}_{key}.ogg"
                if a.clip and f"{lang}/{vk}_{key}" not in a.clip: continue
                if os.path.exists(dst) and not a.force and not a.clip: continue
                x = None
                for attempt in range(a.tries if a.validate else 1):
                    torch.manual_seed(seed + a.bump + attempt * 13)  # identischer Seed je Stimme, Versatz bei Wiederholung
                    wavs, sr = model.generate_voice_design(text=text, instruct=instruct, language=cfg["language"], do_sample=True, temperature=0.7)
                    x = trim(np.asarray(wavs[0], dtype=np.float32), sr)
                    if not a.validate:
                        break
                    ok, got, sim = clip_ok(x, sr, text, lang)
                    print(f"   Versuch {attempt + 1}: {'ok' if ok else 'verworfen'} ({got!r}, {sim:.2f})", flush=True)
                    if ok:
                        break
                x = x / max(1e-6, np.abs(x).max()) * 0.85
                tmp = dst[:-4] + ".wav"
                sf.write(tmp, x, sr)
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
                os.remove(tmp)
                manifest["clips"][f"{lang}/{vk}_{key}"] = {"text": text, "seconds": round(len(x) / sr, 2)}
                print(f"{lang}/{vk}_{key}: {text!r} {len(x)/sr:.2f}s", flush=True)
    mp = f"{OUT}/manifest.json"
    old = json.load(open(mp)) if os.path.exists(mp) else {"clips": {}}
    old.update({k: v for k, v in manifest.items() if k != "clips"}); old["clips"].update(manifest["clips"])
    json.dump(old, open(mp, "w"), indent=1, ensure_ascii=False)

if __name__ == "__main__":
    main()
