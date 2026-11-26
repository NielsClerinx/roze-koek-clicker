extends Node
## Geluid en muziek. Luistert naar EventBus en kijkt naar GameState.settings
## ("sound" voor effecten, "music" voor achtergrondmuziek).
## Alle geluiden zijn zelf gemaakt met tools/audio/make_sounds.py.

const SFX := {
	"klik": preload("res://assets/audio/klik.wav"),
	"kopen": preload("res://assets/audio/kopen.wav"),
	"gouden": preload("res://assets/audio/gouden.wav"),
}
const MUSIC := preload("res://assets/audio/muziek.ogg")
const POOL := 6
const MUSIC_DB := -9.0

var enabled := true   # tests zetten dit uit
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = MUSIC.duplicate()
	stream.loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB
	add_child(_music)
	EventBus.cookies_clicked.connect(func(_a, crit, _p): play("klik", 0.8 if crit else 1.0))
	EventBus.building_bought.connect(func(_id, _n): play("kopen"))
	EventBus.upgrade_bought.connect(func(_id): play("kopen", 1.25))
	EventBus.golden_claimed.connect(func(_m): play("gouden"))
	EventBus.game_loaded.connect(apply_settings)
	apply_settings.call_deferred()

func sound_on() -> bool:
	return bool(GameState.settings.get("sound", true))

func music_on() -> bool:
	return bool(GameState.settings.get("music", true))

func set_sound(on: bool) -> void:
	GameState.settings["sound"] = on
	SaveManager.save_game()

func set_music(on: bool) -> void:
	GameState.settings["music"] = on
	apply_settings()
	SaveManager.save_game()

## Muziek starten of stoppen volgens de instellingen.
func apply_settings() -> void:
	var want := enabled and music_on()
	if want and not _music.playing:
		_music.play()
	elif not want and _music.playing:
		_music.stop()

func is_music_playing() -> bool:
	return _music.playing

## Speelt een effect, met een klein beetje variatie in toonhoogte zodat het niet gaat vervelen.
func play(id: String, pitch := 1.0) -> void:
	if not enabled or not sound_on() or not SFX.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = SFX[id]
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.1)
	p.play()
