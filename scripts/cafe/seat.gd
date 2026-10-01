@tool
class_name Seat
extends Marker3D
## Where a customer sits. The customer faces this node's forward (+Z) direction,
## so point it at the table. Customers walk door -> aisle -> seat, so place
## seats on the aisle side of their table.

@export var label := "1"

var customer: Customer


func _ready() -> void:
	add_to_group("seats")


func facing_yaw() -> float:
	var forward := global_basis.z
	return atan2(forward.x, forward.z)
