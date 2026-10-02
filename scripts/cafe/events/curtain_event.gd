class_name CurtainEvent
extends CatEvent
## A kitten climbs the curtains and clings there, mewing. Walk over and lift
## her down before `curtain_time` runs out, or that curtain gets torn (costs
## `curtain_cost`).


func mischief_id() -> String:
	return "curtains"


func prepare() -> bool:
	return not cafe.get_tree().get_nodes_in_group("curtains").is_empty() and super()


func run() -> String:
	var c := cat()
	var curtain: Curtain = cafe.get_tree().get_nodes_in_group("curtains").pick_random()
	var side := randi() % 2
	var base := cafe.floor_point(curtain.base_point(side), cafe.cat_map)
	cafe.toast("%s is eyeing the curtains..." % c.cat_name)
	await c.go_to(base, true)

	# Up she goes, nose to the curtain.
	var cling := curtain.climb_point(side)
	c.face(-curtain.facing())
	c.pitch(-1.2)
	c.event_pose = "walk"
	var from := c.global_position
	var t := 0.0
	while t < 1.0:
		t += await tick()
		c.global_position = from.lerp(cling, minf(t, 1.0))
	c.event_pose = "idle"
	c.event_mark = "!"
	c.event_meter_color = Color(0.95, 0.75, 0.4)
	var lifted := [false]
	c.set_event_action("Lift %s down" % c.cat_name, func() -> void: lifted[0] = true)
	var left := cafe.curtain_time
	var mew := 0.5
	while left > 0.0 and not lifted[0]:
		var delta := await tick()
		left -= delta
		mew -= delta
		if mew <= 0.0:
			c.meow()
			mew = randf_range(2.0, 3.5)
		c.event_meter = left / cafe.curtain_time

	c.clear_event_action()
	c.event_mark = ""
	c.event_meter = -1.0
	var line: String
	if lifted[0]:
		cafe.float_text(cling + Vector3.UP * 0.3, "Down you come", Color(0.6, 1, 0.6))
		line = "Lifted %s down from the curtains" % c.cat_name
	else:
		curtain.tear(side)
		Audio.play("curtain_rip")
		cafe.float_text(cling + Vector3.UP * 0.3, "Rrrip!", Color(1, 0.45, 0.4))
		cafe.day.breakage += cafe.curtain_cost
		line = "%s tore the curtains (-$%d)" % [c.cat_name, cafe.curtain_cost]
	c.pitch(0.0)
	await c.hop(base)
	c.release()
	return line
