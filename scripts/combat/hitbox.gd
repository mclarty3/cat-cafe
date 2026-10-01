@tool
class_name Hitbox
extends Area2D
## Anything that hurts the player on contact: enemy bodies, spikes, projectiles.
## The player's Hurtbox looks for these.

@export var damage := 1
## Hazard-style: instead of knockback, the player is put back on the last safe
## ground they stood on (like Hollow Knight's spikes).
@export var respawn_player := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false


func damage_origin() -> Vector2:
	return global_position
