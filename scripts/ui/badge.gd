extends Control
## Rond icoon met kleur en letter, gebruikt voor gebouwen en upgrades.

var color := Palette.PINK
var text := ""
var locked := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var col := Color(0.85, 0.8, 0.82) if locked else color
	draw_circle(c + Vector2(0, 3), r, col.darkened(0.25))
	draw_circle(c, r, col)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.35))
	var f := Palette.title_font()
	var fs := int(r * 0.95)
	var t := "?" if locked else text
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
