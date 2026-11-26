extends Node
## Centrale signalen tussen systemen. Systemen kennen elkaar zo min mogelijk.

signal cookies_clicked(amount: float, is_crit: bool, screen_pos: Vector2)
signal building_bought(id: String, amount: int)
signal upgrade_bought(id: String)
signal modifiers_changed
signal golden_spawned
signal golden_claimed(message: String)
signal buff_started(id: String, label: String, duration: float)
signal toast(message: String)
signal offline_earned(amount: float, seconds: float)
signal game_loaded
signal game_reset
signal character_recruited(id: String)
signal ability_used(id: String)
signal achievement_unlocked(id: String)
signal challenge_completed(index: int)
signal heaven_bought(id: String)
