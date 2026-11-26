extends Node
## Laadt en valideert alle content uit res://data. Geen spelregels hier, alleen definities.

var buildings: Array = []            # volgorde = progressievolgorde
var building_by_id: Dictionary = {}
var upgrades: Array = []
var upgrade_by_id: Dictionary = {}
var characters: Array = []
var character_by_id: Dictionary = {}

func _ready() -> void:
	buildings = _load_json("res://data/buildings.json", [])
	for b in buildings:
		building_by_id[b.id] = b
	upgrades = _load_json("res://data/upgrades.json", [])
	for u in upgrades:
		if not u.has("effects") or not u.has("condition"):
			push_error("Upgrade zonder effects/condition: %s" % u.get("id", "?"))
			continue
		upgrade_by_id[u.id] = u
	_load_characters()

func _load_characters() -> void:
	var dir := DirAccess.open("res://data/characters")
	if dir == null:
		return
	for f in dir.get_files():
		# In een export kunnen bestanden als .json.remap verschijnen; alleen .json lezen.
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var c = _load_json("res://data/characters/" + f, null)
		if c is Dictionary and c.has("id"):
			characters.append(c)
			character_by_id[c.id] = c
	characters.sort_custom(func(a, b): return float(a.get("unlock_cost", 0)) < float(b.get("unlock_cost", 0)))

func _load_json(path: String, fallback):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Kan %s niet openen" % path)
		return fallback
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Ongeldige JSON in %s" % path)
		return fallback
	return parsed
