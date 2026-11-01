"""Gleicht die Lautheit der Sprachclips an: Clips außerhalb von -20…-16 LUFS werden auf -18 LUFS gezogen (lineare Verstärkung, Spitzen bis -1 dBFS).
Sehr kurze Clips ohne verlässlichen Messwert bleiben unverändert. Aufruf: python3 tools/audio/level_voice.py"""
import glob, os, re, subprocess
from concurrent.futures import ThreadPoolExecutor

def measure(f):
    r = subprocess.run(["ffmpeg", "-nostats", "-hide_banner", "-i", f, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", r)
    p = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", r)
    return f, float(i[-1]) if i else -70.0, float(p[-1]) if p else 0.0

files = sorted(glob.glob("assets/audio/voice/de/*.ogg") + glob.glob("assets/audio/voice/en/*.ogg"))
with ThreadPoolExecutor(os.cpu_count()) as ex:
    res = list(ex.map(measure, files))
done = 0
for f, lufs, peak in res:
    if lufs < -60.0 or -20.0 <= lufs <= -16.0:
        continue
    gain = min(-18.0 - lufs, -1.0 - peak)
    if abs(gain) < 0.5:
        continue
    tmp = f[:-4] + ".tmp.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f, "-af", "volume=%.2fdB" % gain, "-c:a", "libvorbis", "-q:a", "5", tmp], check=True)
    os.replace(tmp, f)
    done += 1
vals = [l for _, l, _ in res if l > -60.0]
print("%d Clips, %d angeglichen; vorher %.1f…%.1f LUFS" % (len(res), done, min(vals), max(vals)))
