extends Node
class_name CombatFeel

## CombatFeel — Static utility for game-feel effects during combat.
##
## REFINEMENTS:
##   - Hitstop uses 0.1 timescale instead of 0.05 (less stuttery)
##   - Variable hitstop: light hits = short, combo finishers = long
##   - Screen shake uses fewer steps for less jitter
##   - Added spawn_slash_arc() for melee weapon VFX
##   - Added spawn_ground_impact() for heavy attacks


## Brief time-scale reduction for impact feel.
static func hitstop(tree: SceneTree, duration_sec: float = 0.04) -> void:
	if not tree:
		return
	Engine.time_scale = 0.1  # Was 0.05 — less aggressive, feels snappier
	var timer: SceneTreeTimer = tree.create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)


## Camera shake with smooth decay.
static func screen_shake(tree: SceneTree, duration: float = 0.2, intensity: float = 0.3) -> void:
	if not tree:
		return

	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	if not camera:
		return

	var original_h: float = camera.h_offset
	var original_v: float = camera.v_offset

	var shake_node: Node = Node.new()
	shake_node.name = "ScreenShake"
	tree.root.add_child(shake_node)

	var tween: Tween = shake_node.create_tween()
	var steps: int = int(duration / 0.025)  # Slightly fewer steps, smoother feel
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		var strength: float = intensity * (1.0 - t)  # Linear decay
		var h_off: float = original_h + randf_range(-strength, strength)
		var v_off: float = original_v + randf_range(-strength, strength)
		tween.tween_property(camera, "h_offset", h_off, 0.025)
		tween.parallel().tween_property(camera, "v_offset", v_off, 0.025)

	tween.tween_property(camera, "h_offset", original_h, 0.025)
	tween.parallel().tween_property(camera, "v_offset", original_v, 0.025)
	tween.tween_callback(shake_node.queue_free)


## Full combo finisher feel — longer hitstop + big shake.
static func combo_finisher_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.hitstop(tree, 0.08)  # Longer freeze for finisher weight
	var delay_timer: SceneTreeTimer = tree.create_timer(0.06, true, false, true)
	delay_timer.timeout.connect(func(): CombatFeel.screen_shake(tree, 0.3, 0.5))


## Light hit feel — tiny hitstop + small shake for normal attacks.
static func light_hit_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.hitstop(tree, 0.025)  # Very brief — just a "click"
	var delay_timer: SceneTreeTimer = tree.create_timer(0.02, true, false, true)
	delay_timer.timeout.connect(func(): CombatFeel.screen_shake(tree, 0.08, 0.12))


## Arrow impact feel — no hitstop, just a subtle camera punch.
static func arrow_hit_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.screen_shake(tree, 0.06, 0.08)


## ---- NEW: Slash arc VFX ----
## Spawns a brief arc mesh (like a sword trail) in front of the player.
## Uses an unshaded, transparent quad that scales up and fades out.
static func spawn_slash_arc(parent: Node, position: Vector3, direction: Vector3, color: Color = Color(1.0, 0.9, 0.5, 0.6), combo_index: int = 1) -> void:
	if not parent:
		return

	var root: Node3D = Node3D.new()
	root.name = "SlashArc"
	parent.add_child(root)
	root.global_position = position + Vector3(0, 0.8, 0)

	# Orient the arc to face the swing direction
	if direction.length() > 0.01:
		root.rotation.y = atan2(-direction.x, -direction.z)

	# Vary the arc based on combo hit (horizontal, diagonal, overhead)
	var arc_rotation_z: float = 0.0
	match combo_index:
		1: arc_rotation_z = 0.0       # Horizontal slice
		2: arc_rotation_z = -30.0     # Diagonal
		3: arc_rotation_z = -70.0     # Overhead chop

	# Create arc mesh (flat box stretched into an arc shape)
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var arc_mesh: BoxMesh = BoxMesh.new()
	arc_mesh.size = Vector3(2.0, 0.03, 0.8)  # Wide, thin, short depth
	mesh_inst.mesh = arc_mesh
	mesh_inst.position = Vector3(0, 0, -1.2)  # In front of player
	mesh_inst.rotation_degrees.z = arc_rotation_z

	var arc_mat: StandardMaterial3D = StandardMaterial3D.new()
	arc_mat.albedo_color = color
	arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_mat.emission_enabled = true
	arc_mat.emission = Color(color.r, color.g, color.b, 1.0)
	arc_mat.emission_energy_multiplier = 2.0
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.set_surface_override_material(0, arc_mat)
	root.add_child(mesh_inst)

	# Animate: scale up quickly, fade out
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.4, 1.0, 1.3), 0.12)
	tween.tween_property(arc_mat, "albedo_color:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)


## ---- NEW: Ground impact VFX ----
## Spawns a radial crack/dust ring for heavy attacks (combo finishers, boss slams).
static func spawn_ground_impact(parent: Node, position: Vector3, radius: float = 2.0, color: Color = Color(0.8, 0.6, 0.3, 0.5)) -> void:
	if not parent:
		return

	var root: Node3D = Node3D.new()
	root.name = "GroundImpact"
	parent.add_child(root)
	root.global_position = position + Vector3(0, 0.05, 0)

	# Flat expanding ring
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = radius * 0.3
	ring_mesh.bottom_radius = radius * 0.3
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh

	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = color
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.set_surface_override_material(0, ring_mat)
	root.add_child(ring)

	# Dust light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = radius
	light.position.y = 0.3
	root.add_child(light)

	# Animate: expand ring, fade out
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring_mesh, "top_radius", radius, 0.2)
	tween.tween_property(ring_mesh, "bottom_radius", radius, 0.2)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
