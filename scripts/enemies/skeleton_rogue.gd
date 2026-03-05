extends EnemyBase
class_name SkeletonRogue

## Skeleton Rogue — fast, evasive attacker found in the French Quarter.
## Low health but high damage. Dashes behind the player for backstab attacks.
## Uses Skeleton_Rogue.glb model.
##
## REFINEMENTS:
##   - telegraph_duration = 0.25 (very fast — hard to react to, matches rogue fantasy)
##   - knockback_resistance = 0.6 (light — gets sent flying on hit)
##   - detection_range 14 → 16 (alert scouts)
##   - Dash attack now uses telegraph system

var _dash_cooldown: float = 4.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_duration: float = 0.3
var _dash_elapsed: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _next_attack_is_dash: bool = false


func _ready() -> void:
	max_health = 18
	attack_damage = 15
	move_speed = 3.5
	chase_speed = 5.5
	attack_range = 1.5
	detection_range = 16.0              # Was 14 — rogues are alert scouts
	attack_cooldown = 1.0
	telegraph_duration = 0.25           # Very fast wind-up — hard to dodge
	attack_delay_variance = 0.3
	knockback_resistance = 0.6          # Light — gets sent flying

	super._ready()
	add_to_group("skeleton_rogues")


func _physics_process(delta: float) -> void:
	if _dash_timer > 0:
		_dash_timer -= delta

	# Handle dash movement
	if _is_dashing:
		_dash_elapsed += delta
		velocity.x = _dash_direction.x * 15.0
		velocity.z = _dash_direction.z * 15.0

		if _dash_elapsed >= _dash_duration:
			_is_dashing = false
			_dash_elapsed = 0.0
			velocity.x = 0
			velocity.z = 0

	super._physics_process(delta)


func _execute_attack() -> void:
	## Override: dash attack or quick slash based on cooldown.
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Check player is still in range (telegraph gave them 0.25s to react)
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	if to_target.length() > attack_range * 1.8:
		return  # Whiff

	if _dash_timer <= 0 and not _is_dashing:
		_perform_dash_attack()
	else:
		_perform_quick_slash()


func _perform_quick_slash() -> void:
	## Fast double-slash attack
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 4.0

	var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
	hit_pos.y += 0.5
	VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.4, 0.4))

	target.take_damage(attack_damage, global_position)


func _perform_dash_attack() -> void:
	## Dash behind the player, then attack from behind for bonus damage
	_dash_timer = _dash_cooldown

	var to_player: Vector3 = (target.global_position - global_position).normalized()
	to_player.y = 0

	# Dash to the side of the player
	var side_dir: Vector3 = Vector3(-to_player.z, 0, to_player.x)
	if randf() > 0.5:
		side_dir = -side_dir

	_dash_direction = (to_player + side_dir).normalized()
	_is_dashing = true
	_dash_elapsed = 0.0

	# Backstab damage (1.5x) after a slight delay
	var backstab_damage: int = int(float(attack_damage) * 1.5)
	var timer: SceneTreeTimer = get_tree().create_timer(0.25)
	timer.timeout.connect(_apply_backstab_damage.bind(backstab_damage))

	print("[SkeletonRogue] Dash Attack!")


func _apply_backstab_damage(damage_amount: int) -> void:
	if current_state == State.DEAD or is_stunned:
		return
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var dist: float = (target.global_position - global_position).length()
		if dist <= attack_range * 2.0:
			var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
			hit_pos.y += 0.5
			VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.2, 0.5))
			target.take_damage(damage_amount, global_position)
