extends EnemyBase
class_name BaronSamedi

## Baron Samedi — Boss of Level 2: French Quarter.
## A voodoo skeleton lord who commands undead minions and curses the player.
## Three phases:
##   Phase 1 (100-66%): Melee staff strikes + summons Rogue minions
##   Phase 2 (66-33%): Adds poison cloud AoE + faster summons
##   Phase 3 (<33%): Voodoo Frenzy — teleports around arena, rapid attacks, mass summon

@export var summon_cooldown: float = 10.0
@export var summon_count: int = 2
@export var poison_radius: float = 4.0
@export var poison_damage: int = 3
@export var poison_duration: float = 4.0
@export var poison_cooldown: float = 8.0
@export var teleport_cooldown_boss: float = 5.0

# Phase tracking
var current_phase: int = 1
var _phase_2_threshold: float = 0.66
var _phase_3_threshold: float = 0.33

# Ability timers
var _summon_timer: float = 5.0  # First summon after 5 seconds
var _poison_timer: float = 0.0
var _teleport_timer_boss: float = 0.0
var _attack_count: int = 0

# Minion spawning — set by the level script after instantiation
var spawn_rogue_scene: PackedScene = null
var spawn_warrior_scene: PackedScene = null

# -- Boss Signals --
signal boss_phase_changed(phase: int)
signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated


func _ready() -> void:
	max_health = 350
	attack_damage = 18
	move_speed = 2.5
	chase_speed = 3.5
	attack_range = 2.5
	detection_range = 25.0
	attack_cooldown = 1.8

	super._ready()
	add_to_group("bosses")
	add_to_group("baron_samedi")

	current_health = max_health
	boss_health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Update ability timers
	_summon_timer -= delta
	_poison_timer -= delta
	_teleport_timer_boss -= delta

	# Phase 2+: Periodic poison clouds
	if current_phase >= 2 and _poison_timer <= 0 and target and is_instance_valid(target):
		_spawn_poison_cloud()
		_poison_timer = poison_cooldown

	# Phase 3: Periodic teleports
	if current_phase >= 3 and _teleport_timer_boss <= 0 and target and is_instance_valid(target):
		_perform_teleport()
		_teleport_timer_boss = teleport_cooldown_boss

	# Periodic summons
	if _summon_timer <= 0 and target and is_instance_valid(target):
		_summon_minions()
		var cd: float = summon_cooldown
		if current_phase >= 3:
			cd = summon_cooldown * 0.5  # Faster summons in phase 3
		_summon_timer = cd

	super._physics_process(delta)


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return

	_attack_count += 1

	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Every 4th attack is a heavy staff slam
	if _attack_count % 4 == 0:
		_perform_staff_slam()
	else:
		_perform_staff_strike()


func _perform_staff_strike() -> void:
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 3.0

	target.take_damage(attack_damage, global_position)


func _perform_staff_slam() -> void:
	## AoE slam — damages all players in radius
	print("[BaronSamedi] Staff Slam!")

	var slam_radius: float = 4.0
	var slam_damage: int = int(float(attack_damage) * 1.5)

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p and is_instance_valid(p) and p is Node3D and p.has_method("take_damage"):
			var p3d: Node3D = p as Node3D
			var dist: float = (p3d.global_position - global_position).length()
			if dist <= slam_radius:
				p3d.take_damage(slam_damage, global_position)


func _summon_minions() -> void:
	print("[BaronSamedi] Rise, my servants! (Phase %d)" % current_phase)

	var scene_to_use: PackedScene = spawn_rogue_scene
	if current_phase >= 2 and spawn_warrior_scene:
		# Phase 2+: alternate between rogues and warriors
		if _attack_count % 2 == 0:
			scene_to_use = spawn_warrior_scene

	if not scene_to_use:
		return

	var count: int = summon_count
	if current_phase >= 3:
		count = summon_count + 1  # Extra minion in phase 3

	for i: int in range(count):
		var minion: Node3D = scene_to_use.instantiate()
		get_parent().add_child(minion)
		var angle: float = float(i) / float(count) * TAU
		var offset: Vector3 = Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0)
		minion.global_position = global_position + offset

		# Connect death signal if the minion is an EnemyBase
		if minion is EnemyBase:
			var enemy: EnemyBase = minion as EnemyBase
			enemy.enemy_died.connect(_on_summoned_minion_died)


func _on_summoned_minion_died(_enemy: EnemyBase) -> void:
	pass  # Summoned minions don't affect level enemy count


func _spawn_poison_cloud() -> void:
	## Create a poison AoE at the player's position
	if not target or not is_instance_valid(target):
		return

	print("[BaronSamedi] Poison Cloud!")

	var cloud_pos: Vector3 = target.global_position
	cloud_pos.y = 0.1

	# Create visual cloud
	var cloud: Node3D = Node3D.new()
	cloud.name = "PoisonCloud"
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = cloud_pos

	# Green glowing ground circle
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = poison_radius
	cyl.bottom_radius = poison_radius
	cyl.height = 0.1
	mesh_inst.mesh = cyl

	var cloud_mat: StandardMaterial3D = StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.2, 0.8, 0.1, 0.4)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.1, 0.6, 0.05, 1)
	cloud_mat.emission_energy_multiplier = 2.0
	mesh_inst.set_surface_override_material(0, cloud_mat)
	cloud.add_child(mesh_inst)

	# Light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.2, 0.8, 0.1, 1)
	light.light_energy = 1.5
	light.omni_range = poison_radius
	light.position.y = 0.5
	cloud.add_child(light)

	# Damage over time
	_apply_poison_dot(cloud, cloud_pos)


func _apply_poison_dot(cloud: Node3D, center: Vector3) -> void:
	var ticks: int = int(poison_duration / 0.5)
	for i: int in range(ticks):
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(cloud):
			return

		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		for p: Node in players:
			if p and is_instance_valid(p) and p is Node3D and p.has_method("take_damage"):
				var p3d: Node3D = p as Node3D
				var dist: float = (p3d.global_position - center).length()
				if dist <= poison_radius:
					p3d.take_damage(poison_damage, center)

	# Despawn cloud
	if is_instance_valid(cloud):
		cloud.queue_free()


func _perform_teleport() -> void:
	if not target or not is_instance_valid(target):
		return

	print("[BaronSamedi] Shadow Step!")

	# Teleport to a random position around the player
	var angle: float = randf() * TAU
	var dist: float = randf_range(4.0, 7.0)
	var offset: Vector3 = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	var new_pos: Vector3 = target.global_position + offset
	new_pos.y = global_position.y

	global_position = new_pos
	velocity = Vector3.ZERO


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(current_health, 0)

	boss_health_changed.emit(current_health, max_health)
	enemy_damaged.emit(self, current_health)

	# Reduced knockback for boss
	if source_position != Vector3.ZERO:
		var knockback_dir: Vector3 = (global_position - source_position).normalized()
		knockback_dir.y = 0
		velocity += knockback_dir * 1.0

	_check_phase_transition()

	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = 0.25


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
		print("[BaronSamedi] Entering PHASE %d!" % current_phase)

		if current_phase == 2:
			chase_speed = 4.0
			attack_cooldown = 1.5

		if current_phase == 3:
			# VOODOO FRENZY
			chase_speed = 5.0
			attack_cooldown = 1.0
			summon_count = 3


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	target = null
	is_stunned = false

	set_physics_process(false)
	set_process(false)

	# Disable collision
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
	print("[BaronSamedi] DEFEATED!")
