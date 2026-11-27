extends Node
## Alles wat met vrienden op het scherm te maken heeft:
## de Vrienden-tab, de figuren naast de koek en de welkomstpop-up bij het rekruteren.

const FriendFigure := preload("res://scripts/ui/characters/friend_figure.gd")

var main: Control          # hoofdscherm (voor pop-ups en toasts)
var field: Control         # voorste laag in het speelveld (voor de koek)
var field_back: Control    # achterste laag (achter de koek)
var page: ScrollContainer  # inhoud van de Vrienden-tab

var _cards: Dictionary = {}       # id -> {figure, title, role, info, button}
var _field_figs: Dictionary = {}  # id -> {figure, label}

func setup(main_node: Control, field_layer: Control, back_layer: Control) -> void:
	main = main_node
	field = field_layer
	field_back = back_layer
	field.resized.connect(layout_field)
	EventBus.character_recruited.connect(_on_recruited)
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.game_loaded.connect(rebuild_field)
	EventBus.game_reset.connect(rebuild_field)

# ------------------------------------------------------------ Vrienden-tab

func build_page() -> ScrollContainer:
	page = ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.scroll_deadzone = 12
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	page.add_child(list)
	for c in GameData.characters:
		list.add_child(_build_card(c))
	return page

func _build_card(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.box(Color("#FFF6FA"), 24, 0, 2, Palette.PINK_LIGHT))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var fig_box := Control.new()
	fig_box.custom_minimum_size = Vector2(132, 168)
	fig_box.clip_contents = true
	h.add_child(fig_box)
	var fig := FriendFigure.new()
	fig.look = c.get("look", {})
	fig.size = Vector2(132 if c.look.get("companion", "") == "" else 170, 168)
	fig.position = Vector2(132 - fig.size.x, 0) * 0.5
	fig_box.add_child(fig)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var title := Palette.label(c.nickname, 26, Palette.PINK_DEEP, Palette.title_font())
	v.add_child(title)
	var role := Palette.label(c.role, 16, Palette.CHOCO_SOFT, Palette.body_bold())
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(role)
	var info := Palette.label("", 16, Palette.CHOCO)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 20)
	var id: String = c.id
	btn.pressed.connect(func(): _on_card_button(id))
	v.add_child(btn)
	_cards[id] = {"figure": fig, "title": title, "role": role, "info": info, "button": btn}
	return card

func refresh_page() -> void:
	for c in GameData.characters:
		var w: Dictionary = _cards[c.id]
		var btn: Button = w.button
		var fig: Control = w.figure
		var recruited := CharacterSystem.is_recruited(c.id)
		var available := CharacterSystem.is_available(c.id)
		var ab: Dictionary = c.get("ability", {})
		if recruited:
			fig.modulate = Color.WHITE
			w.title.text = c.nickname
			w.info.text = "Bonus: %s\nVaardigheid %s: %s" % [CharacterSystem.bonus_text(c.id), ab.get("name", ""), ab.get("description", "")]
			var left := CharacterSystem.cooldown_left(c.id)
			btn.disabled = left > 0.0
			btn.text = ("%s (nog %s)" % [ab.get("name", ""), NumberFormat.duration(left)]) if left > 0.0 else ("%s!" % ab.get("name", "Vaardigheid"))
			_style_btn(btn, left <= 0.0)
		elif available:
			fig.modulate = Color.WHITE
			w.title.text = c.nickname
			w.info.text = "Bonus: %s" % CharacterSystem.bonus_text(c.id)
			var cost := float(c.get("unlock_cost", 0))
			btn.text = "Rekruteer · %s" % NumberFormat.format(cost)
			btn.disabled = GameState.cookies < cost
			_style_btn(btn, not btn.disabled)
		else:
			fig.modulate = Color(0.35, 0.12, 0.25, 0.55)   # silhouet
			w.title.text = "???"
			w.info.text = "Ontgrendel: %s" % CharacterSystem.condition_text(c.id)
			btn.text = "Nog vergrendeld"
			btn.disabled = true
			_style_btn(btn, false)

func _style_btn(btn: Button, hot: bool) -> void:
	if btn.has_meta("hot") and btn.get_meta("hot") == hot:
		return
	btn.set_meta("hot", hot)
	var col := Palette.PINK_DEEP if hot else Palette.PINK_LIGHT
	btn.add_theme_stylebox_override("normal", Palette.box(col, 18))
	btn.add_theme_stylebox_override("hover", Palette.box(col.lightened(0.08), 18))
	btn.add_theme_stylebox_override("pressed", Palette.box(col.darkened(0.1), 18))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(k, Palette.WHITE if hot else Palette.CHOCO)

func _on_card_button(id: String) -> void:
	if CharacterSystem.is_recruited(id):
		_try_ability(id)
	else:
		CharacterSystem.recruit(id)
	refresh_page()

# ------------------------------------------------------------ figuren naast de koek

func rebuild_field() -> void:
	for e in _field_figs.values():
		e.figure.queue_free()
		e.label.queue_free()
	_field_figs.clear()
	for id in CharacterSystem.recruited_ids():
		_add_field_figure(id)
	layout_field()

func _add_field_figure(id: String) -> void:
	var c = GameData.character_by_id[id]
	var fig := FriendFigure.new()
	fig.look = c.get("look", {})
	field.add_child(fig)
	fig.mouse_filter = Control.MOUSE_FILTER_STOP
	fig.gui_input.connect(func(ev: InputEvent):
		var tap: bool = (ev is InputEventScreenTouch and ev.pressed) or \
			(ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and ev.device != InputEvent.DEVICE_ID_EMULATION)
		if tap:
			fig.accept_event()
			_try_ability(id))
	var lbl := Palette.label("", 16, Palette.WHITE, Palette.body_bold())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_outline_color", Palette.PINK_DARK)
	lbl.add_theme_constant_override("outline_size", 6)
	field.add_child(lbl)
	_field_figs[id] = {"figure": fig, "label": lbl}

## Plaatst de vrienden in het speelveld. Menu dicht (hoog veld): drie vooraan onder de koek,
## twee naast de koek en één erboven, allemaal goed zichtbaar. Menu open (laag veld):
## twee vooraan in de onderhoeken, de rest kleiner achter de koek.
func layout_field() -> void:
	var ids := _field_figs.keys()
	var fs := field.size
	var tall: bool = main.has_method("is_play_tall") and main.is_play_tall()
	var slots: Array
	if tall:
		var cr: Rect2 = main.cookie_rect()
		var side_y: float = (cr.end.y + fs.y * 0.04) / fs.y
		slots = [
			[Vector2(0.0, 1.0), 0.27], [Vector2(1.0, 1.0), 0.27], [Vector2(0.5, 1.0), 0.27],
			[Vector2(0.0, side_y), 0.22], [Vector2(1.0, side_y), 0.22],
			[Vector2(0.03, (cr.position.y + fs.y * 0.17) / fs.y), 0.16]]
	else:
		slots = [
			[Vector2(0.0, 1.0), 0.56], [Vector2(1.0, 1.0), 0.56],
			[Vector2(0.06, 0.62), 0.42], [Vector2(0.94, 0.62), 0.42],
			[Vector2(0.22, 0.42), 0.3], [Vector2(0.78, 0.42), 0.3]]
	for i in ids.size():
		var e: Dictionary = _field_figs[ids[i]]
		var fig = e.figure
		if i >= slots.size():
			fig.visible = false
			e.label.visible = false
			continue
		fig.visible = true
		e.label.visible = true
		var anchor: Vector2 = slots[i][0]
		var h: float = fs.y * slots[i][1]
		var wide: bool = fig.look.get("companion", "") != ""
		var w := h * (1.05 if wide else 0.72)
		fig.size = Vector2(w, h)
		fig.position = Vector2(anchor.x * (fs.x - w), anchor.y * fs.y - h)
		# Laag veld: achterste rij achter de koek. Hoog veld: iedereen vooraan
		var layer: Control = field_back if (i >= 2 and not tall) else field
		if fig.get_parent() != layer:
			fig.reparent(layer, false)
		e.label.size = Vector2(w, 22)
		# Label boven het hoofd
		e.label.position = Vector2(fig.position.x, fig.position.y - 14)

func refresh_field() -> void:
	for id in _field_figs.keys():
		var lbl: Label = _field_figs[id].label
		var left := CharacterSystem.cooldown_left(id)
		if left > 0.0:
			lbl.text = NumberFormat.duration(left)
			lbl.modulate.a = 0.75
		else:
			lbl.text = "Tik: %s!" % GameData.character_by_id[id].ability.get("name", "")
			lbl.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 200.0)

func _try_ability(id: String) -> void:
	if CharacterSystem.use_ability(id):
		return
	if _field_figs.has(id):
		_field_figs[id].figure.play("happy")
	EventBus.toast.emit("%s is nog moe. Klaar over %s." % [GameData.character_by_id[id].nickname, NumberFormat.duration(CharacterSystem.cooldown_left(id))])

func _on_ability_used(id: String) -> void:
	if _field_figs.has(id):
		_field_figs[id].figure.play("ability")
	if _cards.has(id):
		_cards[id].figure.play("ability")
	var ab: Dictionary = GameData.character_by_id[id].ability
	EventBus.toast.emit("%s! %s" % [ab.get("name", ""), ab.get("description", "")])

# ------------------------------------------------------------ welkom-pop-up

func _on_recruited(id: String) -> void:
	_add_field_figure(id)
	layout_field()
	_field_figs[id].figure.play("happy")
	_show_intro(id)

func _show_intro(id: String) -> void:
	var c = GameData.character_by_id[id]
	var overlay := ColorRect.new()
	overlay.color = Color(0.35, 0.1, 0.2, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var ps := Palette.box(Palette.WHITE, 34, 16)
	ps.content_margin_left = 28; ps.content_margin_right = 28
	ps.content_margin_top = 24; ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(minf(main.get_viewport_rect().size.x - 50, 580), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := Palette.label("Nieuwe vriend!", 20, Palette.CHOCO_SOFT, Palette.body_bold())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var t := Palette.label(c.nickname, 40, Palette.PINK_DEEP, Palette.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var fig_box := Control.new()
	fig_box.custom_minimum_size = Vector2(0, 330)
	v.add_child(fig_box)
	var fig := FriendFigure.new()
	fig.look = c.get("look", {})
	fig_box.add_child(fig)
	fig_box.resized.connect(func():
		var w := 330.0 * (1.05 if fig.look.get("companion", "") != "" else 0.75)
		fig.size = Vector2(w, 330)
		fig.position = Vector2((fig_box.size.x - w) * 0.5, 0))
	fig.play("happy")
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Palette.box(Palette.PINK_LIGHT, 20))
	var quote := Palette.label("“%s”" % c.get("intro", ""), 19, Palette.CHOCO, Palette.body_bold())
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(quote)
	v.add_child(bubble)
	var desc := Palette.label(c.get("description", ""), 16, Palette.CHOCO_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var bonus := Palette.label("Bonus: %s" % CharacterSystem.bonus_text(id), 17, Palette.PINK_DARK, Palette.body_bold())
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bonus)
	var ok := Button.new()
	ok.text = "Welkom in het team!"
	ok.custom_minimum_size = Vector2(0, 62)
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", 26)
	_style_btn(ok, true)
	ok.pressed.connect(overlay.queue_free)
	v.add_child(ok)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	await main.get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
