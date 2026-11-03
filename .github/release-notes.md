## Deutsch

### Download

| System | Datei | Hinweis |
|---|---|---|
| Windows | `GraviFare-<Version>-windows-x86_64.zip` | entpacken, `gravifare.exe` starten |
| Linux | `GraviFare-<Version>-linux-x86_64.zip` | entpacken, `gravifare.x86_64` starten (ggf. `chmod +x`) |
| macOS (Intel und Apple Silicon) | `GraviFare-<Version>-macos-universal.zip` | entpacken, `GraviFare.app` nach „Programme“ ziehen |

Die Pakete sind nicht signiert, die Mac-App nicht von Apple notarisiert; Windows warnt beim ersten Start (SmartScreen › „Weitere Informationen“ › „Trotzdem ausführen“). Beim ersten Start daher im
Finder Rechtsklick › „Öffnen“ wählen. Meldet macOS „beschädigt“, entfernt dieser Befehl im
Terminal nur die Download-Sperre:
`xattr -dr com.apple.quarantine /Applications/GraviFare.app`

### Downloads prüfen

Alle Dateien sind in der CI aus dem getaggten Stand gebaut worden.

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Zusätzlich gibt es einen signierten Herkunftsnachweis. Mit der
[GitHub CLI](https://cli.github.com) lässt sich prüfen, dass eine Datei wirklich von dieser
CI stammt:

```bash
gh attestation verify GraviFare-<version>-windows-x86_64.zip --repo floppi77/gravifare
```

Mehr dazu in [SECURITY.md](https://github.com/floppi77/gravifare/blob/main/SECURITY.md).

### Unterstützen

Gefällt dir GraviFare? Über einen Kaffee auf [Ko-fi](https://ko-fi.com/floppi77) freue ich mich.

### Lizenz

Frei für nicht-kommerzielle Zwecke: Code unter
[PolyForm Noncommercial 1.0.0](https://github.com/floppi77/gravifare/blob/main/LICENSE),
Inhalte unter [CC BY-NC-SA 4.0](https://github.com/floppi77/gravifare/blob/main/LICENSE-ASSETS.md).
Die Spieldateien enthalten die Godot Engine (MIT); die Fluglehrer-Stimme und zehn Fahrgaststimmen sind „Built with Fish Audio“, siehe
[THIRD_PARTY_NOTICES.md](https://github.com/floppi77/gravifare/blob/main/THIRD_PARTY_NOTICES.md).

Das Spiel spricht Deutsch und Englisch – umschalten per Flagge im Hauptmenü.


---

## English

### Download

| System | File | Note |
|---|---|---|
| Windows | `GraviFare-<version>-windows-x86_64.zip` | unzip, run `gravifare.exe` |
| Linux | `GraviFare-<version>-linux-x86_64.zip` | unzip, run `gravifare.x86_64` (`chmod +x` if needed) |
| macOS (Intel and Apple Silicon) | `GraviFare-<version>-macos-universal.zip` | unzip, drag `GraviFare.app` into “Applications” |

The packages are unsigned and the Mac app is not notarised by Apple; Windows warns on first launch (SmartScreen › “More info” › “Run anyway”). On first launch, right-click it in
the Finder › “Open”. If macOS reports it as “damaged”, this Terminal command removes only the
download quarantine flag:
`xattr -dr com.apple.quarantine /Applications/GraviFare.app`

The game speaks German and English – switch with the flags in the main menu.

### Verify downloads

All files were built by CI from the tagged source.

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

There is also a signed build provenance attestation. With the
[GitHub CLI](https://cli.github.com) you can check that a file really comes from this CI:

```bash
gh attestation verify GraviFare-<version>-windows-x86_64.zip --repo floppi77/gravifare
```

More in [SECURITY.md](https://github.com/floppi77/gravifare/blob/main/SECURITY.md).

### Support

Enjoying GraviFare? A coffee on [Ko-fi](https://ko-fi.com/floppi77) is much appreciated.

### Licence

Free for non-commercial use: code under
[PolyForm Noncommercial 1.0.0](https://github.com/floppi77/gravifare/blob/main/LICENSE),
content under [CC BY-NC-SA 4.0](https://github.com/floppi77/gravifare/blob/main/LICENSE-ASSETS.md).
The game files contain the Godot Engine (MIT); the flight instructor and ten passenger voices are “Built with Fish Audio”, see
[THIRD_PARTY_NOTICES.md](https://github.com/floppi77/gravifare/blob/main/THIRD_PARTY_NOTICES.md).
