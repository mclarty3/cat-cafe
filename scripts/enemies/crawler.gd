class_name Crawler
extends CharacterBody2D
## Basic nightmare enemy: patrols back and forth, turns at walls and ledges,
## hurts on contact (via its Hitbox child), and gets knocked back when hit.

@export var max_health := 3
@export var speed := 40.0
@export var gravity := 1200.0
@export_enum("Left:-1", "Right:1") var start_direction := -1
## How quickly knockback bleeds off.
@export var knockback_friction := 900.0
@export var stun_time := 0.2

var _health := 0
var _direction := -1
var _stun_timer := 0.0
var _flash_timer := 0.0

@onready var _ledge_ray: RayCast2D = $LedgeRay


func _ready() -> void:
	_health = max_health
	_direction = start_direction


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, 600.0)
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	else:
		_patrol()
	move_and_slide()
	queue_redraw()


func _patrol() -> void:
	if is_on_wall() and signf(get_wall_normal().x) == -_direction:
		_direction = -_direction
	elif is_on_floor():
		_ledge_ray.position.x = _direction * 10.0
		_ledge_ray.force_raycast_update()
		if not _ledge_ray.is_colliding():
			_direction = -_direction
	_ledge_ray.position.x = _direction * 10.0
	velocity.x = _direction * speed


func take_hit(damage: int, knockback: Vector2) -> void:
	_health -= damage
	_flash_timer = 0.1
	_stun_timer = stun_time
	velocity = knockback
	if _health <= 0:
		Poof.spawn(get_parent(), global_position + Vector2(0, -6), 24.0, Color("b58cff"))
		Game.shake(3.0)
		queue_free()


func _draw() -> void:
	var body := Color.WHITE if _flash_timer > 0.0 else Color("4a2f6b")
	draw_rect(Rect2(-9, -12, 18, 12), body)
	var eye := Color("ff5a8a")
	draw_rect(Rect2(_direction * 4.0 - 1.0, -9.0, 2.0, 2.0), eye)
	draw_rect(Rect2(_direction * 7.0 - 1.0, -9.0, 2.0, 2.0), eye)
