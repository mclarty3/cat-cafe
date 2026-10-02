class_name ArmPose
extends SkeletonModifier3D
## Holds chosen bones in the pose they have at the start of an animation, over
## whatever else is playing. The barista's arms stay out front carrying things
## while the walk animation moves the legs. Added by AnimatedModel.hold_arms().

## Bone index -> rotation to hold it at.
var _rotations := {}


## Takes the pose of `bones` from the first frame of `animation` (none = let go).
func set_pose(animation: Animation, bones: PackedStringArray) -> void:
	_rotations.clear()
	var skeleton := get_skeleton()
	if animation == null or skeleton == null:
		return
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(animation.track_get_path(track).get_concatenated_subnames())
		if bone_name in bones:
			_rotations[skeleton.find_bone(bone_name)] = animation.rotation_track_interpolate(track, 0.0)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	for bone: int in _rotations:
		skeleton.set_bone_pose_rotation(bone, _rotations[bone])
