@tool
class_name CafeCat
extends Interactable
## A resident cat. Wanders the floor and can be petted. The cafe can send it
## to the counter to start the "nudging a mug off the edge" event.

signal mug_event_finished(caught: bool)

enum State { IDLE, WALKING, TO_COUNTER, NUDGING }

@export var cat_name := "Mochi"
@export var color := Color(0.95, 0.75, 0.5)
@export var wander_area := Rect2(40, 110, 560, 200)
@export var walk_speed := 35.0
@export var dash_speed := 140.0
## Seconds you have to catch the mug.
@export var mug_time := 6.0

var state := State.IDLE

var _target := Vector2.ZERO
var _idle_timer := 1.0
var _mug_timer := 0.0
var _pet_cooldown := 0.0


func _ready() -> void:
	super()
	circle_shape(self, 10.0)


func start_mug_event(counter_spot: Vector2) -> void:
	state = State.TO_COUNTER
	_target = counter_spot


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pet_cooldown = maxf(_pet_cooldown - delta, 0.0)
	match state:
		State.IDLE:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_target = Vector2(
					randf_range(wander_area.position.x, wander_area.end.x),
					randf_range(wander_area.position.y, wander_area.end.y))
				state = State.WALKING
		State.WALKING:
			if _move_to(_target, walk_speed, delta):
				state = State.IDLE
				_idle_timer = randf_range(2.0, 6.0)
		State.TO_COUNTER:
			if _move_to(_target, dash_speed, delta):
				state = State.NUDGING
				_mug_timer = mug_time
		State.NUDGING:
			_mug_timer -= delta
			if _mug_timer <= 0.0:
				FloatText.spawn(get_parent(), global_position + Vector2(10, 0), "CRASH!", Color(1, 0.45, 0.4))
				_end_mug_event(false)
	queue_redraw()


func _move_to(target: Vector2, move_speed: float, delta: float) -> bool:
	global_position = global_position.move_toward(target, move_speed * delta)
	return global_position.distance_to(target) < 0.5


func _end_mug_event(caught: bool) -> void:
	state = State.WALKING
	_target = wander_area.get_center()
	mug_event_finished.emit(caught)


func get_prompt(_barista: Barista) -> String:
	match state:
		State.NUDGING:
			return "Catch the mug!"
		State.IDLE, State.WALKING:
			if _pet_cooldown <= 0.0:
				return "Pet %s" % cat_name
	return ""


func interact(_barista: Barista) -> void:
	if state == State.NUDGING:
		FloatText.spawn(get_parent(), global_position + Vector2(10, -8), "Nice catch!", Color(0.6, 1, 0.6))
		_end_mug_event(true)
	elif _pet_cooldown <= 0.0:
		_pet_cooldown = 3.0
		FloatText.spawn(get_parent(), global_position + Vector2(0, -12), "purr~", Color(1, 0.8, 0.9))


func _draw() -> void:
	var facing := -1.0 if _target.x < global_position.x else 1.0
	# Tail, body, head, ears.
	draw_line(Vector2(-facing * 6, 0), Vector2(-facing * 11, -6), color.darkened(0.2), 2.0)
	draw_circle(Vector2.ZERO, 6.0, color)
	draw_circle(Vector2(facing * 6, -3), 4.0, color)
	for ear in [-1.0, 1.0]:
		var base := Vector2(facing * 6 + ear * 2.5, -6)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-1.5, 0), base + Vector2(1.5, 0), base + Vector2(ear * 0.5, -3.5),
		]), color.darkened(0.15))
	draw_text_centered(cat_name, Vector2(0, 14), 7, Color(1, 1, 1, 0.7))

	if state == State.NUDGING:
		# The mug, creeping toward the edge.
		var creep := 1.0 - _mug_timer / mug_time
		draw_rect(Rect2(10 + creep * 4.0, -4, 6, 7), Color(0.9, 0.9, 0.95))
		draw_text_centered("!", Vector2(0, -12), 12, Color(1, 0.4, 0.4))
		draw_rect(Rect2(-12, 18, 24, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-12, 18, 24 * (_mug_timer / mug_time), 3), Color(1, 0.5, 0.4))
