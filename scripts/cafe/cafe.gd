class_name Cafe
extends Node3D
## Runs one counter-service cafe day: morning prep, then service, then the
## end-of-day results. Customers queue at the register, wait at the pickup spot
## while you carry their order to the pass, then sit for a while. Day tuning is
## exported here.

enum Phase { PREP, SERVICE, RESULTS }

@export_group("Day")
@export var customers_per_day := 5
@export var first_customer_delay := 2.0
## Random gap between arrivals, in seconds (min, max).
@export var spawn_interval := Vector2(16.0, 24.0)
## Which arrival (0-based) is the regular.
@export var regular_index := 2
@export var regular_id := "theo"
## Seconds into service when Mochi goes for a mug on a table.
@export var mug_event_time := 45.0
## If on, Mochi waits until you aren't in a menu/minigame/chat before going for
## the mug, so the event is a choice rather than bad luck.
@export var cat_events_wait_for_free_hands := true

@export_group("Customers")
@export var customer_walk_speed := 1.4
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

@export_group("Money")
## Tip per drink by quality: poor, good, perfect.
@export var tip_per_quality: Array[int] = [0, 1, 3]
## Bonus tip if the customer still had at least this much patience left.
@export_range(0.0, 1.0) var patience_tip_threshold := 0.5
@export var mug_cost := 2

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
var _mug_event_started := false
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
@onready var _pass: Pass = $Stations/Pass
@onready var _navigation: NavigationRegion3D = $Navigation
@onready var _cat: CafeCat = $Actors/Mochi


func _enter_tree() -> void:
	# Joined before children are ready, so they can find the cafe in their _ready.
	add_to_group("cafe")


func _ready() -> void:
	barista.cafe = self
	OverlayAnchor.attach(barista, overlay, 1.0)
	OverlayAnchor.attach(barista.focus_marker, overlay, 0.0)
	camera.follow_target = barista
	hud.cafe = self
	_cat.mug_event_finished.connect(_on_mug_event_finished)
	# Built from the furniture colliders at runtime, so rearranging the room
	# in the editor just works.
	_navigation.bake_navigation_mesh(false)

	barista.busy = true
	await hud.prep_panel.run(day)
	barista.busy = false
	phase = Phase.SERVICE
	_spawn_timer = first_customer_delay
	toast("The cafe is open!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (not barista.busy or phase == Phase.PREP):
		Game.go_to_title()


func _process(delta: float) -> void:
	if phase != Phase.SERVICE:
		return
	_service_time += delta

	if _spawned < customers_per_day:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			# Line is full: try again shortly.
			_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y) if _try_spawn() else 1.0

	if not _mug_event_started and _service_time >= mug_event_time \
			and not (cat_events_wait_for_free_hands and barista.busy):
		_mug_event_started = true
		_cat.start_mug_event(_pick_mug_spot())
		toast("%s is eyeing a mug on a table..." % _cat.cat_name)

	var mug_settled := _mug_event_started and _cat.state != CafeCat.State.TO_MUG \
		and _cat.state != CafeCat.State.NUDGING
	if _spawned >= customers_per_day and _customers.is_empty() and mug_settled:
		_end_day()


func customers_arrived() -> int:
	return _spawned


func door_outside() -> Vector3:
	return _door.global_position


## A walkable route around the furniture, ending exactly at `to`.
func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var map := get_world_3d().navigation_map
	var points := NavigationServer3D.map_get_path(map, from, to, true)
	var path: Array[Vector3] = []
	for p in points:
		path.append(Vector3(p.x, 0.0, p.z))
	if not path.is_empty() and path[0].distance_to(from) < 0.05:
		path.remove_at(0)
	# Seats sit right against tables, inside the walkable edge: finish the hop.
	if path.is_empty() or path[-1].distance_to(to) > 0.02:
		path.append(to)
	return path


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
	float_text(register_position, "+$%d" % price, Color(1, 0.9, 0.5))
	if customer.is_regular():
		toast("%s: \"%s\"" % [customer.display_name, CafeData.REGULARS[customer.regular_id]["greeting"]])

	_leave_queue(customer)
	customer.on_ordered(ticket, _free_pickup_spot())


func _free_pickup_spot() -> Vector3:
	var waiting := tickets.size() - 1
	var spot: Marker3D = _pickup_spots[mini(waiting, _pickup_spots.size() - 1)]
	return spot.global_position


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
	tickets.erase(ticket)
	_pass.refresh(tickets)
	float_text(_pass.focus_point() + Vector3.UP * 0.8, "#%d up!  +$%d tip" % [ticket.number, tip], Color(1, 0.9, 0.5))
	customer.collect(_free_seat())


func _free_seat() -> Seat:
	var free := get_tree().get_nodes_in_group("seats").filter(func(s: Seat) -> bool: return s.customer == null)
	return free.pick_random() if not free.is_empty() else null


func on_walk_out(customer: Customer) -> void:
	day.walked_out += 1
	if customer in _queue:
		_leave_queue(customer)
	if customer.ticket:
		tickets.erase(customer.ticket)
		_pass.refresh(tickets)


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
	var pick := await hud.dialogue.ask(data["name"], data["opening"], texts)
	await hud.dialogue.say(data["name"], data["choices"][pick]["reply"])
	camera.unfocus()
	customer.in_conversation = false
	barista.busy = false
	day.chats.append("%s: \"%s\"" % [data["name"], texts[pick]])


func toast(text: String) -> void:
	hud.toast(text)


# --- Cat event ----------------------------------------------------------------

## A table top to knock a mug off, preferring tables with someone sitting there.
func _pick_mug_spot() -> Vector3:
	var spots := get_tree().get_nodes_in_group("mug_spots")
	var occupied := spots.filter(func(m: Node3D) -> bool:
		for seat: Seat in get_tree().get_nodes_in_group("seats"):
			if seat.customer and seat.global_position.distance_to(m.global_position) < 1.2:
				return true
		return false)
	return (occupied if not occupied.is_empty() else spots).pick_random().global_position


func _on_mug_event_finished(caught: bool) -> void:
	day.mug_result = "caught" if caught else "broken"
	if not caught:
		day.breakage += mug_cost


func _end_day() -> void:
	phase = Phase.RESULTS
	barista.busy = true
	if await hud.results_panel.run(day):
		get_tree().reload_current_scene()
	else:
		Game.go_to_title()
