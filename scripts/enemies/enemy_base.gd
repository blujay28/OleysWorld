extends CharacterBody3D
class_name EnemyBase

## Base class for all enemies in Oley's World.
## 
## REFINEMENTS over vertical slice:
##   - Attack telegraphing: enemies wind up before dealing damage (player gets reaction window)
##   - Sane detection ranges: enemies don't all aggro from across the map
##   - Group coordination: stagger attack timing so enemies don't all swing at once
##   - Better stagger: hits feel meatier, enemies reel longer
##   - Orbit behavior: melee enemies circle the player instead of stacking
##   - Gravity uses is_on_floor properly for death launches

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
@export var knockback_resistance: float = 1.0
@export var knockback_decay: float = 8.0
@export var death_launch_force: float = 8.0
@export var death_tumble_force: float = 5.0
@export var hit_stagger_duration: float = 0.4   ## INCREASED from 0.3 — hits feel heavier

# -- Attack Telegraph --
@export_group("Attack Telegraph")
@export var telegraph_duration: float = 0.4      ## Wind-up time before damage lands
@export var telegraph_color: Color = Color(1, 0.3, 0.2, 0.8)  ## Flash color during wind-up

# -- Group Coordination --
@export_group("Group AI")
@export var attack_delay_variance: float = 0.6   ## Random delay added so enemies don't all swing together
@export var orbit_speed: float = 2.0             ## Speed at which enemies circle the player
@export var orbit_direction: float = 1.0         ## 1 or -1, randomized on spawn
@export var preferred_spacing: float = 2.0       ## Min distance from other enemies

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
var _knockback_velocity: Vector3 = Vector3.ZERO
var _hit_flash_timer: float = 0.0

# -- Telegraph state --
var _is_telegraphing: bool = false
var _telegraph_timer: float = 0.0

# -- Group coordination --
var _group_attack_delay: float = 0.0  ## Per-instance random delay before attacking

# -- Node references --
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = null
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null
@onready var detection_area: Area3D = $DetectionArea if has_node("DetectionArea") else null

# -- Signals --
signal enemy_died(enemy: EnemyBase)
signal enemy_damaged(enemy: EnemyBase, remaining_health: int)


func _ready() -> void:
	current_health = max_health
	_spawn_position = global_position
	add_to_group("enemies")

	# Randomize orbit direction so enemies circle both ways
	orbit_direction = 1.0 if randf() > 0.5 else -1.0

	# Random attack delay so groups don't all swing at frame 0
	_group_attack_delay = randf_range(0.0, attack_delay_variance)
	_attack_timer = _group_attack_delay

	# Setup AnimationPlayer on the model INSTANCE (SkeletonModel)
	var char_model_instance: Node3D = model.get_child(0) as Node3D
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

	if patrol_points.is_empty():
		current_state = State.IDLE
	else:
		current_state = State.PATROL


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return

	if global_position.y < -10.0:
		_die()
		return

	_apply_gravity(delta)
	_update_timers(delta)
	_apply_knockback_decay(delta)

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

	velocity.x += _knockback_velocity.x
	velocity.z += _knockback_velocity.z
	velocity.y += _knockback_velocity.y

	move_and_slide()

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

	# Telegraph timer — when it expires, the actual hit lands
	if _is_telegraphing:
		_telegraph_timer -= delta
		if _telegraph_timer <= 0.0:
			_is_telegraphing = false
			_execute_attack()
			_restore_enemy_materials()  # Remove telegraph flash

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
			if target and is_instance_valid(target):
				current_state = State.CHASE
			else:
				current_state = State.IDLE


func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

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

	if y_diff > 3.0:
		return

	# In attack range → attack
	if distance <= attack_range:
		current_state = State.ATTACK
		velocity.x = 0
		velocity.z = 0
		return

	# Lost interest
	if distance > detection_range * 1.5:
		target = null
		current_state = State.IDLE
		return

	# ---- ORBIT BEHAVIOR (NEW) ----
	# When close to attack range, circle the player instead of running straight in.
	# This prevents the "damage blob" problem where all enemies stack on each other.
	if distance < attack_range * 2.5:
		var forward_dir := to_target.normalized()
		# Perpendicular orbit vector
		var orbit_dir := Vector3(-forward_dir.z, 0, forward_dir.x) * orbit_direction
		# Blend: mostly forward (close gap) + some orbit (circle)
		var blend: float = clampf((distance - attack_range) / (attack_range * 1.5), 0.0, 1.0)
		var move_dir := (forward_dir * blend + orbit_dir * (1.0 - blend * 0.7)).normalized()

		velocity.x = move_dir.x * chase_speed * 0.8
		velocity.z = move_dir.z * chase_speed * 0.8
		_rotate_toward(forward_dir, delta)  # Always face player

		# Push away from nearby allies to avoid stacking
		_apply_separation(delta)
	else:
		# Far away — beeline toward player
		var direction := to_target.normalized()
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed
		_rotate_toward(direction, delta)


func _apply_separation(delta: float) -> void:
	## Push away from nearby allies to prevent stacking.
	var allies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var push := Vector3.ZERO

	for ally_node: Node in allies:
		if ally_node == self or not (ally_node is Node3D):
			continue
		var ally: Node3D = ally_node as Node3D
		var to_ally: Vector3 = global_position - ally.global_position
		to_ally.y = 0
		var dist: float = to_ally.length()
		if dist < preferred_spacing and dist > 0.01:
			# Stronger push the closer we are
			push += to_ally.normalized() * (preferred_spacing - dist) / preferred_spacing

	if push.length() > 0.01:
		velocity.x += push.x * 4.0 * delta * chase_speed
		velocity.z += push.z * 4.0 * delta * chase_speed


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

	if not target or not is_instance_valid(target):
		target = null
		current_state = State.IDLE
		return

	var to_target := target.global_position - global_position
	var y_diff := absf(to_target.y)
	to_target.y = 0
	_rotate_toward(to_target.normalized(), delta)

	if y_diff > 3.0:
		current_state = State.CHASE
		return

	if to_target.length() > attack_range * 1.3:
		current_state = State.CHASE
		return

	# ---- TELEGRAPH SYSTEM (NEW) ----
	# Instead of instantly dealing damage, we START a telegraph.
	# The enemy flashes/winds up, giving the player a reaction window.
	# After telegraph_duration, _execute_attack() actually deals damage.
	if _attack_timer <= 0 and not _is_telegraphing:
		_start_telegraph()
		_attack_timer = attack_cooldown + randf_range(0.0, attack_delay_variance)


func _start_telegraph() -> void:
	## Visual wind-up before the attack connects.
	## Player sees the flash and has telegraph_duration seconds to dodge.
	_is_telegraphing = true
	_telegraph_timer = telegraph_duration

	# Flash the enemy a warning color
	_apply_telegraph_flash()

	# Play attack animation during wind-up (the anim IS the telegraph)
	if animation_player:
		_play_anim("Hit_A")  # Reuse hit as attack telegraph for skeletons


func _execute_attack() -> void:
	## Actually deal damage — called after telegraph expires.
	## Override in subclasses for different attack behaviors.
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("take_damage"):
		return

	# Check player is still in range (they might have dodged during telegraph!)
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	if to_target.length() > attack_range * 1.5:
		# Player dodged out — attack whiffs!
		return

	var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
	hit_pos.y += 0.5
	VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.5, 0.2))
	target.take_damage(attack_damage, global_position)


func _perform_attack() -> void:
	## Legacy method — subclasses that override this still work.
	## But prefer overriding _execute_attack() for telegraph support.
	_execute_attack()


func _apply_telegraph_flash() -> void:
	## Flash the enemy a warning color during wind-up.
	var meshes: Array[MeshInstance3D] = []
	_find_meshes_recursive(model, meshes)
	for mesh_node: MeshInstance3D in meshes:
		for i: int in range(mesh_node.get_surface_override_material_count()):
			var mat: Material = mesh_node.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				(mat as StandardMaterial3D).albedo_color = telegraph_color


func _process_hurt(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * _delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * _delta)


func _apply_knockback_decay(delta: float) -> void:
	_knockback_velocity.x = move_toward(_knockback_velocity.x, 0.0, knockback_decay * delta)
	_knockback_velocity.z = move_toward(_knockback_velocity.z, 0.0, knockback_decay * delta)
	if is_on_floor():
		_knockback_velocity.y = 0.0
	else:
		_knockback_velocity.y = move_toward(_knockback_velocity.y, 0.0, knockback_decay * 0.5 * delta)


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0:
			_restore_enemy_materials()


func _apply_enemy_hit_flash() -> void:
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
	var target_angle := atan2(-direction.x, -direction.z)
	if model:
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, 10.0 * delta)


func _update_animation() -> void:
	if not animation_player:
		return

	if is_stunned:
		_play_anim("Idle_A")
		return

	# Don't interrupt telegraph animation
	if _is_telegraphing:
		return

	match current_state:
		State.DEAD:
			_play_anim("Death_A")
		State.HURT:
			_play_anim("Hit_A")
		State.ATTACK:
			_play_anim("Idle_A")  # Idle between swings; telegraph plays attack anim
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


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	emit_signal("enemy_damaged", self, current_health)

	# Cancel telegraph on hit — getting smacked interrupts your swing
	if _is_telegraphing:
		_is_telegraphing = false
		_telegraph_timer = 0.0

	# Impulse knockback
	if source_position != Vector3.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		knockback_dir.y = 0
		var impulse_strength: float = (4.0 + float(amount) * 0.2) / knockback_resistance
		_knockback_velocity = knockback_dir * impulse_strength
		_knockback_velocity.y = clampf(float(amount) * 0.08, 0.5, 3.0) / knockback_resistance

	_apply_enemy_hit_flash()

	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = hit_stagger_duration
		# Stagger stuns for the FULL stagger duration (was 0.5x before — too short)
		is_stunned = true
		_stun_timer = hit_stagger_duration


func _die() -> void:
	current_state = State.DEAD
	target = null
	is_stunned = false
	_is_telegraphing = false
	emit_signal("enemy_died", self)

	# Death launch
	var launch_dir: Vector3 = _knockback_velocity.normalized()
	if launch_dir.length() < 0.1:
		launch_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	velocity = launch_dir * death_tumble_force
	velocity.y = death_launch_force

	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	if detection_area:
		detection_area.set_collision_mask_value(2, false)
		detection_area.monitoring = false
		detection_area.monitorable = false
		if detection_area.body_entered.is_connected(_on_detection_body_entered):
			detection_area.body_entered.disconnect(_on_detection_body_entered)
		if detection_area.body_exited.is_connected(_on_detection_body_exited):
			detection_area.body_exited.disconnect(_on_detection_body_exited)

	if animation_player and animation_player.has_animation("Death_A"):
		animation_player.play("Death_A")

	VFXHelper.spawn_death_poof(get_tree().root, global_position)

	await get_tree().create_timer(0.6).timeout
	set_physics_process(false)
	set_process(false)

	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	timer.timeout.connect(queue_free)


func _on_detection_body_entered(body: Node3D) -> void:
	if current_state == State.DEAD:
		return
	if body is PlayerController:
		target = body


func _on_detection_body_exited(body: Node3D) -> void:
	if body is PlayerController and body == target:
		pass


func stun(duration: float) -> void:
	if current_state == State.DEAD:
		return
	is_stunned = true
	_is_telegraphing = false  # Cancel any wind-up
	_stun_timer = duration
	velocity.x = 0
	velocity.z = 0
