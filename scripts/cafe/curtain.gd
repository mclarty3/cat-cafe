@tool
class_name Curtain
extends Node3D
## A pair of curtains at a window: two plain fabric panels, a stand-in until
## there's a real model. Place it on the wall at the window's centre, facing
## into the room (+Z). The curtain event's kitten climbs one side; ignored for
## too long, that side gets torn.

@export var width := 1.0:
	set(value):
		width = value
		_rebuild()
## Panel length, hanging down from `top`.
@export var drop := 0.95:
	set(value):
		drop = value
		_rebuild()
@export var top := 1.25:
	set(value):
		top = value
		_rebuild()
@export var color := Color(0.74, 0.5, 0.48):
	set(value):
		color = value
		_rebuild()

const PANEL_WIDTH := 0.24

var _panels: Array[MeshInstance3D] = []


func _enter_tree() -> void:
	add_to_group("curtains")


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for panel in _panels:
		panel.queue_free()
	_panels.clear()
	for side in 2:
		var panel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(PANEL_WIDTH, drop, 0.03)
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.95
		box.material = material
		panel.mesh = box
		panel.position = Vector3(_panel_x(side), top - drop / 2.0, 0.04)
		add_child(panel)
		_panels.append(panel)


func _panel_x(side: int) -> float:
	return (width / 2.0 - PANEL_WIDTH / 2.0) * (-1.0 if side == 0 else 1.0)


## Where a climbing cat clings, partway up a panel (side 0 or 1).
func climb_point(side: int) -> Vector3:
	return to_global(Vector3(_panel_x(side), top - drop * 0.5, 0.13))


## The floor in front of a panel, where a cat starts climbing.
func base_point(side: int) -> Vector3:
	return to_global(Vector3(_panel_x(side), 0.0, 0.4))


## Which way is into the room.
func facing() -> Vector3:
	return global_basis.z.normalized()


## Shreds one side: it hangs shorter, ragged and darker.
func tear(side: int) -> void:
	var panel := _panels[side]
	var torn := drop * 0.6
	(panel.mesh as BoxMesh).size.y = torn
	panel.position.y = top - torn / 2.0
	panel.rotation.z = 0.08 * (1.0 if side == 0 else -1.0)
	((panel.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = color.darkened(0.25)
