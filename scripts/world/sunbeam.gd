@tool
class_name Sunbeam
extends Area2D
## Exit point: curl up in the sunbeam to wake up, ending the run and keeping
## your loot. Only placed in specific rooms (see Dream Dungeon Structure).

@export var size := Vector2(128, 256):
	set(value):
		size = value
		_sync()

var _player_inside := false


func _ready() -> void:
	collision_layer = 32
	collision_mask = 2
	monitorable = false
	_sync()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		Game.request_wake_up()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		Game.set_prompt("Curl up and wake   [E / Up]")


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		Game.set_prompt("")


func _sync() -> void:
	Shapes.sync_rect(self, size)
	queue_redraw()


func _draw() -> void:
	var beam := PackedVector2Array([
		Vector2(size.x * 0.35, 0), Vector2(size.x * 0.75, 0),
		Vector2(size.x, size.y), Vector2(0, size.y),
	])
	draw_colored_polygon(beam, Color(1.0, 0.85, 0.45, 0.18))
	# Cat bed.
	var bed := Rect2(size.x / 2.0 - 18.0, size.y - 10.0, 36.0, 10.0)
	draw_rect(bed, Color("8a5a3c"))
	draw_rect(bed.grow_individual(-4, -3, -4, 0), Color("d9b38c"))
