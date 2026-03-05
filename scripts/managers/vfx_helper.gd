extends Node
class_name VFXHelper

## VFXHelper — Static utility for spawning one-shot GPU particle effects.
## Based on layering approach: each effect is a small scene tree with
## GPUParticles3D nodes + OmniLight3D, auto-removed after finishing.
##
## Usage:
##   VFXHelper.spawn_hit_sparks(get_tree().root, global_position)
##   VFXHelper.spawn_death_poof(get_tree().root, global_position)
##   VFXHelper.spawn_coin_pickup(get_tree().root, global_position)


## Spawn orange/yellow hit sparks at a position (melee impact).
## Uses billboard quad particles with align-Y for direction-facing.
static func spawn_hit_sparks(parent: Node, position: Vector3, color: Color = Color(1.0, 0.7, 0.2)) -> void:
	var root: Node3D = Node3D.new()
	root.name = "HitSparks"
	parent.add_child(root)
	root.global_position = position

	# -- Spark particles --
	var sparks: GPUParticles3D = GPUParticles3D.new()
	sparks.amount = 12
	sparks.lifetime = 0.4
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.emitting = true

	var spark_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 3.0
	spark_mat.initial_velocity_max = 8.0
	spark_mat.gravity = Vector3(0, -6, 0)
	spark_mat.scale_min = 0.05
	spark_mat.scale_max = 0.12
	spark_mat.color = color
	# Fade out over lifetime
	var alpha_curve: CurveTexture = CurveTexture.new()
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	spark_mat.alpha_curve = alpha_curve
	sparks.process_material = spark_mat

	# Use a small sphere mesh for sparks
	var spark_mesh: SphereMesh = SphereMesh.new()
	spark_mesh.radius = 0.05
	spark_mesh.height = 0.1
	var spark_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_draw_mat.vertex_color_use_as_albedo = true
	spark_draw_mat.emission_enabled = true
	spark_draw_mat.emission = color
	spark_draw_mat.emission_energy_multiplier = 2.0
	spark_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = spark_draw_mat
	sparks.draw_pass_1 = spark_mesh

	root.add_child(sparks)

	# -- Brief flash light --
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 3.0
	flash.omni_range = 3.0
	flash.omni_attenuation = 2.0
	root.add_child(flash)

	# Animate flash fade-out and cleanup
	var tween: Tween = root.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.3)
	tween.tween_callback(root.queue_free).set_delay(0.5)


## Spawn a magical poof when an enemy dies — billboarded expanding particles.
static func spawn_death_poof(parent: Node, position: Vector3, color: Color = Color(0.6, 0.2, 1.0)) -> void:
	var root: Node3D = Node3D.new()
	root.name = "DeathPoof"
	parent.add_child(root)
	root.global_position = position + Vector3(0, 0.5, 0)

	# -- Smoke/poof particles --
	var poof: GPUParticles3D = GPUParticles3D.new()
	poof.amount = 16
	poof.lifetime = 0.8
	poof.one_shot = true
	poof.explosiveness = 0.85
	poof.emitting = true

	var poof_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	poof_mat.direction = Vector3(0, 1, 0)
	poof_mat.spread = 180.0
	poof_mat.initial_velocity_min = 1.0
	poof_mat.initial_velocity_max = 4.0
	poof_mat.gravity = Vector3(0, 2, 0)  # Drift upward
	poof_mat.scale_min = 0.15
	poof_mat.scale_max = 0.4
	poof_mat.color = color
	# Scale up over time then shrink
	var scale_curve: CurveTexture = CurveTexture.new()
	var s_curve: Curve = Curve.new()
	s_curve.add_point(Vector2(0.0, 0.3))
	s_curve.add_point(Vector2(0.3, 1.0))
	s_curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = s_curve
	poof_mat.scale_curve = scale_curve
	# Alpha fade
	var alpha_curve: CurveTexture = CurveTexture.new()
	var a_curve: Curve = Curve.new()
	a_curve.add_point(Vector2(0.0, 0.0))
	a_curve.add_point(Vector2(0.1, 1.0))
	a_curve.add_point(Vector2(0.7, 0.6))
	a_curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = a_curve
	poof_mat.alpha_curve = alpha_curve
	poof.process_material = poof_mat

	# Billboard sphere for soft look
	var poof_mesh: SphereMesh = SphereMesh.new()
	poof_mesh.radius = 0.2
	poof_mesh.height = 0.4
	var poof_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	poof_draw_mat.vertex_color_use_as_albedo = true
	poof_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	poof_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	poof_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	poof_draw_mat.billboard_keep_scale = true
	poof_mesh.material = poof_draw_mat
	poof.draw_pass_1 = poof_mesh

	root.add_child(poof)

	# -- Small bone fragments (debris) --
	var debris: GPUParticles3D = GPUParticles3D.new()
	debris.amount = 8
	debris.lifetime = 1.0
	debris.one_shot = true
	debris.explosiveness = 0.95
	debris.emitting = true

	var debris_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	debris_mat.direction = Vector3(0, 1, 0)
	debris_mat.spread = 180.0
	debris_mat.initial_velocity_min = 2.0
	debris_mat.initial_velocity_max = 6.0
	debris_mat.gravity = Vector3(0, -10, 0)
	debris_mat.scale_min = 0.03
	debris_mat.scale_max = 0.08
	debris_mat.color = Color(0.85, 0.8, 0.7)  # Bone white
	debris.process_material = debris_mat

	var debris_mesh: BoxMesh = BoxMesh.new()
	debris_mesh.size = Vector3(0.06, 0.06, 0.06)
	var debris_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	debris_draw_mat.vertex_color_use_as_albedo = true
	debris_mesh.material = debris_draw_mat
	debris.draw_pass_1 = debris_mesh

	root.add_child(debris)

	# -- Flash light --
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 4.0
	flash.omni_range = 4.0
	flash.omni_attenuation = 2.0
	root.add_child(flash)

	var tween: Tween = root.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.5)
	tween.tween_callback(root.queue_free).set_delay(1.5)


## Spawn sparkle effect when collecting a coin.
static func spawn_coin_pickup(parent: Node, position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "CoinPickup"
	parent.add_child(root)
	root.global_position = position

	var sparkle_color: Color = Color(0.7, 0.3, 1.0)  # Purple for purple coins

	var sparkles: GPUParticles3D = GPUParticles3D.new()
	sparkles.amount = 20
	sparkles.lifetime = 0.6
	sparkles.one_shot = true
	sparkles.explosiveness = 0.8
	sparkles.emitting = true

	var sparkle_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	sparkle_mat.direction = Vector3(0, 1, 0)
	sparkle_mat.spread = 180.0
	sparkle_mat.initial_velocity_min = 2.0
	sparkle_mat.initial_velocity_max = 5.0
	sparkle_mat.gravity = Vector3(0, 1, 0)
	sparkle_mat.scale_min = 0.03
	sparkle_mat.scale_max = 0.08
	sparkle_mat.color = sparkle_color
	# Alpha fade
	var alpha_curve: CurveTexture = CurveTexture.new()
	var a_curve: Curve = Curve.new()
	a_curve.add_point(Vector2(0.0, 1.0))
	a_curve.add_point(Vector2(0.5, 0.8))
	a_curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = a_curve
	sparkle_mat.alpha_curve = alpha_curve
	sparkles.process_material = sparkle_mat

	var sparkle_mesh: SphereMesh = SphereMesh.new()
	sparkle_mesh.radius = 0.04
	sparkle_mesh.height = 0.08
	var sparkle_draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	sparkle_draw_mat.vertex_color_use_as_albedo = true
	sparkle_draw_mat.emission_enabled = true
	sparkle_draw_mat.emission = sparkle_color
	sparkle_draw_mat.emission_energy_multiplier = 3.0
	sparkle_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sparkle_draw_mat.billboard_keep_scale = true
	sparkle_mesh.material = sparkle_draw_mat
	sparkles.draw_pass_1 = sparkle_mesh

	root.add_child(sparkles)

	# -- Flash light --
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = sparkle_color
	flash.light_energy = 2.5
	flash.omni_range = 3.0
	root.add_child(flash)

	var tween: Tween = root.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.4)
	tween.tween_callback(root.queue_free).set_delay(1.0)


## Boss entrance — dramatic energy swirl + shockwave.
static func spawn_boss_entrance(parent: Node, position: Vector3, color: Color = Color(0.8, 0.2, 1.0)) -> void:
	var root: Node3D = Node3D.new()
	root.name = "BossEntrance"
	parent.add_child(root)
	root.global_position = position + Vector3(0, 1.0, 0)

	# -- Energy swirl (pre-process simulates windup) --
	var swirl: GPUParticles3D = GPUParticles3D.new()
	swirl.amount = 30
	swirl.lifetime = 1.5
	swirl.one_shot = true
	swirl.explosiveness = 0.3
	swirl.emitting = true

	var swirl_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	swirl_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	swirl_mat.emission_sphere_radius = 2.0
	swirl_mat.direction = Vector3(0, 1, 0)
	swirl_mat.spread = 60.0
	swirl_mat.initial_velocity_min = 1.0
	swirl_mat.initial_velocity_max = 3.0
	swirl_mat.gravity = Vector3(0, 3, 0)
	swirl_mat.scale_min = 0.1
	swirl_mat.scale_max = 0.25
	swirl_mat.color = color
	# Scale curve — grow then shrink
	var s_curve_tex: CurveTexture = CurveTexture.new()
	var s_curve: Curve = Curve.new()
	s_curve.add_point(Vector2(0.0, 0.2))
	s_curve.add_point(Vector2(0.4, 1.0))
	s_curve.add_point(Vector2(1.0, 0.0))
	s_curve_tex.curve = s_curve
	swirl_mat.scale_curve = s_curve_tex
	swirl.process_material = swirl_mat

	var swirl_mesh: SphereMesh = SphereMesh.new()
	swirl_mesh.radius = 0.12
	swirl_mesh.height = 0.24
	var swirl_draw: StandardMaterial3D = StandardMaterial3D.new()
	swirl_draw.vertex_color_use_as_albedo = true
	swirl_draw.emission_enabled = true
	swirl_draw.emission = color
	swirl_draw.emission_energy_multiplier = 3.0
	swirl_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swirl_draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	swirl_draw.billboard_keep_scale = true
	swirl_mesh.material = swirl_draw
	swirl.draw_pass_1 = swirl_mesh

	root.add_child(swirl)

	# -- Shockwave ring (single particle, expanding sphere) --
	var wave: GPUParticles3D = GPUParticles3D.new()
	wave.amount = 1
	wave.lifetime = 0.6
	wave.one_shot = true
	wave.explosiveness = 1.0
	wave.emitting = true

	var wave_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	wave_mat.gravity = Vector3.ZERO
	wave_mat.scale_min = 0.5
	wave_mat.scale_max = 0.5
	wave_mat.color = Color(color.r, color.g, color.b, 0.6)
	# Rapidly expand
	var wave_scale: CurveTexture = CurveTexture.new()
	var ws_curve: Curve = Curve.new()
	ws_curve.add_point(Vector2(0.0, 0.1))
	ws_curve.add_point(Vector2(0.3, 1.0))
	ws_curve.add_point(Vector2(1.0, 1.5))
	wave_scale.curve = ws_curve
	wave_mat.scale_curve = wave_scale
	# Fade out
	var wave_alpha: CurveTexture = CurveTexture.new()
	var wa_curve: Curve = Curve.new()
	wa_curve.add_point(Vector2(0.0, 0.8))
	wa_curve.add_point(Vector2(0.5, 0.4))
	wa_curve.add_point(Vector2(1.0, 0.0))
	wave_alpha.curve = wa_curve
	wave_mat.alpha_curve = wave_alpha
	wave.process_material = wave_mat

	var wave_mesh: SphereMesh = SphereMesh.new()
	wave_mesh.radius = 2.0
	wave_mesh.height = 4.0
	var wave_draw: StandardMaterial3D = StandardMaterial3D.new()
	wave_draw.vertex_color_use_as_albedo = true
	wave_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave_draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	wave_mesh.material = wave_draw
	wave.draw_pass_1 = wave_mesh

	root.add_child(wave)

	# -- Dramatic light pulse --
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 6.0
	flash.omni_range = 10.0
	flash.omni_attenuation = 1.5
	root.add_child(flash)

	var tween: Tween = root.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 1.2)
	tween.tween_callback(root.queue_free).set_delay(2.0)


## Spawn a healing effect (green particles drifting upward).
static func spawn_heal_effect(parent: Node, position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.name = "HealEffect"
	parent.add_child(root)
	root.global_position = position

	var heal_color: Color = Color(0.2, 1.0, 0.4)

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.emitting = true

	var p_mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 30.0
	p_mat.initial_velocity_min = 1.0
	p_mat.initial_velocity_max = 3.0
	p_mat.gravity = Vector3(0, 1, 0)
	p_mat.scale_min = 0.04
	p_mat.scale_max = 0.1
	p_mat.color = heal_color
	var alpha_curve: CurveTexture = CurveTexture.new()
	var a_curve: Curve = Curve.new()
	a_curve.add_point(Vector2(0.0, 0.0))
	a_curve.add_point(Vector2(0.2, 1.0))
	a_curve.add_point(Vector2(0.8, 0.6))
	a_curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = a_curve
	p_mat.alpha_curve = alpha_curve
	particles.process_material = p_mat

	var p_mesh: SphereMesh = SphereMesh.new()
	p_mesh.radius = 0.05
	p_mesh.height = 0.1
	var draw_mat: StandardMaterial3D = StandardMaterial3D.new()
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.emission_enabled = true
	draw_mat.emission = heal_color
	draw_mat.emission_energy_multiplier = 2.0
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.billboard_keep_scale = true
	p_mesh.material = draw_mat
	particles.draw_pass_1 = p_mesh

	root.add_child(particles)

	var tween: Tween = root.create_tween()
	tween.tween_callback(root.queue_free).set_delay(1.5)
