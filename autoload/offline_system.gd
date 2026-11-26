extends Node
## Offline inkomsten. Werkt bij opstarten én bij terugkeren uit de achtergrond (mobiel).

const MIN_SECONDS := 30.0

func apply_since(last_unix: float) -> void:
	var now := Time.get_unix_time_from_system()
	var elapsed := now - last_unix
	GameState.last_active_unix = now
	# Klok teruggezet of te kort weg: niets uitbetalen.
	if last_unix <= 0.0 or elapsed < MIN_SECONDS:
		return
	var amount := Economy.offline_earnings(elapsed)
	if amount > 0.0:
		GameState.add_cookies(amount)
		EventBus.offline_earned.emit(amount, elapsed)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			GameState.last_active_unix = Time.get_unix_time_from_system()
			SaveManager.save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			apply_since(GameState.last_active_unix)
