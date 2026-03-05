extends EnemyBase
class_name SkeletonWarrior

## Skeleton Warrior — armored melee bruiser found in the French Quarter.
## Tougher than Minions, hits harder, and has a shield bash that stuns.
## Uses Skeleton_Warrior.glb model.
##
## REFINEMENTS:
##   - max_health 45 → 50 (beefier tank)
##   - telegraph_duration = 0.5 (slow wind-up, but punishing if it connects)
##   - knockback_resistance = 1.5 (harder to stagger)
##   - Shield bash uses telegraph system

var _shield_bash_cooldown: float = 6.0
var _shield_bash_timer: float = 0.0
var _bash_range: float = 2.5
var _bash_stun_duration: float = 1.0
var _next_attack_is_bash: bool = false


func _ready() -> void:
	max_health = 50                     # Was 45 — warriors are beefy
	attack_damage = 12
	move_speed = 2.0
	chase_speed = 3.5
	attack_range = 2.0
	detection_range = 14.0
	attack_cooldown = 1.8
	telegraph_duration = 0.5            # Slow wind-up — player can see it coming
	attack_delay_variance = 0.5
	knockback_resistance = 1.5          # Harder to stagger

	super._ready()
	add_to_group("skeleton_warriors")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if _shield_bash_timer > 0:
		_shield_bash_timer -= delta


func _execute_attack() -> void:
	## Override: check if this should be a bash or regular melee.
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Check player is still in range (they had telegraph_duration to dodge)
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	if to_target.length() > attack_range * 1.5:
		return  # Whiff — player dodged the telegraph

	if _next_attack_is_bash:
		_next_attack_is_bash = false
		_execute_shield_bash()
	else:
		_execute_melee_attack()

	# Queue up a bash for next attack if cooldown is ready
	if _shield_bash_timer <= 0:
		_next_attack_is_bash = true
		_shield_bash_timer = _shield_bash_cooldown


func _execute_melee_attack() -> void:
	# Heavy overhead strike
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 2.5

	var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
	hit_pos.y += 0.5
	VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.5, 0.2))

	target.take_damage(attack_damage, global_position)


func _execute_shield_bash() -> void:
	## Shield bash — knocks player back and stuns briefly
	var bash_dir: Vector3 = (target.global_position - global_position).normalized()
	bash_dir.y = 0
	velocity += bash_dir * 4.0

	var bash_damage: int = int(float(attack_damage) * 0.6)

	var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
	hit_pos.y += 0.5
	VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(0.8, 0.8, 1.0))

	target.take_damage(bash_damage, global_position)

	# Extra knockback on player
	if target is CharacterBody3D:
		var player_body: CharacterBody3D = target as CharacterBody3D
		player_body.velocity += bash_dir * 8.0

	print("[SkeletonWarrior] Shield Bash!")
