extends RigidBody3D
class_name BreakableProp

## BreakableProp — Physics-enabled destructible object (barrel, crate, vase, etc.)
## Reacts to sword hits, arrow impacts, and player collision.
## Shatters into debris particles when destroyed. Can drop coins.
##
## How to use in a level:
##   var prop = BreakableProp.create_barrel(Vector3(5, 0.5, 3))
##   add_child(prop)

@export var prop_health: int = 15
@export var prop_color: Color = Color(0.5, 0.35, 0.2)  # Wood brown
@export var prop_size: Vector3 = Vector3(0.6, 0.8, 0.6)
@export var drop_coins: bool = true
@export var coin_drop_count: int = 2
@export var knockback_multiplier: float = 1.5  ## How much force from hits

var _current_health: int
var _is_broken: bool = false


func _ready() -> void:
	_current_health = prop_health
	add_to_group("breakable")

	# Physics setup
	mass = 5.0
	gravity_scale = 1.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.1
	physics_material_override.friction = 0.8

	# Collision layers: environment (1) + interactable (16)
	collision_layer = 17  # Bits 1 and 5
	collision_mask = 7    # Environment (1) + Player (2) + Enemies (4)

	# Don't sleep immediately — stay awake for first few seconds
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 4

	# Create visual mesh if not already present
	if get_child_count() == 0 or not _has_mesh_child():
		_create_default_mesh()

	# Create collision shape if needed
	if not _has_collision_child():
		_create_default_collision()


func _has_mesh_child() -> bool:
	for child in get_children():
		if child is MeshInstance3D:
			return true
	return false


func _has_collision_child() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _create_default_mesh() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = prop_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = prop_color
	box_mesh.material = mat
	mesh_instance.mesh = box_mesh
	add_child(mesh_instance)


func _create_default_collision() -> void:
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = prop_size
	col_shape.shape = box_shape
	add_child(col_shape)


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	"""Called when hit by sword, arrow, or enemy attack."""
	if _is_broken:
		return

	_current_health -= amount

	# Apply physics impulse from the hit direction
	if source_position != Vector3.ZERO:
		var impulse_dir: Vector3 = (global_position - source_position).normalized()
		impulse_dir.y = 0.3  # Slight upward component
		impulse_dir = impulse_dir.normalized()
		var impulse_force: float = float(amount) * knockback_multiplier
		apply_central_impulse(impulse_dir * impulse_force)

	# Flash the mesh briefly
	_flash_hit()

	if _current_health <= 0:
		_break()


func _flash_hit() -> void:
	"""Brief white flash on hit."""
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_inst: MeshInstance3D = child as MeshInstance3D
			if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
				var mat: Material = mesh_inst.get_surface_override_material(0)
				if not mat:
					mat = mesh_inst.mesh.surface_get_material(0)
				if mat and mat is StandardMaterial3D:
					var std: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
					std.albedo_color = Color(1, 0.8, 0.6)
					mesh_inst.set_surface_override_material(0, std)
					# Restore after brief flash
					await get_tree().create_timer(0.08).timeout
					if is_instance_valid(mesh_inst):
						std.albedo_color = prop_color
						mesh_inst.set_surface_override_material(0, std)


func _break() -> void:
	"""Destroy the prop — spawn debris, coins, and remove."""
	if _is_broken:
		return
	_is_broken = true

	# Debris VFX — brown/wood colored sparks
	VFXHelper.spawn_hit_sparks(get_tree().root, global_position + Vector3.UP * 0.3, prop_color.lightened(0.3))
	VFXHelper.spawn_death_poof(get_tree().root, global_position, prop_color.lightened(0.2))

	# Drop coins
	if drop_coins and coin_drop_count > 0:
		GameManager.add_coins(coin_drop_count)
		VFXHelper.spawn_coin_pickup(get_tree().root, global_position + Vector3.UP * 0.5)

	# Brief explosion impulse outward before removing
	apply_central_impulse(Vector3.UP * 8.0)

	# Disable collision immediately
	collision_layer = 0
	collision_mask = 0

	# Fade out mesh and remove
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

	await get_tree().create_timer(0.1).timeout
	queue_free()


## Factory: create a barrel at the given position.
static func create_barrel(pos: Vector3) -> BreakableProp:
	var barrel: BreakableProp = BreakableProp.new()
	barrel.prop_health = 12
	barrel.prop_color = Color(0.45, 0.3, 0.15)
	barrel.prop_size = Vector3(0.7, 1.0, 0.7)
	barrel.position = pos
	barrel.coin_drop_count = 2
	return barrel


## Factory: create a crate at the given position.
static func create_crate(pos: Vector3) -> BreakableProp:
	var crate: BreakableProp = BreakableProp.new()
	crate.prop_health = 18
	crate.prop_color = Color(0.55, 0.4, 0.2)
	crate.prop_size = Vector3(0.8, 0.8, 0.8)
	crate.position = pos
	crate.coin_drop_count = 3
	return crate


## Factory: create a vase at the given position.
static func create_vase(pos: Vector3) -> BreakableProp:
	var vase: BreakableProp = BreakableProp.new()
	vase.prop_health = 5
	vase.prop_color = Color(0.6, 0.3, 0.4)
	vase.prop_size = Vector3(0.4, 0.6, 0.4)
	vase.position = pos
	vase.coin_drop_count = 1
	vase.mass = 2.0
	return vase
