extends Node3D

## Dade's House — Level 1 of Oley's World.
## A dark, decrepit house. Oley fights through rooms of skeleton minions
## before descending into the basement to face Big Mark.
##
## Layout (linear, along -Z axis):
##   Foyer (spawn) → Hallway → Living Room (enemies) → Hallway → Boss Arena
##
## Room bounds (floor centers at Y=-0.25):
##   Foyer:       14×12 at (0, 0)    → X: -7..7,   Z: -6..6
##   Hallway1:     6×8  at (0, -10)  → X: -3..3,   Z: -14..-6
##   Living Room: 20×18 at (0, -23)  → X: -10..10,  Z: -32..-14
##   Hallway2:     6×10 at (0, -37)  → X: -3..3,   Z: -42..-32
##   Boss Arena:  24×24 at (0, -54)  → X: -12..12,  Z: -66..-42

@export var skeleton_minion_scene: PackedScene = preload("res://scenes/enemies/skeleton_minion.tscn")
@export var big_mark_scene: PackedScene = preload("res://scenes/enemies/big_mark.tscn")
@export var purple_coin_scene: PackedScene = preload("res://scenes/pickups/purple_coin.tscn")

# -- State --
var _enemies_alive: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _boss_fight_active: bool = false
var _clout_db: CloutDatabase = CloutDatabase.new()
var _boss_ref: BigMark = null

# -- Enemy spawn data --
# Living Room minions (room center is at Z=-23, 20x18 floor)
var _living_room_spawns: Array = [
	{"pos": Vector3(-5, 0, -18), "patrol": [Vector3(3, 0, 0), Vector3(-3, 0, 0)]},
	{"pos": Vector3(5, 0, -18), "patrol": []},
	{"pos": Vector3(-6, 0, -26), "patrol": [Vector3(2, 0, -2), Vector3(-2, 0, 2)]},
	{"pos": Vector3(6, 0, -26), "patrol": []},
	{"pos": Vector3(0, 0, -22), "patrol": [Vector3(-4, 0, 0), Vector3(4, 0, 0)]},
	{"pos": Vector3(-3, 0, -30), "patrol": []},
	{"pos": Vector3(3, 0, -30), "patrol": []},
]

# Hallway 2 ambush minions (corridor at Z=-37, 6x10 floor)
var _hallway2_spawns: Array = [
	{"pos": Vector3(-1.5, 0, -35), "patrol": []},
	{"pos": Vector3(1.5, 0, -39), "patrol": []},
]

# Coin positions
var _coin_positions: Array[Vector3] = [
	Vector3(4, 0.5, 2),     # Foyer corner
	Vector3(-4, 0.5, 2),    # Foyer corner
	Vector3(0, 0.5, -10),   # Hallway 1
	Vector3(-7, 0.5, -20),  # Living Room edges
	Vector3(7, 0.5, -20),
	Vector3(0, 0.5, -28),   # Living Room center
	Vector3(-2, 0.5, -37),  # Hallway 2
	Vector3(2, 0.5, -37),
]

# ==========================================================================
# WALL DATA — {pos: center, size: Vector3(width, height, depth)}
# All walls are 4m tall. SeeThroughWall script fades them when camera is behind.
# ==========================================================================
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 0.3
var _wall_color: Color = Color(0.3, 0.24, 0.18, 1)  # Dark stone/wood

var _wall_data: Array = [
	# -- Foyer (14×12 at Z=0) --
	{"pos": Vector3(-7, 2, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},  # Left
	{"pos": Vector3(7, 2, 0),     "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},  # Right
	{"pos": Vector3(0, 2, 6),     "size": Vector3(14, WALL_HEIGHT, WALL_THICKNESS)},  # Back (spawn wall)
	{"pos": Vector3(-5, 2, -6),   "size": Vector3(4, WALL_HEIGHT, WALL_THICKNESS)},   # Front-left
	{"pos": Vector3(5, 2, -6),    "size": Vector3(4, WALL_HEIGHT, WALL_THICKNESS)},   # Front-right

	# -- Hallway 1 (6×8 at Z=-10) --
	{"pos": Vector3(-3, 2, -10),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 8)},   # Left
	{"pos": Vector3(3, 2, -10),   "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 8)},   # Right

	# -- Living Room (20×18 at Z=-23) --
	{"pos": Vector3(-10, 2, -23), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 18)},  # Left
	{"pos": Vector3(10, 2, -23),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 18)},  # Right
	{"pos": Vector3(-6.5, 2, -14), "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},  # Front-left
	{"pos": Vector3(6.5, 2, -14),  "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},  # Front-right
	{"pos": Vector3(-6.5, 2, -32), "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},  # Back-left
	{"pos": Vector3(6.5, 2, -32),  "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},  # Back-right

	# -- Hallway 2 (6×10 at Z=-37) --
	{"pos": Vector3(-3, 2, -37),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},  # Left
	{"pos": Vector3(3, 2, -37),   "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},  # Right

	# -- Boss Arena (24×24 at Z=-54) --
	{"pos": Vector3(-12, 2, -54), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 24)},  # Left
	{"pos": Vector3(12, 2, -54),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 24)},  # Right
	{"pos": Vector3(-7.5, 2, -42), "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},  # Front-left
	{"pos": Vector3(7.5, 2, -42),  "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},  # Front-right
	{"pos": Vector3(0, 2, -66),   "size": Vector3(24, WALL_HEIGHT, WALL_THICKNESS)},  # Back wall
]

# ==========================================================================
# PROP DATA — barrels, crates, tables, pillars, candles
# ==========================================================================
var _barrel_positions: Array[Vector3] = [
	# Foyer
	Vector3(5.5, 0.4, 4),
	Vector3(6, 0.4, 3.5),
	# Living Room
	Vector3(-8, 0.4, -16),
	Vector3(-8.5, 0.4, -17),
	Vector3(8, 0.4, -29),
	Vector3(7.5, 0.4, -30),
]

var _crate_positions: Array[Vector3] = [
	# Foyer
	Vector3(-5.5, 0.35, 4),
	# Living Room
	Vector3(8, 0.35, -16),
	Vector3(7.5, 0.35, -15.5),
	Vector3(-7.5, 0.35, -29),
	# Boss Arena
	Vector3(-10, 0.35, -48),
	Vector3(10, 0.35, -48),
]

var _pillar_positions: Array[Vector3] = [
	# Boss Arena — 4 pillars framing the arena
	Vector3(-8, 2, -48),
	Vector3(8, 2, -48),
	Vector3(-8, 2, -60),
	Vector3(8, 2, -60),
]

# Tables: {pos, rot_y} — center of table top
var _table_data: Array = [
	{"pos": Vector3(0, 0.45, 2), "rot": 0.0},     # Foyer center table
	{"pos": Vector3(-4, 0.45, -22), "rot": 15.0},  # Living Room — knocked over angle
]

# Candles on tables / wall sconces
var _candle_positions: Array[Vector3] = [
	Vector3(0, 0.95, 2),       # On foyer table
	Vector3(-4, 0.95, -22),    # On living room table
	Vector3(-9.5, 2.5, -20),   # Living room wall sconce left
	Vector3(9.5, 2.5, -26),    # Living room wall sconce right
]

# -- Node References --
@onready var enemy_container: Node3D = $Enemies
@onready var boss_container: Node3D = $BossContainer
@onready var pickup_container: Node3D = $Pickups
@onready var player: PlayerController = $Oley
@onready var boss_trigger: Area3D = $BossTrigger
@onready var hud: CanvasLayer = $HUD
@onready var walls_container: Node3D = $Walls
@onready var props_container: Node3D = $Props

# Preloaded scripts
var _see_through_script: GDScript = preload("res://scripts/environment/see_through_wall.gd")


func _ready() -> void:
	# Build the environment
	_spawn_walls()
	_spawn_props()

	# Spawn enemies and coins
	_spawn_enemies(_living_room_spawns)
	_spawn_enemies(_hallway2_spawns)
	_spawn_coins()

	# Connect player signals
	if player:
		player.player_died.connect(_on_player_died)

	# Connect boss trigger
	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger_entered)

	# Update HUD stage name
	if hud and hud.has_node("Root/TopBar/TopRight/StageLabel"):
		var stage_label: Label = hud.get_node("Root/TopBar/TopRight/StageLabel") as Label
		if stage_label:
			stage_label.text = "Dade's House"

	print("[DadesHouse] Level loaded. %d enemies, %d walls, props placed." % [_enemies_alive, _wall_data.size()])


# ==========================================================================
# WALLS
# ==========================================================================
func _spawn_walls() -> void:
	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = _wall_color

	for i: int in range(_wall_data.size()):
		var wd: Dictionary = _wall_data[i]
		var wall_size: Vector3 = wd["size"] as Vector3
		var wall_pos: Vector3 = wd["pos"] as Vector3

		# StaticBody3D for collision
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Wall_%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		walls_container.add_child(body)
		body.global_position = wall_pos

		# Collision shape
		var col_shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = wall_size
		col_shape.shape = box_shape
		body.add_child(col_shape)

		# Mesh with see-through script
		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = wall_size
		mesh_inst.mesh = box_mesh
		mesh_inst.set_surface_override_material(0, wall_mat.duplicate())
		mesh_inst.set_script(_see_through_script)
		body.add_child(mesh_inst)


# ==========================================================================
# PROPS (barrels, crates, pillars, tables, candles)
# ==========================================================================
func _spawn_props() -> void:
	_spawn_barrels()
	_spawn_crates()
	_spawn_pillars()
	_spawn_tables()
	_spawn_candles()


func _spawn_barrels() -> void:
	# Physics-enabled breakable barrels — can be smashed by sword, arrows, enemies
	for pos: Vector3 in _barrel_positions:
		var barrel: BreakableProp = BreakableProp.create_barrel(pos)
		props_container.add_child(barrel)


func _spawn_crates() -> void:
	# Physics-enabled breakable crates
	for pos: Vector3 in _crate_positions:
		var crate: BreakableProp = BreakableProp.create_crate(pos)
		props_container.add_child(crate)


func _spawn_pillars() -> void:
	var pillar_mat: StandardMaterial3D = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.25, 0.22, 0.2, 1)

	for pos: Vector3 in _pillar_positions:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		props_container.add_child(body)
		body.global_position = pos

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 4.0
		col.shape = shape
		body.add_child(col)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.55
		cyl.height = 4.0
		mesh_inst.mesh = cyl
		mesh_inst.set_surface_override_material(0, pillar_mat)
		body.add_child(mesh_inst)

		# Pillar base
		var base_mesh: MeshInstance3D = MeshInstance3D.new()
		var base: BoxMesh = BoxMesh.new()
		base.size = Vector3(1.2, 0.2, 1.2)
		base_mesh.mesh = base
		base_mesh.position.y = -1.9
		base_mesh.set_surface_override_material(0, pillar_mat)
		body.add_child(base_mesh)

		# Pillar cap
		var cap_mesh: MeshInstance3D = MeshInstance3D.new()
		var cap: BoxMesh = BoxMesh.new()
		cap.size = Vector3(1.0, 0.15, 1.0)
		cap_mesh.mesh = cap
		cap_mesh.position.y = 1.9
		cap_mesh.set_surface_override_material(0, pillar_mat)
		body.add_child(cap_mesh)


func _spawn_tables() -> void:
	var table_mat: StandardMaterial3D = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.3, 0.2, 0.12, 1)

	for td: Dictionary in _table_data:
		var pos: Vector3 = td["pos"] as Vector3
		var rot_y: float = td["rot"] as float

		var table_root: Node3D = Node3D.new()
		props_container.add_child(table_root)
		table_root.global_position = pos
		table_root.rotation_degrees.y = rot_y

		# Table top
		var top_body: StaticBody3D = StaticBody3D.new()
		top_body.collision_layer = 1
		top_body.collision_mask = 0
		table_root.add_child(top_body)

		var top_col: CollisionShape3D = CollisionShape3D.new()
		var top_shape: BoxShape3D = BoxShape3D.new()
		top_shape.size = Vector3(1.4, 0.08, 0.8)
		top_col.shape = top_shape
		top_body.add_child(top_col)

		var top_mesh: MeshInstance3D = MeshInstance3D.new()
		var top_box: BoxMesh = BoxMesh.new()
		top_box.size = Vector3(1.4, 0.08, 0.8)
		top_mesh.mesh = top_box
		top_mesh.set_surface_override_material(0, table_mat)
		top_body.add_child(top_mesh)

		# 4 legs
		var leg_mat: StandardMaterial3D = StandardMaterial3D.new()
		leg_mat.albedo_color = Color(0.25, 0.16, 0.08, 1)

		var leg_offsets: Array[Vector3] = [
			Vector3(-0.6, -0.25, -0.3),
			Vector3(0.6, -0.25, -0.3),
			Vector3(-0.6, -0.25, 0.3),
			Vector3(0.6, -0.25, 0.3),
		]
		for offset: Vector3 in leg_offsets:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var leg_cyl: CylinderMesh = CylinderMesh.new()
			leg_cyl.top_radius = 0.04
			leg_cyl.bottom_radius = 0.04
			leg_cyl.height = 0.45
			leg.mesh = leg_cyl
			leg.position = offset
			leg.set_surface_override_material(0, leg_mat)
			table_root.add_child(leg)


func _spawn_candles() -> void:
	var candle_mat: StandardMaterial3D = StandardMaterial3D.new()
	candle_mat.albedo_color = Color(0.9, 0.85, 0.7, 1)

	for pos: Vector3 in _candle_positions:
		var candle_root: Node3D = Node3D.new()
		props_container.add_child(candle_root)
		candle_root.global_position = pos

		# Candle body
		var candle_mesh: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = 0.2
		candle_mesh.mesh = cyl
		candle_mesh.set_surface_override_material(0, candle_mat)
		candle_root.add_child(candle_mesh)

		# Flame glow (small OmniLight)
		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = 0.15
		light.light_color = Color(1.0, 0.7, 0.3, 1)
		light.light_energy = 1.5
		light.omni_range = 4.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		candle_root.add_child(light)

		# Tiny flame mesh (sphere)
		var flame: MeshInstance3D = MeshInstance3D.new()
		var flame_mesh: SphereMesh = SphereMesh.new()
		flame_mesh.radius = 0.03
		flame_mesh.height = 0.06
		flame.mesh = flame_mesh
		flame.position.y = 0.12
		var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.6, 0.1, 1)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.6, 0.1, 1)
		flame_mat.emission_energy_multiplier = 3.0
		flame.set_surface_override_material(0, flame_mat)
		candle_root.add_child(flame)


# ==========================================================================
# ENEMIES
# ==========================================================================
func _spawn_enemies(spawn_list: Array) -> void:
	for spawn_data: Dictionary in spawn_list:
		var minion: EnemyBase = skeleton_minion_scene.instantiate() as EnemyBase
		minion.enemy_died.connect(_on_enemy_died)
		enemy_container.add_child(minion)
		minion.global_position = spawn_data["pos"] as Vector3

		if spawn_data.has("patrol"):
			var patrol_array: Array = spawn_data["patrol"]
			if not patrol_array.is_empty():
				var typed_patrol: Array[Vector3] = []
				for pt: Vector3 in patrol_array:
					typed_patrol.append(pt)
				minion.patrol_points = typed_patrol

		_enemies_alive += 1


func _spawn_coins() -> void:
	for coin_pos: Vector3 in _coin_positions:
		var coin: PurpleCoin = purple_coin_scene.instantiate() as PurpleCoin
		pickup_container.add_child(coin)
		coin.global_position = coin_pos

	print("[DadesHouse] Spawned %d coins" % _coin_positions.size())


# -- Boss Trigger --
func _on_boss_trigger_entered(body: Node3D) -> void:
	if _boss_spawned or _boss_defeated:
		return
	if body is PlayerController:
		_start_boss_fight()


func _start_boss_fight() -> void:
	_boss_spawned = true
	_boss_fight_active = true
	print("[DadesHouse] BOSS FIGHT: Big Mark!")

	# Boss entrance VFX — fiery orange for Big Mark
	VFXHelper.spawn_boss_entrance(get_tree().root, Vector3(0, 0, -54), Color(1.0, 0.4, 0.2))

	# Show boss entrance message
	if hud and hud.has_method("show_message"):
		hud.show_message("Big Mark appears!", 2.0)

	# Show boss health bar
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar("Big Mark")

	# Spawn Big Mark in the center of the boss arena
	var boss: BigMark = big_mark_scene.instantiate() as BigMark
	boss.spawn_minion_scene = skeleton_minion_scene
	boss_container.add_child(boss)
	boss.global_position = Vector3(0, 0, -54)

	_boss_ref = boss

	# Connect boss signals
	boss.boss_defeated.connect(_on_boss_defeated)
	boss.boss_phase_changed.connect(_on_boss_phase_changed)
	boss.boss_health_changed.connect(_on_boss_health_changed)
	boss.enemy_died.connect(_on_enemy_died)

	# Disable the trigger so it doesn't fire again
	boss_trigger.set_collision_mask_value(2, false)
	boss_trigger.monitoring = false


# -- Boss Callbacks --
func _on_boss_defeated() -> void:
	_boss_defeated = true
	_boss_fight_active = false
	print("[DadesHouse] Big Mark DEFEATED!")

	if hud and hud.has_method("show_message"):
		hud.show_message("Big Mark defeated!", 3.0)

	# Drop guaranteed GRAIL clout item
	if player and player.clout_inventory:
		var grail_item: CloutItem = _clout_db.get_random_item(CloutItem.Rarity.GRAIL)
		if grail_item:
			player.clout_inventory.add_item(grail_item)
			print("[DadesHouse] Dropped Grail item: %s" % grail_item.item_name)

	# Level complete after a short delay
	await get_tree().create_timer(3.0).timeout
	GameManager.level_completed()


func _on_boss_phase_changed(phase: int) -> void:
	match phase:
		2:
			if hud and hud.has_method("show_message"):
				hud.show_message("Big Mark is getting angry...", 2.0)
		3:
			if hud and hud.has_method("show_message"):
				hud.show_message("Big Mark ENRAGES!", 2.0)


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	# Update boss health bar on HUD
	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(current_hp, max_hp)


# -- Enemy Callbacks --
func _on_enemy_died(enemy: EnemyBase) -> void:
	_enemies_alive -= 1
	print("[DadesHouse] Enemy defeated! %d remaining" % _enemies_alive)

	# Chance to drop clout items from regular enemies
	if not (enemy is BigMark):
		if randf() < 0.25:
			_spawn_clout_drop(enemy.global_position)


func _spawn_clout_drop(position: Vector3) -> void:
	var rarity_roll: float = randf()
	var item_rarity: CloutItem.Rarity

	if rarity_roll < 0.55:
		item_rarity = CloutItem.Rarity.MID
	elif rarity_roll < 0.9:
		item_rarity = CloutItem.Rarity.DRIP
	else:
		item_rarity = CloutItem.Rarity.GRAIL

	var item: CloutItem = _clout_db.get_random_item(item_rarity)
	if item and player and player.clout_inventory:
		if player.clout_inventory.add_item(item):
			print("[DadesHouse] Dropped clout: %s" % item.item_name)


func _on_player_died() -> void:
	print("[DadesHouse] Oley has fallen in Dade's House...")
	GameManager.player_died()
	GameManager.purple_coins = 0
