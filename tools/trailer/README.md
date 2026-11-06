# Trailer

Der Trailer (`docs/media/trailer_de.mp4`, `trailer_en.mp4`, 1080p60, rund 69 s) entsteht vollständig aus dem echten Spiel: Der Autopilot fliegt die Level,
Godots Movie Maker nimmt sie in 1920×1080 bei 60 Bildern pro Sekunde auf, ein Python-Kompositor schneidet, fährt die Kamera am Taxi entlang und legt Effekte darüber.
Ton: die Schichten des Spielthemas `t14` (132 BPM), dazu synthetische Riser, Einschläge, Kicks und die Spiel-Effekte und -Stimmen an den Stellen, an denen sie im Bild passieren.

## Ablauf

1. **Aufnahme.** Projektkopie mit der Taxi-Spur (siehe unten) und `gamescope --backend headless`, damit kein Fenster erscheint:
   ```bash
   godot --path . -w --resolution 1920x1080 --write-movie ~/.cache/gravifare-trailer/clips/n_s3_09.avi --fixed-fps 60 --quit-after 2400 \
         -- --lang=de --level=s3_09 --autopilot --seed=1 --no-hud --trace=~/.cache/gravifare-trailer/clips/n_s3_09.trace
   ```
   Benötigt werden `n_<level>` (ohne Bedienfeld) für `s1_01 s2_04 s3_04 s4_05 s5_04 s6_05 s7_03 s7_05 s8_03 s9_05 s9_10` (je 45 s, Stand der handgemachten Level; der Autopilot muss sie sauber fliegen), `h_s1_01 h_s3_04 h_s5_04` (mit Bedienfeld, 40 s)
   und `trans` (`--level=s1_01 --no-hud --debug-complete`, 14 s, enthält die Weltraumfahrt zwischen zwei Leveln).
2. **Bild.** `python3 tools/trailer/render.py de` (und `en`) rechnet die Zeitleiste aus `timeline.py` in Abschnitten parallel. Einzelbilder zur Kontrolle: `python3 tools/trailer/probe.py de bogen.png 1.5 5 12`.
3. **Ton und Verpackung.** `python3 tools/trailer/mux.py de` baut die Tonspur (`audio.py`, `sound.py`), normiert auf −15 LUFS und schreibt `docs/media/trailer_de.mp4` (H.264, CRF 24).

Voraussetzungen: `ffmpeg`, `gamescope`, Python 3 mit `numpy`, `scipy`, `pillow`.

Die Aufnahmen der aktuellen Fassung liegen in `~/.cache/gravifare-trailer/clips_v2` (Umgebungsvariable `GF_TRAILER_CLIPS` wählt einen anderen Ordner; `clips` enthält die der ersten Fassung). Die erste Fassung des Trailers liegt lokal unter `docs/media/alt/` (nicht im Repo).

## Taxi-Spur

Die Kamera folgt dem Taxi anhand einer Spur aus Bildschirmkoordinaten. Das Spiel schreibt sie nicht von sich aus; für die Aufnahme wird in der Projektkopie (nicht im Projekt) `src/game/game.gd` ergänzt:

```gdscript
var _trace_f: FileAccess = null
var _trace_init := false
func _trace_tick() -> void:
	if not _trace_init:
		_trace_init = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--trace="):
				_trace_f = FileAccess.open(a.substr(8), FileAccess.WRITE)
	if _trace_f == null or run == null:
		return
	var p: Vector2 = get_viewport().get_final_transform() * taxi.get_global_transform_with_canvas().origin
	_trace_f.store_line("%d %.1f %.1f %d %.1f %.1f %.2f" % [Engine.get_process_frames(), p.x, p.y, int(run.sim.state), run.sim.vel.x, run.sim.vel.y, run.sim.hull])
	_trace_f.flush()
```

und `_trace_tick()` als erste Zeile in `_process(delta)` aufgerufen. Spalten: Frame, x, y (Pixel), Zustand (0 fliegt, 1 gelandet, 2 zerstört), vx, vy, Hülle.
