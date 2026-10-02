@tool
class_name CafeCat
extends Interactable
## A resident cat. Wanders the floor and can be petted. Spawned and configured
## from CafeData.CATS by the cafe. A cat with `mischief` can be sent onto a table
## to start the "nudging a mug off the edge" event, which you have to leave the
## counter to deal with.

signal mug_event_finished(caught: bool)

enum State { IDLE, WALKING, TO_MUG, NUDGING }

## A wandering cat that can't get anywhere for this long gives up and goes elsewhere.
const GIVE_UP_TIME := 1.5

@export var cat_name := "Cat"
## Floor area (x, z) the cat wanders in.
@export var wander_area := Rect2(1.6, 2.4, 5.0, 3.2)
@export var walk_speed := 0.6
## Random pause between wanders, in seconds (min, max).
@export var idle_time := Vector2(2, 6)
@export var dash_speed := 2.5
## Seconds you have to catch the mug.
@export var mug_time := 6.0
## How far the mug slides towards the edge before it falls.
@export var mug_slide := 0.25
## Seconds a hop on or off a table takes.
@export var hop_time := 0.35

var state := State.IDLE
var cat_id := ""
## Pitch of this cat's meows and purrs, and the chance petting gets a meow.
var voice_pitch := 1.0
var meowy := 0.5
var _last_sound := ""

## Floor route to the current destination (navmesh points).
var _path: Array[Vector3] = []
var _velocity := Vector3.ZERO
## How long we've been walking without getting anywhere.
var _stalled := 0.0
## Where the mug sits on the table, and the floor spot we hop up from.
var _table_top := Vector3.ZERO
var _table_edge := Vector3.ZERO
var _hopping := false
var _idle_timer := 1.0
var _mug_timer := 0.0
var _pet_cooldown := 0.0
var _gesture_timer := 0.0
var _tink_timer := 0.0
var _cafe: Cafe

@onready var _model: AnimatedModel = $Model
@onready var _mug: Node3D = $Mug


func _ready() -> void:
	super()
	sphere_shape(self, 0.3, Vector3(0, 0.15, 0))
	if Engine.is_editor_hint():
		return
	_mug.hide()
	_cafe = get_tree().get_first_node_in_group("cafe") as Cafe
	if _cafe:
		OverlayAnchor.attach(self, _cafe.overlay, 0.45)


func configure(id: String, data: Dictionary) -> void:
	cat_id = id
	cat_name = data["name"]
	walk_speed = data["walk_speed"]
	idle_time = data["idle"]
	voice_pitch = data["voice"]["pitch"]
	meowy = data["voice"]["meowy"]
	_idle_timer = randf_range(0.5, idle_time.y)
	_model.tint(data["tint"])


func start_mug_event(table_top: Vector3) -> void:
	state = State.TO_MUG
	_table_top = table_top
	# The people's map stops at the table's rim, so that's where we hop up from
	# (not from underneath).
	_table_edge = _cafe.floor_point(table_top)
	_path = _cafe.find_path(global_position, _table_edge, _cafe.cat_map)


## On the floor (not up on a table or hopping), so others steer around us.
func on_floor() -> bool:
	return not _hopping and state != State.NUDGING


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pet_cooldown = maxf(_pet_cooldown - delta, 0.0)
	_gesture_timer = maxf(_gesture_timer - delta, 0.0)
	if _hopping:
		return
	match state:
		State.IDLE:
			if _gesture_timer <= 0.0:
				_model.play("idle")
			_idle_timer -= delta
			# Someone's standing on us: get out of the way.
			if _cafe.crowding(self):
				_idle_timer = 0.0
			if _idle_timer <= 0.0:
				_wander_to(_cafe.random_floor_point(wander_area, _cafe.cat_map))
		State.WALKING:
			_model.play("walk")
			var was := global_position
			if _follow_path(walk_speed, delta):
				state = State.IDLE
				_idle_timer = randf_range(idle_time.x, idle_time.y)
			elif _gave_up(was, delta):
				# Hemmed in (another cat in a narrow gap, say): sit a moment, then
				# wander somewhere else.
				_path.clear()
				state = State.IDLE
				_idle_timer = randf_range(0.5, 1.5)
		State.TO_MUG:
			_model.play("run")
			if _follow_path(dash_speed, delta):
				_model.face(_table_top - global_position)
				await _hop(_table_top)
				state = State.NUDGING
				_mug_timer = mug_time
				_mug.position = Vector3(0, 0, 0.18)
				_mug.show()
				_model.face(Vector3.BACK)
		State.NUDGING:
			_model.play("idle")
			_mug_timer -= delta
			_tink_timer -= delta
			if _tink_timer <= 0.0:
				Audio.play("mug_tink")
				# Nudges come faster as the mug nears the edge.
				_tink_timer = lerpf(1.2, 0.35, 1.0 - _mug_timer / mug_time)
			_mug.position.z = 0.18 + mug_slide * (1.0 - _mug_timer / mug_time)
			if _mug_timer <= 0.0:
				_cafe.float_text(global_position + Vector3.UP * 0.5, "CRASH!", Color(1, 0.45, 0.4))
				_end_mug_event(false)


## A meow or a purr when petted, in this cat's voice, never the same kind twice in a row.
func _vocalise() -> void:
	var options := ["cat_meow", "cat_mew_purr"] if randf() < meowy else ["cat_purr", "purr"]
	options.erase(_last_sound)
	_last_sound = options.pick_random()
	Audio.play(_last_sound, 0.0, voice_pitch)


## How we're moving right now (zero when standing), for others' avoidance.
func walk_velocity() -> Vector3:
	return _velocity if not _path.is_empty() else Vector3.ZERO


func _wander_to(target: Vector3) -> void:
	_path = _cafe.find_path(global_position, target, _cafe.cat_map)
	state = State.WALKING


## Walks the floor route, sidestepping people and other cats. True once arrived.
func _follow_path(move_speed: float, delta: float) -> bool:
	if not _path.is_empty():
		_velocity = _cafe.step_along(self, _path, _velocity, move_speed, delta)
		_model.face(_velocity)
	return _path.is_empty()


## True once we've crept along at under a fifth of our pace for a while.
func _gave_up(was: Vector3, delta: float) -> bool:
	var moved := Vector2(global_position.x - was.x, global_position.z - was.z).length()
	_stalled = _stalled + delta if moved < walk_speed * delta * 0.2 else 0.0
	if _stalled < GIVE_UP_TIME:
		return false
	_stalled = 0.0
	return true


## A little arcing jump onto or off a table.
func _hop(to: Vector3) -> void:
	_hopping = true
	_model.play("jump")
	var from := global_position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.3, 0.0, 1.0, hop_time)
	await tween.finished
	_hopping = false


func _end_mug_event(caught: bool) -> void:
	_mug.hide()
	state = State.WALKING
	_path.clear()
	mug_event_finished.emit(caught)
	_model.face(_table_edge - global_position)
	await _hop(_table_edge)
	var center := wander_area.get_center()
	_wander_to(_cafe.floor_point(Vector3(center.x, 0.0, center.y), _cafe.cat_map))


func marker_point() -> Vector3:
	return global_position + Vector3.UP * 0.7


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
		_cafe.float_text(global_position + Vector3.UP * 0.5, "Nice catch!", Color(0.6, 1, 0.6))
		_end_mug_event(true)
	elif _pet_cooldown <= 0.0:
		_pet_cooldown = 3.0
		state = State.IDLE
		_idle_timer = 2.0
		_gesture_timer = 1.2
		_model.play("gesture-positive")
		_vocalise()
		_cafe.float_text(global_position + Vector3.UP * 0.5, "purr~", Color(1, 0.8, 0.9))


func _draw_overlay(canvas: OverlayAnchor) -> void:
	if state == State.NUDGING:
		canvas.text_centered("!", Vector2(0, -2), 14, Color(1, 0.4, 0.4), 3)
		canvas.meter(Rect2(-12, 4, 24, 3), _mug_timer / mug_time, Color(1, 0.5, 0.4))
