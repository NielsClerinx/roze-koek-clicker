extends Node
## Beschikbaarheid en aankoop van upgrades. Levert modifiers aan Economy.

func _ready() -> void:
	Economy.register_provider(self)

func get_modifiers() -> Array:
	var out: Array = []
	for id in GameState.upgrades.keys():
		var u = GameData.upgrade_by_id.get(id)
		if u != null:
			out.append_array(u.effects)
	return out

func is_condition_met(u: Dictionary) -> bool:
	return check_condition(u.condition)

## Gedeelde voorwaarde-check (ook gebruikt door vrienden).
func check_condition(c: Dictionary) -> bool:
	match c.get("type", ""):
		"building_count": return GameState.count(c.building) >= int(c.count)
		"total_baked": return GameState.baked_run >= float(c.value)
		"kps": return Economy.kps_permanent() >= float(c.value)
		"golden_clicked": return GameState.golden_clicked >= int(c.value)
		"always": return true
		_: return false   # "secret" en onbekend: alleen via unlock_secret

## Upgrades die nu in de winkel staan, goedkoopste eerst.
func available() -> Array:
	var out: Array = []
	for u in GameData.upgrades:
		if not GameState.has_upgrade(u.id) and is_condition_met(u):
			out.append(u)
	out.sort_custom(func(a, b): return float(a.cost) < float(b.cost))
	return out

func buy(id: String) -> bool:
	var u = GameData.upgrade_by_id.get(id)
	if u == null or GameState.has_upgrade(id) or not is_condition_met(u):
		return false
	if not GameState.try_spend(float(u.cost)):
		return false
	GameState.upgrades[id] = true
	EventBus.upgrade_bought.emit(id)
	return true

## Geheime upgrades worden gratis toegekend wanneer de speler het geheim vindt.
func unlock_secret(id: String) -> bool:
	var u = GameData.upgrade_by_id.get(id)
	if u == null or GameState.has_upgrade(id):
		return false
	GameState.upgrades[id] = true
	EventBus.upgrade_bought.emit(id)
	EventBus.toast.emit("Geheime upgrade: %s!" % u.name)
	return true
