# Steam-Erfolge (Vorbereitung)

Stand: Runde 80 (2026-11-18). Ein Steam-Auftritt ist **nicht** geplant; dies ist nur die Vorbereitung, damit er später ohne Umbau möglich ist.

## Wie es funktioniert

- Quelle der Erfolge bleibt das Spiel selbst (`src/core/achievements.gd`, abgeleitet aus dem Spielstand). Sie funktionieren ohne Steam unverändert.
- `src/core/steam_bridge.gd` meldet bei jedem Abgleich (`Save.sync_achievements`) alle erreichten Erfolge zusätzlich an Steam – **nur**, wenn GodotSteam
  (GDExtension, Engine-Singleton `Steam`) eingebunden ist und `steamInitEx()` erfolgreich war. Ohne GodotSteam tut die Brücke nichts.
- Weil alle erreichten Erfolge gemeldet werden, kommen auch früher (ohne Steam) erreichte bei der ersten Steam-Sitzung nach; jede Id höchstens einmal je Sitzung.
- Nicht gewertet (wie im Spiel): Debug-Modus, Entwicklerschalter, Community-Level.

## Für einen späteren Steam-Release

1. GodotSteam (GDExtension, passend zu Godot 4.7) als Addon einbinden; Lizenz MIT – in THIRD_PARTY_LICENSES.md aufnehmen.
2. In Steamworks die 41 Erfolge mit den API-Namen unten anlegen (Name/Beschreibung DE und EN; FR/ES stehen in `data/i18n/fr.json`/`es.json`).
3. Symbole hochladen: `docs/steam/icons/` (64×64 PNG, erreicht und gesperrt). Neu erzeugen mit
   `godot --path . -- --scene=achievements_view --export-ach-icons=<Ordner>` (braucht ein Fenster bzw. `gamescope --backend headless`).
4. `steam_appid.txt` nur für lokale Tests neben die ausführbare Datei legen (nicht ausliefern).

## Liste

| API-Name | Deutsch | Englisch | Beschreibung (EN) | Symbole |
|---|---|---|---|---|
| `ACH_FIRST_FARE` | Erste Fahrt | First fare | Deliver your first passenger | `icons/ACH_FIRST_FARE.png`, `icons/ACH_FIRST_FARE_locked.png` |
| `ACH_FARES_100` | Stammkundschaft | Regulars | Deliver 100 passengers | `icons/ACH_FARES_100.png`, `icons/ACH_FARES_100_locked.png` |
| `ACH_FARES_500` | Taxi-Legende | Taxi legend | Deliver 500 passengers | `icons/ACH_FARES_500.png`, `icons/ACH_FARES_500_locked.png` |
| `ACH_SECTOR_1` | Erster Sektor | First sector | Complete every level of sector 1 | `icons/ACH_SECTOR_1.png`, `icons/ACH_SECTOR_1_locked.png` |
| `ACH_SECTOR_5` | Halbzeit | Halfway there | Complete sectors 1 to 5 | `icons/ACH_SECTOR_5.png`, `icons/ACH_SECTOR_5_locked.png` |
| `ACH_ALL_LEVELS` | Alles gesehen | Seen it all | Complete all 99 levels | `icons/ACH_ALL_LEVELS.png`, `icons/ACH_ALL_LEVELS_locked.png` |
| `ACH_CAREER_DONE` | Feierabend | Clocking off | Fly the career all the way to the finale | `icons/ACH_CAREER_DONE.png`, `icons/ACH_CAREER_DONE_locked.png` |
| `ACH_TRIPLE` | Dreifach | Triple | All three medals in one level | `icons/ACH_TRIPLE.png`, `icons/ACH_TRIPLE_locked.png` |
| `ACH_MEDALS_50` | Medaillensammler | Medal collector | Win 50 medals | `icons/ACH_MEDALS_50.png`, `icons/ACH_MEDALS_50_locked.png` |
| `ACH_SECTOR_GOLD` | Vergoldeter Sektor | Golden sector | Every medal of an entire sector | `icons/ACH_SECTOR_GOLD.png`, `icons/ACH_SECTOR_GOLD_locked.png` |
| `ACH_MEDALS_ALL` | Makellos | Flawless | Win all 297 medals | `icons/ACH_MEDALS_ALL.png`, `icons/ACH_MEDALS_ALL_locked.png` |
| `ACH_PERFECT_25` | Sanft aufgesetzt | Soft touch | 25 perfect landings | `icons/ACH_PERFECT_25.png`, `icons/ACH_PERFECT_25_locked.png` |
| `ACH_PERFECT_250` | Federleicht | Light as a feather | 250 perfect landings | `icons/ACH_PERFECT_250.png`, `icons/ACH_PERFECT_250_locked.png` |
| `ACH_STREAK_10` | In Serie | On a roll | 10 perfect landings in a row | `icons/ACH_STREAK_10.png`, `icons/ACH_STREAK_10_locked.png` |
| `ACH_CREDITS_10K` | Gutes Trinkgeld | Good tips | Earn ¢10.000 in fares | `icons/ACH_CREDITS_10K.png`, `icons/ACH_CREDITS_10K_locked.png` |
| `ACH_CREDITS_100K` | Großverdiener | Big earner | Earn ¢100.000 in fares | `icons/ACH_CREDITS_100K.png`, `icons/ACH_CREDITS_100K_locked.png` |
| `ACH_SHIFT_DONE` | Nachtschwärmer | Night owl | Fly a night shift to the end | `icons/ACH_SHIFT_DONE.png`, `icons/ACH_SHIFT_DONE_locked.png` |
| `ACH_SHIFT_S` | Bestnote | Top grade | Finish a night shift with grade S | `icons/ACH_SHIFT_S.png`, `icons/ACH_SHIFT_S_locked.png` |
| `ACH_DAY_GOLD` | Tagesgold | Daily gold | Gold in the day shift goal | `icons/ACH_DAY_GOLD.png`, `icons/ACH_DAY_GOLD_locked.png` |
| `ACH_DAY_STREAK_7` | Eine Woche am Steuer | A week at the wheel | Fly the day shift 7 days in a row | `icons/ACH_DAY_STREAK_7.png`, `icons/ACH_DAY_STREAK_7_locked.png` |
| `ACH_WORKSHOP_MAX` | Voll ausgebaut | Fully upgraded | Bring one workshop upgrade to its top level | `icons/ACH_WORKSHOP_MAX.png`, `icons/ACH_WORKSHOP_MAX_locked.png` |
| `ACH_NEW_LOOK` | Neuer Anstrich | Fresh coat | Change paint or sticker in the garage | `icons/ACH_NEW_LOOK.png`, `icons/ACH_NEW_LOOK_locked.png` |
| `ACH_PUMP_BOOM` | Funkenflug | Sparks fly | Blow up a fuel pump | `icons/ACH_PUMP_BOOM.png`, `icons/ACH_PUMP_BOOM_locked.png` |
| `ACH_CRASHES_50` | Stehaufmännchen | Bounce back | Survive 50 crashes | `icons/ACH_CRASHES_50.png`, `icons/ACH_CRASHES_50_locked.png` |
| `ACH_COMMUNITY` | Gemeinschaftsgeist | Community spirit | Complete a community level | `icons/ACH_COMMUNITY.png`, `icons/ACH_COMMUNITY_locked.png` |
| `ACH_HOURS_10` | Dauerschicht | Long haul | Play for 10 hours | `icons/ACH_HOURS_10.png`, `icons/ACH_HOURS_10_locked.png` |
| `ACH_EGGS_20` | *versteckt* | *hidden* | in Steamworks als „Hidden“ anlegen; Texte: `ACH_EGGS_20` / `ACH_EGGS_20_D` in `data/i18n` | `icons/ACH_EGGS_20.png`, `icons/ACH_EGGS_20_locked.png` |
| `ACH_DAY_NIKOLAUS` | *versteckt* | *hidden* | in Steamworks als „Hidden“ anlegen; Texte: `ACH_DAY_NIKOLAUS` / `ACH_DAY_NIKOLAUS_D` in `data/i18n` | `icons/ACH_DAY_NIKOLAUS.png`, `icons/ACH_DAY_NIKOLAUS_locked.png` |
| `ACH_DAY_XMAS` | *versteckt* | *hidden* | in Steamworks als „Hidden“ anlegen; Texte: `ACH_DAY_XMAS` / `ACH_DAY_XMAS_D` in `data/i18n` | `icons/ACH_DAY_XMAS.png`, `icons/ACH_DAY_XMAS_locked.png` |
| `ACH_DAY_SILVESTER` | *versteckt* | *hidden* | in Steamworks als „Hidden“ anlegen; Texte: `ACH_DAY_SILVESTER` / `ACH_DAY_SILVESTER_D` in `data/i18n` | `icons/ACH_DAY_SILVESTER.png`, `icons/ACH_DAY_SILVESTER_locked.png` |
| `ACH_DAY_VALENTINE` | *versteckt* | *hidden* | in Steamworks als „Hidden“ anlegen; Texte: `ACH_DAY_VALENTINE` / `ACH_DAY_VALENTINE_D` in `data/i18n` | `icons/ACH_DAY_VALENTINE.png`, `icons/ACH_DAY_VALENTINE_locked.png` |
| `ACH_OT_FIRST` | Überstunden | Overtime | Finish an overtime run | `icons/ACH_OT_FIRST.png`, `icons/ACH_OT_FIRST_locked.png` |
| `ACH_OT_SHORT` | Kurz und knackig | Short and sweet | Complete a short overtime run | `icons/ACH_OT_SHORT.png`, `icons/ACH_OT_SHORT_locked.png` |
| `ACH_OT_MEDIUM` | Durchgehalten | Stayed the course | Complete a medium overtime run | `icons/ACH_OT_MEDIUM.png`, `icons/ACH_OT_MEDIUM_locked.png` |
| `ACH_OT_LONG` | Marathonschicht | Marathon shift | Complete a long overtime run | `icons/ACH_OT_LONG.png`, `icons/ACH_OT_LONG_locked.png` |
| `ACH_OT_STAGE5` | Unermüdlich | Tireless | Complete an overtime run at overtime level 5 or higher | `icons/ACH_OT_STAGE5.png`, `icons/ACH_OT_STAGE5_locked.png` |
| `ACH_OT_RANK10` | Oberdisponent | Head dispatcher | Reach rank 10 | `icons/ACH_OT_RANK10.png`, `icons/ACH_OT_RANK10_locked.png` |
| `ACH_OT_PACTS3` | Teufelspakt | Devil’s bargain | Complete an overtime run with 3 pacts | `icons/ACH_OT_PACTS3.png`, `icons/ACH_OT_PACTS3_locked.png` |
| `ACH_OT_SCORE` | Rekordschicht | Record shift | Score 100000 points in one overtime run | `icons/ACH_OT_SCORE.png`, `icons/ACH_OT_SCORE_locked.png` |
| `ACH_OT_LICENSES` | Lizenzsammler | License collector | Complete an overtime run with each of the 6 licenses | `icons/ACH_OT_LICENSES.png`, `icons/ACH_OT_LICENSES_locked.png` |
| `ACH_ALL_DONE` | Taxi-Ikone | Taxi icon | Unlock all 40 other achievements | `icons/ACH_ALL_DONE.png`, `icons/ACH_ALL_DONE_locked.png` |
