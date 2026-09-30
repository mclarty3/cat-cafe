@tool
class_name Seat
extends Node2D
## Where a customer sits. Customers walk: door -> aisle -> this seat, so place
## seats on the aisle side of their table.

@export var label := "1"

var customer: Customer


func _ready() -> void:
	add_to_group("seats")


func _draw() -> void:
	draw_rect(Rect2(-7, -7, 14, 14), Color(0.45, 0.3, 0.22))
	draw_rect(Rect2(-7, -7, 14, 14), Color(0.6, 0.42, 0.3), false, 1.0)
