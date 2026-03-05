extends WeaponBase
class_name Sword

## Oley's Sword — Melee weapon with combo attacks.
## Uses CombatMelee animations (slice, chop, spin).
## 3-hit combo system: light → light → heavy finisher.
## Each hit in the combo has a window to chain the next attack.

@export var melee_range: float = 2.5
@export var arc_angle: float = 100.0       # Degrees of sweep
@export var combo_window: float = 0.8      # Seconds to chain next attack
@export var heavy_damage_mult: float = 2.0 # Finisher multiplier

# Combo state
var _combo_count: int = 0           # 0 = no combo, 1 = first hit, 2 = second, 3 = finisher
var _combo_timer: float = 0.0
var _is_swinging: bool = false
var _swing_timer: float = 0.0
var _swing_duration: float = 0.25   # How long the swing takes before dealing damage
var _player_ref: PlayerController = null

# Animation names for combo chain
var _combo_anims: Array[String] = [
	"Melee_1H_Attack_Slice_Horizontal",   # Light 1
	"Melee_1H_Attack_Slice_Diagonal",     # Light 2
	"Melee_1H_Attack_Chop",               # Heavy finisher
]

signal combo_hit(combo_index: int)
signal combo_reset


func _ready() -> void:
	weapon_name = "Sword"
	damage = 22
	fire_rate = 0.35  # Base cooldown between swings


func _process(delta: float) -> void:
	# Combo window timer
	if _combo_count > 0 and not _is_swinging:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset_combo()

	# Swing timing
	if _is_swinging:
		_swing_timer -= delta
		if _swing_timer <= 0.0:
			_execute_hit()

	_update_cooldown(delta)


func try_use(player: PlayerController) -> void:
	if not is_ready or _is_swinging:
		return

	_player_ref = player
	_start_swing(player)
	is_ready = false
	current_cooldown = fire_rate


func _start_swing(player: PlayerController) -> void:
	_is_swinging = true

	# Determine which combo hit this is
	if _combo_count < 3:
		_combo_count += 1
	else:
		_combo_count = 1  # Reset to first hit after finisher

	# Scale swing duration for finisher (slower, heavier)
	if _combo_count == 3:
		_swing_duration = 0.35
	else:
		_swing_duration = 0.2

	_swing_timer = _swing_duration

	# Play the appropriate combo animation
	var anim_index: int = _combo_count - 1
	if player.animation_player:
		# Try the specific combo animation, fall back to any melee animation
		var target_anim: String = _combo_anims[anim_index] if anim_index < _combo_anims.size() else _combo_anims[0]
		if player.animation_player.has_animation(target_anim):
			player.animation_player.stop()
			player.animation_player.play(target_anim)
		elif player.animation_player.has_animation("Melee_1H_Attack_Slice_Horizontal"):
			player.animation_player.stop()
			player.animation_player.play("Melee_1H_Attack_Slice_Horizontal")

	# Lunge the player forward — stronger on combo finisher
	if player.last_direction.length() > 0.1:
		var lunge_force: float = 5.0 if _combo_count == 3 else 3.0
		player.velocity += player.last_direction * lunge_force


func _execute_hit() -> void:
	_is_swinging = false
	_combo_timer = combo_window

	if not _player_ref or not is_instance_valid(_player_ref):
		_reset_combo()
		return

	var player: PlayerController = _player_ref

	# Calculate hit damage
	var hit_damage: int = damage
	if _combo_count == 3:
		hit_damage = int(float(damage) * heavy_damage_mult)

	# Apply crit multiplier if active
	if player.crit_active:
		hit_damage = int(float(hit_damage) * player.crit_multiplier)

	# Find enemies in the melee arc
	var player_pos: Vector3 = player.global_position
	var player_forward: Vector3 = player.last_direction
	if player_forward.length() < 0.1:
		player_forward = -player.model.global_transform.basis.z

	# Sphere query for enemies in range
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = melee_range
	query.shape = sphere_shape
	query.transform = Transform3D(Basis.IDENTITY, player_pos + Vector3.UP * 0.5)
	query.collision_mask = 4 | 16  # Enemies (4) + Interactables/Breakables (16)

	var results: Array = space_state.intersect_shape(query)
	var arc_rad: float = deg_to_rad(arc_angle / 2.0)
	var enemies_hit: int = 0

	for result: Dictionary in results:
		var collider: Node = result.get("collider")
		if not collider:
			continue

		# Get the actual damageable node (enemy or breakable prop)
		var target_node: Node3D = null
		if collider.has_method("take_damage"):
			target_node = collider as Node3D
		elif collider is CharacterBody3D and collider.has_method("take_damage"):
			target_node = collider as Node3D
		elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
			target_node = collider.get_parent() as Node3D

		if not target_node:
			continue

		# Check if target is within the arc
		var to_target: Vector3 = target_node.global_position - player_pos
		to_target.y = 0
		if to_target.length() < 0.1:
			continue
		to_target = to_target.normalized()

		var angle: float = acos(clamp(player_forward.dot(to_target), -1.0, 1.0))
		if angle <= arc_rad:
			target_node.take_damage(hit_damage, player_pos)
			enemies_hit += 1

			# Spawn hit sparks at the point of impact
			var hit_pos: Vector3 = (player_pos + target_node.global_position) * 0.5
			hit_pos.y += 0.8
			var spark_color: Color = Color(1.0, 0.8, 0.3) if target_node is EnemyBase else Color(0.7, 0.5, 0.2)
			VFXHelper.spawn_hit_sparks(player.get_tree().root, hit_pos, spark_color)

	# --- Game Feel: hitstop + screen shake on hit ---
	if enemies_hit > 0:
		if _combo_count == 3:
			# Combo finisher: big hitstop + heavy shake
			CombatFeel.combo_finisher_feel(player.get_tree())
		else:
			# Normal hits: light hitstop + small shake
			CombatFeel.light_hit_feel(player.get_tree())

	combo_hit.emit(_combo_count)
	weapon_used.emit()

	# Reset combo after finisher
	if _combo_count >= 3:
		# Small delay before combo resets to give the heavy hit weight
		_combo_timer = 0.3
		_combo_count = 3  # Will reset via timer

	_player_ref = null


func _reset_combo() -> void:
	_combo_count = 0
	_combo_timer = 0.0
	combo_reset.emit()
