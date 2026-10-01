extends Control
## Prototype switchboard: jump into either vertical slice.

const DUNGEON_SCENE := "res://scenes/main.tscn"
const CAFE_SCENE := "res://scenes/cafe/cafe.tscn"


func _ready() -> void:
	Engine.time_scale = 1.0
	Game.transitioning = false
	%DungeonButton.pressed.connect(get_tree().change_scene_to_file.bind(DUNGEON_SCENE))
	%CafeButton.pressed.connect(get_tree().change_scene_to_file.bind(CAFE_SCENE))
	%QuitButton.pressed.connect(get_tree().quit)
	%CafeButton.grab_focus()
