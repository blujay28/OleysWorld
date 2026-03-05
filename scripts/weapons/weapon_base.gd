extends Node
class_name WeaponBase

## Base class for all weapons in Oley's World
## Defines common weapon properties and usage patterns

# -- Properties --
@export var weapon_name: String = "Weapon"
@export var damage: int = 10
@export var fire_rate: float = 1.0

var current_cooldown: float = 0.0
var is_ready: bool = true

# -- Signals --
signal weapon_used
signal weapon_cooldown_updated(remaining: float, max_cooldown: float)


func _process(delta: float) -> void:
	_update_cooldown(delta)


func try_use(player: PlayerController) -> void:
	"""Attempt to use the weapon. Returns true if successful."""
	if is_ready:
		_perform_use(player)
		is_ready = false
		current_cooldown = fire_rate
		weapon_used.emit()


func _perform_use(_player: PlayerController) -> void:
	"""Override in subclasses for specific weapon behavior."""
	pass


func _update_cooldown(delta: float) -> void:
	"""Update the weapon cooldown timer."""
	if not is_ready:
		current_cooldown -= delta
		weapon_cooldown_updated.emit(current_cooldown, fire_rate)
		if current_cooldown <= 0.0:
			is_ready = true
			current_cooldown = 0.0
