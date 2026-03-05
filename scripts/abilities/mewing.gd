extends AbilityBase
class_name MewingAbility

## Mewing - AoE stun ability that freezes enemies in place

@export var stun_radius: float = 8.0
@export var stun_duration: float = 3.0


func _ready() -> void:
	ability_name = "Mewing"
	cooldown = 12.0
	duration = stun_duration


func _perform_ability(player: PlayerController) -> void:
	"""Perform the mewing ability - stun all enemies in radius."""
	var player_pos: Vector3 = player.global_position

	# Find all enemies in stun radius
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = stun_radius
	query.shape = sphere_shape
	query.transform = Transform3D(Basis.IDENTITY, player_pos)
	query.collision_mask = 4  # Layer 3 (Enemies)

	var results: Array = space_state.intersect_shape(query)

	var stunned_count: int = 0
	for result: Dictionary in results:
		var collider: Node = result.get("collider")
		if collider and collider.has_method("stun"):
			collider.stun(stun_duration)
			stunned_count += 1
		elif collider:
			var parent: Node = collider.get_parent()
			if parent and parent.has_method("stun"):
				parent.stun(stun_duration)
				stunned_count += 1

	print("[Mewing] Stunned %d enemies for %.1f seconds" % [stunned_count, stun_duration])
	ability_used.emit()
