class_name Overtime
extends RefCounted
## Sonderschicht (Roguelike): ein Lauf über 9, 18 oder 27 Etappen (je Sektor 1, 2 oder 3 der handgemachten Level, Sektoren aufsteigend).
## Vor jeder Etappe eine Kreuzung mit 3 Aufträgen (Karte + Zwischenfälle + Lohn), alle drei Etappen ein Werkstatt-Halt mit Ausstattung.
## Nichts davon erzeugt Level: Zufällig sind nur Auswahl, Reihenfolge, Zwischenfälle und Angebote (Seed frei wählbar).
## Reine Logik über einem Zustands-Dictionary (speicherbar, testbar ohne Autoloads). Ausstattung, Zwischenfälle und Lizenzen: data/overtime.json.

const DATA_PATH := "res://data/overtime.json"
const BLOCK_PATH := "res://data/overtime_block.json"     # Ergebnis von tools/overtime_check.gd: Zwischenfälle, mit denen der Autopilot ein Level nicht mehr schafft
const LENGTHS := {"short": 1, "medium": 2, "long": 3}    # Etappen je Sektor
const LENGTH_ORDER := ["short", "medium", "long"]
const SECTORS := 9
const START_TAXIS := 3
const MAX_TAXIS := Tuning.MAX_LIVES
const HALT_EVERY := 3                  # Werkstatt-Halt nach jeder dritten Etappe (nicht nach der letzten)
const UNLOCK_SECTORS := 6              # freigeschaltet, wenn alle Level der Sektoren 1–6 einmal geschafft sind
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"     # ohne 0/O, 1/I: lässt sich ablesen und per Pad eintippen
const CODE_LEN := 6

# Kreuzung
const OFFERS := 3
const FARE_PER_CURSE := 0.12           # Lohn: +12 % Fahrpreis je Zwischenfall der Etappe
const RISK_PER_CURSE := 0.25           # Wertung: +25 % Etappenpunkte je Zwischenfall
const PACT_FROM := 2                   # Pakte ab der dritten Kreuzung …
const PACT_CHANCE := 0.15              # … mit dieser Wahrscheinlichkeit (ersetzt den mittleren Auftrag)
const BRIBE_BASE := 250                # Schmiergeld: Zwischenfall streichen für 250 × Sektor Credits (einmal je Kreuzung)

# Werkstatt-Halt
const SHOP_SLOTS := 4
const PRICE := {"c": 600, "r": 1300, "l": 2600}
const PRICE_HALT_STEP := 0.15          # je weiterem Halt +15 %
const PRICE_OWNED_STEP := 0.05         # je schon eingebauter Stufe +5 % (Schneeball: möglich, aber teurer)
const HAGGLE_STEP := 0.15
const REROLL_PRICE := 150              # Neu würfeln im Halt ohne Marke: 150, 300, 600 …
const WEIGHT := {"c": 60.0, "r": 30.0, "l": 10.0}
const LEGEND_FROM_HALT := 2            # legendäre Teile erst ab dem zweiten Halt (und an Pakten/Prämien ab Etappe 6)
const SALARY := 100                    # Grundgehalt je Stufe und Etappe, je Sektor +25 %
const INTEREST := 0.06                 # Zinsen am Halt: 6 % des Guthabens …
const INTEREST_MAX := 600              # … höchstens 600
const AUDIT_RATE := 0.15               # Steuerprüfung: 15 % des Guthabens über 500
const AUDIT_FREE := 500
const GOLDEN_STEP := 0.015             # Goldenes Taxameter: +1,5 % Fahrpreis je geschaffter Etappe
const RISK_PERK_STEP := 0.10           # Risikoprämie: +10 % Fahrpreis je Zwischenfall der Etappe
const RESERVE_FUEL := 15.0

# Wertung
const TAXI_POINTS := 300               # je übrigem Taxi am Ende
const FINISH_BONUS := 0.20             # alle Etappen geschafft: +20 % der Etappenpunkte
const STAGE_STEP := 0.10               # je Überstunden-Stufe +10 % auf alles
const XP_DIV := 25.0                   # Erfahrung = Punkte / 25
const BOARD_SIZE := 10
const STAGE_MAX := 10
const RANK_XP := [0, 150, 400, 750, 1200, 1800, 2500, 3400, 4500, 5800, 7300, 9000, 11000]

## Wirkungen: Grundwert und erlaubter Bereich (Ausstattung stapelt additiv, Zwischenfälle ebenso; danach begrenzt). Die Physikgrenzen halten die
## handgemachten Level fair: Der Autopilot prüft sie mit Serientaxi, zu viel Schub oder Dämpfung würde sie trivial machen.
const FX := {
	"thrust_k": [1.0, 0.7, 1.15], "side_k": [1.0, 0.7, 1.2], "down_k": [1.0, 1.0, 1.3], "drag_k": [1.0, 0.4, 1.3], "gear_time_k": [1.0, 0.5, 3.0],
	"land_tilt": [0.0, 0.0, 0.06], "land_vx": [0.0, 0.0, 8.0], "land_vy": [0.0, 0.0, 9.0], "impact_safe": [0.0, 0.0, 12.0], "burn": [1.0, 0.75, 1.5],
	"damage": [1.0, 0.7, 1.2], "heat_k": [1.0, 0.5, 1.0], "mover_k": [1.0, 0.6, 1.0], "spike_shield": [0.0, 0.0, 1.0], "overheat": [0.0, 0.0, 1.0],
	"leak": [0.0, 0.0, 0.5], "heavy_k": [1.0, 0.8, 1.0], "soft_add": [0.0, 0.0, 4.0], "fuel_cap": [1.0, 1.0, 1.3],
	"fare_add": [0.0, -0.5, 1.0], "tip_add": [0.0, 0.0, 2.0], "tip_k": [1.0, 1.0, 1.5], "repair_k": [1.0, 0.0, 3.0], "taxi_fee_k": [1.0, 0.0, 5.0],
	"fuel_price_k": [1.0, 0.6, 1.0], "refuel_k": [1.0, 1.0, 1.6], "patience_k": [1.0, 0.8, 1.4], "deadline_k": [1.0, 1.0, 1.2], "missed_k": [1.0, 0.5, 1.0],
	"walk_k": [1.0, 0.5, 1.0], "vip_k": [1.0, 1.0, 2.0], "tmax": [0.0, 0.0, 0.2], "pen_k": [1.0, 0.5, 1.0], "combo_k": [1.0, 1.0, 2.0],
	"reserve": [0.0, 0.0, 1.0], "seat": [0.0, 0.0, 1.0], "self_repair": [0.0, 0.0, 2.0], "extra_add": [0.0, 0.0, 1.0],
	"picky": [0.0, 0.0, 1.0], "cash": [0.0, 0.0, 1.0], "pump_cycle": [0.0, 0.0, 1.0], "audit": [0.0, 0.0, 1.0], "newroute": [0.0, 0.0, 1.0],
	"ui_nolight": [0.0, 0.0, 1.0], "ui_nomarker": [0.0, 0.0, 1.0], "ui_shaky": [0.0, 0.0, 1.0], "no_life": [0.0, 0.0, 1.0],
	"scanner": [0.0, 0.0, 1.0], "luck": [0.0, -1.0, 2.0], "bribe": [0.0, 0.0, 1.0], "haggle": [0.0, 0.0, 2.0], "salary": [0.0, 0.0, 3.0],
	"golden": [0.0, 0.0, 1.0], "chain": [0.0, 0.0, 1.0], "risk": [0.0, 0.0, 1.0], "interest": [0.0, 0.0, 1.0], "bonus_k": [1.0, 1.0, 1.5],
	"shop_k": [1.0, 1.0, 2.0], "min_curse": [0.0, 0.0, 1.0], "more_curse": [0.0, 0.0, 1.0], "shop_less": [0.0, 0.0, 1.0],
}

## Überstunden-Stufen (nach einem geschafften Lauf jeweils die nächste frei; wirken zusammen, jede +10 % Wertung).
const STAGES := [
	{"shop_k": 0.15}, {"min_curse": 1}, {"taxis": -1}, {"fare_add": -0.10}, {"repair_k": 1.0},
	{"luck": -1}, {"more_curse": 1}, {"taxi_fee_k": 2.0}, {"shop_less": 1}, {"no_life": 1},
]

static var _data: Dictionary = {}
static var _block: Dictionary = {}
static var _level_info: Dictionary = {}

# --------------------------------------------------------------------------- Katalog

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
		var b := FileAccess.open(BLOCK_PATH, FileAccess.READ)
		if b != null:
			var bd = JSON.parse_string(b.get_as_text())
			if bd is Dictionary:
				_block = bd.get("block", {}) if bd.get("block", {}) is Dictionary else {}
	return _data

static func perks() -> Array:
	return data().get("perks", [])

static func curses() -> Array:
	return data().get("curses", [])

static func licenses() -> Array:
	return data().get("licenses", [])

static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if String(e.get("id", "")) == id:
			return e
	return {}

static func perk(id: String) -> Dictionary:
	return _find(perks(), id)

static func curse(id: String) -> Dictionary:
	return _find(curses(), id)

static func license(id: String) -> Dictionary:
	return _find(licenses(), id)

static func pact_pool() -> Array:
	return data().get("pacts", [])

## Zwischenfälle, mit denen das Level für den Autopiloten unlösbar wird (siehe tools/overtime_check.gd).
static func blocked(curse_id: String, level_id: String) -> bool:
	data()
	var list = _block.get(curse_id, [])
	return list is Array and (list as Array).has(level_id)

# --------------------------------------------------------------------------- Seed

static func code_of(seed: int) -> String:
	var s := absi(seed)
	var out := ""
	for i in CODE_LEN:
		out = CODE_ALPHABET[s % CODE_ALPHABET.length()] + out
		s /= CODE_ALPHABET.length()
	return out

## Seed aus einem Code (Groß-/Kleinschreibung egal, Verwechsler 0→O… werden angeglichen); -1, wenn der Code ungültig ist.
static func seed_of(code: String) -> int:
	var c := code.strip_edges().to_upper().replace("0", "O").replace("1", "I")
	if c.length() != CODE_LEN:
		return -1
	var s := 0
	for ch in c:
		var i := CODE_ALPHABET.find(ch)
		if i < 0:
			return -1
		s = s * CODE_ALPHABET.length() + i
	return s

static func random_code(rng: RandomNumberGenerator) -> String:
	var max_seed := int(pow(CODE_ALPHABET.length(), CODE_LEN))
	return code_of(rng.randi() % max_seed)

static func _rng(st: Dictionary, salt: String, n := 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(("%d:%s:%d" % [int(st.get("seed", 0)), salt, n]).hash())
	return r

# --------------------------------------------------------------------------- Lauf

static func per_sector(length: String) -> int:
	return int(LENGTHS.get(length, 1))

static func total(st: Dictionary) -> int:
	return SECTORS * per_sector(String(st.get("length", "short")))

static func sector_of(st: Dictionary, etappe: int) -> int:
	return clampi(etappe / per_sector(String(st.get("length", "short"))) + 1, 1, SECTORS)

## Neuer Lauf. `meta` ist der Fortschritt der Sonderschicht (Dienstgrad, Stufen); Lizenz und Stufe müssen freigeschaltet sein.
static func new_run(seed: int, length: String, license_id: String, stage: int, meta: Dictionary) -> Dictionary:
	if not LENGTHS.has(length):
		length = "short"
	var r := rank_of(int(meta.get("xp", 0)))
	var lic := license(license_id)
	if lic.is_empty() or int(lic.get("rank", 0)) > r:
		license_id = "standard"
		lic = license("standard")
	stage = clampi(stage, 0, mini(STAGE_MAX, int(meta.get("stage_max", 0))))
	var st := {"version": 1, "seed": seed, "code": code_of(seed), "length": length, "license": license_id, "stage": stage, "rank": r,
		"etappe": 0, "phase": "cross", "level": "", "used": [], "perks": {}, "pacts": [], "curses": [], "offer": {}, "results": [],
		"credits": float(start_capital(r)), "fuel": Tuning.FUEL_MAX, "lives": START_TAXIS, "carry": {}, "tokens": start_tokens(r),
		"angel": 0, "streak": 0, "rerolls": {}, "shop": [], "shop_rolls": 0, "halts": 0, "bribed": -1, "reward": "", "audit_due": false,
		"log": [], "over": false, "done": false}
	for pid in lic.get("perks", {}):
		_add_perk(st, String(pid), int(lic.perks[pid]))
	st.lives = clampi(START_TAXIS + int(lic.get("lives", 0)) + int(_stage_sum(stage, "taxis")), 1, MAX_TAXIS)
	return st

static func start_capital(r: int) -> int:
	return mini(700, 100 * (r / 2))

static func start_tokens(r: int) -> int:
	return (1 if r >= 4 else 0) + (1 if r >= 10 else 0)

static func _stage_sum(stage: int, key: String) -> float:
	var v := 0.0
	for i in mini(stage, STAGES.size()):
		v += float(STAGES[i].get(key, 0.0))
	return v

static func stack(st: Dictionary, id: String) -> int:
	return int((st.get("perks", {}) as Dictionary).get(id, 0))

## Ausstattung einbauen (Verbrauchsteile wirken sofort: Ersatztaxi, Würfel, Schutzengel).
static func _add_perk(st: Dictionary, id: String, n := 1) -> void:
	var p := perk(id)
	if p.is_empty():
		return
	for i in n:
		match id:
			"spare":
				st.lives = mini(MAX_TAXIS, int(st.lives) + 1)
			"dice":
				st.tokens = int(st.tokens) + 2
			"angel":
				st.angel = int(st.angel) + 1
		st.perks[id] = mini(int(p.get("max", 1)), stack(st, id) + 1)

static func is_last(st: Dictionary) -> bool:
	return int(st.etappe) >= total(st)

# --------------------------------------------------------------------------- Wirkungen

## Alle Wirkungen der laufenden Etappe: Ausstattung, Lizenz, Pakte, Zwischenfälle der Etappe und Überstunden-Stufe, begrenzt nach FX.
static func effects(st: Dictionary) -> Dictionary:
	var add := {}
	for id in st.get("perks", {}):
		_put(add, perk(String(id)).get("fx", {}), float(st.perks[id]))
	_put(add, license(String(st.get("license", "standard"))).get("fx", {}), 1.0)
	for i in mini(int(st.get("stage", 0)), STAGES.size()):
		_put(add, STAGES[i], 1.0)
	var active := active_curses(st)
	for cid in active:
		_put(add, curse(String(cid)).get("fx", {}), 1.0)
	var out := {}
	for key in FX:
		var spec: Array = FX[key]
		out[key] = clampf(float(spec[0]) + float(add.get(key, 0.0)), float(spec[1]), float(spec[2]))
	# Fahrpreis: Ausstattung und Lizenz, Lohn des Auftrags, Goldenes Taxameter und Risikoprämie
	var n := active.size()
	var fare := 1.0 + float(out.fare_add) + float((st.get("offer", {}) as Dictionary).get("fare_bonus", 0.0))
	fare += GOLDEN_STEP * float(st.get("etappe", 0)) * float(out.golden)
	fare += RISK_PERK_STEP * float(n) * float(out.risk)
	out["fare_k"] = clampf(fare, 0.5, 3.0)
	if active.has("crooked"):
		var left := _rng(st, "crooked", int(st.get("etappe", 0))).randi() % 2 == 0
		out["side_l"] = 0.75 if left else 1.0
		out["side_r"] = 1.0 if left else 0.75
	else:
		out["side_l"] = 1.0
		out["side_r"] = 1.0
	return out

static func _put(add: Dictionary, fx: Dictionary, k: float) -> void:
	for key in fx:
		add[key] = float(add.get(key, 0.0)) + float(fx[key]) * k

## Zwischenfälle, die in dieser Etappe wirken: die des gewählten Auftrags und alle Pakte.
static func active_curses(st: Dictionary) -> Array:
	var out: Array = (st.get("curses", []) as Array).duplicate()
	for p in st.get("pacts", []):
		if not out.has(p):
			out.append(p)
	return out

## Werte für TaxiSim.apply_mods (im Replay enthalten).
static func sim_mods(fx: Dictionary, angel := 0) -> Dictionary:
	return {"burn": fx.burn, "damage": fx.damage, "land_vy": Tuning.LAND_VY + float(fx.land_vy), "thrust_k": fx.thrust_k, "side_k": fx.side_k,
		"side_l": fx.side_l, "side_r": fx.side_r, "down_k": fx.down_k, "drag_k": fx.drag_k, "gear_time_k": fx.gear_time_k,
		"land_tilt": Tuning.LAND_TILT + float(fx.land_tilt), "land_vx": Tuning.LAND_VX + float(fx.land_vx), "impact_safe": Tuning.IMPACT_SAFE + float(fx.impact_safe),
		"heat_k": fx.heat_k, "mover_k": fx.mover_k, "spike_shield": int(fx.spike_shield), "overheat": float(fx.overheat) > 0.0, "leak": fx.leak,
		"heavy_k": fx.heavy_k, "angel": angel}

## Werte für Run.ot (Wirtschaft und Fahrgäste); leer = keine Sonderschicht.
static func run_mods(fx: Dictionary) -> Dictionary:
	var out := {}
	for k in ["fare_k", "tip_add", "tip_k", "repair_k", "taxi_fee_k", "fuel_price_k", "refuel_k", "deadline_k", "missed_k", "walk_k", "vip_k", "tmax",
			"pen_k", "combo_k", "reserve", "seat", "self_repair", "extra_add", "picky", "cash", "pump_cycle", "soft_add", "no_life"]:
		out[k] = fx[k]
	return out

# --------------------------------------------------------------------------- Kreuzung

static func level_info(id: String) -> Dictionary:
	if not _level_info.has(id):
		var lvl := LevelData.load_file("res://data/levels/%s.json" % id)
		var info := {"pads": 0, "fuel": false, "movers": false}
		if lvl != null:
			for pid in lvl.pads:
				if lvl.is_passenger_pad(String(pid)):
					info.pads += 1
				if bool(lvl.pads[pid].get("fuel", false)):
					info.fuel = true
			info.movers = lvl.has_movers()
		_level_info[id] = info
	return _level_info[id]

## Level-IDs eines Sektors (aus `ids`), noch nicht in diesem Lauf geflogen.
static func pool(st: Dictionary, ids: Array, sector: int) -> Array:
	var prefix := "s%d_" % sector
	var out: Array = ids.filter(func(id): return String(id).begins_with(prefix) and not (st.get("used", []) as Array).has(id))
	out.sort()
	return out

static func curse_ok(cid: String, level_id: String, taken: Array) -> bool:
	var c := curse(cid)
	if c.is_empty() or taken.has(cid) or blocked(cid, level_id):
		return false
	for t in taken:
		if String(curse(String(t)).get("group", "")) == String(c.get("group", "-")):
			return false                          # nie zwei aus derselben Gruppe (z. B. zwei Anzeigen kaputt oder Hitze und schwere Fracht)
	var info := level_info(level_id)
	match cid:
		"newroute":
			return int(info.pads) >= 3
		"pumpcycle":
			return bool(info.fuel)
	return true

## Anzahl Zwischenfälle je Angebot an Etappe `e`: ruhig, mittel, riskant (riskant bringt eine Prämie).
static func curse_counts(st: Dictionary, e: int) -> Array:
	var depth := float(e) / float(maxi(1, total(st) - 1))
	var fx := effects(st)
	var c0 := 0 if depth < 0.4 else 1
	var c1 := 1 if depth < 0.7 else 2
	var c2 := 2 if depth < 0.85 else 3
	if float(fx.min_curse) > 0.0:
		c0 = maxi(c0, 1)
	if float(fx.more_curse) > 0.0:
		c1 = mini(3, c1 + 1)
		c2 = mini(3, c2 + 1)
	return [c0, c1, c2, c2]

## Angebote der laufenden Kreuzung (gleicher Seed, Etappe und Würfelzahl = gleiche Angebote). Jede Kreuzung würfelt mit eigenem Strom:
## Welcher Auftrag gewählt wurde, verschiebt die späteren Angebote nicht (nur die schon geflogene Karte fällt weg).
static func offers(st: Dictionary, ids: Array) -> Array:
	var e := int(st.etappe)
	var sector := sector_of(st, e)
	var rng := _rng(st, "cross", e * 100 + int((st.get("rerolls", {}) as Dictionary).get(str(e), 0)))
	var lv := pool(st, ids, sector)
	if lv.is_empty():
		lv = pool({"used": []}, ids, sector)        # Sicherheit: mehr Etappen als Level im Sektor (kommt bei 3 je Sektor nicht vor)
	var fx := effects(st)
	var n := mini(OFFERS + int(fx.scanner), lv.size())
	var counts := curse_counts(st, e)
	var all_ids: Array = curses().map(func(c): return String(c.id))
	var out: Array = []
	var picked: Array = []
	for i in n:
		var cand: Array = lv.filter(func(id): return not picked.has(id))
		var lid := String(cand[rng.randi() % cand.size()])
		picked.append(lid)
		var want := int(counts[mini(i, counts.size() - 1)])
		var cs: Array = []
		var tries := 0
		while cs.size() < want and tries < 60:
			tries += 1
			var cid := String(all_ids[rng.randi() % all_ids.size()])
			if curse_ok(cid, lid, cs + active_pacts(st)):
				cs.append(cid)
		var o := {"level": lid, "curses": cs, "fare_bonus": FARE_PER_CURSE * float(cs.size()), "pact": "", "reward": ""}
		if cs.size() >= 2:
			o.reward = _roll_perk(st, rng, cs.size() >= 3 or e >= 6)
		out.append(o)
	if e >= PACT_FROM and out.size() >= 2 and rng.randf() < PACT_CHANCE:
		var pool_p: Array = pact_pool().filter(func(p): return not (st.get("pacts", []) as Array).has(p) and curse_ok(String(p), String(out[1].level), out[1].curses + active_pacts(st)))
		if not pool_p.is_empty():
			out[1].pact = String(pool_p[rng.randi() % pool_p.size()])
			out[1].reward = _roll_perk(st, rng, true, true)
	_apply_bribe(st, out)
	return out

static func active_pacts(st: Dictionary) -> Array:
	return (st.get("pacts", []) as Array).duplicate()

## Zwischenfälle zählen für Lohn und Wertung (Pakte zählen in jeder Etappe mit).
static func offer_curse_count(st: Dictionary, o: Dictionary) -> int:
	var n: Array = (o.get("curses", []) as Array).duplicate()
	for p in st.get("pacts", []):
		if not n.has(p):
			n.append(p)
	if String(o.get("pact", "")) != "" and not n.has(o.pact):
		n.append(o.pact)
	return n.size()

## Auftrag wählen: Etappe beginnt. Pakt: Zwischenfall bleibt bis zum Ende, die Prämie gibt es sofort. Grundgehalt wird ausgezahlt.
static func choose(st: Dictionary, o: Dictionary) -> void:
	var pact := String(o.get("pact", ""))
	if pact != "":
		st.pacts.append(pact)
		if String(o.get("reward", "")) != "":
			_add_perk(st, String(o.reward))
		st.reward = ""
	else:
		st.reward = String(o.get("reward", ""))
	st.level = String(o.level)
	st.curses = (o.get("curses", []) as Array).duplicate()
	var ob := o.duplicate(true)
	ob["fare_bonus"] = FARE_PER_CURSE * float(offer_curse_count(st, {"curses": st.curses}))
	st.offer = ob
	st.used.append(st.level)
	st.phase = "fly"
	st.bribed = -1
	st["bribe"] = {}
	var sal := int(effects(st).salary)
	if sal > 0:
		var pay := float(SALARY * sal) * (1.0 + 0.25 * float(sector_of(st, int(st.etappe)) - 1))
		st.credits = float(st.credits) + roundf(pay)
		_note(st, "salary", pay)

## Kreuzung neu würfeln (kostet eine Marke). false ohne Marke.
static func reroll_cross(st: Dictionary) -> bool:
	if int(st.tokens) <= 0:
		return false
	st.tokens = int(st.tokens) - 1
	var key := str(int(st.etappe))
	st.rerolls[key] = int((st.rerolls as Dictionary).get(key, 0)) + 1
	return true

static func bribe_price(st: Dictionary) -> int:
	return BRIBE_BASE * sector_of(st, int(st.etappe))

## Schmiergeld: einen Zwischenfall eines Angebots streichen (einmal je Kreuzung). Die Streichung steht im Zustand, damit sie auch nach dem
## Fortsetzen gilt (neu würfeln verwirft sie). Gibt true zurück, wenn es geklappt hat.
static func bribe(st: Dictionary, ids: Array, offer_index: int, curse_index: int) -> bool:
	var os := offers(st, ids)
	if offer_index < 0 or offer_index >= os.size():
		return false
	var cs: Array = os[offer_index].get("curses", [])
	if float(effects(st).bribe) <= 0.0 or int(st.bribed) == int(st.etappe) or curse_index < 0 or curse_index >= cs.size() or float(st.credits) < bribe_price(st):
		return false
	st.credits = float(st.credits) - bribe_price(st)
	st.bribed = int(st.etappe)
	st["bribe"] = {"e": int(st.etappe), "r": int((st.get("rerolls", {}) as Dictionary).get(str(int(st.etappe)), 0)), "i": offer_index, "c": String(cs[curse_index])}
	return true

static func _apply_bribe(st: Dictionary, out: Array) -> void:
	var b: Dictionary = st.get("bribe", {})
	if b.is_empty() or int(b.get("e", -1)) != int(st.etappe) or int(b.get("r", -1)) != int((st.get("rerolls", {}) as Dictionary).get(str(int(st.etappe)), 0)):
		return
	var i := int(b.get("i", -1))
	if i < 0 or i >= out.size():
		return
	var o: Dictionary = out[i]
	(o.curses as Array).erase(String(b.get("c", "")))
	o.fare_bonus = FARE_PER_CURSE * float((o.curses as Array).size())
	if (o.curses as Array).size() < 2 and String(o.get("pact", "")) == "":
		o.reward = ""

# --------------------------------------------------------------------------- Etappe beendet

## Punkte einer Etappe: Levelpunkte (wie in der Karriere: Netto + Boni) mal Risikofaktor (+25 % je Zwischenfall), Boni mal Ass-Faktor.
static func etappe_score(level_points: int, bonus_points: int, n_curses: int, bonus_k := 1.0) -> int:
	var base := float(level_points - bonus_points) + float(bonus_points) * bonus_k
	return int(round(maxf(0.0, base) * (1.0 + RISK_PER_CURSE * float(n_curses))))

## Etappe geschafft: Ergebnis festhalten, Prämie, Steuer, Serie; danach Halt, Kreuzung oder Ende.
## `res`: {points, bonus, credits, fuel, lives, carry, streak, angel, net, time, delivered, stars}
static func etappe_done(st: Dictionary, res: Dictionary) -> void:
	var n := active_curses(st).size()
	var fx := effects(st)
	var sc := etappe_score(int(res.get("points", 0)), int(res.get("bonus", 0)), n, float(fx.bonus_k))
	st.results.append({"id": st.level, "sector": sector_of(st, int(st.etappe)), "score": sc, "points": int(res.get("points", 0)), "curses": active_curses(st),
		"net": float(res.get("net", 0.0)), "time": float(res.get("time", 0.0)), "stars": int(res.get("stars", 0))})
	st.credits = float(res.get("credits", st.credits))
	st.fuel = float(res.get("fuel", st.fuel))
	st.lives = int(res.get("lives", st.lives))
	st.carry = res.get("carry", {})
	st.angel = int(res.get("angel", st.angel))
	st.streak = int(res.get("streak", 0)) if float(fx.chain) > 0.0 else 0
	if float(fx.audit) > 0.0:
		var tax := roundf(maxf(0.0, float(st.credits) - AUDIT_FREE) * AUDIT_RATE)
		st.credits = float(st.credits) - tax
		_note(st, "audit", tax)
	if String(st.get("reward", "")) != "":
		_add_perk(st, String(st.reward))
		_note(st, "reward", 0.0, String(st.reward))
		st.reward = ""
	st.etappe = int(st.etappe) + 1
	st.curses = []
	st.offer = {}
	st.level = ""
	if is_last(st):
		st.phase = "done"
		st.done = true
	elif int(st.etappe) % HALT_EVERY == 0:
		st.phase = "halt"
		st.halts = int(st.halts) + 1
		st.shop = []
		st.shop_rolls = 0
		if float(fx.interest) > 0.0:
			var z := minf(INTEREST_MAX, roundf(maxf(0.0, float(st.credits)) * INTEREST))
			st.credits = float(st.credits) + z
			_note(st, "interest", z)
	else:
		st.phase = "cross"

## Lauf verloren (kein Taxi mehr): die laufende Etappe zählt nicht.
static func fail(st: Dictionary, credits: float) -> void:
	st.credits = credits
	st.lives = 0
	st.over = true
	st.phase = "done"

static func _note(st: Dictionary, what: String, amount: float, item := "") -> void:
	var l: Array = st.get("log", [])
	l.append({"what": what, "amount": amount, "item": item, "etappe": int(st.get("etappe", 0))})
	if l.size() > 40:
		l.pop_front()
	st["log"] = l

# --------------------------------------------------------------------------- Werkstatt-Halt

static func _weights(st: Dictionary, allow_legend: bool) -> Dictionary:
	var luck := float(effects(st).luck)
	var w := WEIGHT.duplicate()
	w["r"] = maxf(5.0, float(w.r) * pow(2.0, luck))
	w["l"] = maxf(2.0, float(w.l) * pow(2.0, luck)) if allow_legend else 0.0
	return w

## Ein Teil würfeln, das im Pool liegt (Dienstgrad), noch nicht ausgereizt ist und zum Lauf passt.
static func _roll_perk(st: Dictionary, rng: RandomNumberGenerator, rare_up := false, legend_ok := false, exclude: Array = []) -> String:
	var w := _weights(st, legend_ok or int(st.get("halts", 0)) >= LEGEND_FROM_HALT)
	if rare_up:
		w["c"] = float(w.c) * 0.35
	var cand: Array = []
	var total_w := 0.0
	for p in perks():
		var id := String(p.id)
		if exclude.has(id) or int(p.get("rank", 0)) > int(st.get("rank", 0)) or stack(st, id) >= int(p.get("max", 1)):
			continue
		if id == "spare" and int(st.get("lives", 0)) >= MAX_TAXIS:
			continue
		var pw := float(w.get(String(p.get("rar", "c")), 0.0))
		if pw <= 0.0:
			continue
		cand.append([id, pw])
		total_w += pw
	if cand.is_empty():
		return ""
	var x := rng.randf() * total_w
	for c in cand:
		x -= float(c[1])
		if x <= 0.0:
			return String(c[0])
	return String(cand[-1][0])

## Angebot des laufenden Halts (wird beim ersten Aufruf gewürfelt und im Zustand gemerkt).
static func shop(st: Dictionary) -> Array:
	if (st.get("shop", []) as Array).is_empty():
		var rng := _rng(st, "shop", int(st.halts) * 100 + int(st.shop_rolls))
		var slots := SHOP_SLOTS - int(effects(st).shop_less)
		var items: Array = []
		for i in slots:
			var id := _roll_perk(st, rng, false, false, items.map(func(it): return it.id))
			if id == "":
				break
			items.append({"id": id, "sold": false})
		st.shop = items
	return st.shop

static func price(st: Dictionary, id: String) -> int:
	var p := perk(id)
	var owned := 0
	for k in st.get("perks", {}):
		owned += int(st.perks[k])
	var fx := effects(st)
	var k := (1.0 + PRICE_HALT_STEP * float(maxi(int(st.get("halts", 1)) - 1, 0))) * (1.0 + PRICE_OWNED_STEP * float(owned)) * (1.0 - HAGGLE_STEP * float(fx.haggle)) * float(fx.shop_k)
	return int(snappedf(float(PRICE.get(String(p.get("rar", "c")), 600)) * k, 10.0))

## Kaufen; false, wenn das Geld nicht reicht oder das Teil schon verkauft ist.
static func buy(st: Dictionary, slot: int) -> bool:
	var items: Array = shop(st)
	if slot < 0 or slot >= items.size() or bool(items[slot].sold):
		return false
	var id := String(items[slot].id)
	var cost := price(st, id)
	if float(st.credits) < cost or stack(st, id) >= int(perk(id).get("max", 1)):
		return false
	st.credits = float(st.credits) - cost
	_add_perk(st, id)
	items[slot].sold = true
	_note(st, "buy", cost, id)
	return true

static func shop_reroll_price(st: Dictionary) -> int:
	return REROLL_PRICE * int(pow(2, int(st.get("shop_rolls", 0))))

## Halt neu würfeln: mit Marke kostenlos, sonst gegen Credits (150, 300, 600 …).
static func reroll_shop(st: Dictionary) -> bool:
	if int(st.tokens) > 0:
		st.tokens = int(st.tokens) - 1
	elif float(st.credits) >= shop_reroll_price(st):
		st.credits = float(st.credits) - shop_reroll_price(st)
	else:
		return false
	st.shop_rolls = int(st.shop_rolls) + 1
	st.shop = []
	return true

static func leave_halt(st: Dictionary) -> void:
	st.phase = "cross"
	st.shop = []

# --------------------------------------------------------------------------- Wertung, Dienstgrad, Bestenliste

## Schlusswertung mit allen Posten (für die Anzeige).
static func final(st: Dictionary) -> Dictionary:
	var sum := 0
	for r in st.get("results", []):
		sum += int(r.score)
	var lives := maxi(0, int(st.get("lives", 0))) if not bool(st.get("over", false)) else 0
	var taxi_pts := TAXI_POINTS * lives
	var finish := int(round(float(sum) * FINISH_BONUS)) if bool(st.get("done", false)) and not bool(st.get("over", false)) else 0
	var stage := int(st.get("stage", 0))
	var stage_k := 1.0 + STAGE_STEP * float(stage)
	var total_pts := int(round(float(sum + taxi_pts + finish) * stage_k))
	return {"etappen": sum, "taxis": lives, "taxi_points": taxi_pts, "finish": finish, "stage": stage, "stage_k": stage_k, "total": total_pts,
		"flown": (st.get("results", []) as Array).size(), "of": total(st), "won": bool(st.get("done", false)) and not bool(st.get("over", false)),
		"credits": float(st.get("credits", 0.0)), "xp": int(floor(float(total_pts) / XP_DIV))}

static func rank_of(xp: int) -> int:
	var r := 0
	for i in RANK_XP.size():
		if xp >= int(RANK_XP[i]):
			r = i
	return r

## Erfahrung bis zum nächsten Dienstgrad: [erreicht im Rang, nötig im Rang] (bei Höchstrang [0, 0]).
static func rank_progress(xp: int) -> Array:
	var r := rank_of(xp)
	if r >= RANK_XP.size() - 1:
		return [0, 0]
	return [xp - int(RANK_XP[r]), int(RANK_XP[r + 1]) - int(RANK_XP[r])]

static func default_meta() -> Dictionary:
	return {"xp": 0, "stage_max": 0, "runs": 0, "wins": 0, "best": {"short": [], "medium": [], "long": []}}

## Abschluss des Laufs in den Fortschritt übernehmen: Erfahrung, Stufe, Bestenliste. Gibt {rank_before, rank, place, stage_unlocked} zurück.
static func record(meta: Dictionary, st: Dictionary, date: String) -> Dictionary:
	var f := final(st)
	var before := rank_of(int(meta.get("xp", 0)))
	meta["xp"] = int(meta.get("xp", 0)) + int(f.xp)
	meta["runs"] = int(meta.get("runs", 0)) + 1
	var unlocked := -1
	if f.won:
		meta["wins"] = int(meta.get("wins", 0)) + 1
		var nxt := mini(STAGE_MAX, int(st.get("stage", 0)) + 1)
		if nxt > int(meta.get("stage_max", 0)):
			meta["stage_max"] = nxt
			unlocked = nxt
	if not (meta.get("best") is Dictionary):
		meta["best"] = {}
	var length := String(st.get("length", "short"))
	var board: Array = meta.best.get(length, []) if meta.best.get(length, []) is Array else []
	var entry := {"score": f.total, "code": String(st.get("code", "")), "date": date, "license": String(st.get("license", "standard")), "stage": int(st.get("stage", 0)),
		"flown": f.flown, "of": f.of, "won": f.won}
	board.append(entry)
	board.sort_custom(func(a, b): return int(a.score) > int(b.score))
	var place := board.find(entry) + 1
	if board.size() > BOARD_SIZE:
		board.resize(BOARD_SIZE)
	if place > BOARD_SIZE:
		place = 0
	meta.best[length] = board
	return {"rank_before": before, "rank": rank_of(int(meta.xp)), "place": place, "stage_unlocked": unlocked, "final": f}

## Lizenzen, die mit diesem Dienstgrad wählbar sind.
static func licenses_for(r: int) -> Array:
	return licenses().filter(func(l): return int(l.get("rank", 0)) <= r).map(func(l): return String(l.id))

## Neu im Pool mit Dienstgrad `r` (für die Anzeige beim Aufstieg).
static func unlocks_at(r: int) -> Array:
	var out: Array = []
	for p in perks():
		if int(p.get("rank", 0)) == r:
			out.append("perk:" + String(p.id))
	for l in licenses():
		if int(l.get("rank", 0)) == r and r > 0:
			out.append("license:" + String(l.id))
	return out
