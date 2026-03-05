extends Area3D
class_name Bullet

## Simple projectile that moves forward and deals damage on hit

@export var speed: float = 40.0
@export var damage: int = 15
@export var max_distance: float = 50.0

var direction: Vector3 = Vector3.FORWARD
var distance_traveled: float = 0.0
var has_hit: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Connect collision signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	var movement: Vector3 = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()

	# Despawn if beyond max range
	if distance_traveled >= max_distance:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	# Hit an enemy area (e.g. hurtbox on an enemy)
	if has_hit:
		return

	# Never damage the player who fired us
	var parent: Node = area.get_parent()
	if parent and parent.is_in_group("player"):
		return

	if parent and parent.has_method("take_damage"):
		has_hit = true
		parent.take_damage(damage, global_position)
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	# Hit an enemy or environment
	if has_hit:
		return

	if body.is_in_group("player"):
		return

	has_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
