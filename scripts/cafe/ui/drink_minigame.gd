class_name DrinkMinigame
extends Control
## The ~5-10 second drink-making minigame. Each drink is a list of steps:
##   pull:  a pressure-gauge needle sweeps back and forth; press Interact in the zone.
##   steam: hold Interact to heat the milk; release in the zone (don't scald it).
##   drizzle: a dream ingredient pours in while a marker drifts along a balance
##            bar (like grinding in Tony Hawk); steer it with Left/Right to keep
##            it in the green. Scored on time spent in the green; hitting
##            either end spills it.
## The drink's quality is its worst step.
##
## Drawn by hand in _draw(): the thing you're making on the left (a cup filling
## under the portafilter, a steaming pitcher), a gauge on the right, and the
## feedback: the gauge punches and the result word pops on each press, sparkles
## scale with quality, and a Perfect drink gets latte art.
##
## Juice (feedback only; it never changes the score):
##   - the panel pops in over a dimmed screen, and shrinks away when done
##   - each press freezes for a beat (hit-stop, longer for better results),
##     sends out a shockwave ring, flashes the panel border, and rumbles a pad
##   - Perfects in a row climb in pitch ("Perfect! x2")
##   - anticipation: the zone glows as the needle nears it, the needle leaves a
##     trail and ticks entering the zone; steam rises in pitch and the gauge
##     trembles past the zone; the drizzle pours, chimes while you hold the
##     green and warns when you slip out
##   - the finished drink bounces in and earns 1-3 stars, each with a rising
##     chime (and a little jingle for a Perfect drink)

signal _step_done(quality: int)

const PANEL_SIZE := Vector2(300, 132)
const GAUGE_RADIUS := 46.0
const ACCENT := Color(1, 0.85, 0.6)
const ZONE_COLOR := Color(0.4, 0.75, 0.4)
const PERFECT_COLOR := Color(0.75, 1, 0.6)
const QUALITY_COLORS := [Color(0.75, 0.68, 0.62), Color(0.6, 0.95, 0.55), Color(1, 0.82, 0.3)]
const ESPRESSO := Color(0.3, 0.17, 0.09)
const CREMA := Color(0.72, 0.48, 0.26)
const GOLD := Color(1, 0.82, 0.3)
const WARN_COLOR := Color(1, 0.4, 0.35)
## Hit-stop per result (poor, good, perfect): seconds the panel freezes on a press.
const HITSTOP := [0.05, 0.08, 0.13]
## A run of Perfects climbs a major scale.
const STREAK_PITCH := [1.0, 1.122, 1.26, 1.335, 1.498]
## Stars on the finished drink, and the pitch each one chimes at.
const STAR_PITCH := [1.0, 1.26, 1.498]
const STAR_GAP := 0.16
## How long the finished drink shows before the panel closes.
const REVEAL_TIME := 1.0

## How fast the pull needle sweeps (dial widths per second).
@export var pull_speed := 0.6
@export var steam_rate := 0.45
@export var zone_half_width := 0.12
@export var perfect_half_width := 0.035
## Ignores input briefly so the key that started the drink doesn't end a step.
@export var input_delay := 0.25
## Seconds for the cup to fill while pulling (just for show).
@export var pour_time := 1.6
## A pause at the start of each drink to get your bearings: the gauge shows,
## the grinder runs, and nothing moves (presses are ignored) until it's over.
@export var lead_in := 1.0

@export_group("Drizzle")
## How long the drizzle lasts.
@export var drizzle_time := 3.5
## A short pause before it starts, since it uses different keys.
@export var drizzle_lead_in := 0.7
## How hard the marker falls away from the middle, per unit off-centre (the
## further out, the faster it tips, like a grind balance).
@export var drizzle_instability := 2.6
## Random nudges: strength, and how often they change (seconds, min-max).
@export var drizzle_nudge := 1.35
@export var drizzle_nudge_every := Vector2(0.4, 1.0)
## How hard Left/Right push the marker.
@export var drizzle_control := 3.5
## Drag on the marker's speed (higher = steadier, easier).
@export var drizzle_damping := 1.6
## Half widths of the green and the perfect band (the bar runs -1 to 1).
@export var drizzle_zone := 0.35
@export var drizzle_perfect := 0.12
## Share of the time in the green for Good; for Perfect, also this share in
## the perfect band (and nearly all of it in the green).
@export_range(0.0, 1.0) var drizzle_good_share := 0.7
@export_range(0.0, 1.0) var drizzle_perfect_share := 0.55

var _title := ""
var _drink_color := Color.WHITE
var _step := ""
var _t := 0.0
var _value := 0.0
var _zone_center := 0.5
var _holding := false
var _finished := false
var _result_text := ""
var _result_color := Color.WHITE
## Seconds since the result word appeared (drives its pop).
var _result_age := 0.0
## 1 right after a press, easing to 0: the gauge's punch and the zone flash.
var _punch := 0.0
var _flash_color := Color.WHITE
## Seconds of shake left (a scald).
var _shake := 0.0
## Set once the whole drink is done: show the finished cup.
var _final := -1
var _sparkles: Array[Dictionary] = []
## Seconds left of the lead-in (see `lead_in`).
var _ready_left := 0.0
## Drizzle: the marker (-1..1), its speed, the current nudge, and how long it's
## spent in the green and in the perfect band.
var _balance := 0.0
var _balance_vel := 0.0
var _nudge := 0.0
var _nudge_left := 0.0
var _green_time := 0.0
var _perfect_time := 0.0
## Drizzle: which way the player is pushing (-1, 0, 1), for the arrows.
var _steer := 0.0

## Juice state (see the header).
## 0..1: how far the panel has popped in.
var _open := 0.0
## Seconds left of the freeze after a press.
var _hitstop := 0.0
## Perfects in a row this drink.
var _streak := 0
## Expanding rings: {"pos", "age", "life", "color", "radius"}.
var _rings: Array[Dictionary] = []
## Recent needle positions, newest last, for its trail.
var _trail: Array[float] = []
var _was_in_zone := false
## Drizzle: seconds held in the green without slipping, the next chime, and a
## cooldown so slipping out doesn't spam warnings.
var _green_run := 0.0
var _next_chime := 0.0
var _warn_cooldown := 0.0
## The finished drink: seconds since it appeared, and stars shown so far.
var _reveal_age := 0.0
var _stars_shown := 0
## The whole panel's transform this frame (pop-in scale and shake).
var _xf := Transform2D.IDENTITY


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(item_id: String) -> int:
	var data := CafeData.item(item_id)
	_title = data["name"]
	_drink_color = data["color"]
	_final = -1
	_sparkles.clear()
	_rings.clear()
	_streak = 0
	_hitstop = 0.0
	_open = 0.0
	show()
	create_tween().tween_property(self, "_open", 1.0, 0.22)
	var worst := CafeData.Quality.PERFECT
	var steps: Array = data["steps"]
	for i in steps.size():
		var quality: int = await _run_step(steps[i], lead_in if i == 0 else 0.0)
		worst = mini(worst, quality)
	_step = ""
	_final = worst
	_reveal_age = 0.0
	_stars_shown = 0
	_show_result(CafeData.QUALITY_NAMES[worst], QUALITY_COLORS[worst])
	_burst(_cup_rect().get_center() + Vector2(0, -10), worst, true)
	_ring(_cup_rect().get_center(), QUALITY_COLORS[worst], 46.0)
	Audio.play(["drink_poor", "drink_good", "drink_perfect"][worst])
	await get_tree().create_timer(REVEAL_TIME).timeout
	var close := create_tween()
	close.tween_property(self, "_open", 0.0, 0.14)
	await close.finished
	hide()
	return worst


## Runs one step, after `ready` seconds of lead-in. Returns its quality.
func _run_step(step: String, ready := 0.0) -> int:
	_step = step
	_t = 0.0
	_value = 0.0
	_holding = false
	_finished = false
	_result_text = ""
	_trail.clear()
	_was_in_zone = false
	_green_run = 0.0
	_next_chime = 0.6
	_warn_cooldown = 0.0
	_zone_center = randf_range(0.55, 0.85) if step == "pull" else randf_range(0.6, 0.8)
	if step == "pull":
		Audio.play("grinder")
	if step == "drizzle":
		# Start a touch off-centre, already leaning, so it moves straight away.
		_balance = randf_range(0.04, 0.1) * (1 if randf() < 0.5 else -1)
		_balance_vel = 0.0
		_nudge = 0.0
		_nudge_left = 0.0
		_green_time = 0.0
		_perfect_time = 0.0
		_steer = 0.0
		ready = maxf(ready, drizzle_lead_in)
	_ready_left = ready
	while _ready_left > 0.0:
		await get_tree().process_frame
	if step == "pull":
		Audio.start_loop("espresso_pour")
	elif step == "drizzle":
		Audio.start_loop("honey_pour")
	return await _step_done


func _process(delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	# Hit-stop: everything holds still for a beat after a press.
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	_result_age += delta
	_punch = move_toward(_punch, 0.0, delta * 4.0)
	_shake = maxf(_shake - delta, 0.0)
	_update_sparkles(delta)
	_update_rings(delta)
	if _final >= 0:
		_update_reveal(delta)
	if _ready_left > 0.0:
		_ready_left -= delta
	elif not _step.is_empty() and not _finished:
		_t += delta
		var can_input := _t > input_delay
		match _step:
			"pull":
				_value = pingpong(_t * pull_speed, 1.0)
				_track_needle()
				if can_input and Input.is_action_just_pressed("cafe_interact"):
					_finish(_score(_value))
			"steam":
				if can_input and Input.is_action_just_pressed("cafe_interact"):
					_holding = true
					Audio.start_loop("steam")
				if _holding:
					_value += steam_rate * delta
					_track_needle()
					# The hiss climbs as it heats; past the zone the gauge trembles.
					Audio.set_loop_pitch("steam", lerpf(0.85, 1.35, _value))
					if _value > _zone_center + zone_half_width:
						_shake = maxf(_shake, 0.06)
					if _value >= 1.0:
						_value = 1.0
						_finish(CafeData.Quality.POOR, "Scalded!")
					elif not Input.is_action_pressed("cafe_interact"):
						_finish(_score(_value))
			"drizzle":
				_update_drizzle(delta, can_input)


## Remembers the needle for its trail, and ticks softly as it enters the zone
## (a timing cue).
func _track_needle() -> void:
	_trail.append(_value)
	if _trail.size() > 6:
		_trail.pop_front()
	var in_zone := absf(_value - _zone_center) <= zone_half_width
	if in_zone and not _was_in_zone and _t > input_delay:
		Audio.play("mg_zone_tick")
	_was_in_zone = in_zone


## The balance: the marker tips away from the middle (harder the further out),
## random nudges push it about, and Left/Right push back.
func _update_drizzle(delta: float, can_input: bool) -> void:
	_nudge_left -= delta
	if _nudge_left <= 0.0:
		_nudge = randf_range(-1.0, 1.0) * drizzle_nudge
		_nudge_left = randf_range(drizzle_nudge_every.x, drizzle_nudge_every.y)
	_steer = Input.get_axis("move_left", "move_right") if can_input else 0.0
	var push := _balance * drizzle_instability + _nudge + _steer * drizzle_control
	_balance_vel += push * delta
	_balance_vel -= _balance_vel * drizzle_damping * delta
	_balance += _balance_vel * delta
	var in_green := absf(_balance) <= drizzle_zone
	if in_green:
		_green_time += delta
	if absf(_balance) <= drizzle_perfect:
		_perfect_time += delta
	_drizzle_feedback(delta, in_green)
	if absf(_balance) >= 1.0:
		_balance = signf(_balance)
		_finish(CafeData.Quality.POOR, "Spilled!")
	elif _t >= drizzle_time:
		_finish(_drizzle_score())


## Holding the green chimes, climbing a little the longer you hold it, with a
## twinkle at the marker; slipping out gives a soft warning and a red flash.
## The pour sounds richer while you're on target.
func _drizzle_feedback(delta: float, in_green: bool) -> void:
	_warn_cooldown = maxf(_warn_cooldown - delta, 0.0)
	Audio.set_loop_pitch("honey_pour", 1.0 if in_green else 0.85)
	if in_green:
		_green_run += delta
		if _green_run >= _next_chime:
			var step := mini(int(_green_run / 0.6) - 1, STREAK_PITCH.size() - 1)
			Audio.play("mg_good", -4.0, STREAK_PITCH[step])
			_burst(_marker_point(), CafeData.Quality.GOOD, false)
			_next_chime += 0.6
	else:
		if _green_run > 0.0 and _warn_cooldown <= 0.0:
			Audio.play("mg_warn")
			_flash_color = WARN_COLOR
			_punch = 0.5
			_warn_cooldown = 0.5
		_green_run = 0.0
		_next_chime = 0.6


func _drizzle_score() -> int:
	var green := _green_time / maxf(_t, 0.001)
	var perfect := _perfect_time / maxf(_t, 0.001)
	if perfect >= drizzle_perfect_share and green >= 0.95:
		return CafeData.Quality.PERFECT
	if green >= drizzle_good_share:
		return CafeData.Quality.GOOD
	return CafeData.Quality.POOR


func _score(value: float) -> int:
	var d := absf(value - _zone_center)
	if d <= perfect_half_width:
		return CafeData.Quality.PERFECT
	if d <= zone_half_width:
		return CafeData.Quality.GOOD
	return CafeData.Quality.POOR


func _finish(quality: int, text := "") -> void:
	_finished = true
	Audio.stop_loop("espresso_pour")
	Audio.stop_loop("steam")
	Audio.stop_loop("honey_pour")
	_punch = 1.0
	_flash_color = QUALITY_COLORS[quality]
	_hitstop = HITSTOP[quality]
	var at := _marker_point() if _step == "drizzle" else _gauge_center() + _needle_dir() * GAUGE_RADIUS * 0.8
	_streak = _streak + 1 if quality == CafeData.Quality.PERFECT and text.is_empty() else 0
	if not text.is_empty():
		# Scalded, or spilled.
		_shake = 0.3
		_hitstop = 0.12
		_flash_color = WARN_COLOR
		Audio.play("scald" if _step == "steam" else "drink_poor")
		_show_result(text, _flash_color)
		_ring(at, WARN_COLOR, 30.0)
		_rumble(0.2, 0.7, 0.25)
		_done_after(quality)
		return
	if _step == "drizzle":
		Audio.play("step_stop", 0.0, [0.8, 1.05, 1.35][quality])
	else:
		# The click rises in pitch the closer you were to the middle of the zone.
		var closeness := 1.0 - clampf(absf(_value - _zone_center) / (zone_half_width * 2.0), 0.0, 1.0)
		Audio.play("step_stop", 0.0, lerpf(0.8, 1.35, closeness))
	match quality:
		CafeData.Quality.PERFECT:
			# A run of Perfects climbs in pitch and says so.
			Audio.play("mg_perfect", 0.0, STREAK_PITCH[mini(_streak - 1, STREAK_PITCH.size() - 1)])
			var text_streak: String = "Perfect! x%d" % _streak if _streak > 1 else CafeData.QUALITY_NAMES[quality]
			_show_result(text_streak, QUALITY_COLORS[quality])
			_ring(at, GOLD, 34.0)
			_ring(at, Color.WHITE, 22.0, 0.08)
			_rumble(0.5, 0.3, 0.12)
		CafeData.Quality.GOOD:
			Audio.play("mg_good")
			_show_result(CafeData.QUALITY_NAMES[quality], QUALITY_COLORS[quality])
			_ring(at, QUALITY_COLORS[quality], 26.0)
			_rumble(0.35, 0.0, 0.08)
		_:
			_shake = 0.15
			_show_result(CafeData.QUALITY_NAMES[quality], QUALITY_COLORS[quality])
			_rumble(0.0, 0.3, 0.1)
	_burst(at, quality, false)
	_done_after(quality)


func _done_after(quality: int) -> void:
	get_tree().create_timer(0.45).timeout.connect(_step_done.emit.bind(quality))


## A gamepad buzz, if one is connected.
func _rumble(weak: float, strong: float, seconds: float) -> void:
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, weak, strong, seconds)


func _show_result(text: String, color: Color) -> void:
	_result_text = text
	_result_color = color
	_result_age = 0.0


# --- Sparkles ------------------------------------------------------------------

## Sparkles scale with quality: none for Poor, a few for Good, a gold burst for
## Perfect (bigger for the finished drink).
func _burst(at: Vector2, quality: int, big: bool) -> void:
	var count: int = [0, 5, 12][quality] * (2 if big else 1)
	for i in count:
		var angle := randf() * TAU
		var speed := randf_range(30.0, 75.0) * (1.3 if big else 1.0)
		_sparkles.append({
			"pos": at, "vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -20),
			"life": randf_range(0.35, 0.6), "age": 0.0,
			"color": QUALITY_COLORS[quality].lightened(randf() * 0.3), "size": randf_range(1.5, 3.0),
		})


## A shockwave ring growing out to `radius` (after `delay` seconds).
func _ring(at: Vector2, color: Color, radius: float, delay := 0.0) -> void:
	_rings.append({"pos": at, "age": -delay, "life": 0.35, "color": color, "radius": radius})


func _update_rings(delta: float) -> void:
	for r in _rings:
		r["age"] += delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r["age"] < r["life"])


## The finished drink's stars pop in one after another, each chiming a step
## higher; the last star of a Perfect drink gets a little jingle and a burst.
func _update_reveal(delta: float) -> void:
	_reveal_age += delta
	var earned := _final + 1
	var due := mini(int((_reveal_age - 0.12) / STAR_GAP) + 1, earned) if _reveal_age >= 0.12 else 0
	while _stars_shown < due:
		var at := _star_point(_stars_shown)
		Audio.play("mg_star", 0.0, STAR_PITCH[_stars_shown])
		_ring(at, GOLD, 14.0)
		_stars_shown += 1
		if _stars_shown == 3:
			Audio.play("mg_fanfare")
			_burst(at, CafeData.Quality.PERFECT, false)


func _update_sparkles(delta: float) -> void:
	for s in _sparkles:
		s["age"] += delta
		s["vel"] += Vector2(0, 90) * delta
		s["pos"] += s["vel"] * delta
	_sparkles = _sparkles.filter(func(s: Dictionary) -> bool: return s["age"] < s["life"])


# --- Drawing --------------------------------------------------------------------

func _panel() -> Rect2:
	return Rect2(size / 2.0 - PANEL_SIZE / 2.0, PANEL_SIZE)


func _gauge_center() -> Vector2:
	return _panel().position + Vector2(210, 92)


## Where the needle points: left (0) over the top to right (1).
func _needle_dir() -> Vector2:
	var angle := PI + _value * PI
	return Vector2(cos(angle), sin(angle))


## Where the cup (or pitcher) sits: on the left during the steps, bigger and
## centred for the finished drink.
func _cup_rect() -> Rect2:
	if _final >= 0:
		var cup_size := Vector2(64, 50)
		return Rect2(_panel().get_center() - cup_size / 2.0 + Vector2(-6, -8), cup_size)
	return Rect2(_panel().position + Vector2(40, 74), Vector2(48, 38))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var panel := _panel()
	# Dim the cafe behind, then draw the panel popped in (a little overshoot)
	# and shaken.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.28 * _open))
	var pop := 0.7 + 0.3 * _ease_out_back(_open)
	var shake := Vector2.ZERO
	if _shake > 0.0:
		var amount := minf(_shake / 0.15, 1.0) * 3.0
		shake = Vector2(randf_range(-amount, amount), randf_range(-amount, amount) * 0.6)
	var middle := panel.get_center()
	_xf = Transform2D(0.0, Vector2(pop, pop), 0.0, middle + shake) * Transform2D(0.0, -middle)
	draw_set_transform_matrix(_xf)
	modulate.a = clampf(_open * 1.5, 0.0, 1.0)

	draw_rect(panel, Color(0.17, 0.12, 0.1, 0.95))
	# The border flashes the result's colour on a press.
	var border := Color(0.85, 0.68, 0.48).lerp(_flash_color, _punch)
	draw_rect(panel, border, false, 1.0 + 2.0 * _punch)
	draw_string(font, panel.position + Vector2(12, 16), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ACCENT)

	var hint := ""
	match _step:
		"pull":
			hint = "Pull the shot: press Interact in the green"
		"steam":
			hint = "Steam the milk: hold Interact, let go in the green"
		"drizzle":
			hint = "Drizzle it in: keep it in the green with Left / Right"
	draw_string(font, panel.position + Vector2(12, 30), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.8))

	match _step:
		"pull":
			_draw_pull()
		"steam":
			_draw_steam()
		"drizzle":
			_draw_drizzle()
	if _final >= 0:
		# The finished drink bounces up from its base.
		var base := Vector2(_cup_rect().get_center().x, _cup_rect().end.y)
		var k := 0.55 + 0.45 * _ease_out_back(clampf(_reveal_age / 0.28, 0.0, 1.0))
		draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(k, k), 0.0, base) * Transform2D(0.0, -base))
		_draw_finished_cup()
		draw_set_transform_matrix(_xf)
		_draw_stars()
	if _step == "drizzle":
		_draw_balance(font)
	elif not _step.is_empty():
		_draw_gauge(font, "PRESSURE" if _step == "pull" else "TEMP")

	for r in _rings:
		if r["age"] < 0.0:
			continue
		var t: float = r["age"] / r["life"]
		var eased := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(r["pos"], 3.0 + eased * r["radius"], 0.0, TAU, 32, Color(r["color"], 1.0 - t), 3.0 * (1.0 - t) + 0.5)
	for s in _sparkles:
		var fade: float = 1.0 - s["age"] / s["life"]
		draw_circle(s["pos"], s["size"] * fade, Color(s["color"], fade))

	if not _result_text.is_empty():
		_draw_result(font)
	elif _ready_left > 0.0:
		var text := "Get ready..."
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var alpha := 0.55 + 0.35 * sin(_ready_left * 9.0)
		draw_string(font, Vector2(_gauge_center().x - width / 2.0, _panel().end.y - 10), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ACCENT, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _ease_out_back(t: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)


## Where the finished drink's stars sit: a row under the cup.
func _star_point(i: int) -> Vector2:
	var cup := _cup_rect()
	return Vector2(cup.get_center().x + (i - 1) * 22, cup.end.y + 13)


## Three star slots; earned ones pop in gold (see _update_reveal()).
func _draw_stars() -> void:
	for i in 3:
		var at := _star_point(i)
		if i < _stars_shown:
			# Each pops with an overshoot as it lands.
			var age := _reveal_age - 0.12 - i * STAR_GAP
			var pop := lerpf(1.6, 1.0, clampf(age / 0.15, 0.0, 1.0))
			_draw_star(at, 8.0 * pop, GOLD)
		else:
			_draw_star(at, 8.0, Color(1, 1, 1, 0.15))


func _draw_star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(at + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * 0.45))
	draw_colored_polygon(points, color)


## The gauge: a dial over the top, the zone in green (brightest at perfect),
## and the needle. A press punches it outward and flashes the zone.
func _draw_gauge(font: Font, label: String) -> void:
	var center := _gauge_center()
	var r := GAUGE_RADIUS * (1.0 + 0.08 * _punch)
	# The dial face: a half disc, so it sits inside the panel.
	var face := PackedVector2Array()
	for i in 21:
		var a := PI + i / 20.0 * PI
		face.append(center + Vector2(cos(a), sin(a)) * (r + 7))
	face.append(center + Vector2(r + 7, 9))
	face.append(center + Vector2(-(r + 7), 9))
	draw_colored_polygon(face, Color(0.1, 0.07, 0.06))
	draw_arc(center, r, PI, TAU, 40, Color(1, 1, 1, 0.12), 9.0)
	var zone_lo := PI + (_zone_center - zone_half_width) * PI
	var zone_hi := PI + (_zone_center + zone_half_width) * PI
	# The zone glows brighter and thicker as the needle comes near.
	var near := 0.0
	if not _finished and _ready_left <= 0.0 and (_step == "pull" or _holding):
		near = 1.0 - clampf((absf(_value - _zone_center) - zone_half_width) / (zone_half_width * 2.0), 0.0, 1.0)
	var glow := 2.5 * near + 3.0 * _punch
	if near > 0.0:
		draw_arc(center, r, zone_lo, zone_hi, 12, Color(ZONE_COLOR.lightened(0.4), 0.25 * near), 9.0 + glow + 6.0)
	var zone := ZONE_COLOR.lightened(0.25 * near).lerp(_flash_color, _punch * 0.8)
	draw_arc(center, r, zone_lo, zone_hi, 12, zone, 9.0 + glow)
	draw_arc(center, r, PI + (_zone_center - perfect_half_width) * PI,
		PI + (_zone_center + perfect_half_width) * PI, 6, PERFECT_COLOR, 9.0 + glow)
	# Tick marks.
	for i in 11:
		var a := PI + i / 10.0 * PI
		var d := Vector2(cos(a), sin(a))
		draw_line(center + d * (r - 8), center + d * (r - 4 if i % 5 else r - 12), Color(1, 1, 1, 0.35), 1.0)
	# Steaming fills the dial as the milk heats.
	if _step == "steam" and _value > 0.0:
		draw_arc(center, r - 14, PI, PI + _value * PI, 24, Color(1, 0.55, 0.35, 0.45), 4.0)
	# The needle's trail: faded copies where it just was.
	if not _finished:
		for i in _trail.size():
			var a := PI + _trail[i] * PI
			var fade := float(i + 1) / (_trail.size() + 1)
			draw_line(center, center + Vector2(cos(a), sin(a)) * (r - 6), Color(1, 1, 1, 0.12 * fade), 2.0)
	var needle := Color.WHITE.lerp(_flash_color, _punch)
	# Steaming past the zone: the needle pulses red, warning of a scald.
	if _step == "steam" and _holding and not _finished and _value > _zone_center + zone_half_width:
		needle = needle.lerp(WARN_COLOR, 0.5 + 0.5 * sin(_t * 30.0))
	draw_line(center, center + _needle_dir() * (r - 6), needle, 2.0 + _punch)
	draw_circle(center, 4.0, needle)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	draw_string(font, center + Vector2(-width / 2.0, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.45))


## A cup under the portafilter, filling with espresso and crema while you pull.
func _draw_pull() -> void:
	var cup := _cup_rect()
	var head := Rect2(cup.position + Vector2(4, -36), Vector2(cup.size.x - 8, 10))
	draw_rect(head, Color(0.35, 0.33, 0.32))
	draw_rect(Rect2(head.get_center() + Vector2(-14, 4), Vector2(28, 4)), Color(0.22, 0.2, 0.2))
	var fill := clampf(_t / pour_time, 0.0, 1.0) if not _finished else clampf(_t / pour_time, 0.15, 1.0)
	if not _finished and _ready_left <= 0.0:
		# The stream, wobbling a little.
		var x := head.get_center().x + sin(_t * 30.0) * 0.6
		draw_line(Vector2(x, head.end.y + 4), Vector2(x, cup.end.y - 4), ESPRESSO, 2.0)
	_draw_cup(cup, fill, ESPRESSO, CREMA)


## A steel pitcher on the wand: the milk warms (and reddens if it scalds) and
## the steam grows as it heats.
func _draw_steam() -> void:
	var cup := _cup_rect()
	var pitcher := Rect2(cup.position + Vector2(2, -6), Vector2(cup.size.x - 4, cup.size.y + 6))
	var steel := Color(0.72, 0.74, 0.78)
	draw_colored_polygon(PackedVector2Array([
		pitcher.position, Vector2(pitcher.end.x, pitcher.position.y),
		Vector2(pitcher.end.x - 5, pitcher.end.y), Vector2(pitcher.position.x + 5, pitcher.end.y)]), steel)
	draw_arc(Vector2(pitcher.end.x + 2, pitcher.get_center().y), 7, -PI / 2, PI / 2, 8, steel, 3.0)
	var milk := Color(0.97, 0.95, 0.9).lerp(Color(1, 0.55, 0.45), clampf((_value - 0.85) / 0.15, 0.0, 1.0))
	draw_rect(Rect2(pitcher.position + Vector2(3, 3), Vector2(pitcher.size.x - 6, 4)), milk)
	# The wand.
	draw_line(pitcher.position + Vector2(pitcher.size.x * 0.65, -26), pitcher.position + Vector2(pitcher.size.x * 0.55, 10),
		Color(0.55, 0.56, 0.6), 3.0)
	# Steam puffs, more and bigger as it heats.
	var heat := _value if _holding or _finished else 0.0
	for i in int(2 + heat * 7):
		var rise := fmod(_t * 0.9 + i * 0.37, 1.0)
		var p := pitcher.position + Vector2(8 + fmod(i * 13.0, pitcher.size.x - 12) + sin(_t * 3 + i) * 3, -4 - rise * 28)
		draw_circle(p, (2.0 + heat * 3.0) * (1.0 - rise * 0.5), Color(1, 1, 1, 0.35 * (1.0 - rise) * (0.4 + heat)))


## The drizzle's balance bar: green in the middle (brightest at perfect), the
## marker riding along it, arrows that light up as you steer, and a strip
## underneath counting down the pour.
func _balance_bar() -> Rect2:
	return Rect2(_gauge_center() + Vector2(-70, -34), Vector2(140, 10))


func _marker_point() -> Vector2:
	var bar := _balance_bar()
	return Vector2(bar.get_center().x + _balance * bar.size.x / 2.0, bar.get_center().y)


func _draw_balance(font: Font) -> void:
	var bar := _balance_bar()
	var grow := 2.0 * _punch
	bar = bar.grow_individual(0, grow, 0, grow)
	var half := bar.size.x / 2.0
	var mid := bar.get_center().x
	draw_rect(bar.grow(3), Color(0.1, 0.07, 0.06))
	# The ends are where it spills: tinted red.
	draw_rect(bar, Color(0.55, 0.25, 0.2, 0.6))
	draw_rect(Rect2(mid - half * 0.8, bar.position.y, half * 1.6, bar.size.y), Color(1, 1, 1, 0.12))
	# The green warms up the longer you hold it.
	var held := clampf(_green_run / 2.0, 0.0, 1.0) if not _finished else 0.0
	var zone := ZONE_COLOR.lightened(0.3 * held).lerp(_flash_color, _punch * 0.8)
	draw_rect(Rect2(mid - half * drizzle_zone, bar.position.y, half * drizzle_zone * 2.0, bar.size.y), zone)
	draw_rect(Rect2(mid - half * drizzle_perfect, bar.position.y, half * drizzle_perfect * 2.0, bar.size.y), PERFECT_COLOR)
	# The marker: a post with a cap, leaning the way it's falling.
	var at := Vector2(mid + _balance * half, bar.get_center().y)
	var lean := clampf(_balance_vel * 0.25, -0.5, 0.5)
	# White in the green, reddening outside it.
	var off := clampf((absf(_balance) - drizzle_zone) / (1.0 - drizzle_zone) * 2.0, 0.0, 1.0)
	var marker := Color.WHITE.lerp(Color(1, 0.45, 0.4), off).lerp(_flash_color, _punch)
	var top := at + Vector2(sin(lean), -cos(lean)) * 14.0
	# On target: a soft halo that breathes.
	if off <= 0.0 and not _finished and _ready_left <= 0.0:
		draw_circle(top, 6.0 + sin(_t * 8.0), Color(PERFECT_COLOR, 0.25 + 0.2 * held))
	draw_line(at + Vector2(0, 7), top, marker, 2.0 + _punch)
	draw_circle(top, 3.5, marker)
	# Steering arrows at either end; the one you're pushing swells.
	for dir in [-1, 1]:
		var lit: bool = signf(_steer) == dir
		var k := 1.35 if lit else 1.0
		var tip := Vector2(mid + dir * (half + 16), bar.get_center().y)
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-dir * 8, -6) * k, tip + Vector2(-dir * 8, 6) * k]),
			ACCENT if lit else Color(1, 1, 1, 0.3))
	# The pour's progress.
	var progress := clampf(_t / drizzle_time, 0.0, 1.0) if _ready_left <= 0.0 else 0.0
	var strip := Rect2(bar.position.x, bar.end.y + 12, bar.size.x, 3)
	draw_rect(strip, Color(1, 1, 1, 0.12))
	draw_rect(Rect2(strip.position, Vector2(strip.size.x * progress, strip.size.y)), _drink_color)
	var label := "BALANCE"
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	draw_string(font, Vector2(mid - width / 2.0, strip.end.y + 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.45))


## A dipper over the cup, drizzling a stream that sways with the balance; off
## the green it splashes over the rim. The swirl on top grows as it pours.
func _draw_drizzle() -> void:
	var cup := _cup_rect()
	var pour := clampf(_t / drizzle_time, 0.0, 1.0) if _ready_left <= 0.0 else 0.0
	_draw_cup(cup, 0.85, Color(0.78, 0.62, 0.48).darkened(0.2), Color(0.9, 0.8, 0.66))
	var honey := _drink_color
	# The dipper, drifting with the balance.
	var drift := _balance * cup.size.x * 0.55
	var dipper := Vector2(cup.get_center().x + drift, cup.position.y - 30)
	draw_line(dipper + Vector2(10, -12), dipper, Color(0.6, 0.45, 0.3), 2.0)
	draw_circle(dipper, 5.0, honey.darkened(0.15))
	for i in 3:
		draw_line(dipper + Vector2(-5, -2 + i * 2.5), dipper + Vector2(5, -2 + i * 2.5), honey.darkened(0.35), 1.0)
	# The latte's surface (matching _draw_cup at 0.85 full).
	var surface := cup.position.y + 3 + (cup.size.y - 7) * 0.15
	if _ready_left <= 0.0 and not _finished:
		var x := dipper.x + sin(_t * 8.0) * 0.8
		draw_line(Vector2(x, dipper.y + 4), Vector2(x, surface), honey, 2.0)
		if absf(_balance) > drizzle_zone:
			# Missing the cup: drips run down the outside.
			var side := cup.end.x - 3 if _balance > 0 else cup.position.x + 3
			for i in 3:
				var fall := fmod(_t * 1.6 + i * 0.33, 1.0)
				draw_circle(Vector2(side, surface + fall * cup.size.y * 0.8), 1.6, honey)
	# The swirl on the latte's surface, seen from the side (squashed flat).
	if pour > 0.0:
		draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(1, 0.3), 0.0, Vector2(cup.get_center().x, surface + 2)))
		draw_arc(Vector2.ZERO, 2.0 + pour * cup.size.x * 0.28, 0.0, PI * 1.6 * pour + 0.3, 16, honey, 2.0)
		draw_set_transform_matrix(_xf)


## The finished drink: the item's colour, with latte art if it's Perfect.
func _draw_finished_cup() -> void:
	var cup := _cup_rect()
	_draw_cup(cup, 1.0, _drink_color.darkened(0.25), _drink_color)
	if _final == CafeData.Quality.PERFECT:
		# A heart sized to the cup, just below the rim.
		var u := cup.size.x / 16.0
		var top := Vector2(cup.get_center().x, cup.position.y + 3.0 * u)
		var heart := Color(1, 0.97, 0.92)
		draw_circle(top + Vector2(-1.1, -0.3) * u, 1.25 * u, heart)
		draw_circle(top + Vector2(1.1, -0.3) * u, 1.25 * u, heart)
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(-2.3, 0.2) * u, top + Vector2(2.3, 0.2) * u, top + Vector2(0, 2.6) * u]), heart)


## A simple cup: white sides, a handle, and liquid up to `fill` with a lighter top.
func _draw_cup(cup: Rect2, fill: float, liquid: Color, top: Color) -> void:
	var white := Color(0.96, 0.94, 0.9)
	draw_arc(Vector2(cup.end.x, cup.get_center().y), 8, -PI / 2, PI / 2, 10, white, 3.0)
	draw_colored_polygon(PackedVector2Array([
		cup.position, Vector2(cup.end.x, cup.position.y),
		Vector2(cup.end.x - 6, cup.end.y), Vector2(cup.position.x + 6, cup.end.y)]), white)
	if fill <= 0.0:
		return
	var inner := Rect2(cup.position + Vector2(4, 3), cup.size - Vector2(8, 7))
	var level := inner.end.y - inner.size.y * fill
	draw_rect(Rect2(inner.position.x + 2, level, inner.size.x - 4, inner.end.y - level), liquid)
	draw_rect(Rect2(inner.position.x + 1, level, inner.size.x - 2, minf(3.0, inner.end.y - level)), top)


## The result word lands oversized and settles (and droops if it's Poor).
func _draw_result(font: Font) -> void:
	var t := _result_age
	# Lands big (that's what the hit-stop freezes on) and settles.
	var settle := minf(t / 0.2, 1.0)
	var pop := lerpf(1.5, 1.0, 1.0 - pow(1.0 - settle, 3.0))
	var droop := 0.0
	if _result_color == QUALITY_COLORS[CafeData.Quality.POOR]:
		droop = minf(t, 0.4) * 10.0
	var size_px := 15
	var width := font.get_string_size(_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	# The finished drink's word lines up with the cup and its stars.
	var x := _cup_rect().get_center().x if _final >= 0 else _gauge_center().x
	var at := Vector2(x, _panel().end.y - 8 + droop)
	draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2.ONE * pop, 0.0, at))
	draw_string_outline(font, Vector2(-width / 2.0, 0), _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color(0.1, 0.07, 0.05))
	draw_string(font, Vector2(-width / 2.0, 0), _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, _result_color)
	draw_set_transform_matrix(_xf)
