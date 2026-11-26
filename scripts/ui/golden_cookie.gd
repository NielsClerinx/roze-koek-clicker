extends Control
## De gouden roze koek: zweeft, glinstert en verdwijnt als je te traag bent.

signal claimed(global_pos: Vector2)

var lifetime := 12.0
var _t := 0.0
var _done := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	var hit: bool = (event is InputEventScreenTouch and event.pressed) or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION)
	if hit and not _done:
		_done = true
		accept_event()
		claimed.emit(get_global_rect().get_center())
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * 2.5) * 0.12
	position.y += sin(_t * 3.0) * 0.3
	if _t > lifetime - 2.0:
		modulate.a = 0.5 + 0.5 * absf(sin(_t * 10.0))
	if _t >= lifetime and not _done:
		_done = true
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ZERO, 0.3)
		tw.tween_callback(queue_free)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	for i in 8:
		var a := _t * 1.5 + TAU * i / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 1.05, c + Vector2(cos(a), sin(a)) * r * 1.35, Color(1, 0.95, 0.6, 0.8), 4.0, true)
	draw_circle(c + Vector2(0, r * 0.12), r, Palette.GOLD_DARK.darkened(0.2))
	draw_circle(c + Vector2(0, r * 0.05), r * 0.99, Palette.GOLD_DARK)
	draw_circle(c - Vector2(0, r * 0.03), r * 0.88, Palette.GOLD)
	draw_arc(c - Vector2(0, r * 0.03), r * 0.88, 0, TAU, 48, Palette.GOLD_DARK, 3.0, true)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.55))
	var tw := 0.5 + 0.5 * sin(_t * 6.0)
	draw_circle(c + Vector2(r * 0.45, -r * 0.45), r * 0.08 * tw + 1.0, Color.WHITE)
