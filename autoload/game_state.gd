extends Node
## De volledige (op te slaan) toestand van een spel. Bevat geen formules.

const SAVE_VERSION := 2

var cookies: float = 0.0
var baked_run: float = 0.0          # gebakken in deze run (sinds herglazuren)
var baked_lifetime: float = 0.0     # ooit gebakken (alle runs)
var clicks: int = 0
var crits: int = 0
var golden_clicked: int = 0
var buildings: Dictionary = {}      # id -> aantal
var upgrades: Dictionary = {}       # id -> true
var characters: Dictionary = {}     # id -> {"level": int}
var clicks_total: int = 0          # alle runs samen
var crits_total: int = 0
var achievements: Dictionary = {}   # id -> unix-tijd van behalen
var flags: Dictionary = {}          # geheime acties en mijlpalen (id -> true)
var daily: Dictionary = {}          # dagelijkse uitdagingen (zie ChallengeSystem)
var ribbons: int = 0                # Roze Lintjes
var heaven: Dictionary = {}         # Roze Hemel: id -> true
var crystals: int = 0
var crystals_spent: int = 0
var prestiges: int = 0
var play_seconds: float = 0.0
var last_active_unix: float = 0.0
var created_unix: float = 0.0
var bakery_name: String = "Mijn Roze Bakkerij"
var settings: Dictionary = {"sound": true, "vibration": true}

func _ready() -> void:
	reset_all()

func reset_all() -> void:
	reset_run()
	baked_lifetime = 0.0
	crystals = 0
	crystals_spent = 0
	prestiges = 0
	characters = {}
	clicks_total = 0
	crits_total = 0
	achievements = {}
	flags = {}
	daily = {}
	ribbons = 0
	heaven = {}
	golden_clicked = 0
	play_seconds = 0.0
	created_unix = Time.get_unix_time_from_system()
	last_active_unix = created_unix

func reset_run() -> void:
	cookies = 0.0
	baked_run = 0.0
	clicks = 0
	crits = 0
	buildings = {}
	upgrades = {}
	for b in GameData.buildings:
		buildings[b.id] = 0

func add_cookies(amount: float) -> void:
	if amount <= 0.0 or is_nan(amount) or is_inf(amount):
		return
	cookies += amount
	baked_run += amount
	baked_lifetime += amount

func try_spend(amount: float) -> bool:
	if amount < 0.0 or cookies + 1e-9 < amount:
		return false
	cookies = maxf(cookies - amount, 0.0)
	return true

func count(building_id: String) -> int:
	return int(buildings.get(building_id, 0))

func has_upgrade(id: String) -> bool:
	return upgrades.has(id)

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"cookies": cookies, "baked_run": baked_run, "baked_lifetime": baked_lifetime,
		"clicks": clicks, "crits": crits, "golden_clicked": golden_clicked,
		"buildings": buildings, "upgrades": upgrades.keys(), "characters": characters,
		"clicks_total": clicks_total, "crits_total": crits_total,
		"achievements": achievements, "flags": flags.keys(), "daily": daily, "ribbons": ribbons,
		"heaven": heaven.keys(),
		"crystals": crystals, "crystals_spent": crystals_spent, "prestiges": prestiges,
		"play_seconds": play_seconds, "last_active_unix": last_active_unix,
		"created_unix": created_unix, "bakery_name": bakery_name, "settings": settings,
	}

func from_dict(d: Dictionary) -> void:
	reset_all()
	d = _migrate(d)
	cookies = _num(d.get("cookies"))
	baked_run = maxf(_num(d.get("baked_run")), 0.0)
	baked_lifetime = maxf(_num(d.get("baked_lifetime")), baked_run)
	clicks = int(_num(d.get("clicks")))
	crits = int(_num(d.get("crits")))
	golden_clicked = int(_num(d.get("golden_clicked")))
	var b = d.get("buildings", {})
	if b is Dictionary:
		for id in b.keys():
			if GameData.building_by_id.has(id):   # onbekende gebouwen negeren
				buildings[id] = maxi(int(_num(b[id])), 0)
	var u = d.get("upgrades", [])
	if u is Array:
		for id in u:
			if GameData.upgrade_by_id.has(id):
				upgrades[id] = true
	var c = d.get("characters", {})
	if c is Dictionary:
		for id in c.keys():
			if GameData.character_by_id.has(id) and c[id] is Dictionary:
				characters[id] = {"level": maxi(int(_num(c[id].get("level", 1))), 1), "ready_at": _num(c[id].get("ready_at", 0.0))}
	clicks_total = maxi(int(_num(d.get("clicks_total"))), clicks)
	crits_total = maxi(int(_num(d.get("crits_total"))), crits)
	var a = d.get("achievements", {})
	if a is Dictionary:
		for id in a.keys():
			if GameData.achievement_by_id.has(id):
				achievements[id] = _num(a[id])
	var fl = d.get("flags", [])
	if fl is Array:
		for f in fl:
			flags[str(f)] = true
	var dy = d.get("daily", {})
	if dy is Dictionary:
		daily = dy
	ribbons = maxi(int(_num(d.get("ribbons"))), 0)
	var h = d.get("heaven", [])
	if h is Array:
		for id in h:
			if GameData.heaven_by_id.has(id):
				heaven[id] = true
	crystals = int(_num(d.get("crystals")))
	crystals_spent = int(_num(d.get("crystals_spent")))
	prestiges = int(_num(d.get("prestiges")))
	play_seconds = _num(d.get("play_seconds"))
	last_active_unix = _num(d.get("last_active_unix", Time.get_unix_time_from_system()))
	created_unix = _num(d.get("created_unix", last_active_unix))
	bakery_name = str(d.get("bakery_name", bakery_name)).substr(0, 24)
	var s = d.get("settings", {})
	if s is Dictionary:
		settings.merge(s, true)

func _migrate(d: Dictionary) -> Dictionary:
	# Save-versies stap voor stap migreren.
	if int(_num(d.get("version", 1))) < 2:
		# v1 kende geen totalen over alle runs: neem de huidige run als ondergrens.
		d["clicks_total"] = d.get("clicks", 0)
		d["crits_total"] = d.get("crits", 0)
		d["version"] = 2
	return d

func crystals_available() -> int:
	return maxi(crystals - crystals_spent, 0)

static func _num(v) -> float:
	if v is float or v is int:
		var f := float(v)
		return 0.0 if (is_nan(f) or is_inf(f)) else f
	if v is String and v.is_valid_float():
		return v.to_float()
	return 0.0
