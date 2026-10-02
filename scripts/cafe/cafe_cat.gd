@tool
class_name CafeCat
extends Interactable
## A resident cat. Wanders the floor and can be petted. Spawned and configured
## from CafeData.CATS by the cafe. During service a CatEvent can take a cat over
## (knocking a mug off a table, a fight, climbing the curtains, stealing a
## croissant) and drive it with the actions below: move_to(), go_to(), hop(),
## carry(), and an event prompt, mark and meter.

signal arrived

enum State { IDLE, WALKING, EVENT }

## A wandering cat that can't get anywhere for this long gives up and goes elsewhere.
const GIVE_UP_TIME := 1.5
## Where something carried in the mouth sits, in the model's space (scaled with it).
const MOUTH := Vector3(0, 0.13, 0.2)

@export var cat_name := "Cat"
## Floor area (x, z) the cat wanders in.
@export var wander_area := Rect2(1.6, 2.4, 5.0, 3.2)
@export var walk_speed := 0.6
## Random pause between wanders, in seconds (min, max).
@export var idle_time := Vector2(2, 6)
@export var dash_speed := 2.5
## Seconds a hop on or off a table takes.
@export var hop_time := 0.35

var state := State.IDLE
var cat_id := ""
## Event ids from CafeData.CATS `mischief`: what this cat gets up to.
var mischief: Array = []
## Pitch of this cat's meows and purrs, and the chance petting gets a meow.
var voice_pitch := 1.0
var meowy := 0.5

## Set while a CatEvent is driving this cat.
var event: CatEvent
## Animation to hold while an event has us standing still.
var event_pose := "idle"
## Drawn over the cat during an event: a mark ("!") and a 0..1 meter (hidden below 0).
var event_mark := ""
var event_meter := -1.0
var event_meter_color := Color(1, 0.5, 0.4)

## The mug from the mug event (shown only during it).
var mug: Node3D:
	get:
		return $Mug

var _last_sound := ""
## Floor route to the current destination (navmesh points).
var _path: Array[Vector3] = []
var _velocity := Vector3.ZERO
var _running := false
## How long we've been walking without getting anywhere.
var _stalled := 0.0
var _hopping := false
var _idle_timer := 1.0
var _pet_cooldown := 0.0
var _gesture_timer := 0.0
var _event_prompt := ""
var _event_action := Callable()
var _carried: ItemModel
var _cafe: Cafe

@onready var _model: AnimatedModel = $Model


func _ready() -> void:
	super()
	sphere_shape(self, 0.3, Vector3(0, 0.15, 0))
	if Engine.is_editor_hint():
		return
	mug.hide()
	_cafe = get_tree().get_first_node_in_group("cafe") as Cafe
	if _cafe:
		OverlayAnchor.attach(self, _cafe.overlay, 0.45)


func configure(id: String, data: Dictionary) -> void:
	cat_id = id
	cat_name = data["name"]
	walk_speed = data["walk_speed"]
	idle_time = data["idle"]
	mischief = data.get("mischief", [])
	voice_pitch = data["voice"]["pitch"]
	meowy = data["voice"]["meowy"]
	_idle_timer = randf_range(0.5, idle_time.y)
	_model.tint(data["tint"])


## On the floor (not up on a table or a curtain, or mid-hop), so others steer around us.
func on_floor() -> bool:
	return not _hopping and global_position.y < 0.05


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
		State.EVENT:
			if _path.is_empty():
				_model.play(event_pose)
				return
			_model.play("run" if _running else "walk")
			var was := global_position
			var destination := _path[-1]
			if _follow_path(dash_speed if _running else walk_speed, delta):
				arrived.emit()
			elif _gave_up(was, delta):
				# An event needs us there: find another way rather than give up.
				_path = _cafe.find_path(global_position, destination, _cafe.cat_map)


# --- Actions for events ----------------------------------------------------------

## An event takes this cat over (it stops wandering until release()).
func claim(by: CatEvent) -> void:
	event = by
	state = State.EVENT
	event_pose = "idle"
	_path.clear()


## Hands the cat back to wandering, after a short pause.
func release() -> void:
	event = null
	clear_event_action()
	event_mark = ""
	event_meter = -1.0
	drop_carried()
	_model.rotation.x = 0.0
	_path.clear()
	state = State.IDLE
	_idle_timer = randf_range(0.5, 1.5)


## Starts walking (or running) to `target` on the cats' floor map. Doesn't wait.
func move_to(target: Vector3, running := false) -> void:
	_running = running
	_path = _cafe.find_path(global_position, target, _cafe.cat_map)


## Walks (or runs) to `target` and waits until we're there.
func go_to(target: Vector3, running := false) -> void:
	move_to(target, running)
	if not _path.is_empty():
		await arrived


func is_moving() -> bool:
	return not _path.is_empty()


func face(direction: Vector3) -> void:
	_model.face(direction)


## Tilts the model nose-up (climbing) or back level (0).
func pitch(angle: float) -> void:
	_model.rotation.x = angle


func play(anim: String) -> void:
	_model.play(anim)


## Shows a menu item held in the mouth (none = "").
func carry(item_id: String) -> void:
	drop_carried()
	if item_id.is_empty():
		return
	_carried = ItemModel.create(item_id)
	_carried.position = MOUTH
	_model.add_child(_carried)


func drop_carried() -> void:
	if _carried:
		_carried.queue_free()
		_carried = null


## While set, Interact on this cat shows `prompt` and calls `action`.
func set_event_action(prompt: String, action: Callable) -> void:
	_event_prompt = prompt
	_event_action = action


func clear_event_action() -> void:
	_event_prompt = ""
	_event_action = Callable()


## A little arcing jump onto or off something.
func hop(to: Vector3) -> void:
	_hopping = true
	_model.play("jump")
	var from := global_position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.3, 0.0, 1.0, hop_time)
	await tween.finished
	_hopping = false


## A meow in this cat's voice (events use it to get your attention).
func meow() -> void:
	Audio.play("cat_meow", 0.0, voice_pitch)


# --- Wandering --------------------------------------------------------------------

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


# --- Interaction ------------------------------------------------------------------

func marker_point() -> Vector3:
	return global_position + Vector3.UP * 0.7


func get_prompt(_barista: Barista) -> String:
	if state == State.EVENT:
		return _event_prompt
	if _pet_cooldown <= 0.0:
		return "Pet %s" % cat_name
	return ""


func interact(barista: Barista) -> void:
	if state == State.EVENT:
		if _event_action.is_valid():
			_event_action.call()
		return
	if get_prompt(barista).is_empty():
		return
	_pet_cooldown = 3.0
	state = State.IDLE
	_idle_timer = 2.0
	_gesture_timer = 1.2
	_model.play("gesture-positive")
	_vocalise()
	_cafe.float_text(global_position + Vector3.UP * 0.5, "purr~", Color(1, 0.8, 0.9))


## Nobody pets a cat for a few seconds after this (a sulk, say).
func cool_off(seconds: float) -> void:
	_pet_cooldown = seconds


func _draw_overlay(canvas: OverlayAnchor) -> void:
	if not event_mark.is_empty():
		canvas.text_centered(event_mark, Vector2(0, -2), 14, Color(1, 0.4, 0.4), 3)
	if event_meter >= 0.0:
		canvas.meter(Rect2(-12, 4, 24, 3), event_meter, event_meter_color)
