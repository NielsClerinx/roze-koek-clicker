extends Node
## Vrienden als personages. Elk personage is één JSON-bestand in res://data/characters.
## Nieuwe vrienden toevoegen = nieuw bestand + art; geen codewijziging nodig.
## (UI volgt in v0.2; het systeem levert nu al modifiers voor gerekruteerde vrienden.)

func _ready() -> void:
	Economy.register_provider(self)

func is_recruited(id: String) -> bool:
	return GameState.characters.has(id)

func level(id: String) -> int:
	return int(GameState.characters.get(id, {}).get("level", 0))

func get_modifiers() -> Array:
	var out: Array = []
	for id in GameState.characters.keys():
		var c = GameData.character_by_id.get(id)
		if c == null:
			continue
		var lvl := level(id)
		for bonus in c.get("passive_bonus", []):
			var m: Dictionary = bonus.duplicate()
			# Multiplicatieve bonussen groeien met het level: 1 + (waarde-1) * (1 + 0.25*(lvl-1))
			var v := float(m.get("value", 1.0))
			if str(m.get("type", "")).ends_with("_mult"):
				m.value = 1.0 + (v - 1.0) * (1.0 + 0.25 * (lvl - 1))
			else:
				m.value = v * (1.0 + 0.25 * (lvl - 1))
			out.append(m)
	return out

func recruit(id: String) -> bool:
	var c = GameData.character_by_id.get(id)
	if c == null or is_recruited(id):
		return false
	if not GameState.try_spend(float(c.get("unlock_cost", 0))):
		return false
	GameState.characters[id] = {"level": 1}
	EventBus.modifiers_changed.emit()
	return true
