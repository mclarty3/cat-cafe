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
var _freed_on_frame := -10

@onready var _reach: Area3D = $Reach
@onready var _model: AnimatedModel = $Model


func _ready() -> void:
	focus_marker.top_level = true
	add_child(focus_marker)


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
	else:
		_model.play("holding-both" if not hands.is_empty() else "idle")
		_model.set_playback_speed(1.0)

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
			if not area is Interactable:
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


## What you're carrying floats above your head.
func _draw_overlay(canvas: OverlayAnchor) -> void:
	for i in hands.size():
		var x := (i - (hands.size() - 1) / 2.0) * 9.0
		canvas.draw_circle(Vector2(x, 0), 3.5, CafeData.item(hands[i]["id"])["color"])
		canvas.draw_arc(Vector2(x, 0), 3.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
