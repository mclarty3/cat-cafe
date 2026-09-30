class_name FloatText
extends Node2D
## A short piece of text that drifts up and fades: "+$7", "purr~", "CRASH!".

@export var duration := 1.2
@export var rise := 18.0

var text := ""
var color := Color.WHITE
var _t := 0.0


static func spawn(parent: Node, at: Vector2, text: String, color := Color.WHITE) -> void:
	var ft := FloatText.new()
	ft.text = text
	ft.color = color
	ft.z_index = 10
	parent.add_child(ft)
	ft.global_position = at


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _t / duration
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var pos := Vector2(-width / 2.0, -rise * p)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 1.0 - p))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(color, 1.0 - p))
