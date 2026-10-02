class_name Barista
extends CharacterBody3D
## The player in the cafe. Walks relative to the camera (Up = up the screen),
## carries a couple of items from the stations to the pass, and uses whichever
## Interactable in reach is closest.

@export var speed := 2.8
@export var acceleration := 20.0
## Braking (and turning against your motion) is quicker than speeding up,
## so stops feel crisp rather than slidey.
@export var deceleration := 32.0
## Walk animation playback speed at full speed (scales down as you slow).
@export var walk_anim_speed := 1.25
## How many items you can carry at once.
@export var carry_capacity := 2
## Where a carried item sits relative to the middle of the fist: this far in
## front of it (so the fist doesn't hide it) and its base this far below.
@export var grip_forward := 0.05
@export var grip_depth := 0.03
## Carried items are shown this much bigger than on the pass, so they read from
## the game camera.
@export var held_scale := 1.3

## Set while a menu, minigame or conversation has the player's attention.
## The world keeps running.
var busy := false:
	set(value):
		busy = value
		if not value:
			_freed_on_frame = Engine.get_physics_frames()
## What you're carrying. Each item: {"id": String, "quality": CafeData.Quality}.
var hands: Array[Dictionary] = []
var cafe: Cafe

## Bobbing arrow over whatever Interact will use. The cafe pins it to the overlay.
var focus_marker := FocusMarker.new()

var _focus: Interactable
## The models in your hands, matching `hands`, and the item ids they show.
var _held: Array[ItemModel] = []
var _held_ids: Array[String] = []
var _freed_on_frame := -10
var _step_timer := 0.0

@onready var _reach: Area3D = $Reach
@onready var _model: AnimatedModel = $Model


func _ready() -> void:
	focus_marker.top_level = true
	add_child(focus_marker)
	_model.posed.connect(_place_held)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _camera_relative(input)
	var wanted := Vector2(direction.x, direction.z) * speed
	var planar := Vector2(velocity.x, velocity.z)
	var rate := acceleration if wanted.dot(planar) > 0.0 or planar == Vector2.ZERO else deceleration
	if wanted == Vector2.ZERO:
		rate = deceleration
	planar = planar.move_toward(wanted, rate * delta)
	velocity = Vector3(planar.x, 0.0, planar.y)
	move_and_slide()

	var pace := planar.length() / speed
	if pace > 0.08:
		# Face where you're trying to go, so turns read immediately.
		_model.face(direction if direction != Vector3.ZERO else velocity)
		_model.play("walk")
		_model.set_playback_speed(lerpf(0.6, walk_anim_speed, pace))
		_step_timer -= delta
		if _step_timer <= 0.0:
			Audio.play("footstep", lerpf(-6.0, 0.0, pace))
			_step_timer = 0.3 / maxf(pace, 0.6)
	else:
		_step_timer = 0.0
		_model.play("idle")
		_model.set_playback_speed(1.0)

	_update_held()
	_update_focus()
	# Skip a couple of frames after a menu closes, so the key that closed it
	# doesn't also use whatever is in front of you.
	var settled := Engine.get_physics_frames() > _freed_on_frame + 2
	if not busy and settled and _focus and Input.is_action_just_pressed("cafe_interact"):
		_model.face(_focus.focus_point() - global_position)
		_focus.interact(self)


func _camera_relative(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null or input == Vector2.ZERO:
		return Vector3.ZERO
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).limit_length(1.0)


func _update_focus() -> void:
	_focus = null
	var prompt := ""
	if not busy:
		var best_distance := INF
		for area in _reach.get_overlapping_areas():
			if not area is Interactable or (cafe and not cafe.can_use(area)):
				continue
			var text: String = area.get_prompt(self)
			var offset: Vector3 = area.focus_point() - global_position
			var distance := Vector2(offset.x, offset.z).length()
			if not text.is_empty() and distance < best_distance:
				best_distance = distance
				_focus = area
				prompt = text
	focus_marker.active = _focus != null
	if _focus:
		focus_marker.global_position = _focus.marker_point()
	if cafe:
		cafe.hud.set_prompt(prompt)


func has_room() -> bool:
	return hands.size() < carry_capacity


func add_item(id: String, quality: int) -> void:
	hands.append({"id": id, "quality": quality})


func count_item(id: String) -> int:
	return hands.filter(func(it: Dictionary) -> bool: return it["id"] == id).size()


func clear_hands() -> void:
	hands.clear()


## Swaps the models in your hands when what you're carrying changes. The first
## item goes in the right hand, the second in the left, and the arms that hold
## something stay out front (walking or not).
func _update_held() -> void:
	var ids: Array[String] = []
	for it in hands:
		ids.append(it["id"])
	if ids == _held_ids:
		return
	_held_ids = ids
	for item in _held:
		item.queue_free()
	_held.clear()
	for id in ids:
		var item := ItemModel.create(id, held_scale)
		item.top_level = true
		add_child(item)
		_held.append(item)
	match ids.size():
		0:
			_model.hold_arms("")
		1:
			_model.hold_arms("holding-right", ["arm-right"])
		_:
			_model.hold_arms("holding-both")


## Puts each carried model in its fist, upright and facing where you face.
## Runs when the model is posed: the held arms are a skeleton modifier, so
## they're only out front during the skeleton's update (read the pose any other
## time and the arms are down).
func _place_held() -> void:
	for i in _held.size():
		var fist := _model.hand_position("arm-right" if i % 2 == 0 else "arm-left")
		# Past two items, stack them up in the hands.
		var stack := Vector3.UP * 0.12 * (i / 2)
		var facing := Basis(Vector3.UP, _model.global_rotation.y)
		_held[i].global_transform = Transform3D(facing,
			fist + facing.z * grip_forward + Vector3.DOWN * grip_depth + stack)


## What you're carrying floats above your head.
func _draw_overlay(canvas: OverlayAnchor) -> void:
	for i in hands.size():
		var x := (i - (hands.size() - 1) / 2.0) * 9.0
		canvas.draw_circle(Vector2(x, 0), 3.5, CafeData.item(hands[i]["id"])["color"])
		canvas.draw_arc(Vector2(x, 0), 3.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
