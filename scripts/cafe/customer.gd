class_name Customer
extends Interactable
## Walks in, sits, waits to order, waits for food, eats, pays and leaves.
## Walks out without paying if patience runs out. Regulars can be chatted with
## while they eat.

signal left_cafe(customer: Customer)

enum State { ARRIVING, WAITING_TO_ORDER, WAITING_FOR_FOOD, EATING, LEAVING }

const BAR_WIDTH := 20.0

var cafe: Cafe
var seat: Seat
var display_name := "Customer"
## Empty for walk-ins; a key into CafeData.REGULARS otherwise.
var regular_id := ""
var order: Array[String] = []
var delivered: Array[Dictionary] = []
var state := State.ARRIVING
var chatted := false
## Set by the cafe while chatting, so the regular doesn't leave mid-sentence.
var in_conversation := false

var _model: AnimatedModel
var _path: Array[Vector3] = []
var _patience := 0.0
var _patience_max := 1.0
var _eat_timer := 0.0


func _ready() -> void:
	super()
	sphere_shape(self, 0.3, Vector3(0, 0.4, 0))


func setup(p_cafe: Cafe, p_seat: Seat, p_regular_id := "") -> void:
	cafe = p_cafe
	seat = p_seat
	seat.customer = self
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
	_path = cafe.path_to_seat(seat)
	OverlayAnchor.attach(self, cafe.overlay, 1.0)


func is_regular() -> bool:
	return not regular_id.is_empty()


func is_waiting() -> bool:
	return state == State.WAITING_TO_ORDER or state == State.WAITING_FOR_FOOD


## Order items not yet delivered.
func remaining_items() -> Array[String]:
	var left: Array[String] = order.duplicate()
	for it in delivered:
		left.erase(it["id"])
	return left


func _process(delta: float) -> void:
	match state:
		State.ARRIVING, State.LEAVING:
			_follow_path(delta)
		State.WAITING_TO_ORDER, State.WAITING_FOR_FOOD:
			_patience -= delta
			if _patience <= 0.0:
				_walk_out()
		State.EATING:
			if not in_conversation:
				_eat_timer -= delta
			if _eat_timer <= 0.0:
				_pay_and_leave()


func _follow_path(delta: float) -> void:
	if _path.is_empty():
		return
	var to_next := _path[0] - global_position
	_model.face(to_next)
	_model.play("walk")
	global_position = global_position.move_toward(_path[0], cafe.customer_walk_speed * delta)
	if global_position.distance_to(_path[0]) < 0.01:
		_path.remove_at(0)
		if _path.is_empty():
			_arrive()


func _arrive() -> void:
	if state == State.ARRIVING:
		state = State.WAITING_TO_ORDER
		_set_patience(cafe.order_patience)
		global_position = seat.global_position + Vector3.UP * cafe.sit_height
		_model.face_yaw(seat.facing_yaw(), true)
		_model.play("sit")
	else:
		left_cafe.emit(self)
		queue_free()


func _set_patience(seconds: float) -> void:
	_patience = seconds
	_patience_max = seconds


func get_prompt(barista: Barista) -> String:
	match state:
		State.WAITING_TO_ORDER:
			return "Take %s's order" % display_name if is_regular() else "Take order"
		State.WAITING_FOR_FOOD:
			for id in remaining_items():
				if barista.count_item(id) > 0:
					return "Serve"
		State.EATING:
			if is_regular() and not chatted:
				return "Chat with %s" % display_name
	return ""


func interact(barista: Barista) -> void:
	match state:
		State.WAITING_TO_ORDER:
			order = cafe.create_order(self)
			state = State.WAITING_FOR_FOOD
			_set_patience(cafe.food_patience + cafe.patience_per_item * order.size())
		State.WAITING_FOR_FOOD:
			for id in remaining_items():
				var it := barista.take_item(id)
				if not it.is_empty():
					delivered.append(it)
			if remaining_items().is_empty():
				state = State.EATING
				_eat_timer = cafe.regular_linger_time if is_regular() else cafe.eat_time
		State.EATING:
			if is_regular() and not chatted:
				chatted = true
				cafe.start_chat(self)


func patience_ratio() -> float:
	return clampf(_patience / _patience_max, 0.0, 1.0)


func _pay_and_leave() -> void:
	var paid := cafe.pay(self)
	cafe.float_text(global_position + Vector3.UP * 1.1, "+$%d" % paid, Color(1, 0.9, 0.5))
	if is_regular() and not chatted:
		cafe.day.missed_chats.append(CafeData.REGULARS[regular_id]["skipped"])
	_leave()


func _walk_out() -> void:
	cafe.on_walk_out(self)
	cafe.float_text(global_position + Vector3.UP * 1.1, "Hmph!", Color(1, 0.5, 0.5))
	if is_regular():
		cafe.day.missed_chats.append(CafeData.REGULARS[regular_id]["skipped"])
	_leave()


func _leave() -> void:
	state = State.LEAVING
	seat.customer = null
	global_position = seat.global_position
	_path = cafe.path_from_seat(seat)


func _draw_overlay(canvas: OverlayAnchor) -> void:
	if is_regular():
		canvas.text_centered(display_name, Vector2(0, 50), 8, Color(1, 1, 1, 0.9), 3)

	match state:
		State.WAITING_TO_ORDER:
			canvas.bubble(Rect2(-6, -16, 12, 14))
			canvas.text_centered("!", Vector2(0, -5), 10, Color(0.2, 0.15, 0.1))
			canvas.meter(Rect2(-BAR_WIDTH / 2.0, 3, BAR_WIDTH, 3), patience_ratio())
		State.WAITING_FOR_FOOD:
			var items := remaining_items()
			var w := items.size() * 9.0 + 4.0
			canvas.bubble(Rect2(-w / 2.0, -16, w, 14))
			for i in items.size():
				var x := (i - (items.size() - 1) / 2.0) * 9.0
				canvas.draw_circle(Vector2(x, -9), 3.5, CafeData.item(items[i])["color"])
			canvas.meter(Rect2(-BAR_WIDTH / 2.0, 3, BAR_WIDTH, 3), patience_ratio())
		State.EATING:
			if is_regular() and not chatted:
				canvas.bubble(Rect2(-9, -16, 18, 14))
				canvas.text_centered("...", Vector2(0, -6), 10, Color(0.2, 0.15, 0.1))
