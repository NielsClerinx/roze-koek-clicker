extends Node
## De Roze Hemel in de Meer-tab: permanente upgrades voor Fondantkristallen.

const ShopRow := preload("res://scripts/ui/shop_row.gd")

var main: Control
var _header: Label
var _rows: Dictionary = {}

func setup(main_node: Control) -> void:
	main = main_node

## Voegt de sectie toe aan een bestaande lijst (de Meer-pagina).
func build_section(list: VBoxContainer) -> void:
	list.add_child(Palette.label("Roze Hemel", 26, Palette.CHOCO, Palette.title_font()))
	_header = Palette.label("", 18, Palette.CHOCO_SOFT)
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_header)
	for h in GameData.heaven:
		var row := ShopRow.new()
		row.title.text = h.name
		row.badge.color = Color("#B39DDB")
		row.badge.text = "★"
		row.price.text = str(int(h.cost))
		row.tag.text = "kristal" if int(h.cost) == 1 else "kristallen"
		var id: String = h.id
		row.pressed.connect(func(): _buy(id))
		list.add_child(row)
		_rows[id] = row

func refresh() -> void:
	_header.text = "Je hebt %d Fondantkristallen om uit te geven. Wat je hier koopt, blijft voor altijd, ook na herglazuren. Uitgegeven kristallen blijven hun +2%% productie geven." % GameState.crystals_available()
	for h in GameData.heaven:
		var row: ShopRow = _rows[h.id]
		if HeavenSystem.owned(h.id):
			row.subtitle.text = h.description
			row.price.text = "✓"
			row.tag.text = "gekocht"
			row.badge.locked = false
			row.set_affordable(true)
		elif not HeavenSystem.requirements_met(h.id):
			row.subtitle.text = HeavenSystem.requirement_text(h.id)
			row.badge.locked = true
			row.set_affordable(false)
		else:
			row.subtitle.text = h.description
			row.badge.locked = false
			row.set_affordable(HeavenSystem.can_buy(h.id))
		row.badge.queue_redraw()

func _buy(id: String) -> void:
	var h: Dictionary = GameData.heaven_by_id[id]
	if HeavenSystem.buy(id):
		main.show_toast("Roze Hemel: %s!" % h.name)
	elif not HeavenSystem.owned(id):
		main.show_toast(HeavenSystem.requirement_text(id) if not HeavenSystem.requirements_met(id) else "Nog niet genoeg Fondantkristallen.")
	refresh()
