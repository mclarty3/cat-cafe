@tool
class_name Register
extends Station
## The till computer. Before opening it runs CafeOS (prep, cats, furniture,
## upgrades, and opening up). During service it takes the order of whoever is
## at the front of the queue: they pay the menu price here, and tip later at
## the pass.


func get_prompt(_barista: Barista) -> String:
	if cafe.phase == Cafe.Phase.PREP:
		return "Use the computer"
	if cafe.phase != Cafe.Phase.SERVICE:
		return ""
	var customer := cafe.front_of_queue()
	if customer == null:
		return ""
	return "Take %s's order" % customer.display_name if customer.is_regular() else "Take order"


func interact(_barista: Barista) -> void:
	if cafe.phase == Cafe.Phase.PREP:
		cafe.open_computer()
		return
	var customer := cafe.front_of_queue()
	if customer:
		cafe.take_order(customer, focus_point() + Vector3.UP * 0.8)
