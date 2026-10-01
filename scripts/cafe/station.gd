@tool
class_name Station
extends Interactable
## Base for cafe equipment. The interaction zone is a box of `size`, centred
## on this node and sitting on the floor. Add Prop3D children for the visuals.

@export var size := Vector3(0.8, 1.0, 0.8):
	set(value):
		size = value
		_sync()

var cafe: Cafe:
	get:
		return get_tree().get_first_node_in_group("cafe") as Cafe


func _ready() -> void:
	super()
	_sync()


func _sync() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("AutoShape") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "AutoShape"
		add_child(shape_node)
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = Vector3(0, size.y / 2.0, 0)
