extends Area3D
class_name PurpleCoin

## Purple Coin - Pickup that adds to player's coin count

@export var coin_value: int = 1

var _rotation_speed: float = 2.0


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Spin the coin
	rotation.y += _rotation_speed * delta


func _on_body_entered(body: Node3D) -> void:
	"""Handle collision with player."""
	if body is PlayerController or body.is_in_group("player"):
		GameManager.add_coins(coin_value)
		# Spawn purple sparkle VFX before removing
		VFXHelper.spawn_coin_pickup(get_tree().root, global_position)
		queue_free()
