extends EnemyBase
class_name BigMark

## Big Mark — the first boss of Oley's World.
## A massive skeleton found in the basement of Dade's House.
## Three phases: melee → ground slam → enrage + minion summon.

# Boss-specific stats
@export var slam_radius: float = 5.0
@export var slam_damage_multiplier: float = 1.2
@export var minion_spawn_count: int = 2

# Phase tracking
var current_phase: int = 1
var _phase_2_threshold: float = 0.66
var _phase_3_threshold: float = 0.33
var _has_spawned_phase_3_minions: bool = false

# Attack tracking
var _attack_count: int = 0

# Minion spawning — set by the level script after instantiation
var spawn_minion_scene: PackedScene = null

# -- Boss Signals --
signal boss_phase_changed(phase: int)
signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated


func _ready() -> void:
	max_health = 200
	attack_damage = 15
	move_speed = 2.5
	chase_speed = 3.5
	attack_range = 2.5
	detection_range = 2500.0
	attack_cooldown = 2.0

	super._ready()
	add_to_group("bosses")
	add_to_group("big_mark")

	# Re-set health after super (super sets current_health = max_health too)
	current_health = max_health
	boss_health_changed.emit(current_health, max_health)


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return

	_attack_count += 1

	# Phase 2+: every 3rd attack is a ground slam
	if current_phase >= 2 and _attack_count % 3 == 0:
		_perform_ground_slam()
	else:
		_perform_melee_attack()


func _perform_melee_attack() -> void:
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Heavy lunge — bigger than regular skeletons
	var lunge_dir := (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 5.0

	target.take_damage(attack_damage, global_position)
	print("[BigMark] Melee attack! Phase %d, attack #%d" % [current_phase, _attack_count])


func _perform_ground_slam() -> void:
	print("[BigMark] GROUND SLAM! Phase %d" % current_phase)

	# Damage all players within slam radius
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p and is_instance_valid(p) and p is Node3D and p.has_method("take_damage"):
			var p3d: Node3D = p as Node3D
			var to_player: Vector3 = p3d.global_position - global_position
			var dist: float = to_player.length()
			if dist <= slam_radius:
				var slam_dmg: int = int(float(attack_damage) * slam_damage_multiplier)
				p3d.take_damage(slam_dmg, global_position)


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	current_health = max(current_health, 0)

	# Boss-specific signal
	boss_health_changed.emit(current_health, max_health)
	enemy_damaged.emit(self, current_health)

	# Knockback — reduced for boss (he's heavy)
	if source_position != Vector3.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		knockback_dir.y = 0
		velocity += knockback_dir * 1.5

	# Check phase transitions BEFORE death check
	_check_phase_transition()

	if current_health <= 0:
		_die()
	else:
		current_state = State.HURT
		_hurt_timer = 0.3


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
		print("[BigMark] Entering PHASE %d!" % current_phase)

		if current_phase == 3:
			# ENRAGE: faster, meaner
			chase_speed = 5.0
			attack_cooldown = 1.2

			if not _has_spawned_phase_3_minions:
				_spawn_phase_3_minions()
				_has_spawned_phase_3_minions = true


func _spawn_phase_3_minions() -> void:
	if not spawn_minion_scene:
		print("[BigMark] No minion scene set — skipping summon")
		return

	print("[BigMark] Summoning %d skeleton minions!" % minion_spawn_count)
	for i: int in range(minion_spawn_count):
		var minion: Node3D = spawn_minion_scene.instantiate()
		# Must add_child BEFORE setting global_position
		get_parent().add_child(minion)
		var offset: Vector3 = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
		minion.global_position = global_position + offset


func _die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	target = null
	is_stunned = false

	# NUCLEAR: stop all processing
	set_physics_process(false)
	set_process(false)

	# Disable collision
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, false)

	# Disable detection
	if detection_area:
		detection_area.set_collision_mask_value(2, false)
		detection_area.monitoring = false
		detection_area.monitorable = false

	# Play death animation
	if animation_player and animation_player.has_animation("Death_A"):
		animation_player.play("Death_A")

	# Boss-specific signals — emit AFTER death anim starts
	enemy_died.emit(self)
	boss_defeated.emit()
	print("[BigMark] DEFEATED!")

	# Do NOT queue_free — let the level handle cleanup and victory sequence
