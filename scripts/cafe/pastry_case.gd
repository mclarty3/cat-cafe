@tool
class_name PastryCase
extends Station
## Take a pastry baked during morning prep.


func get_prompt(barista: Barista) -> String:
	return "Take a pastry" if barista.has_room() else "Hands full"


func interact(barista: Barista) -> void:
	if not barista.has_room():
		cafe.toast("Your hands are full. Take it to the pass first.")
		return
	# Only what's on today's menu.
	var pastries := CafeData.ids_of_kind("pastry").filter(cafe.day.on_menu)
	if pastries.is_empty():
		cafe.toast("No pastries on today's menu.")
		return
	var options: Array[Dictionary] = []
	for id in pastries:
		var left: int = cafe.day.stock[id]
		options.append({"text": "%s  (%d left)" % [CafeData.item_name(id), left], "disabled": left <= 0})
	var choice := await cafe.choose("Pastry case", options)
	if choice < 0:
		return
	var id: String = pastries[choice]
	cafe.day.stock[id] -= 1
	barista.add_item(id, CafeData.Quality.GOOD)
	Audio.play("pastry")
