class_name ChoicePanel
extends PanelContainer
## A small pick-one menu: `var i := await panel.choose(title, options)`.
## Each option is {"text": String, "disabled": bool}. Returns -1 on cancel.

signal _chosen(index: int)

var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	hide()
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	_title.modulate = Color(1, 0.85, 0.6)
	box.add_child(_title)
	_list = VBoxContainer.new()
	box.add_child(_list)


func choose(title: String, options: Array[Dictionary]) -> int:
	_title.text = title
	for child in _list.get_children():
		child.queue_free()
	var first: Button
	for i in options.size():
		var button := _add_button(options[i]["text"], i)
		button.disabled = options[i].get("disabled", false)
		if first == null and not button.disabled:
			first = button
	var cancel := _add_button("Never mind", -1)
	(first if first else cancel).grab_focus.call_deferred()
	show()
	var result: int = await _chosen
	hide()
	return result


func _add_button(text: String, index: int) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Fire on press, so the key that opened the menu can't also pick from it on release.
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.pressed.connect(_chosen.emit.bind(index))
	_list.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_chosen.emit(-1)
	elif event.is_action_pressed("cafe_interact"):
		# Let the Interact key (E/J) confirm too, not just Enter/Space.
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused and is_ancestor_of(focused):
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
