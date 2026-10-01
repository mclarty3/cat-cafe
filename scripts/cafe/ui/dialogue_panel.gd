class_name DialoguePanel
extends PanelContainer
## Bottom-of-screen conversation box.
##   var i := await dialogue.ask(name, line, ["choice a", "choice b"])
##   await dialogue.say(name, line)

signal _picked(index: int)

var _speaker: Label
var _line: Label
var _choices: VBoxContainer


func _ready() -> void:
	hide()
	custom_minimum_size = Vector2(440, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_speaker = Label.new()
	_speaker.modulate = Color(1, 0.85, 0.6)
	box.add_child(_speaker)
	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(420, 0)
	box.add_child(_line)
	_choices = VBoxContainer.new()
	box.add_child(_choices)


func ask(speaker: String, line: String, choices: Array) -> int:
	_speaker.text = speaker
	_line.text = line
	for child in _choices.get_children():
		child.queue_free()
	var first: Button
	for i in choices.size():
		var button := Button.new()
		button.text = "> " + String(choices[i])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.pressed.connect(_picked.emit.bind(i))
		_choices.add_child(button)
		if first == null:
			first = button
	first.grab_focus.call_deferred()
	show()
	var result: int = await _picked
	hide()
	return result


func say(speaker: String, line: String) -> void:
	await ask(speaker, line, ["(Continue)"])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cafe_interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused and is_ancestor_of(focused):
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
