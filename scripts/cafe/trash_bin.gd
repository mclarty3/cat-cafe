@tool
class_name TrashBin
extends Station
## Empties your hands: for fixing mistakes.


func get_prompt(barista: Barista) -> String:
	return "Toss what you're holding" if not barista.hands.is_empty() else ""


func interact(barista: Barista) -> void:
	barista.clear_hands()
	cafe.toast("Tossed.")
