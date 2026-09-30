@tool
class_name Station
extends Interactable
## Base for counter equipment. Position is the top-left corner; set `size`.

@export var size := Vector2(64, 32):
	set(value):
		size = value
		Shapes.sync_rect(self, size)
		queue_redraw()
@export var title := "Station":
	set(value):
		title = value
		queue_redraw()
@export var color := Color(0.45, 0.45, 0.5):
	set(value):
		color = value
		queue_redraw()

var cafe: Cafe:
	get:
		return get_tree().get_first_node_in_group("cafe") as Cafe


func _ready() -> void:
	super()
	Shapes.sync_rect(self, size)


func focus_point() -> Vector2:
	return global_position + size / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, size), color.lightened(0.3), false, 1.0)
	draw_text_centered(title, Vector2(size.x / 2.0, size.y / 2.0 + 3.0))
