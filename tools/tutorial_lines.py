"""Sprechertexte des Tutorials (Stimme "d0", Schlüssel tut_*) und der Einspieler für neue Spielelemente (Schlüssel vid_*).
Aufruf über tools/radio_lines.py (schreibt data/voice_lines.json)."""

T = {}
T["tut_welcome"] = ("Willkommen in der Flugschule, Taxi sieben! Ich erkläre dir alles, während du fliegst. Deine Aufgabe: Fahrgäste abholen und sicher zu ihrem Ziel bringen.",
                    "Welcome to flight school, Taxi seven! I will explain everything while you fly. Your job: pick up passengers and bring them safely to their destination.")
T["tut_hud_fuel"] = ("Oben links siehst du deinen Tank. Jede Düse verbraucht Sprit. Ist er leer, ist dein Taxi verloren.",
                     "Top left is your fuel tank. Every thruster burns fuel. When it is empty, your taxi is lost.")
T["tut_hud_hull"] = ("Daneben die Hülle. Aufpralle und Hindernisse beschädigen sie. Bei null ist das Taxi zerstört.",
                     "Next to it is your hull. Impacts and obstacles damage it. At zero the taxi is destroyed.")
T["tut_hud_money"] = ("Hier dein Geld in Credits, und daneben deine Leben. Fünf Taxis hast du, mehr gibt es nie.",
                      "Here is your money in credits, and next to it your lives. You have five taxis, never more.")
T["tut_hud_level"] = ('Rechts vom Tor siehst du das Level und seinen Namen. Daneben zählt, wie viele Pflichtfahrgäste du schon befördert hast und wie viele es insgesamt gibt.',
                      'To the right of the gate you see the level and its name. Next to it counts how many mandatory passengers you have delivered and how many there are in total.')
T["tut_hud_gauge"] = ('Ganz rechts die Landeanzeige: wie schnell du sinkst, wie schnell du seitlich fliegst und wie schief du stehst. Bleiben alle drei Balken unter der weißen Marke, landest du sicher.',
                      'At the far right is the landing gauge: how fast you sink, how fast you move sideways and how tilted you are. Keep all three bars below the white mark and you land safely.')
T["tut_fly"] = ("Los geht's! Du steuerst mit W, A, S und D oder mit dem linken Stick. Flieg jetzt einmal im Uhrzeigersinn durch die grünen Kreise.",
                "Let's go! You steer with W, A, S and D, or with the left stick. Now fly once clockwise through the green circles.")
T["tut_fly_ok"] = ("Gut gemacht. Die Schwerkraft zieht dich ständig nach unten, und Schub kostet Sprit. Gleite lieber, statt dauernd zu schieben.",
                   "Well done. Gravity constantly pulls you down, and thrust burns fuel. Glide instead of pushing all the time.")
T["tut_gear"] = ('Vor jeder Landung fährst du das Fahrwerk wieder aus, mit der Leertaste oder der A-Taste. Dann fliegt das Taxi langsamer und genauer. Fahr es jetzt aus.',
                 'Before every landing you extend the landing gear again, with the space bar or the A button. The taxi then flies slower and more precisely. Extend it now.')
T["tut_fuel_low"] = ("Oh, dein Tank ist fast leer! Flieg zur Tankstelle, der orangen Plattform mit der Zapfsäule, und lande dort.",
                     "Oh, your tank is almost empty! Fly to the gas station, the orange platform with the pump, and land there.")
T["tut_refuel"] = ('Solange du hier stehst, tankst du. Sprit kostet Credits. Nur wenn dein Geld nicht reicht, gibt es ihn bis fünfunddreißig Prozent gratis. Stoße nie gegen die Zapfsäule: Nach drei Berührungen explodiert sie.',
                   'While you sit here, you refuel. Fuel costs credits. Only when you cannot pay, you get it free up to thirty-five percent. Never bump the pump: after three touches it explodes.')
T["tut_landing"] = ('Jetzt zur Landung. Landest du langsam und gerade, ist alles gut. Bist du schneller, nimmt dein Taxi Schaden, und bei zu hohem Tempo ist das Taxi sofort zerstört. Schäden kosten dich am Levelende Reparaturgeld.',
                    'Now for landing. If you land slowly and level, all is well. If you are faster, your taxi takes damage, and at too high a speed the taxi is destroyed at once. Damage costs you repair money at the end of a level.')
T["tut_hard"] = ('Probier es aus: Stürz dich jetzt mit voller Kraft nach unten und lande so hart, dass das Taxi zerstört wird. Hier kostet das nichts.',
                 'Try it: dive down with full power and land so hard that the taxi is destroyed. Here it costs nothing.')
T["tut_job"] = ('Jetzt zum Geschäft. Unten steht dein Auftrag: Mika wartet an Plattform zwei. Der Stern über ihr zeigt: Mika ist ein Pflichtfahrgast. Pflichtfahrgäste sind die Aufträge des Levels, am Anfang zwei oder drei, später bis zu neun. Hast du alle befördert, öffnet sich das Tor. Lande bei Mika mit ausgefahrenem Fahrwerk und warte, bis sie einsteigt.',
                'Now to business. At the bottom is your job: Mika is waiting at platform two. The star above her shows that Mika is a mandatory passenger. Mandatory passengers are the jobs of the level, two or three at first, later up to nine. Deliver them all and the gate opens. Land next to Mika with your gear out and wait for her to board.')
T["tut_pay"] = ("Bring sie zu Plattform drei. Je schneller du bist, desto mehr zahlt sie, der Betrag unten rechts tickt herunter. Weiche Landungen in Folge geben einen Bonus.",
                "Take her to platform three. The faster you are, the more she pays; the amount at the bottom right ticks down. Soft landings in a row earn a bonus.")
T["tut_delivered"] = ("Das war dein erster Fahrpreis. Gut gemacht!", "That was your first fare. Well done!")
T["tut_extra"] = ('Funkruf! Neben den Pflichtfahrgästen rufen optionale Fahrgäste an, hier an Plattform zwei. Sie sind freiwillig und bringen Extrageld, doch dein Taxi hat nur einen Sitz, und sie warten nicht ewig. Flieg hin und nimm den Gast mit.',
                  'Radio call! Besides the mandatory passengers, optional ones call in, here at platform two. They are voluntary and bring extra money, but your taxi has only one seat, and they will not wait forever. Fly over and take the guest along.')
T["tut_life"] = ("Die rosa Plattform ist eine Lebensstation. Landest du dort mit tausend Credits, kaufst du ein Zusatzleben. Du kannst höchstens fünf Leben besitzen. In den ersten vierzig Leveln gibt es sie alle fünf Level, später seltener. Zum Üben leihe ich dir das Geld.",
                 "The pink platform is a life station. Land there with a thousand credits and you buy an extra life. You can have five lives at most. In the first forty levels there is one every fifth level, later less often. I will lend you the money to practice.")
T["tut_exit"] = ("Zum Schluss wartet Odo an Plattform eins. Er will zum Ausgang. Ist der letzte Pflichtfahrgast an Bord, fliegst du mit ihm durch das Tor oben.",
                 "Finally, Odo is waiting at platform one. He wants to go to the exit. With the last mandatory passenger aboard, fly through the gate at the top with him.")
T["tut_countdown"] = ('Pass auf die Uhr unter dem Tor auf! Sobald der letzte Pflichtfahrgast erscheint, läuft der Countdown. Ist er abgelaufen, verlässt du das Level automatisch, der Fahrgast ist weg, und du zahlst eine Strafe. Hier in der Flugschule passiert dir nichts, aber wenn dein Fahrgast drängelt, solltest du dich beeilen.',
                       'Watch the clock below the gate! As soon as the last mandatory passenger appears, the countdown starts. When it runs out, you leave the level automatically, the passenger is gone, and you pay a penalty. Here in flight school nothing happens, but when your passenger gets pushy, hurry up.')
T['tut_eject_again'] = ('Halt, den Gast solltest du nicht abliefern, sondern rauswerfen! Hier kommt der Nächste, an Plattform drei. Nimm ihn mit und wirf ihn mit E oder der Y-Taste raus.',
    'Hold on, you were supposed to throw that guest out, not deliver them! Here comes the next one, at platform three. Pick them up and eject them with E or the Y button.')
T['tut_extra2_again'] = ('Der Gast ist weg. An Plattform drei wartet ein neuer. Nimm ihn mit, die Übung kommt gleich.',
    'That guest is gone. A new one is waiting at platform three. Pick them up, the exercise comes right after.')
T['tut_main_again'] = ('Mika ist nicht angekommen. Sie wartet wieder an Plattform zwei. Hol sie ab und bring sie diesmal heil ans Ziel.',
    'Mika did not make it. She is waiting at platform two again. Pick her up and get her there safely this time.')
T['tut_pump_fix'] = ('Die Zapfsäule ist hin! Ich lasse sie gleich reparieren, aber berühr sie bitte nicht noch mal.',
    'The pump is wrecked! I will have it repaired right away, but please do not touch it again.')
T["tut_gate"] = ("Das Tor ist offen. Flieg hindurch!", "The gate is open. Fly through it!")
T["tut_hud_price"] = ('Und hier der Spritpreis an der Tankstelle. Er schwankt, tanke also möglichst dann, wenn er niedrig ist.',
                      'And here is the fuel price at the gas station. It fluctuates, so refuel when it is low if you can.')
T["tut_gear_in"] = ('Dein Fahrwerk ist noch ausgefahren. Zum Losfliegen fährst du es mit der Leertaste ein, am Controller mit der A-Taste. Eingefahren fliegt das Taxi schnell, ausgefahren langsam und genau. Drück die Taste jetzt.',
                    'Your landing gear is still extended. To take off, retract it with the space bar, or the A button on a controller. Retracted, the taxi flies fast; extended, slow and precise. Press the button now.')
T["tut_credit"] = ('Ab jetzt zahlst du. Wer Credits hat, zahlt jeden Tropfen, auch unter fünfunddreißig Prozent. Ich schreibe dir fünfhundert Credits gut, tank also ruhig voll.',
                   'From now on you pay. If you have credits, you pay for every drop, even below thirty-five percent. I am crediting you five hundred credits, so go ahead and fill up.')
T["tut_price"] = ('Der Spritpreis ändert sich regelmäßig, so wie gerade eben. Achte oben auf die Anzeige. Im Flugunterricht lasse ich ihn jetzt in Ruhe.',
                  'The fuel price changes regularly, just like it did a moment ago. Keep an eye on the display at the top. In flight school I will leave it alone from now on.')
T["tut_crash_ok"] = ('Zerstört! Normalerweise kostet dich das ein Leben, und ein Fahrgast an Bord ist verloren. Hier bekommst du sofort ein neues Taxi.',
                     'Destroyed! Normally that costs you a life, and a passenger on board is lost. Here you get a new taxi right away.')
T["tut_soft"] = ('Und jetzt andersherum: Lande auf Plattform drei so sanft wie möglich, mit ausgefahrenem Fahrwerk und langsam sinkend. Es zählt nur die helle Landeplatte, beide Kufen müssen darauf stehen.',
                 'And now the other way around: land on platform three as gently as you can, with the gear out and sinking slowly. Only the bright landing plate counts, both skids must be on it.')
T["tut_soft_ok"] = ('Wunderbar sanft! Weiche, gerade Landungen in Folge bringen dir einen Bonus auf den Fahrpreis.',
                    'Wonderfully gentle! Soft, level landings in a row earn you a bonus on the fare.')
T["tut_soft_meh"] = ('Das ging, war aber noch nicht weich. Je langsamer du aufsetzt, desto besser. Weiche, gerade Landungen in Folge bringen dir einen Bonus.',
                     'That worked, but it was not soft yet. The slower you touch down, the better. Soft, level landings in a row earn you a bonus.')
T["tut_extra_dest"] = ('Das Ziel des Gastes leuchtet jetzt auf. Bring den Gast dorthin.',
                       "The guest's destination is lit up now. Take the guest there.")
T["tut_extra2"] = ('Noch ein Funkruf! Dieser Quälgeist an Plattform drei hat sich schon die ganze Wartezeit beschwert und weiß natürlich alles besser. Flieg hin und lade ihn ein.',
                   'Another radio call! This pain in the neck at platform three has been complaining the whole time and of course knows better. Fly over and pick them up.')
T["tut_eject"] = ('Und schon geht das Gemecker los: zu schnell, zu wackelig, zu teuer. Dafür gibt es die Rauswurf-Taste: E auf der Tastatur, Y am Controller. Steht das Taxi am Boden, landet der Gast weich und schimpft nur. Aus großer Höhe überlebt er das nicht, und das gibt Ärger mit der Zentrale. Bei Pflichtfahrgästen kostet es obendrein Strafe. Zur Feier des Tages: Wirf ihn jetzt raus!',
                  'And there it goes, the complaining: too fast, too wobbly, too expensive. That is what the eject button is for: E on the keyboard, Y on a controller. If the taxi is on the ground, the guest lands softly and just grumbles. From a great height they will not survive, and that means trouble with dispatch. For mandatory passengers it also costs you a penalty. In honor of the occasion: throw them out now!')
T["tut_eject_ok"] = ('Ruhe an Bord, und die Bewertung leidet nur ein bisschen. Merke dir: Rauswerfen bringt kein Geld, aber manchmal ist Ruhe unbezahlbar.',
                     'Peace and quiet on board, and the rating suffers only a little. Remember: throwing someone out earns no money, but sometimes peace and quiet is priceless.')
T["tut_done"] = ("Geschafft! Du bist bereit für den Dienst. Viel Erfolg da draußen, Taxi sieben.",
                 "Done! You are ready for duty. Good luck out there, Taxi seven.")
T["tut_crash"] = ("Autsch. Keine Sorge, in der Flugschule bekommst du sofort ein neues Taxi.",
                  "Ouch. Do not worry, in flight school you get a new taxi right away.")

# ---- Einspieler (data/intros/index.json: Levelnummer -> Name); Stimme "i0" (Fluglehrer), Schlüssel vid_<name>
V = {}
V["vid_spikes"] = ("Dornen. Sie sitzen auf Felsen und Plattformen. Jede Berührung beschädigt dein Taxi, egal wie langsam du bist. Halte Abstand.",
                   "Spikes. They sit on rocks and platforms. Every touch damages your taxi, no matter how slowly you fly. Keep your distance.")
V["vid_doors"] = ("Schiebetore fahren im Takt von beiden Seiten zu, bleiben kurz geschlossen und öffnen wieder. Warte, bis das Tor offen ist, und flieg zügig hindurch. Erwischt es dich, wirst du hinausgeschleudert, und dein Taxi nimmt Schaden.",
                  "Sliding gates close from both sides on a fixed beat, stay shut briefly and open again. Wait until the gate is open and fly through quickly. If it catches you, you get thrown out and your taxi takes damage.")
V["vid_debris"] = ("Trümmerstücke schweben auf festen Bahnen. Beobachte ihren Rhythmus und flieg durch, wenn die Bahn frei ist. Bei einer Berührung nimmt dein Taxi Schaden.",
                   "Debris drifts along fixed paths. Watch its rhythm and fly through when the path is clear. A touch damages your taxi.")
V["vid_moving_pad"] = ("Fahrende Plattformen gleiten auf Schienen. Fliege über sie, passe dein Tempo an und lande im Tempo der Plattform. Das Taxi fährt mit.",
                       "Moving pads glide on rails. Fly over one, match its speed and land at the pad's own pace. The taxi rides along.")
V["vid_hospital"] = ("Krankentransport: Der Patient liegt auf einer Trage und muss ins Krankenhaus. Jede Beschädigung ist gefährlich. Geht er verloren, kostet das den aktuellen Fahrpreis. Fliege besonders sanft.",
                     "Medical transport: the patient lies on a stretcher and must go to the hospital. Any damage is dangerous. If the patient is lost, it costs you the current fare. Fly extra gently.")
V["vid_meteors"] = ("Meteoriten stürzen auf festen Bahnen herab. Die Bahn blinkt, bevor sie fallen. Bleib fern, bis der Stein vorbei ist. Ein Treffer beschädigt dein Taxi.",
                    "Meteors plunge down fixed lanes. The lane flashes before they fall. Stay clear until the rock has passed. A hit damages your taxi.")
V["vid_slider"] = ("Schieber sind große, schwere Blöcke. Sie quetschen alles, was zwischen ihnen und einer Wand bleibt, und beschädigen dein Taxi schwer. Passiere sie, wenn sie weit genug weg sind.",
                   "Sliders are big, heavy blocks. They crush anything caught between them and a wall and badly damage your taxi. Pass them when they are far enough away.")
V["vid_magnet_pull"] = ("Magnetfelder ziehen dein Taxi zum Kern. Je näher, desto stärker. Steuere rechtzeitig dagegen, sonst landest du im Zentrum.",
                        "Magnetic fields pull your taxi toward the core. The closer, the stronger. Steer against it in time, or you end up in the center.")
V["vid_magnet_push"] = ("Abstoßende Magnete schieben dich fort. Du kommst kaum in die Nähe des Kerns. Nutze den Schub, um dich wegtragen zu lassen.",
                        "Repelling magnets push you away. You barely get near the core. Use the push to be carried away.")
V["vid_magnet_pulse"] = ("Manche Magnete schalten im Takt an und aus. Der Ring um den Kern zeigt dir, wann sie aktiv sind. Flieg durch, wenn sie ruhen.",
                         "Some magnets switch on and off on a beat. The ring around the core shows when they are active. Fly through while they rest.")
V["vid_heat"] = ("Hitzezonen glühen. Solange du darin fliegst, nimmt dein Taxi laufend Schaden. Flieg schnell hindurch oder, besser, um sie herum.",
                 "Heat zones glow. As long as you fly inside, your taxi keeps taking damage. Fly through quickly or, better, around them.")
V["vid_beam"] = ("Plasmastrahlen laden kurz auf und brennen dann. Das Blinken warnt dich. Im Strahl nimmt dein Taxi Schaden. Warte, bis er erlischt, und flieg dann hindurch.",
                 "Plasma beams charge briefly, then burn. The flashing warns you. Inside the beam your taxi takes damage. Wait until it goes out, then fly through.")
V["vid_heat_pulse"] = ("Lavablasen kühlen im Takt ab und glühen wieder auf. Sind sie dunkel, kannst du gefahrlos hindurch. Achte auf den Takt.",
                       "Lava blobs cool down on a beat and glow up again. When they are dark you can pass safely. Watch the beat.")
V["vid_wind"] = ("Strömungen schieben dein Taxi in eine Richtung. Die Schlieren zeigen dir, wohin. Gleiche mit Gegenschub aus.",
                 "Currents push your taxi in one direction. The streaks show you which way. Compensate with counter thrust.")
V["vid_gravity"] = ("Schwerkraftzonen verändern dein Gewicht. In der leichten Zone steigst du von selbst, in der schweren sinkst du. Korrigiere den Schub entsprechend.",
                    "Gravity zones change your weight. In the light zone you rise on your own, in the heavy zone you sink. Adjust your thrust accordingly.")
V["vid_wind_gust"] = ("Böen sind Strömungen, die im Takt an- und ausgehen. Warte die Pause ab oder rechne mit dem Stoß.",
                      "Gusts are currents that switch on and off on a beat. Wait for the pause or expect the push.")
V["vid_traffic"] = ("Verkehr: Fremde Fahrzeuge fliegen auf festen Routen durch Tunnelöffnungen in den Wänden. Bei einer Kollision nimmt dein Taxi Schaden. Warte eine Lücke ab und kreuze die Bahn.",
                    "Traffic: other vehicles fly fixed routes through tunnel openings in the walls. A collision damages your taxi. Wait for a gap and cross the lane.")
V["vid_dark"] = ("Dunkelheit. Nur dein Taxi, die Plattformen und das Tor leuchten. Fahrzeuge, Meteoriten und Strahlen verraten sich durch ihr Licht. Merk dir den Weg.",
                 "Darkness. Only your taxi, the platforms and the gate are lit. Vehicles, meteors and beams give themselves away by their light. Remember the way.")
V["vid_vip"] = ('VIP-Fahrgäste erkennst du an der goldenen Krone. Sie zahlen fast das Doppelte, warten aber nur halb so lange. Harte Landungen und Treffer kosten mit ihnen doppelt so viel. Flieg schnell und sanft.',
               'You can spot VIP passengers by the golden crown. They pay almost double, but only wait half as long. Hard landings and hits cost twice as much with them on board. Fly fast and gently.')
V["vid_emergency"] = ('Notfall: Das rote Kreuz und die Zahl zeigen die Frist in Sekunden. Bring den Fahrgast vorher ans Ziel, dann zahlt er das Doppelte. Läuft die Zeit ab, ist er verloren.',
                     'Emergency: the red cross and the number show the deadline in seconds. Get the passenger to the destination in time and you earn double the fare. If time runs out, the passenger is lost.')
