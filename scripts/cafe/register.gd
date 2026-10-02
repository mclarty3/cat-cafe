@tool
class_name Register
extends Station
## Take the order of whoever is at the front of the queue. They pay the menu
## price here; the tip comes later, at the pass.


func get_prompt(_barista: Barista) -> String:
	var customer := cafe.front_of_queue()
	if customer == null:
		return ""
	return "Take %s's order" % customer.display_name if customer.is_regular() else "Take order"


func interact(_barista: Barista) -> void:
	var customer := cafe.front_of_queue()
	if customer:
		cafe.take_order(customer, focus_point() + Vector3.UP * 0.8)
