class_name FocusMarker
extends Node3D
## A small bobbing arrow over whatever Interact will use right now.

var active := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta


func _draw_overlay(canvas: OverlayAnchor) -> void:
	if not active:
		return
	var y := sin(_t * 5.0) * 2.0
	var arrow := PackedVector2Array([Vector2(-5, y - 6), Vector2(5, y - 6), Vector2(0, y)])
	canvas.draw_colored_polygon(arrow, Color(1, 0.88, 0.55))
	canvas.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0.25, 0.15, 0.08), 1.0)
