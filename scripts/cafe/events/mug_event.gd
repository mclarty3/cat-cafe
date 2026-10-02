class_name MugEvent
extends CatEvent
## A cat hops onto a table and nudges a mug toward the edge. Get there and
## catch it before it falls, or it breaks (costs `mug_cost`).


func mischief_id() -> String:
	return "mug"


func run() -> String:
	var c := cat()
	var table_top := cafe.pick_mug_spot()
	# The people's map stops at the table's rim, so that's where we hop up from
	# (not from underneath).
	var table_edge := cafe.floor_point(table_top)
	# Wander over like any other stroll; the event starts on the table.
	await c.go_to(table_edge)
	c.face(table_top - c.global_position)
	await c.hop(table_top)
	cafe.toast("%s is nudging a mug toward the edge!" % c.cat_name)

	c.mug.position = Vector3(0, 0, 0.18)
	c.mug.show()
	c.face(Vector3.BACK)
	c.event_mark = "!"
	var caught := [false]
	c.set_event_action("Catch the mug!", func() -> void: caught[0] = true)
	var left := cafe.mug_time
	var tink := 0.0
	while left > 0.0 and not caught[0]:
		var delta := await tick()
		left -= delta
		tink -= delta
		if tink <= 0.0:
			Audio.play("mug_tink")
			# Nudges come faster as the mug nears the edge.
			tink = lerpf(1.2, 0.35, 1.0 - left / cafe.mug_time)
		c.mug.position.z = 0.18 + cafe.mug_slide * (1.0 - left / cafe.mug_time)
		c.event_meter = left / cafe.mug_time

	c.clear_event_action()
	c.mug.hide()
	c.event_mark = ""
	c.event_meter = -1.0
	var line: String
	if caught[0]:
		Audio.play("mug_catch")
		cafe.float_text(c.global_position + Vector3.UP * 0.5, "Nice catch!", Color(0.6, 1, 0.6))
		line = "Caught the mug %s went for" % c.cat_name
	else:
		Audio.play("mug_crash")
		cafe.float_text(c.global_position + Vector3.UP * 0.5, "CRASH!", Color(1, 0.45, 0.4))
		cafe.day.breakage += cafe.mug_cost
		line = "%s broke a mug (-$%d)" % [c.cat_name, cafe.mug_cost]
	c.face(table_edge - c.global_position)
	await c.hop(table_edge)
	c.release()
	return line
