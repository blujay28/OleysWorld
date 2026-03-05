extends Node3D

## French Quarter — Level 2 of Oley's World.
## A haunted New Orleans street. Skeleton Warriors and Rogues lurk in alleys
## and courtyards. Baron Samedi awaits in the cemetery at the end.
##
## Layout (linear along -Z axis):
##   Courtyard (spawn) → Alley 1 → Market Square (enemies) → Alley 2 (ambush) →
##   Graveyard Entrance → Cemetery Boss Arena
##
## Room bounds (floor centers at Y=-0.25):
##   Courtyard:      16×14 at (0, 0)     → X: -8..8,   Z: -7..7
##   Alley1:          5×10 at (0, -12)   → X: -2.5..2.5, Z: -17..-7
##   Market Square:  22×20 at (0, -27)   → X: -11..11,  Z: -37..-17
##   Alley2:          5×12 at (0, -43)   → X: -2.5..2.5, Z: -49..-37
##   Graveyard:      18×10 at (0, -54)   → X: -9..9,   Z: -59..-49
##   Boss Arena:     26×26 at (0, -72)   → X: -13..13,  Z: -85..-59

@export var skeleton_warrior_scene: PackedScene = preload("res://scenes/enemies/skeleton_warrior.tscn")
@export var skeleton_rogue_scene: PackedScene = preload("res://scenes/enemies/skeleton_rogue.tscn")
@export var skeleton_minion_scene: PackedScene = preload("res://scenes/enemies/skeleton_minion.tscn")
@export var baron_samedi_scene: PackedScene = preload("res://scenes/enemies/baron_samedi.tscn")
@export var purple_coin_scene: PackedScene = preload("res://scenes/pickups/purple_coin.tscn")

# -- State --
var _enemies_alive: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _boss_fight_active: bool = false
var _clout_db: CloutDatabase = CloutDatabase.new()
var _boss_ref: BaronSamedi = null

# -- Enemy spawn data --
# Market Square — mixed warriors and rogues
var _market_spawns: Array = [
	{"pos": Vector3(-6, 0, -21), "patrol": [Vector3(4, 0, 0), Vector3(-4, 0, 0)], "type": "warrior"},
	{"pos": Vector3(6, 0, -21), "patrol": [], "type": "warrior"},
	{"pos": Vector3(-8, 0, -28), "patrol": [Vector3(2, 0, -2), Vector3(-2, 0, 2)], "type": "rogue"},
	{"pos": Vector3(8, 0, -28), "patrol": [], "type": "rogue"},
	{"pos": Vector3(0, 0, -25), "patrol": [Vector3(-5, 0, 0), Vector3(5, 0, 0)], "type": "warrior"},
	{"pos": Vector3(-4, 0, -33), "patrol": [], "type": "rogue"},
	{"pos": Vector3(4, 0, -33), "patrol": [], "type": "rogue"},
	{"pos": Vector3(0, 0, -35), "patrol": [Vector3(3, 0, 0), Vector3(-3, 0, 0)], "type": "warrior"},
]

# Alley 2 ambush — rogues that dash from shadows
var _alley2_spawns: Array = [
	{"pos": Vector3(-1.5, 0, -41), "patrol": [], "type": "rogue"},
	{"pos": Vector3(1.5, 0, -45), "patrol": [], "type": "rogue"},
	{"pos": Vector3(0, 0, -47), "patrol": [], "type": "warrior"},
]

# Graveyard entrance — warriors guarding
var _graveyard_spawns: Array = [
	{"pos": Vector3(-5, 0, -52), "patrol": [Vector3(3, 0, 0), Vector3(-3, 0, 0)], "type": "warrior"},
	{"pos": Vector3(5, 0, -52), "patrol": [], "type": "warrior"},
	{"pos": Vector3(0, 0, -56), "patrol": [], "type": "rogue"},
]

# Coin positions
var _coin_positions: Array[Vector3] = [
	Vector3(5, 0.5, 4),       # Courtyard
	Vector3(-5, 0.5, 4),      # Courtyard
	Vector3(0, 0.5, -12),     # Alley 1
	Vector3(-8, 0.5, -22),    # Market Square
	Vector3(8, 0.5, -22),     # Market Square
	Vector3(0, 0.5, -30),     # Market Square center
	Vector3(-1.5, 0.5, -43),  # Alley 2
	Vector3(1.5, 0.5, -43),   # Alley 2
	Vector3(-6, 0.5, -54),    # Graveyard
	Vector3(6, 0.5, -54),     # Graveyard
]

# ==========================================================================
# WALL DATA
# ==========================================================================
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 0.3
var _wall_color: Color = Color(0.35, 0.28, 0.2, 1)  # Warm stone/stucco

var _wall_data: Array = [
	# -- Courtyard (16×14 at Z=0) --
	{"pos": Vector3(-8, 2, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 14)},
	{"pos": Vector3(8, 2, 0),     "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 14)},
	{"pos": Vector3(0, 2, 7),     "size": Vector3(16, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-5.75, 2, -7), "size": Vector3(4.5, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(5.75, 2, -7),  "size": Vector3(4.5, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Alley 1 (5×10 at Z=-12) --
	{"pos": Vector3(-2.5, 2, -12), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},
	{"pos": Vector3(2.5, 2, -12),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},

	# -- Market Square (22×20 at Z=-27) --
	{"pos": Vector3(-11, 2, -27), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 20)},
	{"pos": Vector3(11, 2, -27),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 20)},
	{"pos": Vector3(-7, 2, -17),  "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(7, 2, -17),   "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-7, 2, -37),  "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(7, 2, -37),   "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Alley 2 (5×12 at Z=-43) --
	{"pos": Vector3(-2.5, 2, -43), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},
	{"pos": Vector3(2.5, 2, -43),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},

	# -- Graveyard Entrance (18×10 at Z=-54) --
	{"pos": Vector3(-9, 2, -54),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},
	{"pos": Vector3(9, 2, -54),   "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},
	{"pos": Vector3(-5.75, 2, -49), "size": Vector3(6.5, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(5.75, 2, -49),  "size": Vector3(6.5, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-7.5, 2, -59), "size": Vector3(3, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(7.5, 2, -59),  "size": Vector3(3, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Boss Arena (26×26 at Z=-72) --
	{"pos": Vector3(-13, 2, -72), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 26)},
	{"pos": Vector3(13, 2, -72),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 26)},
	{"pos": Vector3(-8, 2, -59),  "size": Vector3(10, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(8, 2, -59),   "size": Vector3(10, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(0, 2, -85),   "size": Vector3(26, WALL_HEIGHT, WALL_THICKNESS)},
]

# ==========================================================================
# PROP DATA — French Quarter themed: lamp posts, market stalls, graves
# ==========================================================================
var _lamp_positions: Array[Vector3] = [
	Vector3(6, 0, 3),         # Courtyard
	Vector3(-6, 0, 3),        # Courtyard
	Vector3(-1.5, 0, -10),    # Alley 1
	Vector3(1.5, 0, -14),     # Alley 1
	Vector3(-9, 0, -22),      # Market Square
	Vector3(9, 0, -22),       # Market Square
	Vector3(-9, 0, -32),      # Market Square
	Vector3(9, 0, -32),       # Market Square
]

var _stall_data: Array = [
	{"pos": Vector3(-7, 0, -20), "rot": 0.0},
	{"pos": Vector3(7, 0, -20), "rot": 180.0},
	{"pos": Vector3(-7, 0, -30), "rot": 0.0},
	{"pos": Vector3(7, 0, -30), "rot": 180.0},
]

var _barrel_positions: Array[Vector3] = [
	Vector3(6.5, 0.4, 5),
	Vector3(-6.5, 0.4, 5),
	Vector3(-9.5, 0.4, -19),
	Vector3(9.5, 0.4, -19),
	Vector3(-9, 0.4, -34),
	Vector3(9, 0.4, -34),
]

var _crate_positions: Array[Vector3] = [
	Vector3(-6, 0.35, -5),
	Vector3(6, 0.35, -5),
	Vector3(-9.5, 0.35, -25),
	Vector3(9.5, 0.35, -25),
]

# Graves in the graveyard and boss arena
var _grave_positions: Array[Vector3] = [
	Vector3(-5, 0, -52), Vector3(-3, 0, -53), Vector3(-1, 0, -51),
	Vector3(1, 0, -53), Vector3(3, 0, -52), Vector3(5, 0, -51),
	# Boss arena graves
	Vector3(-10, 0, -65), Vector3(-7, 0, -66), Vector3(-4, 0, -64),
	Vector3(4, 0, -65), Vector3(7, 0, -64), Vector3(10, 0, -66),
	Vector3(-8, 0, -78), Vector3(-5, 0, -79), Vector3(5, 0, -78),
	Vector3(8, 0, -80),
]

var _pillar_positions: Array[Vector3] = [
	# Boss Arena — ritual pillars
	Vector3(-9, 2, -65),
	Vector3(9, 2, -65),
	Vector3(-9, 2, -79),
	Vector3(9, 2, -79),
]

var _candle_positions: Array[Vector3] = [
	Vector3(-9, 3.5, -65),  # On boss pillars
	Vector3(9, 3.5, -65),
	Vector3(-9, 3.5, -79),
	Vector3(9, 3.5, -79),
	# Wall sconces
	Vector3(-10.5, 2.5, -24),
	Vector3(10.5, 2.5, -24),
	Vector3(-10.5, 2.5, -30),
	Vector3(10.5, 2.5, -30),
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

var _see_through_script: GDScript = preload("res://scripts/environment/see_through_wall.gd")


func _ready() -> void:
	_spawn_walls()
	_spawn_props()
	_spawn_enemies(_market_spawns)
	_spawn_enemies(_alley2_spawns)
	_spawn_enemies(_graveyard_spawns)
	_spawn_coins()

	if player:
		player.player_died.connect(_on_player_died)

	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger_entered)

	if hud and hud.has_node("Root/TopBar/TopRight/StageLabel"):
		var stage_label: Label = hud.get_node("Root/TopBar/TopRight/StageLabel") as Label
		if stage_label:
			stage_label.text = "French Quarter"

	print("[FrenchQuarter] Level loaded. %d enemies." % _enemies_alive)


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

		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Wall_%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		walls_container.add_child(body)
		body.global_position = wall_pos

		var col_shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = wall_size
		col_shape.shape = box_shape
		body.add_child(col_shape)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = wall_size
		mesh_inst.mesh = box_mesh
		mesh_inst.set_surface_override_material(0, wall_mat.duplicate())
		mesh_inst.set_script(_see_through_script)
		body.add_child(mesh_inst)


# ==========================================================================
# PROPS
# ==========================================================================
func _spawn_props() -> void:
	_spawn_lamp_posts()
	_spawn_market_stalls()
	_spawn_barrels()
	_spawn_crates()
	_spawn_graves()
	_spawn_pillars()
	_spawn_candles()


func _spawn_lamp_posts() -> void:
	## Wrought-iron style lamp posts with warm light
	var post_mat: StandardMaterial3D = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.15, 0.12, 0.1, 1)

	for pos: Vector3 in _lamp_positions:
		var root: Node3D = Node3D.new()
		props_container.add_child(root)
		root.global_position = pos

		# Post (tall cylinder)
		var post_body: StaticBody3D = StaticBody3D.new()
		post_body.collision_layer = 1
		post_body.collision_mask = 0
		root.add_child(post_body)

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 0.08
		shape.height = 3.0
		col.shape = shape
		col.position.y = 1.5
		post_body.add_child(col)

		var post_mesh: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.1
		cyl.height = 3.0
		post_mesh.mesh = cyl
		post_mesh.position.y = 1.5
		post_mesh.set_surface_override_material(0, post_mat)
		root.add_child(post_mesh)

		# Lantern housing (box on top)
		var lantern: MeshInstance3D = MeshInstance3D.new()
		var lantern_mesh: BoxMesh = BoxMesh.new()
		lantern_mesh.size = Vector3(0.25, 0.3, 0.25)
		lantern.mesh = lantern_mesh
		lantern.position.y = 3.15

		var lantern_mat: StandardMaterial3D = StandardMaterial3D.new()
		lantern_mat.albedo_color = Color(0.8, 0.6, 0.2, 0.7)
		lantern_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lantern_mat.emission_enabled = true
		lantern_mat.emission = Color(1.0, 0.7, 0.3, 1)
		lantern_mat.emission_energy_multiplier = 2.0
		lantern.set_surface_override_material(0, lantern_mat)
		root.add_child(lantern)

		# Light
		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = 3.2
		light.light_color = Color(1.0, 0.75, 0.4, 1)
		light.light_energy = 2.0
		light.omni_range = 6.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		root.add_child(light)


func _spawn_market_stalls() -> void:
	## Simple market stall structures (awning over table)
	var wood_mat: StandardMaterial3D = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.12, 1)

	var awning_mat: StandardMaterial3D = StandardMaterial3D.new()
	awning_mat.albedo_color = Color(0.6, 0.15, 0.1, 1)

	for sd: Dictionary in _stall_data:
		var pos: Vector3 = sd["pos"] as Vector3
		var rot: float = sd["rot"] as float

		var stall: Node3D = Node3D.new()
		props_container.add_child(stall)
		stall.global_position = pos
		stall.rotation_degrees.y = rot

		# Counter
		var counter: StaticBody3D = StaticBody3D.new()
		counter.collision_layer = 1
		counter.collision_mask = 0
		stall.add_child(counter)

		var c_col: CollisionShape3D = CollisionShape3D.new()
		var c_shape: BoxShape3D = BoxShape3D.new()
		c_shape.size = Vector3(2.5, 1.0, 1.0)
		c_col.shape = c_shape
		c_col.position.y = 0.5
		counter.add_child(c_col)

		var c_mesh: MeshInstance3D = MeshInstance3D.new()
		var c_box: BoxMesh = BoxMesh.new()
		c_box.size = Vector3(2.5, 1.0, 1.0)
		c_mesh.mesh = c_box
		c_mesh.position.y = 0.5
		c_mesh.set_surface_override_material(0, wood_mat)
		counter.add_child(c_mesh)

		# Awning (slanted roof)
		var awning: MeshInstance3D = MeshInstance3D.new()
		var a_box: BoxMesh = BoxMesh.new()
		a_box.size = Vector3(3.0, 0.06, 1.5)
		awning.mesh = a_box
		awning.position = Vector3(0, 2.2, 0)
		awning.rotation_degrees.x = 10.0
		awning.set_surface_override_material(0, awning_mat)
		stall.add_child(awning)

		# Support poles
		for x_off: float in [-1.2, 1.2]:
			var pole: MeshInstance3D = MeshInstance3D.new()
			var pole_cyl: CylinderMesh = CylinderMesh.new()
			pole_cyl.top_radius = 0.04
			pole_cyl.bottom_radius = 0.04
			pole_cyl.height = 2.2
			pole.mesh = pole_cyl
			pole.position = Vector3(x_off, 1.1, 0.4)
			pole.set_surface_override_material(0, wood_mat)
			stall.add_child(pole)


func _spawn_barrels() -> void:
	# Physics-enabled breakable barrels
	for pos: Vector3 in _barrel_positions:
		var barrel: BreakableProp = BreakableProp.create_barrel(pos)
		props_container.add_child(barrel)


func _spawn_crates() -> void:
	# Physics-enabled breakable crates
	for pos: Vector3 in _crate_positions:
		var crate: BreakableProp = BreakableProp.create_crate(pos)
		props_container.add_child(crate)


func _spawn_graves() -> void:
	## Tombstones — thin slabs sticking out of the ground
	var grave_mat: StandardMaterial3D = StandardMaterial3D.new()
	grave_mat.albedo_color = Color(0.4, 0.4, 0.38, 1)

	for pos: Vector3 in _grave_positions:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		props_container.add_child(body)
		body.global_position = pos

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.6, 1.0, 0.12)
		col.shape = shape
		col.position.y = 0.5
		body.add_child(col)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.6, 1.0, 0.12)
		mesh_inst.mesh = box
		mesh_inst.position.y = 0.5
		mesh_inst.set_surface_override_material(0, grave_mat)
		# Random slight tilt for age effect
		mesh_inst.rotation_degrees.z = randf_range(-8.0, 8.0)
		mesh_inst.rotation_degrees.y = randf_range(-15.0, 15.0)
		body.add_child(mesh_inst)


func _spawn_pillars() -> void:
	var pillar_mat: StandardMaterial3D = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.3, 0.28, 0.25, 1)

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

		var base_mesh: MeshInstance3D = MeshInstance3D.new()
		var base: BoxMesh = BoxMesh.new()
		base.size = Vector3(1.2, 0.2, 1.2)
		base_mesh.mesh = base
		base_mesh.position.y = -1.9
		base_mesh.set_surface_override_material(0, pillar_mat)
		body.add_child(base_mesh)

		var cap_mesh: MeshInstance3D = MeshInstance3D.new()
		var cap: BoxMesh = BoxMesh.new()
		cap.size = Vector3(1.0, 0.15, 1.0)
		cap_mesh.mesh = cap
		cap_mesh.position.y = 1.9
		cap_mesh.set_surface_override_material(0, pillar_mat)
		body.add_child(cap_mesh)


func _spawn_candles() -> void:
	var candle_mat: StandardMaterial3D = StandardMaterial3D.new()
	candle_mat.albedo_color = Color(0.9, 0.85, 0.7, 1)

	for pos: Vector3 in _candle_positions:
		var candle_root: Node3D = Node3D.new()
		props_container.add_child(candle_root)
		candle_root.global_position = pos

		var candle_mesh: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = 0.2
		candle_mesh.mesh = cyl
		candle_mesh.set_surface_override_material(0, candle_mat)
		candle_root.add_child(candle_mesh)

		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = 0.15
		light.light_color = Color(0.2, 0.8, 0.3, 1)  # Eerie green for graveyard
		light.light_energy = 1.5
		light.omni_range = 4.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		candle_root.add_child(light)

		var flame: MeshInstance3D = MeshInstance3D.new()
		var flame_mesh: SphereMesh = SphereMesh.new()
		flame_mesh.radius = 0.03
		flame_mesh.height = 0.06
		flame.mesh = flame_mesh
		flame.position.y = 0.12
		var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
		flame_mat.albedo_color = Color(0.2, 0.9, 0.3, 1)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(0.2, 0.9, 0.3, 1)
		flame_mat.emission_energy_multiplier = 3.0
		flame.set_surface_override_material(0, flame_mat)
		candle_root.add_child(flame)


# ==========================================================================
# ENEMIES
# ==========================================================================
func _spawn_enemies(spawn_list: Array) -> void:
	for spawn_data: Dictionary in spawn_list:
		var enemy_type: String = spawn_data.get("type", "warrior") as String
		var scene: PackedScene = skeleton_warrior_scene
		match enemy_type:
			"rogue":
				scene = skeleton_rogue_scene
			"minion":
				scene = skeleton_minion_scene
			_:
				scene = skeleton_warrior_scene

		var enemy: EnemyBase = scene.instantiate() as EnemyBase
		enemy.enemy_died.connect(_on_enemy_died)
		enemy_container.add_child(enemy)
		enemy.global_position = spawn_data["pos"] as Vector3

		if spawn_data.has("patrol"):
			var patrol_array: Array = spawn_data["patrol"]
			if not patrol_array.is_empty():
				var typed_patrol: Array[Vector3] = []
				for pt: Vector3 in patrol_array:
					typed_patrol.append(pt)
				enemy.patrol_points = typed_patrol

		_enemies_alive += 1


func _spawn_coins() -> void:
	for coin_pos: Vector3 in _coin_positions:
		var coin: PurpleCoin = purple_coin_scene.instantiate() as PurpleCoin
		pickup_container.add_child(coin)
		coin.global_position = coin_pos


# -- Boss Trigger --
func _on_boss_trigger_entered(body: Node3D) -> void:
	if _boss_spawned or _boss_defeated:
		return
	if body is PlayerController:
		_start_boss_fight()


func _start_boss_fight() -> void:
	_boss_spawned = true
	_boss_fight_active = true
	print("[FrenchQuarter] BOSS FIGHT: Baron Samedi!")

	if hud and hud.has_method("show_message"):
		hud.show_message("Baron Samedi rises!", 2.0)

	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar("Baron Samedi")

	# Dramatic boss entrance VFX — green voodoo energy
	VFXHelper.spawn_boss_entrance(get_tree().root, Vector3(0, 0, -72), Color(0.2, 0.9, 0.3))

	var boss: BaronSamedi = baron_samedi_scene.instantiate() as BaronSamedi
	boss.spawn_rogue_scene = skeleton_rogue_scene
	boss.spawn_warrior_scene = skeleton_warrior_scene
	boss_container.add_child(boss)
	boss.global_position = Vector3(0, 0, -72)

	_boss_ref = boss

	boss.boss_defeated.connect(_on_boss_defeated)
	boss.boss_phase_changed.connect(_on_boss_phase_changed)
	boss.boss_health_changed.connect(_on_boss_health_changed)
	boss.enemy_died.connect(_on_enemy_died)

	boss_trigger.set_collision_mask_value(2, false)
	boss_trigger.monitoring = false


func _on_boss_defeated() -> void:
	_boss_defeated = true
	_boss_fight_active = false
	print("[FrenchQuarter] Baron Samedi DEFEATED!")

	if hud and hud.has_method("show_message"):
		hud.show_message("Baron Samedi defeated!", 3.0)

	if player and player.clout_inventory:
		var grail_item: CloutItem = _clout_db.get_random_item(CloutItem.Rarity.GRAIL)
		if grail_item:
			player.clout_inventory.add_item(grail_item)

	await get_tree().create_timer(3.0).timeout
	GameManager.level_completed()


func _on_boss_phase_changed(phase: int) -> void:
	match phase:
		2:
			if hud and hud.has_method("show_message"):
				hud.show_message("The spirits grow restless...", 2.0)
		3:
			if hud and hud.has_method("show_message"):
				hud.show_message("Baron Samedi enters VOODOO FRENZY!", 2.0)


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(current_hp, max_hp)


func _on_enemy_died(enemy: EnemyBase) -> void:
	_enemies_alive -= 1

	if not (enemy is BaronSamedi):
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
			print("[FrenchQuarter] Dropped clout: %s" % item.item_name)


func _on_player_died() -> void:
	print("[FrenchQuarter] Oley has fallen in the French Quarter...")
	GameManager.player_died()
	GameManager.purple_coins = 0
