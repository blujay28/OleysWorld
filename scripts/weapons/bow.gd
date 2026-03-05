extends WeaponBase
class_name Bow

## Oley's Bow — Ranged weapon that fires arrows.
## Uses CombatRanged animations (draw, shoot, idle).
## Arrows are physical projectiles with gravity arc.

@export var arrow_speed: float = 30.0
@export var max_range: float = 60.0
@export var draw_time: float = 0.35        # Seconds to draw bowstring
@export var arrow_gravity: float = 4.0     # Slight arc on arrows

var arrow_scene: PackedScene = preload("res://scenes/weapons/arrow.tscn")
var _is_drawing: bool = false
var _draw_timer: float = 0.0
var _player_ref: PlayerController = null

signal arrow_fired


func _ready() -> void:
	weapon_name = "Bow"
	damage = 18
	fire_rate = 0.7  # Total time between shots (draw + recovery)


func _process(delta: float) -> void:
	if _is_drawing:
		_draw_timer -= delta
		if _draw_timer <= 0.0:
			_release_arrow()
	else:
		_update_cooldown(delta)


func try_use(player: PlayerController) -> void:
	if is_ready and not _is_drawing:
		_player_ref = player
		_start_draw(player)
		is_ready = false
		current_cooldown = fire_rate


func _start_draw(player: PlayerController) -> void:
	_is_drawing = true
	_draw_timer = draw_time

	# Rotate Oley to face the camera aim direction while drawing
	var aim_dir: Vector3 = player.get_aim_direction()
	player.face_direction(aim_dir)

	# Play draw animation on the player
	if player.animation_player and player.animation_player.has_animation("1H_Ranged_Aiming"):
		player.animation_player.play("1H_Ranged_Aiming")
	elif player.animation_player and player.animation_player.has_animation("1H_Ranged_Shoot"):
		player.animation_player.play("1H_Ranged_Shoot")


func _release_arrow() -> void:
	_is_drawing = false

	if not _player_ref or not is_instance_valid(_player_ref):
		return

	var player: PlayerController = _player_ref

	# Play shoot animation
	if player.animation_player:
		if player.animation_player.has_animation("1H_Ranged_Shoot"):
			player.animation_player.play("1H_Ranged_Shoot")
		elif player.animation_player.has_animation("1H_Ranged_Aiming"):
			player.animation_player.play("1H_Ranged_Aiming")

	# Calculate fire direction from camera aim
	var aim_dir: Vector3 = player.get_aim_direction()
	var camera_basis: Basis = player.camera_pivot.global_transform.basis if player.camera_pivot else player.global_transform.basis
	var fire_direction: Vector3 = -camera_basis.z
	fire_direction = fire_direction.normalized()

	# Rotate model to face the aim direction so Oley doesn't shoot sideways
	player.face_direction(aim_dir)

	# Spawn arrow
	var arrow: Arrow = arrow_scene.instantiate() as Arrow
	arrow.direction = fire_direction
	arrow.speed = arrow_speed
	arrow.damage = damage
	arrow.max_distance = max_range
	arrow.gravity_strength = arrow_gravity

	# Apply crit if active
	if player.crit_active:
		arrow.damage = int(float(arrow.damage) * player.crit_multiplier)
		arrow.is_crit = true

	player.get_parent().add_child(arrow)
	# Spawn arrow in front of where Oley is now AIMING (not last movement direction)
	arrow.global_position = player.global_position + aim_dir * 1.0 + Vector3.UP * 1.2

	arrow_fired.emit()
	weapon_used.emit()
	_player_ref = null
