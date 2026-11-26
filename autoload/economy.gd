extends Node
## Centraal economiemodel. ALLE formules van het spel staan hier.
## Andere systemen leveren "modifiers" aan; Economy combineert ze.
##
## Een modifier is een Dictionary: {"type": String, "value": float, "target": String (optioneel)}
## Types: building_mult, global_mult, click_mult, click_add, click_kps_pct, crit_chance_add,
##        crit_mult_set, offline_eff_add, offline_cap_add, golden_freq_mult,
##        golden_duration_mult, ability_cd_mult

const COST_GROWTH := 1.15
const MILESTONES: Array[int] = [25, 50, 100, 150, 200, 250, 300, 400, 500]
const CRYSTAL_BONUS := 0.02
const PRESTIGE_DIVISOR := 1e12
const BASE_CRIT_CHANCE := 0.03
const MAX_CRIT_CHANCE := 0.25
const BASE_CRIT_MULT := 10.0
const BASE_OFFLINE_EFF := 0.25
const MAX_OFFLINE_EFF := 1.0
const BASE_OFFLINE_CAP := 3.0 * 3600.0
const MAX_OFFLINE_CAP := 24.0 * 3600.0
const BASE_GOLDEN_LIFETIME := 12.0
const MIN_ABILITY_CD_MULT := 0.25

var _providers: Array = []          # [{node, temporary}]
var _dirty := true

# Gecachte waarden
var _building_mult: Dictionary = {}
var _global_mult := 1.0
var _click_mult := 1.0
var _click_add := 0.0
var _click_kps_pct := 0.0
var _crit_chance := BASE_CRIT_CHANCE
var _crit_mult := BASE_CRIT_MULT
var _offline_eff := BASE_OFFLINE_EFF
var _offline_cap := BASE_OFFLINE_CAP
var _golden_freq := 1.0
var _golden_duration := 1.0
var _ability_cd := 1.0
var _temp_prod_mult := 1.0
var _temp_click_mult := 1.0
var _kps_permanent := 0.0
var _building_kps: Dictionary = {}

func _ready() -> void:
	EventBus.modifiers_changed.connect(mark_dirty)
	EventBus.building_bought.connect(func(_id, _n): mark_dirty())
	EventBus.upgrade_bought.connect(func(_id): mark_dirty())
	EventBus.game_loaded.connect(mark_dirty)
	EventBus.game_reset.connect(mark_dirty)

## provider moet get_modifiers() -> Array implementeren.
func register_provider(node: Object, temporary: bool = false) -> void:
	_providers.append({"node": node, "temporary": temporary})
	mark_dirty()

func mark_dirty() -> void:
	_dirty = true

func _ensure() -> void:
	if _dirty:
		_recalculate()

func _recalculate() -> void:
	_dirty = false
	_building_mult = {}
	_global_mult = 1.0
	_click_mult = 1.0
	_click_add = 0.0
	_click_kps_pct = 0.0
	var crit_add := 0.0
	_crit_mult = BASE_CRIT_MULT
	var off_eff_add := 0.0
	var off_cap_add := 0.0
	_golden_freq = 1.0
	_golden_duration = 1.0
	_ability_cd = 1.0
	_temp_prod_mult = 1.0
	_temp_click_mult = 1.0
	for p in _providers:
		if not is_instance_valid(p.node):
			continue
		for m in p.node.get_modifiers():
			var v := float(m.get("value", 1.0))
			match m.get("type", ""):
				"building_mult":
					var t: String = m.get("target", "")
					_building_mult[t] = float(_building_mult.get(t, 1.0)) * v
				"global_mult":
					if p.temporary: _temp_prod_mult *= v
					else: _global_mult *= v
				"click_mult":
					if p.temporary: _temp_click_mult *= v
					else: _click_mult *= v
				"click_add": _click_add += v
				"click_kps_pct": _click_kps_pct += v
				"crit_chance_add": crit_add += v
				"crit_mult_set": _crit_mult = maxf(_crit_mult, v)
				"offline_eff_add": off_eff_add += v
				"offline_cap_add": off_cap_add += v
				"golden_freq_mult": _golden_freq *= v
				"golden_duration_mult": _golden_duration *= v
				"ability_cd_mult": _ability_cd *= v
				_:
					push_warning("Onbekend modifier-type: %s" % m.get("type", ""))
	_ability_cd = maxf(_ability_cd, MIN_ABILITY_CD_MULT)
	_crit_chance = minf(BASE_CRIT_CHANCE + crit_add, MAX_CRIT_CHANCE)
	_offline_eff = minf(BASE_OFFLINE_EFF + off_eff_add, MAX_OFFLINE_EFF)
	_offline_cap = minf(BASE_OFFLINE_CAP + off_cap_add, MAX_OFFLINE_CAP)
	# Productie per gebouw
	_building_kps = {}
	var total := 0.0
	for b in GameData.buildings:
		var n := GameState.count(b.id)
		var kps := float(b.base_kps) * n * float(_building_mult.get(b.id, 1.0)) * milestone_mult(n)
		_building_kps[b.id] = kps
		total += kps
	_kps_permanent = total * _global_mult * crystal_mult()

# ---------- Gebouwen ----------

func building_cost(id: String, amount: int = 1, owned: int = -1) -> float:
	var b = GameData.building_by_id.get(id)
	if b == null or amount <= 0:
		return INF
	if owned < 0:
		owned = GameState.count(id)
	var first := float(b.base_cost) * pow(COST_GROWTH, owned)
	return ceilf(first * (pow(COST_GROWTH, amount) - 1.0) / (COST_GROWTH - 1.0))

## Hoeveel stuks je maximaal kunt kopen met 'budget' koeken.
func max_affordable(id: String, budget: float = -1.0) -> int:
	var b = GameData.building_by_id.get(id)
	if b == null:
		return 0
	if budget < 0.0:
		budget = GameState.cookies
	var first := float(b.base_cost) * pow(COST_GROWTH, GameState.count(id))
	if budget < first:
		return 0
	var k := int(floor(log(budget * (COST_GROWTH - 1.0) / first + 1.0) / log(COST_GROWTH)))
	# Afrondingscorrectie
	while k > 0 and building_cost(id, k) > budget:
		k -= 1
	return k

static func milestone_mult(n: int) -> float:
	var m := 1.0
	for t in MILESTONES:
		if n >= t:
			m *= 2.0
	return m

func building_kps_total(id: String) -> float:
	_ensure()
	return float(_building_kps.get(id, 0.0)) * _global_mult * crystal_mult() * _temp_prod_mult

func building_kps_each(id: String) -> float:
	var n := GameState.count(id)
	if n > 0:
		return building_kps_total(id) / n
	_ensure()
	var b = GameData.building_by_id[id]
	return float(b.base_kps) * float(_building_mult.get(id, 1.0)) * _global_mult * crystal_mult() * _temp_prod_mult

# ---------- Productie ----------

func kps() -> float:
	_ensure()
	return _kps_permanent * _temp_prod_mult

## Zonder tijdelijke boosts (gebruikt voor offline-berekening en voorwaarden).
func kps_permanent() -> float:
	_ensure()
	return _kps_permanent

func crystal_mult() -> float:
	return 1.0 + CRYSTAL_BONUS * GameState.crystals

# ---------- Klikken ----------

func click_value() -> float:
	_ensure()
	return ((1.0 + _click_add) * _click_mult + _click_kps_pct * kps()) * _temp_click_mult

func crit_chance() -> float:
	_ensure()
	return _crit_chance

func crit_mult() -> float:
	_ensure()
	return _crit_mult

# ---------- Offline ----------

func offline_efficiency() -> float:
	_ensure()
	return _offline_eff

func offline_cap_seconds() -> float:
	_ensure()
	return _offline_cap

func offline_earnings(seconds: float) -> float:
	if seconds <= 0.0 or is_nan(seconds):
		return 0.0
	return kps_permanent() * minf(seconds, offline_cap_seconds()) * offline_efficiency()

# ---------- Gouden koek ----------

func golden_frequency_mult() -> float:
	_ensure()
	return _golden_freq

func golden_lifetime() -> float:
	_ensure()
	return BASE_GOLDEN_LIFETIME * _golden_duration

# ---------- Vrienden ----------

func ability_cooldown(base_seconds: float) -> float:
	_ensure()
	return base_seconds * _ability_cd

# ---------- Prestige ----------

func crystals_total_for(lifetime_baked: float) -> int:
	# Kleine marge: pow(64, 1/3) is in drijvende komma 3,9999...
	return int(floor(pow(maxf(lifetime_baked, 0.0) / PRESTIGE_DIVISOR, 1.0 / 3.0) + 1e-9))

func crystals_pending() -> int:
	return maxi(crystals_total_for(GameState.baked_lifetime) - GameState.crystals, 0)
