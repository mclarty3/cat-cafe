extends Node
## Global audio: a music playlist plus one-shot and looping sound effects,
## looked up by name in SOUNDS so gameplay code never deals with file paths.
## Music and effects go to the "Music" and "SFX" buses (default_bus_layout.tres).

const KENNEY := "res://assets/audio/sfx/kenney/"
const SYNTH := "res://assets/audio/sfx/synth/"
const CATS := "res://assets/audio/sfx/cats/"

## name -> files (one is picked at random), volume in dB, pitch, and random
## pitch variation (+/-) so repeated sounds don't feel mechanical.
const SOUNDS := {
	# Barista
	"footstep": {"files": ["footstep_wood_000", "footstep_wood_001", "footstep_wood_002", "footstep_wood_003", "footstep_wood_004"], "db": -15.0, "jitter": 0.08},
	"pastry": {"files": ["impactSoft_medium_000", "impactSoft_medium_001"], "db": -6.0},
	"place": {"files": ["impactPlate_light_000", "impactPlate_light_001", "impactPlate_light_002"], "db": -4.0},
	"trash": {"files": ["drop_002"], "db": -4.0},
	# Coffee
	"grinder": {"files": ["synth/grinder"], "db": -20.0, "jitter": 0.03},
	"espresso_pour": {"files": ["synth/espresso_pour"], "db": -21.0, "jitter": 0.0},
	"steam": {"files": ["synth/steam"], "db": -12.0, "jitter": 0.0},
	"scald": {"files": ["synth/scald"], "db": -8.0},
	"step_stop": {"files": ["click_002"], "db": -16.0, "pitch": 0.85},
	"drink_perfect": {"files": ["pluck_002"], "db": -14.0, "pitch": 0.9, "jitter": 0.0},
	"drink_good": {"files": ["pluck_001"], "db": -16.0, "pitch": 0.85, "jitter": 0.0},
	"drink_poor": {"files": ["error_004"], "db": -20.0, "pitch": 0.85, "jitter": 0.0},
	# Minigame feedback (kept quiet: it plays on every press). Pitches are
	# raised further in code for a run of Perfects and for each star.
	"mg_zone_tick": {"files": ["click_002"], "db": -26.0, "pitch": 1.7, "jitter": 0.0},
	"mg_good": {"files": ["pluck_001"], "db": -18.0, "pitch": 1.2, "jitter": 0.0},
	"mg_perfect": {"files": ["pluck_002"], "db": -15.0, "pitch": 1.35, "jitter": 0.0},
	"mg_warn": {"files": ["click_002"], "db": -20.0, "pitch": 0.55, "jitter": 0.0},
	"mg_star": {"files": ["pluck_002"], "db": -17.0, "pitch": 1.0, "jitter": 0.0},
	"mg_fanfare": {"files": ["confirmation_002"], "db": -18.0, "jitter": 0.0},
	"honey_pour": {"files": ["synth/espresso_pour"], "db": -24.0, "pitch": 0.6, "jitter": 0.0},
	# Customers and money
	"door_open": {"files": ["doorOpen_1"], "db": -14.0},
	"door_bell": {"files": ["impactBell_heavy_000"], "db": -16.0, "pitch": 2.2, "jitter": 0.03},
	"register": {"files": ["handleCoins"], "db": -6.0},
	"order_up": {"files": ["impactBell_heavy_000"], "db": -9.0, "pitch": 2.6, "jitter": 0.0},
	"tip": {"files": ["handleCoins2"], "db": -8.0, "pitch": 1.15},
	"walk_out": {"files": ["back_002"], "db": -6.0, "pitch": 0.8},
	"door_close": {"files": ["doorClose_1"], "db": -16.0},
	# Cat (pitch is also scaled per cat by its voice in CafeData.CATS)
	"purr": {"files": ["synth/purr"], "db": -8.0, "pitch": 1.1},
	"cat_meow": {"files": ["cats/meow_short", "cats/meow_food", "cats/meow_soft", "cats/meow_kitten"], "db": -8.0},
	"cat_mew_purr": {"files": ["cats/mew_purr", "cats/mew_purr_long"], "db": -8.0},
	"cat_purr": {"files": ["cats/purr_active", "cats/purr_sleepy"], "db": -17.0},
	"mug_tink": {"files": ["glass_001", "glass_002", "glass_003"], "db": -10.0, "jitter": 0.1},
	"mug_catch": {"files": ["impactPlate_medium_000"], "db": -4.0},
	"mug_crash": {"files": ["impactGlass_heavy_000", "impactGlass_heavy_001"], "db": -3.0},
	"cat_hiss": {"files": ["synth/hiss"], "db": -10.0, "jitter": 0.0},
	"munch": {"files": ["synth/munch"], "db": -14.0},
	"curtain_rip": {"files": ["synth/curtain_rip"], "db": -8.0},
	# UI
	"ui_move": {"files": ["click_002"], "db": -22.0, "pitch": 1.1},
	"ui_select": {"files": ["select_003"], "db": -20.0, "pitch": 0.85},
	"ui_open": {"files": ["open_002"], "db": -22.0, "pitch": 0.85},
	"ui_back": {"files": ["close_002"], "db": -22.0, "pitch": 0.85},
	"dialogue": {"files": ["pluck_001", "pluck_002"], "db": -12.0},
	"prep": {"files": ["impactWood_light_000"], "db": -6.0},
	# Jingles
	# Opening: the shop-door bell as you flip the sign, not a fanfare.
	"day_open": {"files": ["impactBell_heavy_000"], "db": -13.0, "pitch": 2.0, "jitter": 0.0},
	# Closing: the same bell as opening, played as a two-note "ding... dong"
	# (this note, then a fourth lower; see Cafe._end_day).
	"day_close": {"files": ["impactBell_heavy_000"], "db": -12.0, "pitch": 2.0, "jitter": 0.0},
}

const POOL_SIZE := 12
const SILENT_DB := -40.0

var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _loops := {}
var _cache := {}
## Last file played per sound, so variations don't repeat back to back.
var _last_file := {}
var _music: AudioStreamPlayer
var _music_tween: Tween
var _playlist: Array[String] = []
var _track := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_music.finished.connect(_next_track)


## Plays a one-shot sound by name.
func play(sound: String, volume_offset := 0.0, pitch := 1.0) -> void:
	var def := _def(sound)
	if def.is_empty():
		return
	var player := _take_player()
	player.stream = _load(_pick_file(sound, def["files"]))
	player.volume_db = def.get("db", 0.0) + volume_offset
	var jitter: float = def.get("jitter", 0.05)
	player.pitch_scale = pitch * def.get("pitch", 1.0) * randf_range(1.0 - jitter, 1.0 + jitter)
	player.play()


## Starts a looping sound (grinder hum, steam...). Calling it again while it's
## already playing does nothing.
func start_loop(sound: String, fade := 0.08) -> void:
	if _loops.has(sound):
		return
	var def := _def(sound)
	if def.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = _looping(_load(def["files"][0]))
	player.pitch_scale = def.get("pitch", 1.0)
	player.volume_db = SILENT_DB
	add_child(player)
	player.play()
	create_tween().tween_property(player, "volume_db", def.get("db", 0.0), fade)
	_loops[sound] = player


func stop_loop(sound: String, fade := 0.15) -> void:
	if not _loops.has(sound):
		return
	var player: AudioStreamPlayer = _loops[sound]
	_loops.erase(sound)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, fade)
	tween.tween_callback(player.queue_free)


## Bends a running loop's pitch (1 = as defined in SOUNDS), e.g. steam rising
## as the milk heats.
func set_loop_pitch(sound: String, pitch: float) -> void:
	if _loops.has(sound):
		(_loops[sound] as AudioStreamPlayer).pitch_scale = _def(sound).get("pitch", 1.0) * pitch


func stop_all_loops() -> void:
	for sound in _loops.keys():
		stop_loop(sound)


## Plays the tracks in order, moving on when each finishes, and wraps around.
func play_music(tracks: Array[String], fade_in := 2.5) -> void:
	_playlist = tracks.duplicate()
	_track = 0
	if _playlist.is_empty():
		return
	_music.volume_db = SILENT_DB
	_start_track()
	_fade_music(0.0, fade_in)


func stop_music(fade := 1.0) -> void:
	_playlist.clear()
	_fade_music(SILENT_DB, fade, true)


## Temporarily lowers the music (e.g. under the closing chime or a conversation).
func duck_music(amount_db: float, fade := 0.4) -> void:
	_fade_music(-amount_db, fade)


func _start_track() -> void:
	_music.stream = load(_playlist[_track])
	_music.play()


func _next_track() -> void:
	if _playlist.is_empty():
		return
	_track = (_track + 1) % _playlist.size()
	_start_track()


func _fade_music(volume_db: float, duration: float, stop_after := false) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", volume_db, duration)
	if stop_after:
		_music_tween.tween_callback(_music.stop)


func _def(sound: String) -> Dictionary:
	if not SOUNDS.has(sound):
		push_warning("Unknown sound '%s'" % sound)
		return {}
	return SOUNDS[sound]


func _pick_file(sound: String, files: Array) -> String:
	var choices := files.filter(func(f: String) -> bool: return f != _last_file.get(sound, ""))
	var file: String = (choices if not choices.is_empty() else files).pick_random()
	_last_file[sound] = file
	return file


func _take_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	# All busy: reuse the oldest.
	_next_player = (_next_player + 1) % _pool.size()
	return _pool[_next_player]


func _load(file: String) -> AudioStream:
	if not _cache.has(file):
		var path := KENNEY + file + ".ogg"
		if file.begins_with("synth/"):
			path = SYNTH + file.trim_prefix("synth/") + ".wav"
		elif file.begins_with("cats/"):
			path = CATS + file.trim_prefix("cats/") + ".ogg"
		_cache[file] = load(path)
	return _cache[file]


func _looping(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = copy.data.size() / 2  # 16-bit mono
	elif copy is AudioStreamOggVorbis:
		copy.loop = true
	return copy
