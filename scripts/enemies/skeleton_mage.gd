extends EnemyBase
class_name SkeletonMage

## Skeleton Mage — ranged caster found in Zenith's Laboratory.
## Fires magic projectiles and can teleport short distances when threatened.
## Uses Skeleton_Mage.glb model.

@export var projectile_speed: float = 12.0
@export var projectile_damage: int = 10
@export var teleport_cooldown: float = 8.0
@export var teleport_range: float = 6.0
@export var preferred_distance: float = 8.0

var _teleport_timer: float = 0.0
var _projectile_scene: PackedScene = null

# We create simple projectiles inline since we don't have a mage-specific scene
var _casting: bool = false
var _cast_timer: float = 0.0
var _cast_duration: float = 0.5


func _ready() -> void:
	max_health = 25
	attack_damage = 10
	move_speed = 2.0
	chase_speed = 2.5
	attack_range = 12.0  # Ranged attacker — stays far away
	detection_range = 16.0
	attack_cooldown = 2.5

	super._ready()
	add_to_group("skeleton_mages")


func _physics_process(delta: float) -> void:
	if _teleport_timer > 0:
		_teleport_timer -= delta

	# Handle cast wind-up
	if _casting:
		_cast_timer -= delta
		if _cast_timer <= 0:
			_casting = false
			_fire_projectile()

	super._physics_process(delta)


func _process_chase(delta: float) -> void:
	## Override chase to maintain distance — mages kite backwards
	if not target or not is_instance_valid(target):
		target = null
		current_state = State.IDLE
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	var distance: float = to_target.length()

	# If player is too close, back away (or teleport)
	if distance < preferred_distance * 0.5:
		if _teleport_timer <= 0:
			_perform_teleport()
			return
		else:
			# Retreat
			var retreat_dir: Vector3 = -to_target.normalized()
			velocity.x = retreat_dir.x * chase_speed
			velocity.z = retreat_dir.z * chase_speed
			_rotate_toward(to_target.normalized(), delta)
			return

	# If in attack range, attack
	if distance <= attack_range:
		current_state = State.ATTACK
		velocity.x = 0
		velocity.z = 0
		return

	# If target too far, give up
	if distance > detection_range * 1.5:
		target = null
		current_state = State.IDLE
		return

	# Move toward target but stop at preferred distance
	if distance > preferred_distance:
		var direction: Vector3 = to_target.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		_rotate_toward(direction, delta)
	else:
		# At ideal range — just face the target
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_rotate_toward(to_target.normalized(), delta)
		current_state = State.ATTACK


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target):
		return

	# Start casting (wind-up before projectile fires)
	if not _casting:
		_casting = true
		_cast_timer = _cast_duration


func _fire_projectile() -> void:
	## Create a magic bolt projectile
	if not target or not is_instance_valid(target):
		return

	var direction: Vector3 = (target.global_position + Vector3(0, 0.8, 0) - global_position).normalized()

	# Create a simple Area3D projectile
	var bolt: Area3D = Area3D.new()
	bolt.name = "MageBolt"
	bolt.collision_layer = 8  # Projectiles
	bolt.collision_mask = 3   # Environment + Player

	# Collision shape
	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.2
	col.shape = sphere_shape
	bolt.add_child(col)

	# Visual — glowing sphere
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	mesh_inst.mesh = sphere_mesh

	var bolt_mat: StandardMaterial3D = StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.3, 0.8, 1.0, 1)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.3, 0.8, 1.0, 1)
	bolt_mat.emission_energy_multiplier = 4.0
	mesh_inst.set_surface_override_material(0, bolt_mat)
	bolt.add_child(mesh_inst)

	# Light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.3, 0.8, 1.0, 1)
	light.light_energy = 2.0
	light.omni_range = 3.0
	bolt.add_child(light)

	# Add to scene
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position + Vector3(0, 1.0, 0)

	# Set up movement and collision via a script-like approach using metadata
	bolt.set_meta("direction", direction)
	bolt.set_meta("speed", projectile_speed)
	bolt.set_meta("damage", projectile_damage)
	bolt.set_meta("lifetime", 4.0)
	bolt.set_meta("source", self)

	# Connect body entered
	bolt.body_entered.connect(_on_bolt_hit.bind(bolt))

	# Create a timer to move the bolt and handle its lifetime
	_animate_bolt(bolt)


func _animate_bolt(bolt: Area3D) -> void:
	## Move the bolt each frame until it hits something or expires
	if not is_instance_valid(bolt):
		return

	var direction: Vector3 = bolt.get_meta("direction") as Vector3
	var speed: float = bolt.get_meta("speed") as float
	var lifetime: float = bolt.get_meta("lifetime") as float

	var elapsed: float = 0.0
	while elapsed < lifetime:
		if not is_instance_valid(bolt):
			return
		bolt.global_position += direction * speed * get_physics_process_delta_time()
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame

	# Despawn if still alive
	if is_instance_valid(bolt):
		bolt.queue_free()


func _on_bolt_hit(body: Node3D, bolt: Area3D) -> void:
	if not is_instance_valid(bolt):
		return

	# Skip self
	if body == self:
		return

	# Skip other enemies
	if body.is_in_group("enemies"):
		return

	var damage: int = bolt.get_meta("damage") as int

	if body.has_method("take_damage"):
		body.take_damage(damage, bolt.global_position)

	bolt.queue_free()


func _perform_teleport() -> void:
	## Blink teleport away from player
	_teleport_timer = teleport_cooldown

	if not target or not is_instance_valid(target):
		return

	var away_dir: Vector3 = (global_position - target.global_position).normalized()
	away_dir.y = 0

	# Add some randomness to the teleport direction
	var angle_offset: float = randf_range(-0.8, 0.8)
	var rotated_dir: Vector3 = Vector3(
		away_dir.x * cos(angle_offset) - away_dir.z * sin(angle_offset),
		0,
		away_dir.x * sin(angle_offset) + away_dir.z * cos(angle_offset)
	)

	var new_pos: Vector3 = global_position + rotated_dir * teleport_range
	new_pos.y = global_position.y  # Keep same height

	global_position = new_pos
	velocity = Vector3.ZERO

	print("[SkeletonMage] Teleport!")
