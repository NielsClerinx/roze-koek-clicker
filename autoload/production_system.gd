extends Node
## Automatische productie en het kopen van gebouwen.

var paused := false

func _process(delta: float) -> void:
	if paused:
		return
	# Grote frame-sprongen (app terug uit achtergrond) worden door OfflineSystem afgehandeld.
	delta = minf(delta, 1.0)
	GameState.play_seconds += delta
	var k := Economy.kps()
	if k > 0.0:
		GameState.add_cookies(k * delta)

func is_visible_in_shop(id: String) -> bool:
	# Een gebouw verschijnt als je er één hebt, of als het vorige gebouw gekocht is.
	var idx := -1
	for i in GameData.buildings.size():
		if GameData.buildings[i].id == id:
			idx = i
			break
	if idx <= 0 or GameState.count(id) > 0:
		return true
	var prev: String = GameData.buildings[idx - 1].id
	return GameState.count(prev) > 0 or GameState.baked_run >= float(GameData.buildings[idx].base_cost) * 0.5

func buy(id: String, amount: int) -> int:
	if not GameData.building_by_id.has(id):
		return 0
	if amount <= 0:   # Max
		amount = Economy.max_affordable(id)
		if amount <= 0:
			return 0
	var cost := Economy.building_cost(id, amount)
	if not GameState.try_spend(cost):
		return 0
	GameState.buildings[id] = GameState.count(id) + amount
	EventBus.building_bought.emit(id, amount)
	return amount
