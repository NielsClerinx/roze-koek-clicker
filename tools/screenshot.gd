extends Node
## Maakt screenshots voor documentatie: godot --path . res://tools/screenshot.tscn -- <uitvoermap>

func _ready() -> void:
	SaveManager.slot = "screenshot"
	SaveManager.wipe()
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	# Speltoestand van een speler na ~20 minuten
	GameState.cookies = 18420.0
	GameState.baked_run = 64000.0
	GameState.baked_lifetime = 64000.0
	for kv in [["kleine_bakker", 28], ["bakkerij", 14], ["oven", 6], ["fondantmijn", 1]]:
		GameState.buildings[kv[0]] = kv[1]
	for u in ["click_1", "click_2", "kleine_bakker_t1", "kleine_bakker_t2", "bakkerij_t1"]:
		GameState.upgrades[u] = true
	GameState.bakery_name = "Bakkerij De Roze Droom"
	for id in ["niels", "timothy", "jordi", "vriend_1", "kattenkoningin"]:
		GameState.characters[id] = {"level": 1, "ready_at": 0.0}
	GameState.characters["timothy"]["ready_at"] = Time.get_unix_time_from_system() + 222
	GameState.clicks_total = 740
	GameState.crits_total = 21
	GameState.golden_clicked = 3
	GameState.crystals = 6
	GameState.crystals_spent = 1
	GameState.heaven["hemel_start"] = true
	GameState.ribbons = 20
	GameState.daily = {"streak": 3, "last_full_day": ChallengeSystem.previous_day(ChallengeSystem.day_key())}
	SaveManager.save_game()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(30)
	for i in 6:
		ClickSystem.click(Vector2(360 + i * 12, 420))
		await _frames(2)
	await _frames(4)
	_shot(out + "/screen_gebouwen.png")
	main._select_tab(1)
	await _frames(10)
	_shot(out + "/screen_upgrades.png")
	main._select_tab(2)
	await _frames(10)
	_shot(out + "/screen_vrienden.png")
	CharacterSystem.use_ability("niels")
	await _frames(25)
	_shot(out + "/screen_vaardigheid.png")
	var tasks := ChallengeSystem.tasks()
	tasks[0].progress = tasks[0].goal
	tasks[1].progress = float(tasks[1].goal) * 0.6
	ChallengeSystem.claim(0)
	tasks[2].progress = tasks[2].goal
	main._select_tab(3)
	await _frames(40)
	_shot(out + "/screen_prestaties.png")
	var ap: ScrollContainer = main._pages[3]
	ap.scroll_vertical = 560
	await _frames(10)
	_shot(out + "/screen_medailles.png")
	main._select_tab(4)
	await _frames(10)
	var sc: ScrollContainer = main._pages[4]
	sc.scroll_vertical = 520
	await _frames(10)
	_shot(out + "/screen_roze_hemel.png")
	GameState.characters.erase("jordi")
	GameState.buildings["oven"] = 6
	GameState.cookies = 30000
	CharacterSystem.recruit("jordi")
	await _frames(30)
	_shot(out + "/screen_nieuwe_vriend.png")
	main._select_tab(0)
	RandomEventSystem.spawn_golden()
	main._on_offline_earned(48210.0, 5400.0)
	await _frames(40)
	_shot(out + "/screen_welkom.png")
	SaveManager.wipe()
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot: ", path)
