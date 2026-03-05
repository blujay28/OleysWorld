extends CharacterBody3D
class_name PlayerController

## Player Controller for Oley (Ranger model)
## Handles movement, jumping, combat, and interaction.
## Weapons: Sword (melee, 3-hit combo) and Bow (ranged, draw-and-release).

# -- Movement --
@export_group("Movement")
@export var move_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var acceleration: float = 15.0
@export var friction: float = 12.0
@export var rotation_speed: float = 12.0

# -- Jumping --
@export_group("Jumping")
@export var jump_force: float = 8.0
@export var gravity_multiplier: float = 2.5
@export var fall_multiplier: float = 3.0
@export var coyote_time: float = 0.12          ## Seconds after leaving a ledge where jump is still allowed
@export var jump_buffer_time: float = 0.1      ## Seconds before landing where jump input is remembered

# -- Combat --
@export_group("Combat")
@export var max_health: int = 100
@export var attack_damage: int = 15
@export var attack_cooldown: float = 0.5
@export var dodge_speed: float = 14.0
@export var dodge_duration: float = 0.3
@export var invincibility_duration: float = 0.4

# -- State --
var current_health: int
var is_attacking: bool = false
var is_dodging: bool = false
var is_invincible: bool = false
var can_attack: bool = true
var is_dead: bool = false
var last_direction: Vector3 = Vector3.FORWARD

# -- Weapons & Abilities --
var weapons: Array[WeaponBase] = []
var current_weapon_index: int = 0
var abilities: Array[AbilityBase] = []
var clout_inventory: CloutInventory

# -- Special Stats --
var crit_active: bool = false
var crit_multiplier: float = 1.0

# -- Hit flash --
var _hit_flash_timer: float = 0.0
var _original_materials: Array = []

# -- Animation rig paths (KayKit ships animations separately) --
@export_group("Animation Rigs")
@export var anim_rig_general: String = "res://assets/animations/character/Rig_Medium_General.glb"
@export var anim_rig_movement: String = "res://assets/animations/character/Rig_Medium_MovementBasic.glb"
@export var anim_rig_combat_melee: String = "res://assets/animations/character/Rig_Medium_CombatMelee.glb"
@export var anim_rig_combat_ranged: String = "res://assets/animations/character/Rig_Medium_CombatRanged.glb"
@export var anim_rig_dodge: String = "res://assets/animations/character/Rig_Medium_MovementAdvanced.glb"
@export var anim_rig_special: String = "res://assets/animations/character/Rig_Medium_Special.glb"

# -- Node references --
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else null
@onready var camera_pivot: Node3D = $CameraPivot
@onready var attack_area: Area3D = $Model/AttackArea if has_node("Model/AttackArea") else null
@onready var hurtbox: Area3D = $Hurtbox if has_node("Hurtbox") else null
@onready var weapon_holder: Node3D = $Model/WeaponHolder if has_node("Model/WeaponHolder") else null
@onready var sword_mesh: Node3D = $Model/WeaponHolder/SwordMesh if has_node("Model/WeaponHolder/SwordMesh") else null
@onready var bow_mesh: Node3D = $Model/WeaponHolder/BowMesh if has_node("Model/WeaponHolder/BowMesh") else null

# -- Signals --
signal health_changed(new_health: int, max_hp: int)
signal player_died
signal weapon_switched(weapon_name: String)

# -- Timers --
var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _invincibility_timer: float = 0.0

# Track whether weapon is controlling the animation
var _weapon_anim_playing: bool = false
var _weapon_anim_timer: float = 0.0

# -- Coyote time / jump buffer --
var _coyote_timer: float = 0.0       ## Time left to still jump after leaving ground
var _jump_buffer_timer: float = 0.0  ## Buffered jump input
var _was_on_floor: bool = true       ## Track floor state changes

# -- Knockback (player) --
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_decay: float = 10.0


func _ready() -> void:
	current_health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")

	# Setup AnimationPlayer on the character model INSTANCE (RangerModel),
	# NOT on Model. The rig animations have track paths like "Skeleton3D:hips"
	# that only resolve if the AnimationPlayer lives at the same level as the
	# rig's root — which is the imported .glb instance node.
	var char_model_instance: Node3D = model.get_child(0) as Node3D  # RangerModel
	if char_model_instance:
		animation_player = AnimationHelper.setup_animation_player(char_model_instance)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_general)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_movement)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_combat_melee)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_combat_ranged)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_dodge)
		AnimationHelper.load_animations_from_rig(animation_player, anim_rig_special)
		print("[Oley] Loaded animations: ", animation_player.get_animation_list())

	# Attach weapons to the right hand bone so they move with animations
	_attach_weapons_to_hand()

	# Connect hurtbox if it exists
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Initialize clout inventory
	clout_inventory = CloutInventory.new(3)
	clout_inventory.inventory_changed.connect(_on_inventory_changed)

	# Initialize weapons and abilities
	_setup_weapons()
	_setup_abilities()
	_update_weapon_visuals()

	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_apply_gravity(delta)
	_update_coyote_time(delta)
	_apply_player_knockback_decay(delta)

	if is_dodging:
		_process_dodge(delta)
	else:
		_process_movement(delta)
		_process_jump()
		_process_attack()
		_process_dodge_input()

	# Merge knockback into velocity
	velocity += _knockback_velocity

	move_and_slide()

	# Remove knockback contribution after move
	velocity -= _knockback_velocity

	_update_animation()

	# Kill plane — respawn if fallen off the map
	if global_position.y < -20.0:
		current_health = 0
		emit_signal("health_changed", current_health, max_health)
		_die()


func _process_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")

	if input_dir.length() > 0:
		# Use camera basis directly — basis.z * input.y gives correct movement
		var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
		var look_dir: Vector3 = cam_basis.z * input_dir.y + cam_basis.x * input_dir.x
		look_dir.y = 0
		look_dir = look_dir.normalized()
		last_direction = look_dir

		# Smooth acceleration toward target speed (not instant snap)
		velocity.x = move_toward(velocity.x, look_dir.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, look_dir.z * move_speed, acceleration * delta)

		# Rotate model toward movement direction.
		# RangerModel has a baked 180° Y flip so Model's -Z = visual forward.
		# atan2(-x, -z) gives the angle that makes -Z face look_dir.
		var target_rotation: float = atan2(-look_dir.x, -look_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Smooth deceleration to zero
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)


func _get_input_direction() -> Vector3:
	return last_direction


func get_aim_direction() -> Vector3:
	"""Returns the camera's forward direction projected onto the ground plane."""
	if camera_pivot and camera_pivot is CameraController:
		return (camera_pivot as CameraController).get_aim_direction()
	# Fallback: use last movement direction
	return last_direction


func face_direction(dir: Vector3) -> void:
	"""Immediately snap the model to face a world-space direction."""
	if dir.length() < 0.01:
		return
	var target_rotation: float = atan2(-dir.x, -dir.z)
	model.rotation.y = target_rotation


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_value: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		if velocity.y > 0:
			velocity.y -= gravity_value * gravity_multiplier * delta
		else:
			velocity.y -= gravity_value * fall_multiplier * delta


func _process_jump() -> void:
	# Buffer jump input — if pressed slightly before landing, jump fires on landing
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# Can jump if: on floor OR within coyote window
	var can_jump: bool = is_on_floor() or _coyote_timer > 0.0

	if can_jump and _jump_buffer_timer > 0.0:
		velocity.y = jump_force
		_coyote_timer = 0.0         # Consume coyote time
		_jump_buffer_timer = 0.0    # Consume buffer

	# Tick down buffer timer
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= get_physics_process_delta_time()


func _update_coyote_time(_delta: float) -> void:
	"""Track when the player leaves the floor to enable coyote time."""
	if is_on_floor():
		_coyote_timer = coyote_time
		_was_on_floor = true
	else:
		if _was_on_floor:
			# Just left the floor — start coyote countdown
			# Only grant coyote time if we didn't jump (falling off ledge)
			if velocity.y <= 0:
				_coyote_timer = coyote_time
			else:
				_coyote_timer = 0.0
			_was_on_floor = false
		_coyote_timer -= _delta


func _apply_player_knockback_decay(delta: float) -> void:
	"""Decay player knockback smoothly."""
	_knockback_velocity.x = move_toward(_knockback_velocity.x, 0.0, _knockback_decay * delta)
	_knockback_velocity.z = move_toward(_knockback_velocity.z, 0.0, _knockback_decay * delta)
	if is_on_floor():
		_knockback_velocity.y = 0.0
	else:
		_knockback_velocity.y = move_toward(_knockback_velocity.y, 0.0, _knockback_decay * 0.5 * delta)


func _process_attack() -> void:
	# Use current weapon
	if Input.is_action_just_pressed("attack"):
		if weapons.size() > 0:
			var current_weapon: WeaponBase = weapons[current_weapon_index]
			current_weapon.try_use(self)
			# Mark that weapon is controlling animation
			_weapon_anim_playing = true
			_weapon_anim_timer = 0.5  # Let weapon animation play for at least this long

	# Weapon switching
	if Input.is_action_just_pressed("weapon_1"):
		_switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_switch_weapon(1)

	# Abilities
	if Input.is_action_just_pressed("ability_1"):
		if abilities.size() > 0:
			abilities[0].try_activate(self)
	elif Input.is_action_just_pressed("ability_2"):
		if abilities.size() > 1:
			abilities[1].try_activate(self)


func _process_dodge_input() -> void:
	if Input.is_action_just_pressed("dodge") and is_on_floor() and not is_dodging:
		is_dodging = true
		is_invincible = true
		_dodge_timer = dodge_duration
		_invincibility_timer = invincibility_duration
		velocity.x = last_direction.x * dodge_speed
		velocity.z = last_direction.z * dodge_speed
		_weapon_anim_playing = false  # Dodge cancels weapon animation


func _process_dodge(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
	velocity.z = move_toward(velocity.z, 0.0, friction * 0.5 * delta)


func _update_timers(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta
		if _attack_timer <= 0:
			can_attack = true

	if _dodge_timer > 0:
		_dodge_timer -= delta
		if _dodge_timer <= 0:
			is_dodging = false

	if _invincibility_timer > 0:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0:
			is_invincible = false

	# Weapon animation lock timer
	if _weapon_anim_playing:
		_weapon_anim_timer -= delta
		if _weapon_anim_timer <= 0:
			_weapon_anim_playing = false

	# Hit flash timer
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0:
			_restore_materials()


func _update_animation() -> void:
	if not animation_player:
		return

	if is_dead:
		return

	# Don't override weapon animations while they're playing
	if _weapon_anim_playing:
		return

	var speed := Vector2(velocity.x, velocity.z).length()

	if is_dodging:
		_play_anim("Dodge_Forward")
	elif not is_on_floor():
		_play_anim("Jump_Full_Short")
	elif speed > 3.0:
		_play_anim("Running_A")
	elif speed > 0.5:
		_play_anim("Walking_A")
	else:
		# Idle pose depends on equipped weapon
		if current_weapon_index == 1:  # Bow
			if animation_player.has_animation("1H_Ranged_Idle"):
				_play_anim("1H_Ranged_Idle")
			else:
				_play_anim("Idle_A")
		else:  # Sword
			if animation_player.has_animation("1H_Melee_Attack_Slice_Horizontal"):
				_play_anim("Idle_A")
			else:
				_play_anim("Idle_A")


func _play_anim(anim_name: String) -> void:
	if animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)


func take_damage(amount: int, source_position: Vector3 = Vector3.ZERO) -> void:
	if is_invincible or is_dead:
		return

	print("[Oley] TAKING %d DAMAGE" % amount)

	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)

	# Brief invincibility after hit
	is_invincible = true
	_invincibility_timer = invincibility_duration

	# Hit flash effect — briefly tint the model red
	_apply_hit_flash()

	# Hit sparks VFX at the point of impact
	if source_position != Vector3.ZERO:
		var hit_vfx_pos: Vector3 = (global_position + source_position) * 0.5
		hit_vfx_pos.y += 0.5
		VFXHelper.spawn_hit_sparks(get_tree().root, hit_vfx_pos, Color(1.0, 0.3, 0.3))

	# Impulse-based knockback (separate vector, decayed smoothly)
	if source_position != Vector3.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		knockback_dir.y = 0
		_knockback_velocity = knockback_dir * 6.0
		_knockback_velocity.y = 1.5  # Small upward pop
		# Screen shake on taking damage
		CombatFeel.screen_shake(get_tree(), 0.15, 0.2)

	# Play hurt animation (brief, doesn't lock out movement)
	if animation_player and animation_player.has_animation("Hit_A"):
		animation_player.play("Hit_A")
		_weapon_anim_playing = true
		_weapon_anim_timer = 0.3

	if current_health <= 0:
		_die()


func _apply_hit_flash() -> void:
	_hit_flash_timer = 0.15
	# Find all MeshInstance3D children in model and tint them
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(model, meshes)
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.get_surface_override_material_count() > 0:
			var mat: Material = mesh_node.get_surface_override_material(0)
			if mat and mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat as StandardMaterial3D
				std_mat.albedo_color = Color(1, 0.3, 0.3, 1)


func _restore_materials() -> void:
	# Reset tint (simple approach: just set back to white)
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(model, meshes)
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.get_surface_override_material_count() > 0:
			var mat: Material = mesh_node.get_surface_override_material(0)
			if mat and mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat as StandardMaterial3D
				std_mat.albedo_color = Color(1, 1, 1, 1)


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_meshes(child, result)


func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	emit_signal("health_changed", current_health, max_health)
	# Green healing particles
	VFXHelper.spawn_heal_effect(get_tree().root, global_position)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	emit_signal("player_died")

	if animation_player and animation_player.has_animation("Death_A"):
		animation_player.play("Death_A")


func _on_hurtbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy_attack"):
		var dmg: int = area.get_meta("damage", 10) as int
		take_damage(dmg, area.global_position)


func _attach_weapons_to_hand() -> void:
	"""Find the Skeleton3D in the Ranger model and reparent WeaponHolder
	   onto the right hand bone using a BoneAttachment3D."""
	if not weapon_holder or not model:
		print("[Oley] No weapon_holder or model — skipping hand attachment")
		return

	var char_model_instance: Node3D = model.get_child(0) as Node3D  # RangerModel
	if not char_model_instance:
		print("[Oley] No character model instance found")
		return

	# Find the Skeleton3D node inside the imported .glb
	var skeleton: Skeleton3D = _find_skeleton(char_model_instance)
	if not skeleton:
		print("[Oley] No Skeleton3D found in model — weapons stay at static offset")
		return

	# Print all bone names to find the right hand bone
	var bone_count: int = skeleton.get_bone_count()
	var hand_bone_idx: int = -1
	var hand_bone_name: String = ""

	# KayKit uses these common bone names — try them in priority order
	var hand_bone_candidates: Array[String] = [
		"hand_R", "Hand_R", "hand.R", "HandR",
		"mixamorig:RightHand", "RightHand", "Right_Hand",
		"hand_r", "handR", "Wrist_R", "wrist_R",
	]

	for candidate: String in hand_bone_candidates:
		var idx: int = skeleton.find_bone(candidate)
		if idx >= 0:
			hand_bone_idx = idx
			hand_bone_name = candidate
			break

	# If none of the named candidates matched, search for any bone with "hand" and "r"
	if hand_bone_idx < 0:
		for i: int in range(bone_count):
			var bname: String = skeleton.get_bone_name(i).to_lower()
			if "hand" in bname and ("right" in bname or bname.ends_with("_r") or bname.ends_with(".r")):
				hand_bone_idx = i
				hand_bone_name = skeleton.get_bone_name(i)
				break

	# Last resort: just print all bones so we can debug
	if hand_bone_idx < 0:
		var bone_names: Array[String] = []
		for i: int in range(bone_count):
			bone_names.append(skeleton.get_bone_name(i))
		print("[Oley] Could not find hand bone. Available bones: ", bone_names)
		print("[Oley] Weapons remain at static offset")
		return

	print("[Oley] Attaching weapons to bone: '%s' (index %d)" % [hand_bone_name, hand_bone_idx])

	# Create a BoneAttachment3D to follow the hand bone
	var bone_attach: BoneAttachment3D = BoneAttachment3D.new()
	bone_attach.name = "HandAttachment"
	bone_attach.bone_name = hand_bone_name
	bone_attach.bone_idx = hand_bone_idx
	skeleton.add_child(bone_attach)

	# Reparent the weapon holder from Model to the bone attachment
	# First, save current children (sword/bow meshes)
	weapon_holder.get_parent().remove_child(weapon_holder)
	bone_attach.add_child(weapon_holder)

	# Reset weapon holder transform — the bone attachment handles positioning now
	# We just need a small offset to place the weapon in the palm
	weapon_holder.transform = Transform3D.IDENTITY
	weapon_holder.position = Vector3(0, 0, 0)

	# Update the mesh references since they got reparented
	sword_mesh = weapon_holder.get_node("SwordMesh") if weapon_holder.has_node("SwordMesh") else null
	bow_mesh = weapon_holder.get_node("BowMesh") if weapon_holder.has_node("BowMesh") else null

	# Adjust weapon mesh transforms for hand-held look
	# These may need tweaking based on the exact bone orientation
	if sword_mesh:
		# Sword: grip along the hand, blade extending outward
		sword_mesh.transform = Transform3D(
			Vector3(0, 0, 0.5),
			Vector3(-0.5, 0, 0),
			Vector3(0, 0.5, 0),
			Vector3(0, 0.05, 0)
		)

	if bow_mesh:
		# Bow: held vertically in the hand
		bow_mesh.transform = Transform3D(
			Vector3(0.5, 0, 0),
			Vector3(0, 0.5, 0),
			Vector3(0, 0, 0.5),
			Vector3(0, 0, 0)
		)

	print("[Oley] Weapons successfully attached to hand bone!")


func _find_skeleton(node: Node) -> Skeleton3D:
	"""Recursively find the first Skeleton3D node in the tree."""
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result:
			return result
	return null


func _setup_weapons() -> void:
	"""Initialize the player's weapons — Sword (slot 1) and Bow (slot 2)."""
	var sword: Sword = Sword.new()
	add_child(sword)
	weapons.append(sword)

	var bow: Bow = Bow.new()
	add_child(bow)
	weapons.append(bow)

	current_weapon_index = 0
	print("[PlayerController] Weapons initialized: Sword, Bow")


func _setup_abilities() -> void:
	"""Initialize the player's abilities."""
	var mewing: MewingAbility = MewingAbility.new()
	add_child(mewing)
	abilities.append(mewing)

	var hypercritical: HypercriticalAnalysisAbility = HypercriticalAnalysisAbility.new()
	add_child(hypercritical)
	abilities.append(hypercritical)

	print("[PlayerController] Abilities initialized: Mewing, Hypercritical Analysis")


func _switch_weapon(index: int) -> void:
	"""Switch to the weapon at the given index."""
	if index >= 0 and index < weapons.size() and index != current_weapon_index:
		current_weapon_index = index
		_update_weapon_visuals()
		_weapon_anim_playing = false  # Allow idle anim to update
		var weapon: WeaponBase = weapons[current_weapon_index]
		weapon_switched.emit(weapon.weapon_name)
		print("[PlayerController] Switched to weapon: %s" % weapon.weapon_name)


func _update_weapon_visuals() -> void:
	"""Show/hide weapon meshes based on active weapon."""
	if sword_mesh:
		sword_mesh.visible = (current_weapon_index == 0)
	if bow_mesh:
		bow_mesh.visible = (current_weapon_index == 1)


func _on_inventory_changed() -> void:
	"""Called when clout inventory changes. Apply stat modifiers."""
	var speed_mult: float = clout_inventory.get_stat_modifier("speed")
	var health_mult: float = clout_inventory.get_stat_modifier("max_health")
	var damage_mult: float = clout_inventory.get_stat_modifier("damage")
	print("[PlayerController] Clout modifiers - Speed: %.2fx, Health: %.2fx, Damage: %.2fx" % [speed_mult, health_mult, damage_mult])


func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
