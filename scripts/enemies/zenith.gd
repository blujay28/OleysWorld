extends EnemyBase
class_name Zenith

## Zenith — The final boss of Oley's World.
## A mad scientist skeleton who uses technology and dark magic.
## Three phases:
##   Phase 1 (100-66%): Laser beam attacks + deploys turret mines
##   Phase 2 (66-33%): Adds shockwave dash + spawns Mage minions
##   Phase 3 (<33%): OVERLOAD — all abilities enhanced, arena hazards

@export var laser_damage: int = 20
@export var laser_range: float = 15.0
@export var laser_cooldown: float = 3.0
@export var mine_count: int = 3
@export var mine_cooldown: float = 12.0
@export var mine_damage: int = 25
@export var mine_radius: float = 3.0
@export var shockwave_damage: int = 15
@export var shockwave_radius: float = 6.0
@export var shockwave_cooldown: float = 7.0
@export var summon_cooldown_boss: float = 15.0

# Phase tracking
var current_phase: int = 1
var _phase_2_threshold: float = 0.66
var _phase_3_threshold: float = 0.33

# Ability timers
var _laser_timer: float = 2.0
var _mine_timer: float = 8.0
var _shockwave_timer: float = 0.0
var _summon_timer: float = 0.0
var _attack_count: int = 0

# References
var spawn_mage_scene: PackedScene = null
var spawn_minion_scene: PackedScene = null

# Arena hazard tracking (Phase 3)
var _hazard_active: bool = false
var _hazard_timer: float = 0.0

# -- Boss Signals --
signal boss_phase_changed(phase: int)
signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated


func _ready() -> void:
	max_health = 500
	attack_damage = 20
	move_speed = 2.0
	chase_speed = 3.0
	attack_range = 3.0
	detection_range = 30.0
	attack_cooldown = 2.0

	super._ready()
	add_to_group("bosses")
	add_to_group("zenith")

	current_health = max_health
	boss_health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Update ability timers
	_laser_timer -= delta
	_mine_timer -= delta
	_shockwave_timer -= delta
	_summon_timer -= delta

	if not target or not is_instance_valid(target):
		super._physics_process(delta)
		return

	# Laser attack — primary ranged ability
	if _laser_timer <= 0:
		_fire_laser()
		var cd: float = laser_cooldown
		if current_phase >= 3:
			cd *= 0.6
		_laser_timer = cd

	# Deploy mines
	if _mine_timer <= 0:
		_deploy_mines()
		_mine_timer = mine_cooldown

	# Phase 2+: Shockwave dash
	if current_phase >= 2 and _shockwave_timer <= 0:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0
		if to_target.length() < shockwave_radius * 1.5:
			_perform_shockwave()
			_shockwave_timer = shockwave_cooldown

	# Phase 2+: Summon mages
	if current_phase >= 2 and _summon_timer <= 0:
		_summon_minions()
		_summon_timer = summon_cooldown_boss

	# Phase 3: Arena hazards
	if current_phase >= 3 and not _hazard_active:
		_activate_arena_hazards()

	super._physics_process(delta)


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return

	_attack_count += 1

	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Melee attack with electric shock effect
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 4.0

	var damage: int = attack_damage
	if current_phase >= 3:
		damage = int(float(attack_damage) * 1.3)

	target.take_damage(damage, global_position)


func _fire_laser() -> void:
	## Fire a laser beam at the player
	if not target or not is_instance_valid(target):
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	if to_target.length() > laser_range:
		return

	print("[Zenith] Laser Beam!")

	# Create visual laser beam
	var beam: MeshInstance3D = MeshInstance3D.new()
	var beam_mesh: CylinderMesh = CylinderMesh.new()
	var beam_length: float = to_target.length()
	beam_mesh.top_radius = 0.08
	beam_mesh.bottom_radius = 0.08
	beam_mesh.height = beam_length
	beam.mesh = beam_mesh

	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1.0, 0.1, 0.1, 1)
	beam_mat.emission_energy_multiplier = 5.0
	beam.set_surface_override_material(0, beam_mat)

	get_tree().current_scene.add_child(beam)

	# Position beam between self and target
	var midpoint: Vector3 = (global_position + target.global_position) * 0.5
	midpoint.y = 1.0
	beam.global_position = midpoint

	# Rotate beam to face target
	var dir: Vector3 = to_target.normalized()
	beam.rotation.x = PI / 2.0
	beam.rotation.y = atan2(dir.x, dir.z)

	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(laser_damage, global_position)

	# Despawn beam after a flash
	_despawn_after(beam, 0.3)


func _deploy_mines() -> void:
	## Place proximity mines around the arena
	if not target or not is_instance_valid(target):
		return

	print("[Zenith] Deploying mines!")

	var count: int = mine_count
	if current_phase >= 3:
		count += 2

	for i: int in range(count):
		# Place mines in a spread around the player's area
		var angle: float = randf() * TAU
		var dist: float = randf_range(2.0, 8.0)
		var mine_pos: Vector3 = target.global_position + Vector3(cos(angle) * dist, 0.15, sin(angle) * dist)

		var mine: Node3D = Node3D.new()
		mine.name = "Mine_%d" % i
		get_tree().current_scene.add_child(mine)
		mine.global_position = mine_pos

		# Visual — pulsing red sphere
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		mesh.mesh = sphere

		var mine_mat: StandardMaterial3D = StandardMaterial3D.new()
		mine_mat.albedo_color = Color(0.8, 0.1, 0.1, 1)
		mine_mat.emission_enabled = true
		mine_mat.emission = Color(1.0, 0.1, 0.0, 1)
		mine_mat.emission_energy_multiplier = 3.0
		mesh.set_surface_override_material(0, mine_mat)
		mine.add_child(mesh)

		# Warning light
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.1, 0.0, 1)
		light.light_energy = 1.0
		light.omni_range = 2.0
		mine.add_child(light)

		# Arm mine after 1 second, check for proximity
		_arm_mine(mine, mine_pos)


func _arm_mine(mine: Node3D, pos: Vector3) -> void:
	await get_tree().create_timer(1.0).timeout

	# Check proximity every 0.2 seconds for 10 seconds
	for i: int in range(50):
		if not is_instance_valid(mine):
			return

		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for p: Node in players:
			if p and is_instance_valid(p) and p is Node3D:
				var p3d: Node3D = p as Node3D
				var dist: float = (p3d.global_position - pos).length()
				if dist <= mine_radius:
					# BOOM
					if p3d.has_method("take_damage"):
						p3d.take_damage(mine_damage, pos)
					mine.queue_free()
					return

		await get_tree().create_timer(0.2).timeout

	# Expire after 10 seconds
	if is_instance_valid(mine):
		mine.queue_free()


func _perform_shockwave() -> void:
	## Dash forward and create a shockwave on landing
	print("[Zenith] Shockwave Dash!")

	if not target or not is_instance_valid(target):
		return

	var dash_dir: Vector3 = (target.global_position - global_position).normalized()
	dash_dir.y = 0
	velocity += dash_dir * 12.0

	# Create shockwave visual
	var wave: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = shockwave_radius * 0.8
	torus.outer_radius = shockwave_radius
	wave.mesh = torus

	var wave_mat: StandardMaterial3D = StandardMaterial3D.new()
	wave_mat.albedo_color = Color(0.5, 0.2, 1.0, 0.5)
	wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_mat.emission_enabled = true
	wave_mat.emission = Color(0.5, 0.2, 1.0, 1)
	wave_mat.emission_energy_multiplier = 3.0
	wave.set_surface_override_material(0, wave_mat)

	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position + Vector3(0, 0.2, 0)

	# Damage nearby players
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p and is_instance_valid(p) and p is Node3D and p.has_method("take_damage"):
			var p3d: Node3D = p as Node3D
			var dist: float = (p3d.global_position - global_position).length()
			if dist <= shockwave_radius:
				p3d.take_damage(shockwave_damage, global_position)
				# Knockback
				if p3d is CharacterBody3D:
					var kb: CharacterBody3D = p3d as CharacterBody3D
					var kb_dir: Vector3 = (p3d.global_position - global_position).normalized()
					kb.velocity += kb_dir * 10.0

	_despawn_after(wave, 0.5)


func _summon_minions() -> void:
	print("[Zenith] Deploying test subjects!")

	var scenes: Array[PackedScene] = []
	if spawn_mage_scene:
		scenes.append(spawn_mage_scene)
	if spawn_minion_scene:
		scenes.append(spawn_minion_scene)

	if scenes.is_empty():
		return

	var count: int = 2
	if current_phase >= 3:
		count = 3

	for i: int in range(count):
		var scene: PackedScene = scenes[i % scenes.size()]
		var minion: Node3D = scene.instantiate()
		get_parent().add_child(minion)
		var angle: float = float(i) / float(count) * TAU
		var offset: Vector3 = Vector3(cos(angle) * 4.0, 0, sin(angle) * 4.0)
		minion.global_position = global_position + offset


func _activate_arena_hazards() -> void:
	## Phase 3: Create periodic electric floor panels
	_hazard_active = true
	print("[Zenith] OVERLOAD — Arena hazards active!")

	# Spawn hazard zones periodically
	_run_hazard_loop()


func _run_hazard_loop() -> void:
	while current_state != State.DEAD and current_phase >= 3:
		await get_tree().create_timer(3.0).timeout

		if current_state == State.DEAD:
			return

		# Create electric floor panel at random position near player
		if target and is_instance_valid(target):
			var t_pos: Vector3 = target.global_position
			var offset: Vector3 = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			var hazard_pos: Vector3 = t_pos + offset
			hazard_pos.y = 0.05

			# Warning indicator (yellow circle appears first)
			var warning: MeshInstance3D = MeshInstance3D.new()
			var warn_cyl: CylinderMesh = CylinderMesh.new()
			warn_cyl.top_radius = 2.5
			warn_cyl.bottom_radius = 2.5
			warn_cyl.height = 0.05
			warning.mesh = warn_cyl

			var warn_mat: StandardMaterial3D = StandardMaterial3D.new()
			warn_mat.albedo_color = Color(1.0, 0.8, 0.0, 0.3)
			warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			warn_mat.emission_enabled = true
			warn_mat.emission = Color(1.0, 0.8, 0.0, 1)
			warn_mat.emission_energy_multiplier = 2.0
			warning.set_surface_override_material(0, warn_mat)

			get_tree().current_scene.add_child(warning)
			warning.global_position = hazard_pos

			# After 1 second, the hazard goes off
			await get_tree().create_timer(1.0).timeout

			if is_instance_valid(warning):
				# Change to red/electric
				warn_mat.albedo_color = Color(0.5, 0.1, 1.0, 0.6)
				warn_mat.emission = Color(0.5, 0.1, 1.0, 1)
				warn_mat.emission_energy_multiplier = 5.0

				# Damage players standing on it
				var players: Array[Node] = get_tree().get_nodes_in_group("player")
				for p: Node in players:
					if p and is_instance_valid(p) and p is Node3D and p.has_method("take_damage"):
						var p3d: Node3D = p as Node3D
						var dist: float = (p3d.global_position - hazard_pos).length()
						if dist <= 2.5:
							p3d.take_damage(12, hazard_pos)

				_despawn_after(warning, 0.5)


func _despawn_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(current_health, 0)

	boss_health_changed.emit(current_health, max_health)
	enemy_damaged.emit(self, current_health)

	# Minimal knockback for final boss
	if source_position != Vector3.ZERO:
		var knockback_dir: Vector3 = (global_position - source_position).normalized()
		knockback_dir.y = 0
		velocity += knockback_dir * 0.5

	_check_phase_transition()

	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = 0.2


func _check_phase_transition() -> void:
	var hp_ratio: float = float(current_health) / float(max_health)
	var new_phase: int = 1

	if hp_ratio > _phase_2_threshold:
		new_phase = 1
	elif hp_ratio > _phase_3_threshold:
		new_phase = 2
	else:
		new_phase = 3

	if new_phase != current_phase:
		current_phase = new_phase
		boss_phase_changed.emit(current_phase)
		print("[Zenith] Entering PHASE %d!" % current_phase)

		if current_phase == 2:
			chase_speed = 3.5
			attack_cooldown = 1.5

		if current_phase == 3:
			# OVERLOAD
			chase_speed = 4.5
			attack_cooldown = 1.0
			laser_damage = 28
			mine_count = 5


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	target = null
	is_stunned = false
	_hazard_active = false

	set_physics_process(false)
	set_process(false)

	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	if detection_area:
		detection_area.set_collision_mask_value(2, false)
		detection_area.monitoring = false
		detection_area.monitorable = false

	if animation_player and animation_player.has_animation("Death_A"):
		animation_player.play("Death_A")

	enemy_died.emit(self)
	boss_defeated.emit()
	print("[Zenith] DEFEATED! Oley has saved the world!")
