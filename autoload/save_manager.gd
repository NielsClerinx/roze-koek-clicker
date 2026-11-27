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

# ------------------------------------------------------------ bewaarcode
## Een bewaarcode is de hele save als tekst: "RKC1." + base64(gzip(json)) + "." + controlegetal.
## Zo kan je je spel meenemen van de webversie naar de app (of naar een nieuwe gsm).
const CODE_PREFIX := "RKC1."

func export_code() -> String:
	GameState.last_active_unix = Time.get_unix_time_from_system()
	var json := JSON.stringify(GameState.to_dict())
	var packed := json.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return CODE_PREFIX + Marshalls.raw_to_base64(packed) + "." + _checksum(json)

## Leest een bewaarcode. Geeft {"data": Dictionary} terug, of {"error": "uitleg voor de speler"}.
func parse_code(code: String) -> Dictionary:
	var c := code.strip_edges().replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
	if c.is_empty():
		return {"error": "Er is geen code ingevuld."}
	if not c.begins_with(CODE_PREFIX):
		return {"error": "Dit is geen bewaarcode van Roze Koek Clicker."}
	var parts := c.substr(CODE_PREFIX.length()).split(".")
	if parts.size() != 2 or parts[0].is_empty():
		return {"error": "De code is onvolledig. Kopieer ze opnieuw, helemaal."}
	var raw := Marshalls.base64_to_raw(parts[0])
	if raw.is_empty():
		return {"error": "De code is beschadigd. Kopieer ze opnieuw, helemaal."}
	var unpacked := raw.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if unpacked.is_empty():
		return {"error": "De code is beschadigd. Kopieer ze opnieuw, helemaal."}
	var json := unpacked.get_string_from_utf8()
	if _checksum(json) != parts[1]:
		return {"error": "De code klopt niet (een stukje ontbreekt of is veranderd)."}
	var d = JSON.parse_string(json)
	if not (d is Dictionary) or not d.has("version"):
		return {"error": "De code is beschadigd."}
	if int(GameState._num(d.get("version"))) > GameState.SAVE_VERSION:
		return {"error": "Deze code komt uit een nieuwere versie van het spel. Werk eerst je spel bij."}
	return {"data": d}

## Korte samenvatting om te tonen voor je een code inlaadt.
func describe(d: Dictionary) -> String:
	var chars = d.get("characters", {})
	var n_friends: int = chars.size() if chars is Dictionary else 0
	return "%s · %s roze koeken · %d vrienden" % [
		str(d.get("bakery_name", "Bakkerij")).substr(0, 24),
		NumberFormat.format(maxf(GameState._num(d.get("cookies")), 0.0)), n_friends]

## Vervangt het huidige spel door de save uit een bewaarcode.
## De geluidsinstellingen van dit toestel blijven behouden, en er komt geen offline-opbrengst bij.
func import_data(d: Dictionary) -> void:
	var keep := GameState.settings.duplicate()
	GameState.from_dict(d)
	GameState.settings = keep
	GameState.last_active_unix = Time.get_unix_time_from_system()
	save_game()
	EventBus.game_loaded.emit()
	EventBus.game_reset.emit()

func _checksum(text: String) -> String:
	return "%08x" % (hash(text) & 0xffffffff)

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
