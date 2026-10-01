class_name Barista
extends CharacterBody3D
## The player in the cafe. Walks relative to the camera (Up = up the screen),
## carries a tray of up to TRAY_SIZE items, and uses whichever Interactable in
## reach is closest.

const TRAY_SIZE := 3

@export var speed := 2.4
@export var acceleration := 18.0

## Set while a menu, minigame or conversation has the player's attention.
## The world keeps running.
var busy := false:
	set(value):
		busy = value
		if not value:
			_freed_on_frame = Engine.get_physics_frames()
## Each item: {"id": String, "quality": CafeData.Quality}.
var tray: Array[Dictionary] = []
var cafe: Cafe

var _focus: Interactable
var _freed_on_frame := -10

@onready var _reach: Area3D = $Reach
@onready var _model: AnimatedModel = $Model


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _camera_relative(input)
	var planar := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(direction.x, direction.z) * speed, acceleration * delta)
	velocity = Vector3(planar.x, 0.0, planar.y)
	move_and_slide()

	if planar.length() > 0.2:
		_model.face(velocity)
		_model.play("walk")
	else:
		_model.play("holding-both" if not tray.is_empty() else "idle")

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
	if cafe:
		cafe.hud.set_prompt(prompt)


func has_room() -> bool:
	return tray.size() < TRAY_SIZE


func add_item(id: String, quality: int) -> void:
	tray.append({"id": id, "quality": quality})


func count_item(id: String) -> int:
	return tray.filter(func(it: Dictionary) -> bool: return it["id"] == id).size()


## Removes and returns the best-quality item with this id, or {} if none.
func take_item(id: String) -> Dictionary:
	var best := -1
	for i in tray.size():
		if tray[i]["id"] == id and (best < 0 or tray[i]["quality"] > tray[best]["quality"]):
			best = i
	if best < 0:
		return {}
	var it := tray[best]
	tray.remove_at(best)
	return it


func clear_tray() -> void:
	tray.clear()


## Tray contents float above your head.
func _draw_overlay(canvas: OverlayAnchor) -> void:
	for i in tray.size():
		var x := (i - (tray.size() - 1) / 2.0) * 9.0
		canvas.draw_circle(Vector2(x, 0), 3.5, CafeData.item(tray[i]["id"])["color"])
		canvas.draw_arc(Vector2(x, 0), 3.5, 0.0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
