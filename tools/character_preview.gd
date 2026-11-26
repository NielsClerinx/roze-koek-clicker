extends Control
## Rendert een personage als reeks PNG-frames (voor een GIF-preview).
## godot --path . --rendering-driver opengl3 res://tools/character_preview.tscn -- <id> <uitvoermap>

const FriendFigure := preload("res://scripts/ui/characters/friend_figure.gd")
const FPS := 20.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else ""
	var out: String = args[1] if args.size() > 1 else "user://"
	var data = GameData.character_by_id.get(id)
	if data == null:
		push_error("Onbekend personage: " + id)
		get_tree().quit(1)
		return
	theme = Palette.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.BG_TOP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Palette.box(Palette.PINK_LIGHT, 40))
	card.position = Vector2(30, 30)
	card.size = get_viewport_rect().size - Vector2(60, 60)
	add_child(card)
	var title := Palette.label(data.nickname, 44, Palette.PINK_DEEP, Palette.title_font())
	title.position = Vector2(60, 50)
	add_child(title)
	var role := Palette.label(data.role, 22, Palette.CHOCO_SOFT, Palette.body_bold())
	role.position = Vector2(62, 108)
	add_child(role)
	var fig := FriendFigure.new()
	fig.look = data.look
	fig.position = Vector2(40, 150)
	fig.size = get_viewport_rect().size - Vector2(80, 180)
	fig.set_process(false)
	add_child(fig)
	var caption := Palette.label("", 24, Palette.CHOCO, Palette.title_font())
	caption.position = Vector2(62, get_viewport_rect().size.y - 80)
	add_child(caption)
	var plan := [["idle", 2.0, "Rustig"], ["ability", 1.6, data.ability.name], ["idle", 0.8, "Rustig"], ["happy", 1.6, "Blij"], ["idle", 0.8, "Rustig"]]
	var frame := 0
	for step in plan:
		fig.play(step[0])
		caption.text = step[2]
		for i in int(step[1] * FPS):
			fig._process(1.0 / FPS)
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/frame_%03d.png" % [out, frame])
			frame += 1
	print("frames: ", frame)
	get_tree().quit()
