@tool
class_name Room
extends Node2D
## Root script for every room scene. Defines the camera bounds and where the
## player appears when entering through a door (or at the start of a run).

const START_SPAWN := &"start"

@export var size := Vector2(640, 360):
	set(value):
		size = value
		queue_redraw()
@export var background := Color("1b1830"):
	set(value):
		background = value
		queue_redraw()


func get_bounds() -> Rect2:
	return Rect2(global_position, size)


func get_spawn_position(spawn_id: StringName) -> Vector2:
	if spawn_id == START_SPAWN:
		var start := get_node_or_null("PlayerStart") as Node2D
		if start:
			return start.global_position
	for node in find_children("*", "", true, false):
		if node is Door and node.door_id == spawn_id:
			return node.get_spawn_position()
	push_warning("Room %s has no spawn '%s'" % [name, spawn_id])
	return global_position + size / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.4), false, 2.0)
