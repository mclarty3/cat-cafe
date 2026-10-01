class_name GameCamera
extends Camera2D
## Follows the player, clamped to the current room's bounds, with screen shake.

@export var shake_decay := 30.0

var _shake := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0


func set_bounds(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


## Jump straight to the target (after a room change) instead of panning.
func snap() -> void:
	position_smoothing_enabled = false
	force_update_scroll()
	position_smoothing_enabled = true
	reset_smoothing()


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, shake_decay * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
