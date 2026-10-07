class_name Customer
extends Interactable
## Counter-service customer: queues at the register, orders, waits at the
## pickup spot, collects from the pass, sits for a while, then leaves.
## They carry their order from the pass (drink in the right hand where there is
## one), and while seated sip the drink and eat the pastry a bite at a time,
## spread over their stay. The drink goes down with each sip and the pastry is
## finished by the end; on the way out they drop the empty cup in the bin by
## the door. Customers taking it to go (no free table) carry it out full.
## Walks out if kept waiting too long. Regulars can be chatted with at their
## table (you have to leave the counter for that).

signal left_cafe(customer: Customer)

enum State { QUEUED, WAITING_PICKUP, SEATED, LEAVING }

const BAR_WIDTH := 20.0
## Sips of a drink and bites of a pastry over a stay at a table.
const SIPS := 3
const BITES := 3
## Seconds to raise to the mouth, hold there, and lower again.
const LIFT_TIME := 0.35
const MOUTH_TIME := 0.45

var cafe: Cafe
var display_name := "Customer"
## Empty for walk-ins; a key into CafeData.REGULARS otherwise.
var regular_id := ""
var state := State.QUEUED
var ticket: Ticket
var seat: Seat
## The pickup spot we hold (index into the cafe's markers), or -1.
var pickup_index := -1
var chatted := false
## Set by the cafe while chatting, so the regular doesn't leave mid-sentence.
var in_conversation := false

var _model: AnimatedModel
var _path: Array[Vector3] = []
var _velocity := Vector3.ZERO
var _patience := 0.0
var _patience_max := 1.0
var _linger_timer := 0.0

## What we're holding: {"model": ItemModel, "arm": bone name, "bites": int}
## ("bites" left for a pastry; a drink just gets sipped).
var _held: Array[Dictionary] = []
## Seated: which held item each sip or bite uses (indices into _held), and
## when the next one starts (seconds of stay left).
var _snacks: Array[int] = []
var _next_snack_at := 0.0
var _snacking := false
## Seated: the table top's height. Held items never sink below it, so they rest
## on the table rather than vanishing under it.
var _table_top := -INF
## Leaving: heading to the bin first to drop what's left of the order.
var _to_bin := false


func _ready() -> void:
	super()
	sphere_shape(self, 0.3, Vector3(0, 0.4, 0))


func setup(p_cafe: Cafe, p_regular_id := "") -> void:
	cafe = p_cafe
	regular_id = p_regular_id
	var model_path: String
	if is_regular():
		var data: Dictionary = CafeData.REGULARS[regular_id]
		display_name = data["name"]
		model_path = data["model"]
	else:
		model_path = CafeData.WALK_IN_MODELS.pick_random()
	_model = AnimatedModel.new()
	_model.model_scale = cafe.character_scale
	add_child(_model)
	_model.model = load(model_path)
	_model.posed.connect(_place_held)
	global_position = cafe.door_outside()
	_set_patience(cafe.queue_patience)
	OverlayAnchor.attach(self, cafe.overlay, 1.0)


func is_regular() -> bool:
	return not regular_id.is_empty()


func is_walking() -> bool:
	return not _path.is_empty()


## Ready to order: in line and standing still (the cafe checks who's first).
func can_order() -> bool:
	return state == State.QUEUED and not is_walking()


## How we're moving right now (zero when standing), for others' avoidance.
func walk_velocity() -> Vector3:
	return _velocity if not _path.is_empty() else Vector3.ZERO


func walk_to(target: Vector3) -> void:
	_path = cafe.find_path(global_position, target)


# --- Called by the cafe -------------------------------------------------------

## The cafe then sends us to a pickup spot.
func on_ordered(p_ticket: Ticket) -> void:
	ticket = p_ticket
	state = State.WAITING_PICKUP
	_set_patience(cafe.pickup_patience + cafe.patience_per_item * ticket.items.size())


## The order is complete on the pass and we're there to take it.
## `p_seat` is null when every table is taken: they leave with it to go.
func collect(p_seat: Seat) -> void:
	_take_order()
	if p_seat == null:
		_leave()
		return
	seat = p_seat
	seat.customer = self
	state = State.SEATED
	_linger_timer = cafe.regular_linger_time if is_regular() else cafe.linger_time
	_plan_snacks()
	walk_to(seat.global_position)


func patience_ratio() -> float:
	return clampf(_patience / _patience_max, 0.0, 1.0)


# --- Behaviour ------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_walking():
		_follow_path(delta)

	match state:
		State.QUEUED, State.WAITING_PICKUP:
			_patience -= delta * cafe.patience_drain()
			if _patience <= 0.0:
				_walk_out()
			elif not is_walking():
				_model.play("idle")
				if state == State.WAITING_PICKUP and ticket.is_complete():
					cafe.collect_order(self)
		State.SEATED:
			if not is_walking() and not in_conversation:
				_linger_timer -= delta
				if not _snacking and not _snacks.is_empty() and _linger_timer <= _next_snack_at:
					_snack()
				if _linger_timer <= 0.0 and not _snacking:
					_leave()


func _follow_path(delta: float) -> void:
	_velocity = cafe.step_along(self, _path, _velocity, cafe.customer_walk_speed, delta)
	_model.face(_velocity)
	_model.play("walk")
	if _path.is_empty():
		_arrive()


func _arrive() -> void:
	match state:
		State.SEATED:
			global_position = seat.global_position + Vector3.UP * cafe.sit_height
			_model.face_yaw(seat.facing_yaw(), true)
			_model.play("sit")
			_table_top = cafe.table_top_near(seat.global_position)
		State.LEAVING:
			if _to_bin:
				_drop_in_bin()
				return
			left_cafe.emit(self)
			queue_free()
		_:
			# In line or at pickup: face the counter.
			_model.face(Vector3.FORWARD)


## Gets up from the table and goes (a cat fight that ran on too long, say).
func leave_early() -> void:
	cafe.float_text(global_position + Vector3.UP * 1.1, "Too noisy...", Color(1, 0.75, 0.5))
	_leave()


func _walk_out() -> void:
	cafe.on_walk_out(self)
	cafe.float_text(global_position + Vector3.UP * 1.1, "Hmph!", Color(1, 0.5, 0.5))
	_leave()


## At the register with nothing left on the menu: leave without ordering.
func turn_away() -> void:
	cafe.float_text(global_position + Vector3.UP * 1.1, "All sold out...", Color(1, 0.75, 0.5))
	_leave()


func _leave() -> void:
	if is_regular() and not chatted:
		cafe.day.missed_chats.append(CafeData.REGULARS[regular_id]["skipped"])
	# Sat in: anything still in hand goes in the bin on the way out.
	_to_bin = seat != null and not _held.is_empty()
	if seat:
		global_position = seat.global_position
		seat.customer = null
	_table_top = -INF
	state = State.LEAVING
	walk_to(cafe.cup_bin_point() if _to_bin else cafe.door_outside())


func _drop_in_bin() -> void:
	_to_bin = false
	# The bin is just behind the spot, toward the front of the room.
	_model.face(Vector3.BACK)
	for h in _held:
		h["model"].queue_free()
	_held.clear()
	_update_arms()
	Audio.play("trash", -8.0)
	walk_to(cafe.door_outside())


# --- The order in hand ------------------------------------------------------------

## Picks the order up off the pass: the drink in the right hand where there is
## one, the pastry in the other.
func _take_order() -> void:
	var ids := ticket.items.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return CafeData.item(a)["kind"] == "drink" and CafeData.item(b)["kind"] != "drink")
	for i in ids.size():
		var model := ItemModel.create(ids[i], cafe.barista.held_scale)
		model.top_level = true
		add_child(model)
		var pastry: bool = CafeData.item(ids[i])["kind"] == "pastry"
		_held.append({"model": model, "arm": "arm-right" if i % 2 == 0 else "arm-left",
			"bites": BITES if pastry else 0, "sips": 0 if pastry else SIPS})
	_update_arms()


## Arms holding something stay out front.
func _update_arms() -> void:
	var arms := _held.map(func(h: Dictionary) -> String: return h["arm"])
	if arms.is_empty():
		_model.hold_arms("")
	elif arms.size() == 1:
		var arm: String = arms[0]
		_model.hold_arms("holding-right" if arm == "arm-right" else "holding-left", [arm])
	else:
		_model.hold_arms("holding-both")


## Each held item in its fist, upright and facing where we face (see Barista._place_held()).
func _place_held() -> void:
	var facing := Basis(Vector3.UP, _model.global_rotation.y)
	for h in _held:
		var fist := _model.hand_position(h["arm"])
		var size: float = maxf(h.get("size", 1.0), 0.01)
		var at := fist + facing.z * cafe.barista.grip_forward + Vector3.DOWN * cafe.barista.grip_depth
		at.y = maxf(at.y, _table_top)
		(h["model"] as ItemModel).global_transform = Transform3D(facing.scaled(Vector3.ONE * size), at)


## Spreads the sips and bites evenly over the stay, alternating between the
## drink and the pastry, starting a moment after sitting down.
func _plan_snacks() -> void:
	_snacks.clear()
	var per_item: Array[int] = []
	for h in _held:
		per_item.append(BITES if h["bites"] > 0 else SIPS)
	for turn in per_item.max() if not per_item.is_empty() else 0:
		for i in _held.size():
			if turn < per_item[i]:
				_snacks.append(i)
	_next_snack_at = _linger_timer * (1.0 - 1.0 / (_snacks.size() + 1)) if not _snacks.is_empty() else 0.0


## One sip or bite: up to the mouth, a pause, and back down. A pastry gets
## smaller with each bite and is gone after the last.
func _snack() -> void:
	var item: Dictionary = _held[_snacks.pop_front()]
	var gap := _linger_timer / (_snacks.size() + 1)
	_next_snack_at = _linger_timer - gap
	_snacking = true
	var arm: String = item["arm"]
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _model.lift_arm(arm, v), 0.0, 1.0, LIFT_TIME) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_interval(MOUTH_TIME)
	if item["bites"] > 0:
		tween.tween_callback(_bite.bind(item))
	else:
		tween.tween_callback(_sip.bind(item))
	tween.tween_method(func(v: float) -> void: _model.lift_arm(arm, v), 1.0, 0.0, LIFT_TIME) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_snacking = false
		if item.get("eaten", false):
			_finish_item(item))


## A sip: the drink goes down, and the last one empties the cup.
func _sip(item: Dictionary) -> void:
	item["sips"] = maxi(item["sips"] - 1, 0)
	(item["model"] as ItemModel).set_fill(float(item["sips"]) / SIPS)


## A bite: the pastry shrinks, and the last one finishes it.
func _bite(item: Dictionary) -> void:
	item["bites"] -= 1
	Audio.play("munch", -6.0, 1.3)
	item["size"] = float(item["bites"]) / BITES
	if item["bites"] == 0:
		item["eaten"] = true


## Puts away a finished pastry: its hand comes down, and the sips still to come
## point at the right item again.
func _finish_item(item: Dictionary) -> void:
	var index := _held.find(item)
	item["model"].queue_free()
	_held.remove_at(index)
	var remaining: Array[int] = []
	for i in _snacks:
		if i != index:
			remaining.append(i - 1 if i > index else i)
	_snacks = remaining
	_update_arms()


# --- Interaction (only regulars, at their table) -----------------------------------

func get_prompt(_barista: Barista) -> String:
	if state == State.SEATED and not is_walking() and is_regular() and not chatted:
		return "Chat with %s" % display_name
	return ""


func marker_point() -> Vector3:
	return global_position + Vector3.UP * 1.35


func interact(barista: Barista) -> void:
	if get_prompt(barista).is_empty():
		return
	chatted = true
	cafe.start_chat(self)


func _draw_overlay(canvas: OverlayAnchor) -> void:
	if is_regular():
		canvas.text_centered(display_name, Vector2(0, 50), 8, Color(1, 1, 1, 0.9), 3)

	match state:
		State.QUEUED:
			if cafe.front_of_queue() == self:
				canvas.bubble(Rect2(-6, -16, 12, 14))
				canvas.text_centered("!", Vector2(0, -5), 10, Color(0.2, 0.15, 0.1))
			canvas.meter(Rect2(-BAR_WIDTH / 2.0, 3, BAR_WIDTH, 3), patience_ratio())
		State.WAITING_PICKUP:
			var items := ticket.items
			var missing := ticket.remaining()
			var w := items.size() * 9.0 + 4.0
			canvas.bubble(Rect2(-w / 2.0, -16, w, 14))
			for i in items.size():
				var x := (i - (items.size() - 1) / 2.0) * 9.0
				var color: Color = CafeData.item(items[i])["color"]
				# Items already on the pass are shown faded.
				var waiting := items[i] in missing
				missing.erase(items[i])
				canvas.draw_circle(Vector2(x, -9), 3.5, Color(color, 1.0 if waiting else 0.3))
			canvas.text_centered("#%d" % ticket.number, Vector2(0, -19), 7, Color(1, 1, 1, 0.9), 3)
			canvas.meter(Rect2(-BAR_WIDTH / 2.0, 3, BAR_WIDTH, 3), patience_ratio())
		State.SEATED:
			if is_regular() and not chatted and not is_walking():
				canvas.bubble(Rect2(-9, -16, 18, 14))
				canvas.text_centered("...", Vector2(0, -6), 10, Color(0.2, 0.15, 0.1))


func _set_patience(seconds: float) -> void:
	_patience = seconds
	_patience_max = seconds
