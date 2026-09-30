@tool
class_name Block
extends StaticBody2D
## Placeholder solid geometry. Position is the top-left corner; resize with `size`.
## Turn on grid snapping (16px) in the 2D editor for quick layout.

@export var size := Vector2(64, 16):
	set(value):
		size = value
		_sync()
@export var color := Color("3b3558"):
	set(value):
		color = value
		queue_redraw()
## Can be jumped up through from below.
@export var one_way := false:
	set(value):
		one_way = value
		_sync()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_sync()


func _sync() -> void:
	Shapes.sync_rect(self, size, one_way)
	queue_redraw()


func _draw() -> void:
	if one_way:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, minf(size.y, 6.0))), color.lightened(0.15))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), color)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 2.0)), color.lightened(0.2))
