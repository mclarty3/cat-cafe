class_name OverlayAnchor
extends Node2D
## A 2D drawing surface pinned above a 3D node: speech bubbles, patience bars
## and labels stay crisp and screen-aligned in the 3D view.
## The target draws by implementing `_draw_overlay(canvas: OverlayAnchor)`.

var target: Node3D
## World-space height above the target's origin to pin to.
var height := 1.0


static func attach(p_target: Node3D, layer: CanvasLayer, p_height: float) -> OverlayAnchor:
	var anchor := OverlayAnchor.new()
	anchor.target = p_target
	anchor.height = p_height
	layer.add_child(anchor)
	p_target.tree_exiting.connect(anchor.queue_free)
	return anchor


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(target):
		return
	position = camera.unproject_position(target.global_position + Vector3.UP * height)
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(target) and target.has_method("_draw_overlay"):
		target._draw_overlay(self)


## Draws text horizontally centred on `center.x`, with its baseline at `center.y`.
func text_centered(text: String, center: Vector2, font_size := 8, color := Color.WHITE, outline := 0) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center - Vector2(width / 2.0, 0)
	if outline > 0:
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(0, 0, 0, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func bubble(rect: Rect2) -> void:
	var fill := Color(1, 0.98, 0.92)
	draw_rect(rect, fill)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, rect.end.y), Vector2(3, rect.end.y), Vector2(0, rect.end.y + 4),
	]), fill)


## A small bar that goes from green (full) to red (empty).
func meter(rect: Rect2, ratio: float, color := Color.TRANSPARENT) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.5))
	var fill := color if color.a > 0.0 else Color(1.0 - ratio, 0.3 + 0.6 * ratio, 0.3)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), fill)
