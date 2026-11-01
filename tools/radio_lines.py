"""Funksprüche der Zentrale beim Levelwechsel: je Level (2–99) ein eigener Spruch (Level 1 beginnt ohne Übergang).
Wird ein neues Element eingeführt, nimmt der Spruch darauf Bezug; sonst nur Plauderei.
Aufruf: python3 tools/radio_lines.py   -> schreibt data/voice_lines.json (Stimme "d0", Schlüssel r2 … r99)."""
import json

L = {}
# ---- Sektor 1 Sternenhafen (Level 2–11)
L[2] = ("Tankstelle voraus: Landen, tanken, zahlen. Die Preise schwanken.", "Fuel stop ahead: land, refuel, pay. Prices fluctuate.")
L[3] = ("Ein enger Schacht. Gut, dass du Fingerspitzengefühl hast.", "A narrow shaft. Good thing you have a delicate touch.")
L[4] = ("Terrassenlandung. Der Hausmeister bittet um saubere Plattformen.", "Terrace landing. The caretaker asks for clean platforms.")
L[5] = ("Neu: Lebensstationen für tausend Credits. Und Fahrgäste winken jetzt spontan.", "New: life stations for a thousand credits. And passengers now hail you spontaneously.")
L[6] = ("Der Tankwart ist heute gereizt. Rempel seine Zapfsäule nicht an.", "The attendant is cranky today. Do not bump his pump.")
L[7] = ("Rundkurs. Wer im Kreis fliegt, sieht mehr von der Stadt.", "Circuit route. Flying in circles shows more of the city.")
L[8] = ("Achtung, Dornen! Jede Berührung kostet dreißig Hülle.", "Watch out, spikes! Every touch costs thirty hull.")
L[9] = ("Nadelspitzen. Hetz dich nicht, aber trödel auch nicht.", "Needle points. Do not rush, but do not dawdle either.")
L[10] = ("Tanknot gemeldet. Die Tankstelle sitzt hoch oben.", "Fuel emergency reported. The station sits high up.")
L[11] = ("Meisterprüfung. Danach hast du dir einen Kaffee verdient.", "Master exam. Afterwards you have earned a coffee.")
# ---- Sektor 2 Neon-Schluchten (12–22)
L[12] = ("Neon-Schluchten voraus. Eng, hell und voller Verkehr.", "Neon Canyons ahead. Tight, bright and busy.")
L[13] = ("Neonallee. Das Licht ist hübsch, der Abstand zur Wand wichtiger.", "Neon Avenue. The lights are pretty, the distance to the wall matters more.")
L[14] = ("Neu: Schleusentore. Sie schließen im Takt, lass dich nicht einsperren.", "New: lock gates. They close on a beat, do not get trapped.")
L[15] = ("Zwei Schleusen hintereinander. Zähl den Takt mit.", "Two locks in a row. Count the beat.")
L[16] = ("Rushhour in den Schluchten. Alle wollen gleichzeitig irgendwohin.", "Rush hour in the canyons. Everyone wants to go somewhere at once.")
L[17] = ("Doppelte Schleuse, doppelte Geduld.", "Double lock, double patience.")
L[18] = ("Fallgitter! Schnell durch, aber nicht zu schnell.", "Portcullis! Go through fast, but not too fast.")
L[19] = ("Das Neonlabyrinth. Kein Faden, aber ein guter Orientierungssinn.", "The neon labyrinth. No thread, but a good sense of direction.")
L[20] = ("Schleusenkammer. Der Kaffee dort ist übrigens schrecklich.", "Lock chamber. The coffee there is terrible, by the way.")
L[21] = ("Neonfinale. Gleich hast du die Schluchten hinter dir.", "Neon finale. You are almost through the canyons.")
L[22] = ("Glasfassade. Bitte nicht hineinfliegen, das gibt Ärger mit dem Hausmeister.", "Glass facade. Please do not fly into it, the caretaker will complain.")
# ---- Sektor 6 Gezeitenorbit (56–66)
L[56] = ("Gezeitenorbit. Strömungen und wechselnde Schwerkraft, oben und unten sind Ansichtssache.", "Tidal Orbit. Currents and shifting gravity; up and down are a matter of opinion.")
L[57] = ("Hier ziehen die Gezeiten an allem, sogar an deiner Kaffeetasse.", "Tides pull at everything here, even your coffee cup.")
L[58] = ("Die Fahrgäste schwören, der Mond sei heute näher.", "Passengers swear the moon is closer today.")
L[59] = ("Ein Funkloch voraus. Falls du mich nicht hörst: alles gut.", "A radio dead zone ahead. If you cannot hear me: all good.")
L[60] = ("Sechzig Level. Die Zentrale ist stolz auf dich.", "Sixty levels. Dispatch is proud of you.")
L[61] = ("Die Tankpreise tanzen mit den Gezeiten. Beobachte die Anzeige.", "Fuel prices dance with the tides. Watch the display.")
L[62] = ("Ein Fahrgast fragt, ob man hier schwimmen darf. Nein.", "A passenger asks if one may swim here. No.")
L[63] = ("Gegenstrom voraus, aber du kennst ja deine Düsen.", "Counter current ahead, but you know your thrusters.")
L[64] = ("Der Kapitän der Orbitalfähre grüßt dich mit der Hupe.", "The orbital ferry captain greets you with the horn.")
L[65] = ("Bald ist das Wasser hinter dir. Halte noch durch.", "The water is almost behind you. Hold on a little longer.")
L[66] = ("Letztes Level der Gezeiten. Gleich geht es zum Knotenpunkt.", "Last tidal level. Next stop: the hub.")
# ---- Sektor 7 Transitknoten (67–77)
L[67] = ("Transitknoten. Viel Verkehr, Schleusen und Routen. Bleib höflich.", "Transit Hub. Heavy traffic, locks and routes. Be polite.")
L[68] = ("Die Lichtbahnen sind nur Dekoration. Meistens.", "The light lanes are only decoration. Mostly.")
L[69] = ("Der Knoten meldet Stau auf Ebene drei.", "The hub reports a jam on level three.")
L[70] = ("Ein Fahrgast hat sein Gepäck vergessen und kauft einfach neues.", "A passenger forgot their luggage and simply buys new.")
L[71] = ("Die Zentrale hat die Kaffeemaschine repariert. Fast.", "Dispatch fixed the coffee machine. Almost.")
L[72] = ("Hupen ist im Weltraum verboten, nützt aber ohnehin nichts.", "Honking is banned in space, and pointless anyway.")
L[73] = ("Du bist heute wunderbar im Takt, Taxi sieben.", "You are wonderfully on the beat today, Taxi seven.")
L[74] = ("Ein Kollege winkt dir von der Nachbarbahn zu.", "A colleague waves at you from the next lane.")
L[75] = ("Die Station vermisst dein Lächeln. Und die Rechnung.", "The station misses your smile. And the invoice.")
L[76] = ("Fast am Ende des Knotens. Halte die Spur.", "Nearly out of the hub. Keep your lane.")
L[77] = ("Letzter Knoten. Danach wird es dunkel.", "Last hub level. After that it gets dark.")
# ---- Sektor 8 Schattenring (78–88)
L[78] = ("Schattenring. Hier ist es dunkel, nur Lichter von Hütten und Fahrzeugen. Melde dich regelmäßig.", "Shadow Ring. It is dark here, only lights from huts and vehicles. Check in regularly.")
L[79] = ("Hier ist es dunkel. Schalte im Kopf das Licht an.", "It is dark here. Turn on the lights in your head.")
L[80] = ("Meteoriten und Strahlen leuchten schwach. Such sie, bevor sie dich finden.", "Meteors and beams glow faintly. Spot them before they find you.")
L[81] = ("Ein Schatten bewegt sich. Wahrscheinlich nur ein Fahrgast.", "A shadow moves. Probably just a passenger.")
L[82] = ("Der Ring ist still. Zu still, wenn du mich fragst.", "The ring is quiet. Too quiet, if you ask me.")
L[83] = ("Im Dunkeln siehst du nur dein Scheinwerferlicht: dich. Sehr gut.", "In the dark you only see your own headlight: you. Very good.")
L[84] = ("Kein Stress, aber der Ring wird nicht heller.", "No stress, but the ring is not getting any brighter.")
L[85] = ("Ein Fahrgast bittet um eine Taschenlampe. Ich fürchte, nein.", "A passenger asks for a flashlight. I am afraid not.")
L[86] = ("Du fliegst wie im Schlaf. Bitte wach bleiben.", "You fly as if asleep. Please stay awake.")
L[87] = ("Gleich siehst du wieder Sterne. Echte.", "Soon you will see stars again. Real ones.")
L[88] = ("Letztes Level im Schatten. Danach das Finale.", "Last level in the shadow. Then the finale.")
# ---- Sektor 9 Singularitätsrand (89–99)
L[89] = ("Singularitätsrand. Alle Systeme gleichzeitig. Jetzt zählt jede Sekunde.", "Singularity Edge. All systems at once. Every second counts now.")
L[90] = ("Die Zeit läuft hier langsamer. Deine Rechnung nicht.", "Time runs slower here. Your invoice does not.")
L[91] = ("Das Licht biegt sich. Bleib trotzdem auf Kurs.", "Light bends here. Stay on course anyway.")
L[92] = ("Die Zentrale hält den Atem an.", "Dispatch is holding its breath.")
L[93] = ("Ein Fahrgast fragt, ob das ein Wurmloch ist. Bitte nicht.", "A passenger asks if that is a wormhole. Please, no.")
L[94] = ("Du bist der beste Pilot, den die Zentrale je hatte. Sag es keinem.", "You are the best pilot dispatch ever had. Tell no one.")
L[95] = ("Alle Instrumente zittern, deine Hände hoffentlich nicht.", "All instruments tremble, hopefully not your hands.")
L[96] = ("Nur noch wenige Level, Taxi sieben.", "Only a few levels left, Taxi seven.")
L[97] = ("Der Rand wird enger. Dein Können nicht.", "The edge grows narrow. Your skill does not.")
L[98] = ("Das vorletzte Level. Atme tief durch.", "The second to last level. Take a deep breath.")
L[99] = ("Letztes Level. Zeig, was du kannst, Taxi sieben.", "Final level. Show them what you've got, Taxi seven.")

# ---- Sektor 3–5 (Level 23–55): werden nach dem endgültigen Aufbau der Level ergänzt
try:
    from radio_lines_s345 import L345
    L.update(L345)
except ImportError:
    pass


def main():
    d = json.load(open("data/voice_lines.json"))
    d["d0"] = {"de": {"r%d" % n: v[0] for n, v in sorted(L.items())}, "en": {"r%d" % n: v[1] for n, v in sorted(L.items())}}
    try:
        from tutorial_lines import T, V
        d["i0"] = {"de": {}, "en": {}}              # Fluglehrer (Tutorial, Einspieler): eigene Stimme
        for k, v in list(T.items()) + list(V.items()):
            d["i0"]["de"][k] = v[0]
            d["i0"]["en"][k] = v[1]
    except ImportError:
        pass
    d["d0"]["de"]["patient_lost"] = "Patient verloren. Das wird teuer."
    d["d0"]["en"]["patient_lost"] = "Patient lost. That will be expensive."
    json.dump(d, open("data/voice_lines.json", "w"), indent=1, ensure_ascii=False)
    missing = [n for n in range(2, 100) if n not in L]
    print("Zeilen:", len(L), "fehlend:", missing)


if __name__ == "__main__":
    import sys
    sys.path.insert(0, "tools")
    main()
