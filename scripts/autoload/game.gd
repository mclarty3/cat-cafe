extends Node
## Global hub for run-level events. Gameplay nodes call into this instead of
## reaching for the main scene directly, so rooms stay self-contained.

signal room_change_requested(room_path: String, door_id: StringName)
signal wake_up_requested
signal prompt_changed(text: String)
signal camera_shake_requested(strength: float)

## True while a fade / room swap / run restart is in progress.
var transitioning := false

var _hitstop_id := 0


func request_room_change(room_path: String, door_id: StringName) -> void:
	if transitioning:
		return
	room_change_requested.emit(room_path, door_id)


func request_wake_up() -> void:
	if transitioning:
		return
	wake_up_requested.emit()


func set_prompt(text: String) -> void:
	prompt_changed.emit(text)


func shake(strength: float) -> void:
	camera_shake_requested.emit(strength)


## Briefly slows time to sell the weight of a hit.
func hitstop(duration: float, time_scale := 0.05) -> void:
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0
