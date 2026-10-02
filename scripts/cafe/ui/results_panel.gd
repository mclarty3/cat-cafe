class_name ResultsPanel
extends PanelContainer
## End-of-day summary. `run()` returns true for "next day", false for "title".

signal _picked(next_day: bool)

var _body: Label
var _next_button: Button


func _ready() -> void:
	hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var heading := Label.new()
	heading.text = "Closing time"
	heading.add_theme_font_size_override("font_size", 14)
	heading.modulate = Color(1, 0.85, 0.6)
	box.add_child(heading)
	_body = Label.new()
	box.add_child(_body)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_next_button = Button.new()
	_next_button.text = "Another day"
	_next_button.pressed.connect(_picked.emit.bind(true))
	_next_button.pressed.connect(Audio.play.bind("ui_select"))
	buttons.add_child(_next_button)
	var title := Button.new()
	title.text = "Back to title"
	title.pressed.connect(_picked.emit.bind(false))
	buttons.add_child(title)


func run(day: CafeDay) -> bool:
	var lines := [
		"Customers served: %d" % day.served,
		"Walked out: %d" % day.walked_out,
		"Sales: $%d    Tips: $%d" % [day.earnings, day.tips],
	]
	match day.mug_result:
		"caught":
			lines.append("The mug a cat went for: caught it!")
		"broken":
			lines.append("The mug a cat went for: broken (-$%d)" % day.breakage)
	lines.append("Total: $%d" % day.coins())
	for chat in day.chats:
		lines.append("Chatted with %s" % chat)
	for missed in day.missed_chats:
		lines.append(missed)
	_body.text = "\n".join(lines)
	show()
	_next_button.grab_focus.call_deferred()
	var next_day: bool = await _picked
	hide()
	return next_day
