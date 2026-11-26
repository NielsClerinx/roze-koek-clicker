extends Node
## Prestaties (achievements). Elke behaalde prestatie geeft permanent +1% productie.
## Definities staan in res://data/achievements.json. Prestaties blijven na herglazuren.

const BONUS_PER_ACHIEVEMENT := 0.01
const CHECK_INTERVAL := 0.5

var _t := 0.0
## Tests zetten dit uit zodat prestatiebonussen andere berekeningen niet beïnvloeden.
var enabled := true

func _ready() -> void:
	Economy.register_provider(self)
	# Directe controle na acties die vaak een prestatie opleveren.
	EventBus.building_bought.connect(func(_id, _n): check_all())
	EventBus.upgrade_bought.connect(func(_id): check_all())
	EventBus.character_recruited.connect(func(_id): check_all())
	EventBus.golden_claimed.connect(func(_m): check_all())
	EventBus.game_reset.connect(check_all)
	EventBus.game_loaded.connect(func(): check_all(true))

func _process(delta: float) -> void:
	_t += delta
	if _t >= CHECK_INTERVAL:
		_t = 0.0
		_check_time_flags()
		check_all()

func get_modifiers() -> Array:
	if GameState.achievements.is_empty():
		return []
	return [{"type": "global_mult", "value": production_mult()}]

func production_mult() -> float:
	return 1.0 + BONUS_PER_ACHIEVEMENT * unlocked_count()

func unlocked_count() -> int:
	return GameState.achievements.size()

func is_unlocked(id: String) -> bool:
	return GameState.achievements.has(id)

## silent: bij het laden van een save geen meldingen tonen.
func check_all(silent: bool = false) -> void:
	if not enabled:
		return
	var gained := false
	for a in GameData.achievements:
		if not is_unlocked(a.id) and is_met(a.condition):
			GameState.achievements[a.id] = Time.get_unix_time_from_system()
			gained = true
			if not silent:
				EventBus.achievement_unlocked.emit(a.id)
	if gained:
		EventBus.modifiers_changed.emit()

func is_met(c: Dictionary) -> bool:
	match c.get("type", ""):
		"lifetime_baked": return GameState.baked_lifetime >= float(c.value)
		"clicks_total": return GameState.clicks_total >= int(c.value)
		"crits_total": return GameState.crits_total >= int(c.value)
		"upgrades_owned": return GameState.upgrades.size() >= int(c.value)
		"friends_recruited": return GameState.characters.size() >= int(c.value)
		"friends_all": return not GameData.characters.is_empty() and GameState.characters.size() >= GameData.characters.size()
		"prestiges": return GameState.prestiges >= int(c.value)
		"flag": return GameState.flags.has(c.flag)
		"upgrade_owned": return GameState.has_upgrade(c.upgrade)
		_: return UpgradeSystem.check_condition(c)

## 0..1 voortgang voor de UI (geheime en ja/nee-prestaties: 0 of 1).
func progress(id: String) -> float:
	if is_unlocked(id):
		return 1.0
	var c: Dictionary = GameData.achievement_by_id[id].condition
	var have := 0.0
	var need := 1.0
	match c.get("type", ""):
		"lifetime_baked": have = GameState.baked_lifetime; need = float(c.value)
		"clicks_total": have = GameState.clicks_total; need = float(c.value)
		"crits_total": have = GameState.crits_total; need = float(c.value)
		"upgrades_owned": have = GameState.upgrades.size(); need = float(c.value)
		"friends_recruited": have = GameState.characters.size(); need = float(c.value)
		"friends_all": have = GameState.characters.size(); need = maxf(GameData.characters.size(), 1)
		"prestiges": have = GameState.prestiges; need = float(c.value)
		"golden_clicked": have = GameState.golden_clicked; need = float(c.value)
		"building_count": have = GameState.count(c.building); need = float(c.count)
	return clampf(have / need, 0.0, 1.0)

func _check_time_flags() -> void:
	if GameState.flags.has("night_baker"):
		return
	var t := Time.get_time_dict_from_system()
	if int(t.hour) == 3:
		GameState.flags["night_baker"] = true
