extends Control
## De grote roze koek: getekend in code (scherp op elke resolutie), met squash, stralen en kruimels.

signal tapped(global_pos: Vector2)

const MAX_CRUMBS := 140

var golden := false          # zelfde tekening als gouden variant
var squash := 1.0
var sunglasses := false
var _t := 0.0
var _crumbs: Array = []       # [pos, vel, life, color, size]
var _rng := RandomNumberGenerator.new()
var _tween: Tween

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP

func radius() -> float:
	return minf(size.x, size.y) * 0.5 * 0.80

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius() * 1.02

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
	if pos != Vector2.INF:
		accept_event()
		_on_tap(pos)

func _on_tap(local_pos: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "squash", 0.9, 0.05).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "squash", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst(local_pos, 7)
	tapped.emit(get_global_transform() * local_pos)

func burst(local_pos: Vector2, n: int) -> void:
	for i in n:
		if _crumbs.size() >= MAX_CRUMBS:
			_crumbs.pop_front()
		var ang := _rng.randf_range(-PI, 0.0)
		var spd := _rng.randf_range(180.0, 420.0)
		var col: Color = [Palette.PINK, Palette.CAKE, Palette.PINK_LIGHT, Palette.CAKE_DARK][_rng.randi() % 4]
		if golden:
			col = Palette.GOLD
		_crumbs.append([local_pos, Vector2(cos(ang), sin(ang)) * spd, _rng.randf_range(0.5, 0.9), col, _rng.randf_range(5.0, 11.0)])

func _process(delta: float) -> void:
	_t += delta
	for c in _crumbs:
		c[1].y += 980.0 * delta
		c[0] += c[1] * delta
		c[2] -= delta
	_crumbs = _crumbs.filter(func(c): return c[2] > 0.0)
	queue_redraw()

func _draw() -> void:
	var r := radius()
	var center := size * 0.5
	var breathe := 1.0 + 0.012 * sin(_t * 2.2)
	var s := squash * breathe
	# Stralen
	if not golden:
		var rays := 14
		for i in rays:
			var a := _t * 0.25 + TAU * i / rays
			var a2 := a + TAU / rays * 0.45
			var pts := PackedVector2Array([center, center + Vector2(cos(a), sin(a)) * r * 1.6, center + Vector2(cos(a2), sin(a2)) * r * 1.6])
			draw_colored_polygon(pts, Color(1, 1, 1, 0.28))
		draw_circle(center, r * 1.18, Color(1, 1, 1, 0.22))
	var base := Transform2D(0.0, Vector2(s * (2.0 - squash), s), 0.0, center)
	# Schaduw
	_ellipse(base, Vector2(0, r * 0.9), Vector2(r * 0.95, r * 0.16), Color(0.45, 0.1, 0.25, 0.16))
	var cake := Palette.GOLD_DARK if golden else Palette.CAKE
	var cake_dark := Palette.GOLD_DARK.darkened(0.25) if golden else Palette.CAKE_DARK
	var glaze := Palette.GOLD if golden else Palette.PINK
	var glaze_dark := Palette.GOLD_DARK if golden else Palette.PINK_DARK
	# Perspectief: de koek is een platte, ronde cake (bovenaanzicht onder een hoek).
	var k := 0.84
	var side := r * 0.2
	# Zijkant van de cake
	_ellipse(base, Vector2(0, side * 0.5), Vector2(r, r * k), cake_dark)
	draw_set_transform_matrix(base)
	draw_rect(Rect2(-r, -side * 0.5, r * 2.0, side), cake_dark)
	_ellipse(base, Vector2(0, -side * 0.5), Vector2(r, r * k), cake)
	# Bovenkant: cake-rand met poriën
	draw_set_transform_matrix(base)
	for i in 22:
		var a := TAU * i / 22.0 + 0.2
		var p := Vector2(cos(a) * r * 0.94, sin(a) * r * k * 0.94 - side * 0.5)
		draw_circle(p, r * 0.016, cake_dark)
	# Roze fondant met druppels over de rand
	var gc := Vector2(0, -side * 0.62)
	var gr := r * 0.86
	for i in 11:
		var a := PI * 0.08 + PI * 0.84 * i / 10.0
		var p := gc + Vector2(cos(a) * gr, sin(a) * gr * k)
		var drip := r * (0.06 + 0.035 * absf(sin(i * 2.3)))
		draw_set_transform_matrix(base)
		draw_circle(p + Vector2(0, drip * 0.4), drip, glaze)
		draw_circle(p + Vector2(0, drip * 1.3), drip * 0.7, glaze)
	_ellipse(base, gc + Vector2(0, r * 0.02), Vector2(gr, gr * k), glaze_dark)
	_ellipse(base, gc, Vector2(gr, gr * k), glaze)
	# Zachte glans op het fondant
	draw_set_transform_matrix(base * Transform2D(-0.35, Vector2(1.0, 0.42), 0.0, Vector2(-r * 0.3, gc.y - r * 0.36)))
	draw_circle(Vector2.ZERO, r * 0.32, Color(1, 1, 1, 0.38))
	draw_set_transform_matrix(base)
	draw_circle(Vector2(r * 0.4, gc.y - r * 0.44), r * 0.055, Color(1, 1, 1, 0.55))
	draw_circle(Vector2(r * 0.53, gc.y - r * 0.3), r * 0.028, Color(1, 1, 1, 0.45))
	if sunglasses:
		_draw_sunglasses(r)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Kruimels
	for c in _crumbs:
		var col: Color = c[3]
		col.a = clampf(c[2] * 1.6, 0.0, 1.0)
		var sz: float = c[4]
		draw_rect(Rect2(c[0] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)

func _draw_sunglasses(r: float) -> void:
	var y := -r * 0.2
	var col := Color("#2B1B22")
	draw_circle(Vector2(-r * 0.3, y), r * 0.2, col)
	draw_circle(Vector2(r * 0.3, y), r * 0.2, col)
	draw_line(Vector2(-r * 0.12, y - r * 0.04), Vector2(r * 0.12, y - r * 0.04), col, r * 0.05)
	draw_circle(Vector2(-r * 0.36, y - r * 0.07), r * 0.05, Color(1, 1, 1, 0.5))
	draw_circle(Vector2(r * 0.24, y - r * 0.07), r * 0.05, Color(1, 1, 1, 0.5))
	draw_arc(Vector2(0, r * 0.08), r * 0.22, 0.3, PI - 0.3, 24, col, r * 0.04, true)

func _ellipse(base: Transform2D, pos: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform_matrix(base * Transform2D(0.0, Vector2(1.0, radii.y / radii.x), 0.0, pos))
	draw_circle(Vector2.ZERO, radii.x, color)
