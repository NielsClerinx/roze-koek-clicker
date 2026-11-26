extends Node
## Scrollen door te vegen, overal in een lijst (ook bovenop knoppen en kaarten).
## Godot laat een ScrollContainer op touchscreens alleen via het balkje scrollen zodra
## de vinger op een knop begint. Deze node vangt de sleepbeweging zelf op:
## - beweegt de vinger meer dan DEADZONE pixels verticaal, dan scrollt de lijst mee;
## - bij het loslaten na een veeg krijgt de knop onder de vinger GEEN tik;
## - na het loslaten glijdt de lijst nog even uit.

const DEADZONE := 14.0
const FRICTION := 0.04        # resterende snelheid na 1 seconde
const MIN_SPEED := 30.0

var scrolls: Array[ScrollContainer] = []

var _sc: ScrollContainer
var _pressed := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _speed := 0.0
var _last_y := 0.0
var _last_t := 0.0
var _fling_sc: ScrollContainer
var _reinject := false

func register(sc: ScrollContainer) -> void:
	scrolls.append(sc)

func is_dragging() -> bool:
	return _dragging

func _input(e: InputEvent) -> void:
	if _reinject:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_sc = _scroll_at(e.position)
			_pressed = _sc != null
			_dragging = false
			_fling_sc = null
			_speed = 0.0
			_start = e.position
		else:
			if _dragging:
				# De knop kreeg de 'druk', maar loslaten buiten beeld voorkomt een tik.
				get_viewport().set_input_as_handled()
				var r: InputEventMouseButton = e.duplicate()
				r.position = Vector2(-10000, -10000)
				r.global_position = r.position
				_push(r)
				if absf(_speed) > MIN_SPEED:
					_fling_sc = _sc
			_pressed = false
			_dragging = false
	elif e is InputEventMouseMotion and _pressed and is_instance_valid(_sc):
		var now := Time.get_ticks_msec() / 1000.0
		if not _dragging and absf(e.position.y - _start.y) > DEADZONE:
			_dragging = true
			_start = e.position
			_start_scroll = _sc.scroll_vertical
			# Laat de ingedrukte knop denken dat de vinger weggleed: dan volgt er geen tik.
			var away: InputEventMouseMotion = e.duplicate()
			away.position = Vector2(-10000, -10000)
			away.global_position = away.position
			_push(away)
			_last_y = e.position.y
			_last_t = now
		if _dragging:
			_sc.scroll_vertical = int(_start_scroll - (e.position.y - _start.y))
			var dt := now - _last_t
			if dt > 0.0:
				_speed = lerpf(_speed, (e.position.y - _last_y) / dt, 0.5)
			_last_y = e.position.y
			_last_t = now
			get_viewport().set_input_as_handled()

func _push(ev: InputEvent) -> void:
	_reinject = true
	get_viewport().push_input(ev, true)
	_reinject = false

func _process(delta: float) -> void:
	if _fling_sc == null or not is_instance_valid(_fling_sc):
		return
	_fling_sc.scroll_vertical = int(_fling_sc.scroll_vertical - _speed * delta)
	_speed *= pow(FRICTION, delta)
	if absf(_speed) < MIN_SPEED:
		_fling_sc = null

func _scroll_at(pos: Vector2) -> ScrollContainer:
	for sc in scrolls:
		if is_instance_valid(sc) and sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			return sc
	return null
