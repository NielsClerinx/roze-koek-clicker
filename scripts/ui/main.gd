extends Control
## Hoofdscherm. Bouwt de UI op in code en koppelt die aan de systemen.
## Bevat geen spelregels: alles loopt via Economy en de systemen.

const CookieView := preload("res://scripts/ui/cookie_view.gd")
const ShopRow := preload("res://scripts/ui/shop_row.gd")
const GoldenCookie := preload("res://scripts/ui/golden_cookie.gd")
const FriendsUI := preload("res://scripts/ui/friends_ui.gd")
const AchievementsUI := preload("res://scripts/ui/achievements_ui.gd")
const HeavenUI := preload("res://scripts/ui/heaven_ui.gd")
const DragScroll := preload("res://scripts/ui/drag_scroll.gd")

const TAB_NAMES := ["Gebouwen", "Upgrades", "Vrienden", "Prestaties", "Meer"]
const BUY_AMOUNTS := [1, 10, 100, 0]   # 0 = Max
const UPGRADE_COLORS := {
	"click": Color("#F26B9E"), "global": Color("#B39DDB"), "offline": Color("#80CBC4"),
	"golden": Color("#FFC93C"), "secret": Color("#5A2E3A"),
}

var _safe: MarginContainer
var _cookies_label: Label
var _kps_label: Label
var _buff_label: Label
var _play: Control
var _cookie: CookieView
var _fx_layer: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _buy_buttons: Array[Button] = []
var _buy_amount := 1
var _building_rows: Dictionary = {}
var _locked_row: ShopRow
var _upgrade_list: VBoxContainer
var _upgrade_rows: Dictionary = {}
var _upgrade_key := ""
var _upgrade_empty: Label
var _stats_label: Label
var _prestige_btn: Button
var _wipe_btn: Button
var _golden: GoldenCookie
var _refresh_t := 0.0
var _floaters := 0
var _name_taps := 0
var _rng := RandomNumberGenerator.new()
var _friends: FriendsUI
var _friend_layer: Control
var _menu_spacer: Control
var _menu_bar: PanelContainer
var _menu_btn: Button
var _sheet_clip: Control
var _sheet: PanelContainer
var _menu_t := 0.0
var _menu_open := false
var _menu_tween: Tween
var _sheet_h := 600.0
var _badge_upgrades := 0
var _gear_btn: Button
var _settings: ColorRect
var _setting_checks: Array[CheckButton] = []
var _achievements: AchievementsUI
var _heaven: HeavenUI

func _ready() -> void:
	_rng.randomize()
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_layout()
	EventBus.cookies_clicked.connect(_on_cookies_clicked)
	EventBus.golden_spawned.connect(_on_golden_spawned)
	EventBus.golden_claimed.connect(show_toast)
	EventBus.toast.connect(show_toast)
	EventBus.offline_earned.connect(_on_offline_earned)
	EventBus.upgrade_bought.connect(func(_id): _upgrade_key = "")
	EventBus.game_reset.connect(_on_reset)
	get_viewport().size_changed.connect(_apply_safe_area)
	get_tree().set_quit_on_go_back(false)
	_menu_bar.item_rect_changed.connect(_layout_sheet)
	var last := SaveManager.load_game()
	if SaveManager.loaded_from_disk:
		OfflineSystem.apply_since(last)
	_apply_safe_area()
	_select_tab(0)
	_refresh(true)

# ------------------------------------------------------------ opbouw

func _build_background() -> void:
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Palette.BG_TOP)
	grad.set_color(1, Palette.BG_BOTTOM)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 8
	gt.height = 256
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_layout() -> void:
	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_safe.add_child(root)

	# --- Topbalk
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", -4)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top)
	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.add_theme_font_size_override("font_size", 20)
	name_btn.add_theme_color_override("font_color", Palette.PINK_DARK)
	name_btn.add_theme_color_override("font_hover_color", Palette.PINK_DARK)
	name_btn.add_theme_color_override("font_pressed_color", Palette.PINK_DEEP)
	for st in ["normal", "hover", "pressed"]:
		name_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	name_btn.pressed.connect(_on_name_tapped)
	top.add_child(name_btn)
	_cookies_label = Palette.label("0", 54, Palette.CHOCO, Palette.title_font())
	_cookies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_cookies_label)
	_kps_label = Palette.label("per seconde: 0", 22, Palette.CHOCO_SOFT, Palette.body_bold())
	_kps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_kps_label)
	_buff_label = Palette.label("", 18, Palette.PINK_DEEP, Palette.body_bold())
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.custom_minimum_size = Vector2(0, 26)
	top.add_child(_buff_label)
	set_meta("name_btn", name_btn)

	# --- Speelveld (krijgt het hele scherm als het menu dicht is)
	_play = Control.new()
	_play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play.clip_contents = false
	_play.resized.connect(_layout_play)
	root.add_child(_play)
	_cookie = CookieView.new()
	_cookie.tapped.connect(_on_cookie_tapped)
	# Vrienden: achterste rij achter de koek, voorste rij ervoor
	var back_layer := Control.new()
	back_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(back_layer)
	_play.add_child(_cookie)
	_friend_layer = Control.new()
	_friend_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_friend_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(_friend_layer)
	_friends = FriendsUI.new()
	add_child(_friends)
	_friends.setup(self, _friend_layer, back_layer)
	_achievements = AchievementsUI.new()
	add_child(_achievements)
	_achievements.setup(self)
	_heaven = HeavenUI.new()
	add_child(_heaven)
	_heaven.setup(self)

	# Ruimte die het menu inneemt als het open is (wordt geanimeerd)
	_menu_spacer = Control.new()
	_menu_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_menu_spacer)

	# --- Menubalk onderaan met de hamburgerknop
	_menu_bar = PanelContainer.new()
	var bar_style := StyleBoxEmpty.new()
	bar_style.content_margin_top = 8
	bar_style.content_margin_bottom = 14
	_menu_bar.add_theme_stylebox_override("panel", bar_style)
	root.add_child(_menu_bar)
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_bar.add_child(bar_row)
	_menu_btn = Button.new()
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.custom_minimum_size = Vector2(300, 64)
	_menu_btn.add_theme_font_size_override("font_size", 24)
	_menu_btn.add_theme_constant_override("h_separation", 14)
	_menu_btn.icon = _hamburger_icon()
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_menu_btn.add_theme_stylebox_override(st, Palette.box(Palette.PINK_DEEP if st != "pressed" else Palette.PINK_DARK, 32))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_menu_btn.add_theme_color_override(c, Palette.WHITE)
	_menu_btn.add_theme_color_override("icon_normal_color", Palette.WHITE)
	_menu_btn.add_theme_color_override("icon_hover_color", Palette.WHITE)
	_menu_btn.add_theme_color_override("icon_pressed_color", Palette.WHITE)
	_menu_btn.pressed.connect(toggle_menu)
	bar_row.add_child(_menu_btn)

	# --- Menu (schuift omhoog vanachter de menubalk)
	_sheet_clip = Control.new()
	_sheet_clip.clip_contents = true
	_sheet_clip.visible = false
	add_child(_sheet_clip)
	_sheet = PanelContainer.new()
	var sheet_style := Palette.box(Palette.WHITE, 34, 14)
	sheet_style.corner_radius_bottom_left = 0
	sheet_style.corner_radius_bottom_right = 0
	sheet_style.content_margin_top = 16
	sheet_style.content_margin_left = 16
	sheet_style.content_margin_right = 16
	sheet_style.content_margin_bottom = 4
	_sheet.add_theme_stylebox_override("panel", sheet_style)
	_sheet_clip.add_child(_sheet)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	_sheet.add_child(sv)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	sv.add_child(tabs)
	tabs.add_theme_constant_override("separation", 6)
	for t in TAB_NAMES:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.add_theme_constant_override("h_separation", 0)
		# Vijf tabs: smallere binnenmarge zodat "Prestaties (2)" past
		var cols := {"normal": Palette.PINK_LIGHT, "hover": Palette.PINK_LIGHT.lightened(0.2),
			"pressed": Palette.PINK_DEEP, "hover_pressed": Palette.PINK_DEEP}
		for st in cols.keys():
			var sb := Palette.box(cols[st], 22)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_pressed_color", Palette.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Palette.WHITE)
		var idx := _tab_buttons.size()
		b.pressed.connect(func(): _select_tab(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(pages)
	_pages = [_build_buildings_page(), _build_upgrades_page(), _friends.build_page(), _achievements.build_page(), _build_more_page()]
	var drag := DragScroll.new()
	add_child(drag)
	for p in _pages:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)
		for sc in p.find_children("*", "ScrollContainer", true, false) + ([p] if p is ScrollContainer else []):
			drag.register(sc)

	# --- Effectlaag (zwevende getallen, toast, gouden koek)
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_toast = PanelContainer.new()
	var ts := Palette.box(Palette.CHOCO, 26, 8)
	ts.content_margin_left = 22; ts.content_margin_right = 22
	_toast.add_theme_stylebox_override("panel", ts)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = Palette.label("", 20, Palette.WHITE, Palette.body_bold())
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_build_settings()

# ------------------------------------------------------------ instellingen

func _gear_icon() -> ImageTexture:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var ang := d.angle()
			var tooth := 1.0 if fmod(ang / TAU * 8.0 + 8.25, 1.0) < 0.5 else 0.0
			var r_out: float = 14.0 + 5.0 * tooth
			var r := d.length()
			var a: float = clampf(r_out - r + 0.5, 0.0, 1.0) * clampf(r - 6.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Schakelaar-icoon (pil met bolletje), groter en duidelijker dan het standaard vinkje.
func _toggle_icon(on: bool) -> ImageTexture:
	var w := 76
	var h := 42
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Palette.PINK_DEEP if on else Color("#D9C3CB")
	var r := h * 0.5
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var a := clampf(r - p.distance_to(Vector2(cx, r)) + 0.5, 0.0, 1.0)
			var col := bg
			var kd := p.distance_to(Vector2(knob_x, r))
			var ka := clampf(r - 5.0 - kd + 0.5, 0.0, 1.0)
			col = col.lerp(Color.WHITE, ka)
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func _build_settings() -> void:
	# Tandwiel rechtsboven
	_gear_btn = Button.new()
	_gear_btn.icon = _gear_icon()
	_gear_btn.focus_mode = Control.FOCUS_NONE
	_gear_btn.custom_minimum_size = Vector2(64, 64)
	_gear_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_gear_btn.add_theme_stylebox_override(st, Palette.box(Palette.PINK_LIGHT if st != "pressed" else Palette.PINK, 32))
	for st in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		_gear_btn.add_theme_color_override(st, Palette.PINK_DARK)
	_gear_btn.pressed.connect(open_settings)
	add_child(_gear_btn)

	_settings = ColorRect.new()
	_settings.color = Color(0.35, 0.1, 0.2, 0.45)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	_settings.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_settings())
	add_child(_settings)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings.add_child(center)
	var panel := PanelContainer.new()
	var ps := Palette.box(Palette.WHITE, 34, 16)
	ps.content_margin_left = 30; ps.content_margin_right = 30
	ps.content_margin_top = 26; ps.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60, 560), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := Palette.label("Instellingen", 36, Palette.PINK_DEEP, Palette.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var toggles := [
		["Geluidseffecten", AudioManager.sound_on(), AudioManager.set_sound],
		["Achtergrondmuziek", AudioManager.music_on(), AudioManager.set_music],
		["Trillen bij kritieke klik", bool(GameState.settings.get("vibration", true)),
			func(on): GameState.settings["vibration"] = on],
	]
	_setting_checks.clear()
	var icon_on := _toggle_icon(true)
	var icon_off := _toggle_icon(false)
	for row in toggles:
		var cb := CheckButton.new()
		cb.text = row[0]
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = row[1]
		cb.toggled.connect(row[2])
		cb.add_theme_font_override("font", Palette.body_bold())
		cb.add_theme_font_size_override("font_size", 22)
		cb.custom_minimum_size = Vector2(0, 56)
		cb.add_theme_icon_override("checked", icon_on)
		cb.add_theme_icon_override("unchecked", icon_off)
		cb.add_theme_icon_override("checked_mirrored", icon_on)
		cb.add_theme_icon_override("unchecked_mirrored", icon_off)
		v.add_child(cb)
		_setting_checks.append(cb)
	var auto := Palette.label("Je voortgang wordt automatisch bewaard.", 17, Palette.CHOCO_SOFT)
	auto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(auto)
	_wipe_btn = Button.new()
	_wipe_btn.text = "Spel wissen"
	_wipe_btn.custom_minimum_size = Vector2(0, 56)
	_wipe_btn.focus_mode = Control.FOCUS_NONE
	_wipe_btn.add_theme_color_override("font_color", Color("#C0392B"))
	_wipe_btn.pressed.connect(_on_wipe_pressed)
	v.add_child(_wipe_btn)
	var ok := Button.new()
	ok.text = "Klaar"
	ok.custom_minimum_size = Vector2(0, 62)
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_stylebox_override("normal", Palette.box(Palette.PINK_DEEP, 24))
	ok.add_theme_stylebox_override("hover", Palette.box(Palette.PINK_DEEP.lightened(0.1), 24))
	ok.add_theme_stylebox_override("pressed", Palette.box(Palette.PINK_DARK, 24))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		ok.add_theme_color_override(c, Palette.WHITE)
	ok.add_theme_font_size_override("font_size", 26)
	ok.pressed.connect(close_settings)
	v.add_child(ok)
	var ver := Palette.label("Roze Koek Clicker v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 16, Palette.CHOCO_SOFT)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)

func open_settings() -> void:
	_setting_checks[0].set_pressed_no_signal(AudioManager.sound_on())
	_setting_checks[1].set_pressed_no_signal(AudioManager.music_on())
	_setting_checks[2].set_pressed_no_signal(bool(GameState.settings.get("vibration", true)))
	_settings.visible = true
	move_child(_settings, -1)

func close_settings() -> void:
	_settings.visible = false

func is_settings_open() -> bool:
	return _settings.visible

func _scroll_page() -> Array:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 12
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	return [sc, list]

func _build_buildings_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var amounts := HBoxContainer.new()
	amounts.add_theme_constant_override("separation", 6)
	var lbl := Palette.label("Koop", 18, Palette.CHOCO_SOFT, Palette.body_bold())
	amounts.add_child(lbl)
	for a in BUY_AMOUNTS:
		var b := Button.new()
		b.text = "Max" if a == 0 else "x%d" % a
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_stylebox_override("normal", Palette.box(Color("#FFF1F6"), 16))
		b.add_theme_stylebox_override("pressed", Palette.box(Palette.PINK, 16))
		b.add_theme_stylebox_override("hover_pressed", Palette.box(Palette.PINK, 16))
		b.add_theme_color_override("font_pressed_color", Palette.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Palette.WHITE)
		b.pressed.connect(func(): _set_buy_amount(a))
		amounts.add_child(b)
		_buy_buttons.append(b)
	page.add_child(amounts)
	var pair := _scroll_page()
	pair[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(pair[0])
	var list: VBoxContainer = pair[1]
	for b in GameData.buildings:
		var row := ShopRow.new()
		row.title.text = b.name
		row.badge.color = Color(b.color)
		row.badge.text = b.name.substr(0, 1)
		var id: String = b.id
		row.pressed.connect(func(): _buy_building(id, row))
		list.add_child(row)
		_building_rows[id] = row
	_locked_row = ShopRow.new()
	_locked_row.disabled = true
	_locked_row.badge.locked = true
	_locked_row.title.text = "???"
	_locked_row.subtitle.text = "Bak meer om dit te ontdekken"
	list.add_child(_locked_row)
	_set_buy_amount(1)
	return page

func _build_upgrades_page() -> Control:
	var pair := _scroll_page()
	_upgrade_list = pair[1]
	_upgrade_empty = Palette.label("Nog geen upgrades beschikbaar.\nKoop meer gebouwen!", 20, Palette.CHOCO_SOFT)
	_upgrade_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_empty.custom_minimum_size = Vector2(0, 120)
	_upgrade_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_list.add_child(_upgrade_empty)
	return pair[0]

func _build_more_page() -> Control:
	var pair := _scroll_page()
	var list: VBoxContainer = pair[1]
	list.add_theme_constant_override("separation", 14)
	list.add_child(Palette.label("Statistieken", 26, Palette.CHOCO, Palette.title_font()))
	_stats_label = Palette.label("", 19, Palette.CHOCO)
	list.add_child(_stats_label)
	list.add_child(Palette.label("Herglazuren", 26, Palette.CHOCO, Palette.title_font()))
	var info := Palette.label("Vanaf 1 T roze koeken gebakken kun je opnieuw beginnen in ruil voor Fondantkristallen. Elk kristal geeft voor altijd +2% productie.", 18, Palette.CHOCO_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(info)
	_prestige_btn = Button.new()
	_prestige_btn.custom_minimum_size = Vector2(0, 60)
	_prestige_btn.focus_mode = Control.FOCUS_NONE
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	list.add_child(_prestige_btn)
	_heaven.build_section(list)
	var open_set := Button.new()
	open_set.text = "Instellingen (geluid, muziek, trillen)"
	open_set.custom_minimum_size = Vector2(0, 56)
	open_set.focus_mode = Control.FOCUS_NONE
	open_set.pressed.connect(open_settings)
	list.add_child(open_set)
	var ver := Palette.label("Roze Koek Clicker v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 16, Palette.CHOCO_SOFT)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(ver)
	return pair[0]

func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp := get_viewport_rect().size
	var top := 10.0
	var bottom := 0.0
	if OS.has_feature("mobile") and screen.y > 0:
		var scale_y := vp.y / float(screen.y)
		top = maxf(safe.position.y * scale_y, 10.0)
		bottom = maxf((screen.y - safe.end.y) * scale_y, 0.0)
	_safe.add_theme_constant_override("margin_top", int(top))
	_safe.add_theme_constant_override("margin_bottom", int(bottom))
	_safe.add_theme_constant_override("margin_left", 0)
	_safe.add_theme_constant_override("margin_right", 0)
	_layout_sheet.call_deferred()
	if _gear_btn:
		_gear_btn.position = Vector2(get_viewport_rect().size.x - 64 - 14, top + 4)

func _layout_play() -> void:
	var ps := _play.size
	var s: float
	var center: Vector2
	if is_play_tall():
		# Menu dicht: koek in het midden, vrienden in een kring eromheen
		s = minf(ps.x * 0.54, ps.y * 0.35)
		center = ps * 0.5
	else:
		s = minf(ps.x * 0.8, ps.y * 0.92)
		center = ps * 0.5
	_cookie.size = Vector2(s, s)
	_cookie.position = center - _cookie.size * 0.5
	_cookie.pivot_offset = _cookie.size * 0.5
	if _friends:
		_friends.layout_field()

## Hoog speelveld (menu dicht) of laag (menu open).
func is_play_tall() -> bool:
	return _play.size.y > _play.size.x * 1.05

func cookie_rect() -> Rect2:
	return Rect2(_cookie.position, _cookie.size)

# ------------------------------------------------------------ menu

func _hamburger_icon() -> ImageTexture:
	var img := Image.create(30, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for i in 3:
		img.fill_rect(Rect2i(0, i * 10, 30, 4), Color.WHITE)
	return ImageTexture.create_from_image(img)

func is_menu_open() -> bool:
	return _menu_open

func open_menu(tab := -1) -> void:
	if tab >= 0:
		_select_tab(tab)
	_animate_menu(true)

func close_menu() -> void:
	_animate_menu(false)

func toggle_menu() -> void:
	_animate_menu(not _menu_open)

func _animate_menu(open: bool) -> void:
	_menu_open = open
	_update_menu_button()
	if _menu_tween:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_method(_set_menu_t, _menu_t, 1.0 if open else 0.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if open:
		_refresh(true)

func _set_menu_t(t: float) -> void:
	_menu_t = t
	_layout_sheet()

## Zet het menu en de ruimte erboven op de juiste plek voor de huidige stand (_menu_t).
func _layout_sheet() -> void:
	if _sheet == null:
		return
	var vp := size
	var bar_top := _menu_bar.get_global_rect().position.y
	if _menu_bar.size.y <= 0.0:
		return
	_sheet_h = roundf(vp.y * 0.5)
	var shown := roundf(_sheet_h * _menu_t)
	_menu_spacer.custom_minimum_size = Vector2(0, shown)
	# De balk schuift niet: hij staat onderaan, dus de bovenkant blijft gelijk
	_sheet_clip.visible = shown > 0.5
	_sheet_clip.position = Vector2(0, bar_top - shown)
	_sheet_clip.size = Vector2(vp.x, shown)
	_sheet.position = Vector2.ZERO
	_sheet.size = Vector2(vp.x, _sheet_h)

func _update_menu_button() -> void:
	if _menu_btn == null:
		return
	if _menu_open:
		_menu_btn.text = "Sluiten"
		return
	var n := _badge_upgrades + _achievements.claimable()
	_menu_btn.text = "Menu" + ("  (%d)" % n if n > 0 else "")

func _notification(what: int) -> void:
	# Terugknop van Android: eerst het menu sluiten
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings and _settings.visible:
			close_settings()
		elif _menu_open:
			close_menu()
		else:
			SaveManager.save_game()
			get_tree().quit()

# ------------------------------------------------------------ interactie

func _select_tab(i: int) -> void:
	for j in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == i)
		_pages[j].visible = j == i
	_refresh(true)

func _set_buy_amount(a: int) -> void:
	_buy_amount = a
	for j in _buy_buttons.size():
		_buy_buttons[j].set_pressed_no_signal(BUY_AMOUNTS[j] == a)
	_refresh(true)

func _on_cookie_tapped(global_pos: Vector2) -> void:
	ClickSystem.click(global_pos)

func _on_cookies_clicked(amount: float, crit: bool, pos: Vector2) -> void:
	_spawn_floater(("KRITIEK! +" if crit else "+") + NumberFormat.format(amount, true), pos, crit)
	if crit:
		_cookie.burst(_cookie.get_global_transform().affine_inverse() * pos, 14)
		if GameState.settings.get("vibration", true):
			Input.vibrate_handheld(25)
	_refresh_top()

func _spawn_floater(text: String, pos: Vector2, big: bool) -> void:
	if _floaters > 30:
		return
	_floaters += 1
	var l := Palette.label(text, 34 if big else 28, Palette.GOLD_DARK if big else Palette.WHITE, Palette.title_font())
	l.add_theme_color_override("font_outline_color", Palette.PINK_DARK if not big else Palette.CHOCO)
	l.add_theme_constant_override("outline_size", 8)
	_fx_layer.add_child(l)
	l.reset_size()
	l.position = pos - l.size * 0.5 + Vector2(_rng.randf_range(-24, 24), -30)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 140.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(func():
		_floaters -= 1
		l.queue_free())

func _buy_building(id: String, row: ShopRow) -> void:
	var n := ProductionSystem.buy(id, _buy_amount)
	if n > 0:
		var tw := row.create_tween()
		tw.tween_property(row, "scale", Vector2(0.97, 0.97), 0.05)
		tw.tween_property(row, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh(true)

func _buy_upgrade(id: String) -> void:
	if UpgradeSystem.buy(id):
		show_toast("Upgrade gekocht: %s" % GameData.upgrade_by_id[id].name)
	_refresh(true)

func _on_name_tapped() -> void:
	_name_taps += 1
	if _name_taps == 7:
		if UpgradeSystem.unlock_secret("secret_ikbendekoek"):
			_cookie.sunglasses = true

func _on_golden_spawned() -> void:
	if is_instance_valid(_golden):
		_golden.queue_free()
	_golden = GoldenCookie.new()
	_golden.size = Vector2(110, 110)
	var area := _play.get_global_rect()
	_golden.position = Vector2(
		_rng.randf_range(area.position.x + 10, area.end.x - 120),
		_rng.randf_range(area.position.y + 10, area.end.y - 120))
	_golden.lifetime = Economy.golden_lifetime()
	_golden.claimed.connect(func(p: Vector2):
		RandomEventSystem.claim_golden()
		_spawn_floater("GOUDEN KOEK!", p, true))
	add_child(_golden)
	move_child(_toast, -1)

func _on_offline_earned(amount: float, seconds: float) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.35, 0.1, 0.2, 0.45)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var ps := Palette.box(Palette.WHITE, 34, 16)
	ps.content_margin_left = 32; ps.content_margin_right = 32
	ps.content_margin_top = 28; ps.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", ps)
	panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 60, 560), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := Palette.label("Welkom terug!", 38, Palette.PINK_DEEP, Palette.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var away := Palette.label("Je was %s weg. Je bakkers bakten ondertussen:" % NumberFormat.duration(seconds), 19, Palette.CHOCO_SOFT)
	away.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	away.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(away)
	var amt := Palette.label("+" + NumberFormat.format(amount), 46, Palette.CHOCO, Palette.title_font())
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(amt)
	var sub := Palette.label("roze koeken (%d%% efficiëntie, max %s)" % [int(Economy.offline_efficiency() * 100), NumberFormat.duration(Economy.offline_cap_seconds())], 16, Palette.CHOCO_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var ok := Button.new()
	ok.text = "Lekker!"
	ok.custom_minimum_size = Vector2(0, 64)
	ok.add_theme_stylebox_override("normal", Palette.box(Palette.PINK_DEEP, 24))
	ok.add_theme_stylebox_override("hover", Palette.box(Palette.PINK_DEEP.lightened(0.1), 24))
	ok.add_theme_stylebox_override("pressed", Palette.box(Palette.PINK_DARK, 24))
	ok.add_theme_color_override("font_color", Palette.WHITE)
	ok.add_theme_color_override("font_hover_color", Palette.WHITE)
	ok.add_theme_color_override("font_pressed_color", Palette.WHITE)
	ok.add_theme_font_size_override("font_size", 28)
	ok.pressed.connect(overlay.queue_free)
	v.add_child(ok)
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)

func _on_prestige_pressed() -> void:
	if not PrestigeSystem.can_prestige():
		return
	if _prestige_btn.get_meta("confirm", false):
		var g := PrestigeSystem.prestige()
		show_toast("Herglazuurd! +%d Fondantkristallen" % g)
		_prestige_btn.set_meta("confirm", false)
	else:
		_prestige_btn.set_meta("confirm", true)
		_prestige_btn.text = "Zeker? Tik nogmaals om te herglazuren"
		get_tree().create_timer(4.0).timeout.connect(func(): _prestige_btn.set_meta("confirm", false))

func _on_wipe_pressed() -> void:
	if _wipe_btn.get_meta("confirm", false):
		SaveManager.wipe()
		show_toast("Nieuw begin. Veel bakplezier!")
		_wipe_btn.set_meta("confirm", false)
		_wipe_btn.text = "Spel wissen"
	else:
		_wipe_btn.set_meta("confirm", true)
		_wipe_btn.text = "Echt alles wissen? Tik nogmaals"
		get_tree().create_timer(4.0).timeout.connect(func():
			_wipe_btn.set_meta("confirm", false)
			_wipe_btn.text = "Spel wissen")

func _on_reset() -> void:
	_cookie.sunglasses = GameState.has_upgrade("secret_ikbendekoek")
	_upgrade_key = ""
	_refresh(true)

func show_toast(msg: String) -> void:
	_toast_label.text = msg
	var w := minf(get_viewport_rect().size.x - 40, 600)
	_toast_label.custom_minimum_size = Vector2(w - 44, 0)
	_toast.custom_minimum_size = Vector2(w, 0)
	_toast.size = Vector2(w, 0)
	_toast.reset_size()
	_toast.position = Vector2((get_viewport_rect().size.x - w) * 0.5, _play.get_global_rect().position.y + 6)
	if _toast_tween:
		_toast_tween.kill()
	var tw := _toast.create_tween()
	_toast_tween = tw
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	# De tekstomloop wordt pas na een frame berekend: daarna de hoogte opnieuw bepalen.
	tw.parallel().tween_callback(_toast.reset_size).set_delay(0.05)
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

# ------------------------------------------------------------ verversen

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= 0.2:
		_refresh_t = 0.0
		_refresh(false)

func _refresh_top() -> void:
	_cookies_label.text = NumberFormat.format(GameState.cookies)
	_kps_label.text = "roze koeken · %s per seconde" % NumberFormat.format(Economy.kps(), true)

func _refresh(force: bool) -> void:
	if _pages.size() < TAB_NAMES.size():
		return   # UI wordt nog opgebouwd
	_refresh_top()
	var name_btn: Button = get_meta("name_btn")
	name_btn.text = GameState.bakery_name
	_cookie.sunglasses = GameState.has_upgrade("secret_ikbendekoek")
	var buffs: Array[String] = []
	for b in RandomEventSystem.buffs.values():
		buffs.append("%s · %d s" % [b.label, ceili(b.left)])
	_buff_label.text = "   ".join(buffs)
	if _pages[0].visible or force:
		_refresh_buildings()
	if _pages[1].visible or force:
		_refresh_upgrades()
	_friends.refresh_field()
	if _pages[2].visible or force:
		_friends.refresh_page()
	if _pages[3].visible or force:
		_achievements.refresh_page()
	# Tellers op de tabs en de menuknop: betaalbare upgrades en op te halen prestaties
	var affordable := 0
	for u in UpgradeSystem.available():
		if GameState.cookies >= float(u.cost):
			affordable += 1
	_badge_upgrades = affordable
	_tab_buttons[1].text = "Upgrades" + (" (%d)" % affordable if affordable > 0 else "")
	_update_menu_button()
	var claim := _achievements.claimable()
	_tab_buttons[3].text = "Prestaties" + (" (%d)" % claim if claim > 0 else "")
	if _pages[4].visible:
		_refresh_more()
		_heaven.refresh()

func _refresh_buildings() -> void:
	var shown_locked := false
	for b in GameData.buildings:
		var row: ShopRow = _building_rows[b.id]
		var vis := ProductionSystem.is_visible_in_shop(b.id)
		row.visible = vis
		if not vis:
			if not shown_locked:
				shown_locked = true
				_locked_row.get_parent().move_child(_locked_row, row.get_index())
			continue
		var n := GameState.count(b.id)
		var amount := _buy_amount
		if amount == 0:
			amount = maxi(Economy.max_affordable(b.id), 1)
		var cost := Economy.building_cost(b.id, amount)
		row.price.text = NumberFormat.format(cost)
		row.tag.text = "x%d" % amount if amount > 1 else ""
		var each := Economy.building_kps_each(b.id)
		if n > 0:
			row.subtitle.text = "%d in bezit · %s/s" % [n, NumberFormat.format(Economy.building_kps_total(b.id), true)]
		else:
			row.subtitle.text = "+%s/s per stuk" % NumberFormat.format(each, true)
		row.tooltip_text = b.description
		row.set_affordable(GameState.cookies >= cost)
	_locked_row.visible = shown_locked

func _refresh_upgrades() -> void:
	var avail := UpgradeSystem.available()
	var key := ",".join(avail.map(func(u): return u.id))
	if key != _upgrade_key:
		_upgrade_key = key
		for r in _upgrade_rows.values():
			r.queue_free()
		_upgrade_rows.clear()
		for u in avail.slice(0, 25):
			var row := ShopRow.new()
			row.title.text = u.name
			row.subtitle.text = u.description
			row.price.text = NumberFormat.format(float(u.cost))
			var kind := _upgrade_kind(u)
			row.badge.color = UPGRADE_COLORS.get(kind, Palette.PINK)
			if kind == "building":
				var bid: String = u.condition.building
				row.badge.color = Color(GameData.building_by_id[bid].color)
				row.badge.text = GameData.building_by_id[bid].name.substr(0, 1)
			else:
				row.badge.text = {"click": "K", "global": "★", "offline": "Z", "golden": "G", "secret": "?"}.get(kind, "+")
			var id: String = u.id
			row.pressed.connect(func(): _buy_upgrade(id))
			_upgrade_list.add_child(row)
			_upgrade_rows[id] = row
	_upgrade_empty.visible = avail.is_empty()
	for id in _upgrade_rows.keys():
		var u = GameData.upgrade_by_id[id]
		_upgrade_rows[id].set_affordable(GameState.cookies >= float(u.cost))

func _upgrade_kind(u: Dictionary) -> String:
	var id: String = u.id
	if id.begins_with("click_"): return "click"
	if id.begins_with("global_"): return "global"
	if id.begins_with("offline_"): return "offline"
	if id.begins_with("golden_"): return "golden"
	if id.begins_with("secret_"): return "secret"
	return "building"

func _refresh_more() -> void:
	var lines := [
		"Gebakken deze run: %s" % NumberFormat.format(GameState.baked_run),
		"Ooit gebakken: %s" % NumberFormat.format(GameState.baked_lifetime),
		"Kliks: %s (kritiek: %s), ooit: %s" % [NumberFormat.format(GameState.clicks), NumberFormat.format(GameState.crits), NumberFormat.format(GameState.clicks_total)],
		"Per klik: %s" % NumberFormat.format(Economy.click_value(), true),
		"Kritieke kans: %d%% (x%d)" % [int(round(Economy.crit_chance() * 100)), int(Economy.crit_mult())],
		"Gouden koeken gevangen: %d" % GameState.golden_clicked,
		"Fondantkristallen: %d (+%d%% productie, %d te besteden)" % [GameState.crystals, GameState.crystals * 2, GameState.crystals_available()],
		"Prestaties: %d/%d (+%d%% productie)" % [AchievementSystem.unlocked_count(), GameData.achievements.size(), AchievementSystem.unlocked_count()],
		"Roze Lintjes: %d" % GameState.ribbons,
		"Offline: %d%% tot %s" % [int(Economy.offline_efficiency() * 100), NumberFormat.duration(Economy.offline_cap_seconds())],
		"Speeltijd: %s" % NumberFormat.duration(GameState.play_seconds),
	]
	_stats_label.text = "\n".join(lines)
	var pending := Economy.crystals_pending()
	_prestige_btn.disabled = pending < 1
	if not _prestige_btn.get_meta("confirm", false):
		_prestige_btn.text = "Herglazuren: +%d kristallen" % pending if pending > 0 else "Herglazuren (nog niet beschikbaar)"
