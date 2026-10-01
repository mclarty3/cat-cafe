class_name Cafe
extends Node2D
## Runs one cafe day: morning prep, then service (customers, the regular, the
## cat event), then the end-of-day results. Day tuning is exported here.

enum Phase { PREP, SERVICE, RESULTS }

@export_group("Day")
@export var customers_per_day := 5
@export var first_customer_delay := 2.0
## Random gap between arrivals, in seconds (min, max).
@export var spawn_interval := Vector2(16.0, 24.0)
## Which arrival (0-based) is the regular.
@export var regular_index := 2
@export var regular_id := "theo"
## Seconds into service when Mochi goes for the mug.
@export var mug_event_time := 45.0
## If on, Mochi waits until you aren't in a menu/minigame/chat before going for
## the mug, so the event is a choice rather than bad luck.
@export var cat_events_wait_for_free_hands := true

@export_group("Customers")
@export var customer_walk_speed := 60.0
@export var order_patience := 45.0
@export var food_patience := 70.0
@export var patience_per_item := 15.0
@export var eat_time := 6.0
## Regulars stay longer so there's time to chat.
@export var regular_linger_time := 20.0
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
var aisle_x: float:
	get:
		return _door.global_position.x

var _spawned := 0
var _spawn_timer := 0.0
var _service_time := 0.0
var _mug_event_started := false
var _customers: Array[Customer] = []

@onready var hud: CafeHud = $HUD
@onready var barista: Barista = $Barista
@onready var _actors: Node2D = $Actors
@onready var _door: Marker2D = $Door
@onready var _mug_spot: Marker2D = $MugSpot
@onready var _cat: CafeCat = $Actors/Mochi


func _ready() -> void:
	add_to_group("cafe")
	barista.cafe = self
	hud.cafe = self
	_cat.mug_event_finished.connect(_on_mug_event_finished)

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
			# No free seat: try again shortly.
			_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y) if _try_spawn() else 1.0

	if not _mug_event_started and _service_time >= mug_event_time 			and not (cat_events_wait_for_free_hands and barista.busy):
		_mug_event_started = true
		_cat.start_mug_event(_mug_spot.global_position)
		toast("%s is eyeing a mug on the counter..." % _cat.cat_name)

	var mug_settled := _mug_event_started and _cat.state != CafeCat.State.TO_COUNTER \
		and _cat.state != CafeCat.State.NUDGING
	if _spawned >= customers_per_day and _customers.is_empty() and mug_settled:
		_end_day()


func customers_arrived() -> int:
	return _spawned


func waiting_customers() -> Array[Customer]:
	return _customers.filter(func(c: Customer) -> bool: return c.is_waiting())


func door_position() -> Vector2:
	return _door.global_position


func _try_spawn() -> bool:
	var free := get_tree().get_nodes_in_group("seats").filter(func(s: Seat) -> bool: return s.customer == null)
	if free.is_empty():
		return false
	var customer := Customer.new()
	_actors.add_child(customer)
	customer.setup(self, free.pick_random(), door_position(), regular_id if _spawned == regular_index else "")
	customer.left_cafe.connect(_on_customer_left)
	_customers.append(customer)
	_spawned += 1
	return true


func _on_customer_left(customer: Customer) -> void:
	_customers.erase(customer)


# --- Orders & money ---------------------------------------------------------

func create_order(customer: Customer) -> Array[String]:
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
## already on the tray, minus what's owed to waiting customers.
func _available(id: String) -> int:
	var uses: String = CafeData.item(id).get("uses", "")
	if uses.is_empty():
		return 999
	var count: int = day.stock[uses]
	for item_id in CafeData.ITEMS:
		if CafeData.item(item_id).get("uses", "") == uses:
			count += barista.count_item(item_id)
	for customer in waiting_customers():
		for item_id in customer.remaining_items():
			if CafeData.item(item_id).get("uses", "") == uses:
				count -= 1
	return count


func pay(customer: Customer) -> int:
	var price := 0
	var tip := 0
	for it in customer.delivered:
		var data := CafeData.item(it["id"])
		price += data["price"]
		if data["kind"] == "drink":
			tip += tip_per_quality[it["quality"]]
	if customer.patience_ratio() >= patience_tip_threshold:
		tip += 1
	day.earnings += price
	day.tips += tip
	day.served += 1
	return price + tip


func on_walk_out(_customer: Customer) -> void:
	day.walked_out += 1


# --- Modal interactions -----------------------------------------------------
# The world keeps running during these: customers stay impatient while you
# fiddle with the espresso machine or chat.

func choose(title: String, options: Array[Dictionary]) -> int:
	barista.busy = true
	var choice := await hud.choice_panel.choose(title, options)
	barista.busy = false
	return choice


func play_drink_minigame(item_id: String) -> int:
	barista.busy = true
	var quality := await hud.minigame.play(item_id)
	barista.busy = false
	return quality


func start_chat(customer: Customer) -> void:
	var data: Dictionary = CafeData.REGULARS[customer.regular_id]
	var texts := (data["choices"] as Array).map(func(c: Dictionary) -> String: return c["text"])
	barista.busy = true
	customer.in_conversation = true
	var pick := await hud.dialogue.ask(data["name"], data["opening"], texts)
	await hud.dialogue.say(data["name"], data["choices"][pick]["reply"])
	customer.in_conversation = false
	barista.busy = false
	day.chats.append("%s: \"%s\"" % [data["name"], texts[pick]])


func toast(text: String) -> void:
	hud.toast(text)


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


func _draw() -> void:
	# Wooden floor.
	draw_rect(Rect2(0, 0, 640, 360), Color(0.36, 0.25, 0.19))
	for y in range(16, 360, 24):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.3, 0.2, 0.15), 1.0)
	# Rug by the door.
	draw_rect(Rect2(288, 318, 64, 26), Color(0.55, 0.3, 0.28))
