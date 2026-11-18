"""Erzeugt die Sprachzeilen des Fluglehrers (Stimme "i0": Tutorial tut_* und Einspieler vid_*) mit EINER gleichbleibenden Stimme:
1. Referenzaufnahme je Sprache mit Qwen3-TTS VoiceDesign (einmalig, liegt danach in assets/audio/voice/ref/),
2. alle Zeilen mit Qwen3-TTS Base als Stimmklon dieser Referenz (kein Zufallssprecher je Zeile, natürlicher Satzfluss).
Aufruf (Projektwurzel):  .venv/tts/bin/python tools/audio/gen_voice_clone.py [--lang de] [--only tut_] [--new-ref]
Ausgabe: assets/audio/voice/<lang>/i0_<schlüssel>.ogg, Eintrag im manifest.json. Läuft offline (Modelle im lokalen HF-Cache)."""
import argparse, json, os, subprocess, sys
import numpy as np, soundfile as sf, torch

sys.path.insert(0, "tools/audio")
from gen_voice import trim, VOICES, OUT

REF_TEXT = {
    "de": "Willkommen in der Flugschule. Ich bin dein Fluglehrer und erkläre dir alles, was du für den Dienst als Taxipilot wissen musst. Hör gut zu, und halte die Düsen ruhig.",
    "en": "Welcome to flight school. I am your flight instructor, and I will explain everything you need to know to serve as a taxi pilot. Listen carefully, and keep your thrusters steady.",
    "fr": "Bienvenue à l’école de pilotage. Je suis votre instructeur de vol et je vais vous expliquer tout ce qu’il faut savoir pour piloter un taxi. Écoutez bien, et gardez les réacteurs bien stables.",
    "es": "Bienvenido a la escuela de vuelo. Soy tu instructor de vuelo y te explicaré todo lo que necesitas saber para pilotar un taxi. Escucha con atención y mantén los propulsores estables.",
}
LANGNAME = {"de": "German", "en": "English", "fr": "French", "es": "Spanish"}
REF_DIR = OUT + "/ref"
INSTRUCT_EXTRA = {"de": " Er spricht wie ein erfahrener Fluglehrer: ruhig, klar, freundlich und mit natürlichem Sprachfluss.",
                  "en": " He speaks like an experienced flight instructor: calm, clear, friendly and with a natural flow.",
                  "fr": " Il parle comme un instructeur de vol expérimenté : calme, clair, aimable, avec un débit naturel.",
                  "es": " Habla como un instructor de vuelo experimentado: tranquilo, claro, amable y con un ritmo natural."}


def make_refs(langs, force):
    from qwen_tts import Qwen3TTSModel
    todo = [l for l in langs if force or not os.path.exists("%s/i0_%s.wav" % (REF_DIR, l))]
    if not todo:
        return
    os.makedirs(REF_DIR, exist_ok=True)
    model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign", device_map="cuda:0", dtype=torch.bfloat16)
    for l in todo:
        instruct, seed = VOICES[l]["m0"]
        torch.manual_seed(seed)
        wavs, sr = model.generate_voice_design(text=REF_TEXT[l], instruct=instruct + INSTRUCT_EXTRA[l], language=LANGNAME[l], do_sample=True, temperature=0.6)
        x = trim(np.asarray(wavs[0], dtype=np.float32), sr)
        sf.write("%s/i0_%s.wav" % (REF_DIR, l), x, sr)
        print("Referenz", l, "%.1f s" % (len(x) / sr), flush=True)
    del model
    torch.cuda.empty_cache()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", default="")
    ap.add_argument("--only", default="", help="nur Schlüssel mit diesem Präfix, z. B. tut_ oder vid_")
    ap.add_argument("--new-ref", action="store_true")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--validate", action="store_true", help="jeden Clip per Spracherkennung prüfen, bei Abweichung mit neuem Seed wiederholen")
    ap.add_argument("--tries", type=int, default=6)
    ap.add_argument("--skip-existing", action="store_true")
    a = ap.parse_args()
    langs = [a.lang] if a.lang else ["de", "en"]
    make_refs(langs, a.new_ref)
    from qwen_tts import Qwen3TTSModel
    base = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-1.7B-Base", device_map="cuda:0", dtype=torch.bfloat16)
    lines = json.load(open("data/voice_lines.json"))["i0"]
    mp = OUT + "/manifest.json"
    man = json.load(open(mp))
    for l in langs:
        ref, sr0 = sf.read("%s/i0_%s.wav" % (REF_DIR, l))
        prompt = base.create_voice_clone_prompt(ref_audio=(ref.astype(np.float32), sr0), ref_text=REF_TEXT[l], x_vector_only_mode=False)
        for key, text in lines[l].items():
            if a.only and not key.startswith(a.only):
                continue
            dst = "%s/%s/i0_%s.ogg" % (OUT, l, key)
            if a.skip_existing and os.path.exists(dst):
                continue
            import voice_lang
            say = voice_lang.spoken(text, l)
            best = None
            for attempt in range(a.tries if a.validate else 1):
                torch.manual_seed(a.seed + len(key) + attempt * 13)
                wavs, sr = base.generate_voice_clone(text=say, language=LANGNAME[l], voice_clone_prompt=prompt, do_sample=True, temperature=0.6)
                x = trim(np.asarray(wavs[0], dtype=np.float32), sr)
                if not a.validate:
                    best = (1.0, x)
                    break
                ok, got, sim = voice_lang.check(x, sr, text, l, threshold=0.85)
                print("   Versuch %d: %s (%.2f) %r" % (attempt + 1, "ok" if ok else "verworfen", sim, got[:80]), flush=True)
                if best is None or sim > best[0]:
                    best = (sim, x)
                if ok:
                    break
            if best[0] < 0.85:
                print("SCHWACH %s/i0_%s (%.2f)" % (l, key, best[0]), flush=True)
            x = best[1]
            x = x / max(1e-6, np.abs(x).max()) * 0.85
            tmp = dst[:-4] + ".wav"
            sf.write(tmp, x, sr)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
            os.remove(tmp)
            man["clips"]["%s/i0_%s" % (l, key)] = {"text": text, "seconds": round(len(x) / sr, 2)}
            json.dump(man, open(mp, "w"), indent=1, ensure_ascii=False)
            print("%s/i0_%s: %.1fs (%d Zeichen)" % (l, key, len(x) / sr, len(text)), flush=True)
    man["clone"] = {"model": "Qwen/Qwen3-TTS-12Hz-1.7B-Base", "reference": "VoiceDesign m0 + Fluglehrer", "license": "Apache-2.0"}
    json.dump(man, open(mp, "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
