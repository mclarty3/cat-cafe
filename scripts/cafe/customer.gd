class_name Customer
extends Interactable
## Counter-service customer: queues at the register, orders, waits at the
## pickup spot, collects from the pass, sits for a while, then leaves.
## Walks out if kept waiting too long. Regulars can be chatted with at their
## table (you have to leave the counter for that).

signal left_cafe(customer: Customer)

enum State { QUEUED, WAITING_PICKUP, SEATED, LEAVING }

const BAR_WIDTH := 20.0

var cafe: Cafe
var display_name := "Customer"
## Empty for walk-ins; a key into CafeData.REGULARS otherwise.
var regular_id := ""
var state := State.QUEUED
var ticket: Ticket
var seat: Seat
var chatted := false
## Set by the cafe while chatting, so the regular doesn't leave mid-sentence.
var in_conversation := false

var _model: AnimatedModel
var _path: Array[Vector3] = []
var _patience := 0.0
var _patience_max := 1.0
var _linger_timer := 0.0


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


func walk_to(target: Vector3) -> void:
	_path = cafe.find_path(global_position, target)


# --- Called by the cafe -------------------------------------------------------

func on_ordered(p_ticket: Ticket, pickup_spot: Vector3) -> void:
	ticket = p_ticket
	state = State.WAITING_PICKUP
	_set_patience(cafe.pickup_patience + cafe.patience_per_item * ticket.items.size())
	walk_to(pickup_spot)


## The order is complete on the pass and we're there to take it.
## `p_seat` is null when every table is taken: they leave with it to go.
func collect(p_seat: Seat) -> void:
	if p_seat == null:
		_leave()
		return
	seat = p_seat
	seat.customer = self
	state = State.SEATED
	_linger_timer = cafe.regular_linger_time if is_regular() else cafe.linger_time
	walk_to(seat.global_position)


func patience_ratio() -> float:
	return clampf(_patience / _patience_max, 0.0, 1.0)


# --- Behaviour ------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_walking():
		_follow_path(delta)

	match state:
		State.QUEUED, State.WAITING_PICKUP:
			_patience -= delta
			if _patience <= 0.0:
				_walk_out()
			elif not is_walking():
				_model.play("idle")
				if state == State.WAITING_PICKUP and ticket.is_complete():
					cafe.collect_order(self)
		State.SEATED:
			if not is_walking() and not in_conversation:
				_linger_timer -= delta
				if _linger_timer <= 0.0:
					_leave()


func _follow_path(delta: float) -> void:
	_model.face(_path[0] - global_position)
	_model.play("walk")
	global_position = global_position.move_toward(_path[0], cafe.customer_walk_speed * delta)
	if global_position.distance_to(_path[0]) < 0.01:
		_path.remove_at(0)
		if _path.is_empty():
			_arrive()


func _arrive() -> void:
	match state:
		State.SEATED:
			global_position = seat.global_position + Vector3.UP * cafe.sit_height
			_model.face_yaw(seat.facing_yaw(), true)
			_model.play("sit")
		State.LEAVING:
			left_cafe.emit(self)
			queue_free()
		_:
			# In line or at pickup: face the counter.
			_model.face(Vector3.FORWARD)


func _walk_out() -> void:
	cafe.on_walk_out(self)
	cafe.float_text(global_position + Vector3.UP * 1.1, "Hmph!", Color(1, 0.5, 0.5))
	_leave()


func _leave() -> void:
	if is_regular() and not chatted:
		cafe.day.missed_chats.append(CafeData.REGULARS[regular_id]["skipped"])
	if seat:
		global_position = seat.global_position
		seat.customer = null
	state = State.LEAVING
	walk_to(cafe.door_outside())


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
