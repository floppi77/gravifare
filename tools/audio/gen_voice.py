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
_FR = " Locutrice native française, accent standard de France."
_FR_M = " Locuteur natif français, accent standard de France."
_ES = " Hablante nativa de español de España, acento castellano neutro."
_ES_M = " Hablante nativo de español de España, acento castellano neutro."
VOICES["fr"] = {
    "f0": ("Une jeune femme à la voix claire, chaleureuse et joyeuse, tessiture moyenne, détendue et aimable." + _FR, 101),
    "f1": ("Une femme d’environ trente-cinq ans à la voix un peu plus grave, calme et assurée, avec un humour pince-sans-rire." + _FR, 202),
    "m0": ("Un homme d’environ trente-cinq ans à la voix de baryton grave, calme et chaleureuse, détendu et aimable." + _FR_M, 303),
    "m1": ("Un homme âgé à la voix grave, chaleureuse et légèrement rauque, posé et bienveillant." + _FR_M, 404),
    "t0": ("Un vieux pompiste à la voix grave et rauque, bougon mais bon enfant, qui parle avec beaucoup d’insistance." + _FR_M, 505),
    "d0": ("Une régulatrice d’une quarantaine d’années à la voix calme, maîtrisée, légèrement ironique, à la diction claire, comme à la radio." + _FR, 606),
}
VOICES["es"] = {
    "f0": ("Una mujer joven con voz clara, cálida y alegre, tono medio, desenfadada y amable." + _ES, 101),
    "f1": ("Una mujer de unos treinta y cinco años con voz algo más grave, tranquila y segura, con un humor seco." + _ES, 202),
    "m0": ("Un hombre de unos treinta y cinco años con voz de barítono grave, tranquila y cálida, relajado y amable." + _ES_M, 303),
    "m1": ("Un hombre mayor con voz grave, cálida y algo ronca, sereno y bondadoso." + _ES_M, 404),
    "t0": ("Un gasolinero mayor con voz grave y ronca, gruñón pero bonachón, que habla con mucho énfasis." + _ES_M, 505),
    "d0": ("Una operadora de radio de unos cuarenta años con voz tranquila, serena, algo irónica y dicción clara, como por radio." + _ES, 606),
}
VOICES["fr"]["i0"] = VOICES["fr"]["m0"]
VOICES["es"]["i0"] = VOICES["es"]["m0"]
SPECIAL = json.load(open("data/voice_lines.json"))          # gemeinsame Quelle für Generator und Spiel-Untertitel
PASSENGER_VOICES = ["f0", "f1", "m0", "m1"]
VOICES["de"]["t0"] = ("Ein älterer Tankwart mit tiefer, rauer, gutmütig-grantiger Stimme, spricht mit kräftiger Betonung. Deutscher Muttersprachler, akzentfreies Standarddeutsch mit deutscher Aussprache.", 505)
VOICES["en"]["t0"] = ("An older gas station attendant with a deep, rough, good-naturedly grumpy voice, speaking with strong emphasis. Native English speaker with a neutral accent.", 505)
VOICES["de"]["d0"] = ("Eine Disponentin Mitte vierzig mit ruhiger, souveräner, leicht ironischer Stimme und klarer Aussprache, wie über Funk. Deutsche Muttersprachlerin, akzentfreies Standarddeutsch mit deutscher Aussprache.", 606)
VOICES["en"]["d0"] = ("A dispatcher woman in her forties with a calm, composed, slightly ironic voice and clear diction, as over a radio. Native English speaker with a neutral accent.", 606)
VOICES["de"]["i0"] = VOICES["de"]["m0"]          # Fluglehrer im Tutorial: gleiche Männerstimme wie m0 (ohne Funkeffekt)
VOICES["en"]["i0"] = VOICES["en"]["m0"]
NUM_DE = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
NUM_EN = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
NUM_FR = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"]
NUM_ES = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
LINES = {
    "de": {"language": "German", "lines": {
        "call": "Hey Taxi!", "thanks": "Danke!", "angry": "Hey, Idiot!", "dest_exit": "Zum Ausgang, bitte!", "dest_H": "Zum Krankenhaus, bitte!", **{f"dest_{n}": f"Plattform {NUM_DE[n]}, bitte!" for n in range(1, 10)}}},
    "en": {"language": "English", "lines": {
        "call": "Hey Taxi!", "thanks": "Thanks!", "angry": "Hey, idiot!", "dest_exit": "To the exit, please!", "dest_H": "To the hospital, please!", **{f"dest_{n}": f"Platform {NUM_EN[n]}, please!" for n in range(1, 10)}}},
    "fr": {"language": "French", "lines": {
        "call": "Hé, taxi !", "thanks": "Merci !", "angry": "Hé, espèce d’idiot !", "dest_exit": "À la sortie, s’il vous plaît !", "dest_H": "À l’hôpital, s’il vous plaît !", **{f"dest_{n}": f"Plateforme {NUM_FR[n]}, s’il vous plaît !" for n in range(1, 10)}}},
    "es": {"language": "Spanish", "lines": {
        "call": "¡Eh, taxi!", "thanks": "¡Gracias!", "angry": "¡Oye, idiota!", "dest_exit": "¡A la salida, por favor!", "dest_H": "¡Al hospital, por favor!", **{f"dest_{n}": f"¡A la plataforma {NUM_ES[n]}, por favor!" for n in range(1, 10)}}},
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
    if lang in ("fr", "es"):                         # Französisch/Spanisch: gemeinsame Prüfung mit Zahlwörtern (tools/audio/voice_lang.py)
        sys.path.insert(0, "tools/audio")
        import voice_lang
        return voice_lang.check(x, sr, text, lang)
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

def radio(x, sr):
    """Funk-Effekt für die Disponentin: Bandpass 300–3400 Hz, leichte Sättigung, Rauschbett, Squelch-Klicks."""
    from scipy import signal
    sos = signal.butter(4, [300, 3400], btype="bandpass", fs=sr, output="sos")
    y = signal.sosfilt(sos, x.astype(np.float64))
    y = np.tanh(y * 2.4) / np.tanh(2.4)
    rng = np.random.default_rng(3)
    noise = signal.sosfilt(sos, rng.standard_normal(len(y))) * 0.012
    y = y + noise
    n = int(0.035 * sr)
    burst = signal.sosfilt(sos, rng.standard_normal(n)) * np.linspace(1, 0, n) * 0.06
    return np.concatenate([burst, y, burst[: int(n * 0.8)] * 1.2]).astype(np.float32)

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
            lines = dict(cfg["lines"]); lines.update(SPECIAL["passenger_extra"][lang]) if vk in PASSENGER_VOICES else None
            if vk not in PASSENGER_VOICES:
                lines = SPECIAL.get(vk, {}).get(lang, {})
            for key, text in lines.items():
                dst = f"{OUT}/{lang}/{vk}_{key}.ogg"
                if a.clip and f"{lang}/{vk}_{key}" not in a.clip: continue
                if os.path.exists(dst) and not a.force and not a.clip: continue
                x = None
                for attempt in range(a.tries if a.validate else 1):
                    torch.manual_seed(seed + a.bump + attempt * 13)  # identischer Seed je Stimme, Versatz bei Wiederholung
                    say = text
                    if lang in ("fr", "es"):                 # Ziffern im Untertitel („plateforme 2“) für die Sprachausgabe ausschreiben
                        sys.path.insert(0, "tools/audio")
                        import voice_lang
                        say = voice_lang.spoken(text, lang)
                    wavs, sr = model.generate_voice_design(text=say, instruct=instruct, language=cfg["language"], do_sample=True, temperature=0.7)
                    x = trim(np.asarray(wavs[0], dtype=np.float32), sr)
                    if not a.validate:
                        break
                    ok, got, sim = clip_ok(x, sr, text, lang)
                    print(f"   Versuch {attempt + 1}: {'ok' if ok else 'verworfen'} ({got!r}, {sim:.2f})", flush=True)
                    if ok:
                        break
                if vk == "d0":
                    x = radio(x, sr)
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
