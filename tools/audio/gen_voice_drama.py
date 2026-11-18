"""Erzeugt die Tutorial-Zeilen des Fluglehrers (Stimme "i0", Schlüssel tut_*) mit Fish Audio Drama 3 (FP8) über einen lokal laufenden `drama serve`.
Quelle der Sprechtexte und Regieanweisungen: tools/audio/drama_tutorial.json (gesprochene Zahlen ausgeschrieben). Die Untertitel (voice_lines.json) entstehen
daraus mit Ziffern („Plattform 2“, „Taxi 7“). Dieselbe Referenzstimme je Sprache (assets/audio/voice/ref/i0_<lang>.wav), fester Seed, jede Regieanweisung
endet auf „wie ein erfahrener Fluglehrer“: so bleibt es eine Stimme.

Server vorher starten (FP8, Referenzen als Stimmen), z. B.:
  drama serve --experts fp8 --vram-reserve-gb 4.5 --addr 127.0.0.1:18732 \
    --voice "lehrer_de=assets/audio/voice/ref/i0_de.wav=<Text>" --voice "lehrer_en=assets/audio/voice/ref/i0_en.wav=<Text>"
Aufruf (Projektwurzel): python3 tools/audio/gen_voice_drama.py [--lang de|en|both] [--only tut_gate …] [--seed N] [--keep-wav DIR]
Lizenz der Ausgabe: Fish Audio Community License („Built with Fish Audio“ in den Credits)."""
import argparse, io, json, os, re, subprocess, tempfile, urllib.request, wave
import numpy as np

SRC = "tools/audio/drama_tutorial.json"
OUT = "assets/audio/voice"
TARGET_DB = {"de": -17.4, "en": -16.3, "fr": -16.8, "es": -16.8}      # mittlerer Pegel der aktiven Sprache, wie die bisherigen Clips
NUM_DE = {"null": "0", "zwei": "2", "drei": "3", "vier": "4", "fünf": "5", "sechs": "6", "sieben": "7", "acht": "8", "neun": "9", "zehn": "10",
          "tausend": "1000", "fünfhundert": "500", "fünfunddreißig": "35"}
NUM_EN = {"zero": "0", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
          "thirty-five": "35", "five hundred": "500", "a thousand": "1000"}

def subtitle(text: str, lang: str) -> str:
    """Untertitel: Regieanweisungen/Wortmarken entfernen, Zahlwörter als Ziffern („Plattform zwei“ → „Plattform 2“)."""
    t = re.sub(r"<[^>]+>", "", text)
    t = re.sub(r"\[[^\]]*\]\s*", "", t)
    m = NUM_DE if lang == "de" else NUM_EN
    for w in sorted(m, key=len, reverse=True):
        t = re.sub(r"(?<![\wäöüÄÖÜß-])" + re.escape(w) + r"(?![\wäöüÄÖÜß-])", m[w], t, flags=re.I if lang == "en" else 0)
    return re.sub(r"\s{2,}", " ", t).strip()

def chunks(text: str, limit=280):
    sents = re.findall(r".+?(?:[.!?]+(?:\s+|$)|$)", text.strip(), flags=re.S)
    out, cur = [], ""
    for s in (x.strip() for x in sents):
        if not s:
            continue
        if cur and len((cur + " " + s).encode()) > limit:
            out.append(cur)
            cur = s
        else:
            cur = (cur + " " + s).strip()
    return out + ([cur] if cur else [])

def speak(url, voice, text, seed):
    body = json.dumps({"text": text, "voice": voice, "split": False, "seed": seed}).encode()
    if not url.startswith("http://127.0.0.1:"):          # nur der lokale drama-Server
        raise ValueError("nur lokale Server erlaubt: " + url)
    return urllib.request.urlopen(urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}), timeout=300).read()  # nosec B310 (Schema oben geprüft)

def render(url, lang, entry, seed):
    parts = []
    for c in chunks(entry["spoken"]):
        parts.append(speak(url, "lehrer_" + lang, c if c.lstrip().startswith("[") else entry["direction"] + " " + c, seed))
    pcm, sr = [], 44100
    for i, p in enumerate(parts):
        with wave.open(io.BytesIO(p)) as w:
            sr = w.getframerate()
            pcm.append(np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0)
        if i < len(parts) - 1:
            pcm.append(np.zeros(int(sr * 0.28), dtype=np.float32))
    return np.concatenate(pcm), sr

def finish(y, sr, lang, dest):
    """Stille beschneiden, Pegel angleichen, 24 kHz mono OGG (wie die bisherigen Clips)."""
    a = np.abs(y)
    idx = np.where(a > 0.015 * a.max())[0]
    y = y[max(0, idx[0] - int(0.06 * sr)): idx[-1] + int(0.20 * sr)]
    act = y[np.abs(y) > 0.02 * np.abs(y).max()]
    gain_db = TARGET_DB[lang] - 20 * np.log10(np.sqrt(np.mean(act ** 2)) + 1e-9)
    dur = len(y) / sr
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
            w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
        flt = f"volume={gain_db:.2f}dB,alimiter=limit=0.89:level=disabled,afade=t=in:d=0.005,afade=t=out:st={max(dur - 0.18, 0):.3f}:d=0.18"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp.name, "-af", flt, "-ar", "24000", "-ac", "1", "-c:a", "libvorbis", "-b:a", "56k", dest], check=True)
    return dur

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="both"); ap.add_argument("--only", nargs="*", default=[]); ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--server", default="http://127.0.0.1:18732/v1/speak"); ap.add_argument("--keep-wav", default="")
    ap.add_argument("--validate", action="store_true", help="jeden Clip mit faster-whisper prüfen und bei Abweichung mit neuem Seed wiederholen")
    ap.add_argument("--tries", type=int, default=5); ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--threshold", type=float, default=0.85, help="Mindestähnlichkeit der Spracherkennung")
    a = ap.parse_args()
    src = json.load(open(SRC, encoding="utf-8"))
    langs = {"both": ["de", "en"], "all": ["de", "en", "fr", "es"]}.get(a.lang, [a.lang])
    import sys
    sys.path.insert(0, "tools/audio")
    import voice_lang
    weak = []
    mp = OUT + "/manifest.json"
    manifest = json.load(open(mp, encoding="utf-8"))
    lines = json.load(open("data/voice_lines.json", encoding="utf-8"))
    for lang in langs:
        for key, e in src.items():
            if a.only and key not in a.only:
                continue
            if lang not in e:
                continue
            dest = f"{OUT}/{lang}/i0_{key}.ogg"
            if a.skip_existing and os.path.exists(dest):
                continue
            sub_want = e[lang].get("subtitle") or subtitle(e[lang]["spoken"], lang)
            best = None
            for attempt in range(a.tries if a.validate else 1):
                y, sr = render(a.server, lang, e[lang], a.seed + attempt * 13)
                if not a.validate:
                    best = (1.0, y, sr)
                    break
                ok, got, sim = voice_lang.check(y, sr, sub_want, lang, threshold=a.threshold)
                print(f"   {lang}/{key} Versuch {attempt + 1}: {'ok' if ok else 'verworfen'} ({sim:.2f}) {got[:70]!r}", flush=True)
                if best is None or sim > best[0]:
                    best = (sim, y, sr)
                if ok:
                    break
            if best[0] < a.threshold:
                weak.append(f"{lang}/i0_{key} ({best[0]:.2f})")
            _, y, sr = best
            if a.keep_wav:
                os.makedirs(a.keep_wav, exist_ok=True)
                with wave.open(f"{a.keep_wav}/{lang}_{key}.wav", "wb") as w:
                    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
            dur = finish(y, sr, lang, dest)
            sub = sub_want
            lines["i0"][lang][key] = sub
            manifest["clips"][f"{lang}/i0_{key}"] = {"text": sub, "seconds": round(dur, 2), "engine": "drama3-fp8", "spoken": e[lang]["spoken"]}
            print(lang, key, f"{dur:.1f}s", flush=True)
            json.dump(manifest, open(mp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            json.dump(lines, open("data/voice_lines.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("\nSchwache Clips: " + ", ".join(weak) if weak else "\nAlle Clips ok.")

if __name__ == "__main__":
    main()
