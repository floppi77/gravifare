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
