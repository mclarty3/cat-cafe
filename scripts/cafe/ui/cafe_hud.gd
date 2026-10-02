class_name CafeHud
extends CanvasLayer
## Cafe status readouts plus the modal panels (menus, minigame, dialogue,
## prep, results). Readouts are rebuilt every frame from the cafe's state.

var cafe: Cafe

var choice_panel: ChoicePanel
var minigame: DrinkMinigame
var dialogue: DialoguePanel
var prep_panel: PrepPanel
var results_panel: ResultsPanel

var _status: Label
var _stock: Label
var _tickets: Label
var _hands: Label
var _prompt: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	_status = _add_label(Control.PRESET_TOP_LEFT)
	_stock = _add_label(Control.PRESET_TOP_RIGHT)
	_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tickets = _add_label(Control.PRESET_CENTER_LEFT)
	_hands = _add_label(Control.PRESET_BOTTOM_LEFT)
	_prompt = _add_label(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 0.95, 0.75)
	_toast = _add_label(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position.y += 18

	# Panels live in layout containers so they stay put as their contents change.
	var centered := CenterContainer.new()
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	for container: Container in [centered, bottom]:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(container)
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	choice_panel = ChoicePanel.new()
	centered.add_child(choice_panel)
	prep_panel = PrepPanel.new()
	centered.add_child(prep_panel)
	results_panel = ResultsPanel.new()
	centered.add_child(results_panel)
	dialogue = DialoguePanel.new()
	dialogue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(dialogue)
	minigame = DrinkMinigame.new()
	add_child(minigame)


func _add_label(preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 6)
	label.grow_horizontal = {
		Control.PRESET_TOP_RIGHT: Control.GROW_DIRECTION_BEGIN,
		Control.PRESET_CENTER_BOTTOM: Control.GROW_DIRECTION_BOTH,
		Control.PRESET_CENTER_TOP: Control.GROW_DIRECTION_BOTH,
	}.get(preset, Control.GROW_DIRECTION_END)
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_BOTTOM]:
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return label


func set_prompt(text: String) -> void:
	_prompt.text = "[Interact]  " + text if not text.is_empty() else ""


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	if cafe == null:
		return
	var day := cafe.day
	_status.text = "$%d      Customers %d / %d" % [day.coins(), cafe.customers_arrived(), cafe.customers_per_day]

	var stock := []
	for key in CafeData.STOCK_NAMES:
		stock.append("%s %d" % [CafeData.STOCK_NAMES[key], day.stock[key]])
	_stock.text = "\n".join(stock)

	# The ticket rail: every open order, with what's already on the pass ticked.
	var tickets := []
	for ticket in cafe.tickets:
		var missing := ticket.remaining()
		var lines := []
		for id in ticket.items:
			var done := not id in missing
			missing.erase(id)
			lines.append(("  [x] " if done else "  [ ] ") + CafeData.item_name(id))
		var who := ticket.customer.display_name if ticket.customer.is_regular() else ""
		tickets.append("#%d %s\n%s" % [ticket.number, who, "\n".join(lines)])
	_tickets.text = "Tickets\n" + "\n".join(tickets) if not tickets.is_empty() else ""

	var hands := cafe.barista.hands.map(func(it: Dictionary) -> String:
		return "%s (%s)" % [CafeData.item_name(it["id"]), CafeData.QUALITY_NAMES[it["quality"]]])
	_hands.text = "Carrying: " + (", ".join(hands) if not hands.is_empty() else "nothing")
