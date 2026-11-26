extends Node
## Dagelijkse uitdagingen: elke dag drie opdrachten, gekozen op basis van de datum
## (dus voor iedereen dezelfde soort opdracht). De doelen schalen met de voortgang.
## Beloning: Roze Lintjes. Alle drie voltooien op 7 dagen na elkaar geeft een bonus.
##
## GameState.daily = {day, tasks: [{id, goal, progress, claimed}], streak, last_full_day}

const TASKS_PER_DAY := 3

var _last_baked := -1.0
var _t := 0.0

func _ready() -> void:
	EventBus.cookies_clicked.connect(_on_click)
	EventBus.golden_claimed.connect(func(_m): add_progress("golden", 1))
	EventBus.building_bought.connect(func(_id, n): add_progress("buildings", n))
	EventBus.upgrade_bought.connect(func(_id): add_progress("upgrades", 1))
	EventBus.ability_used.connect(func(_id): add_progress("ability", 1))
	EventBus.game_loaded.connect(_on_loaded)
	EventBus.game_reset.connect(func(): _last_baked = GameState.baked_lifetime)

func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	ensure_today()
	if _last_baked >= 0.0 and GameState.baked_lifetime > _last_baked:
		add_progress("bake", GameState.baked_lifetime - _last_baked)
	_last_baked = GameState.baked_lifetime

func _on_loaded() -> void:
	_last_baked = GameState.baked_lifetime
	ensure_today()

func _on_click(_amount: float, crit: bool, _pos: Vector2) -> void:
	add_progress("clicks", 1)
	if crit:
		add_progress("crits", 1)

# ------------------------------------------------------------ dagen

static func day_key(unix: float = -1.0) -> String:
	if unix < 0.0:
		unix = Time.get_unix_time_from_system()
	# Lokale datum: de dag wisselt om middernacht bij de speler.
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(unix) + bias)

static func previous_day(key: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(key + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)

## Maakt nieuwe uitdagingen zodra het een nieuwe dag is.
func ensure_today(today: String = "") -> void:
	if today == "":
		today = day_key()
	if GameState.daily.get("day", "") == today and GameState.daily.get("tasks", []) is Array \
			and GameState.daily.tasks.size() == TASKS_PER_DAY:
		return
	var streak := int(GameState.daily.get("streak", 0))
	var last_full: String = GameState.daily.get("last_full_day", "")
	# Gisteren niet alles gedaan: de reeks begint opnieuw.
	if last_full != "" and last_full != previous_day(today) and last_full != today:
		streak = 0
	GameState.daily = {"day": today, "tasks": generate(today), "streak": streak, "last_full_day": last_full}
	_last_baked = GameState.baked_lifetime

## Deterministisch: dezelfde datum geeft dezelfde soorten opdrachten.
func generate(day: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("roze-koek-" + day)
	var pool: Array = []
	for c in GameData.challenges.get("challenges", []):
		pool.append(c)
	# Vaste volgorde schudden met de dagseed
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	var tasks: Array = []
	for c in pool:
		if tasks.size() >= TASKS_PER_DAY:
			break
		if c.get("needs_friend", false) and GameState.characters.is_empty():
			continue
		tasks.append({"id": c.id, "goal": goal_for(c), "progress": 0.0, "claimed": false})
	return tasks

## Niveau 0..3 op basis van hoeveel je ooit gebakken hebt.
func tier() -> int:
	return clampi(int(floor(log(maxf(GameState.baked_lifetime, 1.0)) / log(10.0) / 3.0)), 0, 3)

func goal_for(c: Dictionary) -> float:
	var goals: Array = c.get("goals", [1])
	var g := float(goals[mini(tier(), goals.size() - 1)])
	if c.get("metric", "") == "bake":
		# Ongeveer een kwartier productie, afgerond op een mooi getal.
		g = maxf(g, Economy.kps_permanent() * 60.0 * float(c.get("minutes", 15)))
		var p := pow(10.0, floor(log(g) / log(10.0)))
		g = ceilf(g / p) * p
	return g

# ------------------------------------------------------------ voortgang

func tasks() -> Array:
	return GameState.daily.get("tasks", [])

func definition(task: Dictionary) -> Dictionary:
	for c in GameData.challenges.get("challenges", []):
		if c.id == task.id:
			return c
	return {}

func add_progress(metric: String, amount: float) -> void:
	for i in tasks().size():
		var t: Dictionary = tasks()[i]
		var c := definition(t)
		if c.get("metric", "") != metric or is_done(i):
			continue
		t.progress = minf(float(t.progress) + amount, float(t.goal))
		if is_done(i):
			EventBus.challenge_completed.emit(i)

func is_done(i: int) -> bool:
	var t: Dictionary = tasks()[i]
	return float(t.progress) >= float(t.goal)

func text(i: int) -> String:
	var t: Dictionary = tasks()[i]
	return str(definition(t).get("text", "%s")) % NumberFormat.format(float(t.goal))

func reward() -> int:
	return int(GameData.challenges.get("reward", 5))

func streak() -> int:
	return int(GameState.daily.get("streak", 0))

func streak_days() -> int:
	return int(GameData.challenges.get("streak_days", 7))

## Beloning ophalen. Geeft het aantal ontvangen lintjes terug (0 = niet mogelijk).
func claim(i: int) -> int:
	if i < 0 or i >= tasks().size() or not is_done(i) or tasks()[i].claimed:
		return 0
	tasks()[i].claimed = true
	var got := reward()
	if all_claimed():
		got += _complete_day()
	GameState.ribbons += got
	return got

func all_claimed() -> bool:
	for t in tasks():
		if not t.claimed:
			return false
	return not tasks().is_empty()

func _complete_day() -> int:
	var today: String = GameState.daily.day
	if GameState.daily.get("last_full_day", "") == today:
		return 0
	GameState.daily.last_full_day = today
	GameState.daily.streak = streak() + 1
	if streak() >= streak_days():
		GameState.daily.streak = 0
		GameState.flags["streak_7"] = true
		var bonus := int(GameData.challenges.get("streak_reward", 25))
		EventBus.toast.emit("%d dagen op rij! +%d bonuslintjes" % [streak_days(), bonus])
		return bonus
	return 0

# ------------------------------------------------------------ lintjes uitgeven

func boost_info() -> Dictionary:
	return GameData.challenges.get("boost", {"cost": 15, "value": 2, "duration": 900})

func buy_boost() -> bool:
	var b := boost_info()
	if GameState.ribbons < int(b.cost) or RandomEventSystem.buffs.has("lintjes"):
		return false
	GameState.ribbons -= int(b.cost)
	RandomEventSystem.add_buff("lintjes", "Lintjesboost x%d" % int(b.value), float(b.duration),
		[{"type": "global_mult", "value": float(b.value)}])
	return true
