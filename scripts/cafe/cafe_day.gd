class_name CafeDay
extends RefCounted
## Everything that changes over one cafe day: prep, stock, money and stats.

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


func can_make(recipe: Dictionary) -> bool:
	for key in recipe["costs"]:
		if pantry.get(key, 0) < recipe["costs"][key]:
			return false
	return true


func make(recipe: Dictionary) -> void:
	for key in recipe["costs"]:
		pantry[key] -= recipe["costs"][key]
	for key in recipe["gives"]:
		stock[key] += recipe["gives"][key]


func coins() -> int:
	return earnings + tips - breakage
