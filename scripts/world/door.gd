@tool
class_name Door
extends Area2D
## Walk into it to move to another room. You arrive at the door in the target
## room whose `door_id` matches `target_door`.

@export var door_id: StringName = &"left"
@export_file("*.tscn") var target_room := ""
@export var target_door: StringName = &"right"
@export var size := Vector2(16, 64):
	set(value):
		size = value
		_sync()
## Where an arriving player is placed, relative to this door's bottom-centre.
## Point it into the room so they don't immediately walk back out.
@export var spawn_offset := Vector2(32, 0):
	set(value):
		spawn_offset = value
		queue_redraw()


func _ready() -> void:
	collision_layer = 32
	collision_mask = 2
	monitorable = false
	_sync()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func get_spawn_position() -> Vector2:
	return global_position + Vector2(size.x / 2.0, size.y) + spawn_offset


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if target_room.is_empty():
			push_warning("Door '%s' has no target_room" % door_id)
			return
		Game.request_room_change(target_room, target_door)


func _sync() -> void:
	Shapes.sync_rect(self, size)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.45, 0.95, 0.3))
	if Engine.is_editor_hint():
		draw_circle(Vector2(size.x / 2.0, size.y) + spawn_offset, 3.0, Color(0.55, 1.0, 0.55))
