extends EnemyBase
class_name SkeletonRogue

## Skeleton Rogue — fast, evasive attacker found in the French Quarter.
## Low health but high damage. Dashes behind the player for backstab attacks.
## Uses Skeleton_Rogue.glb model.

var _dash_cooldown: float = 4.0
var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_duration: float = 0.3
var _dash_elapsed: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	max_health = 18
	attack_damage = 15
	move_speed = 3.5
	chase_speed = 5.5
	attack_range = 1.5
	detection_range = 14.0
	attack_cooldown = 1.0

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


func _perform_attack() -> void:
	if current_state == State.DEAD or is_stunned:
		return
	if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	# Try to dash behind player every few seconds
	if _dash_timer <= 0 and not _is_dashing:
		_perform_dash_attack()
	else:
		_perform_quick_slash()


func _perform_quick_slash() -> void:
	## Fast double-slash attack
	var lunge_dir: Vector3 = (target.global_position - global_position).normalized()
	lunge_dir.y = 0
	velocity += lunge_dir * 4.0

	target.take_damage(attack_damage, global_position)


func _perform_dash_attack() -> void:
	## Dash behind the player, then attack from behind for bonus damage
	_dash_timer = _dash_cooldown

	# Calculate a point behind the player
	var to_player: Vector3 = (target.global_position - global_position).normalized()
	to_player.y = 0

	# Dash to the side of the player
	var side_dir: Vector3 = Vector3(-to_player.z, 0, to_player.x)
	if randf() > 0.5:
		side_dir = -side_dir

	_dash_direction = (to_player + side_dir).normalized()
	_is_dashing = true
	_dash_elapsed = 0.0

	# Deal backstab damage (1.5x) after a slight delay
	var backstab_damage: int = int(float(attack_damage) * 1.5)
	# Use a timer to apply damage at the end of the dash
	var timer: SceneTreeTimer = get_tree().create_timer(0.25)
	timer.timeout.connect(_apply_backstab_damage.bind(backstab_damage))

	print("[SkeletonRogue] Dash Attack!")


func _apply_backstab_damage(damage: int) -> void:
	if current_state == State.DEAD or is_stunned:
		return
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var dist: float = (target.global_position - global_position).length()
		if dist <= attack_range * 2.0:
			target.take_damage(damage, global_position)
