extends Button
## Eén prestatie in het raster: een medaille met voortgangsring en de naam eronder.

var unlocked := false
var secret := false
var progress := 0.0
var title := ""
var _label: Label

func _init() -> void:
	custom_minimum_size = Vector2(0, 138)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(st, Palette.box(Color("#FFF6FA") if st != "pressed" else Palette.PINK_LIGHT, 18))
	_label = Palette.label("", 14, Palette.CHOCO, Palette.body_bold())
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func set_state(p_title: String, p_unlocked: bool, p_secret: bool, p_progress: float) -> void:
	if p_title == title and p_unlocked == unlocked and absf(p_progress - progress) < 0.01 and p_secret == secret:
		return
	title = p_title
	unlocked = p_unlocked
	secret = p_secret
	progress = p_progress
	_label.text = title if (unlocked or not secret) else "???"
	_label.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _label:
		_label.position = Vector2(4, 84)
		_label.size = Vector2(size.x - 8, size.y - 86)

func _draw() -> void:
	var c := Vector2(size.x * 0.5, 44)
	var r := 30.0
	if unlocked:
		# Lintje onder de medaille
		var rib := PackedVector2Array([c + Vector2(-16, 10), c + Vector2(-4, 10), c + Vector2(-10, 40), c + Vector2(-20, 34)])
		draw_colored_polygon(rib, Palette.PINK_DEEP)
		rib = PackedVector2Array([c + Vector2(4, 10), c + Vector2(16, 10), c + Vector2(20, 34), c + Vector2(10, 40)])
		draw_colored_polygon(rib, Palette.PINK)
		draw_circle(c + Vector2(0, 3), r, Palette.GOLD_DARK)
		draw_circle(c, r, Palette.GOLD)
		draw_circle(c, r * 0.72, Color("#FFDD73"))
		draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.45))
		_draw_star(c, r * 0.48, Palette.WHITE)
	else:
		draw_circle(c, r, Color("#EFE3E8"))
		if progress > 0.0:
			draw_arc(c, r - 3, -PI / 2, -PI / 2 + TAU * progress, 40, Palette.PINK, 6, true)
		var f := Palette.title_font()
		var t := "?" if secret else "%d%%" % int(progress * 100)
		var fs := 26 if secret else 17
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.CHOCO_SOFT)

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
