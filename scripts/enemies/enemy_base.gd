extends CharacterBody3D
class_name EnemyBase

## Base class for all enemies in Oley's World.
## Handles health, damage, basic state machine, and death.
## Extend this class for specific enemy types (Minion, Warrior, Mage, Rogue).
## Physics-enhanced: impulse knockback, stagger, dramatic launch-on-death.

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

# -- Stats --
@export_group("Stats")
@export var max_health: int = 30
@export var attack_damage: int = 10
@export var move_speed: float = 3.0
@export var chase_speed: float = 5.0
@export var attack_range: float = 2.0
@export var detection_range: float = 12.0
@export var attack_cooldown: float = 1.2

# -- Physics / Knockback --
@export_group("Physics")
@export var knockback_resistance: float = 1.0   ## 1.0 = normal, 2.0 = tanky, 0.5 = light
@export var knockback_decay: float = 8.0        ## How fast knockback velocity decays
@export var death_launch_force: float = 8.0     ## Upward impulse on death
@export var death_tumble_force: float = 5.0     ## Horizontal scatter on death
@export var hit_stagger_duration: float = 0.3   ## How long the enemy staggers after hit

# -- Patrol --
@export_group("Patrol")
@export var patrol_points: Array[Vector3] = []
@export var patrol_wait_time: float = 2.0

# -- Animation rig paths --
@export_group("Animation Rigs")
@export var anim_rig_general: String = "res://assets/animations/skeleton/Rig_Medium_General.glb"
@export var anim_rig_movement: String = "res://assets/animations/skeleton/Rig_Medium_MovementBasic.glb"

# -- State --
var current_health: int
var current_state: State = State.IDLE
var target: Node3D = null
var is_stunned: bool = false
var _attack_timer: float = 0.0
var _patrol_index: int = 0
var _patrol_wait_timer: float = 0.0
var _hurt_timer: float = 0.0
var _stun_timer: float = 0.0
var _spawn_position: Vector3

# -- Knockback physics --
var _knockback_velocity: Vector3 = Vector3.ZERO  ## Separate knockback vector decayed over time
var _hit_flash_timer: float = 0.0
var _original_color: Color = Color.WHITE

# -- Node references --
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else null
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var detection_area: Area3D = $DetectionArea if has_node("DetectionArea") else null

# -- Signals --
signal enemy_died(enemy: EnemyBase)
signal enemy_damaged(enemy: EnemyBase, remaining_health: int)


func _ready() -> void:
	current_health = max_health
	_spawn_position = global_position
	add_to_group("enemies")

	# Setup AnimationPlayer on the model INSTANCE (SkeletonModel),
	# not on Model. Track paths like "Skeleton3D:hips" resolve correctly
	# when the AnimationPlayer is at the .glb instance root level.
	var char_model_instance: Node3D = model.get_child(0) as Node3D  # SkeletonModel
	if char_model_instance:
		animation_player = AnimationHelper.setup_animation_player(char_model_instance)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_general)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_movement)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	if nav_agent:
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 1.5
		nav_agent.max_speed = chase_speed

	# If no patrol points, default to standing in place
	if patrol_points.is_empty():
		current_state = State.IDLE
	else:
		current_state = State.PATROL


func _physics_process(delta: float) -> void:
	# Dead enemies still need gravity + move_and_slide for their death launch flight
	if current_state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return

	# Kill plane — enemies that fall off the map die immediately
	if global_position.y < -10.0:
		_die()
		return

	_apply_gravity(delta)
	_update_timers(delta)
	_apply_knockback_decay(delta)

	# Skip state processing if stunned
	if not is_stunned:
		match current_state:
			State.IDLE:
				_process_idle(delta)
			State.PATROL:
				_process_patrol(delta)
			State.CHASE:
				_process_chase(delta)
			State.ATTACK:
				_process_attack(delta)
			State.HURT:
				_process_hurt(delta)

	# Merge knockback into velocity for movement
	velocity.x += _knockback_velocity.x
	velocity.z += _knockback_velocity.z
	velocity.y += _knockback_velocity.y

	move_and_slide()

	# Subtract knockback after move so state logic doesn't double-count
	velocity.x -= _knockback_velocity.x
	velocity.z -= _knockback_velocity.z
	velocity.y -= _knockback_velocity.y

	_update_animation()
	_update_hit_flash(delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_value: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		velocity.y -= gravity_value * 2.0 * delta


func _update_timers(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta

	if _hurt_timer > 0:
		_hurt_timer -= delta
		if _hurt_timer <= 0:
			if target:
				current_state = State.CHASE
			else:
				current_state = State.IDLE

	if _stun_timer > 0:
		_stun_timer -= delta
		if _stun_timer <= 0:
			is_stunned = false
			velocity.x = 0
			velocity.z = 0
			# Reset to chase/idle — don't let enemy instantly attack on stun end
			if target and is_instance_valid(target):
				current_state = State.CHASE
			else:
				current_state = State.IDLE


func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	# Check if player is in range
	if target:
		current_state = State.CHASE


func _process_patrol(delta: float) -> void:
	if target:
		current_state = State.CHASE
		return

	if patrol_points.is_empty():
		current_state = State.IDLE
		return

	var patrol_target := patrol_points[_patrol_index] + _spawn_position
	var direction := (patrol_target - global_position)
	direction.y = 0

	if direction.length() < 1.0:
		# Reached patrol point, wait then move to next
		_patrol_wait_timer += delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

		if _patrol_wait_timer >= patrol_wait_time:
			_patrol_wait_timer = 0.0
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
	else:
		var move_dir := direction.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		_rotate_toward(move_dir, delta)


func _process_chase(delta: float) -> void:
	if not target or not is_instance_valid(target):
		target = null
		current_state = State.IDLE
		return

	var to_target := target.global_position - global_position
	var y_diff := absf(to_target.y)
	to_target.y = 0
	var distance := to_target.length()

	# Don't attack if we're on a completely different vertical level
	if y_diff > 3.0:
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

	# Direct movement toward target (nav agent requires a baked navmesh)
	var direction := to_target.normalized()
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	_rotate_toward(direction, delta)


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	if not target or not is_instance_valid(target):
		target = null
		current_state = State.IDLE
		return

	# Face the target
	var to_target := target.global_position - global_position
	var y_diff := absf(to_target.y)
	to_target.y = 0
	_rotate_toward(to_target.normalized(), delta)

	# Can't attack from a completely different vertical level
	if y_diff > 3.0:
		current_state = State.CHASE
		return

	# Check if still in range
	if to_target.length() > attack_range * 1.3:
		current_state = State.CHASE
		return

	# Attack on cooldown
	if _attack_timer <= 0:
		_perform_attack()
		_attack_timer = attack_cooldown


func _perform_attack() -> void:
	## Override in subclasses for different attack behaviors
	if current_state == State.DEAD or is_stunned:
		return
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		# Spawn hit sparks at the point of impact
		var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
		hit_pos.y += 0.5
		VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.5, 0.2))
		target.take_damage(attack_damage, global_position)


func _process_hurt(_delta: float) -> void:
	# Movement slows during hurt state — knockback handles displacement
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * _delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * _delta)


func _apply_knockback_decay(delta: float) -> void:
	"""Smoothly decay the knockback impulse vector each frame."""
	_knockback_velocity.x = move_toward(_knockback_velocity.x, 0.0, knockback_decay * delta)
	_knockback_velocity.z = move_toward(_knockback_velocity.z, 0.0, knockback_decay * delta)
	if is_on_floor():
		_knockback_velocity.y = 0.0
	else:
		_knockback_velocity.y = move_toward(_knockback_velocity.y, 0.0, knockback_decay * 0.5 * delta)


func _update_hit_flash(delta: float) -> void:
	"""Flash the model white-red on hit then restore."""
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0:
			_restore_enemy_materials()


func _apply_enemy_hit_flash() -> void:
	"""Briefly tint the enemy model red on hit."""
	_hit_flash_timer = 0.12
	var meshes: Array[MeshInstance3D] = []
	_find_meshes_recursive(model, meshes)
	for mesh_node: MeshInstance3D in meshes:
		for i: int in range(mesh_node.get_surface_override_material_count()):
			var mat: Material = mesh_node.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = Color(1, 0.3, 0.3, 1)


func _restore_enemy_materials() -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes_recursive(model, meshes)
	for mesh_node: MeshInstance3D in meshes:
		for i: int in range(mesh_node.get_surface_override_material_count()):
			var mat: Material = mesh_node.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1)


func _find_meshes_recursive(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_meshes_recursive(child, result)


func _rotate_toward(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	# Consistent -Z forward convention: atan2(-x, -z) for baked 180° models
	var target_angle := atan2(-direction.x, -direction.z)
	if model:
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, 10.0 * delta)


func _update_animation() -> void:
	if not animation_player:
		return

	# Stunned enemies freeze in idle pose
	if is_stunned:
		_play_anim("Idle_A")
		return

	# KayKit animation names from rig files
	match current_state:
		State.DEAD:
			_play_anim("Death_A")
		State.HURT:
			_play_anim("Hit_A")
		State.ATTACK:
			_play_anim("Hit_A") # Reuse hit as attack for skeletons
		State.CHASE:
			_play_anim("Running_A")
		State.PATROL:
			_play_anim("Walking_A")
		State.IDLE:
			_play_anim("Idle_A")


func _play_anim(anim_name: String) -> void:
	if animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
	else:
		pass


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	emit_signal("enemy_damaged", self, current_health)

	# --- Impulse-based knockback ---
	# Knockback scales with damage dealt and inversely with resistance.
	# Heavy hits (combo finisher, crits) send enemies flying further.
	if source_position != Vector3.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		knockback_dir.y = 0

		# Base impulse + damage-proportional bonus
		var impulse_strength: float = (4.0 + float(amount) * 0.2) / knockback_resistance
		_knockback_velocity = knockback_dir * impulse_strength
		# Small upward pop for game feel (larger hits = more pop)
		_knockback_velocity.y = clampf(float(amount) * 0.08, 0.5, 3.0) / knockback_resistance

	# Visual feedback — flash red
	_apply_enemy_hit_flash()

	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = hit_stagger_duration
		# Stagger interrupts current action
		is_stunned = true
		_stun_timer = hit_stagger_duration * 0.5


func _die() -> void:
	current_state = State.DEAD
	target = null
	is_stunned = false
	emit_signal("enemy_died", self)

	# --- Death launch: dramatic upward + outward impulse ---
	# Keep physics running briefly so the body flies through the air
	var launch_dir: Vector3 = _knockback_velocity.normalized()
	if launch_dir.length() < 0.1:
		# Random scatter if no knockback direction
		launch_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	velocity = launch_dir * death_tumble_force
	velocity.y = death_launch_force

	# Disable collision so dead body doesn't block players/enemies
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)
	# Keep environment mask (1) so body lands on floor

	# Disable detection area and disconnect signals so no deferred callbacks fire
	if detection_area:
		detection_area.set_collision_mask_value(2, false)
		detection_area.monitoring = false
		detection_area.monitorable = false
		if detection_area.body_entered.is_connected(_on_detection_body_entered):
			detection_area.body_entered.disconnect(_on_detection_body_entered)
		if detection_area.body_exited.is_connected(_on_detection_body_exited):
			detection_area.body_exited.disconnect(_on_detection_body_exited)

	# Play death animation directly
	if animation_player and animation_player.has_animation("Death_A"):
		animation_player.play("Death_A")

	# Spawn death VFX — purple poof with bone debris
	VFXHelper.spawn_death_poof(get_tree().root, global_position)

	# Let the body fly for a moment, then stop physics and despawn
	await get_tree().create_timer(0.6).timeout
	set_physics_process(false)
	set_process(false)

	# Despawn after death animation finishes
	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	timer.timeout.connect(queue_free)


func _on_detection_body_entered(body: Node3D) -> void:
	if current_state == State.DEAD:
		return
	if body is PlayerController:
		target = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body is PlayerController and body == target:
		# Keep chasing for a bit before losing interest
		pass


func stun(duration: float) -> void:
	"""Stun the enemy for the given duration."""
	if current_state == State.DEAD:
		return
	is_stunned = true
	_stun_timer = duration
	velocity.x = 0
	velocity.z = 0
