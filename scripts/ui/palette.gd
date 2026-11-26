class_name Palette
extends RefCounted
## Huisstijl: kleuren, lettertypes en stijlblokken op één plek.

const BG_TOP := Color("#FFE9F1")
const BG_BOTTOM := Color("#FFC4D8")
const PINK := Color("#F26B9E")
const PINK_DARK := Color("#D94F85")
const PINK_DEEP := Color("#E8457C")
const PINK_LIGHT := Color("#FFD6E5")
const CAKE := Color("#E3A862")
const CAKE_DARK := Color("#C4874A")
const CHOCO := Color("#5A2E3A")
const CHOCO_SOFT := Color("#8C6470")
const WHITE := Color("#FFFFFF")
const GOLD := Color("#FFC93C")
const GOLD_DARK := Color("#E09B12")
const MINT := Color("#7ED9B5")

static var _title_font: FontVariation
static var _body_font: FontVariation
static var _body_bold: FontVariation

static func title_font() -> Font:
	if _title_font == null:
		_title_font = _variant("res://assets/fonts/Fredoka.ttf", 600)
	return _title_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = _variant("res://assets/fonts/Nunito.ttf", 600)
	return _body_font

static func body_bold() -> Font:
	if _body_bold == null:
		_body_bold = _variant("res://assets/fonts/Nunito.ttf", 800)
	return _body_bold

static func _variant(path: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	var base = load(path)
	if base is Font:
		fv.base_font = base
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv

static func box(color: Color, radius: int = 24, shadow: int = 0, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Color(0.55, 0.15, 0.3, 0.18)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", CHOCO)
	t.set_color("font_color", "Button", CHOCO)
	t.set_color("font_hover_color", "Button", CHOCO)
	t.set_color("font_pressed_color", "Button", CHOCO)
	t.set_color("font_focus_color", "Button", CHOCO)
	t.set_color("font_disabled_color", "Button", CHOCO_SOFT)
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("normal", "Button", box(PINK_LIGHT, 22))
	t.set_stylebox("hover", "Button", box(PINK_LIGHT.lightened(0.2), 22))
	t.set_stylebox("pressed", "Button", box(PINK_LIGHT.darkened(0.06), 22))
	t.set_stylebox("disabled", "Button", box(Color(0.95, 0.92, 0.93), 22))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(WHITE, 28, 10))
	# Dunne, ronde scrollbalk
	var grab := box(Color(PINK, 0.55), 6)
	grab.content_margin_left = 3; grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 3; sb.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	return t

static func label(text: String, size: int, color: Color = CHOCO, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
