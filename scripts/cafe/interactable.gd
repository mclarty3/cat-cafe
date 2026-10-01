@tool
class_name Interactable
extends Area3D
## Something the barista can use by standing near it and pressing Interact.
## Subclasses override get_prompt() (empty = nothing to do right now) and interact().


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	monitoring = false


func get_prompt(_barista: Barista) -> String:
	return ""


func interact(_barista: Barista) -> void:
	pass


## Where "closest interactable" is measured from.
func focus_point() -> Vector3:
	return global_position


static func sphere_shape(parent: CollisionObject3D, radius: float, offset := Vector3.ZERO) -> void:
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape_node.shape = sphere
	shape_node.position = offset
	parent.add_child(shape_node)
