"""Erzeugt die Referenzaufnahmen der zehn zusätzlichen Fahrgast-Stimmen (tools/audio/passenger_voices.py) mit Qwen3-TTS VoiceDesign (Apache-2.0).
Sie dienen nur als Stimmvorlage für Drama 3 und liegen als kleine OGG-Dateien in tools/audio/passenger_refs/<sprache>/<stimme>.ogg (nicht im Spiel).
Aufruf (Projektwurzel, Qwen-Umgebung wie in gen_voice.py):  .venv/tts/bin/python tools/audio/gen_passenger_refs.py [--only f2] [--force]"""
import argparse, os, subprocess, sys
import numpy as np, soundfile as sf, torch

sys.path.insert(0, "tools/audio")
from passenger_voices import VOICES, REF_TEXT, LANGNAME, TARGET_F0

DEST = "tools/audio/passenger_refs"
MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"


def trim(x, sr):
    idx = np.where(np.abs(x) > np.abs(x).max() * 0.02)[0]
    return x[max(0, idx[0] - int(0.05 * sr)): idx[-1] + int(0.25 * sr)]


def median_f0(x, sr):
    import librosa
    y = librosa.resample(x, orig_sr=sr, target_sr=16000)
    f0, voiced, _ = librosa.pyin(y, fmin=60, fmax=450, sr=16000)
    f0 = f0[voiced & ~np.isnan(f0)]
    return float(np.median(f0)) if len(f0) > 5 else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=""); ap.add_argument("--tries", type=int, default=8); ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    from qwen_tts import Qwen3TTSModel
    model = Qwen3TTSModel.from_pretrained(MODEL, device_map="cuda:0", dtype=torch.bfloat16)
    for vk, per in VOICES.items():
        if a.only and a.only != vk:
            continue
        for lang, (instruct, seed) in per.items():
            dst = f"{DEST}/{lang}/{vk}.ogg"
            if os.path.exists(dst) and not a.force:
                continue
            os.makedirs(f"{DEST}/{lang}", exist_ok=True)
            lo, hi = TARGET_F0[vk]
            best = None            # (Abstand zum Zielbereich, Signal, Abtastrate, Tonlage)
            for k in range(a.tries):
                torch.manual_seed(seed + 17 * k)
                wavs, sr = model.generate_voice_design(text=REF_TEXT[lang], instruct=instruct, language=LANGNAME[lang], do_sample=True, temperature=0.6)
                cand = trim(np.asarray(wavs[0], dtype=np.float32), sr)
                f = median_f0(cand, sr)
                miss = 0.0 if lo <= f <= hi else min(abs(f - lo), abs(f - hi))
                if best is None or miss < best[0]:
                    best = (miss, cand, sr, f)
                if miss == 0.0:
                    break
            _, x, sr, f = best
            x = x / max(1e-6, np.abs(x).max()) * 0.85
            tmp = dst[:-4] + ".wav"
            sf.write(tmp, x, sr)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", dst], check=True)
            os.remove(tmp)
            print(f"{lang}/{vk}: {len(x) / sr:.1f} s, {f:.0f} Hz (Ziel {lo}-{hi})", flush=True)


if __name__ == "__main__":
    main()
