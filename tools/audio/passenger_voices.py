"""Gemeinsame Beschreibung der zehn zusätzlichen Fahrgast-Stimmen (f2–f6 weiblich, m2–m6 männlich), je Sprache.
Jede Stimme ist eine frei beschriebene Kunststimme (keine reale Person): Qwen3-TTS VoiceDesign erzeugt daraus eine kurze Referenzaufnahme
(tools/audio/gen_passenger_refs.py), Fish Audio Drama 3 spricht damit alle Fahrgast-Zeilen (tools/audio/gen_voice_drama_passengers.py).
Alter, Tonlage und Klangfarbe sind bewusst weit gestreut und weichen von den vier Qwen-Stimmen f0, f1, m0, m1 ab."""

REF_TEXT = {
    "de": "Guten Tag! Ich möchte heute noch ankommen, also fliegen Sie bitte zügig, aber sicher. Vielen Dank, dass Sie mich mitnehmen.",
    "en": "Good day! I would like to arrive today, so please fly quickly but safely. Thank you very much for taking me along.",
    "fr": "Bonjour ! J’aimerais arriver aujourd’hui, alors volez vite, mais prudemment. Merci beaucoup de m’emmener.",
    "es": "¡Buenos días! Me gustaría llegar hoy, así que vuele rápido, pero con cuidado. Muchas gracias por llevarme.",
}
LANGNAME = {"de": "German", "en": "English", "fr": "French", "es": "Spanish"}

_DE_TAIL = " Deutsche Muttersprachlerin, akzentfreies Standarddeutsch mit deutscher Aussprache."
_DE_TAIL_M = " Deutscher Muttersprachler, akzentfreies Standarddeutsch mit deutscher Aussprache."
_EN_TAIL = " Native English speaker with a neutral accent."

# Stimme -> {Sprache: (Beschreibung, Seed)}; gleiche Figur in beiden Sprachen.
VOICES = {
    "f2": {"de": ("Ein Mädchen von etwa siebzehn Jahren mit heller, hoher, aufgeregter Stimme, schnell und lebhaft, ein wenig kichernd." + _DE_TAIL, 1102),
           "en": ("A girl of about seventeen with a bright, high, excited voice, fast and lively, a little giggly." + _EN_TAIL, 1102),
           "fr": ("Une adolescente d’environ dix-sept ans à la voix claire, aiguë et excitée, rapide et vive, un peu rieuse. Locutrice native française, accent standard de France.", 1102),
           "es": ("Una chica de unos diecisiete años con voz clara, aguda y emocionada, rápida y vivaz, un poco risueña. Hablante nativa de español de España, acento castellano neutro.", 1102)},
    "f3": {"de": ("Eine Frau Ende zwanzig mit tiefer, rauchiger Altstimme, langsam, cool und gelassen, leicht spöttisch." + _DE_TAIL, 1103),
           "en": ("A woman in her late twenties with a deep, smoky alto voice, slow, cool and laid-back, slightly mocking." + _EN_TAIL, 1103),
           "fr": ("Une femme de presque trente ans à la voix d’alto grave et voilée, lente, cool et détendue, un peu moqueuse. Locutrice native française, accent standard de France.", 1103),
           "es": ("Una mujer de casi treinta años con voz de contralto grave y ahumada, lenta, tranquila y relajada, algo burlona. Hablante nativa de español de España, acento castellano neutro.", 1103)},
    "f4": {"de": ("Eine Geschäftsfrau Mitte vierzig mit klarer, fester, leicht nasaler Stimme, mittlere Tonlage, bestimmt und zügig, immer in Eile." + _DE_TAIL, 1104),
           "en": ("A businesswoman in her mid-forties with a clear, firm, slightly nasal voice, medium pitch, decisive and brisk, always in a hurry." + _EN_TAIL, 1104),
           "fr": ("Une femme d’affaires d’environ quarante-cinq ans à la voix claire, ferme, légèrement nasale, tessiture moyenne, décidée et rapide, toujours pressée. Locutrice native française, accent standard de France.", 1104),
           "es": ("Una mujer de negocios de unos cuarenta y cinco años con voz clara, firme, algo nasal, tono medio, decidida y rápida, siempre con prisa. Hablante nativa de español de España, acento castellano neutro.", 1104)},
    "f5": {"de": ("Eine ältere Dame Anfang siebzig mit warmer, leicht brüchiger, zittriger Stimme, langsam und gütig, mittelhohe Lage." + _DE_TAIL, 1105),
           "en": ("An elderly lady in her early seventies with a warm, slightly cracked, trembling voice, slow and kindly, medium-high pitch." + _EN_TAIL, 1105),
           "fr": ("Une dame âgée d’un peu plus de soixante-dix ans à la voix chaleureuse, légèrement cassée et tremblante, lente et bienveillante, assez aiguë. Locutrice native française, accent standard de France.", 1105),
           "es": ("Una señora mayor de algo más de setenta años con voz cálida, algo quebrada y temblorosa, lenta y bondadosa, tono medio-alto. Hablante nativa de español de España, acento castellano neutro.", 1105)},
    "f6": {"de": ("Eine Frau um die dreißig mit weicher, hauchiger, sanfter Stimme, mittelhoch, ruhig und verträumt." + _DE_TAIL, 1106),
           "en": ("A woman around thirty with a soft, breathy, gentle voice, medium-high pitch, calm and dreamy." + _EN_TAIL, 1106),
           "fr": ("Une femme d’une trentaine d’années à la voix douce, soufflée et tendre, assez aiguë, calme et rêveuse. Locutrice native française, accent standard de France.", 1106),
           "es": ("Una mujer de unos treinta años con voz suave, susurrante y dulce, tono medio-alto, tranquila y soñadora. Hablante nativa de español de España, acento castellano neutro.", 1106)},
    "m2": {"de": ("Ein junger Mann von etwa neunzehn Jahren mit heller Tenorstimme, aufgeregt und jugendlich, schnell, ein bisschen lässig." + _DE_TAIL_M, 1202),
           "en": ("A young man of about nineteen with a bright tenor voice, excited and youthful, fast, a little casual." + _EN_TAIL, 1202),
           "fr": ("Un jeune homme d’environ dix-neuf ans à la voix de ténor claire, excitée et juvénile, rapide, un peu nonchalante. Locuteur natif français, accent standard de France.", 1202),
           "es": ("Un chico de unos diecinueve años con voz de tenor clara, emocionada y juvenil, rápida, algo despreocupada. Hablante nativo de español de España, acento castellano neutro.", 1202)},
    "m3": {"de": ("Ein Mann Anfang vierzig mit sehr tiefer, dröhnender Bassstimme, langsam und gemütlich, kräftig und warm." + _DE_TAIL_M, 1203),
           "en": ("A man in his early forties with a very deep, booming bass voice, slow and easygoing, powerful and warm." + _EN_TAIL, 1203),
           "fr": ("Un homme d’une quarantaine d’années à la voix de basse très grave et tonnante, lente et débonnaire, puissante et chaleureuse. Locuteur natif français, accent standard de France.", 1203),
           "es": ("Un hombre de unos cuarenta años con voz de bajo muy grave y retumbante, lenta y campechana, potente y cálida. Hablante nativo de español de España, acento castellano neutro.", 1203)},
    "m4": {"de": ("Ein Mann Ende zwanzig mit heller, leicht nasaler Stimme, schnell, nervös und witzig, sprunghaft." + _DE_TAIL_M, 1204),
           "en": ("A man in his late twenties with a bright, slightly nasal voice, fast, nervous and witty, jumpy." + _EN_TAIL, 1204),
           "fr": ("Un homme de presque trente ans à la voix claire, légèrement nasale, rapide, nerveuse et drôle, sautillante. Locuteur natif français, accent standard de France.", 1204),
           "es": ("Un hombre de casi treinta años con voz clara, algo nasal, rápida, nerviosa y graciosa, inquieta. Hablante nativo de español de España, acento castellano neutro.", 1204)},
    "m5": {"de": ("Ein Mann Mitte vierzig mit glatter, klarer Sprecherstimme, mittlere Lage, souverän und präzise betont, wie ein Nachrichtensprecher." + _DE_TAIL_M, 1205),
           "en": ("A man in his mid-forties with a smooth, clear announcer voice, medium pitch, confident and precisely emphasized, like a newsreader." + _EN_TAIL, 1205),
           "fr": ("Un homme d’environ quarante-cinq ans à la voix de présentateur lisse et claire, tessiture moyenne, assurée et précise, comme un présentateur de journal. Locuteur natif français, accent standard de France.", 1205),
           "es": ("Un hombre de unos cuarenta y cinco años con voz de locutor suave y clara, tono medio, segura y de entonación precisa, como un presentador de noticias. Hablante nativo de español de España, acento castellano neutro.", 1205)},
    "m6": {"de": ("Ein sehr alter Mann von etwa achtzig Jahren mit dünner, brüchiger Stimme, langsam, warm und ein wenig schwerhörig laut." + _DE_TAIL_M, 1206),
           "en": ("A very old man of about eighty with a thin, cracked voice, slow, warm and a little loud as if hard of hearing." + _EN_TAIL, 1206),
           "fr": ("Un très vieil homme d’environ quatre-vingts ans à la voix fine et cassée, lente, chaleureuse et un peu forte, comme s’il entendait mal. Locuteur natif français, accent standard de France.", 1206),
           "es": ("Un hombre muy mayor de unos ochenta años con voz fina y quebrada, lenta, cálida y algo alta, como si oyera mal. Hablante nativo de español de España, acento castellano neutro.", 1206)},
}
# Zielbereich der mittleren Grundfrequenz (Hz, Median) der Referenz: gen_passenger_refs.py wählt unter mehreren Kandidaten den passenden.
TARGET_F0 = {"f2": (310, 400), "f3": (180, 225), "f4": (240, 285), "f5": (200, 250), "f6": (260, 310),
             "m2": (190, 240), "m3": (85, 115), "m4": (170, 210), "m5": (115, 145), "m6": (140, 185)}
FEMALE = ["f2", "f3", "f4", "f5", "f6"]
MALE = ["m2", "m3", "m4", "m5", "m6"]

# Regieanweisung je Zeile (Drama 3 versteht Klammern am Satzanfang); Sprache der Anweisung = Sprache der Zeile.
def direction(key: str, lang: str) -> str:
    de = {"call": "[rufend, freundlich, winkend]", "thanks": "[dankbar, warm]", "angry": "[wütend, schimpfend]",
          "soft": "[erstaunt, erleichtert]", "hard": "[schmerzerfüllt, erschrocken]", "bored": "[genervt, ungeduldig]",
          "wrong_pad": "[verärgert, bestimmt]", "bumpy": "[besorgt, ängstlich]", "hurry": "[drängend, eilig]"}
    en = {"call": "[calling out, friendly, waving]", "thanks": "[grateful, warm]", "angry": "[furious, scolding]",
          "soft": "[amazed, relieved]", "hard": "[pained, startled]", "bored": "[annoyed, impatient]",
          "wrong_pad": "[irritated, firm]", "bumpy": "[worried, anxious]", "hurry": "[urgent, rushed]"}
    fr = {"call": "[en appelant, aimable, en faisant signe]", "thanks": "[reconnaissant, chaleureux]", "angry": "[furieux, en grondant]",
          "soft": "[étonné, soulagé]", "hard": "[douloureux, effrayé]", "bored": "[agacé, impatient]",
          "wrong_pad": "[irrité, ferme]", "bumpy": "[inquiet, anxieux]", "hurry": "[pressant, pressé]"}
    es = {"call": "[llamando, amable, saludando]", "thanks": "[agradecido, cálido]", "angry": "[furioso, regañando]",
          "soft": "[asombrado, aliviado]", "hard": "[dolorido, asustado]", "bored": "[molesto, impaciente]",
          "wrong_pad": "[irritado, firme]", "bumpy": "[preocupado, nervioso]", "hurry": "[apremiante, con prisa]"}
    d = {"de": de, "en": en, "fr": fr, "es": es}[lang]
    base = key.rsplit("_", 1)[0] if key.startswith("hurry_") else key
    if key.startswith("dest_"):
        return {"de": "[freundlich, klar]", "en": "[friendly, clear]", "fr": "[aimable, clair]", "es": "[amable, claro]"}[lang]
    return d.get(base, "")
