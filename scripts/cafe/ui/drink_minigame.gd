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

signal _step_done(quality: int)

const PANEL_SIZE := Vector2(300, 132)
const GAUGE_RADIUS := 46.0
const ACCENT := Color(1, 0.85, 0.6)
const ZONE_COLOR := Color(0.4, 0.75, 0.4)
const PERFECT_COLOR := Color(0.75, 1, 0.6)
const QUALITY_COLORS := [Color(0.75, 0.68, 0.62), Color(0.6, 0.95, 0.55), Color(1, 0.82, 0.3)]
const ESPRESSO := Color(0.3, 0.17, 0.09)
const CREMA := Color(0.72, 0.48, 0.26)

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
	show()
	var worst := CafeData.Quality.PERFECT
	var steps: Array = data["steps"]
	for i in steps.size():
		var quality: int = await _run_step(steps[i], lead_in if i == 0 else 0.0)
		worst = mini(worst, quality)
	_step = ""
	_final = worst
	_show_result(CafeData.QUALITY_NAMES[worst], QUALITY_COLORS[worst])
	_burst(_cup_rect().get_center() + Vector2(0, -10), worst, true)
	Audio.play(["drink_poor", "drink_good", "drink_perfect"][worst])
	await get_tree().create_timer(0.6).timeout
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
	return await _step_done


func _process(delta: float) -> void:
	if not visible:
		return
	_result_age += delta
	_punch = move_toward(_punch, 0.0, delta * 4.0)
	_shake = maxf(_shake - delta, 0.0)
	_update_sparkles(delta)
	if _ready_left > 0.0:
		_ready_left -= delta
	elif not _step.is_empty() and not _finished:
		_t += delta
		var can_input := _t > input_delay
		match _step:
			"pull":
				_value = pingpong(_t * pull_speed, 1.0)
				if can_input and Input.is_action_just_pressed("cafe_interact"):
					_finish(_score(_value))
			"steam":
				if can_input and Input.is_action_just_pressed("cafe_interact"):
					_holding = true
					Audio.start_loop("steam")
				if _holding:
					_value += steam_rate * delta
					if _value >= 1.0:
						_value = 1.0
						_finish(CafeData.Quality.POOR, "Scalded!")
					elif not Input.is_action_pressed("cafe_interact"):
						_finish(_score(_value))
			"drizzle":
				_update_drizzle(delta, can_input)
	queue_redraw()


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
	if absf(_balance) <= drizzle_zone:
		_green_time += delta
	if absf(_balance) <= drizzle_perfect:
		_perfect_time += delta
	if absf(_balance) >= 1.0:
		_balance = signf(_balance)
		_finish(CafeData.Quality.POOR, "Spilled!")
	elif _t >= drizzle_time:
		_finish(_drizzle_score())


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
	_punch = 1.0
	_flash_color = QUALITY_COLORS[quality]
	if not text.is_empty():
		# Scalded, or spilled.
		_shake = 0.25
		_flash_color = Color(1, 0.35, 0.3)
		Audio.play("scald" if _step == "steam" else "drink_poor")
		_show_result(text, _flash_color)
	elif _step == "drizzle":
		Audio.play("step_stop", 0.0, [0.8, 1.05, 1.35][quality])
		_show_result(CafeData.QUALITY_NAMES[quality], QUALITY_COLORS[quality])
		_burst(_marker_point(), quality, false)
	else:
		# The click rises in pitch the closer you were to the middle of the zone.
		var closeness := 1.0 - clampf(absf(_value - _zone_center) / (zone_half_width * 2.0), 0.0, 1.0)
		Audio.play("step_stop", 0.0, lerpf(0.8, 1.35, closeness))
		_show_result(CafeData.QUALITY_NAMES[quality], QUALITY_COLORS[quality])
		_burst(_gauge_center() + _needle_dir() * GAUGE_RADIUS * 0.8, quality, false)
	get_tree().create_timer(0.45).timeout.connect(_step_done.emit.bind(quality))


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
	draw_rect(panel, Color(0.17, 0.12, 0.1, 0.95))
	draw_rect(panel, Color(0.85, 0.68, 0.48), false, 1.0)
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
		_draw_finished_cup()
	if _step == "drizzle":
		_draw_balance(font)
	elif not _step.is_empty():
		_draw_gauge(font, "PRESSURE" if _step == "pull" else "TEMP")

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


## The gauge: a dial over the top, the zone in green (brightest at perfect),
## and the needle. A press punches it outward and flashes the zone.
func _draw_gauge(font: Font, label: String) -> void:
	var center := _gauge_center()
	if _shake > 0.0:
		center += Vector2(randf_range(-2, 2), randf_range(-1, 1))
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
	var zone := ZONE_COLOR.lerp(_flash_color, _punch * 0.8)
	draw_arc(center, r, zone_lo, zone_hi, 12, zone, 9.0 + 3.0 * _punch)
	draw_arc(center, r, PI + (_zone_center - perfect_half_width) * PI,
		PI + (_zone_center + perfect_half_width) * PI, 6, PERFECT_COLOR, 9.0 + 3.0 * _punch)
	# Tick marks.
	for i in 11:
		var a := PI + i / 10.0 * PI
		var d := Vector2(cos(a), sin(a))
		draw_line(center + d * (r - 8), center + d * (r - 4 if i % 5 else r - 12), Color(1, 1, 1, 0.35), 1.0)
	# Steaming fills the dial as the milk heats.
	if _step == "steam" and _value > 0.0:
		draw_arc(center, r - 14, PI, PI + _value * PI, 24, Color(1, 0.55, 0.35, 0.45), 4.0)
	var needle := Color.WHITE.lerp(_flash_color, _punch)
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
	if _shake > 0.0:
		bar.position += Vector2(randf_range(-2, 2), randf_range(-1, 1))
	var grow := 2.0 * _punch
	bar = bar.grow_individual(0, grow, 0, grow)
	var half := bar.size.x / 2.0
	var mid := bar.get_center().x
	draw_rect(bar.grow(3), Color(0.1, 0.07, 0.06))
	# The ends are where it spills: tinted red.
	draw_rect(bar, Color(0.55, 0.25, 0.2, 0.6))
	draw_rect(Rect2(mid - half * 0.8, bar.position.y, half * 1.6, bar.size.y), Color(1, 1, 1, 0.12))
	var zone := ZONE_COLOR.lerp(_flash_color, _punch * 0.8)
	draw_rect(Rect2(mid - half * drizzle_zone, bar.position.y, half * drizzle_zone * 2.0, bar.size.y), zone)
	draw_rect(Rect2(mid - half * drizzle_perfect, bar.position.y, half * drizzle_perfect * 2.0, bar.size.y), PERFECT_COLOR)
	# The marker: a post with a cap, leaning the way it's falling.
	var at := Vector2(mid + _balance * half, bar.get_center().y)
	var lean := clampf(_balance_vel * 0.25, -0.5, 0.5)
	# White in the green, reddening outside it.
	var off := clampf((absf(_balance) - drizzle_zone) / (1.0 - drizzle_zone) * 2.0, 0.0, 1.0)
	var marker := Color.WHITE.lerp(Color(1, 0.45, 0.4), off).lerp(_flash_color, _punch)
	var top := at + Vector2(sin(lean), -cos(lean)) * 14.0
	draw_line(at + Vector2(0, 7), top, marker, 2.0 + _punch)
	draw_circle(top, 3.5, marker)
	# Steering arrows at either end.
	for dir in [-1, 1]:
		var lit: bool = signf(_steer) == dir
		var tip := Vector2(mid + dir * (half + 16), bar.get_center().y)
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-dir * 8, -6), tip + Vector2(-dir * 8, 6)]),
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
		draw_set_transform(Vector2(cup.get_center().x, surface + 2), 0.0, Vector2(1, 0.3))
		draw_arc(Vector2.ZERO, 2.0 + pour * cup.size.x * 0.28, 0.0, PI * 1.6 * pour + 0.3, 16, honey, 2.0)
		draw_set_transform(Vector2.ZERO)


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


## The result word pops in with a little overshoot (and droops if it's Poor).
func _draw_result(font: Font) -> void:
	var t := _result_age
	var pop := lerpf(0.4, 1.25, t / 0.08) if t < 0.08 else lerpf(1.25, 1.0, minf((t - 0.08) / 0.14, 1.0))
	var droop := 0.0
	if _result_color == QUALITY_COLORS[CafeData.Quality.POOR]:
		droop = minf(t, 0.4) * 10.0
	var size_px := 15
	var width := font.get_string_size(_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := _panel().get_center().x if _final >= 0 else _gauge_center().x
	var at := Vector2(x, _panel().end.y - 8 + droop)
	draw_set_transform(at, 0.0, Vector2.ONE * pop)
	draw_string_outline(font, Vector2(-width / 2.0, 0), _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color(0.1, 0.07, 0.05))
	draw_string(font, Vector2(-width / 2.0, 0), _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, _result_color)
	draw_set_transform(Vector2.ZERO)
