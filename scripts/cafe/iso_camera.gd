@tool
class_name IsoCamera
extends Camera3D
## Fixed orthographic camera at an isometric-style angle, aimed at `target`.

@export var target := Vector3.ZERO:
	set(value):
		target = value
		_apply()
## Degrees looking down. True isometric is about 35.26; 30 reads a bit flatter.
@export_range(10.0, 80.0) var pitch := 32.0:
	set(value):
		pitch = value
		_apply()
## Degrees around the vertical axis. 45 shows two walls equally.
@export_range(-180.0, 180.0) var yaw := 45.0:
	set(value):
		yaw = value
		_apply()
## Vertical extent of the view in world units (orthographic zoom).
@export var view_height := 6.5:
	set(value):
		view_height = value
		_apply()
@export var distance := 30.0:
	set(value):
		distance = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = view_height
	near = 0.1
	far = distance * 2.0
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0))
	# `target` is in the parent's space (the cafe root).
	transform = Transform3D(basis, target + basis.z * distance)
