# Hintergrundbilder – Vorgaben für externe Erstellung

**Anzahl:** 9 Sektoren × 3 Ebenen = **27 Bilder** (Sektor 1 liegt vor; für Sektor 2–9 stehen 24 selbst erzeugte Platzhalter in `assets/art/`, die du ersetzen kannst).

| Datei | Ebene | Format | Inhalt |
|---|---|---|---|
| `bg_sN_far.png` | fern | **1920 × 1080**, PNG, **deckend** (kein Alpha) | Himmel, Nebel, Sterne, großes Fernobjekt (Planet, Sonne, Schwarzes Loch …) |
| `bg_sN_mid.png` | mittel | **1920 × 1080**, PNG, **mit Alpha** | Silhouetten im unteren Drittel (Gebäude, Gerüste, Trümmer …), sonst transparent |
| `bg_sN_near.png` | nah | **1920 × 1080**, PNG, **mit Alpha** | größere, dunklere Silhouetten ganz unten (Rohre, Masten, Wracks …), sonst transparent |

`N` = 1…9 (Sektor). Zielordner: `assets/art/` (gleiche Dateinamen überschreiben die Platzhalter, danach einmal `godot --headless --import`).

## Technische Hinweise
- Das Spiel rechnet logisch in **640 × 360** und skaliert ganzzahlig auf 1080p (Faktor 3). Die Bilder haben deshalb **1920 × 1080 = 3 × 640 × 360**. Wer 4K-Schärfe will, kann auch **3840 × 2160** liefern (gleiches Seitenverhältnis, wird einfach skaliert).
- **Pixel-Art-Look** passt am besten (harte Kanten, keine Weichzeichnung, begrenzte Palette, leichtes Dithering); im Spiel wird ohne Glättung skaliert.
- `mid` und `near` werden nebeneinander gekachelt (Versatz ±640 logische Pixel): **linker und rechter Rand müssen nahtlos aneinanderpassen**. `far` wird einmal gezeichnet und muss nicht kacheln.
- Parallax ist gering (mittlere Ebene 8 %, nahe Ebene 18 % der Kamerabewegung); die Level füllen den Bildschirm, die Kamera bewegt sich nur leicht.
- **Lesbarkeit des Spiels geht vor:** Plattformen, Hindernisse und Fahrgäste liegen im Bereich **y ≈ 5 % … 95 %** und werden in Cyan/Orange/Gelb/Rosa gezeichnet. Hintergründe bitte eher **dunkel bis mittel**, Kontrast in der Bildmitte niedrig, helle Akzente nur sparsam; keine feinen hellen Muster in Cyan/Orange/Gelb direkt hinter dem Spielfeld.
- Der obere Rand (16 px logisch = 48 px im Bild) und der untere Rand (ca. 24 px logisch = 72 px im Bild) sind HUD-Streifen; dort darf nichts Wichtiges liegen.
- Dateigröße: `far` gern bis ~1 MB, `mid`/`near` meist deutlich kleiner.

## Stimmungen je Sektor
1. **Sternenhafen** – Raumhafenstadt bei Nacht, Ringplanet (vorhanden)
2. **Neon-Schluchten** – Neonstadt, magenta/cyan, Gitterhorizont
3. **Schrottgürtel** – Asteroiden- und Schrottfeld, bräunlich, Gasriese
4. **Magnetfeld** – Polarlicht-Bänder, Feldlinien, blau/grün
5. **Solarschmiede** – glühende Sonne, Schmelz- und Schmiedeanlagen, orange/rot
6. **Gezeitenorbit** – Wasserwelt mit Mond, Orbitringe, blau
7. **Transitknoten** – Raumstation, Verkehrsbahnen aus Licht, graublau
8. **Schattenring** – dunkler Planet mit Schattenring, Sensormasten, fast schwarz/violett
9. **Singularitätsrand** – Schwarzes Loch mit Akkretionsscheibe, Gravitationslinsen, sehr dunkel
