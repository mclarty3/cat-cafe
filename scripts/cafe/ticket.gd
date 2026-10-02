class_name Ticket
extends RefCounted
## One customer's order, from the register to the pass.

var number := 0
var customer: Customer
var items: Array[String] = []
## Items placed on the pass so far: {"id": String, "quality": CafeData.Quality}.
var on_pass: Array[Dictionary] = []


## Items still missing from the pass.
func remaining() -> Array[String]:
	var left: Array[String] = items.duplicate()
	for it in on_pass:
		left.erase(it["id"])
	return left


func needs(id: String) -> bool:
	return id in remaining()


func is_complete() -> bool:
	return remaining().is_empty()
