class_name Hud
extends CanvasLayer
## Health pips, interaction prompt, centre-screen messages and the fade used
## for room transitions.

const PIP_FULL := Color("f2e6d0")
const PIP_EMPTY := Color(1, 1, 1, 0.15)

@onready var _pips: HBoxContainer = $HealthPips
@onready var _prompt: Label = $Prompt
@onready var _message: Label = $Message
@onready var _fade: ColorRect = $Fade


func _ready() -> void:
	Game.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	_prompt.text = ""
	_message.text = ""


func set_health(current: int, maximum: int) -> void:
	while _pips.get_child_count() < maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 10)
		_pips.add_child(pip)
	while _pips.get_child_count() > maximum:
		var extra := _pips.get_child(-1)
		_pips.remove_child(extra)
		extra.queue_free()
	for i in _pips.get_child_count():
		(_pips.get_child(i) as ColorRect).color = PIP_FULL if i < current else PIP_EMPTY


func show_message(text: String) -> void:
	_message.text = text


func hide_message() -> void:
	_message.text = ""


func fade_out(duration := 0.2) -> void:
	await _fade_to(1.0, duration)


func fade_in(duration := 0.2) -> void:
	await _fade_to(0.0, duration)


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
