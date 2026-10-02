@tool
class_name CafeCamera
extends Camera3D
## Perspective camera that looks at the cafe from the front of house and
## softly follows the barista: part room-centred, part player-centred, with a
## little look-ahead in the direction of movement. Eases in on a point of
## interest (a station, a customer) while a menu or chat is open.

## The room point the camera rests on when not following anyone.
@export var room_center := Vector3(3.5, 0.3, 3.1):
	set(value):
		room_center = value
		_snap()
## Degrees looking down.
@export_range(15.0, 85.0) var pitch := 48.0:
	set(value):
		pitch = value
		_snap()
## Degrees around the vertical axis. 0 looks straight at the back wall.
@export_range(-180.0, 180.0) var yaw := 0.0:
	set(value):
		yaw = value
		_snap()
## Distance from the look-at point. Paired with a narrow FOV (set on the node):
## pulling back with a narrower lens keeps the counter large while shrinking the
## nearby tables, so the whole floor fits on screen.
@export var distance := 10.0:
	set(value):
		distance = value
		_snap()

@export_group("Follow")
## The node to follow (the barista). Set by the cafe at runtime.
var follow_target: Node3D
## Side-to-side follow: 0 = stay on the room centre, 1 = keep the player centred.
@export_range(0.0, 1.0) var follow_amount := 0.4
## Front-to-back follow. Kept low so working the counter doesn't push the
## tables off the bottom of the screen.
@export_range(0.0, 1.0) var follow_depth := 0.15
## How far ahead of the player (in seconds of their velocity) to look.
@export var look_ahead := 0.25
## Higher = snappier tracking.
@export var smoothing := 4.0
## Keeps the look-at point inside the room (x/z min and max).
@export var bounds := Rect2(2.4, 1.6, 2.2, 2.0)

@export_group("Focus")
## While using a station or chatting, move this much closer...
@export_range(0.3, 1.0) var focus_zoom := 0.8
## ...and slide this far (0-1) from the usual view toward the point of interest.
@export_range(0.0, 1.0) var focus_pull := 0.5

var _look_at := Vector3.ZERO
var _distance := 0.0
var _focus_point: Variant = null


func _ready() -> void:
	_snap()


func focus(point: Vector3) -> void:
	_focus_point = point


func unfocus() -> void:
	_focus_point = null


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var goal := room_center
	if is_instance_valid(follow_target):
		var ahead := follow_target.global_position
		if follow_target is CharacterBody3D:
			ahead += (follow_target as CharacterBody3D).velocity * look_ahead
		goal = Vector3(
			lerpf(room_center.x, ahead.x, follow_amount), room_center.y,
			lerpf(room_center.z, ahead.z, follow_depth))
	var goal_distance := distance
	if _focus_point != null:
		var p: Vector3 = _focus_point
		goal = goal.lerp(Vector3(p.x, room_center.y, p.z), focus_pull)
		goal_distance = distance * focus_zoom
	goal.x = clampf(goal.x, bounds.position.x, bounds.end.x)
	goal.z = clampf(goal.z, bounds.position.y, bounds.end.y)

	var weight := 1.0 - exp(-smoothing * delta)
	_look_at = _look_at.lerp(goal, weight)
	_distance = lerpf(_distance, goal_distance, weight)
	_place()


func _snap() -> void:
	_look_at = room_center
	_distance = distance
	_place()


func _place() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0))
	# Positions are in the parent's space (the cafe root).
	transform = Transform3D(basis, _look_at + basis.z * _distance)
