extends MeshInstance3D
class_name SeeThroughWall

## A wall that becomes transparent when the camera is behind it
## (between the camera and the player). This prevents the camera
## from being blocked by walls in the dungeon.
##
## Attach this script to any MeshInstance3D wall. It checks each frame
## whether the wall sits between the camera and the player, and if so,
## fades to a configurable transparency.

@export var opaque_alpha: float = 1.0
@export var transparent_alpha: float = 0.15
@export var fade_speed: float = 8.0

var _current_alpha: float = 1.0
var _target_alpha: float = 1.0
var _material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("see_through_walls")

	# Ensure we have a unique material we can modify
	if get_surface_override_material(0):
		_material = get_surface_override_material(0).duplicate() as StandardMaterial3D
	elif mesh and mesh.surface_get_material(0):
		_material = mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	else:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.35, 0.28, 0.2, 1)

	# Enable transparency support
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	set_surface_override_material(0, _material)
	_current_alpha = opaque_alpha


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	# Find the player
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player_node: Node = players[0]
	if not (player_node is Node3D):
		return
	var player: Node3D = player_node as Node3D

	# Check if this wall is between camera and player
	var cam_pos: Vector3 = camera.global_position
	var player_pos: Vector3 = player.global_position + Vector3(0, 1, 0)  # Aim at player center
	var wall_pos: Vector3 = global_position

	# Project wall position onto the camera→player line
	var cam_to_player: Vector3 = player_pos - cam_pos
	var cam_to_wall: Vector3 = wall_pos - cam_pos
	var line_length: float = cam_to_player.length()

	if line_length < 0.1:
		_target_alpha = opaque_alpha
		_apply_alpha(delta)
		return

	var line_dir: Vector3 = cam_to_player / line_length
	var projection: float = cam_to_wall.dot(line_dir)

	# Wall must be between camera and player (along the line)
	if projection > 0 and projection < line_length:
		# Check perpendicular distance from wall center to the line
		var closest_point: Vector3 = cam_pos + line_dir * projection
		var perp_dist: float = (wall_pos - closest_point).length()

		# Use wall's AABB to determine a generous threshold
		var aabb: AABB = get_aabb()
		var wall_half_extent: float = max(aabb.size.x, aabb.size.z) * 0.5 + 2.0

		if perp_dist < wall_half_extent:
			_target_alpha = transparent_alpha
		else:
			_target_alpha = opaque_alpha
	else:
		_target_alpha = opaque_alpha

	_apply_alpha(delta)


func _apply_alpha(delta: float) -> void:
	_current_alpha = lerp(_current_alpha, _target_alpha, fade_speed * delta)

	if _material:
		var col: Color = _material.albedo_color
		col.a = _current_alpha
		_material.albedo_color = col

		# Optimization: when fully opaque, switch to opaque mode
		if _current_alpha > 0.99:
			_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		else:
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
