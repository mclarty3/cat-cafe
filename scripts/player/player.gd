class_name Player
extends CharacterBody2D
## The dreamer. Run, variable-height jump (with coyote time and jump buffering),
## dash, a 3-hit sword combo (the brooch-sword), up/down slashes, and a
## Hollow Knight-style pogo off enemies and spikes.
##
## Every tuning value is exported: select the Player in the Remote scene tree
## while the game runs to tweak them live.

signal health_changed(current: int, maximum: int)
signal died

enum AttackDir { SIDE, UP, DOWN }

@export_group("Run")
@export var run_speed := 140.0
@export var ground_accel := 1800.0
@export var ground_decel := 2200.0
@export var air_accel := 1200.0
@export var air_decel := 1000.0

@export_group("Jump")
## Peak height of a full (held) jump, in pixels.
@export var jump_height := 72.0
@export var jump_time_to_peak := 0.36
## Falling uses stronger gravity than rising, for a snappier arc.
@export var jump_time_to_fall := 0.28
## Upward velocity is multiplied by this when jump is released early.
@export_range(0.0, 1.0) var jump_cut := 0.4
@export var max_fall_speed := 480.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Dash")
@export var dash_speed := 360.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.35
@export var air_dashes := 1
@export var dash_invulnerable := false

@export_group("Attack")
@export var attack_duration := 0.25
## The hitbox is live between these two times (seconds into the swing).
@export var attack_active_start := 0.03
@export var attack_active_end := 0.14
## How long after a swing ends the next press continues the combo.
@export var combo_window := 0.3
@export var attack_buffer_time := 0.12
@export var attack_damage := 1
@export var finisher_damage := 2
## Horizontal push-back on the player when a side slash connects.
@export var attack_recoil := 120.0
@export var enemy_knockback := 220.0
@export var pogo_velocity := 380.0

@export_group("Health")
@export var max_health := 5
@export var invuln_time := 1.0
@export var hurt_stun_time := 0.25
@export var hurt_knockback := Vector2(180, -220)

var health := 0
var facing := 1
## Ignores input (room transitions, death, waking up). Momentum is kept.
var frozen := false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _is_jumping := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _air_dashes_left := 0
var _attack_timer := 0.0
var _attack_buffer_timer := 0.0
var _attack_dir := AttackDir.SIDE
var _combo_step := 0
var _combo_timer := 0.0
var _hit_this_swing: Array[Node] = []
var _swing_connected := false
var _recoil_timer := 0.0
var _invuln_timer := 0.0
var _hurt_timer := 0.0
var _safe_timer := 0.0
var _last_safe_position := Vector2.ZERO

@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	_attack_shape.shape = RectangleShape2D.new()
	health = max_health


func reset() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	velocity = Vector2.ZERO
	facing = 1
	_dash_timer = 0.0
	_attack_timer = 0.0
	_invuln_timer = 0.0
	_hurt_timer = 0.0
	_recoil_timer = 0.0
	_combo_step = 0


func place_at(pos: Vector2) -> void:
	global_position = pos
	_last_safe_position = pos


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if is_on_floor():
		_coyote_timer = coyote_time
		_air_dashes_left = air_dashes
		_is_jumping = false

	var can_act := not frozen and _hurt_timer <= 0.0
	if can_act:
		_read_actions()

	if _dash_timer > 0.0:
		velocity = Vector2(facing * dash_speed, 0.0)
	else:
		var input_x := Input.get_axis("move_left", "move_right") if can_act else 0.0
		_apply_horizontal(input_x, delta)
		_apply_gravity(delta)
		if can_act:
			_try_jump()
			if _attack_buffer_timer > 0.0 and _attack_timer <= 0.0:
				_start_attack()

	move_and_slide()

	_update_attack()
	_check_hurtbox()
	_update_safe_position(delta)
	queue_redraw()


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	_recoil_timer = maxf(_recoil_timer - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			# Leave the dash at run speed rather than sliding off at dash speed.
			velocity.x = facing * run_speed


func _read_actions() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released("jump") and _is_jumping and velocity.y < 0.0:
		velocity.y *= jump_cut
		_is_jumping = false
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = attack_buffer_time


func _apply_horizontal(input_x: float, delta: float) -> void:
	if frozen or _recoil_timer > 0.0 or _hurt_timer > 0.0:
		# Let knockback / recoil / transition momentum play out.
		velocity.x = move_toward(velocity.x, 0.0, air_decel * 0.5 * delta)
		return
	if input_x != 0.0 and _attack_timer <= 0.0:
		facing = int(signf(input_x))
	var accel: float
	if is_on_floor():
		accel = ground_accel if input_x != 0.0 else ground_decel
	else:
		accel = air_accel if input_x != 0.0 else air_decel
	velocity.x = move_toward(velocity.x, input_x * run_speed, accel * delta)


func _apply_gravity(delta: float) -> void:
	var rising_gravity := 2.0 * jump_height / pow(jump_time_to_peak, 2)
	var falling_gravity := 2.0 * jump_height / pow(jump_time_to_fall, 2)
	var gravity := rising_gravity if velocity.y < 0.0 else falling_gravity
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	velocity.y = -2.0 * jump_height / jump_time_to_peak
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_is_jumping = true
	# A buffered tap that was already released becomes a short hop.
	if not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut
		_is_jumping = false


func _try_dash() -> void:
	if _dash_timer > 0.0 or _dash_cooldown_timer > 0.0:
		return
	if not is_on_floor():
		if _air_dashes_left <= 0:
			return
		_air_dashes_left -= 1
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		facing = int(signf(input_x))
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_duration + dash_cooldown
	_attack_timer = 0.0
	_is_jumping = false


func _start_attack() -> void:
	_attack_buffer_timer = 0.0
	if _dash_timer > 0.0:
		return
	if Input.is_action_pressed("look_up"):
		_attack_dir = AttackDir.UP
	elif Input.is_action_pressed("look_down") and not is_on_floor():
		_attack_dir = AttackDir.DOWN
	else:
		_attack_dir = AttackDir.SIDE

	if _attack_dir == AttackDir.SIDE and _combo_timer > 0.0:
		_combo_step = _combo_step % 3 + 1
	else:
		_combo_step = 1

	_attack_timer = attack_duration
	_combo_timer = attack_duration + combo_window
	_hit_this_swing.clear()
	_swing_connected = false

	var rect := _attack_shape.shape as RectangleShape2D
	match _attack_dir:
		AttackDir.SIDE:
			rect.size = Vector2(44, 26) if _is_finisher() else Vector2(36, 22)
			_attack_shape.position = Vector2(facing * (6.0 + rect.size.x / 2.0), -12.0)
		AttackDir.UP:
			rect.size = Vector2(28, 34)
			_attack_shape.position = Vector2(0, -22.0 - rect.size.y / 2.0)
		AttackDir.DOWN:
			rect.size = Vector2(28, 34)
			_attack_shape.position = Vector2(0, rect.size.y / 2.0)


func _is_finisher() -> bool:
	return _attack_dir == AttackDir.SIDE and _combo_step == 3


func _is_attack_active() -> bool:
	if _attack_timer <= 0.0:
		return false
	var elapsed := attack_duration - _attack_timer
	return elapsed >= attack_active_start and elapsed <= attack_active_end


func _update_attack() -> void:
	if not _is_attack_active():
		return
	for body in _attack_area.get_overlapping_bodies():
		if body in _hit_this_swing or not body.has_method("take_hit"):
			continue
		_hit_this_swing.append(body)
		var damage := finisher_damage if _is_finisher() else attack_damage
		body.take_hit(damage, _knockback_for_swing())
		Poof.spawn(get_parent(), body.global_position + Vector2(0, -6), 12.0)
		_on_swing_connected()
	for area in _attack_area.get_overlapping_areas():
		if area in _hit_this_swing or not area.is_in_group("pogoable"):
			continue
		_hit_this_swing.append(area)
		_on_swing_connected()


func _knockback_for_swing() -> Vector2:
	match _attack_dir:
		AttackDir.UP:
			return Vector2(0, -enemy_knockback)
		AttackDir.DOWN:
			return Vector2(0, enemy_knockback * 0.5)
	var strength := enemy_knockback * (1.5 if _is_finisher() else 1.0)
	return Vector2(facing * strength, -60)


## Recoil / pogo happens once per swing, however many things it hit.
func _on_swing_connected() -> void:
	if _swing_connected:
		return
	_swing_connected = true
	match _attack_dir:
		AttackDir.DOWN:
			velocity.y = -pogo_velocity
			_is_jumping = false
			_air_dashes_left = air_dashes
		AttackDir.SIDE:
			velocity.x = -facing * attack_recoil
			_recoil_timer = 0.08
	Game.hitstop(0.05)
	Game.shake(2.0)


func _check_hurtbox() -> void:
	if frozen or _invuln_timer > 0.0 or (dash_invulnerable and _dash_timer > 0.0):
		return
	for area in _hurtbox.get_overlapping_areas():
		if area is Hitbox:
			take_damage(area.damage, area.damage_origin(), area.respawn_player)
			return


func take_damage(amount: int, from: Vector2, respawn := false) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invuln_timer = invuln_time
	_hurt_timer = hurt_stun_time
	_attack_timer = 0.0
	_dash_timer = 0.0
	Game.hitstop(0.12)
	Game.shake(6.0)

	if health == 0:
		frozen = true
		velocity = Vector2.ZERO
		died.emit()
		return

	if respawn:
		global_position = _last_safe_position
		velocity = Vector2.ZERO
		return

	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * hurt_knockback.x, hurt_knockback.y)


## Remembers solid ground to return to after touching a respawn hazard.
func _update_safe_position(delta: float) -> void:
	if is_on_floor() and not frozen and _hurt_timer <= 0.0:
		_safe_timer += delta
		if _safe_timer >= 0.15:
			_last_safe_position = global_position
	else:
		_safe_timer = 0.0


func _draw() -> void:
	var blink := _invuln_timer > 0.0 and int(_invuln_timer * 20.0) % 2 == 0
	var body_color := Color("f2e6d0")
	if blink:
		body_color.a = 0.3

	if _dash_timer > 0.0:
		for i in range(1, 4):
			draw_rect(Rect2(-6.0 - facing * i * 7.0, -22.0, 12.0, 22.0), Color(body_color, 0.25 / i))

	draw_rect(Rect2(-6, -22, 12, 22), body_color)
	draw_rect(Rect2(facing * 3.0 - 1.0, -18.0, 2.0, 3.0), Color("1b1830"))
	# The brooch.
	draw_circle(Vector2(-facing * 1.0, -12.0), 1.5, Color("7fd4ff"))

	if _attack_timer > 0.0:
		var rect := _attack_shape.shape as RectangleShape2D
		var slash := Rect2(_attack_shape.position - rect.size / 2.0, rect.size)
		var alpha := 0.7 if _is_attack_active() else 0.25
		draw_rect(slash, Color(0.85, 0.95, 1.0, alpha * 0.4))
		draw_rect(slash, Color(0.85, 0.95, 1.0, alpha), false, 1.0)
