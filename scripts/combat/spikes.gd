@tool
class_name Spikes
extends Hitbox
## Placeholder hazard strip. Pogo off it with a downward air attack.

@export var size := Vector2(48, 8):
	set(value):
		size = value
		_sync()


func _init() -> void:
	respawn_player = true


func _ready() -> void:
	super()
	add_to_group("pogoable")
	_sync()


func damage_origin() -> Vector2:
	return global_position + size / 2.0


func _sync() -> void:
	Shapes.sync_rect(self, size)
	queue_redraw()


func _draw() -> void:
	var tooth := 8.0
	var x := 0.0
	while x < size.x:
		var w := minf(tooth, size.x - x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, size.y), Vector2(x + w / 2.0, 0), Vector2(x + w, size.y),
		]), Color("c9c3e6"))
		x += tooth
