@tool
class_name AnimatedModel
extends Node3D
## Wraps an imported animated model (Kenney characters and pets): play
## animations by name and smoothly turn to face a direction.

## Emitted after the skeleton is posed each frame: the moment to place things
## that follow the hands (see hand_position()).
signal posed

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
var _skeleton: Skeleton3D
var _arm_pose: ArmPose
## Bone name -> the fist's position in that bone's space.
var _fists := {}
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
	_skeleton = null
	_arm_pose = null
	_fists.clear()
	_current = ""
	if model == null:
		return
	_instance = model.instantiate()
	_instance.scale = Vector3.ONE * model_scale
	add_child(_instance)
	_player = _instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_skeleton.skeleton_updated.connect(posed.emit)
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


## Multiplies the model's colours (e.g. to vary one shared cat model).
func tint(color: Color) -> void:
	if _instance == null:
		return
	for mesh: MeshInstance3D in _instance.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i).duplicate() as BaseMaterial3D
			if material:
				material.albedo_color = color
				mesh.set_surface_override_material(i, material)


func set_playback_speed(scale: float) -> void:
	if _player:
		_player.speed_scale = scale


## Holds the arms in the first frame of `anim` (e.g. "holding-both") over
## whatever is playing, so you can walk while carrying. Only `bones` are held;
## an empty `anim` lets go.
func hold_arms(anim: String, bones: PackedStringArray = ["arm-left", "arm-right"]) -> void:
	if _skeleton == null:
		return
	if _arm_pose == null:
		_arm_pose = ArmPose.new()
		_skeleton.add_child(_arm_pose)
	var animation: Animation = null
	if _player and _player.has_animation(anim):
		animation = _player.get_animation(anim)
	_arm_pose.set_pose(animation, bones)


## Lifts an arm held by hold_arms() further up (0 = held, 1 = up to the face).
func lift_arm(bone: String, amount: float) -> void:
	if _arm_pose:
		_arm_pose.set_lift(bone, amount)


## Where the fist at the end of `bone` (an arm) is right now, in world space.
## Call it from `posed` to include held arms (see hold_arms()).
func hand_position(bone: String) -> Vector3:
	var index := _skeleton.find_bone(bone) if _skeleton else -1
	if index < 0:
		return global_position
	if not _fists.has(bone):
		_fists[bone] = _fist_offset(bone)
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(index) * _fists[bone]


## The fist, measured from the skinned mesh: the middle of the bone's vertices
## furthest from its joint, in the bone's own space. Works for any of the
## Kenney characters, whatever their arm length.
func _fist_offset(bone_name: String) -> Vector3:
	var bone := _skeleton.find_bone(bone_name)
	var points: Array[Vector3] = []
	for mesh_instance: MeshInstance3D in _instance.find_children("*", "MeshInstance3D", true, false):
		var skin := mesh_instance.skin
		if skin == null:
			continue
		for bind in skin.get_bind_count():
			if skin.get_bind_bone(bind) != bone and skin.get_bind_name(bind) != bone_name:
				continue
			for surface in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var per_vertex := bones.size() / vertices.size()
				for v in vertices.size():
					for k in per_vertex:
						if bones[v * per_vertex + k] == bind and weights[v * per_vertex + k] >= 0.5:
							points.append(skin.get_bind_pose(bind) * vertices[v])
	if points.is_empty():
		return Vector3.ZERO
	var reach := 0.0
	for point in points:
		reach = maxf(reach, point.length())
	var sum := Vector3.ZERO
	var count := 0
	for point in points:
		if point.length() > reach * 0.8:
			sum += point
			count += 1
	return sum / count


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
