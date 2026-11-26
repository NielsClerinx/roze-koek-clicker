extends Node
## De Roze Hemel: permanente upgrades die je koopt met Fondantkristallen.
## Gekochte kristallen blijven hun +2% productie geven; uitgeven kost dus niets aan bonus.
## Definities staan in res://data/heaven.json.

func _ready() -> void:
	Economy.register_provider(self)

func get_modifiers() -> Array:
	var out: Array = []
	for id in GameState.heaven.keys():
		var h = GameData.heaven_by_id.get(id)
		if h != null:
			out.append_array(h.get("effects", []))
	return out

func owned(id: String) -> bool:
	return GameState.heaven.has(id)

func requirements_met(id: String) -> bool:
	var h = GameData.heaven_by_id.get(id)
	if h == null:
		return false
	for r in h.get("requires", []):
		if not owned(r):
			return false
	return true

func can_buy(id: String) -> bool:
	var h = GameData.heaven_by_id.get(id)
	return h != null and not owned(id) and requirements_met(id) \
		and GameState.crystals_available() >= int(h.cost)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var h = GameData.heaven_by_id[id]
	GameState.crystals_spent += int(h.cost)
	GameState.heaven[id] = true
	EventBus.heaven_bought.emit(id)
	EventBus.modifiers_changed.emit()
	return true

## Gebouwen waarmee elke nieuwe run begint (hoogste waarde per gebouw telt).
func start_buildings() -> Dictionary:
	var out: Dictionary = {}
	for id in GameState.heaven.keys():
		var h = GameData.heaven_by_id.get(id)
		if h == null:
			continue
		var st: Dictionary = h.get("start", {})
		for b in st.keys():
			if GameData.building_by_id.has(b):
				out[b] = maxi(int(out.get(b, 0)), int(st[b]))
	return out

## Wordt aangeroepen direct na het resetten van een run.
func apply_start_bonus() -> void:
	var st := start_buildings()
	for b in st.keys():
		GameState.buildings[b] = maxi(GameState.count(b), int(st[b]))
	if not st.is_empty():
		Economy.mark_dirty()

func requirement_text(id: String) -> String:
	var names: Array[String] = []
	for r in GameData.heaven_by_id[id].get("requires", []):
		if not owned(r):
			names.append(GameData.heaven_by_id[r].name)
	return "Eerst: " + ", ".join(names)
