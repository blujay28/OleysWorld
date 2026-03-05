extends Node3D
class_name CameraController

## Third-person camera pivot — orbits around the player via mouse input.
##
## Uses SpringArm3D for wall collision and a smooth-follow pattern so the
## camera doesn't snap harshly when walls push it forward/back.
##
## Scene structure expected:
##   CameraPivot (this script, top_level = true)
##     └─ SpringArm3D          (collision via SphereShape3D)
##         └─ SpringPosition   (Node3D — target position marker)
##     └─ Camera3D             (lerps toward SpringPosition each frame)

@export_group("Camera Settings")
@export var mouse_sensitivity: float = 0.003
@export_range(-90, 0, 0.1, "radians_as_degrees") var min_pitch: float = deg_to_rad(-60.0)
@export_range(0, 90, 0.1, "radians_as_degrees") var max_pitch: float = deg_to_rad(40.0)
@export var camera_distance: float = 5.0
@export var camera_height: float = 2.8

@export_group("Smooth Follow")
## How quickly the camera catches up to the spring position (higher = snappier).
@export var follow_speed: float = 8.0
## How quickly the pivot slides to the player's position when top_level is on.
@export var pivot_follow_speed: float = 12.0

# -- Node references --
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var spring_position: Node3D = $SpringArm3D/SpringPosition
@onready var camera: Camera3D = $Camera3D

# -- Internal state --
var _pitch: float = 0.0
var _yaw: float = 0.0
var _player: Node3D = null


func _ready() -> void:
	# Enable top_level so we don't inherit the player's rotation/scale.
	# We'll manually follow the player's position in _physics_process.
	top_level = true

	# Cache the player reference (our parent before top_level disconnects us).
	_player = get_parent() as Node3D

	# Snap to the player's initial position so the camera starts right.
	if _player:
		global_position = _player.global_position

	# Configure spring arm for collision avoidance.
	if spring_arm:
		spring_arm.spring_length = camera_distance
		spring_arm.position.y = camera_height
		# Only collide with environment (layer 1), NOT player (layer 2) or enemies (layer 4).
		spring_arm.collision_mask = 1
		# Exclude the player body itself to prevent self-collision.
		if _player:
			spring_arm.add_excluded_object(_player.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return

	# Apply yaw/pitch rotation DURING physics so it's in sync when
	# player_controller reads camera_pivot.global_transform.basis.
	rotation.y = _yaw
	if spring_arm:
		spring_arm.rotation.x = _pitch

	# Also follow the player position in physics for consistent basis.
	var pivot_weight: float = minf(pivot_follow_speed * delta, 1.0)
	global_position = global_position.lerp(_player.global_position, pivot_weight)


func _process(delta: float) -> void:
	if not camera or not spring_position:
		return

	# Smoothly interpolate the camera toward the spring's target position.
	# This prevents harsh snapping when the spring arm retracts/extends
	# due to wall collisions.
	var cam_weight: float = minf(follow_speed * delta, 1.0)
	camera.global_position = camera.global_position.lerp(
		spring_position.global_position, cam_weight
	)
	# Keep the camera looking at the pivot point (player head area).
	camera.look_at(global_position + Vector3.UP * camera_height * 0.5)


## Returns the world-space aim direction (camera forward, flattened to ground plane).
func get_aim_direction() -> Vector3:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()
