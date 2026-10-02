class_name CafeDay
extends RefCounted
## Everything that changes over one cafe day: prep, stock, money and stats.

var prep_actions_left := 3
var pantry: Dictionary = CafeData.STARTING_PANTRY.duplicate()
var stock := {"croissant": 0, "moon_muffin": 0, "honey_syrup": 0}

var earnings := 0
var tips := 0
var breakage := 0
var served := 0
var walked_out := 0
## Customers who left early, upset by a cat fight (a hook for a future daily rating).
var left_early := 0
## A line per cat event, for the results screen.
var cat_events: Array[String] = []
var chats: Array[String] = []
var missed_chats: Array[String] = []


func can_do_prep(action: Dictionary) -> bool:
	if prep_actions_left <= 0:
		return false
	for key in action["costs"]:
		if pantry.get(key, 0) < action["costs"][key]:
			return false
	return true


func do_prep(action: Dictionary) -> void:
	prep_actions_left -= 1
	for key in action["costs"]:
		pantry[key] -= action["costs"][key]
	for key in action["gives"]:
		stock[key] += action["gives"][key]


func coins() -> int:
	return earnings + tips - breakage
