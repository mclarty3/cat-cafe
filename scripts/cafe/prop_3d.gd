@tool
class_name Prop3D
extends Node3D
## Places a model (e.g. a Kenney .glb) with optional auto-sized collision.
## Kenney furniture has its origin at a corner; with `center` on, the model's
## footprint is centred on this node so rotating it behaves.

enum Collision { NONE, BOX, CYLINDER }

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export var model_scale := 1.0:
	set(value):
		model_scale = value
		_rebuild()
@export var center := true:
	set(value):
		center = value
		_rebuild()
@export var collision := Collision.NONE:
	set(value):
		collision = value
		_rebuild()
## Grows (or shrinks) the collision shape on each side.
@export var collision_margin := 0.0:
	set(value):
		collision_margin = value
		_rebuild()

## The model's bounds in this node's local space, after centring.
var bounds := AABB()

var _instance: Node3D
var _body: StaticBody3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	# Children made here have no owner, so they're rebuilt on load and never saved.
	for node in [_instance, _body]:
		if node:
			remove_child(node)
			node.queue_free()
	_instance = null
	_body = null
	if model == null:
		return

	_instance = model.instantiate()
	_instance.scale = Vector3.ONE * model_scale
	add_child(_instance)

	var box := _measure()
	var offset := Vector3(0, -box.position.y, 0)
	if center:
		offset.x = -box.get_center().x
		offset.z = -box.get_center().z
	_instance.position = offset
	bounds = AABB(box.position + offset, box.size)

	if collision != Collision.NONE:
		_add_collision()


func _measure() -> AABB:
	var inverse := global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _instance.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = inverse * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _add_collision() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var size := bounds.size + Vector3(collision_margin, 0, collision_margin) * 2.0
	if collision == Collision.BOX:
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
	else:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(size.x, size.z) / 2.0
		shape.height = size.y
		shape_node.shape = shape
	shape_node.position = bounds.get_center()
	_body.add_child(shape_node)
	add_child(_body)
