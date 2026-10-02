@tool
class_name AnimatedModel
extends Node3D
## Wraps an imported animated model (Kenney characters and pets): play
## animations by name and smoothly turn to face a direction.

## Animations that should repeat rather than play once.
const LOOPING := ["idle", "walk", "sprint", "run", "sit", "holding-both", "eat"]

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export var model_scale := 1.0:
	set(value):
		model_scale = value
		_rebuild()
@export var turn_speed := 14.0

var _instance: Node3D
var _player: AnimationPlayer
var _current := ""
var _target_yaw := 0.0


func _ready() -> void:
	_target_yaw = rotation.y
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _instance:
		remove_child(_instance)
		_instance.queue_free()
		_instance = null
	_player = null
	_current = ""
	if model == null:
		return
	_instance = model.instantiate()
	_instance.scale = Vector3.ONE * model_scale
	add_child(_instance)
	_player = _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player:
		for anim in LOOPING:
			if _player.has_animation(anim):
				_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	play("idle")


func play(anim: String, blend := 0.15) -> void:
	if anim == _current or _player == null or not _player.has_animation(anim):
		return
	_current = anim
	_player.play(anim, blend)


func set_playback_speed(scale: float) -> void:
	if _player:
		_player.speed_scale = scale


func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() > 0.0001:
		_target_yaw = atan2(direction.x, direction.z)


func face_yaw(yaw: float, instant := false) -> void:
	_target_yaw = yaw
	if instant:
		rotation.y = yaw


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-turn_speed * delta))
