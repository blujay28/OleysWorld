extends Node
class_name AnimationHelper

## Loads animations from separate KayKit rig .glb files and applies them
## to a character model. KayKit ships models and animations in separate files
## that share the same skeleton bone structure (Rig_Medium).
##
## The AnimationPlayer MUST be a child of the character model instance root
## (e.g., RangerModel or SkeletonModel) so that the rig's track paths
## (like "Skeleton3D:hips") resolve correctly against the same hierarchy.
##
## Usage:
##   var anim_player = AnimationHelper.setup_animation_player(model_instance)
##   AnimationHelper.load_animations_from_rig(anim_player, "res://assets/animations/character/Rig_Medium_General.glb")


## Creates an AnimationPlayer as a child of the given model instance node,
## or returns the existing one if present.
static func setup_animation_player(model_instance: Node3D) -> AnimationPlayer:
	# Check if there's already an AnimationPlayer in this node
	for child: Node in model_instance.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer

	# Create new AnimationPlayer as child of the model instance root
	# This way, track paths from the rig (e.g., "Skeleton3D:hips") resolve
	# correctly since the model instance has the same hierarchy as the rig.
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	model_instance.add_child(anim_player)
	return anim_player


## Loads all animations from a rig .glb file and copies them into
## the target AnimationPlayer. Skips T-Pose and RESET animations.
static func load_animations_from_rig(target_player: AnimationPlayer, rig_path: String) -> void:
	var rig_resource: PackedScene = load(rig_path) as PackedScene
	if not rig_resource:
		push_warning("AnimationHelper: Could not load rig from %s" % rig_path)
		return

	var rig_instance: Node = rig_resource.instantiate()

	# Find the AnimationPlayer in the rig
	var rig_anim_player: AnimationPlayer = _find_node_of_type(rig_instance, "AnimationPlayer") as AnimationPlayer
	if not rig_anim_player:
		push_warning("AnimationHelper: No AnimationPlayer found in %s" % rig_path)
		rig_instance.queue_free()
		return

	# Get or create the default animation library
	var lib: AnimationLibrary
	if target_player.has_animation_library(""):
		lib = target_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		target_player.add_animation_library("", lib)

	# Copy each animation (skip T-Pose and RESET)
	for anim_name: StringName in rig_anim_player.get_animation_list():
		var name_str: String = String(anim_name)
		if name_str == "T-Pose" or name_str == "RESET":
			continue
		if lib.has_animation(anim_name):
			continue # Don't overwrite existing animations

		var anim: Animation = rig_anim_player.get_animation(anim_name)
		if anim:
			lib.add_animation(anim_name, anim.duplicate())

	rig_instance.queue_free()


## Recursively finds the first node of a given class name.
static func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_node_of_type(child, type_name)
		if result:
			return result
	return null
