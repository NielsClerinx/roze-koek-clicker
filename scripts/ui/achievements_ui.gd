extends Node
## De Prestaties-tab: drie dagelijkse uitdagingen, Roze Lintjes en het raster met prestaties.

const AchievementTile := preload("res://scripts/ui/achievement_tile.gd")

var main: Control
var page: ScrollContainer
var _challenge_rows: Array = []     # [{panel, text, bar, count, button}]
var _streak_label: Label
var _ribbon_label: Label
var _boost_btn: Button
var _ach_header: Label
var _tiles: Dictionary = {}         # id -> AchievementTile
var _tasks_key := ""

func setup(main_node: Control) -> void:
	main = main_node
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.challenge_completed.connect(func(_i): main.show_toast("Uitdaging voltooid! Haal je lintjes op bij Prestaties."))

func build_page() -> ScrollContainer:
	page = ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.scroll_deadzone = 12
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	page.add_child(list)

	list.add_child(Palette.label("Dagelijkse uitdagingen", 26, Palette.CHOCO, Palette.title_font()))
	_streak_label = Palette.label("", 17, Palette.CHOCO_SOFT, Palette.body_bold())
	_streak_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_streak_label)
	for i in ChallengeSystem.TASKS_PER_DAY:
		list.add_child(_build_challenge(i))

	var rib := HBoxContainer.new()
	rib.add_theme_constant_override("separation", 10)
	_ribbon_label = Palette.label("", 20, Palette.PINK_DEEP, Palette.title_font())
	_ribbon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(_ribbon_label)
	_boost_btn = Button.new()
	_boost_btn.focus_mode = Control.FOCUS_NONE
	_boost_btn.custom_minimum_size = Vector2(0, 50)
	_boost_btn.add_theme_font_size_override("font_size", 18)
	_boost_btn.pressed.connect(_on_boost)
	rib.add_child(_boost_btn)
	list.add_child(rib)

	_ach_header = Palette.label("", 26, Palette.CHOCO, Palette.title_font())
	list.add_child(_ach_header)
	var hint := Palette.label("Elke prestatie geeft voor altijd +1% productie. Tik op een medaille voor uitleg.", 16, Palette.CHOCO_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for a in GameData.achievements:
		var t := AchievementTile.new()
		var id: String = a.id
		t.pressed.connect(func(): _on_tile(id))
		grid.add_child(t)
		_tiles[id] = t
	return page

func _build_challenge(i: int) -> Control:
	var panel := PanelContainer.new()
	var ps := Palette.box(Color("#FFF6FA"), 20, 0, 2, Palette.PINK_LIGHT)
	ps.content_margin_left = 14; ps.content_margin_right = 14
	ps.content_margin_top = 10; ps.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", ps)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var text := Palette.label("", 19, Palette.CHOCO, Palette.body_bold())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.add_theme_stylebox_override("background", Palette.box(Color("#F3E4EA"), 7))
	bar.add_theme_stylebox_override("fill", Palette.box(Palette.PINK, 7))
	v.add_child(bar)
	var count := Palette.label("", 15, Palette.CHOCO_SOFT)
	v.add_child(count)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 54)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(func(): _on_claim(i))
	h.add_child(btn)
	_challenge_rows.append({"panel": panel, "text": text, "bar": bar, "count": count, "button": btn})
	return panel

func refresh_page() -> void:
	var tasks := ChallengeSystem.tasks()
	for i in _challenge_rows.size():
		var w: Dictionary = _challenge_rows[i]
		w.panel.visible = i < tasks.size()
		if i >= tasks.size():
			continue
		var t: Dictionary = tasks[i]
		var done := ChallengeSystem.is_done(i)
		w.text.text = ChallengeSystem.text(i)
		w.bar.value = clampf(float(t.progress) / maxf(float(t.goal), 1.0), 0.0, 1.0)
		w.count.text = "%s / %s" % [NumberFormat.format(floorf(float(t.progress))), NumberFormat.format(float(t.goal))]
		var btn: Button = w.button
		if t.claimed:
			btn.text = "Opgehaald ✓"
			btn.disabled = true
			_style_btn(btn, "done")
		elif done:
			btn.text = "Ophalen +%d" % ChallengeSystem.reward()
			btn.disabled = false
			_style_btn(btn, "hot")
		else:
			btn.text = "+%d lintjes" % ChallengeSystem.reward()
			btn.disabled = true
			_style_btn(btn, "cold")
	var sd := ChallengeSystem.streak_days()
	_streak_label.text = "Nieuwe opdrachten elke dag om middernacht. Reeks: %d/%d dagen%s" % [
		ChallengeSystem.streak(), sd,
		" (vandaag voltooid!)" if ChallengeSystem.all_claimed() else ""]
	_ribbon_label.text = "Roze Lintjes: %d" % GameState.ribbons
	var b := ChallengeSystem.boost_info()
	var active := RandomEventSystem.buffs.has("lintjes")
	_boost_btn.text = "Boost actief" if active else "Productie x%d (15 min) · %d" % [int(b.value), int(b.cost)]
	_boost_btn.disabled = active or GameState.ribbons < int(b.cost)
	_style_btn(_boost_btn, "cold" if _boost_btn.disabled else "hot")
	_ach_header.text = "Prestaties %d/%d · +%d%%" % [AchievementSystem.unlocked_count(), GameData.achievements.size(), AchievementSystem.unlocked_count()]
	for a in GameData.achievements:
		_tiles[a.id].set_state(a.name, AchievementSystem.is_unlocked(a.id), a.get("secret", false), AchievementSystem.progress(a.id))

## Aantal uitdagingen waarvan de beloning klaarligt (voor het tabbadge).
func claimable() -> int:
	var n := 0
	for i in ChallengeSystem.tasks().size():
		if ChallengeSystem.is_done(i) and not ChallengeSystem.tasks()[i].claimed:
			n += 1
	return n

func _style_btn(btn: Button, kind: String) -> void:
	if btn.has_meta("kind") and btn.get_meta("kind") == kind:
		return
	btn.set_meta("kind", kind)
	var col: Color = {"hot": Palette.PINK_DEEP, "done": Palette.MINT, "cold": Palette.PINK_LIGHT}[kind]
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(st, Palette.box(col if st != "pressed" else col.darkened(0.1), 18))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		btn.add_theme_color_override(k, Palette.CHOCO if kind == "cold" else Palette.WHITE)

func _on_claim(i: int) -> void:
	var got := ChallengeSystem.claim(i)
	if got > 0:
		main.show_toast("+%d Roze Lintjes!" % got)
	refresh_page()

func _on_boost() -> void:
	if ChallengeSystem.buy_boost():
		main.show_toast("Lintjesboost! Productie x%d" % int(ChallengeSystem.boost_info().value))
	refresh_page()

func _on_tile(id: String) -> void:
	var a: Dictionary = GameData.achievement_by_id[id]
	if AchievementSystem.is_unlocked(id):
		main.show_toast("%s: %s" % [a.name, a.description])
	elif a.get("secret", false):
		main.show_toast("Geheime prestatie. Ontdek het zelf!")
	else:
		main.show_toast("%s: %s (%d%%)" % [a.name, a.description, int(AchievementSystem.progress(id) * 100)])

func _on_achievement(id: String) -> void:
	main.show_toast("Prestatie behaald: %s! (+1%% productie)" % GameData.achievement_by_id[id].name)
