extends WeaponBase
class_name Belt

## Oley's Belt - Melee whip weapon with arc sweep attack

@export var whip_range: float = 4.0
@export var arc_angle: float = 120.0  # Degrees
@export var windup_delay: float = 0.2

var _windup_timer: float = 0.0
var _is_winding_up: bool = false


func _ready() -> void:
	weapon_name = "Belt"
	damage = 20
	fire_rate = 0.8


func try_use(player: PlayerController) -> void:
	"""Try to use the belt weapon."""
	if is_ready:
		_perform_use(player)
		is_ready = false
		current_cooldown = fire_rate


func _perform_use(player: PlayerController) -> void:
	"""Perform a whip arc sweep attack."""
	_is_winding_up = true
	_windup_timer = windup_delay

	# Wait for wind-up, then deal damage
	await get_tree().create_timer(windup_delay).timeout

	if not _is_winding_up:
		return

	_is_winding_up = false

	# Find all enemies in arc sweep
	var player_pos: Vector3 = player.global_position
	var player_forward: Vector3 = player.last_direction

	# Get enemies in detection range
	var enemies_in_range: Array[Node3D] = []
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

	# Create a sphere query for initial detection
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = whip_range
	query.shape = sphere_shape
	query.transform = Transform3D(Basis.IDENTITY, player_pos)
	query.collision_mask = 4  # Layer 3 (Enemies)

	var results: Array = space_state.intersect_shape(query)

	for result: Dictionary in results:
		var collider: Node = result.get("collider")
		if collider and collider.has_method("take_damage"):
			var collider_parent: Node = collider.get_parent()
			if collider_parent is CharacterBody3D and collider_parent.has_method("take_damage"):
				enemies_in_range.append(collider_parent)
			elif collider is CharacterBody3D and collider.has_method("take_damage"):
				enemies_in_range.append(collider)

	# Filter by arc angle
	var arc_rad: float = deg_to_rad(arc_angle / 2.0)
	for enemy: Node3D in enemies_in_range:
		var to_enemy: Vector3 = (enemy.global_position - player_pos)
		to_enemy.y = 0
		to_enemy = to_enemy.normalized()

		var angle: float = acos(clamp(player_forward.dot(to_enemy), -1.0, 1.0))
		if angle <= arc_rad:
			enemy.take_damage(damage, player_pos)

	weapon_used.emit()
