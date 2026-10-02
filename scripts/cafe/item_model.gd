class_name ItemModel
extends Node3D
## A menu item as a little 3D model (on the pass, in the barista's hands), built
## from its CafeData.ITEMS entry: `model` at `model_scale`, standing on an
## optional `base` at `base_scale` (espresso's cup sits on a saucer).

var item_id := ""
## Multiplies the item's scales (the barista shows carried items a bit bigger).
var scale_factor := 1.0


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
	var main := Prop3D.new()
	add_child(main)
	main.model_scale = data.get("model_scale", 0.35) * scale_factor
	main.model = load(data["model"])
	main.position.y = lift
