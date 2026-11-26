extends Node
## Tikken op de koek en kritieke klikken.

var _rng := RandomNumberGenerator.new()
var _recent: Array[float] = []   # tijdstempels voor de "rustig aan"-easter egg

func _ready() -> void:
	_rng.randomize()

## Geeft {amount, crit} terug.
func click(screen_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var amount := Economy.click_value()
	var crit := _rng.randf() < Economy.crit_chance()
	if crit:
		amount *= Economy.crit_mult()
		GameState.crits += 1
		GameState.crits_total += 1
	GameState.clicks += 1
	GameState.clicks_total += 1
	GameState.add_cookies(amount)
	EventBus.cookies_clicked.emit(amount, crit, screen_pos)
	_track_speed()
	return {"amount": amount, "crit": crit}

func _track_speed() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_recent.append(now)
	while _recent.size() > 0 and now - _recent[0] > 10.0:
		_recent.pop_front()
	if _recent.size() == 100:
		EventBus.toast.emit("Rustig aan! De koek heeft ook gevoelens.")
		GameState.flags["speed_clicker"] = true
