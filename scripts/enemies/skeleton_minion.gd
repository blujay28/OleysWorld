extends EnemyBase
class_name SkeletonMinion

## Skeleton Minion - the basic fodder enemy.
## Uses Skeleton_Minion.glb model.
## Weak, slow, but appears in groups. Simple melee attack.

func _ready() -> void:
	# Override base stats for minion (weaker than other skeleton types)
	max_health = 20
	attack_damage = 8
	move_speed = 2.5
	chase_speed = 4.0
	attack_range = 1.8
	detection_range = 2500.0
	attack_cooldown = 1.5

	super._ready()
	add_to_group("skeleton_minions")


func _perform_attack() -> void:
	## Simple lunge attack
	if current_state == State.DEAD or is_stunned:
		return
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		# Small lunge toward target
		var lunge_dir := (target.global_position - global_position).normalized()
		lunge_dir.y = 0
		velocity += lunge_dir * 3.0

		target.take_damage(attack_damage, global_position)
