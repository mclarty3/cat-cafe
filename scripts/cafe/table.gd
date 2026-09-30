@tool
class_name CafeTable
extends StaticBody2D
## A round table the barista walks around. Put Seat nodes next to it.

@export var radius := 18.0:
	set(value):
		radius = value
		_sync()
@export var color := Color(0.62, 0.44, 0.3):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_sync()


func _sync() -> void:
	var shape_node := get_node_or_null("AutoShape") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "AutoShape"
		add_child(shape_node)
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color.lightened(0.25), 1.5)
