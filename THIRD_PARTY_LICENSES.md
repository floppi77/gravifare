# Asset- und Lizenzinventar
| Asset | Herkunft | Lizenz | Modifikation | Export | Status |
|---|---|---|---|---|---|
| Godot Engine 4.7.2 | godotengine.org | MIT | – | Laufzeit | in Benutzung (Lizenztexte beim Export beilegen) |
| tiles_s1–s9, floppy_1–3, taxi, passengers, bg_s1_* | eigene Skripte `tools/art` | eigene Arbeit | – | ja | in Benutzung |
| Hintergrundbilder `bg_s1`–`bg_s9`, `bg_menu` (1920×1080, 10 Motive) | KI-generiert (Angabe des Entwicklers, 2026-11-01); Prompts/Exportdatum nicht archiviert | keine Lizenz, frei verwendbar (Angabe des Entwicklers, 2026-11-01) | Zuschnitt (Zoom 1,06), Abdunklung je Sektor, Parallax | ja | in Benutzung |
| `logo.png` (Hauptmenü-Logo) | KI-generiert (Angabe des Entwicklers, 2026-11-01); Prompts nicht archiviert | keine Lizenz, frei verwendbar (Angabe des Entwicklers, 2026-11-01) | Zuschnitt | ja | in Benutzung |
| Jersey 10 (Titel) | github.com/google/fonts (ofl/jersey10), © 2023 The Soft Type Project Authors | SIL OFL 1.1 (`assets/fonts/jersey10/OFL.txt`) | – | ja | in Benutzung |
| Oxanium (HUD, Menüs) | github.com/google/fonts (ofl/oxanium), © 2019 The Oxanium Project Authors | SIL OFL 1.1 (`assets/fonts/oxanium/OFL.txt`) | variabel, Gewicht 600 | ja | in Benutzung |
| Nunito (Untertitel, Funk-/Fließtext) | github.com/google/fonts (ofl/nunito), © 2014 The Nunito Project Authors | SIL OFL 1.1 (`assets/fonts/nunito/OFL.txt`) | variabel, Gewicht 600 | ja | in Benutzung |
| Silkscreen, Pixelify Sans | Google Fonts | OFL 1.1 | – | nein | **bewertet, nicht eingebunden** (Silkscreen: sehr klein und nur Versalien; Pixelify: breit) |
| Raumklang `amb_s1–s9` | eigene Synthese `tools/audio/gen_ambience.py` | eigene Arbeit | – | ja | in Benutzung |
| Musik (22 Themen × 3 Schichten, OGG, Klang von C64-SID und Amiga-Paula) | eigene Synthese und Komposition `tools/audio/gen_music.py`, `music_score.py`; alle Instrumente selbst erzeugt, keine Fremdsamples | eigene Arbeit | – | ja | in Benutzung |
| VSCO 2 CE / VCSL | GitHub sgossner | CC0-1.0 laut Repo (Unterbestände prüfen) | – | ja | **noch nicht eingebunden** |
| Qwen3-TTS-12Hz-1.7B-VoiceDesign (Entwicklungswerkzeug, nicht im Spiel) | huggingface.co/Qwen | Apache-2.0 (Modellkarte per API geprüft, 2026-10-30) | – | nur die erzeugten OGG-Clips `assets/audio/voice/` | in Benutzung |
| qwen-tts 0.1.1 (Python-Paket, Entwicklungswerkzeug) | PyPI | Apache-2.0 | – | nein | in Benutzung |
| Qwen3-TTS-12Hz-1.7B-Base (Stimmklon der synthetischen Fluglehrer-Referenz, `gen_voice_clone.py`) | huggingface.co/Qwen | Apache-2.0 laut Modellkarte – **vor Veröffentlichung nochmals prüfen**; Referenz stammt aus VoiceDesign (kein realer Sprecher) | – | nur erzeugte OGG-Clips und `assets/audio/voice/ref/*.wav` | in Benutzung |
| faster-whisper Modelle (Systran, lokal) | lokal vorhanden | MIT (nur Qualitätsprüfung der Clips) | – | nein | nur Entwicklung |
| Sprachclips (Fahrgäste, Tankwart, Funk-Zentrale; DE/EN) | eigene Erzeugung mit Qwen3-TTS | Ausgabe eines Apache-2.0-Modells; Modellkarte vor Veröffentlichung nochmals auf Nutzungshinweise prüfen | Trimmen, Normalisieren, OGG | ja | in Benutzung |
| Fish Audio Drama 3 (FP8; Entwicklungswerkzeug, nicht im Spiel) mit drama-rs 0.3.0 | fish.audio / huggingface.co/fishaudio | Fish Audio Community License 1.0 – Hinweis „Built with Fish Audio“ in README, Credits und `THIRD_PARTY_NOTICES.md`; erzeugte Clips gehören dem Erzeuger (IV(c)(iii)); kommerzielle Nutzung bis 500 000 USD Jahresumsatz erlaubt (III(a)), darüber eigene Vereinbarung | – | nur die erzeugten Clips: Tutorial `assets/audio/voice/*/i0_tut_*.ogg` und Fahrgäste `assets/audio/voice/*/{f2-f6,m2-m6}_*.ogg` (Stimmvorlagen: frei beschriebene Qwen3-TTS-VoiceDesign-Kunststimmen, `tools/audio/passenger_refs/`) | in Benutzung |
Keine Fremdassets ohne Eintrag hier.
