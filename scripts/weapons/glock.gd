extends WeaponBase
class_name Glock

## Oley's Glock - Ranged weapon with bullets and magazine system

@export var bullet_speed: float = 40.0
@export var max_range: float = 50.0
@export var spread: float = 0.05
@export var magazine_size: int = 12
@export var reload_time: float = 1.5

var current_ammo: int = 12
var is_reloading: bool = false
var _reload_timer: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/weapons/bullet.tscn")

# -- Signals --
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished


func _ready() -> void:
	weapon_name = "Glock"
	damage = 12
	fire_rate = 0.1
	current_ammo = magazine_size
	ammo_changed.emit(current_ammo, magazine_size)


func _process(delta: float) -> void:
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	else:
		_update_cooldown(delta)


func try_use(player: PlayerController) -> void:
	"""Try to fire the glock."""
	if is_reloading:
		return

	if current_ammo <= 0:
		start_reload()
		return

	if is_ready:
		_perform_use(player)
		is_ready = false
		current_cooldown = fire_rate


func _perform_use(player: PlayerController) -> void:
	"""Fire a bullet toward where the player is looking."""
	if current_ammo <= 0:
		return

	# Get camera direction (player forward)
	var camera_basis: Basis = player.camera_pivot.global_transform.basis if player.camera_pivot else player.global_transform.basis
	var fire_direction: Vector3 = -camera_basis.z  # Camera faces -Z

	# Apply spread
	var spread_angle_h: float = randf_range(-spread, spread)
	var spread_angle_v: float = randf_range(-spread, spread)
	fire_direction = fire_direction.rotated(player.global_transform.basis.x, spread_angle_v)
	fire_direction = fire_direction.rotated(Vector3.UP, spread_angle_h)
	fire_direction = fire_direction.normalized()

	# Spawn bullet — must add to tree BEFORE setting global_position
	var bullet: Bullet = bullet_scene.instantiate() as Bullet
	bullet.direction = fire_direction
	bullet.speed = bullet_speed
	bullet.damage = damage
	bullet.max_distance = max_range
	player.get_parent().add_child(bullet)
	bullet.global_position = player.global_position + player.last_direction * 1.5 + Vector3.UP * 1.0

	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size)
	weapon_used.emit()

	# Auto-reload when empty
	if current_ammo <= 0:
		start_reload()


func start_reload() -> void:
	"""Begin reloading the magazine."""
	if is_reloading or current_ammo == magazine_size:
		return

	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit()


func _finish_reload() -> void:
	"""Complete the reload."""
	is_reloading = false
	current_ammo = magazine_size
	ammo_changed.emit(current_ammo, magazine_size)
	reload_finished.emit()
