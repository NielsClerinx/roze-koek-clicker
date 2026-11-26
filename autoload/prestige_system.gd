extends Node
## Herglazuren: reset de run, levert Fondantkristallen (+2% productie per stuk).

const MIN_CRYSTALS := 1

func can_prestige() -> bool:
	return Economy.crystals_pending() >= MIN_CRYSTALS

func prestige() -> int:
	var gained := Economy.crystals_pending()
	if gained < MIN_CRYSTALS:
		return 0
	GameState.crystals += gained
	GameState.prestiges += 1
	GameState.reset_run()
	HeavenSystem.apply_start_bonus()
	EventBus.game_reset.emit()
	SaveManager.save_game()
	return gained
