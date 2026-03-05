extends Node
class_name AbilityBase

## Base class for all abilities in Oley's World

@export var ability_name: String = "Ability"
@export var cooldown: float = 10.0
@export var duration: float = 5.0

var current_cooldown: float = 0.0
var is_ready: bool = true

# -- Signals --
signal ability_used
signal cooldown_updated(remaining: float, max_cooldown: float)


func _process(delta: float) -> void:
	_update_cooldown(delta)


func try_activate(player: PlayerController) -> void:
	"""Attempt to activate the ability."""
	if is_ready:
		_perform_ability(player)
		is_ready = false
		current_cooldown = cooldown
		ability_used.emit()


func _perform_ability(_player: PlayerController) -> void:
	"""Override in subclasses for specific ability behavior."""
	pass


func _update_cooldown(delta: float) -> void:
	"""Update the ability cooldown timer."""
	if not is_ready:
		current_cooldown -= delta
		cooldown_updated.emit(current_cooldown, cooldown)
		if current_cooldown <= 0.0:
			is_ready = true
			current_cooldown = 0.0
