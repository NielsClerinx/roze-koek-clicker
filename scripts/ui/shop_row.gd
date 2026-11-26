extends Button
## Eén rij in de winkel (gebouw of upgrade). Puur weergave; main.gd vult de waarden.

const Badge := preload("res://scripts/ui/badge.gd")

var badge: Badge
var title: Label
var subtitle: Label
var price: Label
var tag: Label
var affordable := true

func _init() -> void:
	custom_minimum_size = Vector2(0, 92)
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	add_theme_stylebox_override("normal", Palette.box(Palette.WHITE, 22, 0, 2, Palette.PINK_LIGHT))
	add_theme_stylebox_override("hover", Palette.box(Color("#FFF6FA"), 22, 0, 2, Palette.PINK))
	add_theme_stylebox_override("pressed", Palette.box(Palette.PINK_LIGHT, 22, 0, 2, Palette.PINK))
	add_theme_stylebox_override("disabled", Palette.box(Color("#FBF7F8"), 22, 0, 2, Color("#F1E6EA")))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 14)
	add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 14)
	m.add_child(h)
	badge = Badge.new()
	badge.custom_minimum_size = Vector2(62, 62)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	title = Palette.label("", 24, Palette.CHOCO, Palette.title_font())
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title)
	subtitle = Palette.label("", 16, Palette.CHOCO_SOFT)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(subtitle)
	var pv := VBoxContainer.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 0)
	h.add_child(pv)
	price = Palette.label("", 22, Palette.PINK_DEEP, Palette.title_font())
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(price)
	tag = Palette.label("", 15, Palette.CHOCO_SOFT, Palette.body_bold())
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(tag)

func set_affordable(ok: bool) -> void:
	if ok == affordable:
		return
	affordable = ok
	price.add_theme_color_override("font_color", Palette.PINK_DEEP if ok else Palette.CHOCO_SOFT)
	badge.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.55)
	title.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.6)
	if ok:
		# Kort oplichten wanneer iets net betaalbaar wordt
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.02, 1.02), 0.08)
		tw.tween_property(self, "scale", Vector2.ONE, 0.15)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
