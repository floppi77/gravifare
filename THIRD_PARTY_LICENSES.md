# Asset- und Lizenzinventar
| Asset | Herkunft | Lizenz | Modifikation | Export | Status |
|---|---|---|---|---|---|
| Godot Engine 4.7.2 | godotengine.org | MIT | – | Laufzeit | in Benutzung (Lizenztexte beim Export beilegen) |
| tiles_s1–s9, floppy_1–3, taxi, passengers, bg_s1_* | eigene Skripte `tools/art` | eigene Arbeit | – | ja | in Benutzung |
| Hintergrundbilder `bg_s1`–`bg_s9`, `bg_menu` (1920×1080, 10 Motive) | KI-generiert mit „ChatGPT Astra 6.0“ (Angabe des Entwicklers, 2026-11-01); Prompts/Exportdatum nicht archiviert | Nutzungsrechte nach den Nutzungsbedingungen des Anbieters – **vor Veröffentlichung prüfen**: kommerzielle Nutzung, Rechtslage und Schutzfähigkeit KI-generierter Bilder, ggf. Kennzeichnung | Zuschnitt (Zoom 1,06), Abdunklung je Sektor, Parallax | ja | in Benutzung, **Rechteprüfung offen** |
| `logo.png` (Hauptmenü-Logo) | KI-generiert mit „ChatGPT Astra 6.0“ (Angabe des Entwicklers, 2026-11-01); Prompts nicht archiviert | Nutzungsrechte nach den Nutzungsbedingungen des Anbieters – **vor Veröffentlichung prüfen** | Zuschnitt | ja | in Benutzung, **Rechteprüfung offen** |
| Jersey 10 (Titel) | github.com/google/fonts (ofl/jersey10), © 2023 The Soft Type Project Authors | SIL OFL 1.1 (`assets/fonts/jersey10/OFL.txt`) | – | ja | in Benutzung |
| Oxanium (HUD, Menüs) | github.com/google/fonts (ofl/oxanium), © 2019 The Oxanium Project Authors | SIL OFL 1.1 (`assets/fonts/oxanium/OFL.txt`) | variabel, Gewicht 600 | ja | in Benutzung |
| Nunito (Untertitel, Funk-/Fließtext) | github.com/google/fonts (ofl/nunito), © 2014 The Nunito Project Authors | SIL OFL 1.1 (`assets/fonts/nunito/OFL.txt`) | variabel, Gewicht 600 | ja | in Benutzung |
| Silkscreen, Pixelify Sans | Google Fonts | OFL 1.1 | – | nein | **bewertet, nicht eingebunden** (Silkscreen: sehr klein und nur Versalien; Pixelify: breit) |
| Raumklang `amb_s1–s9` | eigene Synthese `tools/audio/gen_ambience.py` | eigene Arbeit | – | ja | in Benutzung |
| Musik (21 Themen × 3 Schichten, OGG, SID-Klang) | eigene Synthese `tools/audio/gen_music_sid.py` | eigene Arbeit | – | ja | in Benutzung |
| VSCO 2 CE / VCSL | GitHub sgossner | CC0-1.0 laut Repo (Unterbestände prüfen) | – | ja | **noch nicht eingebunden** |
| Qwen3-TTS-12Hz-1.7B-VoiceDesign (Entwicklungswerkzeug, nicht im Spiel) | huggingface.co/Qwen | Apache-2.0 (Modellkarte per API geprüft, 2026-10-30) | – | nur die erzeugten OGG-Clips `assets/audio/voice/` | in Benutzung |
| qwen-tts 0.1.1 (Python-Paket, Entwicklungswerkzeug) | PyPI | Apache-2.0 | – | nein | in Benutzung |
| Qwen3-TTS-12Hz-1.7B-Base (Stimmklon der synthetischen Fluglehrer-Referenz, `gen_voice_clone.py`) | huggingface.co/Qwen | Apache-2.0 laut Modellkarte – **vor Veröffentlichung nochmals prüfen**; Referenz stammt aus VoiceDesign (kein realer Sprecher) | – | nur erzeugte OGG-Clips und `assets/audio/voice/ref/*.wav` | in Benutzung |
| faster-whisper Modelle (Systran, lokal) | lokal vorhanden | MIT (nur Qualitätsprüfung der Clips) | – | nein | nur Entwicklung |
| Sprachclips (Fahrgäste, Tankwart, Funk-Zentrale; DE/EN) | eigene Erzeugung mit Qwen3-TTS | Ausgabe eines Apache-2.0-Modells; Modellkarte vor Veröffentlichung nochmals auf Nutzungshinweise prüfen | Trimmen, Normalisieren, OGG | ja | in Benutzung |
Keine Fremdassets ohne Eintrag hier.
