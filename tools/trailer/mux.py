#!/usr/bin/env python3
"""Tonspur bauen und mit dem gerenderten Video zu docs/media/trailer_<lang>.mp4 verbinden: python3 tools/trailer/mux.py <de|en>"""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(__file__))
import engine, timeline, audio, sound

lang = sys.argv[1]
OUT = os.path.expanduser("~/.cache/gravifare-trailer/out")
engine.CLIPS = os.path.expanduser(os.environ.get("GF_TRAILER_CLIPS", "~/.cache/gravifare-trailer/clips_v2"))
tl = timeline.build(lang)
y = audio.build(lang, tl)
wav = f"{OUT}/{lang}/audio.wav"
sound.save(wav, y)
dest = os.path.join(audio.ROOT, "docs", "media", f"trailer_{lang}.mp4")
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", f"{OUT}/{lang}/video.mp4", "-i", wav, "-map", "0:v", "-map", "1:a", "-t", f"{tl.total:.3f}",
                "-c:v", "libx264", "-preset", "slow", "-tune", "animation", "-crf", "24", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-af", "loudnorm=I=-15:TP=-1.5:LRA=10", "-ar", "48000", "-c:a", "aac", "-b:a", "224k", dest], check=True)
print(dest, os.path.getsize(dest) // 1024, "KiB")
