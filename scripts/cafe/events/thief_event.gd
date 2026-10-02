class_name ThiefEvent
extends CatEvent
## A cat sneaks up to the pastry case, hops up, grabs a croissant (stock goes
## down) and runs off to eat it under a table. You can watch it happen. While
## hiding it has no marker over it: the tells are the croissant in its mouth,
## munching, and its munching sound. Find it within `thief_time` to put the
## croissant back in stock; otherwise it's eaten.


func mischief_id() -> String:
	return "croissant_thief"


func prepare() -> bool:
	return cafe.day.stock.get("croissant", 0) > 0 and super()


func run() -> String:
	var c := cat()
	var shelf := cafe.pastry_case_shelf()
	var below := cafe.floor_point(shelf, cafe.cat_map)
	await c.go_to(below)
	c.face(shelf - c.global_position)
	await c.hop(shelf)

	if cafe.day.stock.get("croissant", 0) <= 0:
		# Sold out while we were sneaking over: nothing to take.
		await c.hop(below)
		c.release()
		return ""
	cafe.day.stock["croissant"] -= 1
	c.carry("croissant")
	Audio.play("pastry")
	cafe.toast("A croissant has gone missing!")
	await wait(0.3)
	await c.hop(below)
	await c.go_to(_hiding_spot(), true)

	# Tuck in, back to the room.
	c.face(Vector3.BACK)
	c.event_pose = "eat"
	var found := [false]
	c.set_event_action("Take back the croissant", func() -> void: found[0] = true)
	var left := cafe.thief_time
	var munch := 1.0
	while left > 0.0 and not found[0]:
		var delta := await tick()
		left -= delta
		munch -= delta
		if munch <= 0.0:
			Audio.play("munch", 0.0, c.voice_pitch)
			munch = randf_range(2.5, 4.0)

	var line: String
	if found[0]:
		cafe.day.stock["croissant"] += 1
		Audio.play("pastry")
		cafe.float_text(c.global_position + Vector3.UP * 0.5, "Got it back!", Color(0.6, 1, 0.6))
		line = "Caught %s with a stolen croissant" % c.cat_name
	else:
		cafe.float_text(c.global_position + Vector3.UP * 0.5, "*crumbs*", Color(1, 0.8, 0.5))
		line = "%s ate a stolen croissant" % c.cat_name
	c.release()
	# A short sulk: no petting for a bit.
	c.cool_off(6.0)
	return line


## Under a random table, on the room side of its pedestal.
func _hiding_spot() -> Vector3:
	var table: Vector3 = cafe.table_positions().pick_random()
	return cafe.floor_point(table + Vector3.BACK * 0.35, cafe.cat_map)
