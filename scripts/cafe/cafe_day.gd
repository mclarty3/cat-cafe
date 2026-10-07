class_name CafeDay
extends RefCounted
## Everything that changes over one cafe day: the menu, stock, money and stats.
##
## In the morning the player sets the menu: which drinks are on it (up to
## `drink_slots`), how many of each pastry to bake (up to `pastry_slots` in
## all), and how many of each dungeon-ingredient drink to offer. Ingredients are
## taken as items go on and given back if they come off, so the menu can be
## changed freely until opening.

var drink_slots := 3
var pastry_slots := 8
var pantry: Dictionary = CafeData.STARTING_PANTRY.duplicate()
## Item ids on today's menu. Counted items stay on it when they sell out.
var menu: Array[String] = []
## How many of each counted item are left (see CafeData.is_counted).
var stock := {}

var earnings := 0
var tips := 0
var breakage := 0
var served := 0
var walked_out := 0
## Customers who left without ordering because nothing they wanted was left.
var turned_away := 0
## Customers who left early, upset by a cat fight (a hook for a future daily rating).
var left_early := 0
## A line per cat event, for the results screen.
var cat_events: Array[String] = []
var chats: Array[String] = []
var missed_chats: Array[String] = []


func _init() -> void:
	for id in CafeData.ITEMS:
		if CafeData.is_counted(id):
			stock[id] = 0


func coins() -> int:
	return earnings + tips - breakage


func on_menu(id: String) -> bool:
	return id in menu


func drinks_on_menu() -> int:
	return menu.filter(func(id: String) -> bool: return CafeData.item(id)["kind"] == "drink").size()


func pastries_baked() -> int:
	var total := 0
	for id in CafeData.ids_of_kind("pastry"):
		total += stock[id]
	return total


## Puts a drink on the menu or takes it off. An ingredient drink goes on with
## one already counted (so it needs an ingredient spare), and taking it off
## gives its ingredients back. A counted item is never on the menu at 0 before
## opening, so whatever is on the menu can be sold.
func can_toggle_drink(id: String) -> bool:
	if on_menu(id):
		return true
	var data := CafeData.item(id)
	if data.has("ingredient") and pantry.get(data["ingredient"], 0) <= 0:
		return false
	return drinks_on_menu() < drink_slots


func toggle_drink(id: String) -> void:
	if on_menu(id):
		while stock.get(id, 0) > 0:
			remove_one(id)
		menu.erase(id)
	elif can_toggle_drink(id):
		menu.append(id)
		if CafeData.is_counted(id):
			add_one(id)


## One more of a counted item: a pastry needs a free slot, an ingredient drink
## needs to be on the menu; both need their ingredient, if they use one.
func can_add_one(id: String) -> bool:
	var data := CafeData.item(id)
	if data["kind"] == "pastry":
		if pastries_baked() >= pastry_slots:
			return false
	elif not on_menu(id):
		return false
	return not data.has("ingredient") or pantry.get(data["ingredient"], 0) > 0


func add_one(id: String) -> void:
	if not can_add_one(id):
		return
	var data := CafeData.item(id)
	if data.has("ingredient"):
		pantry[data["ingredient"]] -= 1
	stock[id] += 1
	if not on_menu(id):
		menu.append(id)


func can_remove_one(id: String) -> bool:
	return stock.get(id, 0) > 0


func remove_one(id: String) -> void:
	if not can_remove_one(id):
		return
	var data := CafeData.item(id)
	if data.has("ingredient"):
		pantry[data["ingredient"]] += 1
	stock[id] -= 1
	# Down to none: off the menu (a drink's box unticks too).
	if stock[id] == 0:
		menu.erase(id)


## Left to sell: unlimited (-1) for an uncounted drink on the menu, else the stock.
func left(id: String) -> int:
	if not on_menu(id):
		return 0
	return stock[id] if CafeData.is_counted(id) else -1
