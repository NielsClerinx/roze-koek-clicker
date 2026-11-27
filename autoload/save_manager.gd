extends Node
## Opslaan en laden. Atomair schrijven (tmp -> hernoemen) met .bak als vangnet.

## Naam van het opslagbestand (tests gebruiken een eigen slot zodat echte saves veilig blijven).
var slot := "save"
var SAVE_PATH: String:
	get: return "user://%s.json" % slot
var BAK_PATH: String:
	get: return "user://%s.json.bak" % slot
const AUTOSAVE_INTERVAL := 30.0

var _timer := 0.0
var loaded_from_disk := false

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Terugknop (het hoofdscherm beslist of het spel sluit), app naar achtergrond of tab verlaten
		save_game()

func save_game() -> bool:
	GameState.last_active_unix = Time.get_unix_time_from_system()
	var text := JSON.stringify(GameState.to_dict())
	var f := FileAccess.open("user://%s.json.tmp" % slot, FileAccess.WRITE)
	if f == null:
		push_error("Opslaan mislukt: %s" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var main := slot + ".json"
	if dir.file_exists(main):
		dir.remove(main + ".bak")
		dir.rename(main, main + ".bak")
	var err := dir.rename(main + ".tmp", main)
	if err != OK:
		push_error("Hernoemen save mislukt: %s" % err)
		return false
	return true

## Laadt de save (of de back-up). Geeft het laatste actieve tijdstip terug (0 = nieuw spel).
func load_game() -> float:
	for path in [SAVE_PATH, BAK_PATH]:
		var d = _read(path)
		if d is Dictionary:
			GameState.from_dict(d)
			loaded_from_disk = true
			EventBus.game_loaded.emit()
			return GameState.last_active_unix
	GameState.reset_all()
	EventBus.game_loaded.emit()
	return 0.0

func wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for f in [slot + ".json", slot + ".json.bak", slot + ".json.tmp"]:
			if dir.file_exists(f):
				dir.remove(f)
	GameState.reset_all()
	EventBus.game_reset.emit()

func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("version"):
		return parsed
	push_warning("Save %s is beschadigd, probeer back-up." % path)
	return null
