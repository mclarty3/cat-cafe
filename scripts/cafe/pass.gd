@tool
class_name Pass
extends Station
## The hand-off shelf. Put what you're carrying here; each item goes to the
## oldest ticket that needs it. Customers collect complete orders themselves.

## How far apart the items on display sit along the counter.
@export var display_spacing := 0.16
## Height of the counter top the items sit on.
@export var display_height := 0.45

var _display: Node3D


func _ready() -> void:
	super()
	_display = Node3D.new()
	add_child(_display)


func get_prompt(barista: Barista) -> String:
	for it in barista.hands:
		if cafe.ticket_needing(it["id"]):
			return "Put on the pass"
	return ""


func interact(barista: Barista) -> void:
	if not cafe.place_on_pass(barista):
		cafe.toast("No order needs that.")


## Shows the items waiting on the pass as little 3D models.
func refresh(tickets: Array[Ticket]) -> void:
	for child in _display.get_children():
		child.queue_free()
	var items: Array[Dictionary] = []
	for ticket in tickets:
		items.append_array(ticket.on_pass)
	for i in items.size():
		var model := Prop3D.new()
		var data := CafeData.item(items[i]["id"])
		_display.add_child(model)
		model.model_scale = data.get("model_scale", 0.35)
		model.model = load(data["model"])
		model.position = Vector3((i - (items.size() - 1) / 2.0) * display_spacing, display_height, 0.2)
