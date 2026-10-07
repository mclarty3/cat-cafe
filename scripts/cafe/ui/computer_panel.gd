class_name ComputerPanel
extends PanelContainer
## "CafeOS": the back-counter computer used before opening. Tabs down the side
## (moving through them switches the page), content on the right. The header
## always shows the day's key info, and "Open the cafe" sits in the sidebar so
## you can open up from any page.
##   var open_cafe := await computer.run(day)
## Returns true if the player chose to open the cafe, false if they just closed it.

signal _closed(open_cafe: bool)

const TABS := ["Menu", "Cats", "Furniture", "Upgrades"]
const ACCENT := Color(1, 0.85, 0.6)
const DIM := Color(1, 1, 1, 0.55)
const OPEN_COLOR := Color(0.27, 0.45, 0.3)
const CARD_COLOR := Color(0.24, 0.18, 0.15)
## Effect icons: cafe effects are green (benefit) or red (drawback); dream
## effects are always lilac.
const GOOD_ICON_COLOR := Color(0.6, 0.88, 0.55)
const BAD_ICON_COLOR := Color(1, 0.5, 0.45)
const DREAM_ICON_COLOR := Color(0.75, 0.68, 1)
const ICON_DIR := "res://assets/ui/icons/"

var _day: CafeDay
var _tab := "Menu"
var _tab_buttons := {}
var _open_button: Button
var _content: VBoxContainer
var _status: Label
## Line pinned under the page (outside the scrolling area): details for
## whatever is hovered or focused. Empty on pages that don't use it.
var _info: RichTextLabel


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
	_open_button = Button.new()
	_open_button.text = "Open the cafe"
	_style_open_button(_open_button)
	_open_button.pressed.connect(_close.bind(true))
	_open_button.focus_entered.connect(Audio.play.bind("ui_move"))
	sidebar.add_child(_open_button)
	var close := Button.new()
	close.text = "Log off"
	close.pressed.connect(_close.bind(false))
	close.focus_entered.connect(Audio.play.bind("ui_move"))
	sidebar.add_child(close)

	body.add_child(VSeparator.new())
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	# Always exactly two lines tall, so changing its text on hover never
	# shifts the layout (which made the list jump).
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(0, 34)
	_info.add_theme_color_override("default_color", Color(1, 1, 1, 0.75))
	_info.add_theme_constant_override("line_separation", -1)
	page.add_child(_info)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)


func run(day: CafeDay) -> bool:
	_day = day
	_show_tab("Menu")
	Audio.play("ui_open")
	show()
	_tab_buttons["Menu"].grab_focus.call_deferred()
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
	_status.text = "6:45 AM  -  Closed"
	# Nothing to sell, nothing to open for.
	_open_button.disabled = _day.menu.is_empty()
	_set_info("")
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match tab:
		"Menu":
			_menu_page()
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


## Today's menu: tick the drinks to offer (up to the drink slots), and set how
## many of each pastry to bake (up to the pastry slots) and of each
## dream-ingredient drink to offer. Ingredients come back if you lower a count,
## so it can be changed freely until opening.
func _menu_page() -> void:
	_heading("Today's menu")
	var pantry := []
	for key in CafeData.PANTRY_NAMES:
		pantry.append("%s %d" % [CafeData.PANTRY_NAMES[key], _day.pantry[key]])
	_text("From last night's dream: " + ", ".join(pantry))

	_subheading("Drinks", "%d / %d slots" % [_day.drinks_on_menu(), _day.drink_slots])
	for id in CafeData.ids_of_kind("drink"):
		var row := _row()
		var check := CheckBox.new()
		check.text = "%s   $%d" % [CafeData.item_name(id), CafeData.item(id)["price"]]
		check.button_pressed = _day.on_menu(id)
		check.disabled = not _day.can_toggle_drink(id)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.focus_entered.connect(Audio.play.bind("ui_move"))
		row.add_child(check)
		_on_press(check, _day.toggle_drink.bind(id))
		if CafeData.is_counted(id) and _day.on_menu(id):
			_stepper(row, id)
		_note(row, _item_note(id))

	_subheading("Pastry case", "%d / %d slots" % [_day.pastries_baked(), _day.pastry_slots])
	for id in CafeData.ids_of_kind("pastry"):
		var row := _row()
		var label := Label.new()
		label.text = "%s   $%d" % [CafeData.item_name(id), CafeData.item(id)["price"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_stepper(row, id)
		_note(row, _item_note(id))

	if _day.menu.is_empty():
		_set_info("[color=#ffffff88]Put something on the menu before opening.[/color]")


## What it takes to make one: an ingredient, or nothing.
func _item_note(id: String) -> String:
	var data := CafeData.item(id)
	if data.has("ingredient"):
		return "1 %s each" % CafeData.PANTRY_NAMES[data["ingredient"]].to_lower()
	return "free to bake" if data["kind"] == "pastry" else "unlimited"


## [-] count [+] for a counted item.
func _stepper(row: HBoxContainer, id: String) -> void:
	var minus := _small_button(row, "-")
	minus.disabled = not _day.can_remove_one(id)
	_on_press(minus, _day.remove_one.bind(id))
	var count := Label.new()
	count.text = str(_day.stock[id])
	count.custom_minimum_size = Vector2(18, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus := _small_button(row, "+")
	plus.disabled = not _day.can_add_one(id)
	_on_press(plus, _day.add_one.bind(id))


## Pressing runs `change`, then rebuilds the page with this button still focused.
func _on_press(button: Button, change: Callable) -> void:
	button.pressed.connect(func() -> void:
		var index := _content.find_children("*", "Button", true, false).find(button)
		change.call()
		Audio.play("prep")
		_refresh(index))


## The roster of cats living in the cafe, as compact cards: name and
## personality up front, effects as icons (hover or focus one for details).
## Viewing only for now; managing cats comes with the cat systems.
func _cats_page() -> void:
	_heading("Cats in the cafe  (%d)" % CafeData.CATS.size())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for id in CafeData.CATS:
		grid.add_child(_cat_card(CafeData.CATS[id]))
	_set_info("[color=#ffffff88]Hover a cat or an icon for details  -  green helps, red is a drawback  -  not active yet[/color]")


func _cat_card(cat: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	# Name in the accent colour, the description, then the backstory smaller
	# and dimmer underneath.
	var about := "[color=#%s]%s[/color]  %s
[font_size=8][color=#ffffff70][i]%s[/i][/color][/font_size]" % [
		ACCENT.to_html(false), cat["name"], cat["blurb"], cat["since"]]
	card.mouse_entered.connect(_set_info.bind(about))

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	card.add_child(rows)

	# Name and personality, big and up front.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	rows.add_child(top)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot := StyleBoxFlat.new()
	dot.bg_color = cat["swatch"]
	dot.set_corner_radius_all(6)
	swatch.add_theme_stylebox_override("panel", dot)
	top.add_child(swatch)
	var name_label := Label.new()
	name_label.text = cat["name"]
	name_label.add_theme_font_size_override("font_size", 13)
	top.add_child(name_label)
	var trait_label := Label.new()
	trait_label.text = cat["personality"]
	trait_label.modulate = ACCENT
	trait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(trait_label)

	# Effects as icons, grouped by where they apply.
	var effects := HBoxContainer.new()
	effects.add_theme_constant_override("separation", 3)
	rows.add_child(effects)
	var personality: Dictionary = CafeData.PERSONALITIES[cat["personality"]]
	_effect_group(effects, "Cafe", personality["cafe"], cat["name"])
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.add_child(gap)
	_effect_group(effects, "Dream", personality["dream"], cat["name"])
	return card


func _effect_group(row: HBoxContainer, title: String, effects: Array, cat_name: String) -> void:
	var label := Label.new()
	label.text = title
	label.modulate = DIM
	label.add_theme_font_size_override("font_size", 8)
	row.add_child(label)
	for effect in effects:
		var color := DREAM_ICON_COLOR
		if title == "Cafe":
			color = BAD_ICON_COLOR if effect.get("negative", false) else GOOD_ICON_COLOR
		var icon := Button.new()
		icon.icon = load(ICON_DIR + effect["icon"] + ".png")
		icon.expand_icon = true
		icon.custom_minimum_size = Vector2(20, 20)
		var where := "In the cafe" if title == "Cafe" else "In the dream"
		for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
			icon.add_theme_color_override(state, color if state == "icon_normal_color" else color.lightened(0.35))
		var plain := StyleBoxEmpty.new()
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(1, 1, 1, 0.08)
		ring.set_corner_radius_all(4)
		ring.set_border_width_all(1)
		ring.border_color = color
		for state in ["normal", "pressed", "disabled"]:
			icon.add_theme_stylebox_override(state, plain)
		icon.add_theme_stylebox_override("hover", ring)
		icon.add_theme_stylebox_override("focus", ring)
		var detail := "[color=#%s]%s[/color]  -  %s: %s" % [ACCENT.to_html(false), cat_name, where, effect["text"]]
		icon.mouse_entered.connect(_set_info.bind(detail))
		icon.focus_entered.connect(_set_info.bind(detail))
		icon.focus_entered.connect(Audio.play.bind("ui_move"))
		row.add_child(icon)


func _set_info(text: String) -> void:
	_info.text = text
	_info.visible = not text.is_empty()


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


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = ACCENT
	label.add_theme_font_size_override("font_size", 13)
	_content.add_child(label)


## A section title with a dim count on the right.
func _subheading(text: String, count: String) -> void:
	var row := _row()
	var label := Label.new()
	label.text = text
	label.modulate = ACCENT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var right := Label.new()
	right.text = count
	right.modulate = DIM
	row.add_child(right)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)
	return row


func _note(row: HBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = DIM
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 9)
	row.add_child(label)


func _small_button(row: HBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(20, 0)
	button.focus_entered.connect(Audio.play.bind("ui_move"))
	row.add_child(button)
	return button


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
