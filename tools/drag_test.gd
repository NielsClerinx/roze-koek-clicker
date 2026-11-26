extends Node
func _ready() -> void:
	SaveManager.slot = "dragtest"
	SaveManager.wipe()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10: await get_tree().process_frame
	main._select_tab(2)
	for i in 5: await get_tree().process_frame
	var sc: ScrollContainer = main._pages[2]
	print("rect ", sc.get_global_rect(), " max ", sc.get_v_scroll_bar().max_value)
	var bought := GameState.characters.size()
	var start := Vector2(200, sc.get_global_rect().position.y + 300)
	_btn(start, true)
	for k in 20:
		_motion(start + Vector2(0, -10 * k))
		await get_tree().process_frame
	_btn(start + Vector2(0, -200), false)
	for i in 3: await get_tree().process_frame
	print("scroll_vertical ", sc.scroll_vertical)
	# Tik op een gebouw koopt nog steeds; veeg op een gebouw koopt niets
	main._select_tab(0)
	GameState.cookies = 1e9
	for i in 5: await get_tree().process_frame
	var row: Control = main._building_rows["kleine_bakker"]
	var c := row.get_global_rect().get_center()
	_btn(c, true); await get_tree().process_frame; _btn(c, false)
	for i in 3: await get_tree().process_frame
	print("na tik: ", GameState.count("kleine_bakker"))
	_btn(c, true)
	for k in 10:
		_motion(c + Vector2(0, -8 * k)); await get_tree().process_frame
	_btn(c + Vector2(0, -72), false)
	for i in 3: await get_tree().process_frame
	print("na veeg: ", GameState.count("kleine_bakker"))
	SaveManager.wipe()
	get_tree().quit()

func _btn(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down; e.position = p; e.global_position = p
	get_viewport().push_input(e, true)
func _motion(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p; e.global_position = p; e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)
