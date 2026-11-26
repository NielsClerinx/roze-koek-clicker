extends Node
## Vrienden als personages. Elk personage is één JSON-bestand in res://data/characters.
## Nieuwe vrienden toevoegen = nieuw bestand (met "look" voor de figuur); geen codewijziging nodig.
##
## Vaardigheidstypes (ability.type):
##   production_boost  alle productie x value gedurende duration s (click_too: ook tikken)
##   click_frenzy      tikken x value gedurende duration s
##   golden_rain       value gouden roze koeken verschijnen
##   instant_bake      meteen value minuten productie

func _ready() -> void:
	Economy.register_provider(self)

# ------------------------------------------------------------ status

func is_recruited(id: String) -> bool:
	return GameState.characters.has(id)

func is_available(id: String) -> bool:
	var c = GameData.character_by_id.get(id)
	if c == null or is_recruited(id):
		return false
	return UpgradeSystem.check_condition(c.get("unlock_condition", {"type": "always"}))

func level(id: String) -> int:
	return int(GameState.characters.get(id, {}).get("level", 0))

func recruited_ids() -> Array:
	var out: Array = []
	for c in GameData.characters:
		if is_recruited(c.id):
			out.append(c.id)
	return out

# ------------------------------------------------------------ economie

func get_modifiers() -> Array:
	var out: Array = []
	for id in GameState.characters.keys():
		var c = GameData.character_by_id.get(id)
		if c == null:
			continue
		var lvl := maxi(level(id), 1)
		for bonus in c.get("passive_bonus", []):
			var m: Dictionary = bonus.duplicate()
			# Bonussen groeien met het level: +25% van de bonus per extra level
			var v := float(m.get("value", 1.0))
			var t := str(m.get("type", ""))
			if t.ends_with("_mult"):
				m.value = 1.0 + (v - 1.0) * (1.0 + 0.25 * (lvl - 1))
			else:
				m.value = v * (1.0 + 0.25 * (lvl - 1))
			out.append(m)
	return out

func recruit(id: String) -> bool:
	var c = GameData.character_by_id.get(id)
	if c == null or not is_available(id):
		return false
	if not GameState.try_spend(float(c.get("unlock_cost", 0))):
		return false
	GameState.characters[id] = {"level": 1, "ready_at": 0.0}
	EventBus.character_recruited.emit(id)
	EventBus.modifiers_changed.emit()
	return true

# ------------------------------------------------------------ vaardigheden

func cooldown_left(id: String) -> float:
	var ready_at := float(GameState.characters.get(id, {}).get("ready_at", 0.0))
	return maxf(ready_at - Time.get_unix_time_from_system(), 0.0)

func is_ability_ready(id: String) -> bool:
	return is_recruited(id) and cooldown_left(id) <= 0.0

func use_ability(id: String) -> bool:
	if not is_ability_ready(id):
		return false
	var c = GameData.character_by_id[id]
	var ab: Dictionary = c.get("ability", {})
	var value := float(ab.get("value", 1))
	var dur := float(ab.get("duration", 0))
	var label := "%s: %s" % [c.get("nickname", c.name), ab.get("name", "")]
	match ab.get("type", ""):
		"production_boost":
			var mods: Array = [{"type": "global_mult", "value": value}]
			if ab.get("click_too", false):
				mods.append({"type": "click_mult", "value": value})
			RandomEventSystem.add_buff("ability_" + id, label, dur, mods)
		"click_frenzy":
			RandomEventSystem.add_buff("ability_" + id, label, dur, [{"type": "click_mult", "value": value}])
		"golden_rain":
			RandomEventSystem.spawn_golden()
		"instant_bake":
			# value = aantal minuten productie dat meteen binnenkomt
			GameState.add_cookies(maxf(Economy.kps_permanent() * 60.0 * value, 100.0))
		_:
			push_warning("Onbekend vaardigheidstype: %s" % ab.get("type", ""))
			return false
	GameState.characters[id]["ready_at"] = Time.get_unix_time_from_system() + Economy.ability_cooldown(float(ab.get("cooldown", 600)))
	EventBus.ability_used.emit(id)
	return true

# ------------------------------------------------------------ teksten voor de UI

func bonus_text(id: String) -> String:
	var c = GameData.character_by_id.get(id)
	if c == null:
		return ""
	var parts: Array[String] = []
	for b in c.get("passive_bonus", []):
		var v := float(b.get("value", 1))
		match b.get("type", ""):
			"building_mult":
				var bname: String = GameData.building_by_id.get(b.get("target", ""), {}).get("name", "?")
				parts.append("%s +%d%%" % [bname, roundi((v - 1.0) * 100)])
			"global_mult": parts.append("alle productie +%d%%" % roundi((v - 1.0) * 100))
			"click_mult": parts.append("tikken x%s" % _num(v))
			"crit_chance_add": parts.append("kritieke kans +%d%%" % roundi(v * 100))
			"offline_eff_add": parts.append("offline +%d%%" % roundi(v * 100))
			"golden_freq_mult": parts.append("gouden koeken +%d%%" % roundi((v - 1.0) * 100))
			"offline_cap_add": parts.append("offline %s langer" % NumberFormat.duration(v))
	return ", ".join(parts)

func condition_text(id: String) -> String:
	var c = GameData.character_by_id.get(id)
	var cond: Dictionary = c.get("unlock_condition", {})
	match cond.get("type", ""):
		"building_count":
			var bname: String = GameData.building_by_id.get(cond.building, {}).get("name", "?")
			return "Bezit %d× %s" % [int(cond.count), bname]
		"total_baked": return "Bak %s roze koeken" % NumberFormat.format(float(cond.value))
		_: return "Nog geheim"

static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
