class_name FightEvent
extends CatEvent
## Two cats square off in the middle of the floor and scuffle in a cloud that
## grows and gets louder. While it runs, customers waiting in line or at
## pickup lose patience faster (more as it escalates). Break it up before
## `fight_time_limit`, or seated customers nearby leave early.

const RADIUS := 0.22


func mischief_id() -> String:
	return "fight"


func prepare() -> bool:
	var able := cafe.free_cats(mischief_id())
	if able.size() < 2:
		return false
	able.shuffle()
	cats = [able[0], able[1]]
	return true


func run() -> String:
	var a := cats[0]
	var b := cats[1]
	# Out in the open, somewhere the barista can reach.
	var spot := cafe.floor_point(cafe.random_floor_point(a.wander_area, cafe.cat_map))
	cafe.toast("%s and %s are squaring up..." % [a.cat_name, b.cat_name])
	a.move_to(spot + Vector3.RIGHT * RADIUS, true)
	b.move_to(spot - Vector3.RIGHT * RADIUS, true)
	var waited := 0.0
	while (a.is_moving() or b.is_moving()) and waited < 8.0:
		waited += await tick()

	var cloud := _make_cloud()
	cafe.add_actor(cloud)
	cloud.global_position = spot + Vector3.UP * 0.12
	var broken := [false]
	for c in cats:
		c.event_mark = "!"
		c.event_pose = "run"
		c.set_event_action("Break up the fight", func() -> void: broken[0] = true)
	var t := 0.0
	var angle := 0.0
	var hiss := 0.0
	while not broken[0] and t < cafe.fight_time_limit:
		var delta := await tick()
		t += delta
		var intensity := clampf(t / cafe.fight_escalate_time, 0.0, 1.0)
		cafe.fight_intensity = intensity
		# Circling each other, faster as it heats up.
		angle += delta * lerpf(2.5, 6.0, intensity)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * RADIUS
		a.global_position = spot + offset
		b.global_position = spot - offset
		a.face(-offset)
		b.face(offset)
		_puff(cloud, lerpf(0.7, 1.4, intensity))
		hiss -= delta
		if hiss <= 0.0:
			var who: CafeCat = cats.pick_random()
			Audio.play("cat_hiss", lerpf(-4.0, 0.0, intensity), who.voice_pitch * randf_range(0.9, 1.1))
			hiss = lerpf(1.6, 0.5, intensity) * randf_range(0.8, 1.2)
		for c in cats:
			c.event_meter = 1.0 - t / cafe.fight_time_limit

	cafe.fight_intensity = 0.0
	cloud.queue_free()
	var line: String
	if broken[0]:
		cafe.float_text(spot + Vector3.UP * 0.5, "Break it up!", Color(0.6, 1, 0.6))
		line = "Broke up a fight between %s and %s" % [a.cat_name, b.cat_name]
	else:
		var left := cafe.upset_seated_customers(spot, cafe.fight_upset_radius)
		line = "%s and %s's fight ran on: %d customer%s left early" \
			% [a.cat_name, b.cat_name, left, "" if left == 1 else "s"]
	for c in cats:
		c.release()
	return line


## A clump of white puffs: the classic cartoon scuffle.
func _make_cloud() -> Node3D:
	var cloud := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.94, 0.9)
	material.roughness = 1.0
	for i in 7:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.07, 0.11)
		sphere.height = sphere.radius * 2.0
		sphere.material = material
		puff.mesh = sphere
		puff.set_meta("home", Vector3(randf_range(-1, 1), randf_range(-0.4, 0.8), randf_range(-1, 1)) * 0.14)
		cloud.add_child(puff)
	return cloud


func _puff(cloud: Node3D, size: float) -> void:
	cloud.scale = Vector3.ONE * size
	for puff in cloud.get_children():
		var home: Vector3 = puff.get_meta("home")
		puff.position = home + Vector3(randf(), randf(), randf()) * 0.04
