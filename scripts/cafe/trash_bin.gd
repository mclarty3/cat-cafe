@tool
class_name TrashBin
extends Station
## Empties the tray: for fixing mistakes.


func get_prompt(barista: Barista) -> String:
	return "Toss tray" if not barista.tray.is_empty() else ""


func interact(barista: Barista) -> void:
	barista.clear_tray()
	cafe.toast("Tossed.")
