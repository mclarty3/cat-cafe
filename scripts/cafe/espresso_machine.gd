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
	var drinks := CafeData.ids_of_kind("drink")
	var options: Array[Dictionary] = []
	for id in drinks:
		var data := CafeData.item(id)
		var text: String = data["name"]
		var disabled := false
		if data.has("uses"):
			var left: int = cafe.day.stock[data["uses"]]
			text += "  (%d left)" % left
			disabled = left <= 0
		options.append({"text": text, "disabled": disabled})
	var choice := await cafe.choose("Espresso machine", options)
	if choice < 0:
		return
	var id := drinks[choice]
	var quality := await cafe.play_drink_minigame(id)
	var uses: String = CafeData.item(id).get("uses", "")
	if not uses.is_empty():
		cafe.day.stock[uses] -= 1
	barista.add_item(id, quality)
	cafe.toast("%s: %s" % [CafeData.item_name(id), CafeData.QUALITY_NAMES[quality]])
