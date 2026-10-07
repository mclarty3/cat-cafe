class_name ArmPose
extends SkeletonModifier3D
## Holds chosen bones in the pose they have at the start of an animation, over
## whatever else is playing. The barista's arms stay out front carrying things
## while the walk animation moves the legs. Added by AnimatedModel.hold_arms().
##
## A held arm can also be lifted further along the same swing (see set_lift()),
## e.g. to bring a cup up to the mouth.

## How far a full lift (1) swings a held arm past its held pose, in radians.
const LIFT_ANGLE := 0.9

## Bone index -> {"rest": Quaternion, "axis": Vector3, "angle": float}: the
## held pose as a swing from the bone's rest.
var _swings := {}
## Bone index -> lift amount (0..1).
var _lifts := {}


## Takes the pose of `bones` from the first frame of `animation` (none = let go).
func set_pose(animation: Animation, bones: PackedStringArray) -> void:
	_swings.clear()
	var skeleton := get_skeleton()
	if animation == null or skeleton == null:
		return
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(animation.track_get_path(track).get_concatenated_subnames())
		if bone_name in bones:
			var bone := skeleton.find_bone(bone_name)
			var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			var held := animation.rotation_track_interpolate(track, 0.0)
			var swing := rest.inverse() * held
			var axis := swing.get_axis() if swing.get_angle() > 0.001 else Vector3.RIGHT
			_swings[bone] = {"rest": rest, "axis": axis.normalized(), "angle": swing.get_angle()}


## Lifts a held arm further along its swing: 0 = the held pose, 1 = LIFT_ANGLE more.
func set_lift(bone_name: String, amount: float) -> void:
	var skeleton := get_skeleton()
	if skeleton:
		_lifts[skeleton.find_bone(bone_name)] = amount


func _process_modification() -> void:
	var skeleton := get_skeleton()
	for bone: int in _swings:
		var swing: Dictionary = _swings[bone]
		var angle: float = swing["angle"] + _lifts.get(bone, 0.0) * LIFT_ANGLE
		skeleton.set_bone_pose_rotation(bone, swing["rest"] * Quaternion(swing["axis"], angle))
