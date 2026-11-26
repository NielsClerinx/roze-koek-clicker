extends Node
## Willekeurige gebeurtenissen. v0.1: de gouden roze koek en tijdelijke boosts.
## Nieuwe events (inspecteur, receptdiefstal, ...) komen hier in v0.4.

const GOLDEN_MIN := 90.0
const GOLDEN_MAX := 210.0
const GOLDEN_FIRST := 75.0

var _rng := RandomNumberGenerator.new()
var _next_golden := GOLDEN_FIRST
var golden_active := false
var _golden_left := 0.0
var buffs: Dictionary = {}   # id -> {label, left, modifiers}

func _ready() -> void:
	_rng.randomize()
	Economy.register_provider(self, true)
	EventBus.game_reset.connect(reset)

func get_modifiers() -> Array:
	var out: Array = []
	for b in buffs.values():
		out.append_array(b.modifiers)
	return out

func _process(delta: float) -> void:
	delta = minf(delta, 1.0)
	# Buffs aftellen
	var expired := false
	for id in buffs.keys():
		buffs[id].left -= delta
		if buffs[id].left <= 0.0:
			buffs.erase(id)
			expired = true
	if expired:
		EventBus.modifiers_changed.emit()
	# Gouden koek
	if golden_active:
		_golden_left -= delta
		if _golden_left <= 0.0:
			golden_active = false
	else:
		_next_golden -= delta * Economy.golden_frequency_mult()
		if _next_golden <= 0.0:
			spawn_golden()

func spawn_golden() -> void:
	golden_active = true
	_golden_left = Economy.golden_lifetime()
	_next_golden = _rng.randf_range(GOLDEN_MIN, GOLDEN_MAX)
	EventBus.golden_spawned.emit()

func golden_time_left() -> float:
	return _golden_left if golden_active else 0.0

func claim_golden() -> String:
	if not golden_active:
		return ""
	golden_active = false
	GameState.golden_clicked += 1
	var roll := _rng.randf()
	var msg: String
	if roll < 0.5:
		# Koekenregen: 15% van de bank, maximaal 15 min productie, minimaal 13 koeken.
		var gain := maxf(minf(GameState.cookies * 0.15, Economy.kps_permanent() * 900.0), 13.0)
		GameState.add_cookies(gain)
		msg = "Koekenregen! +%s roze koeken" % NumberFormat.format(gain)
	elif roll < 0.85:
		add_buff("razernij", "Roze razernij x7", 60.0, [{"type": "global_mult", "value": 7.0}])
		msg = "Roze razernij! Productie x7 gedurende 60 s"
	else:
		add_buff("klikstorm", "Klikstorm x77", 10.0, [{"type": "click_mult", "value": 77.0}])
		msg = "Klikstorm! Tikken x77 gedurende 10 s"
	EventBus.golden_claimed.emit(msg)
	return msg

func add_buff(id: String, label: String, duration: float, modifiers: Array) -> void:
	buffs[id] = {"label": label, "left": duration, "duration": duration, "modifiers": modifiers}
	EventBus.buff_started.emit(id, label, duration)
	EventBus.modifiers_changed.emit()

func reset() -> void:
	buffs.clear()
	golden_active = false
	_next_golden = GOLDEN_FIRST
	EventBus.modifiers_changed.emit()
