extends Area3D
class_name Arrow

## Arrow projectile fired by the Bow.
## Travels in a slight arc (gravity), sticks into surfaces on hit,
## and deals damage to enemies.

@export var speed: float = 30.0
@export var damage: int = 18
@export var max_distance: float = 60.0
@export var gravity_strength: float = 4.0
@export var lifetime: float = 5.0

var direction: Vector3 = Vector3.FORWARD
var velocity_vec: Vector3 = Vector3.ZERO
var distance_traveled: float = 0.0
var has_hit: bool = false
var is_crit: bool = false

var _lifetime_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $ArrowMesh


func _ready() -> void:
	# Set initial velocity from direction and speed
	velocity_vec = direction * speed

	# Orient arrow along travel direction
	_orient_to_velocity()

	# Connect collision signals
	body_entered.connect(_on_body_entered)

	_lifetime_timer = lifetime


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	# Apply gravity to velocity
	velocity_vec.y -= gravity_strength * delta

	# Move
	var movement: Vector3 = velocity_vec * delta
	global_position += movement
	distance_traveled += movement.length()

	# Orient arrow along travel direction
	_orient_to_velocity()

	# Lifetime / range check
	_lifetime_timer -= delta
	if distance_traveled >= max_distance or _lifetime_timer <= 0.0:
		queue_free()


func _orient_to_velocity() -> void:
	if velocity_vec.length() > 0.1:
		# Look along the velocity vector
		var target_pos: Vector3 = global_position + velocity_vec.normalized()
		look_at(target_pos, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return

	# Don't hit the player
	if body.is_in_group("player"):
		return

	has_hit = true

	# Deal damage
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)

		# Crit visual feedback
		if is_crit:
			print("[Arrow] CRITICAL HIT for %d damage!" % damage)
			# Big hit sparks + camera shake for crits
			VFXHelper.spawn_hit_sparks(get_tree().root, global_position, Color(1.0, 0.3, 0.8))
			CombatFeel.screen_shake(get_tree(), 0.15, 0.25)
		else:
			# Normal arrow hit — small sparks + subtle punch
			VFXHelper.spawn_hit_sparks(get_tree().root, global_position, Color(0.8, 0.8, 1.0))
			CombatFeel.arrow_hit_feel(get_tree())
	else:
		# Hit environment — small spark at impact point
		VFXHelper.spawn_hit_sparks(get_tree().root, global_position, Color(0.6, 0.5, 0.4))

	# Stick the arrow where it hit — disable physics, keep visual briefly
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)

	# Fade and remove after a moment
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)
