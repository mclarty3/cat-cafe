class_name ComputerPanel
extends PanelContainer
## "CafeOS": the back-counter computer used before opening. Tabs down the side
## (moving through them switches the page), content on the right. The header
## always shows the day's key info, and "Open the cafe" sits in the sidebar so
## you can open up from any page.
##   var open_cafe := await computer.run(day)
## Returns true if the player chose to open the cafe, false if they just closed it.

signal _closed(open_cafe: bool)

const TABS := ["Kitchen", "Cats", "Furniture", "Upgrades"]
const ACCENT := Color(1, 0.85, 0.6)
const DIM := Color(1, 1, 1, 0.55)
const OPEN_COLOR := Color(0.27, 0.45, 0.3)

var _day: CafeDay
var _tab := "Kitchen"
var _tab_buttons := {}
var _content: VBoxContainer
var _status: Label


func _ready() -> void:
	hide()
	custom_minimum_size = Vector2(520, 290)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "CafeOS"
	title.modulate = ACCENT
	title.add_theme_font_size_override("font_size", 13)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_status = Label.new()
	_status.modulate = DIM
	header.add_child(_status)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(96, 0)
	body.add_child(sidebar)
	for tab in TABS:
		var button := Button.new()
		button.text = tab
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		# Moving onto a tab shows it straight away.
		button.focus_entered.connect(_show_tab.bind(tab))
		button.focus_entered.connect(Audio.play.bind("ui_move"))
		sidebar.add_child(button)
		_tab_buttons[tab] = button
	var sidebar_spacer := Control.new()
	sidebar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(sidebar_spacer)
	var open := Button.new()
	open.text = "Open the cafe"
	_style_open_button(open)
	open.pressed.connect(_close.bind(true))
	open.focus_entered.connect(Audio.play.bind("ui_move"))
	sidebar.add_child(open)
	var close := Button.new()
	close.text = "Log off"
	close.pressed.connect(_close.bind(false))
	close.focus_entered.connect(Audio.play.bind("ui_move"))
	sidebar.add_child(close)

	body.add_child(VSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)


func run(day: CafeDay) -> bool:
	_day = day
	_show_tab("Kitchen")
	Audio.play("ui_open")
	show()
	_tab_buttons["Kitchen"].grab_focus.call_deferred()
	var open_cafe: bool = await _closed
	hide()
	return open_cafe


func _close(open_cafe: bool) -> void:
	Audio.play("ui_select" if open_cafe else "ui_back")
	_closed.emit(open_cafe)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)
	elif event.is_action_pressed("cafe_interact"):
		# Let the Interact key (E/J) press buttons too, not just Enter/Space.
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused and is_ancestor_of(focused) and not focused.disabled:
			get_viewport().set_input_as_handled()
			focused.pressed.emit()


# --- Pages ----------------------------------------------------------------------

func _show_tab(tab: String) -> void:
	_tab = tab
	for name in _tab_buttons:
		_tab_buttons[name].button_pressed = name == tab
	_status.text = "6:45 AM  -  Closed  -  Prep actions left: %d" % _day.prep_actions_left
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match tab:
		"Kitchen":
			_kitchen_page()
		"Cats":
			_cats_page()
		"Furniture":
			_ideas_page("Furniture", "Change the layout and decor before opening.", CafeData.FURNITURE_IDEAS)
		"Upgrades":
			_ideas_page("Upgrades", "Spend your savings on the cafe.", CafeData.UPGRADE_IDEAS)


## Rebuilds the current page in place (after an action changes the day).
func _refresh(focus_index := -1) -> void:
	_show_tab(_tab)
	if focus_index >= 0:
		var buttons := _content.find_children("*", "Button", true, false)
		if focus_index < buttons.size():
			(buttons[focus_index] as Button).grab_focus.call_deferred()


func _kitchen_page() -> void:
	_heading("Kitchen")
	var pantry := []
	for key in CafeData.PANTRY_NAMES:
		pantry.append("%s %d" % [CafeData.PANTRY_NAMES[key], _day.pantry[key]])
	_text("From last night's dream: " + ", ".join(pantry))
	_text("Stock: " + _stock_summary())
	for i in CafeData.PREP_ACTIONS.size():
		var action: Dictionary = CafeData.PREP_ACTIONS[i]
		var gives := []
		for key in action["gives"]:
			gives.append("+%d %s" % [action["gives"][key], CafeData.STOCK_NAMES[key].to_lower()])
		var costs := []
		for key in action["costs"]:
			costs.append("%d %s" % [action["costs"][key], CafeData.PANTRY_NAMES[key].to_lower()])
		var button := _button("%s   (%s%s)" % [action["name"], ", ".join(gives),
			"; uses " + ", ".join(costs) if not costs.is_empty() else ""])
		button.disabled = not _day.can_do_prep(action)
		button.pressed.connect(func() -> void:
			_day.do_prep(action)
			Audio.play("prep")
			_refresh(i))


## The roster of cats living in the cafe. Viewing only for now; managing
## them comes with the cat systems.
func _cats_page() -> void:
	_heading("Cats in the cafe  (%d)" % CafeData.CATS.size())
	for id in CafeData.CATS:
		var cat: Dictionary = CafeData.CATS[id]
		_text("%s  -  %s" % [cat["name"], cat["personality"]], ACCENT)
		_text(cat["blurb"])
		_text(cat["since"], DIM)
	_text("Coming later: bond levels, where each cat hangs out, equipping cats for the dream, "
		+ "residents and adoption.", DIM)


func _ideas_page(title: String, intro: String, ideas: Array) -> void:
	_heading(title)
	_text(intro)
	for idea in ideas:
		var label: String = idea["name"]
		if idea.has("price"):
			label += "   $%d" % idea["price"]
		var button := _button(label + "   -  " + idea["note"])
		button.disabled = true
	_text("Coming soon: this needs savings and the cafe layout to carry over between days.", DIM)


# --- Building blocks ---------------------------------------------------------------

func _style_open_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = OPEN_COLOR if state == "normal" else OPEN_COLOR.lightened(0.2)
		box.set_corner_radius_all(3)
		box.set_content_margin_all(4)
		if state == "focus":
			box.set_border_width_all(1)
			box.border_color = Color(0.8, 1, 0.8)
		button.add_theme_stylebox_override(state, box)


func _stock_summary() -> String:
	var parts := []
	for key in CafeData.STOCK_NAMES:
		parts.append("%s %d" % [CafeData.STOCK_NAMES[key], _day.stock[key]])
	return ", ".join(parts)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = ACCENT
	label.add_theme_font_size_override("font_size", 13)
	_content.add_child(label)


func _text(text: String, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_entered.connect(Audio.play.bind("ui_move"))
	_content.add_child(button)
	return button
