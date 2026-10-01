@tool
class_name Interactable
extends Area2D
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
func focus_point() -> Vector2:
	return global_position


static func circle_shape(parent: CollisionObject2D, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	parent.add_child(shape_node)


## Draws text horizontally centred on `center.x`, with its baseline at `center.y`.
func draw_text_centered(text: String, center: Vector2, font_size := 8, color := Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
