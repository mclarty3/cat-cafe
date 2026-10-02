class_name DebugPanel
extends PanelContainer
## Debug menu (debug builds only), toggled with F9. Docks on the right so the
## floor stays visible; the world keeps running while it's open, but the
## barista ignores input. Calls into the cafe's debug_* functions.

const ACCENT := Color(0.55, 0.9, 0.85)
const DIM := Color(1, 1, 1, 0.55)
const SPEEDS := [1.0, 2.0, 4.0]
const BUSES := ["Master", "Music", "SFX"]
## Volume sliders go up to this much of a bus's starting level (100% = as mixed).
const MAX_VOLUME := 1.5

## Each bus's starting volume (dB), taken the first time a panel is made, so
## the sliders stay relative to the mix even after the scene reloads.
static var _mixed_db := {}
## Debug builds start quieter: these buses begin at this share of the mix (set
## once per session, so whatever you set on the sliders afterwards sticks).
const START_VOLUMES := {"Master": 0.25}

var cafe: Cafe

var _status: Label
var _event_buttons := {}
var _spawn: Button
var _complete_all: Button
var _end_day: Button
var _refresh := 0.0


func _ready() -> void:
	hide()
	custom_minimum_size = Vector2(170, 0)
	theme = _compact_theme()
	if _mixed_db.is_empty():
		for bus_name in BUSES:
			var bus := AudioServer.get_bus_index(bus_name)
			if bus >= 0:
				_mixed_db[bus_name] = AudioServer.get_bus_volume_db(bus)
				if START_VOLUMES.has(bus_name):
					AudioServer.set_bus_volume_db(bus, _mixed_db[bus_name] + linear_to_db(START_VOLUMES[bus_name]))
	var style := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.border_color = ACCENT.darkened(0.2)
	style.bg_color = Color(0.1, 0.12, 0.13, 0.94)
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "DEBUG"
	title.modulate = ACCENT
	title.add_theme_font_size_override("font_size", 11)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var hint := Label.new()
	hint.text = "F9 / Esc to close"
	hint.modulate = DIM
	hint.add_theme_font_size_override("font_size", 8)
	header.add_child(hint)

	_status = Label.new()
	_status.modulate = Color(1, 1, 1, 0.8)
	_status.add_theme_font_size_override("font_size", 8)
	root.add_child(_status)

	_section(root, "Cat events")
	var events := GridContainer.new()
	events.columns = 2
	root.add_child(events)
	for kind in Cafe.CAT_EVENTS:
		var id: String = kind.new().mischief_id()
		var button := _button(events, id.capitalize(), func() -> void: cafe.debug_start_cat_event(kind))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_event_buttons[kind] = button

	_section(root, "Customers")
	var customer_row := HBoxContainer.new()
	root.add_child(customer_row)
	_spawn = _button(customer_row, "Spawn customer", func() -> void: cafe.debug_spawn_customer())
	_complete_all = _button(customer_row, "Complete orders", func() -> void: cafe.debug_complete_orders())
	for button in [_spawn, _complete_all]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn.tooltip_text = "The next customer walks in now"
	_complete_all.tooltip_text = "Put everything open orders need on the pass"
	_toggle(root, "Auto-take orders", func(on: bool) -> void: cafe.debug_auto_take = on)
	_toggle(root, "Auto-complete orders", func(on: bool) -> void: cafe.debug_auto_complete = on)

	_section(root, "Day")
	var speed_row := HBoxContainer.new()
	root.add_child(speed_row)
	var stock := _button(speed_row, "+3 stock", func() -> void: cafe.debug_add_stock(3))
	stock.tooltip_text = "+3 of each stock"
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	for speed: float in SPEEDS:
		var button := _button(speed_row, "%dx" % speed, func() -> void: Engine.time_scale = speed)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = is_equal_approx(Engine.time_scale, speed)
	_end_day = _button(root, "Skip to closing", func() -> void:
		close()
		cafe.debug_end_day())

	var audio := _section(root, "Audio")
	var music := AudioServer.get_bus_index("Music")
	var mute := Button.new()
	mute.text = "Mute music"
	mute.toggle_mode = true
	mute.button_pressed = AudioServer.is_bus_mute(music)
	mute.add_theme_font_size_override("font_size", 8)
	mute.toggled.connect(func(on: bool) -> void: AudioServer.set_bus_mute(music, on))
	audio.add_child(mute)
	for bus in BUSES:
		_volume_row(root, bus)


## A volume slider for one bus (0% silent, 100% as mixed).
func _volume_row(parent: Control, bus_name: String) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = bus_name
	label.custom_minimum_size.x = 38
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = MAX_VOLUME
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus) - _mixed_db[bus_name])
	row.add_child(slider)
	var percent := Label.new()
	percent.custom_minimum_size.x = 30
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.modulate = DIM
	row.add_child(percent)
	var show_percent := func(value: float) -> void: percent.text = "%d%%" % roundi(value * 100.0)
	show_percent.call(slider.value)
	slider.value_changed.connect(show_percent)
	slider.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_db(bus, _mixed_db[bus_name] + linear_to_db(maxf(value, 0.0001))))


## The project theme, a size smaller: this is a tool, not part of the game.
func _compact_theme() -> Theme:
	var compact := ThemeDB.get_project_theme().duplicate(true) as Theme
	compact.default_font_size = 9
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := compact.get_stylebox(state, "Button") as StyleBoxFlat
		if box:
			box.content_margin_top = 1
			box.content_margin_bottom = 1
	compact.set_constant("h_separation", "GridContainer", 3)
	compact.set_constant("v_separation", "GridContainer", 3)
	compact.set_constant("separation", "HBoxContainer", 3)
	return compact


## A section heading. Returns its row, so a section can put a control beside it.
func _section(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text.to_upper()
	label.modulate = ACCENT
	label.add_theme_font_size_override("font_size", 8)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _toggle(parent: Control, text: String, action: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.toggled.connect(action)
	parent.add_child(toggle)
	return toggle


func open() -> void:
	show()
	cafe.barista.busy = true
	_update()
	for button in _event_buttons.values():
		if not button.disabled:
			button.grab_focus()
			return
	_spawn.grab_focus()


func close() -> void:
	hide()
	cafe.barista.busy = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_update()


## Status line and which buttons can do something right now.
func _update() -> void:
	_status.text = cafe.debug_status()
	var service := cafe.phase == Cafe.Phase.SERVICE
	for kind in _event_buttons:
		_event_buttons[kind].disabled = not cafe.debug_can_start_cat_event(kind)
	_spawn.disabled = not service or not cafe.debug_can_spawn()
	_complete_all.disabled = cafe.tickets.is_empty()
	_end_day.disabled = not service
