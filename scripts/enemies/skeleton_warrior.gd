extends EnemyBase
class_name SkeletonWarrior

## Skeleton Warrior — armored melee bruiser found in the French Quarter.
## Tougher than Minions, hits harder, and has a shield bash that stuns.
## Uses Skeleton_Warrior.glb model.

var _shield_bash_cooldown: float = 6.0
var _shield_bash_timer: float = 0.0
var _bash_range: float = 2.5
var _bash_stun_duration: float = 1.0


func _ready() -> void:
	max_health = 45
	attack_damage = 12
	move_speed = 2.0
	chase_speed = 3.5
	attack_range = 2.0
	detection_range = 14.0
	attack_cooldown = 1.8

	super._ready()
	add_to_group("skeleton_warriors")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if _shield_bash_timer > 0:
		_shield_bash_timer -= delta


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	var dist: float = to_target.length()

	# Shield bash every 6 seconds when in range
	if _shield_bash_timer <= 0 and dist <= _bash_range:
		_perform_shield_bash()
	else:
		_perform_melee_attack()


func _perform_melee_attack() -> void:
	# Heavy overhead strike
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 2.5

	target.take_damage(attack_damage, global_position)


func _perform_shield_bash() -> void:
	## Shield bash — knocks player back and stuns briefly
	_shield_bash_timer = _shield_bash_cooldown

	var bash_dir: Vector3 = (target.global_position - global_position).normalized()
	bash_dir.y = 0
	velocity += bash_dir * 4.0

	# Deal reduced damage but stun the player
	var bash_damage: int = int(float(attack_damage) * 0.6)
	target.take_damage(bash_damage, global_position)

	# Knockback the player extra hard
	if target is CharacterBody3D:
		var player_body: CharacterBody3D = target as CharacterBody3D
		player_body.velocity += bash_dir * 8.0

	print("[SkeletonWarrior] Shield Bash!")
