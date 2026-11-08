# Trailer

Der Trailer (`docs/media/trailer_de.mp4`, `trailer_en.mp4`, 1080p60, rund 76 s) entsteht vollständig aus dem echten Spiel: Der Autopilot fliegt die Level,
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
   Dazu `n_s5_01` (Hitze), `f_s9_05` (Start mit 17 % Sprit über `GF_FUEL`, 25 s, Tanken) sowie `ws` (Werkstatt, 15 s) und `ed` (Level-Editor, 12 s).
   Alle Aufnahmen gibt es je Sprache (englische mit `en_`, bei Bedienfeld `h_en_`).
   `ws` und `ed` sind eigene Szenen der Aufnahmekopie (Aufruf mit `res://ws_trailer.tscn` bzw. `res://ed_trailer.tscn` statt `--level`):
   - `ws_trailer.gd`: öffnet `WorkshopBay` (Sektor 3, ¢ 16000, Ausbau Düsen 1, Hülle 0, Fahrwerk 1); nach dem Öffnen der Tafel (Frame 130)
     wandert der Fokus über die Einbauten, gekauft werden Düsen (Frame 240) und Hülle (Frame 350). Die Zeiten stehen in `timeline.py` (`WS_SHOP`, `WS_BUYS`).
   - `ed_trailer.gd`: öffnet den Level-Editor und baut Strich für Strich ein Level (Rechteck-Striche über `_begin`/`_move_stroke`/`_end_stroke`,
     danach Magnet, Strahl, Trümmer, Strömung über `model.add_object`). Strichanfänge: `ED_STROKES` in `timeline.py`.
   Außerdem in der Kopie: ein Autoload, der Gamepad-Ereignisse aus der InputMap entfernt (Godot liest Controller systemweit), und in `game.gd`
   nach `run.start(...)` `if OS.get_environment("GF_FUEL") != "": run.sim.fuel = float(...)`.
2. **Bild.** `python3 tools/trailer/render.py de` (und `en`) rechnet die Zeitleiste aus `timeline.py` in Abschnitten parallel. Einzelbilder zur Kontrolle: `python3 tools/trailer/probe.py de bogen.png 1.5 5 12`.
3. **Ton und Verpackung.** `python3 tools/trailer/mux.py de` baut die Tonspur (`audio.py`, `sound.py`), normiert auf −15 LUFS und schreibt `docs/media/trailer_de.mp4` (H.264, CRF 24).

Voraussetzungen: `ffmpeg`, `gamescope`, Python 3 mit `numpy`, `scipy`, `pillow`.

Die Aufnahmen der aktuellen Fassung (Grafik ab 0.9.11, mit Werkstatt und Editor) liegen in `~/.cache/gravifare-trailer/clips_v3` (Umgebungsvariable `GF_TRAILER_CLIPS` wählt einen anderen Ordner; `clips_v2` und `clips` enthalten die der früheren Fassungen). Die erste Fassung des Trailers liegt lokal unter `docs/media/alt/` (nicht im Repo).

## Aufnahmekopie

`tools/trailer/rec/` enthält die Teile für die Projektkopie: `ws_trailer.*` und `ed_trailer.*` (an die Wurzel der Kopie), `no_pad.gd`
(nach `src/core/`, als letzter Autoload `NoPad` eintragen), `rec_one.sh` (eine Aufnahme, `GF_REC_SP` = Ordner, der die Kopie als `rec/` enthält)
und `jobs.txt` (alle 38 Aufnahmen: `cat jobs.txt | xargs -P 3 -L 1 ./rec_one.sh`). Der Ordner hat eine `.gdignore`, im Projekt selbst werden die Szenen nicht geladen.

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
	_trace_f.store_line("%d %.1f %.1f %d %.1f %.1f %.2f %.1f %d %d" % [Engine.get_process_frames(), p.x, p.y, int(run.sim.state), run.sim.vel.x, run.sim.vel.y, run.sim.hull, run.sim.fuel, int(run.exit_open), int(run.refuel_tick)])
	_trace_f.flush()
```

und `_trace_tick()` als erste Zeile in `_process(delta)` aufgerufen. Spalten: Frame, x, y (Pixel), Zustand (0 fliegt, 1 gelandet, 2 zerstört), vx, vy, Hülle, Sprit, Ausgang offen (0/1), tankt gerade (0/1).
Die festen Quellzeiten in `timeline.py` (Tor offen, Hitze, Verkehr, Strahl …) gelten für diese Aufnahmen; nach einer Neuaufnahme mit `probe.py` prüfen.
