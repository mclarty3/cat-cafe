extends Node2D
## Owns the things that persist across rooms (player, camera, HUD) and swaps
## room scenes in and out. Also runs the run lifecycle: start, death, waking up.

@export_file("*.tscn") var start_room := "res://scenes/rooms/room_start.tscn"

var _room: Room

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player
@onready var _camera: GameCamera = $Player/Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	Game.room_change_requested.connect(_on_room_change_requested)
	Game.wake_up_requested.connect(_on_wake_up_requested)
	Game.camera_shake_requested.connect(_camera.shake)
	_player.health_changed.connect(_hud.set_health)
	_player.died.connect(_on_player_died)
	_start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not Game.transitioning:
		_start_run()


func _start_run() -> void:
	Game.transitioning = true
	_player.frozen = true
	await _hud.fade_out()
	_player.reset()
	await _load_room(start_room, Room.START_SPAWN)
	_hud.hide_message()
	await _hud.fade_in()
	_player.frozen = false
	Game.transitioning = false


func _load_room(path: String, spawn_id: StringName) -> void:
	if _room:
		_room_holder.remove_child(_room)
		_room.queue_free()
	_room = (load(path) as PackedScene).instantiate() as Room
	_room_holder.add_child(_room)
	_player.place_at(_room.get_spawn_position(spawn_id))
	_camera.set_bounds(_room.get_bounds())
	Game.set_prompt("")
	await get_tree().physics_frame
	_camera.snap()


func _on_room_change_requested(room_path: String, door_id: StringName) -> void:
	Game.transitioning = true
	_player.frozen = true
	await _hud.fade_out(0.15)
	await _load_room(room_path, door_id)
	await _hud.fade_in(0.15)
	_player.frozen = false
	Game.transitioning = false


func _on_player_died() -> void:
	Game.transitioning = true
	_hud.show_message("The dream fades...")
	await get_tree().create_timer(1.5).timeout
	_start_run()


func _on_wake_up_requested() -> void:
	Game.transitioning = true
	_player.frozen = true
	await _hud.fade_out(0.8)
	_hud.show_message("You curl up in the warm sunbeam...\nand wake up back at the cafe.\n\n(The cafe doesn't exist yet. Starting a new run.)")
	await get_tree().create_timer(2.5).timeout
	_start_run()
