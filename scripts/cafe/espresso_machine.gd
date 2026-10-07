@tool
class_name EspressoMachine
extends Station
## Pick a drink, play its minigame, and it goes on your tray.


func get_prompt(barista: Barista) -> String:
	return "Make a drink" if barista.has_room() else "Hands full"


func interact(barista: Barista) -> void:
	if not barista.has_room():
		cafe.toast("Your hands are full. Take it to the pass first.")
		return
	# Only what's on today's menu.
	var drinks := CafeData.ids_of_kind("drink").filter(cafe.day.on_menu)
	var options: Array[Dictionary] = []
	for id in drinks:
		var text := CafeData.item_name(id)
		var left := cafe.day.left(id)
		if left >= 0:
			text += "  (%d left)" % left
		options.append({"text": text, "disabled": left == 0})
	var choice := await cafe.choose("Espresso machine", options)
	if choice < 0:
		return
	var id: String = drinks[choice]
	var quality := await cafe.play_drink_minigame(id)
	if CafeData.is_counted(id):
		cafe.day.stock[id] -= 1
	barista.add_item(id, quality)
	cafe.toast("%s: %s" % [CafeData.item_name(id), CafeData.QUALITY_NAMES[quality]])
