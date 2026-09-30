class_name Poof
extends Node2D
## Throwaway hit/death effect: an expanding ring that fades out.

@export var radius := 14.0
@export var duration := 0.25
@export var color := Color.WHITE

var _t := 0.0


static func spawn(parent: Node, at: Vector2, radius := 14.0, color := Color.WHITE) -> void:
	var poof := Poof.new()
	poof.radius = radius
	poof.color = color
	parent.add_child(poof)
	poof.global_position = at


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _t / duration
	draw_arc(Vector2.ZERO, radius * p, 0.0, TAU, 24, Color(color, 1.0 - p), 2.0)
