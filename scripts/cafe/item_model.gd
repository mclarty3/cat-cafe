class_name ItemModel
extends Node3D
## A menu item as a little 3D model (on the pass, in the barista's hands), built
## from its CafeData.ITEMS entry: `model` at `model_scale`, standing on an
## optional `base` at `base_scale` (espresso's cup sits on a saucer).
##
## A drink can be drunk down with set_fill(): the coffee in the Kenney cup is
## part of the cup's mesh (coloured from the shared colormap), so its faces are
## found by colour and lowered, then recoloured to the cup's white when empty.

## How dark a colormap texel is to count as the drink rather than the cup.
const LIQUID_LUMINANCE := 0.45
## Mesh -> {"liquid": PackedInt32Array of vertex indices, "top": y, "bottom": y,
## "white_uv": Vector2}, worked out once per model.
static var _liquid_info := {}

var item_id := ""
## Multiplies the item's scales (the barista shows carried items a bit bigger).
var scale_factor := 1.0

var _main: Prop3D
var _full_mesh: ArrayMesh


static func create(id: String, factor := 1.0) -> ItemModel:
	var item := ItemModel.new()
	item.item_id = id
	item.scale_factor = factor
	return item


func _ready() -> void:
	var data := CafeData.item(item_id)
	var lift := 0.0
	if data.has("base"):
		var base := Prop3D.new()
		add_child(base)
		base.model_scale = data.get("base_scale", 0.35) * scale_factor
		base.model = load(data["base"])
		lift = base.bounds.end.y
	_main = Prop3D.new()
	add_child(_main)
	_main.model_scale = data.get("model_scale", 0.35) * scale_factor
	_main.model = load(data["model"])
	_main.position.y = lift


## How full the drink is: 1 as made, 0 an empty cup.
func set_fill(fill: float) -> void:
	if _main == null:
		return
	var meshes := _main.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	if _full_mesh == null:
		_full_mesh = mesh_instance.mesh as ArrayMesh
	if _full_mesh == null:
		return
	var info := _liquid(_full_mesh)
	if info.is_empty():
		return
	var tool := MeshDataTool.new()
	tool.create_from_surface(_full_mesh, 0)
	var level: float = lerpf(info["bottom"], info["top"], clampf(fill, 0.0, 1.0))
	for v: int in info["liquid"]:
		var at := tool.get_vertex(v)
		tool.set_vertex(v, Vector3(at.x, level, at.z))
		if fill <= 0.0:
			tool.set_vertex_uv(v, info["white_uv"])
	var drunk := ArrayMesh.new()
	tool.commit_to_surface(drunk)
	mesh_instance.mesh = drunk


## Finds the drink's faces in a cup mesh by their texel colour (see set_fill()).
static func _liquid(mesh: ArrayMesh) -> Dictionary:
	if _liquid_info.has(mesh):
		return _liquid_info[mesh]
	var info := {}
	var material := mesh.surface_get_material(0) as BaseMaterial3D
	var texture := material.albedo_texture if material else null
	if texture:
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var tool := MeshDataTool.new()
		tool.create_from_surface(mesh, 0)
		var liquid := PackedInt32Array()
		var white_uv := Vector2(-1, -1)
		var size := Vector2(image.get_size() - Vector2i.ONE)
		for face in tool.get_face_count():
			var first := tool.get_face_vertex(face, 0)
			var texel := Vector2i(tool.get_vertex_uv(first).posmod(1.0) * size)
			var shade := image.get_pixelv(texel).get_luminance()
			for corner in 3:
				var v := tool.get_face_vertex(face, corner)
				if shade < LIQUID_LUMINANCE and not liquid.has(v):
					liquid.append(v)
			if shade > 0.85 and white_uv.x < 0.0:
				white_uv = tool.get_vertex_uv(first)
		if not liquid.is_empty() and white_uv.x >= 0.0:
			var top := -INF
			for v in liquid:
				top = maxf(top, tool.get_vertex(v).y)
			var floor_y := mesh.get_aabb().position.y
			info = {"liquid": liquid, "top": top, "bottom": lerpf(floor_y, top, 0.2), "white_uv": white_uv}
	_liquid_info[mesh] = info
	return info
