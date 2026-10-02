class_name PrepPanel
extends PanelContainer
## Morning prep: spend a limited number of actions turning dungeon ingredients
## into stock, then open the cafe.

signal _opened

var _day: CafeDay
var _info: Label
var _actions: VBoxContainer
var _open_button: Button


func _ready() -> void:
	hide()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var heading := Label.new()
	heading.text = "Morning prep"
	heading.add_theme_font_size_override("font_size", 14)
	heading.modulate = Color(1, 0.85, 0.6)
	box.add_child(heading)
	_info = Label.new()
	box.add_child(_info)
	_actions = VBoxContainer.new()
	box.add_child(_actions)
	_open_button = Button.new()
	_open_button.text = "Open the cafe"
	_open_button.pressed.connect(_opened.emit)
	box.add_child(_open_button)


func run(day: CafeDay) -> void:
	_day = day
	for i in CafeData.PREP_ACTIONS.size():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_do_action.bind(i))
		button.focus_entered.connect(Audio.play.bind("ui_move"))
		_actions.add_child(button)
	_refresh()
	show()
	_actions.get_child(0).grab_focus.call_deferred()
	await _opened
	hide()


func _do_action(index: int) -> void:
	_day.do_prep(CafeData.PREP_ACTIONS[index])
	Audio.play("prep")
	_refresh()
	if _day.prep_actions_left == 0:
		_open_button.grab_focus()


func _refresh() -> void:
	var pantry := []
	for key in CafeData.PANTRY_NAMES:
		pantry.append("%s %d" % [CafeData.PANTRY_NAMES[key], _day.pantry[key]])
	var stock := []
	for key in CafeData.STOCK_NAMES:
		stock.append("%s %d" % [CafeData.STOCK_NAMES[key], _day.stock[key]])
	_info.text = "Actions left: %d\nFrom last night's dream: %s\nStock: %s" % [
		_day.prep_actions_left, ", ".join(pantry), ", ".join(stock)]

	for i in CafeData.PREP_ACTIONS.size():
		var action: Dictionary = CafeData.PREP_ACTIONS[i]
		var button := _actions.get_child(i) as Button
		var gives := []
		for key in action["gives"]:
			gives.append("+%d %s" % [action["gives"][key], CafeData.STOCK_NAMES[key].to_lower()])
		var costs := []
		for key in action["costs"]:
			costs.append("%d %s" % [action["costs"][key], CafeData.PANTRY_NAMES[key].to_lower()])
		button.text = "%s   (%s%s)" % [action["name"], ", ".join(gives),
			"; uses " + ", ".join(costs) if not costs.is_empty() else ""]
		button.disabled = not _day.can_do_prep(action)
