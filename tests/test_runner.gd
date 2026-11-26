extends Node
## Headless tests voor economie, opslag en offline-berekening.
## Draaien: godot --headless --path . res://tests/test_runner.tscn

var _fails := 0
var _passes := 0

func _ready() -> void:
	SaveManager.slot = "test_save"
	GameState.reset_all()
	EventBus.game_reset.emit()
	_test_number_format()
	_test_costs()
	_test_purchase_and_kps()
	_test_upgrades()
	_test_clicks()
	_test_offline()
	_test_save_roundtrip()
	_test_corrupt_save()
	_test_prestige()
	_test_data_integrity()
	_test_characters()
	print("\n%d geslaagd, %d mislukt" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

func check(cond: bool, name: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("MISLUKT: " + name)

func approx(a: float, b: float, rel: float = 1e-6) -> bool:
	return absf(a - b) <= maxf(absf(b) * rel, 1e-9)

func _test_number_format() -> void:
	check(NumberFormat.format(0) == "0", "format 0")
	check(NumberFormat.format(999) == "999", "format 999")
	check(NumberFormat.format(1234) == "1.234", "format 1234 -> " + NumberFormat.format(1234))
	check(NumberFormat.format(1.5e6) == "1,50 M", "format 1,5M -> " + NumberFormat.format(1.5e6))
	check(NumberFormat.format(2.5e12) == "2,50 T", "format T")
	check(NumberFormat.format(999.999e6) == "1,00 B", "afronding naar B -> " + NumberFormat.format(999.999e6))
	check(NumberFormat.format(0.1, true) == "0,1", "decimaal klein")
	check(NumberFormat.format(1e70).contains("e70"), "wetenschappelijk -> " + NumberFormat.format(1e70))

func _test_costs() -> void:
	check(Economy.building_cost("kleine_bakker", 1, 0) == 15.0, "basisprijs")
	check(Economy.building_cost("kleine_bakker", 1, 1) == ceilf(15 * 1.15), "prijs na 1")
	var sum := 0.0
	for i in 10:
		sum += 15.0 * pow(1.15, i)
	check(approx(Economy.building_cost("kleine_bakker", 10, 0), ceilf(sum)), "bulkprijs x10")
	GameState.cookies = 1000.0
	var k := Economy.max_affordable("kleine_bakker")
	check(Economy.building_cost("kleine_bakker", k) <= 1000.0 and Economy.building_cost("kleine_bakker", k + 1) > 1000.0, "max affordable")

func _test_purchase_and_kps() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	GameState.cookies = 15.0
	check(ProductionSystem.buy("kleine_bakker", 1) == 1, "koop 1 bakker")
	check(GameState.cookies == 0.0, "koeken afgetrokken")
	check(ProductionSystem.buy("kleine_bakker", 1) == 0, "niet genoeg koeken")
	check(approx(Economy.kps(), 0.1), "kps 0,1")
	GameState.buildings["kleine_bakker"] = 25
	Economy.mark_dirty()
	check(approx(Economy.kps(), 25 * 0.1 * 2.0), "mijlpaal 25 = x2")

func _test_upgrades() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	GameState.buildings["kleine_bakker"] = 1
	GameState.cookies = 1e6
	check(UpgradeSystem.buy("kleine_bakker_t1"), "koop tier 1")
	check(approx(Economy.kps(), 0.2), "tier 1 verdubbelt")
	check(not UpgradeSystem.buy("kleine_bakker_t1"), "geen dubbele aankoop")
	check(not UpgradeSystem.buy("kleine_bakker_t2"), "tier 2 vergrendeld")
	check(not UpgradeSystem.buy("secret_ikbendekoek"), "geheim niet koopbaar")
	check(UpgradeSystem.buy("click_1"), "klik-upgrade")
	check(approx(Economy.click_value(), 2.0), "klik x2")

func _test_clicks() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	var total := 0.0
	var crits := 0
	for i in 5000:
		var r := ClickSystem.click()
		total += r.amount
		if r.crit: crits += 1
	check(GameState.clicks == 5000, "klikteller")
	check(crits > 80 and crits < 250, "kritieke kans ~3%% (%d)" % crits)
	check(approx(GameState.cookies, total), "kliks opgeteld")

func _test_offline() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	GameState.buildings["bakkerij"] = 10   # 10 kps
	Economy.mark_dirty()
	check(approx(Economy.offline_earnings(100), 10 * 100 * 0.25), "offline 25%")
	check(approx(Economy.offline_earnings(1e7), 10 * 3 * 3600 * 0.25), "offline limiet 3 uur")
	check(Economy.offline_earnings(-50) == 0.0, "teruggezette klok")
	var before := GameState.cookies
	OfflineSystem.apply_since(Time.get_unix_time_from_system() - 3600)
	check(approx(GameState.cookies - before, 10 * 3600 * 0.25, 1e-3), "offline toegepast")
	before = GameState.cookies
	OfflineSystem.apply_since(Time.get_unix_time_from_system() + 5000)
	check(GameState.cookies == before, "toekomstige tijd geeft niets")

func _test_save_roundtrip() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	GameState.cookies = 12345.5
	GameState.buildings["oven"] = 7
	GameState.upgrades["click_1"] = true
	GameState.bakery_name = "Testbakkerij"
	check(SaveManager.save_game(), "opslaan")
	GameState.reset_all()
	SaveManager.load_game()
	check(approx(GameState.cookies, 12345.5), "koeken geladen")
	check(GameState.count("oven") == 7, "gebouwen geladen")
	check(GameState.has_upgrade("click_1"), "upgrades geladen")
	check(GameState.bakery_name == "Testbakkerij", "naam geladen")

func _test_corrupt_save() -> void:
	SaveManager.save_game()   # zorgt voor een geldige .bak
	SaveManager.save_game()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{kapot")
	f.close()
	GameState.reset_all()
	SaveManager.load_game()
	check(GameState.count("oven") == 7, "back-up geladen bij kapotte save")
	var bad := {"version": 1, "cookies": "NaN", "buildings": {"oven": -5, "bestaat_niet": 3}, "upgrades": ["onbekend"]}
	GameState.from_dict(bad)
	check(GameState.cookies == 0.0 and GameState.count("oven") == 0 and GameState.upgrades.is_empty(), "ongeldige waarden genegeerd")
	SaveManager.wipe()

func _test_prestige() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	check(Economy.crystals_total_for(1e12) == 1, "1T = 1 kristal")
	check(Economy.crystals_total_for(8e12) == 2, "8T = 2 kristallen")
	GameState.add_cookies(27e12)
	GameState.buildings["oven"] = 5
	check(PrestigeSystem.prestige() == 3, "herglazuren geeft 3")
	check(GameState.cookies == 0.0 and GameState.count("oven") == 0, "run gereset")
	check(GameState.crystals == 3 and approx(Economy.crystal_mult(), 1.06), "kristalbonus")
	check(Economy.crystals_pending() == 0, "geen dubbele kristallen")
	SaveManager.wipe()

func _test_data_integrity() -> void:
	check(GameData.buildings.size() == 15, "15 gebouwen")
	check(GameData.upgrades.size() >= 30, "minstens 30 upgrades (%d)" % GameData.upgrades.size())
	var prev := 0.0
	var ok := true
	for b in GameData.buildings:
		if float(b.base_cost) <= prev: ok = false
		prev = float(b.base_cost)
	check(ok, "gebouwen oplopend in prijs")
	for u in GameData.upgrades:
		if u.condition.get("type") == "building_count":
			check(GameData.building_by_id.has(u.condition.building), "upgrade verwijst naar bestaand gebouw: " + u.id)

func _test_characters() -> void:
	GameState.reset_all(); EventBus.game_reset.emit()
	check(GameData.characters.size() >= 4, "minstens 4 vrienden (%d)" % GameData.characters.size())
	for c in GameData.characters:
		check(c.has("look") and c.has("ability") and c.has("passive_bonus"), "vriend compleet: " + c.id)
	# Timothy: vergrendeld tot 1 bakkerij
	GameState.cookies = 1e6
	check(not CharacterSystem.recruit("timothy"), "vergrendelde vriend niet te rekruteren")
	GameState.buildings["bakkerij"] = 1
	Economy.mark_dirty()
	var before := Economy.kps()
	check(CharacterSystem.recruit("timothy"), "timothy rekruteren")
	check(approx(Economy.kps(), before * 1.5), "bakkerij-bonus x1,5")
	check(approx(Economy.crit_chance(), 0.05), "kritieke kans +2%%")
	check(not CharacterSystem.recruit("timothy"), "niet dubbel rekruteren")
	# Vaardigheid: productie x3, daarna afkoeltijd
	var k := Economy.kps()
	check(CharacterSystem.use_ability("timothy"), "vaardigheid gebruiken")
	check(approx(Economy.kps(), k * 3.0), "proost x3")
	check(approx(Economy.kps_permanent(), k), "boost telt niet mee offline")
	check(not CharacterSystem.use_ability("timothy"), "afkoeltijd actief")
	check(CharacterSystem.cooldown_left("timothy") > 590.0, "afkoeltijd ~600 s")
	# Opslaan en laden bewaart vrienden en afkoeltijd
	SaveManager.save_game()
	GameState.reset_all()
	SaveManager.load_game()
	check(CharacterSystem.is_recruited("timothy"), "vriend geladen")
	check(CharacterSystem.cooldown_left("timothy") > 590.0, "afkoeltijd geladen")
	# Vrienden blijven na herglazuren
	GameState.add_cookies(1e12)
	PrestigeSystem.prestige()
	check(CharacterSystem.is_recruited("timothy"), "vriend blijft na herglazuren")
	RandomEventSystem.reset()
	SaveManager.wipe()
