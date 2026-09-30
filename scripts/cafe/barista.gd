class_name Barista
extends CharacterBody2D
## Top-down cafe player. Walks around, carries a tray of up to TRAY_SIZE items,
## and uses whichever Interactable in reach is closest.

const TRAY_SIZE := 3

@export var speed := 110.0
@export var acceleration := 1400.0

## Set while a menu, minigame or conversation has the player's attention.
## The world keeps running.
var busy := false:
	set(value):
		busy = value
		if not value:
			_freed_on_frame = Engine.get_physics_frames()
## Each item: {"id": String, "quality": CafeData.Quality}.
var tray: Array[Dictionary] = []
var cafe: Cafe

var _focus: Interactable
var _freed_on_frame := -10

@onready var _reach: Area2D = $Reach


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.move_toward(input * speed, acceleration * delta)
	move_and_slide()

	_update_focus()
	# Skip a couple of frames after a menu closes, so the key that closed it
	# doesn't also use whatever is in front of you.
	var settled := Engine.get_physics_frames() > _freed_on_frame + 2
	if not busy and settled and _focus and Input.is_action_just_pressed("cafe_interact"):
		_focus.interact(self)
	queue_redraw()


func _update_focus() -> void:
	_focus = null
	var prompt := ""
	if not busy:
		var best_distance := INF
		for area in _reach.get_overlapping_areas():
			if not area is Interactable:
				continue
			var text: String = area.get_prompt(self)
			var distance := global_position.distance_to(area.focus_point())
			if not text.is_empty() and distance < best_distance:
				best_distance = distance
				_focus = area
				prompt = text
	if cafe:
		cafe.hud.set_prompt(prompt)


func has_room() -> bool:
	return tray.size() < TRAY_SIZE


func add_item(id: String, quality: int) -> void:
	tray.append({"id": id, "quality": quality})


func count_item(id: String) -> int:
	return tray.filter(func(it: Dictionary) -> bool: return it["id"] == id).size()


## Removes and returns the best-quality item with this id, or {} if none.
func take_item(id: String) -> Dictionary:
	var best := -1
	for i in tray.size():
		if tray[i]["id"] == id and (best < 0 or tray[i]["quality"] > tray[best]["quality"]):
			best = i
	if best < 0:
		return {}
	var it := tray[best]
	tray.remove_at(best)
	return it


func clear_tray() -> void:
	tray.clear()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.95, 0.9, 0.82))
	draw_rect(Rect2(-5, -1, 10, 8), Color(0.35, 0.5, 0.45))  # apron
	# Tray contents float above your head.
	for i in tray.size():
		var x := (i - (tray.size() - 1) / 2.0) * 9.0
		draw_circle(Vector2(x, -15), 3.5, CafeData.item(tray[i]["id"])["color"])
		draw_arc(Vector2(x, -15), 3.5, 0.0, TAU, 12, Color(0, 0, 0, 0.5), 1.0)
