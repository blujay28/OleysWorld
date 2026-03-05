extends EnemyBase
class_name SkeletonMinion

## Skeleton Minion - the basic fodder enemy.
## Uses Skeleton_Minion.glb model.
## Weak, slow, but appears in groups. Simple melee attack.
##
## REFINEMENTS:
##   - detection_range reduced from 2500 to 14 — enemies don't all aggro at level start
##   - Added lunge telegraph: small lunge during wind-up, damage on connect
##   - Slightly more health so they don't pop instantly (20 → 25)

func _ready() -> void:
	max_health = 25                     # Was 20 — slightly more durable
	attack_damage = 8
	move_speed = 2.5
	chase_speed = 4.0
	attack_range = 1.8
	detection_range = 14.0              # Was 2500 — NOW enemies only aggro when you're nearby
	attack_cooldown = 1.5
	telegraph_duration = 0.35           # Short wind-up — player can dodge if they react
	attack_delay_variance = 0.8         # Groups stagger their swings over 0-0.8s

	super._ready()
	add_to_group("skeleton_minions")


func _execute_attack() -> void:
	## Lunge attack — telegraph already played, now connect the hit.
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Check player is still in range (they had telegraph_duration to dodge)
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0
	if to_target.length() > attack_range * 1.5:
		return  # Whiff — player dodged

	# Lunge forward on hit connect
	var lunge_dir := to_target.normalized()
	velocity += lunge_dir * 3.5

	# Hit sparks
	var hit_pos: Vector3 = (global_position + target.global_position) * 0.5
	hit_pos.y += 0.5
	VFXHelper.spawn_hit_sparks(get_tree().root, hit_pos, Color(1.0, 0.5, 0.2))

	target.take_damage(attack_damage, global_position)
