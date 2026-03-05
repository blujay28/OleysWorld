extends Node
class_name CombatFeel

## CombatFeel — Static utility for game-feel effects during combat.
## Hitstop (brief time-scale reduction), camera shake, and hit-lag.
##
## Usage:
##   CombatFeel.hitstop(get_tree(), 0.06)
##   CombatFeel.screen_shake(get_tree(), 0.3, 0.4)
##   CombatFeel.combo_finisher_feel(get_tree())


## Brief time-scale reduction for impact feel.
## Uses a process-independent timer callback to restore time scale.
static func hitstop(tree: SceneTree, duration_sec: float = 0.05) -> void:
	if not tree:
		return
	Engine.time_scale = 0.05  # Near-freeze
	# Use process_always=true so timer runs even during slow-mo
	var timer: SceneTreeTimer = tree.create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)


## Camera shake — apply random offset to the camera over a duration.
## Finds the active Camera3D and shakes it using a tween for smooth decay.
static func screen_shake(tree: SceneTree, duration: float = 0.2, intensity: float = 0.3) -> void:
	if not tree:
		return

	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	if not camera:
		return

	var original_h: float = camera.h_offset
	var original_v: float = camera.v_offset

	# Rapid random offsets via a brief loop, then restore
	var shake_node: Node = Node.new()
	shake_node.name = "ScreenShake"
	tree.root.add_child(shake_node)

	var tween: Tween = shake_node.create_tween()
	var steps: int = int(duration / 0.02)  # ~50fps shake updates
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		var strength: float = intensity * (1.0 - t)  # Decay over time
		var h_off: float = original_h + randf_range(-strength, strength)
		var v_off: float = original_v + randf_range(-strength, strength)
		tween.tween_property(camera, "h_offset", h_off, 0.02)
		tween.parallel().tween_property(camera, "v_offset", v_off, 0.02)

	# Restore original offsets and clean up
	tween.tween_property(camera, "h_offset", original_h, 0.02)
	tween.parallel().tween_property(camera, "v_offset", original_v, 0.02)
	tween.tween_callback(shake_node.queue_free)


## Full combo finisher feel — hitstop + big shake.
static func combo_finisher_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.hitstop(tree, 0.08)
	# Shake starts slightly delayed so hitstop and shake overlap nicely
	var delay_timer: SceneTreeTimer = tree.create_timer(0.06, true, false, true)
	delay_timer.timeout.connect(func(): CombatFeel.screen_shake(tree, 0.3, 0.4))


## Light hit feel — tiny hitstop + small shake for normal attacks.
static func light_hit_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.hitstop(tree, 0.03)
	var delay_timer: SceneTreeTimer = tree.create_timer(0.02, true, false, true)
	delay_timer.timeout.connect(func(): CombatFeel.screen_shake(tree, 0.1, 0.15))


## Arrow impact feel — no hitstop, just a subtle camera punch.
static func arrow_hit_feel(tree: SceneTree) -> void:
	if not tree:
		return
	CombatFeel.screen_shake(tree, 0.08, 0.1)
