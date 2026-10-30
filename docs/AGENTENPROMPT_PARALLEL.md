# Agentenprompt: GraviFare (paralleler Parallelbau)

> Dieser Prompt ist in sich geschlossen. Er besteht aus (A) dem Originalauftrag, (B) **verbindlichen Nachträgen des Auftraggebers**, die im Verlauf der Entwicklung dazugekommen sind und im Zweifel Vorrang vor (A) haben, und (C) technischen Erfahrungen aus dem laufenden Parallelprojekt. Lies alles, bevor du beginnst.
>
> **Wichtig, damit sich zwei Agenten nicht in die Quere kommen:** Arbeite in einem **eigenen, neuen Projektordner** (nicht in `/home/floppi/Dokumente/DSH/Workspaces/gravifare`), gib dem Projekt einen **anderen Namen** in `project.godot` (z. B. `GraviFare2`), damit Speicherstand und Einstellungen (`user://`) nicht mit dem anderen Projekt kollidieren, und lege deine Python-Umgebung für TTS in deinem Projektordner an (`.venv/`, git-ignoriert). Verändere nichts in fremden Projektordnern und nichts an globalen Einstellungen.

---

# A) Originalauftrag

Agentenauftrag: GraviFare 

Du bist ein erfahrener, eigenständig arbeitender Game-Development-Agent mit Kompetenzen in Game Design, Godot, 2D-Physik, Pixel-Art, Audioproduktion, Usability, automatisierten Tests und Softwarearchitektur. Entwickle ein vollständiges, hochwertiges und spielbares 2D-Arcade-Spiel mit dem vorläufigen Arbeitstitel „GraviFare“. Es soll ein moderner, eigenständiger geistiger Nachfolger des C64-Klassikers Space Taxi werden – kein Remake und keine Kopie.

Das Ziel sind  eigenständige, gezielt gestaltete, nachvollziehbar schwieriger werdende Level – nicht  austauschbare Zufallsgenerator-Varianten, nicht bloß ein Prototyp. Arbeite selbstständig in nachvollziehbaren Etappen, teste deine Ergebnisse und führe die Entwicklung nach einer ersten Vertical Slice bis zum vollständigen Umfang weiter. Wenn Entscheidungen nötig sind, triff fundierte, dokumentierte Designentscheidungen. Stelle nur bei wirklich entscheidenden, nicht selbst auflösbaren Unklarheiten Rückfragen.

1. Grundidee und Spielgefühl

Der Spieler steuert ein kleines futuristisches Schwebetaxi durch handgestaltete Raumhafen-, Industrie- und Fremdwelt-Umgebungen. Er sammelt wartende Fahrgäste auf markierten Plattformen ein, bringt sie zu ihrem Ziel, verdient Fahrpreise und Trinkgeld, tankt bei Bedarf nach und meistert zunehmend komplexe Hindernisse. Die Faszination entsteht aus Trägheit, Schwerkraft, präzisem Flug, riskanten, aber fairen Landeanflügen und dem Wunsch, jede Fahrt noch sauberer zu meistern.

Die Kernmechanik umfasst:

Reproduzierbare, fein abstimmbare 2D-Flugphysik: Beschleunigung durch Schubdüsen, Impuls/Trägheit, Gegenschub, Schwerkraft, kontrolliertes Abbremsen; kein beliebiges Sofortstoppen.

Ein klar lesbares, ausfahrbares Landefahrwerk. Sichere Landung nur mit korrekter Position, zulässiger Geschwindigkeit und Neigung; exakte, faire Kollisions- und Landetoleranzen. Mit visueller Vorwarnung im HUD.

Verschiedene nummerierte oder eindeutig benannte Pads: Passagiere steigen nur auf einer sicheren, ruhenden Plattform ein und aus. Zielplattform wird immer gut erkennbar angekündigt und markiert.

Mehrere Transportaufträge pro Level, gut lesbare Auftragsanzeige, eine verständliche Levelabschlussbedingung und ein aktiver Ausgang bzw. finales Gate.

Treibstoff-/Energiesystem, optionale Tank- und Reparaturstationen, faire Kosten, Bonus für schonende Landungen, zeitabhängiges Trinkgeld. Keine Sackgasse allein durch schlechte Zufallswerte oder eine ökonomisch unmögliche Betankung.

Kollisionen, bewegte Gefahren, kontrollierte Schadens- und Neustartlogik. Sofortiger, schneller Neustart ohne lange Animationen; optionale kurze Rückspulfunktion bzw. Übungsmodus, sofern gut integrierbar.

Präzise, reaktionsschnelle Bedienung. Das Spiel darf schwierig sein, aber niemals unfair, schwammig oder nur durch Glück gewinnbar wirken.

Das Fliegen und Landen muss bereits ohne Zusatzfeatures so gut sein, dass eine einzelne kurze Fahrt Spaß macht. Überprüfe dies anhand einer frühen Vertical Slice und verbessere das Spielgefühl, bevor die große Content-Produktion beginnt.

2. -Level-Kampagne und Schwierigkeit

Baue exakt neun thematisch und spielerisch unterscheidbare Sektoren mit je elf Levels. Jede Welt führt neue Elemente zunächst einzeln ein, steigert ihre Anforderungen und kombiniert sie später. Der jeweils elfte Level ist eine besondere Meisterprüfung; Level  bildet ein eigenständiges Kampagnenfinale.

Level

Sektor

Schwerpunkt

01–11

Sternenhafen

Grundlagen: Schub, Trägheit, Landung, erste Personenbeförderung, Tanken; zunehmend engere Flugwege

12–22

Neon-Schluchten

Vertikale Schächte, Engstellen, bewegliche Tore und präzise Anflüge

23–33

Schrottgürtel

Driftende Trümmer, bewegliche Plattformen und vorausberechnete Flugbahnen

34–44

Magnetfeld

Magnetische Zonen, anziehende/abstoßende Kräfte und sichere Korridore

45–55

Solarschmiede

Hitzezonen, periodische Strahlen, Taktung und dynamische Gefahren

56–66

Gezeitenorbit

Wechselnde Schwerkraftrichtungen, Strömungen und räumliche Orientierung

67–77

Transitknoten

Verkehr, synchronisierte Schleusen, alternative Routen und komplexere Auftragsfolgen

78–88

Schattenring

Eingeschränkte Sicht, Radar, Sensoren und anspruchsvolle Energiesteuerung, jedoch niemals blinde Glückspassagen

89–

Singularitätsrand

Faire Kombination aller erlernten Systeme; Level  als großes, erinnerungswürdiges Finale

Verbindliche Content-Anforderungen:

Jedes der  Level besitzt ein eigenes, sichtbar unterschiedliches Layout, eine eindeutige Kennung und eine bewusst entworfene Flug-/Auftragsherausforderung. Reine Kopien mit geänderter Farbe oder nur höheren Geschwindigkeiten zählen nicht.

Leveldesign und Konfiguration sind datengetrieben, gut wartbar und pro Level separat prüfbar (z. B. Godot Resources oder geeignete eigene Level-Szenen).

Erstelle eine Leveldesign-Matrix mit neuen Mechaniken, Fahrgastanzahl, Gefahrentypen, Tankstellen, erwarteter Schwierigkeit, Checkpoints und Besonderheiten je Level.

Schwierigkeitssteigerung durch präzisere Manöver, komplexere Routen, neue Kombinationen und kluge Planung – nicht vorrangig durch willkürliche Treibstoffknappheit, unfair kleine Landeflächen oder unvorhersehbare Kollisionen.

Keine unlösbaren Situationen: Pads, Wege, Physik, Treibstoff, bewegte Hindernisse und Auftragsfolgen müssen zueinander passen. Alle zufälligen Elemente müssen reproduzierbar sein und dürfen keine Pflichtfahrt unmöglich machen.

Jedes Level benötigt eine dokumentierte Solvability-/Validierungsprüfung, nach Möglichkeit eine automatisierte Testfahrt oder simulierte Erreichbarkeitsanalyse und zusätzlich tatsächliche spielerische Abnahme. Nicht bestandene Tests niemals als bestanden ausgeben.

Dauerhafter Kampagnenfortschritt und Levelauswahl für freigeschaltete Level. Eine vollständig absolvierte Kampagne muss auch nach einem Neustart als abgeschlossen gelten.

3. Moderne, sinnvolle Erweiterungen

Bewerte und implementiere die folgenden Ideen nur, wenn sie den Kern bereichern und keine unkontrollierbare Feature-Überladung verursachen:

Verschiedene Fahrgasttypen mit spielerisch relevanten, verständlich kommunizierten Aufträgen: eilige VIPs, zerbrechliche Fracht, Mehrfachziele, Gruppen, Notfalltransporte.

Ein schlankes freischaltbares Upgrade-System: beispielsweise effizientere Düsen, begrenztes Stabilisierungssystem, bessere Sensoren oder ein einmaliger Notschild. Fortschritt darf das präzise Fliegen nicht entwerten. Upgrades dürfen nicht zwingende Voraussetzung für das Beenden regulärer Level sein; ein Challenge-Modus mit Standardtaxi bleibt möglich. Keine Echtgeldmechaniken.

Drei Medaillen bzw. Leistungsränge pro Level anhand sinnvoller Kriterien (z. B. sichere Zustellungen, Zeit, Treibstoff, Beschädigungen), Bestzeiten und lokale Rekorde.

Optionaler Arcade-/Endlosmodus, tägliche Herausforderung mit lokalem Seed, persönliche Geisterfahrt oder Wiederholung – klar getrennt von den  Kampagnenleveln.

Besondere Sektorfinales mit überraschenden, aber zuvor eingeführten Mechanikkombinationen, kein themenfremder Kampfzwang.

Charmante Fahrgastreaktionen, kleine humorvolle Ereignisse, ein eigenständiges Universum mit wiederkehrenden Figuren und dezenter Story, die das Tempo nicht bremst.

Verschiedene Schwierigkeits- und Zugänglichkeitsoptionen (z. B. Casual/Arcade, Hilfsanzeigen, reduzierte Effekte) ohne die Standardherausforderung aufzugeben.

Lege zuerst eine Prioritätenliste fest: Pflicht / wertvolle Erweiterung / optional. Implementiere die Pflichtfunktionen vollständig, bevor du optionale Modi hinzufügst.

4. Grafik, Atmosphäre und UI

Ziel ist moderne, hochwertige Pixel-Art, nicht einfache Retro-Platzhalter oder ein unverändertes C64-Bild. Verwende einen konsistenten Maßstab, hochwertige Silhouetten, handwerklich stimmige Tile-Sets, lebendige Beleuchtung, kontrollierte Farbpaletten, Animationen, dezente Partikel, mehrschichtige Parallaxe und starke visuelle Identität. Das Spiel soll auch auf 4K-Monitoren attraktiv aussehen.

Bevorzugt 2D in Godot. Evaluieren, ob Aseprite für Sprites/Animationen und Blender für ausgewählte vorgerenderte Motive, räumliche Referenzen oder Partikel sinnvoll sind. Kein Tool muss nur deshalb benutzt werden, weil es vorhanden ist.

Pixel-Art bleibt in Bewegungen und Skalierung scharf: passende interne Spielauflösung (z. B. 640 × 360 bei 16:9), sinnvolles Integer-Scaling, saubere Kamera, kontinuierliche Physik mit passendem Rendering, keine zitternden Sprites.

Sektorweise klar unterscheidbare Palette und Architektur, moderne Lichtakzente und atmosphärische Details, ohne wichtige Plattformen, Gefahren oder Passagiere zu überstrahlen.

Großes Augenmerk auf die Taxi-Animationen: Triebwerksflammen für Schubrichtungen, Fahrwerk aus-/eingefahren, Bremseffekt, beschädigte Zustände, kurze Boarding-Sequenzen, sichere Landungsrückmeldung.

Professionelles Hauptmenü, pausierbares Spiel, grafische Einstellungen, Steuerungsbelegung, Soundmix, Sprache, Zugänglichkeit, Kampagnenstand, Sektorauswahl, Statistik, Credits und „Spiel beenden“.

Klare Trennung von HUD und Spielwelt. Korrekte und sofort verständliche Anzeigen für Treibstoff, Zustand, Geschwindigkeit/Landesicherheit, Ziel, Auftrag, Geld und Fortschritt.

Als verfügbare Schriftarten evaluieren: Jersey 10, Silkscreen, Pixelify Sans, Nunito, Oxanium. Wähle bewusst wenige passende Fonts für Titel/HUD/Fließtext, prüfe ihre konkreten Weitergaberechte und baue sie lesbar ein.

Alle Spieltexte mindestens auf Deutsch und Englisch, mit sauberem Lokalisierungssystem und korrekt skalierendem UI.

Vollbild- und Fenstermodus, 16:9 und möglichst andere Seitenverhältnisse ohne abgeschnittene Elemente, konfigurierbare V-Sync-/FPS-Einstellungen, reduzierte Bildschirmbewegung und visuelle Warnhinweise zusätzlich zum Ton.

Verwende vorhandene generative Bildwerkzeuge wie SwarmUI höchstens dort, wo sie sich qualitativ und rechtlich eignen, z. B. für Konzeptbilder und Moodboards. Übernimm keine unscharfen KI-Bilder direkt als vermeintliche Pixel-Sprites. Sämtliche finalen Assets müssen technisch sauber, konsistent und stilistisch überarbeitet sein.

5. Steuerung und Spielkomfort

Tastatur: WASD und Pfeiltasten für Schubsteuerung, Leertaste für das Landefahrwerk, Esc für Pause/Menü und Zurück, Enter oder Leertaste für die Menüauswahl. Wo Tasten doppelt belegt sind, muss dies kontextabhängig konfliktfrei funktionieren.

Gamepad: Linker Stick und Steuerkreuz für Schubsteuerung, A für Fahrwerk bzw. Bestätigung im Menü, B für Zurück, Start zum Öffnen und Schließen des Pausenmenüs. Optionale analoge Dosierung des Schubs nur dann, wenn sie präzise und konsistent ist.

Steuerung vollständig frei belegbar; Gamepad- und Tastaturhinweise automatisch passend zur letzten aktiven Eingabe anzeigen. Tastenbelegungen persistent speichern.

Landefahrwerk wahlweise per Halten oder Umschalten steuerbar; Zustand immer eindeutig sichtbar. Sticks mit einstellbarer Deadzone, Menüfokus zuverlässig, keine doppelten/verschluckten Eingaben.

Menüs vollständig mit Gamepad bedienbar. Start öffnet und schließt Pause zuverlässig; keine Eingaben dürfen gleichzeitig Menübefehle und Spielschub auslösen. Kein Softlock durch Pausieren während einer Landung oder Transportanimation.

Schnelle Wiederholung, klare Fehlerrückmeldung, optionale Tutorials, jederzeit überspringbare Hinweise und kein unnötiges Warten zwischen Fahrten.

6. Musik, Sound und Sprachausgabe

Komponiere einen eigenständigen, atmosphärischen Soundtrack mit modernem Chiptune-/Synthwave-/Orchester-Hybrid. Musik und Geräusche sollen das dynamische Arcade-Spielgefühl stützen; Soundeffekte für Schub, Landung, Passagier, Warnung und Gefahr haben Vorrang vor musikalischer Üppigkeit.

Als mögliche Quellen für Instrumentensamples stehen bereit:

VSCO 2 Community Edition: https://github.com/sgossner/VSCO-2-CE

Versilian Community Sample Library (VCSL): https://github.com/sgossner/VCSL

Beide Repositories weisen eine CC0-1.0-Lizenz aus. Prüfe beim konkreten Download und jedem verwendeten Unterbestand die Provenienz, Lizenz und eventuelle Drittrechte erneut. Komponiere originelle Musikstücke; übernimm keine bekannten Melodien, Original-Sounds oder Musik aus Space Taxi. Ziel: mindestens ein charakteristisches, nahtlos loopbares Musikthema pro Sektor, eigene Menü-/Finalmusik und passende akustische Signale. Stelle getrennte Lautstärken für Musik, SFX und Stimmen bereit.

Für Durchsagen und humorvolle Fahrgastzeilen kann Qwen3-TTS eingesetzt werden: https://github.com/QwenLM/Qwen3-TTS . Prüfe die Lizenz des konkret gewählten Modells und der verwendeten Komponenten, bevor die Ausgaben in das Spiel übernommen werden. Erzeuge Audio offline im Entwicklungsprozess, konvertiere es in geeignete komprimierte Spieldateien und liefere das Spiel so aus, dass keine KI-Inferenz, GPU, Internetverbindung oder TTS-Installation zur Laufzeit nötig ist. Keine Stimmen realer Personen ohne Einwilligung nachahmen. Durchsagen müssen in Deutsch und Englisch verfügbar und zusätzlich als Untertitel lesbar sein; Sprache muss einzeln abschaltbar sein. Fehlt TTS, ist Text+SFX ein funktionierender Fallback.

7. Werkzeuge und technische Architektur

Zur Verfügung stehen Godot, Blender, Aseprite, die genannten Schriftarten und Soundbibliotheken, Qwen3-TTS, SwarmUI sowie weitere lokal installierte Programme. Du darfst den sinnvollen lokalen Werkzeugbestand inventarisieren, Varianten hinsichtlich Qualität, Entwicklungsaufwand, Bedienbarkeit und Lizenz vergleichen und anschließend die am besten geeignete Toolchain wählen. Nicht alle Programme müssen verwendet werden. Nutze Godot als primäre Engine, sofern keine schwerwiegenden Gründe dagegensprechen.

Arbeite auf dem vorhandenen Linux-/CachyOS-System. Berücksichtige native Entwicklungs- und Exportwege; wenn zusätzliche Software erforderlich wird, bevorzuge gut prüfbare, vertrauenswürdige Pakete bzw. bestehende Installationen. Keine unnötigen globalen Änderungen, keine blinde Ausführung fremder Installationsskripte, keine geheimen Zugangsdaten im Projekt.

Verwende gut verständliche, modulare Godot-Szenen/Skripte mit klar getrennter Flugphysik, Leveldaten, Auftragslogik, HUD, Audio, Speicherständen und Eingaben.

Keine künstliche Abhängigkeit von Onlinediensten, generativer KI oder proprietären Cloud-APIs für den Spielbetrieb.

Bei Bedarf feste Physik-Ticks; sauberes Verhalten bei hohen Bildwiederholraten (auch 240 Hz), Pause und variabler Framerate. Ziel: flüssige Wiedergabe ohne Physik- oder Eingabefehler.

Konfigurationsdateien, Speicherstände, Steuerungszuordnungen und Lokalisierung robust behandeln; sichere Fallbacks bei defekten/fehlenden Daten.

Performance auch auf durchschnittlichen PCs sinnvoll halten. Native Linux-Version ist Pflicht; Windows-Export nach Machbarkeit. Geeignete Projekt- und Exportdokumentation beilegen.

Erstelle ein Asset- und Lizenzinventar mit Herkunft, Lizenz, Modifikation und Exportverwendung. Füge erforderliche Drittlizenzen und Hinweise bei. Keine Fonts/Samples ungeprüft verteilen.

8. Lokales Git und Entwicklungshygiene

Lege direkt zu Beginn ein lokales Git-Repository im neuen Spielprojekt an (git init), sofern dort noch keines existiert. Richte eine korrekte .gitignore für Godot, temporäre Exporte, Cache, Entwicklungsartefakte und lokale Konfiguration ein. Versioniere Quellcode, Szenen, Leveldaten, Tests, Projektkonfiguration und notwendige Assets; ignoriere nicht pauschal Testdateien oder Quellverzeichnisse. Erstelle nachvollziehbare Commits nach abgeschlossenen Meilensteinen. Lege keinen GitHub-Remote an und pushe/veröffentliche nichts ohne ausdrücklichen Auftrag.

Pflege mindestens: README.md, DESIGN.md, LEVELS.md, CONTROLS.md, TESTING.md, CREDITS.md und THIRD_PARTY_LICENSES.md (oder gleichwertig gut benannte Dokumente). Entscheide eine etwaige öffentliche Lizenz für das eigene Spiel nicht eigenmächtig; dokumentiere den Stand und frage vor Veröffentlichung.

9. Entwicklung in verbindlichen Meilensteinen

M1 – Bestand und Design: Lokale Tools und Versionen prüfen, Lizenzrisiken sichten, Spielkonzept/Technikentscheidungen dokumentieren, Git initialisieren, minimal ausführbares Godot-Projekt und Teststruktur anlegen.

M2 – Vertical Slice: Flugphysik, Fahrwerk, Pad-/Passagiersystem, Tanken, HUD, Gamepad, Menü und ein vollständig gestaltetes Level. Spielgefühl kritisch überprüfen und iterieren. Erst weitergehen, wenn Starten, Fliegen, Landen, Aufträge, Verlieren und Wiederholen sauber funktionieren.

M3 – Systemfundament: Datengetriebene Levelarchitektur, Levelauswahl, Fortschritt, Lokalisierung, Audio-Pipeline, Optionen, Replay-/Score-Fundament, Validatoren und dokumentierte Testwerkzeuge.

M4 –  Level: Die neun Sektoren vollständig entwickeln, Layouts individuell erstellen, neue Mechaniken einführen, auf Schwierigkeit abstimmen und jeden Level validieren. Nach jedem Sektor sichtbare Art-/Audio-Politur und spielerische Tests, nicht nur Befüllen einer Datenliste.

M5 – Politur: Konsistente Pixel-Art, vollständige UI, Soundtrack, deutsche/englische Texte und Ansagen, Menüs, Optionen, Feedback, Performance und Fehlerbehebung. Optionale Zusatzmodi nur bei stabiler Kampagne.

M6 – Release Candidate: Alle  Level tatsächlich durchspielbar und geprüft; Projekt startet im Godot-Editor und läuft als nativer Export. Saubere Dokumentation, Lizenzinventar, Testbericht, bekannte Einschränkungen und Git-Stand übergeben.

Melde nach jedem Meilenstein kurz und konkret: umgesetzt, spielbar, getestet, verbleibende Probleme, nächster Schritt. Sage niemals „fertig“, wenn nur Code generiert wurde oder die  Level nicht vollständig getestet sind. Bei Zeit- oder Kontextgrenzen den aktuellen Stand so dokumentieren und committen, dass die Arbeit ohne Verlust fortsetzbar ist.

10. Verbindliche Qualitäts- und Abnahmekriterien

Genau  verschiedene Kampagnenlevel sind vorhanden, freischaltbar, startbar, abschließbar und nach Neustart korrekt im Fortschritt sichtbar. Es gibt keine Füll- oder Dummy-Level.

Jeder Level ist unter den vorgesehenen Regeln grundsätzlich lösbar; dies wird durch automatisierte Validierung und manuelle/agentengestützte Spieltests nachvollziehbar belegt.

Flug und Landung sind präzise, reproduzierbar und fair; relevante Parameter sind dokumentiert und über längere Spielsitzungen geprüft.

Gamepad, Tastatur, Menü, Pause, Restart und Remapping funktionieren ohne Fokusfehler, Eingabekonflikte und Softlocks.

Pixel-Art, Effekte, Bedienoberfläche und Klang sind einheitlich hochwertig, stilistisch eigenständig und klar besser als grafische Platzhalter.

Keine blockierende Internet- oder KI-Abhängigkeit im fertigen Spiel; Musik, Ansagen und Assets sind lokal verfügbar.

Lauffähiger Linux-Build, Godot-Projekt, verständliche Start-/Exportanleitung, reproduzierbare Tests und keine unkritisch bekannten schwerwiegenden Fehler.

Eine übersichtliche Tabelle dokumentiert für alle  Level Mechaniken, Teststatus, offene Probleme und tatsächliche Abnahme. Erstelle außerdem eine Levelübersicht als Bilder/Kontaktbogen, soweit lokal praktikabel.

Alle verwendeten Fremdassets haben nachvollziehbare Nutzungserlaubnisse; der Titel, die Figuren, Hintergründe, Musik, Sounds und Levelanordnungen sind unabhängig von Space Taxi gestaltet.

Ein lokales Git-Repository mit sinnvoller Commit-Historie ist vorhanden; es gibt keinen ungefragt eingerichteten Remote oder Upload.

11. Originalität und Rechte

Die bekannte Grundidee „Flugtaxi holt Fahrgäste ab und landet präzise“ darf als Spielprinzip-Inspiration dienen. Übernimm jedoch keine Originalgrafiken, konkreten Originallevel, Sprüche/Sprachaufnahmen, Soundeffekte, Musik, Namen, Figuren, Quelltexte oder erkennbar imitierte Gesamtaufmachung. Entwickle ein eigenes Science-Fiction-Universum, UI, Levelkonzepte und eine eigene audiovisuelle Identität.

„GraviFare “ ist ein vorläufiger Arbeitstitel. Vor einer Veröffentlichung sind identische und ähnliche Marken/Titel in den relevanten Märkten (mindestens Deutschland/EU), bestehende Spiele, Plattformen und Domains sowie mögliche ältere Kennzeichenrechte zu prüfen. Eine Websuche allein ist keine rechtssichere Freigabe. Wenn sich ein Konflikt zeigt, schlage neue eigenständige Namen vor und halte die Entscheidung offen.

12. Deine erste Antwort und dein Start

Beginne unmittelbar mit einer knappen Bestandsaufnahme der lokal vorhandenen Tools und Engines, einer begründeten technischen Auswahl, einer priorisierten Featureliste sowie dem Plan für die erste spielbare Vertical Slice. Initialisiere anschließend das neue lokale Projekt und Git-Repository und setze die Arbeit tatsächlich um. Ich erwarte ein fertiges Spiel als Projektziel, nicht nur ein Game-Design-Dokument, einige Screenshots oder eine Demonstration mit fünf Levels.


---

# B) Verbindliche Nachträge des Auftraggebers (Vorrang vor A)

Zahlen, die im Originaltext fehlen: Es sind **99 Level** (9 Sektoren à 11 Level); Level 99 ist das große Kampagnenfinale. Der Titel „GraviFare“ bleibt vorläufig.

## B1 Darstellung, Auflösung, Grafik
- Logische Spielauflösung 640×360, **Standardfenster 1920×1080** (Stretch `canvas_items`, Integer-Scaling, 4K = exakt 6×). UI und Schrift bleiben scharf.
- Grafik in **3-facher Detailauflösung** (Tile = 48 px = 16 Welteinheiten), deutlich detaillierter als einfache 640×360-Pixel-Art: Hüllenplatten mit Nieten, Lüftungen, Statusleuchten, mehrschichtige Hintergründe (Nebel, Planet, Skyline-Ebenen), detailliertes Taxi mit Fahrer.
- **Räumlichkeit**: Licht (Punktlichter an Pads, Unterständen, Tor, Taxi) mit Schattenwurf (Occluder), Normal-Maps auf den Tiles, Schlagschatten und Ambient Occlusion, Kontaktschatten des Taxis, Bloom, Vignette, Atmosphäre/Dunst. Spielelemente (Taxi, Pads, Fahrgäste, Tor) bleiben ungelit und immer klar lesbar.
- Partikel: Abgase (Haupt-, Seiten-, Bremsdüsen), Bodenstaub unter dem Schub, Staubwolke bei Landung/Start, Funken bei Kollision, Rauch bei Schaden, Schwebestaub. Bei „Weniger Bewegung“ reduziert.
- Alle Grafik eigenständig per Skript/Pixel-Art erzeugt (Python/Pillow, Aseprite nach Bedarf), keine unüberarbeiteten KI-Bilder.

## B2 Ausgangstor
- Das Ausgangstor liegt in **jedem Level immer mittig oben** in der Decke (4×2 Tiles), ist ein **echtes Tor** (Rahmen mit Warnstreifen, zwei Torflügel, Statuslampen, Schild „GESPERRT/AUSGANG“ bzw. „LOCKED/EXIT“), **geschlossen = fest**, öffnet erst, wenn alles für das Level erledigt ist (siehe B5), mit Animation (Flügel fahren auseinander, heller Innenraum mit Leit-Chevrons, Lichtkegel). Darunter bleibt immer ein mindestens 4 Tiles breiter Flugweg frei. Per Test für jedes Level prüfen.

## B3 Fahrgäste, Wartebereiche, Sprache
- Jedes Passagier-Pad hat einen **Wartebereich**: Unterstand an einem Padende mit beleuchteter Tür, davor der Wartepunkt. Fahrgäste treten aus der Tür, warten (Idle mit Blinzeln), **winken und rufen „Hey Taxi!“**, laufen mit **echter Laufanimation** (6-Frame-Zyklus, Seitenansicht, keine Wackelbewegung) zum gelandeten Taxi, steigen ein und sagen ihr Ziel (**„Plattform 2, bitte!“ / „Platform two, please!“**). Am Ziel steigen sie aus, laufen in den Unterstand und verschwinden dort („Danke!“/„Thanks!“). Einsteigen dauert so lange, wie sie laufen; Abheben bricht es ab (Fahrgast läuft zurück). Abgelieferte Fahrgäste erscheinen **nie erneut** am Ursprungspad; jeder Auftrag hat einen eigenen Fahrgast (Name, Geschlecht, Figur).
- **Neue Fahrgäste erscheinen nie auf dem Pad, auf dem das Taxi gerade steht.** Levelregel (per Test erzwingen): erster Auftrag ≠ Startpad; jeder Auftrag beginnt an einem anderen Pad als der vorherige endete. Zusätzlich Laufzeitschutz: Spawn wartet, solange das Taxi auf dem betreffenden Pad steht.
- **Pad-Nummern sind immer fortlaufend 1..N** (bei 3 Pads: 1, 2, 3; nie 1, 2, 5). In späteren Leveln darf es mehr Pads geben, bis zu 9.
- **Sprachausgabe** mit **Qwen3-TTS** (VoiceDesign, Apache-2.0), **offline** erzeugt, als OGG ausgeliefert: **getrennte weibliche und männliche Stimmen** (zwei je Geschlecht), Deutsch und Englisch, mit **Untertiteln** (abschaltbar) und eigenem Voice-Regler; ohne Sprachdateien bleibt Text+SFX. Zur Laufzeit keine KI.
  - Stimmbeschreibungen **in der Sprache der jeweiligen Zeile** formulieren („Deutsche Muttersprachlerin, akzentfreies Standarddeutsch …“), sonst klingt Deutsch englisch akzentuiert (so geschehen).
  - Clip-Enden dürfen nicht abgehackt sein: relative Schwelle (ca. −46 dB zur Spitze), 0,25 s Nachlauf, ~180 ms Cosinus-Ausblendung, erst **danach** normalisieren.
  - Jeden Clip automatisch per lokaler Spracherkennung prüfen (faster-whisper „medium“, nur lokale Modelle) und bei Fehlern (Zusatzwörter wie Lacher/Stottern, falsche Zahlwörter) mit neuem Seed wiederholen. Der Auftraggeber hat die Stimmen gehört und für **gut befunden**, wenn diese Maßnahmen angewandt werden.

## B4 Flug- und Landeverhalten
- Eigene deterministische Taxi-Physik mit festem Tick (120 Hz), Physik-Interpolation fürs Rendering. Schwerkraft 90 px/s², Hauptschub 230, Seitenschub 125, Dämpfung 0,18/s, Höchstgeschwindigkeit 240; Neigung folgt dem Seitenschub. Landefenster: Sinkrate ≤ 48 px/s, Seitengeschwindigkeit ≤ 32 px/s, Neigung ≤ 8,6°, beide Füße auf demselben Pad, Fahrwerk ausgefahren; „weich“ ab ≤ 22 px/s. **Der Auftraggeber hat Schwerkraft, Landefenster und Steuerung als gut befunden – nicht grundlos ändern.**
- **Zwei Flugmodi**: Fahrwerk **eingefahren** = schnelle, wendige Navigation (Werte oben). Fahrwerk **ausgefahren** = Feinmanöver: schwächere Düsen (Schub 150/Seite 68/runter 80), starke Dämpfung (1,1/s), Höchstgeschwindigkeit 90; Übergang folgt der Fahrwerksanimation.
- **Absturz-Balance**: Aufprall bis 70 px/s harmlos; darüber Hüllenschaden, der überproportional mit der Geschwindigkeit steigt (Schaden = 100·((v−70)/(170−70))^1,6); **ab 170 px/s ist das Taxi sofort zerstört**.
- **Harte Landung schmälert den Ertrag**: Landungen zwischen „weich“ und Limit verringern den Fahrpreis (bis −30 % je Landung, linear mit der Sinkrate).
- Sofortiger Neustart (R/Y) ohne lange Animation.

## B5 Spielregeln und Ökonomie
- **Fahrpreis hängt von der Zeit ab**: gemessen vom **Erscheinen** des Fahrgasts bis zur Ankunft am Ziel. Je schneller, desto mehr Credits, je länger, desto weniger. Formel: Faktor = clamp(1 + (1 − t/par)·0,6; 0,35; 1,6); bei Richtzeit `par` genau 1,0. Aktueller Faktor im HUD anzeigen (z. B. „×1,35“).
- **Am Ende jedes Levels will ein Fahrgast „ins nächste Level“ gebracht werden** (letzter Auftrag `to: "exit"`): Das Tor öffnet erst, wenn dieser Fahrgast an Bord ist („Zum Ausgang, bitte!“ / „To the exit, please!“); Level endet, wenn das Taxi mit ihm durchs Tor fliegt. Im nächsten Level steigt er nach der Landung auf der Startplattform aus, bedankt sich und läuft in den Unterstand.
- **5 Leben für die gesamte Kampagne (99 Level)**. Zerstörtes Taxi = ein Leben weniger, Level startet neu (Sprit/Credits wie beim Levelbeginn). Kein Leben mehr = **Game Over** (Anzeige, dann Hauptmenü). Leben im HUD anzeigen (kleine Taxi-Symbole). Freigeschaltete Level bleiben dauerhaft verfügbar (Levelauswahl startet einen neuen Lauf mit 5 Leben).
- **Sprit wird nicht zu Levelbeginn aufgefüllt**, sondern **vom vorherigen Level übernommen** (Untergrenze 35 %, damit es nie eine Sackgasse gibt; Tankstellen: unter 35 % kostenlos, sonst gegen Credits). Credits laufen über alle Level mit.
- Level-Validierung muss auch den **ungünstigsten Start (Mindestvorrat 35 %)** automatisiert nachweisen.

## B6 Level und Schwierigkeit
- Schwierigkeit steigt **von Level 1 bis 99 durchgehend** an. Führe eine **Schwierigkeitsmetrik** ein (z. B. engster Flugkorridor der Bot-Route, Streckenlänge, Anzahl Aufträge, Padbreite, Gefahren) und **erzwinge per Test, dass sie über die Level nicht sinkt**. Frühe Level großzügig (keine engen Anflüge): Der Auftraggeber fand Pad 2 in Level 2 wegen des geringen Abstands bereits zu schwer – die ersten Level müssen sehr großzügig sein, Engstellen kommen erst später.
- Level als JSON mit ASCII-Karte, pro Level separat prüfbar; Pads mindestens 4 Tiles breit (Unterstand braucht 2 Tiles Luft über einem Padende); Bot-Lösbarkeitstest (BFS-Planung + echte Physik) für jedes Level; zusätzliche spielerische Abnahme dokumentieren; nicht bestandene Tests niemals als bestanden melden.

## B7 UI, Sprache, Menüs, Eingabe
- **Komplett zweisprachig (Deutsch/Englisch)**: alle Texte über JSON-Übersetzung (Test: gleiche Schlüssel, nichts Leeres, alle im Code benutzten Schlüssel definiert), Levelnamen in beiden Sprachen, Sprachclips je Sprache. **Sprachwahl im Hauptmenü unter den Menüeinträgen über zwei Flaggen ohne Text**: Deutschland und eine **diagonal geteilte Flagge Großbritannien/USA**; Wahl wird gespeichert, Menü baut sich sofort neu auf; Flaggen **zentriert in ihrem Auswahlrahmen**, mit Gamepad fokussierbar.
- **Hauptmenühintergrund animiert** (z. B. Parallax-Skyline, funkelnde Sterne, Sternschnuppen, vorbeifliegende Taxis/Schiffe mit Abgasspur, blinkende Baken, Staubpartikel) – eigene Ideen willkommen, dezent und performant, mit Rücksicht auf „Weniger Bewegung“.
- **Gamepad im Menü**: A bestätigt, B zurück, Start öffnet/schließt Pause. Hinweis: In Godot 4.7 haben `ui_accept`/`ui_cancel` keine Gamepad-Tasten – explizit hinzufügen. Last-device-Erkennung nur für Stick-Achsen (nicht Trigger, die im Ruhezustand −1 melden).
- Optionen: Musik/Effekte/Stimmen, Deadzone, Fahrwerk Umschalten/Halten, Sprache, Vollbild, Weniger Bewegung, Untertitel; alles persistent, robust gegen defekte Dateien.
- **Levelwechsel-Sequenz**: Beim Verlassen des Tors blendet das alte Level in **2 s** aus (in den Weltraum), es folgt eine **3–4 s Zwischensequenz** (Taxi fliegt durchs All: Sterne in mehreren Ebenen, Planeten, Titelkarte „Sektor · Level – Name“, verdienter Betrag, mit Sound), dann blendet das neue Level in **2 s** ein, **während das Taxi durch das kurz öffnende Tor in der Decke austritt, eine S-Kurve fliegt und auf seiner Startplattform landet**. Überspringbar (A/Enter/B/Esc). Der Sound ist eine **eigene, hochwertige Synthese** (Klangcharakter eines Weltraumflugs: ansteigendes Antriebsbrummen, Vorbeiflug-Whooshes mit Doppler, Sweeps, Pad-Akkorde, Arpeggio, Reverb, stereo) – **kein Original-Space-Taxi-Klang übernehmen** (Rechte).

## B8 Entwicklungshygiene
- Lokales Git (kein Remote/Push), Dokumente README/DESIGN/LEVELS/CONTROLS/TESTING/CREDITS/THIRD_PARTY_LICENSES laufend pflegen, Meilensteinberichte kurz und ehrlich (umgesetzt/spielbar/getestet/Probleme/nächster Schritt), nie „fertig“ melden, wenn nur Code generiert wurde.
- Dev-/Testläufe (Autopilot, Debug-Flags) **dürfen den echten Speicherstand nie verändern**.
- Der Auftraggeber testet selbst und gibt Rückmeldung nach jedem Meilenstein; baue Dev-Flags für Screenshots/Autopilot (`--level=`, `--autopilot`, `--shot=… --frames=…`, `--lang=`, `--debug-complete`, `--trans-t=`).

---

# C) Technische Erfahrungen (spart dir Umwege)

- **Umgebung**: Linux (CachyOS), KDE/Wayland, RTX 4090. Godot `~/.local/bin/godot` (4.7.2), Blender 5.2, Aseprite, ffmpeg (libvorbis), sox, fluidsynth, csound, Python mit Pillow/numpy/scipy. Godot-**Export-Templates fehlen** lokal; Schriftarten (Jersey 10, Silkscreen, Pixelify Sans, Nunito, Oxanium) und die Sample-Bibliotheken VSCO/VCSL sind **nicht installiert** – Download nur nach Rückfrage/Lizenzprüfung (OFL bzw. CC0).
- **Qwen3-TTS**: Modellordner im HF-Cache waren leer. Einrichtung: `uv venv .venv/tts --python 3.12 && uv pip install --python .venv/tts/bin/python qwen-tts==0.1.1 torch faster-whisper` (CUDA funktioniert); Modell `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign` (4,5 GB, Apache-2.0, Lizenz vorher per HF-API prüfen). API: `Qwen3TTSModel.from_pretrained(..., device_map="cuda:0", dtype=torch.bfloat16).generate_voice_design(text=, instruct=, language="German"/"English")`. Lokale Whisper-Modelle (nur lesen) unter `/home/floppi/Dokumente/DSH/Workspaces/ws-dsh-intern/.bench/.hf/hub/models--Systran--faster-whisper-medium/snapshots/*/`; GPU-Whisper scheitert an fehlendem cuBLAS → CPU int8.
- `godot --headless --import` einmal nach frischem Checkout (baut den Klassen-Cache); Tests: `godot --headless -s tests/test_runner.gd`.
- Fallstricke: `CPUParticles2D` hat kein `amount_ratio`; `GDScript` braucht explizite Typen bei Variant-Werten; `pgrep -f`/`pkill -f` treffen die eigene Shell – nicht in Warteschleifen verwenden; `godot --minimized` öffnet unter KDE/Wayland **nicht** minimiert; TextureRect mit großer Textur braucht `expand_mode = EXPAND_IGNORE_SIZE` + `STRETCH_SCALE`; Icon in Button zentrieren, indem man ein zentriertes TextureRect-Kind nutzt (sonst sitzt die Flagge schief im Rahmen); `Control`-Layout in CanvasLayern mit `set_anchors_and_offsets_preset` setzen; Screenshots: `--rendering-driver opengl3 -- --shot=… --frames=…`.
- Bewährt: Tile-Raster 16 px, Level 40×22 Tiles, Pads/Unterstände aus ASCII-Karte, Autopilot-Bot als Spieltester, Levelwerkzeug (`Grid`-Klasse mit `pad()`, `gate()`), Kontaktbogen-Screenshots je Level.

---

# D) Nachtrag aus dem laufenden Parallelprojekt (neuere Erkenntnisse)

- **Schwierigkeitsmetrik** (Score = 40·Enge + 25·Streckenlänge + 15·Aufträge + 10·Padbreite + 10·Gefahren; Enge = engster Flugkorridor der Bot-Route per BFS mit wachsendem Sicherheitsrand) – Test erzwingt, dass sie über die Levelnummern nicht fällt. Typische Stolperfalle: Zwischen einem von der Decke hängenden Block (z. B. dem Torblock) und einem Block darunter müssen mindestens **96 px** Durchflug bleiben; zwischen Regal und hängendem Block mindestens **80 px** (sonst ist der Anflug zu eng – der Auftraggeber hat genau das bemängelt).
- Jedes Level muss **ab Mindest-Sprit 35 %** lösbar sein (ggf. Tankpad einbauen, sonst Sackgasse). Der Bot sollte nur bei kritischem Stand (< 14 %) tanken, sonst pendelt er zwischen Tankstelle und Auftrag.
- Fahrgast-Spawn-Regel kann den Bot festsetzen, wenn ein Level sie verletzt (Fahrgast erscheint nicht, solange das Taxi auf seinem Pad steht) → Levelregel per Test erzwingen.
- **Optik**: Normal-Maps aus der Helligkeit der Tiles ableiten (OpenGL-Konvention), `PointLight2D.height` setzen; **kein `hdr_2d`** und keine `adjustment_*`-Farbkorrektur (Bild wird zu dunkel/überzogen); Umgebungslicht ≈ (0,86/0,90/1,0); Glow-Schwelle ≈ 0,92. Screenshots mit dem Standard-Renderer (Forward+) machen, nicht mit `--rendering-driver opengl3`, sonst weicht der Look ab.
- **Transit-Sound**: Stereo, zeitgenau zur Sequenz (2 s Riser, Einschlag bei 2,0 s, Pad-Akkorde, Arpeggio mit Ping-Pong-Delay, Vorbeiflug-Whooshes mit Doppler, Abwärts-Sweep, Raumhall, am Ende leise zum Aufsetzen); Spektralschwerpunkt maschinell prüfen (< ~3 kHz, kein Zischen), Spitze < 0,9, kein Clipping.
- Skyline-/Nebel-Scrolling im Menü: jede zweite Kachel spiegeln, dann sind die Nähte unsichtbar.
- Mit ausgefahrenem Fahrwerk ist die Geschwindigkeit auf 90 px/s begrenzt; Sturztests (Sofortzerstörung ab 170 px/s) deshalb ohne Fahrwerk durchführen (`gear = 0` explizit setzen – das Setup startet gelandet mit ausgefahrenem Fahrwerk).

## E) Weitere Nachträge des Auftraggebers
- **Fahrgast-Kollision**: Landet das Taxi einem wartenden Fahrgast auf dem Kopf (oder fliegt hinein, nicht beim Aufsteigen und nicht beim Einsteigen), schimpft er („Hey, Idiot!“ / „Hey, idiot!“ als Sprachclip, DE/EN, Untertitel) und verschwindet (flieht in den Unterstand). **An seiner Stelle erscheint woanders ein neuer Fahrgast** (anderes Passagierpad, andere Person, deterministisch). Fahrgäste pro Level bleiben gleich in Anzahl und Auftragsdaten; es dauert nur länger (Zeitfaktor sinkt, mehr Sprit verbraucht = Strafe).
- **Plattformen unterschiedlich groß** (5–8 Tiles): je kleiner, desto schwieriger – **aber immer genug Platz zum Landen** (freies Landefenster neben Wartebereich ≥ 28 px, per Test). Dafür das **Taxi 20 % kleiner skalieren** (Hülle 16×8, Füße ±6,4); Fahrgäste und Unterstände 85 %. Metrik-Term „Landefenster“ statt reiner Padbreite.
- **Parallelbetrieb**: Mehrere Agenten können gleichzeitig Godot nutzen – nie Prozesse per Name beenden, nur eigene PIDs; eigener Projektordner und Projektname.

## F) Weitere Nachträge des Auftraggebers (Stand: dritte Testrunde)
- **Sprachwahl per Flagge auch im Pausenmenü** (gleiche zwei Flaggen wie im Hauptmenü, Gamepad-fokussierbar).
- **Einkommen erst bei Ankunft im Häuschen**: Der Fahrpreis wird gutgeschrieben, wenn die Figur nach dem Aussteigen ihren Unterstand erreicht hat; die Gehzeit zählt zur Fahrzeit (Zeitfaktor). Das belohnt Landungen nahe am Häuschen. Wichtig: Sehr kurze Wege (< 0,5 s) dürfen die Auszahlung nicht verlieren (Zahlungsinfo schon beim Aussteigen setzen); beim Levelende noch laufende Fahrgäste als angekommen werten; der Ausgangs-Fahrgast wird erst im nächsten Level im Häuschen bezahlt.
- **Absturz setzt das Level nicht zurück** (kein Neustart!): Leben −1, Erledigtes bleibt erledigt. Der Fahrgast an Bord zählt als verloren (kein Geld), **derselbe Fahrgast** wartet erneut an seinem Abholpad, das Tor schließt sich bis zum erneuten Einsammeln. Neues Taxi am Startpad (Rest-Sprit, mindestens 35 %). Nur der freiwillige Neustart (R) startet das Level komplett neu.
- **Plattformen dürfen in späteren Leveln kleiner werden**: Mindest-Landefenster linear von 34 px (Level 1–3) auf 20 px (Level 99); Level 1–3 sind bewusst großzügig, Spielraum bis Level 99 nutzen.
- **Klarstellung Padgrößen**: Das Mindest-Landefenster ist eine Untergrenze **je Pad**. Innerhalb eines Levels dürfen **unterschiedlich große Pads gemischt auftreten** (große neben kleinen); größere Pads sind jederzeit erlaubt. Nicht vorschreiben, dass alle Pads eines Levels gleich klein oder gleich groß sind.

## G) Weitere Nachträge des Auftraggebers (vierte Testrunde)
- **Betrag dauerhaft über dem Fahrgast**: vom Erscheinen bis zum Einsteigen und vom Aussteigen bis zum Häuschen; er **tickt herunter** (Zeitfaktor; Gehzeit stärker gewichten, z. B. ×2,5, sonst ändert er sich bei den schnell laufenden Figuren kaum sichtbar). Im HUD zusätzlich der laufende Betrag.
- **Fahrpreis berücksichtigt Entfernung und Schwierigkeit**: längere und schwierigere Wege zahlen etwas mehr (Streckenzuschlag 1,0–1,6 aus Routenlänge, engstem Korridor und Ziel-Landefenster, aus dem Layout berechnet, nicht von Hand).
- **Zufällige Spritpreise je Level** in festem Bereich („nie zu billig, nie zu teuer“); Preise ändern sich **sprunghaft in zufälligen Abständen**, reproduzierbar per Seed. Die **Tankstelle hat eine Zapfsäule mit Preisanzeige**, die man **berühren** kann: Preis steigt sofort; die Anzeige **knickt in 3 Stufen ab**, nach der dritten Berührung **explodiert die Tankstelle** und ist defekt. Der Spieler darf dadurch nie in eine echte Sackgasse geraten (Leben-Verlust gibt ≥ 35 % Sprit, Fortschritt bleibt).

## H) Weitere Nachträge des Auftraggebers (fünfte Testrunde)
Umzusetzen: **Gamepad-Vibration** (Schub, Landung, Kollision, Explosion; Stärke einstellbar); **Sprachzeilen**: Fahrgast-Reaktionen auf Landungen („Wow, sanft!“/„Aua!“), **Tankwart-Stimme** (schimpft bei Berührung der Zapfsäule, kommentiert Preise), **Funk-Dispatcher „Zentrale“** mit Funkfilter in der Weltraumsequenz (dezente Story, Sektor-Intros); **Serie perfekter Landungen** (+5 % je Stufe, max. +30 %, HUD-Anzeige); **Kamera-Gefühl** (Vorausblick, Wackeln, Zeitlupe bei Beinahe-Treffern); **dynamische Musik** je Sektor aus mehreren synchronen Schichten (Basis/Bewegung/Spannung, reagiert auf Spielzustand); **Garage mit Kosmetik** (Lackierungen, Aufkleber, Freischaltungen über Statistiken, Challenge-Look mit Standardtaxi); **Schriften** (Jersey 10, Oxanium, Nunito – OFL, Lizenztexte beilegen); **Pad-Reflexionen**, **Credits-Abspann**, animierter/glänzender Menütitel.
Später, Level für Level: Fahrgasttypen (VIP, zerbrechlich, Gruppe, Notfall), Tankstellen-Ausbau (mehrere Stationen, Reparatur, Sonderangebote), Zufallsereignisse. **Ganz am Ende**: Tagesherausforderung mit festem Seed (Spritpreise nutzen das Seed-System).

## I) M2-Abschluss (sechste Runde)
Zusätzlich zu den Nachträgen oben: **frei belegbare Steuerung** (Tastatur + Gamepad, Tausch bei Konflikten, persistent, robust gegen defekte Dateien; Pause/Menünavigation fest), Optionen in Kategorien mit **V-Sync, FPS-Limit und FPS-Anzeige**, **drei Medaillen je Level** (Zeit, Sauber, Meister) mit Bestzeiten, **Statistik-Seite**, **überspringbare Tutorial-Hinweise**, Tests für Speicherstand-/Einstellungs-Robustheit. Kamera auf den Physik-Takt stellen (sonst Warnung bei Physik-Interpolation).

## J) Nachträge nach dem Anspielen von Sektor 1 (siebte Runde)
- **Medaillen sind Sterne** (HUD-Ergebnisblock, Levelauswahl ★/☆).
- **Dornen** (`^`) sind nur an Flächen erlaubt (Test) und zeigen von der tragenden Fläche weg (Boden = hoch, Decke = runter, Wand = seitlich); sie machen festen Schaden (30 Hülle, 0,5 s Sperre).
- **Einflug beim Levelwechsel** folgt einem hindernisfreien Pfad (`Pathing.arrival_path`, Test je Level); nie quer durch Fels.
- **Fahrgast nach dem Aussteigen** geht auch bei sofortigem Abflug zum Häuschen und wird dort bezahlt (nie zurück ins Taxi).
- **Ökonomie**: Spritpreise ~4× höher und +3 % je Level; Reparatur (2 ¢ je verlorenem Hüllenpunkt, am Levelende) und Ersatztaxi nach Totalschaden (80 ¢ + 2 ¢ je Levelnummer). Credits sind gedeckelt bei 0.
- **Zusatzfahrgäste ab Level 5** („Funkruf“): erscheinen zusätzlich, auch während das Taxi jemanden fährt (ein Sitz), mit Geduld (42–70 s, Balken über dem Betrag); wer zu lange wartet, schimpft und geht. Gleichzeitig wartend: 1 (L5–10), 2 (L11–30), 3 (ab L31). Optional, zählen nicht zum Levelziel. Pause nach dem Absetzen eines Auftrags-Fahrgasts: zufällig 2,5–6 s.
- **HUD** zeigt „Nr/99 Levelname“.
- **Offen (M6)**: eigenes Taskleistensymbol (Fenster-/Projektsymbol).

## K) Nachträge nach der achten Testrunde
- Pfeil und Auftragszeile für den nächsten Fahrgast erst, wenn er erscheint. Falsche Plattform und Schaden mit Fahrgast an Bord: Fahrgast meckert (Sprachzeilen `wrong_pad`, `bumpy`), Fahrpreis sinkt (−15 % bzw. −8 %, max. −50 %).
- Spritpreis bleibt beim Tanken stehen; Tankpads in unterschiedlichen Größen, später schwerer erreichbar.
- Geduld kürzer (Zusatzfahrgäste 20–34 s, Auftrags-Fahrgäste 45–70 s). Schaden früher und stärker: harmlos bis 40 px/s, Sofortzerstörung ab 150 px/s, Exponent 1,3.
- Belohnungen: Auftrags-Fahrpreise ab Level 5 auf 22 %; Zusatzfahrgäste nötig, um im Plus zu bleiben. Spritpreise nicht mehr anfassen.
- **Musik im C64-SID-Klang** (Pulswellen mit PWM, Dreieck, Rauschen, Arpeggien), 32 Takte je Thema, **Themenwechsel alle 5 Level** (21 Themen: Menü + t00..t19), erzeugt mit `tools/audio/gen_music_sid.py`.

## L) Nachträge nach der neunten Testrunde
- Verpasster Pflichtfahrgast: kein Ersatz, Abzug, Tor öffnet nach dem letzten Pflichtfahrgast. Falsche-Plattform-Regel: Abholpad nie falsch; Ausgangs-Fahrgast meckert.
- Menü: „Fortsetzen“ (gespeicherter Feldzug) und „Neues Spiel“. Wimpel mit Plattformzahl statt Laterne; Sprechblase mit Zielplattform nach dem „!“.

## M) Nachträge Runde 10
- Ergebnisansicht nach dem Level bleibt, bis bestätigt wird (Enter/A). Wimpelzahlen kleiner. Replay-Fundament, Punkte.
- **Bewegliche Tore** (Zeichen a–e, `doors` im JSON), Sektor 2 „Neon-Schluchten“ (Level 12–22).
- Mindest-Fahrpreis: profitabel bis 25 % Zufriedenheit. Preise ruhen beim Tanken und bei defekter Zapfsäule. Neues Taxi = voller Tank. Der nächste Fahrgast erscheint nie auf dem Pad, auf dem das Taxi steht (Bot wartet schwebend).
