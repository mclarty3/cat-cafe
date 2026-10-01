class_name Shapes
## Helpers for the placeholder @tool nodes (blocks, spikes, doors...) that size
## their own collision from a `size` property. Origin is the top-left corner.


static func sync_rect(parent: CollisionObject2D, size: Vector2, one_way := false) -> void:
	var shape_node := parent.get_node_or_null("AutoShape") as CollisionShape2D
	if shape_node == null:
		# Deliberately left without an owner: it's rebuilt on load and never saved.
		shape_node = CollisionShape2D.new()
		shape_node.name = "AutoShape"
		parent.add_child(shape_node)
	# Always a fresh shape, so editor-duplicated nodes never share one.
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = size / 2.0
	shape_node.one_way_collision = one_way
