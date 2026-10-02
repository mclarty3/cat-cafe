class_name Cafe
extends Node3D
## Runs one counter-service cafe day: a walkable morning prep (done on the
## register's computer), then service, then the end-of-day results. Customers queue at the register, wait at the pickup spot
## while you carry their order to the pass, then sit for a while. Day tuning is
## exported here.

## Emitted every frame with its length (cat events step along on it).
signal ticked(delta: float)

enum Phase { PREP, SERVICE, RESULTS }

## The cat events a day can draw from (see the "Cat events" settings).
const CAT_EVENTS: Array[GDScript] = [
	preload("res://scripts/cafe/events/mug_event.gd"),
	preload("res://scripts/cafe/events/fight_event.gd"),
	preload("res://scripts/cafe/events/curtain_event.gd"),
	preload("res://scripts/cafe/events/thief_event.gd"),
]

@export_group("Day")
@export var customers_per_day := 5
@export var first_customer_delay := 2.0
## Random gap between arrivals, in seconds (min, max).
@export var spawn_interval := Vector2(16.0, 24.0)
## Which arrival (0-based) is the regular.
@export var regular_index := 2
@export var regular_id := "theo"

@export_group("Cat events")
## How many happen during a day's service (each a different kind).
@export var cat_events_per_day := 2
## When they can start, in seconds after opening (earliest, latest).
@export var cat_event_window := Vector2(20.0, 110.0)
## At least this long between two starting.
@export var cat_event_min_gap := 30.0
## If on, an event waits until you aren't in a menu/minigame/chat, so it's a
## choice rather than bad luck.
@export var cat_events_wait_for_free_hands := true
## Mug: seconds to catch it, and how far it slides toward the edge before falling.
@export var mug_time := 6.0
@export var mug_slide := 0.25
## Fight: seconds to reach full intensity, and until it upsets the room.
@export var fight_escalate_time := 20.0
@export var fight_time_limit := 30.0
## At full intensity, waiting customers lose patience this much faster (1 = twice as fast).
@export var fight_patience_drain := 1.0
## When a fight runs out its time, seated customers this close leave early.
@export var fight_upset_radius := 2.5
## Curtains: seconds to lift the kitten down before she tears them.
@export var curtain_time := 20.0
## Croissant thief: seconds before the stolen croissant is eaten.
@export var thief_time := 40.0

@export_group("Customers")
@export var customer_walk_speed := 1.4
## Walking customers and cats sidestep anyone closer than this.
@export var avoid_radius := 0.7
## The same when a cat is involved: they're long and low, so they start turning
## early to pass side by side.
@export var cat_avoid_radius := 0.65
## How hard walkers turn aside (1 = up to 45 degrees when touching).
@export var avoid_strength := 2.5
## How quickly walkers turn toward where they want to go (higher = snappier).
@export var steer_response := 20.0
## Scale for the Kenney character models (customers; the barista sets its own).
@export var character_scale := 0.8
## Height to lift a seated customer so the sit pose lands on the chair.
@export var sit_height := 0.3
## Patience while in line, from walking in to ordering.
@export var queue_patience := 60.0
## Patience at the pickup spot, plus a bit more per item ordered.
@export var pickup_patience := 50.0
@export var patience_per_item := 15.0
## How long walk-ins sit with their order before leaving.
@export var linger_time := 10.0
## Regulars stay longer so there's time to chat.
@export var regular_linger_time := 25.0
@export_range(0.0, 1.0) var drink_order_chance := 0.85
@export_range(0.0, 1.0) var pastry_order_chance := 0.6

@export_group("Morning")
## Light before opening: cooler and dimmer, warming up when you open.
@export var morning_sun_energy := 0.3
@export var morning_sun_color := Color(0.8, 0.88, 1.0)
@export var morning_ambient_energy := 0.22
@export var open_light_fade := 2.5

@export_group("Money")
## Tip per drink by quality: poor, good, perfect.
@export var tip_per_quality: Array[int] = [0, 1, 3]
## Bonus tip if the customer still had at least this much patience left.
@export_range(0.0, 1.0) var patience_tip_threshold := 0.5
@export var mug_cost := 2
@export var curtain_cost := 3

## Walkers stop sidestepping this close to the end of their route.
const ARRIVE_RADIUS := 0.4
## Walkers may leave the walkable floor this close to an off-floor destination (the door).
const EXIT_RADIUS := 1.2

var day := CafeDay.new()
var phase := Phase.PREP
## Open orders, oldest first.
var tickets: Array[Ticket] = []
## 2D layer for bubbles, bars and floating text that track 3D positions.
## A getter, because children read it before this node's _ready runs.
var overlay: CanvasLayer:
	get:
		return $Overlay

var _spawned := 0
var _spawn_timer := 0.0
var _service_time := 0.0
## 0..1 while a cat fight runs: waiting customers lose patience faster.
var fight_intensity := 0.0
## Service times (seconds) when the day's cat events start, soonest first.
var _event_times: Array[float] = []
## Mischief ids already used today (one of each kind a day).
var _events_done: Array[String] = []
var _active_event: CatEvent
## Shift+F9 (debug builds) starts these in turn.
var _debug_event := 0
var _next_ticket := 1
var _customers: Array[Customer] = []
## Customers in line, front first.
var _queue: Array[Customer] = []

@onready var hud: CafeHud = $HUD
@onready var barista: Barista = $Barista
@onready var camera: CafeCamera = $Camera
@onready var _actors: Node3D = $Actors
@onready var _door: Marker3D = $Markers/Door
@onready var _queue_spots: Array[Node] = $Markers/Queue.get_children()
@onready var _pickup_spots: Array[Node] = $Markers/Pickup.get_children()
@onready var _overflow_spots: Array[Node] = $Markers/PickupOverflow.get_children()
@onready var _pass: Pass = $Stations/Pass
@onready var _navigation: NavigationRegion3D = $Navigation
@onready var _room: Node3D = $Room
var _cats: Array[CafeCat] = []
## The cats' navigation map (see _bake_cat_navigation).
var cat_map: RID
var _cat_region: RID
@onready var _sun: DirectionalLight3D = $Sun
@onready var _environment: Environment = $WorldEnvironment.environment

var _day_sun_energy := 0.0
var _day_sun_color := Color.WHITE
var _day_ambient_energy := 0.0


func _enter_tree() -> void:
	# Joined before children are ready, so they can find the cafe in their _ready.
	add_to_group("cafe")


func _ready() -> void:
	barista.cafe = self
	OverlayAnchor.attach(barista, overlay, 1.0)
	OverlayAnchor.attach(barista.focus_marker, overlay, 0.0)
	camera.follow_target = barista
	hud.cafe = self
	_spawn_cats()
	# Built from the furniture colliders at runtime, so rearranging the room
	# in the editor just works.
	_navigation.bake_navigation_mesh(false)
	_keep_floor_only(_navigation.navigation_mesh)
	NavigationServer3D.region_set_navigation_mesh(_navigation.get_rid(), _navigation.navigation_mesh)
	_bake_cat_navigation()
	# The cats' map picks up its bake on the next sync: put them on the floor then.
	NavigationServer3D.map_changed.connect(_on_map_changed)
	Audio.play_music(CafeData.PLAYLIST)
	tree_exiting.connect(func() -> void:
		NavigationServer3D.free_rid(_cat_region)
		NavigationServer3D.free_rid(cat_map)
		Audio.stop_music(0.5)
		Audio.stop_all_loops())

	_start_morning()


func _spawn_cats() -> void:
	var scene := load("res://scenes/cafe/cat.tscn") as PackedScene
	for id in CafeData.CATS:
		var cat := scene.instantiate() as CafeCat
		_actors.add_child(cat)
		cat.configure(id, CafeData.CATS[id])
		_cats.append(cat)


## The bake also makes walkable islands on top of tables, chairs and the
## counter. Nobody walks up there, and they'd make floor_point() snap people
## into the furniture, so keep only the floor's polygons.
func _keep_floor_only(mesh: NavigationMesh) -> void:
	var vertices := mesh.get_vertices()
	# The floor is the lowest layer (it bakes a little above y = 0).
	var floor_y := INF
	for v in vertices:
		floor_y = minf(floor_y, v.y)
	var floor_polygons: Array[PackedInt32Array] = []
	for i in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(i)
		if Array(polygon).all(func(v: int) -> bool: return vertices[v].y < floor_y + 0.2):
			floor_polygons.append(polygon)
	mesh.clear_polygons()
	for polygon in floor_polygons:
		mesh.add_polygon(polygon)


## Cats get their own navigation map, baked from what the furniture actually
## looks like rather than its colliders: anything with cat-sized room underneath
## (tables, chairs) can be walked under, and legs and pedestals block wherever
## they really are. The room's shell (floor and walls) still comes from its
## colliders, since the walls cut away for the camera have none to see.
func _bake_cat_navigation() -> void:
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.1
	mesh.cell_height = 0.1
	mesh.agent_radius = 0.2
	mesh.agent_height = 0.3
	mesh.agent_max_climb = 0.1
	# Rugs, mats and pedestal feet are just floor (otherwise the rug's edge is a seam).
	mesh.filter_low_hanging_obstacles = true
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var source := NavigationMeshSourceGeometryData3D.new()
	for node in get_tree().get_nodes_in_group("nav_source"):
		mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS 			if node == _room else NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
		var part := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, part, node)
		source.merge(part)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	_keep_floor_only(mesh)

	cat_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(cat_map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(cat_map, mesh.cell_height)
	NavigationServer3D.map_set_active(cat_map, true)
	_cat_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_cat_region, cat_map)
	NavigationServer3D.region_set_navigation_mesh(_cat_region, mesh)


func _on_map_changed(map: RID) -> void:
	if map == cat_map:
		NavigationServer3D.map_changed.disconnect(_on_map_changed)
		_place_cats()


func _place_cats() -> void:
	for cat in _cats:
		cat.global_position = random_floor_point(cat.wander_area, cat_map)


## A random walkable point on the floor inside `area` (x, z), off the furniture.
## `map` is the people's map unless given (cats pass `cat_map`).
func random_floor_point(area: Rect2, map := RID()) -> Vector3:
	var point := Vector3(randf_range(area.position.x, area.end.x), 0.0, randf_range(area.position.y, area.end.y))
	return floor_point(point, map)


## The nearest walkable floor point to `point`, looking straight down through
## it, so a slightly raised patch of floor (a rug) counts as much as the floor
## around it.
func floor_point(point: Vector3, map := RID()) -> Vector3:
	var p := NavigationServer3D.map_get_closest_point_to_segment(_map_or_default(map),
		Vector3(point.x, 1.0, point.z), Vector3(point.x, -1.0, point.z))
	return Vector3(p.x, 0.0, p.z)


func _map_or_default(map: RID) -> RID:
	return map if map.is_valid() else get_world_3d().navigation_map


# --- Morning prep -----------------------------------------------------------------

func _start_morning() -> void:
	phase = Phase.PREP
	_day_sun_energy = _sun.light_energy
	_day_sun_color = _sun.light_color
	_day_ambient_energy = _environment.ambient_light_energy
	_sun.light_energy = morning_sun_energy
	_sun.light_color = morning_sun_color
	_environment.ambient_light_energy = morning_ambient_energy
	hud.set_objective("Morning prep: use the computer at the register, then open up.")


## Which interactables work right now: the register (its computer runs CafeOS
## before opening) and the cat any time, the other stations during service.
func can_use(interactable: Interactable) -> bool:
	if interactable is CafeCat or interactable is Register:
		return true
	return phase == Phase.SERVICE


func open_computer() -> void:
	barista.busy = true
	camera.focus(barista.global_position)
	var open_cafe := await hud.computer.run(day)
	camera.unfocus()
	barista.busy = false
	if open_cafe:
		_open_cafe()


func _open_cafe() -> void:
	phase = Phase.SERVICE
	_spawn_timer = first_customer_delay
	hud.set_objective("")
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sun, "light_energy", _day_sun_energy, open_light_fade)
	tween.tween_property(_sun, "light_color", _day_sun_color, open_light_fade)
	tween.tween_property(_environment, "ambient_light_energy", _day_ambient_energy, open_light_fade)
	Audio.play("door_open")
	Audio.play("day_open")
	toast("The cafe is open!")
	_schedule_cat_events()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not barista.busy:
		Game.go_to_title()
	# Debug shortcuts (debug builds, during service). Godot's editor already uses F8
	# (stop) and the other F-keys near it, so both live on F9.
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F9 and phase == Phase.SERVICE:
		if event.shift_pressed:
			# Shift+F9: start a cat event now, each kind in turn.
			if _active_event == null:
				for i in CAT_EVENTS.size():
					var kind: GDScript = CAT_EVENTS[(_debug_event + i) % CAT_EVENTS.size()]
					if _start_cat_event(kind):
						_debug_event = (_debug_event + i + 1) % CAT_EVENTS.size()
						break
		elif not barista.busy:
			# F9: skip straight to closing time (results screen and closing chime).
			_end_day()


func _process(delta: float) -> void:
	ticked.emit(delta)
	if phase != Phase.SERVICE:
		return
	_service_time += delta

	if _spawned < customers_per_day:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			# Line is full: try again shortly.
			_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y) if _try_spawn() else 1.0

	_update_cat_events()
	# Closing time once everyone's gone; any events still to come are skipped,
	# but one that's running plays out.
	if _spawned >= customers_per_day and _customers.is_empty() and _active_event == null:
		_end_day()


func customers_arrived() -> int:
	return _spawned


func door_outside() -> Vector3:
	return _door.global_position


## A walkable route around the furniture, ending exactly at `to`.
func find_path(from: Vector3, to: Vector3, map := RID()) -> Array[Vector3]:
	var points := NavigationServer3D.map_get_path(_map_or_default(map), from, to, true)
	var path: Array[Vector3] = []
	for p in points:
		path.append(Vector3(p.x, 0.0, p.z))
	if not path.is_empty() and path[0].distance_to(from) < 0.05:
		path.remove_at(0)
	# Seats sit right against tables, inside the walkable edge: finish the hop.
	if path.is_empty() or path[-1].distance_to(to) > 0.02:
		path.append(to)
	return path


## Moves a walking customer or cat one step along `path` (from find_path; points
## are removed as they're reached), sidestepping whoever is in the way.
## `velocity` is the walker's current velocity; the new one is returned, and is
## what the walker should face. It turns toward the wanted direction over a few
## frames, so sidesteps curve rather than jitter and walkers look where they go.
func step_along(actor: Node3D, path: Array[Vector3], velocity: Vector3, speed: float, delta: float) -> Vector3:
	var to_target := path[0] - actor.global_position
	to_target.y = 0.0
	var step := speed * delta
	# Near the end, walk straight on, so we land exactly on our spot or seat.
	if path.size() == 1 and to_target.length() <= ARRIVE_RADIUS:
		actor.global_position = actor.global_position.move_toward(path[0], step)
		if actor.global_position.distance_to(path[0]) < 0.01:
			path.clear()
		return to_target.normalized() * speed
	var map := cat_map if actor is CafeCat else RID()
	var heading := to_target.normalized()
	var push := avoidance(actor, heading)
	var wanted := (heading + push).normalized() * speed
	velocity = velocity.lerp(wanted, 1.0 - exp(-steer_response * delta))
	var next := actor.global_position + velocity * delta
	# Near a destination that's off the walkable floor on purpose (out of the
	# door, or the hop into a seat), head straight for it. Otherwise a crowd
	# sidestepping at the doorway gets pinned to the floor's edge, circling the
	# last corner of the route.
	var destination := path[-1]
	if _flat_distance(destination, floor_point(destination, map)) > 0.05 			and _flat_distance(actor.global_position, destination) < EXIT_RADIUS:
		actor.global_position = next
		path.assign([destination])
		return velocity
	if push == Vector3.ZERO:
		# On the route, which lies on the floor already. (Clamping here would
		# snag on the jagged outline of chair legs and the like.)
		actor.global_position = next
	else:
		# A sidestep can head anywhere: stay on the walkable floor, sliding along
		# the furniture and facing (and keeping) the way we actually went.
		var from := actor.global_position
		actor.global_position = floor_point(next, map)
		velocity = (actor.global_position - from) / delta
		velocity.y = 0.0
		# Then re-plan from here. That keeps the room the sidestep made instead
		# of steering back into whoever we're passing, and the next corner can't
		# end up behind the furniture.
		path.assign(find_path(actor.global_position, destination, map))
	if path.size() > 1 and _flat_distance(actor.global_position, path[0]) <= maxf(step, 0.05):
		path.remove_at(0)
	return velocity


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func float_text(world_position: Vector3, text: String, color := Color.WHITE) -> void:
	FloatText.spawn(overlay, camera.unproject_position(world_position), text, color)


# --- Queue ---------------------------------------------------------------------

func _try_spawn() -> bool:
	if _queue.size() >= _queue_spots.size():
		return false
	var customer := Customer.new()
	_actors.add_child(customer)
	customer.setup(self, regular_id if _spawned == regular_index else "")
	customer.left_cafe.connect(_on_customer_left)
	_customers.append(customer)
	_queue.append(customer)
	customer.walk_to(_queue_spots[_queue.size() - 1].global_position)
	Audio.play("door_open")
	Audio.play("door_bell")
	_spawned += 1
	return true


## Whoever is standing at the register ready to order, if anyone.
func front_of_queue() -> Customer:
	if _queue.is_empty() or not _queue[0].can_order():
		return null
	return _queue[0]


func _leave_queue(customer: Customer) -> void:
	_queue.erase(customer)
	for i in _queue.size():
		_queue[i].walk_to(_queue_spots[i].global_position)


# --- Orders, the pass and pickup ----------------------------------------------

func take_order(customer: Customer, register_position: Vector3) -> void:
	var ticket := Ticket.new()
	ticket.number = _next_ticket
	_next_ticket += 1
	ticket.customer = customer
	ticket.items = _create_order(customer)
	tickets.append(ticket)

	var price := 0
	for id in ticket.items:
		price += CafeData.item(id)["price"]
	day.earnings += price
	Audio.play("register")
	float_text(register_position, "+$%d" % price, Color(1, 0.9, 0.5))
	if customer.is_regular():
		toast("%s: \"%s\"" % [customer.display_name, CafeData.REGULARS[customer.regular_id]["greeting"]])

	_leave_queue(customer)
	customer.on_ordered(ticket)
	_fill_pickup_spots()


## Sends everyone waiting for an order to their own pickup spot, oldest ticket
## first. If every spot is taken, the rest wait in a line behind the last one
## and move up as spots free.
func _fill_pickup_spots() -> void:
	var waiting := _customers.filter(func(c: Customer) -> bool: return c.state == Customer.State.WAITING_PICKUP)
	waiting.sort_custom(func(a: Customer, b: Customer) -> bool: return a.ticket.number < b.ticket.number)
	var taken := waiting.map(func(c: Customer) -> int: return c.pickup_index)
	var overflow := 0
	for customer: Customer in waiting:
		if customer.pickup_index >= 0:
			continue
		var free := range(_pickup_spots.size()).filter(func(i: int) -> bool: return i not in taken)
		if not free.is_empty():
			customer.pickup_index = free[0]
			taken.append(free[0])
			customer.walk_to(_pickup_spots[free[0]].global_position)
		else:
			overflow += 1
			customer.walk_to(_pickup_overflow_point(overflow))


## The overflow line is the markers under Markers/PickupOverflow, in order (`rank`
## starts at 1). If it's longer than that, it carries on past the last marker at
## the same spacing.
func _pickup_overflow_point(rank: int) -> Vector3:
	var spots := _overflow_spots.map(func(m: Marker3D) -> Vector3: return m.global_position)
	if spots.is_empty():
		spots = [_pickup_spots[-1].global_position]
	if rank <= spots.size():
		return spots[rank - 1]
	var last: Vector3 = spots[-1]
	var step: Vector3 = last - spots[-2] if spots.size() > 1 else Vector3.ZERO
	return floor_point(last + step * (rank - spots.size()))


## Frees a pickup spot when its customer stops waiting, and moves the line up.
## Deferred, so the customer has already moved on (seated or leaving) by then.
func _release_pickup_spot(customer: Customer) -> void:
	customer.pickup_index = -1
	_fill_pickup_spots.call_deferred()


## A nudge that steers a walking customer or cat around whoever is close
## ahead: customers (not ones sitting down), cats on the floor and the barista.
## Steers to the side rather than backing off, so two meeting head-on pass.
func avoidance(actor: Node3D, heading: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for other in _obstacles(actor):
		var radius := cat_avoid_radius if actor is CafeCat or other is CafeCat else avoid_radius
		var away := actor.global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		# Ignore anyone well behind us (they're the ones who should steer), but keep
		# steering past someone alongside, or our sides brush as we pass.
		if distance >= radius or away.dot(heading) > distance * 0.5:
			continue
		# Ignore anyone we're already drawing away from, unless we're touching:
		# otherwise a knot of walkers keeps nudging each other back and forth.
		var closing := (_walk_velocity(actor) - _walk_velocity(other)).dot(-away / maxf(distance, 0.001))
		if closing <= 0.0 and distance > radius * 0.5:
			continue
		var side := heading.cross(Vector3.UP)
		if side.dot(away) < -0.01:
			side = -side
		push += side * (1.0 - distance / radius) * avoid_strength
	return push


func _walk_velocity(node: Node3D) -> Vector3:
	if node is Barista:
		return (node as Barista).velocity
	return node.walk_velocity()


## True when someone is standing on top of this idle cat, so it should move.
func crowding(cat: CafeCat) -> bool:
	for other in _obstacles(cat):
		var away := cat.global_position - other.global_position
		away.y = 0.0
		if away.length() < cat_avoid_radius * 0.5:
			return true
	return false


func _obstacles(actor: Node3D) -> Array[Node3D]:
	var others: Array[Node3D] = [barista]
	for c in _customers:
		if c != actor and (c.state != Customer.State.SEATED or c.is_walking()):
			others.append(c)
	for cat in _cats:
		if cat != actor and cat.on_floor():
			others.append(cat)
	return others


func _create_order(customer: Customer) -> Array[String]:
	var order: Array[String] = []
	if customer.is_regular():
		for id in CafeData.REGULARS[customer.regular_id]["favourite"]:
			if _available(id) > 0:
				order.append(id)
				return order

	var drinks := CafeData.ids_of_kind("drink").filter(func(id: String) -> bool: return _available(id) > 0)
	var pastries := CafeData.ids_of_kind("pastry").filter(func(id: String) -> bool: return _available(id) > 0)
	if randf() < drink_order_chance and not drinks.is_empty():
		order.append(drinks.pick_random())
	if (randf() < pastry_order_chance or order.is_empty()) and not pastries.is_empty():
		order.append(pastries.pick_random())
	if order.is_empty():
		order.append("espresso")
	return order


## How many more of an item can be promised to new orders: stock, plus any
## already in hand or on the pass, minus what open tickets still need.
func _available(id: String) -> int:
	var uses: String = CafeData.item(id).get("uses", "")
	if uses.is_empty():
		return 999
	var count: int = day.stock[uses]
	for item_id in CafeData.ITEMS:
		if CafeData.item(item_id).get("uses", "") != uses:
			continue
		count += barista.count_item(item_id)
		for ticket in tickets:
			# Items already on the pass have left stock; only the rest are owed.
			var placed := ticket.on_pass.filter(func(it: Dictionary) -> bool: return it["id"] == item_id).size()
			count -= ticket.items.count(item_id) - placed
	return count


## The oldest open ticket still missing this item.
func ticket_needing(id: String) -> Ticket:
	for ticket in tickets:
		if ticket.needs(id):
			return ticket
	return null


## Moves everything in the barista's hands that an order needs onto the pass.
func place_on_pass(barista_: Barista) -> bool:
	var placed := false
	for it in barista_.hands.duplicate():
		var ticket := ticket_needing(it["id"])
		if ticket:
			barista_.hands.erase(it)
			ticket.on_pass.append(it)
			placed = true
	if placed:
		Audio.play("place")
	_pass.refresh(tickets)
	return placed


## Called by a customer standing at pickup once their ticket is complete.
func collect_order(customer: Customer) -> void:
	var ticket := customer.ticket
	var tip := 0
	for it in ticket.on_pass:
		if CafeData.item(it["id"])["kind"] == "drink":
			tip += tip_per_quality[it["quality"]]
	if customer.patience_ratio() >= patience_tip_threshold:
		tip += 1
	day.tips += tip
	day.served += 1
	Audio.play("order_up")
	if tip > 0:
		Audio.play("tip")
	tickets.erase(ticket)
	_pass.refresh(tickets)
	float_text(_pass.focus_point() + Vector3.UP * 0.8, "#%d up!  +$%d tip" % [ticket.number, tip], Color(1, 0.9, 0.5))
	_release_pickup_spot(customer)
	customer.collect(_free_seat())


func _free_seat() -> Seat:
	var free := get_tree().get_nodes_in_group("seats").filter(func(s: Seat) -> bool: return s.customer == null)
	return free.pick_random() if not free.is_empty() else null


func on_walk_out(customer: Customer) -> void:
	day.walked_out += 1
	Audio.play("walk_out")
	if customer in _queue:
		_leave_queue(customer)
	if customer.ticket:
		tickets.erase(customer.ticket)
		_pass.refresh(tickets)
		_release_pickup_spot(customer)


func _on_customer_left(customer: Customer) -> void:
	_customers.erase(customer)


# --- Modal interactions -----------------------------------------------------
# The world keeps running during these: the line keeps growing while you
# fiddle with the espresso machine or chat at a table.

func choose(title: String, options: Array[Dictionary]) -> int:
	barista.busy = true
	camera.focus(barista.global_position)
	var choice := await hud.choice_panel.choose(title, options)
	camera.unfocus()
	barista.busy = false
	return choice


func play_drink_minigame(item_id: String) -> int:
	barista.busy = true
	camera.focus(barista.global_position)
	var quality := await hud.minigame.play(item_id)
	camera.unfocus()
	barista.busy = false
	return quality


func start_chat(customer: Customer) -> void:
	var data: Dictionary = CafeData.REGULARS[customer.regular_id]
	var texts := (data["choices"] as Array).map(func(c: Dictionary) -> String: return c["text"])
	barista.busy = true
	customer.in_conversation = true
	camera.focus(customer.global_position)
	Audio.duck_music(6.0)
	var pick := await hud.dialogue.ask(data["name"], data["opening"], texts)
	await hud.dialogue.say(data["name"], data["choices"][pick]["reply"])
	camera.unfocus()
	Audio.duck_music(0.0)
	customer.in_conversation = false
	barista.busy = false
	day.chats.append("%s: \"%s\"" % [data["name"], texts[pick]])


func toast(text: String) -> void:
	hud.toast(text)


# --- Cat events ---------------------------------------------------------------

## Picks the day's event start times: random within the window, spaced out.
func _schedule_cat_events() -> void:
	_event_times.clear()
	for attempt in 50:
		var times: Array[float] = []
		for i in cat_events_per_day:
			times.append(randf_range(cat_event_window.x, cat_event_window.y))
		times.sort()
		var spaced := true
		for i in range(1, times.size()):
			spaced = spaced and times[i] - times[i - 1] >= cat_event_min_gap
		if spaced:
			_event_times = times
			return
	# Couldn't space them randomly: spread them evenly instead.
	for i in cat_events_per_day:
		_event_times.append(lerpf(cat_event_window.x, cat_event_window.y, (i + 0.5) / cat_events_per_day))


## Starts the next event once its time comes, one at a time, waiting for free
## hands. Which kind is chosen then, from those that can happen right now.
func _update_cat_events() -> void:
	if _event_times.is_empty() or _active_event or _service_time < _event_times[0]:
		return
	if cat_events_wait_for_free_hands and barista.busy:
		return
	var kinds := CAT_EVENTS.duplicate()
	kinds.shuffle()
	for kind: GDScript in kinds:
		if _start_cat_event(kind):
			_event_times.pop_front()
			return
	# Nothing can happen right now (cats busy, say): try again shortly.
	_event_times[0] += 5.0


## Starts an event of this kind if it can happen now (and hasn't today).
func _start_cat_event(kind: GDScript) -> bool:
	var event: CatEvent = kind.new()
	event.cafe = self
	if event.mischief_id() in _events_done or not event.prepare():
		return false
	_events_done.append(event.mischief_id())
	_run_cat_event(event)
	return true


func _run_cat_event(event: CatEvent) -> void:
	_active_event = event
	for c in event.cats:
		c.claim(event)
	var line: String = await event.run()
	if not line.is_empty():
		day.cat_events.append(line)
	_active_event = null


## Cats free to get up to `mischief` (an id from their CafeData.CATS list).
func free_cats(mischief: String) -> Array[CafeCat]:
	var free: Array[CafeCat] = []
	for c in _cats:
		if c.event == null and c.on_floor() and mischief in c.mischief:
			free.append(c)
	return free


## Adds something an event brings into the room (a scuffle cloud, say).
func add_actor(node: Node3D) -> void:
	_actors.add_child(node)


## How fast waiting customers lose patience (1 = normal; more during a cat fight).
func patience_drain() -> float:
	return 1.0 + fight_intensity * fight_patience_drain


## Seated customers this close to `spot` leave early. Returns how many did.
func upset_seated_customers(spot: Vector3, radius: float) -> int:
	var count := 0
	for c in _customers.duplicate():
		if c.state == Customer.State.SEATED and not c.is_walking() and not c.in_conversation \
				and _flat_distance(c.global_position, spot) < radius:
			c.leave_early()
			count += 1
	day.left_early += count
	return count


## Where the croissants sit on the pastry case.
func pastry_case_shelf() -> Vector3:
	return $Stations/PastryCase/Croissant.global_position


func table_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spot: Node3D in get_tree().get_nodes_in_group("mug_spots"):
		positions.append(spot.get_parent().global_position)
	return positions


## A table top to knock a mug off, preferring tables with someone sitting there.
func pick_mug_spot() -> Vector3:
	var spots := get_tree().get_nodes_in_group("mug_spots")
	var occupied := spots.filter(func(m: Node3D) -> bool:
		for seat: Seat in get_tree().get_nodes_in_group("seats"):
			if seat.customer and seat.global_position.distance_to(m.global_position) < 1.2:
				return true
		return false)
	return (occupied if not occupied.is_empty() else spots).pick_random().global_position


func _end_day() -> void:
	phase = Phase.RESULTS
	barista.busy = true
	Audio.duck_music(8.0)
	Audio.play("day_close")
	# Second note of the closing chime, a fourth lower.
	get_tree().create_timer(0.45).timeout.connect(Audio.play.bind("day_close", -1.0, 0.75))
	if await hud.results_panel.run(day):
		get_tree().reload_current_scene()
	else:
		Game.go_to_title()
