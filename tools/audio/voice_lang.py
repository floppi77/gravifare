"""Gemeinsame Sprachhilfen der Stimm-Skripte für alle vier Sprachen (de, en, fr, es).
- spoken(text, lang): Ziffern im Sprechtext als Wörter (Französisch/Spanisch; die deutschen und englischen Quellen sind schon ausgeschrieben).
- norm(text, lang): Wortliste für den Vergleich mit der Spracherkennung (Kleinschreibung, ohne Akzente, Zahlen als Wörter).
- check(...): faster-whisper (medium, nur lokale Modelle) gegen den Solltext; ok bei Ähnlichkeit >= Schwelle und ohne Zusatzwörter.
- DIRECTION: Regieanweisungen der Flugschule (Drama 3) aus dem Englischen in Französisch und Spanisch."""
import difflib, os, re, unicodedata
import numpy as np

LANGNAME = {"de": "German", "en": "English", "fr": "French", "es": "Spanish"}
DIG = {"de": ["null", "eins", "zwei", "drei", "vier", "funf", "sechs", "sieben", "acht", "neun"],
       "en": ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"],
       "fr": ["zero", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"],
       "es": ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]}
WORDS = {
    "fr": {"0": "zéro", "1": "un", "2": "deux", "3": "trois", "4": "quatre", "5": "cinq", "6": "six", "7": "sept", "8": "huit", "9": "neuf",
           "10": "dix", "35": "trente-cinq", "60": "soixante", "99": "quatre-vingt-dix-neuf", "500": "cinq cents", "1000": "mille"},
    "es": {"0": "cero", "1": "uno", "2": "dos", "3": "tres", "4": "cuatro", "5": "cinco", "6": "seis", "7": "siete", "8": "ocho", "9": "nueve",
           "10": "diez", "35": "treinta y cinco", "60": "sesenta", "99": "noventa y nueve", "500": "quinientos", "1000": "mil"},
}
PERCENT = {"fr": " pour cent", "es": " por ciento", "de": " prozent", "en": " percent"}

def spoken(text: str, lang: str) -> str:
    if lang not in WORDS:
        return text
    t = re.sub(r"(\d)\s*%", lambda m: m.group(1) + PERCENT[lang], text)
    return re.sub(r"\d+", lambda m: WORDS[lang].get(m.group(0), m.group(0)), t)

def _strip(t: str) -> str:
    t = unicodedata.normalize("NFKD", t.lower())
    return "".join(c for c in t if not unicodedata.combining(c))

def norm(text: str, lang: str) -> list:
    t = re.sub(r"(\d)[\s  .,](\d{3})\b", r"\1\2", text)          # „1 000“, „1.000“ → 1000
    t = re.sub(r"(\d)\s*%", lambda m: m.group(1) + PERCENT.get(lang, ""), t)
    if lang in WORDS:
        t = re.sub(r"\d+", lambda m: WORDS[lang].get(m.group(0), m.group(0)), t)
    t = _strip(t).replace("-", " ").replace("’", " ").replace("'", " ")
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    return [DIG[lang][int(w)] if w.isdigit() and int(w) < 10 else w for w in t.split()]

_asr = None
def check(y, sr, text, lang, threshold=0.88):
    """(ok, erkannt, Ähnlichkeit) – keine Zusatzwörter (Lacher, Stottern), Ähnlichkeit >= threshold."""
    global _asr
    import librosa
    if _asr is None:
        from faster_whisper import WhisperModel
        _asr = WhisperModel(os.environ.get("WHISPER_MODEL_DIR", "medium"), device="cpu", compute_type="int8", local_files_only=True)
    segs, _ = _asr.transcribe(librosa.resample(np.asarray(y, dtype=np.float32), orig_sr=sr, target_sr=16000), language=lang, beam_size=5)
    got, want = norm(" ".join(s.text for s in segs), lang), norm(text, lang)
    sim = difflib.SequenceMatcher(None, "".join(got), "".join(want)).ratio()
    return sim >= threshold and len(got) <= len(want) + 1, " ".join(got), sim

DIRECTION = {
    "[warm and encouraging, like an experienced flight instructor]": ("[chaleureux et encourageant, comme un instructeur de vol expérimenté]", "[cálido y alentador, como un instructor de vuelo experimentado]"),
    "[calm, friendly, like an experienced flight instructor]": ("[calme, aimable, comme un instructeur de vol expérimenté]", "[tranquilo, amable, como un instructor de vuelo experimentado]"),
    "[slow and clear, explanatory, like an experienced flight instructor]": ("[lent et clair, pédagogue, comme un instructeur de vol expérimenté]", "[lento y claro, explicativo, como un instructor de vuelo experimentado]"),
    "[lively and brisk, like an experienced flight instructor]": ("[vif et entraînant, comme un instructeur de vol expérimenté]", "[animado y enérgico, como un instructor de vuelo experimentado]"),
    "[enthusiastic, appreciative, like an experienced flight instructor]": ("[enthousiaste, élogieux, comme un instructeur de vol expérimenté]", "[entusiasta, elogioso, como un instructor de vuelo experimentado]"),
    "[urgent, tense, like an experienced flight instructor]": ("[pressant, tendu, comme un instructeur de vol expérimenté]", "[urgente, tenso, como un instructor de vuelo experimentado]"),
    "[dry, slightly ironic, like an experienced flight instructor]": ("[pince-sans-rire, un peu ironique, comme un instructeur de vol expérimenté]", "[seco, algo irónico, como un instructor de vuelo experimentado]"),
    "[serious and insistent, like an experienced flight instructor]": ("[sérieux et insistant, comme un instructeur de vol expérimenté]", "[serio e insistente, como un instructor de vuelo experimentado]"),
}
# „Schneller als erklärt“ (tut_fast_*): verblüfft und amüsiert, ohne Lachen (Lacher würden die Prüfung durch die Spracherkennung stören).
FAST_DIRECTION = {"de": "[verblüfft und amüsiert, gut gelaunt, wie ein erfahrener Fluglehrer]",
                  "en": "[surprised and amused, good-humored, like an experienced flight instructor]",
                  "fr": "[surpris et amusé, de bonne humeur, comme un instructeur de vol expérimenté]",
                  "es": "[sorprendido y divertido, de buen humor, como un instructor de vuelo experimentado]"}
