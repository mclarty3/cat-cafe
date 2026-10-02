class_name DrinkMinigame
extends Control
## The ~5-10 second drink-making minigame. Each drink is a list of steps:
##   pull:  a marker sweeps back and forth; press Interact inside the zone.
##   steam: hold Interact to heat the milk; release inside the zone (don't scald it).
## The drink's quality is its worst step.

signal _step_done(quality: int)

const PANEL_SIZE := Vector2(280, 96)
const BAR_WIDTH := 240.0

@export var pull_speed := 0.9
@export var steam_rate := 0.45
@export var zone_half_width := 0.12
@export var perfect_half_width := 0.035
## Ignores input briefly so the key that started the drink doesn't end a step.
@export var input_delay := 0.25

var _title := ""
var _step := ""
var _t := 0.0
var _value := 0.0
var _zone_center := 0.5
var _holding := false
var _finished := false
var _result_text := ""


func _ready() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(item_id: String) -> int:
	var data := CafeData.item(item_id)
	_title = data["name"]
	show()
	var worst := CafeData.Quality.PERFECT
	for step in data["steps"]:
		var quality: int = await _run_step(step)
		worst = mini(worst, quality)
	_step = ""
	_result_text = CafeData.QUALITY_NAMES[worst]
	Audio.play(["drink_poor", "drink_good", "drink_perfect"][worst])
	queue_redraw()
	await get_tree().create_timer(0.6).timeout
	hide()
	return worst


func _run_step(step: String) -> int:
	_step = step
	_t = 0.0
	_value = 0.0
	_holding = false
	_finished = false
	_result_text = ""
	_zone_center = randf_range(0.55, 0.85) if step == "pull" else randf_range(0.6, 0.8)
	if step == "pull":
		Audio.play("grinder")
		Audio.start_loop("espresso_pour")
	return await _step_done


func _process(delta: float) -> void:
	if not visible or _step.is_empty() or _finished:
		return
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
	queue_redraw()


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
	Audio.play("scald" if not text.is_empty() else "step_stop")
	_result_text = text if not text.is_empty() else CafeData.QUALITY_NAMES[quality]
	get_tree().create_timer(0.45).timeout.connect(_step_done.emit.bind(quality))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var panel := Rect2(size / 2.0 - PANEL_SIZE / 2.0, PANEL_SIZE)
	draw_rect(panel, Color(0.17, 0.12, 0.1, 0.95))
	draw_rect(panel, Color(0.85, 0.68, 0.48), false, 1.0)
	draw_string(font, panel.position + Vector2(12, 16), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.6))

	var hint := ""
	match _step:
		"pull":
			hint = "Pull the shot: press Interact in the zone"
		"steam":
			hint = "Steam the milk: hold Interact, release in the zone"
	draw_string(font, panel.position + Vector2(12, 32), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.8))

	var bar := Rect2(panel.position + Vector2((PANEL_SIZE.x - BAR_WIDTH) / 2.0, 44), Vector2(BAR_WIDTH, 14))
	if not _step.is_empty():
		draw_rect(bar, Color(0, 0, 0, 0.5))
		var zone := Rect2(bar.position.x + (_zone_center - zone_half_width) * BAR_WIDTH, bar.position.y,
			zone_half_width * 2.0 * BAR_WIDTH, bar.size.y)
		draw_rect(zone, Color(0.4, 0.75, 0.4, 0.7))
		var perfect := Rect2(bar.position.x + (_zone_center - perfect_half_width) * BAR_WIDTH, bar.position.y,
			perfect_half_width * 2.0 * BAR_WIDTH, bar.size.y)
		draw_rect(perfect, Color(0.7, 1, 0.6, 0.9))
		if _step == "steam":
			draw_rect(Rect2(bar.position, Vector2(_value * BAR_WIDTH, bar.size.y)), Color(1, 0.6, 0.4, 0.35))
		var x := bar.position.x + _value * BAR_WIDTH
		draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.end.y + 3), Color.WHITE, 2.0)

	if not _result_text.is_empty():
		var width := font.get_string_size(_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(panel.get_center().x - width / 2.0, panel.end.y - 12), _result_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.7))
