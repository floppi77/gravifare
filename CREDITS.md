# CREDITS
Spielidee: floppi. Alle 99 Level hat floppi von Hand gebaut und selbst durchgeflogen. Eigenentwicklung: Code und generierte Pixel-Art (`tools/art/`). Entwickelt mit Claude Code.
Eingebunden sind Schriften (OFL), lokal erzeugte Sprachausgabe und KI-generierte Hintergrundbilder (Angabe des Entwicklers) – Herkunft und Lizenzen siehe THIRD_PARTY_LICENSES.md. Geplant: Instrumentensamples (CC0).
Das Logo (`logo.png`) ist ebenfalls KI-generiert. Bilder und Logo sind laut Entwickler frei verwendbar und stehen unter keiner Lizenz.

**Sprachausgabe:** Stimmen mit Qwen3-TTS-12Hz-1.7B-VoiceDesign (Alibaba/Qwen, Apache-2.0) offline erzeugt; die Stimmen sind frei beschriebene Kunststimmen, keine Nachahmung realer Personen. Die Stimme des Fluglehrers im Tutorial und zehn weitere Fahrgaststimmen (je fünf weibliche und männliche, jeweils Deutsch und Englisch) wurden mit Fish Audio Drama 3 erzeugt – **Built with Fish Audio** (Fish Audio Community License). Als Stimmvorlage dienen frei beschriebene Kunststimmen aus Qwen3-TTS.

**Schriften:** Jersey 10, Oxanium, Nunito (SIL OFL 1.1). **Musik und Klänge:** komplett eigene Synthese. **Credits im Spiel:** Hauptmenü → Credits.

**Seit Runde 58–63 (eigene Arbeit, keine Fremdassets):** Taxi und Verkehrsfahrzeug in 78×48, Scheinwerfer-Symbol der Werkstatt (Aseprite über den MCP, Quellen in `tools/art/aseprite/`), Aufkleber in Taxigröße und Fels-Materialien der neun Sektoren (per Code, `tools/art/gen_art.py`, `tools/art/gen_sector_tiles.py`). Neue Sprachclips: Fluglehrer `tut_refuel`, `tut_credit` (Fish Audio Drama 3, **Built with Fish Audio**), Einspieler `vid_vip`, `vid_emergency` (Qwen3-TTS-Klon, Apache-2.0).

**Seit Runde 68 (eigene Arbeit, keine Fremdassets):** Hintergründe des Zwischenflugs je Sektor (`assets/art/transit/`): Motive als per Skript gebaute Blender-Szenen (Cycles), Schwarzes Loch per eigener Strahlverfolgung, Nebel und Pixelstil in Python (`tools/art/transit/`). Sie sind nicht KI-generiert.
