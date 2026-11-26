extends Control
## Geanimeerde cartoonvriend, volledig in code getekend (scherp op elk scherm, geen sprites nodig).
## Het uiterlijk komt uit de "look"-sectie van het personagebestand, zodat elke vriend
## dezelfde stijl deelt maar eigen kenmerken krijgt (haar, baard, hoed, kleren, huisdier ...).
##
## Animaties: "idle" (ademen, knipperen, haar wiegt), "ability" (vaardigheid), "happy" (blij).

const OUTLINE := Color("#3A1F2A")

var look: Dictionary = {
	"skin": "#F1C7A5", "hair": "#3B2418", "hair_length": "long", "beard": "full",
	"beard_grey": true, "brows": "skeptical", "eyes": "#6B4423",
	"shirt": "#5E6B3A", "undershirt": "#46512C", "pants": "#3A3530",
	"hat": "straw_fedora", "earring": true, "necklaces": ["cord_stone", "crucifix"],
	"companion": "pinscher",
}
var animation := "idle"
var _t := 0.0
var _anim_t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _u := 1.0   # schaal: 1 eenheid bij 460 hoog

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(anim: String) -> void:
	animation = anim
	_anim_t = 0.0

func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.2, 4.5)
	_blink = maxf(_blink - delta, 0.0)
	if animation != "idle" and _anim_t > 1.6:
		animation = "idle"
	queue_redraw()

func c(key: String, fallback: String = "#FF00FF") -> Color:
	return Color(str(look.get(key, fallback)))

# ------------------------------------------------------------------ tekenen

func _draw() -> void:
	_u = size.y / 460.0
	var has_dog: bool = look.get("companion", "") != ""
	var base_x := size.x * (0.36 if has_dog else 0.5)
	var feet := Vector2(base_x, size.y * 0.97)
	# Animatieparameters
	var bob := sin(_t * 2.4) * 3.0
	var jump := 0.0
	var hat_lift := 0.0
	var point := 0.0
	var smile := 0.0
	var surprise := 0.0
	var p := clampf(_anim_t / 1.6, 0.0, 1.0)
	match animation:
		"happy":
			jump = absf(sin(p * PI * 2.0)) * 38.0
			hat_lift = sin(p * PI) * 46.0
			smile = sin(p * PI)
		"ability":
			point = clampf(sin(p * PI) * 1.6, 0.0, 1.0)
			if look.get("ability_pose", "point") == "cheers":
				smile = point
			surprise = point
			jump = absf(sin(p * PI * 3.0)) * 8.0 * point
	var o := Vector2(0, -jump + bob * 0.3)
	# Schaduw
	_ellipse(feet + Vector2(0, -2) * _u, Vector2(95, 14) * _u * (1.0 - jump / 150.0), Color(0.45, 0.1, 0.25, 0.18))
	if has_dog:
		_draw_dog(feet + Vector2(178, 0) * _u, p)
	_draw_person(feet, o, bob, hat_lift, point, smile, surprise)

func _P(feet: Vector2, o: Vector2, x: float, y: float) -> Vector2:
	return feet + (o + Vector2(x, y)) * _u

func _draw_person(feet: Vector2, o: Vector2, bob: float, hat_lift: float, point: float, smile: float, surprise: float) -> void:
	var skin := c("skin")
	var hair := c("hair")
	var shirt := c("shirt")
	var breathe := sin(_t * 2.4) * 2.0
	var head_o := o + Vector2(0, bob * 0.5)
	var sway := sin(_t * 1.7) * 4.0
	# --- Haar achter (lang tot op de schouders)
	if look.get("hair_length", "") == "long":
		for side in [-1, 1]:
			var top := _P(feet, head_o, 72 * side, -262)
			var bottom := _P(feet, o, (86 + sway * 0.5) * side + sway, -168)
			_capsule(top, bottom, 30 * _u, hair, true)
		_ellipse_ol(_P(feet, head_o, 0, -258), Vector2(94, 100) * _u, hair)
	# --- Benen en schoenen
	for side in [-1, 1]:
		_capsule(_P(feet, o, 26 * side, -70), _P(feet, o, 26 * side, -20), 19 * _u, c("pants"), true)
		_ellipse_ol(_P(feet, o, 32 * side, -12), Vector2(26, 13) * _u, Color("#2B2220"))
	# --- Armen (achter de romp)
	var w := 1.18 if look.get("build", "") == "stocky" else 1.0
	var cheers: bool = look.get("ability_pose", "point") == "cheers"
	var hand_l := _P(feet, o, -82 * w, -82 + breathe)
	if cheers:
		hand_l = hand_l.lerp(_P(feet, o, -112 * w, -228), point)
	_arm(_P(feet, o, -58 * w, -150), hand_l, shirt, skin, false)
	# --- Romp
	var torso := PackedVector2Array([
		_P(feet, o, -62 * w, -160 - breathe), _P(feet, o, 62 * w, -160 - breathe),
		_P(feet, o, 54 * w, -58), _P(feet, o, -54 * w, -58)])
	_poly_ol(torso, shirt)
	if look.get("shirt_style", "open") == "tee":
		draw_arc(_P(feet, o, 0, -166 - breathe), 26 * _u, 0.15, PI - 0.15, 16, shirt.darkened(0.18), 5 * _u, true)
		for side in [-1, 1]:
			draw_line(_P(feet, o, 40 * w * side, -150), _P(feet, o, 36 * w * side, -120), shirt.darkened(0.06), 3 * _u, true)
	else:
		_draw_open_shirt(feet, o, breathe, shirt)
	# --- Kettingen
	var necklaces: Array = look.get("necklaces", [])
	if "crucifix" in necklaces:
		_chain(_P(feet, o, -22, -168), _P(feet, o, 22, -168), _P(feet, o, 6, -112), Color("#D8D8E2"))
		var cx := _P(feet, o, 6 + sin(_t * 2.4) * 1.5, -100)
		_capsule(cx + Vector2(0, -14) * _u, cx + Vector2(0, 16) * _u, 3.2 * _u, Color("#E6E6EE"), true)
		_capsule(cx + Vector2(-9, -5) * _u, cx + Vector2(9, -5) * _u, 3.2 * _u, Color("#E6E6EE"), true)
	if "cord_stone" in necklaces:
		_chain(_P(feet, o, -20, -172), _P(feet, o, 20, -172), _P(feet, o, -4, -142), Color("#1E1A1A"))
		var st := _P(feet, o, -4, -136)
		_poly_ol(PackedVector2Array([st + Vector2(-8, -6) * _u, st + Vector2(7, -8) * _u, st + Vector2(9, 6) * _u, st + Vector2(-2, 12) * _u]), Color("#2F4A44"))
	# --- Rechterarm (wijst bij vaardigheid)
	var hand_r := _P(feet, o, 82 * w, -82 + breathe)
	if not cheers:
		hand_r = hand_r.lerp(_P(feet, o, 128, -205), point)
	_arm(_P(feet, o, 58 * w, -150), hand_r, shirt, skin, true)
	if point > 0.5 and not cheers:
		_capsule(hand_r, hand_r + Vector2(14, -10) * _u, 5 * _u, skin, true)
	# --- Nek en hoofd
	_capsule(_P(feet, head_o, 0, -190), _P(feet, o, 0, -160), 20 * _u, skin.darkened(0.08), false)
	for side in [-1, 1]:
		_ellipse_ol(_P(feet, head_o, 80 * side, -248), Vector2(13, 18) * _u, skin)
	if look.get("earring", false):
		draw_circle(_P(feet, head_o, -84, -236), 4.0 * _u, Color("#F2D88A"))
		draw_circle(_P(feet, head_o, -85, -237), 1.5 * _u, Color.WHITE)
	var bald: bool = look.get("hair_style", "") == "bald"
	_ellipse_ol(_P(feet, head_o, 0, -255 - (6 if bald else 0)), Vector2(80, 90 + (6 if bald else 0)) * _u, skin)
	if bald:
		# Glimmende schedel
		draw_set_transform(_P(feet, head_o, -26, -318), -0.5, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 20 * _u, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(_P(feet, head_o, 4, -334), 5 * _u, Color(1, 1, 1, 0.6))
	if look.get("cheeks", false):
		for side in [-1, 1]:
			_ellipse(_P(feet, head_o, 48 * side, -226), Vector2(14, 9) * _u, Color("#F08C8C", 0.45))
	if look.get("beard", "") == "goatee":
		var hair_c := c("hair")
		# Stoppels langs de kaak
		var stub := PackedVector2Array()
		for i in 15:
			var a := PI * 0.08 + PI * 0.84 * i / 14.0
			stub.append(_P(feet, head_o, cos(a) * 78, -252 + sin(a) * 86))
		for i in 15:
			var a := PI * 0.92 - PI * 0.84 * i / 14.0
			stub.append(_P(feet, head_o, cos(a) * 66, -238 + sin(a) * 60))
		_poly(stub, Color(hair_c, 0.16))
		# Sikje
		var gt := PackedVector2Array([_P(feet, head_o, -24, -200), _P(feet, head_o, 24, -200), _P(feet, head_o, 20, -176),
			_P(feet, head_o, 8, -160), _P(feet, head_o, -8, -160), _P(feet, head_o, -20, -176)])
		_poly_ol(gt, hair_c)
		# Mond: zelfvoldane grijns
		var m := _P(feet, head_o, 0, -205)
		if smile > 0.05:
			draw_arc(m, (14 + 6 * smile) * _u, 0.2, PI - 0.2, 16, Color("#7A2E3A"), 6 * _u, true)
		else:
			draw_line(m + Vector2(-14, 1) * _u, m + Vector2(14, -4) * _u, Color("#B5555F"), 5 * _u, true)
		# Snor
		for side in [-1, 1]:
			_capsule(_P(feet, head_o, 4 * side, -217), _P(feet, head_o, 30 * side, -208 + smile * -4), 7 * _u, hair_c, false)
	# --- Baard (vol, licht overdreven, met grijze strepen)
	if look.get("beard", "") == "full":
		var bw := 1.0 + sin(_t * 2.4 + 0.6) * 0.015
		var pts := PackedVector2Array()
		var cps := [Vector2(-79, -262), Vector2(-82, -225), Vector2(-70, -185), Vector2(-46, -158), Vector2(-16, -142),
			Vector2(0, -138), Vector2(16, -142), Vector2(46, -158), Vector2(70, -185), Vector2(82, -225), Vector2(79, -262),
			Vector2(60, -240), Vector2(38, -222), Vector2(0, -218), Vector2(-38, -222), Vector2(-60, -240)]
		for q in cps:
			pts.append(_P(feet, head_o, q.x * bw, q.y + (q.y + 200) * (bw - 1.0)))
		_poly_ol(pts, hair)
		if look.get("beard_grey", false):
			for i in 6:
				var x := -48 + i * 19
				draw_line(_P(feet, head_o, x, -205), _P(feet, head_o, x * 0.8, -170), Color("#9A9590", 0.85), 2.2 * _u, true)
		# Mond
		var mouth := _P(feet, head_o, 0, -205)
		if smile > 0.05:
			draw_arc(mouth, (12 + 8 * smile) * _u, 0.25, PI - 0.25, 16, Color("#7A2E3A"), 6 * _u, true)
			draw_arc(mouth + Vector2(0, -2) * _u, (12 + 8 * smile) * _u, 0.5, PI - 0.5, 12, Color.WHITE, 3 * _u, true)
		elif surprise > 0.3:
			_ellipse(mouth + Vector2(0, 2) * _u, Vector2(8, 10 * surprise) * _u, Color("#7A2E3A"))
		else:
			_ellipse(mouth, Vector2(13, 5) * _u, Color("#C96F7A"))
		# Snor
		for side in [-1, 1]:
			_capsule(_P(feet, head_o, 6 * side, -218), _P(feet, head_o, 36 * side, -208 + smile * -6), 9 * _u, hair, false)
	# --- Haar voor (achterover gekamd, licht wijkende haarlijn)
	if not bald:
		_draw_hair_front(feet, head_o, hair, sway)
	# --- Neus
	_ellipse_ol(_P(feet, head_o, 2, -234), Vector2(13, 16) * _u, skin.darkened(0.06))
	draw_circle(_P(feet, head_o, -2, -240), 3.5 * _u, Color(1, 1, 1, 0.35))
	draw_arc(_P(feet, head_o, 2, -228), 8 * _u, 0.3, PI - 0.3, 10, skin.darkened(0.3), 2.5 * _u, true)
	# --- Ogen
	for side in [-1, 1]:
		var e := _P(feet, head_o, 31 * side, -262)
		if _blink > 0.0:
			draw_line(e + Vector2(-13, 0) * _u, e + Vector2(13, 0) * _u, OUTLINE, 4 * _u, true)
		else:
			var open := 1.0 + surprise * 0.35
			_ellipse_ol(e, Vector2(15, 12 * open) * _u, Color.WHITE)
			var look_dir := Vector2(sin(_t * 0.7) * 2.5 + point * 4.0, -point * 3.0)
			draw_circle(e + look_dir * _u, 8.5 * _u, c("eyes"))
			draw_circle(e + look_dir * _u, 4.5 * _u, Color("#1C1012"))
			draw_circle(e + (look_dir + Vector2(-3, -3)) * _u, 2.4 * _u, Color.WHITE)
			if look.get("eye_shape", "") == "squint" and surprise < 0.3:
				# Halfgesloten oogleden: relaxte, zelfverzekerde blik
				var lid := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					lid.append(e + Vector2(cos(a) * 17, sin(a) * 15) * _u)
				lid.append(e + Vector2(17, 2) * _u)
				lid.append(e + Vector2(-17, 2) * _u)
				draw_colored_polygon(lid, skin)
				draw_line(e + Vector2(-17, 1) * _u, e + Vector2(17, -1) * _u, OUTLINE, 3.5 * _u, true)
			else:
				# Zware oogleden: de intense blik
				draw_arc(e, 15 * _u, PI * 1.08, PI * 1.92, 12, OUTLINE, 3.5 * _u, true)
	# --- Wenkbrauwen: dik, één opgetrokken (sceptische blik)
	var lift := surprise * 10.0 + smile * 6.0
	var skeptical: bool = look.get("brows", "") == "skeptical"
	var brow_col := c("brow_color", str(look.get("hair", "#3B2418")))
	var hair_saved := hair
	hair = brow_col
	_capsule(_P(feet, head_o, -50, -284 - lift), _P(feet, head_o, -14, -276 - lift + (5 if skeptical else 0)), 7.5 * _u, hair, false)
	_capsule(_P(feet, head_o, 14, -282 - lift - (7 if skeptical else 0)), _P(feet, head_o, 50, -288 - lift - (3 if skeptical else 0)), 7.5 * _u, hair, false)
	hair = hair_saved
	# --- Hoofddeksel
	if look.get("hat", "") == "straw_fedora":
		_draw_hat(_P(feet, head_o, 0, -330 - hat_lift), hat_lift)
	elif look.get("hat", "") == "flat_cap":
		_draw_flat_cap(_P(feet, head_o, 0, -318 - hat_lift), hat_lift)
	# --- Voorwerp in de linkerhand
	_draw_prop(hand_l, point if cheers else 0.0)

func _draw_hair_front(feet: Vector2, head_o: Vector2, hair: Color, sway: float) -> void:
	var cap := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		cap.append(_P(feet, head_o, cos(a) * 85, -258 + sin(a) * 96))
	cap.append(_P(feet, head_o, 76, -270))
	cap.append(_P(feet, head_o, 56, -312))
	cap.append(_P(feet, head_o, 18, -326))
	cap.append(_P(feet, head_o, -18, -326))
	cap.append(_P(feet, head_o, -56, -312))
	cap.append(_P(feet, head_o, -76, -270))
	_poly_ol(cap, hair)
	for i in 4:
		var x := -40 + i * 26
		draw_arc(_P(feet, head_o, x, -300), 28 * _u, PI * 1.2, PI * 1.75, 10, hair.lightened(0.18), 3 * _u, true)
	# Losse lok die meewiegt
	draw_line(_P(feet, head_o, 30, -318), _P(feet, head_o, 52 + sway, -282), hair, 6 * _u, true)

func _draw_open_shirt(feet: Vector2, o: Vector2, breathe: float, shirt: Color) -> void:
	_poly(PackedVector2Array([_P(feet, o, -26, -160 - breathe), _P(feet, o, 26, -160 - breathe), _P(feet, o, 10, -95), _P(feet, o, -10, -95)]), c("undershirt"))
	# Kraag
	_poly_ol(PackedVector2Array([_P(feet, o, -30, -163 - breathe), _P(feet, o, -6, -150), _P(feet, o, -22, -128)]), shirt.lightened(0.12))
	_poly_ol(PackedVector2Array([_P(feet, o, 30, -163 - breathe), _P(feet, o, 6, -150), _P(feet, o, 22, -128)]), shirt.lightened(0.12))
	# Knopen
	for i in 3:
		draw_circle(_P(feet, o, -30, -140 + i * 26), 3.2 * _u, shirt.darkened(0.35))

func _arm(shoulder: Vector2, hand: Vector2, shirt: Color, skin: Color, right: bool) -> void:
	if look.get("sleeves", "long") == "short":
		var elbow := shoulder.lerp(hand, 0.45)
		_capsule(elbow, hand, 15 * _u, skin, true)
		if right and look.get("tattoo", false):
			var d := (hand - elbow)
			var mid := elbow + d * 0.55
			var ang := d.angle()
			draw_set_transform(mid, ang, Vector2.ONE)
			_ellipse(Vector2.ZERO, Vector2(d.length() * 0.38, 11 * _u), Color("#4F5B5E"))
			# haaienvin en tandjes
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -9) * _u, Vector2(4, -9) * _u, Vector2(-2, -18) * _u]), Color("#4F5B5E"))
			for i in 4:
				draw_circle(Vector2(-10 + i * 6, 3) * _u, 1.6 * _u, Color("#DDE3E3"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var hair_col := c("hair").lightened(0.1)
		for i in 3:
			var q := elbow.lerp(hand, 0.25 + i * 0.22)
			draw_line(q + Vector2(-5, 9) * _u, q + Vector2(-1, 12) * _u, hair_col, 1.6 * _u, true)
		_capsule(shoulder, elbow, 18 * _u, shirt, true)
	else:
		_capsule(shoulder, hand, 17 * _u, shirt, true)
	_circle_ol(hand, 14 * _u, skin)

func _draw_prop(hand: Vector2, raised: float) -> void:
	if look.get("prop", "") != "beer":
		return
	var u := _u
	var g := hand + Vector2(0, -30) * u
	var glass := PackedVector2Array([g + Vector2(-15, -32) * u, g + Vector2(15, -32) * u, g + Vector2(11, 26) * u, g + Vector2(-11, 26) * u])
	_poly_ol(glass, Color("#E8A33A"))
	draw_line(g + Vector2(-7, -24) * u, g + Vector2(-5, 18) * u, Color(1, 1, 1, 0.45), 3 * u, true)
	var foam := g + Vector2(0, -34) * u
	for i in 4:
		draw_circle(foam + Vector2(-12 + i * 8, -2 - (i % 2) * 4 - raised * 4) * u, 8 * u, Color("#FFF8E8"))
	draw_circle(hand, 14 * u, c("skin"))
	if raised > 0.6:
		var f := Palette.title_font()
		var tp := foam + Vector2(-70, -40) * u
		draw_string_outline(f, tp, "PROOST!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * u), int(8 * u), OUTLINE)
		draw_string(f, tp, "PROOST!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * u), Palette.GOLD)

func _draw_flat_cap(center: Vector2, lift: float) -> void:
	var u := _u
	var col := Color("#3A3634")
	draw_set_transform(center, -0.05 - lift * 0.004, Vector2.ONE)
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(Vector2(cos(a) * 86, sin(a) * 40 + 4) * u)
	cap.append(Vector2(84, 14) * u)
	cap.append(Vector2(-84, 14) * u)
	_poly_ol(cap, col)
	# Klep
	_poly_ol(PackedVector2Array([Vector2(-60, 10) * u, Vector2(70, 6) * u, Vector2(98, 22) * u, Vector2(-40, 26) * u]), col.darkened(0.15))
	for i in 5:
		draw_line(Vector2(-60 + i * 28, -30) * u, Vector2(-50 + i * 28, 8) * u, col.lightened(0.12), 2 * u, true)
	draw_circle(Vector2(0, -36) * u, 5 * u, col.lightened(0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hat(center: Vector2, lift: float) -> void:
	var straw := Color("#D9C38E")
	var tilt := -0.08 - lift * 0.004
	draw_set_transform(center, tilt, Vector2.ONE)
	var u := _u
	# Rand
	_ellipse_ol(Vector2(0, 10) * u, Vector2(128, 26) * u, straw)
	# Bol
	var crown := PackedVector2Array([Vector2(-80, 8) * u, Vector2(-66, -62) * u, Vector2(-20, -74) * u,
		Vector2(0, -62) * u, Vector2(20, -74) * u, Vector2(66, -62) * u, Vector2(80, 8) * u])
	_poly_ol(crown, straw)
	# Band
	_poly(PackedVector2Array([Vector2(-80, 6) * u, Vector2(-76, -14) * u, Vector2(76, -14) * u, Vector2(80, 6) * u]), Color("#6B4E32"))
	# Vlechtpatroon
	for row in 4:
		for col in 9:
			var px := -56 + col * 14 + (row % 2) * 7
			draw_line(Vector2(px, -60 + row * 12) * u, Vector2(px + 6, -54 + row * 12) * u, straw.darkened(0.2), 2 * u, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_dog(pos: Vector2, p: float) -> void:
	var u := _u
	var black := Color("#24191A")
	var tan := Color("#B9773A")
	var sweater := Color("#3B3638")
	var hop := 0.0
	var bark := false
	if animation == "ability":
		hop = absf(sin(p * PI * 4.0)) * 26.0
		bark = fmod(p * 4.0, 1.0) < 0.5
	elif animation == "happy":
		hop = absf(sin(p * PI * 2.0)) * 16.0
	var o := pos + Vector2(0, -hop) * u
	# Staart (kwispelt)
	var wag := sin(_t * (14.0 if animation != "idle" else 7.0)) * 0.6
	var tail_base := o + Vector2(40, -40) * u
	draw_line(tail_base, tail_base + Vector2(cos(-0.9 + wag), sin(-0.9 + wag)) * 36 * u, OUTLINE, 11 * u, true)
	draw_line(tail_base, tail_base + Vector2(cos(-0.9 + wag), sin(-0.9 + wag)) * 34 * u, black, 7 * u, true)
	# Pootjes
	for x in [-26, -8, 14, 30]:
		_capsule(o + Vector2(x, -30) * u, o + Vector2(x, -6) * u, 7 * u, tan, true)
	# Lijf in gebreide trui
	_ellipse_ol(o + Vector2(2, -42) * u, Vector2(46, 28) * u, sweater)
	for i in 7:
		var x := -34 + i * 11
		draw_line(o + Vector2(x, -62) * u, o + Vector2(x, -22) * u, sweater.lightened(0.12), 2.5 * u, true)
	# Kop (kijkt omhoog naar het baasje)
	var h := o + Vector2(-34, -88) * u
	var tilt := sin(_t * 1.3) * 0.08 + (0.15 if bark else 0.0)
	draw_set_transform(h, tilt, Vector2.ONE)
	# Oren
	_poly_ol(PackedVector2Array([Vector2(-22, -14) * u, Vector2(-40, -40) * u, Vector2(-8, -26) * u]), black)
	_poly_ol(PackedVector2Array([Vector2(14, -22) * u, Vector2(38, -44) * u, Vector2(26, -10) * u]), black)
	_ellipse_ol(Vector2.ZERO, Vector2(30, 27) * u, black)
	# Snuit (tan) + neus
	_ellipse_ol(Vector2(-22, 8) * u, Vector2(20, 14) * u, tan)
	_ellipse_ol(Vector2(-36, 2) * u, Vector2(8, 6) * u, black)
	draw_circle(Vector2(-38, 0) * u, 2.2 * u, Color(1, 1, 1, 0.6))
	# Wenkbrauwvlekjes en ogen
	draw_circle(Vector2(-12, -14) * u, 4.5 * u, tan)
	draw_circle(Vector2(8, -12) * u, 4.5 * u, tan)
	if _blink > 0.0:
		draw_line(Vector2(-16, -5) * u, Vector2(-6, -5) * u, Color.WHITE, 2 * u)
	else:
		draw_circle(Vector2(-11, -5) * u, 5.5 * u, Color("#120A0A"))
		draw_circle(Vector2(-13, -7) * u, 2 * u, Color.WHITE)
		draw_circle(Vector2(9, -4) * u, 5 * u, Color("#120A0A"))
		draw_circle(Vector2(7, -6) * u, 1.8 * u, Color.WHITE)
	# Hijgende tong
	var pant := 0.5 + 0.5 * sin(_t * 9.0)
	if bark:
		_ellipse(Vector2(-24, 20) * u, Vector2(10, 9) * u, Color("#5A1E26"))
	_ellipse_ol(Vector2(-18, 22 + pant * 4) * u, Vector2(7, 9 + pant * 3) * u, Color("#F27A96"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if bark:
		var f := Palette.title_font()
		var tp := h + Vector2(-110, -40) * u
		draw_string_outline(f, tp, "WAF!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * u), int(8 * u), OUTLINE)
		draw_string(f, tp, "WAF!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 * u), Palette.GOLD)

# ------------------------------------------------------------------ tekenhulpjes

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)

func _ellipse_ol(center: Vector2, radii: Vector2, color: Color) -> void:
	var w := 3.5 * _u
	_ellipse(center, radii + Vector2(w, w), OUTLINE)
	_ellipse(center, radii, color)

func _circle_ol(center: Vector2, r: float, color: Color) -> void:
	draw_circle(center, r + 3.5 * _u, OUTLINE)
	draw_circle(center, r, color)

func _capsule(a: Vector2, b: Vector2, r: float, color: Color, outline: bool) -> void:
	if outline:
		var w := 3.5 * _u
		draw_line(a, b, OUTLINE, (r + w) * 2.0)
		draw_circle(a, r + w, OUTLINE)
		draw_circle(b, r + w, OUTLINE)
	draw_line(a, b, color, r * 2.0)
	draw_circle(a, r, color)
	draw_circle(b, r, color)

func _poly(pts: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, color)

func _poly_ol(pts: PackedVector2Array, color: Color) -> void:
	_poly(pts, color)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUTLINE, 3.5 * _u, true)

func _chain(a: Vector2, b: Vector2, low: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(low, t).lerp(low.lerp(b, t), t))
	draw_polyline(pts, color, 2.4 * _u, true)
