extends Node3D

## Zenith's Laboratory — Level 3 (Final) of Oley's World.
## A high-tech dungeon beneath the city. Skeleton Mages and enhanced Warriors
## guard Zenith's experiments. The final boss awaits in the reactor core.
##
## Layout (linear along -Z axis):
##   Entrance Lab (spawn) → Corridor 1 → Test Chamber (enemies) →
##   Corridor 2 → Containment Wing → Reactor Core (boss arena)
##
## Room bounds (floor at Y=-0.25):
##   Entrance:      14×12 at (0, 0)     → X: -7..7,   Z: -6..6
##   Corridor1:      6×10 at (0, -11)   → X: -3..3,   Z: -16..-6
##   Test Chamber:  24×22 at (0, -27)   → X: -12..12,  Z: -38..-16
##   Corridor2:      6×10 at (0, -43)   → X: -3..3,   Z: -48..-38
##   Containment:   20×16 at (0, -56)   → X: -10..10,  Z: -64..-48
##   Reactor Core:  28×28 at (0, -78)   → X: -14..14,  Z: -92..-64

@export var skeleton_mage_scene: PackedScene = preload("res://scenes/enemies/skeleton_mage.tscn")
@export var skeleton_warrior_scene: PackedScene = preload("res://scenes/enemies/skeleton_warrior.tscn")
@export var skeleton_minion_scene: PackedScene = preload("res://scenes/enemies/skeleton_minion.tscn")
@export var zenith_scene: PackedScene = preload("res://scenes/enemies/zenith.tscn")
@export var purple_coin_scene: PackedScene = preload("res://scenes/pickups/purple_coin.tscn")

# -- State --
var _enemies_alive: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _boss_fight_active: bool = false
var _clout_db: CloutDatabase = CloutDatabase.new()
var _boss_ref: Zenith = null

# -- Enemy spawn data --
# Test Chamber — mages and warriors
var _test_chamber_spawns: Array = [
	{"pos": Vector3(-8, 0, -20), "patrol": [Vector3(4, 0, 0), Vector3(-4, 0, 0)], "type": "mage"},
	{"pos": Vector3(8, 0, -20), "patrol": [], "type": "mage"},
	{"pos": Vector3(-6, 0, -28), "patrol": [Vector3(2, 0, -2), Vector3(-2, 0, 2)], "type": "warrior"},
	{"pos": Vector3(6, 0, -28), "patrol": [], "type": "warrior"},
	{"pos": Vector3(0, 0, -24), "patrol": [Vector3(-5, 0, 0), Vector3(5, 0, 0)], "type": "mage"},
	{"pos": Vector3(-4, 0, -34), "patrol": [], "type": "warrior"},
	{"pos": Vector3(4, 0, -34), "patrol": [], "type": "mage"},
	{"pos": Vector3(-10, 0, -25), "patrol": [], "type": "warrior"},
	{"pos": Vector3(10, 0, -30), "patrol": [Vector3(0, 0, -3), Vector3(0, 0, 3)], "type": "mage"},
]

# Corridor 2 — ambush
var _corridor2_spawns: Array = [
	{"pos": Vector3(-2, 0, -41), "patrol": [], "type": "warrior"},
	{"pos": Vector3(2, 0, -45), "patrol": [], "type": "mage"},
]

# Containment Wing — heavy resistance
var _containment_spawns: Array = [
	{"pos": Vector3(-6, 0, -51), "patrol": [Vector3(3, 0, 0), Vector3(-3, 0, 0)], "type": "warrior"},
	{"pos": Vector3(6, 0, -51), "patrol": [], "type": "mage"},
	{"pos": Vector3(-8, 0, -58), "patrol": [], "type": "mage"},
	{"pos": Vector3(8, 0, -58), "patrol": [], "type": "warrior"},
	{"pos": Vector3(0, 0, -55), "patrol": [Vector3(-4, 0, 0), Vector3(4, 0, 0)], "type": "mage"},
	{"pos": Vector3(-4, 0, -62), "patrol": [], "type": "warrior"},
	{"pos": Vector3(4, 0, -62), "patrol": [], "type": "warrior"},
]

# Coin positions
var _coin_positions: Array[Vector3] = [
	Vector3(4, 0.5, 3),       # Entrance
	Vector3(-4, 0.5, 3),      # Entrance
	Vector3(0, 0.5, -11),     # Corridor 1
	Vector3(-9, 0.5, -22),    # Test Chamber
	Vector3(9, 0.5, -22),     # Test Chamber
	Vector3(0, 0.5, -30),     # Test Chamber center
	Vector3(-2, 0.5, -43),    # Corridor 2
	Vector3(2, 0.5, -43),     # Corridor 2
	Vector3(-7, 0.5, -55),    # Containment
	Vector3(7, 0.5, -55),     # Containment
	Vector3(0, 0.5, -60),     # Containment center
	Vector3(-10, 0.5, -70),   # Near reactor
]

# ==========================================================================
# WALL DATA
# ==========================================================================
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 0.3
var _wall_color: Color = Color(0.22, 0.22, 0.28, 1)  # Cool metallic grey

var _wall_data: Array = [
	# -- Entrance Lab (14×12 at Z=0) --
	{"pos": Vector3(-7, 2, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},
	{"pos": Vector3(7, 2, 0),     "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 12)},
	{"pos": Vector3(0, 2, 6),     "size": Vector3(14, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-5, 2, -6),   "size": Vector3(4, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(5, 2, -6),    "size": Vector3(4, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Corridor 1 (6×10 at Z=-11) --
	{"pos": Vector3(-3, 2, -11),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},
	{"pos": Vector3(3, 2, -11),   "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},

	# -- Test Chamber (24×22 at Z=-27) --
	{"pos": Vector3(-12, 2, -27), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 22)},
	{"pos": Vector3(12, 2, -27),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 22)},
	{"pos": Vector3(-7.5, 2, -16), "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(7.5, 2, -16),  "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-7.5, 2, -38), "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(7.5, 2, -38),  "size": Vector3(9, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Corridor 2 (6×10 at Z=-43) --
	{"pos": Vector3(-3, 2, -43),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},
	{"pos": Vector3(3, 2, -43),   "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 10)},

	# -- Containment Wing (20×16 at Z=-56) --
	{"pos": Vector3(-10, 2, -56), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 16)},
	{"pos": Vector3(10, 2, -56),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 16)},
	{"pos": Vector3(-6.5, 2, -48), "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(6.5, 2, -48),  "size": Vector3(7, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(-6, 2, -64),  "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(6, 2, -64),   "size": Vector3(8, WALL_HEIGHT, WALL_THICKNESS)},

	# -- Reactor Core (28×28 at Z=-78) --
	{"pos": Vector3(-14, 2, -78), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 28)},
	{"pos": Vector3(14, 2, -78),  "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 28)},
	{"pos": Vector3(-9, 2, -64),  "size": Vector3(10, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(9, 2, -64),   "size": Vector3(10, WALL_HEIGHT, WALL_THICKNESS)},
	{"pos": Vector3(0, 2, -92),   "size": Vector3(28, WALL_HEIGHT, WALL_THICKNESS)},
]

# ==========================================================================
# PROP DATA — Lab themed: containment pods, terminals, generators
# ==========================================================================
var _terminal_positions: Array[Vector3] = [
	Vector3(5, 0, 3),        # Entrance
	Vector3(-5, 0, 3),       # Entrance
	Vector3(-10, 0, -20),    # Test Chamber
	Vector3(10, 0, -20),     # Test Chamber
	Vector3(-10, 0, -32),    # Test Chamber
	Vector3(10, 0, -32),     # Test Chamber
	Vector3(-8, 0, -52),     # Containment
	Vector3(8, 0, -52),      # Containment
]

var _pod_positions: Array[Vector3] = [
	# Containment pods — tall cylinders with eerie glow
	Vector3(-7, 0, -56),
	Vector3(-3, 0, -56),
	Vector3(3, 0, -56),
	Vector3(7, 0, -56),
	Vector3(-5, 0, -61),
	Vector3(5, 0, -61),
]

var _generator_positions: Array[Vector3] = [
	# Reactor Core — large generator structures
	Vector3(-10, 0, -70),
	Vector3(10, 0, -70),
	Vector3(-10, 0, -86),
	Vector3(10, 0, -86),
]

var _pillar_positions: Array[Vector3] = [
	# Reactor Core — support pillars
	Vector3(-10, 2, -72),
	Vector3(10, 2, -72),
	Vector3(-10, 2, -84),
	Vector3(10, 2, -84),
]

var _barrel_positions: Array[Vector3] = [
	Vector3(-5.5, 0.4, -4),
	Vector3(5.5, 0.4, -4),
	Vector3(-11, 0.4, -18),
	Vector3(11, 0.4, -35),
]

var _crate_positions: Array[Vector3] = [
	Vector3(-5.5, 0.35, 1),
	Vector3(5.5, 0.35, 1),
	Vector3(-11, 0.35, -24),
	Vector3(11, 0.35, -24),
	Vector3(-8.5, 0.35, -60),
	Vector3(8.5, 0.35, -60),
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
	_spawn_enemies(_test_chamber_spawns)
	_spawn_enemies(_corridor2_spawns)
	_spawn_enemies(_containment_spawns)
	_spawn_coins()

	if player:
		player.player_died.connect(_on_player_died)

	if boss_trigger:
		boss_trigger.body_entered.connect(_on_boss_trigger_entered)

	if hud and hud.has_node("Root/TopBar/TopRight/StageLabel"):
		var stage_label: Label = hud.get_node("Root/TopBar/TopRight/StageLabel") as Label
		if stage_label:
			stage_label.text = "Zenith's Laboratory"

	print("[ZenithsLab] Level loaded. %d enemies." % _enemies_alive)


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
	_spawn_terminals()
	_spawn_containment_pods()
	_spawn_generators()
	_spawn_pillars()
	_spawn_barrels()
	_spawn_crates()
	_spawn_lab_lights()


func _spawn_terminals() -> void:
	## Computer terminal stations — boxy with glowing screens
	var terminal_mat: StandardMaterial3D = StandardMaterial3D.new()
	terminal_mat.albedo_color = Color(0.18, 0.18, 0.22, 1)

	var screen_mat: StandardMaterial3D = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.8, 0.3, 0.9)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.8, 0.3, 1)
	screen_mat.emission_energy_multiplier = 2.0

	for pos: Vector3 in _terminal_positions:
		var root: Node3D = Node3D.new()
		props_container.add_child(root)
		root.global_position = pos

		# Terminal base
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.8, 1.0, 0.5)
		col.shape = shape
		col.position.y = 0.5
		body.add_child(col)

		var base_mesh: MeshInstance3D = MeshInstance3D.new()
		var base_box: BoxMesh = BoxMesh.new()
		base_box.size = Vector3(0.8, 1.0, 0.5)
		base_mesh.mesh = base_box
		base_mesh.position.y = 0.5
		base_mesh.set_surface_override_material(0, terminal_mat)
		root.add_child(base_mesh)

		# Screen (angled panel on top)
		var screen: MeshInstance3D = MeshInstance3D.new()
		var screen_box: BoxMesh = BoxMesh.new()
		screen_box.size = Vector3(0.6, 0.4, 0.02)
		screen.mesh = screen_box
		screen.position = Vector3(0, 1.2, -0.15)
		screen.rotation_degrees.x = -15.0
		screen.set_surface_override_material(0, screen_mat)
		root.add_child(screen)


func _spawn_containment_pods() -> void:
	## Tall glass cylinders with eerie green glow
	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.2, 0.8, 0.4, 0.3)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.1, 0.6, 0.2, 1)
	glass_mat.emission_energy_multiplier = 1.5

	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.15, 0.15, 0.2, 1)

	for pos: Vector3 in _pod_positions:
		var root: Node3D = Node3D.new()
		props_container.add_child(root)
		root.global_position = pos

		# Pod base
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 0.6
		shape.height = 2.5
		col.shape = shape
		col.position.y = 1.25
		body.add_child(col)

		# Base platform
		var base_mesh: MeshInstance3D = MeshInstance3D.new()
		var base_cyl: CylinderMesh = CylinderMesh.new()
		base_cyl.top_radius = 0.7
		base_cyl.bottom_radius = 0.8
		base_cyl.height = 0.2
		base_mesh.mesh = base_cyl
		base_mesh.position.y = 0.1
		base_mesh.set_surface_override_material(0, base_mat)
		root.add_child(base_mesh)

		# Glass tube
		var glass: MeshInstance3D = MeshInstance3D.new()
		var glass_cyl: CylinderMesh = CylinderMesh.new()
		glass_cyl.top_radius = 0.55
		glass_cyl.bottom_radius = 0.55
		glass_cyl.height = 2.2
		glass.mesh = glass_cyl
		glass.position.y = 1.3
		glass.set_surface_override_material(0, glass_mat)
		root.add_child(glass)

		# Interior glow light
		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = 1.3
		light.light_color = Color(0.1, 0.8, 0.3, 1)
		light.light_energy = 1.5
		light.omni_range = 3.0
		light.shadow_enabled = false
		root.add_child(light)

		# Top cap
		var cap_mesh: MeshInstance3D = MeshInstance3D.new()
		var cap_cyl: CylinderMesh = CylinderMesh.new()
		cap_cyl.top_radius = 0.65
		cap_cyl.bottom_radius = 0.7
		cap_cyl.height = 0.15
		cap_mesh.mesh = cap_cyl
		cap_mesh.position.y = 2.45
		cap_mesh.set_surface_override_material(0, base_mat)
		root.add_child(cap_mesh)


func _spawn_generators() -> void:
	## Large humming generators with electric glow
	var gen_mat: StandardMaterial3D = StandardMaterial3D.new()
	gen_mat.albedo_color = Color(0.2, 0.2, 0.25, 1)

	var coil_mat: StandardMaterial3D = StandardMaterial3D.new()
	coil_mat.albedo_color = Color(0.4, 0.2, 0.8, 0.8)
	coil_mat.emission_enabled = true
	coil_mat.emission = Color(0.5, 0.2, 1.0, 1)
	coil_mat.emission_energy_multiplier = 3.0

	for pos: Vector3 in _generator_positions:
		var root: Node3D = Node3D.new()
		props_container.add_child(root)
		root.global_position = pos

		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(2.0, 2.5, 2.0)
		col.shape = shape
		col.position.y = 1.25
		body.add_child(col)

		# Main housing
		var housing: MeshInstance3D = MeshInstance3D.new()
		var housing_box: BoxMesh = BoxMesh.new()
		housing_box.size = Vector3(2.0, 2.5, 2.0)
		housing.mesh = housing_box
		housing.position.y = 1.25
		housing.set_surface_override_material(0, gen_mat)
		root.add_child(housing)

		# Energy coil on top
		var coil: MeshInstance3D = MeshInstance3D.new()
		var coil_cyl: CylinderMesh = CylinderMesh.new()
		coil_cyl.top_radius = 0.3
		coil_cyl.bottom_radius = 0.5
		coil_cyl.height = 1.0
		coil.mesh = coil_cyl
		coil.position.y = 3.0
		coil.set_surface_override_material(0, coil_mat)
		root.add_child(coil)

		# Electric glow
		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = 3.2
		light.light_color = Color(0.5, 0.2, 1.0, 1)
		light.light_energy = 2.5
		light.omni_range = 5.0
		light.shadow_enabled = false
		root.add_child(light)


func _spawn_pillars() -> void:
	var pillar_mat: StandardMaterial3D = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.2, 0.2, 0.25, 1)

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


func _spawn_barrels() -> void:
	# Physics-enabled breakable barrels — metallic lab color
	for pos: Vector3 in _barrel_positions:
		var barrel: BreakableProp = BreakableProp.create_barrel(pos)
		barrel.prop_color = Color(0.25, 0.25, 0.3)  # Metallic lab barrel
		props_container.add_child(barrel)


func _spawn_crates() -> void:
	# Physics-enabled breakable crates — metallic lab color
	for pos: Vector3 in _crate_positions:
		var crate: BreakableProp = BreakableProp.create_crate(pos)
		crate.prop_color = Color(0.25, 0.25, 0.3)  # Metallic lab crate
		props_container.add_child(crate)


func _spawn_lab_lights() -> void:
	## Fluorescent-style overhead lights with cool blue tone
	var light_positions: Array[Vector3] = [
		Vector3(0, 3.5, 0),     # Entrance
		Vector3(0, 3.5, -11),   # Corridor 1
		Vector3(-6, 3.5, -22),  # Test Chamber
		Vector3(6, 3.5, -22),
		Vector3(-6, 3.5, -32),
		Vector3(6, 3.5, -32),
		Vector3(0, 3.5, -43),   # Corridor 2
		Vector3(-5, 3.5, -53),  # Containment
		Vector3(5, 3.5, -53),
		Vector3(-5, 3.5, -59),
		Vector3(5, 3.5, -59),
	]

	var fixture_mat: StandardMaterial3D = StandardMaterial3D.new()
	fixture_mat.albedo_color = Color(0.8, 0.85, 1.0, 0.8)
	fixture_mat.emission_enabled = true
	fixture_mat.emission = Color(0.7, 0.8, 1.0, 1)
	fixture_mat.emission_energy_multiplier = 1.5

	for pos: Vector3 in light_positions:
		var root: Node3D = Node3D.new()
		props_container.add_child(root)
		root.global_position = pos

		# Light fixture mesh
		var fixture: MeshInstance3D = MeshInstance3D.new()
		var fix_box: BoxMesh = BoxMesh.new()
		fix_box.size = Vector3(1.5, 0.05, 0.3)
		fixture.mesh = fix_box
		fixture.set_surface_override_material(0, fixture_mat)
		root.add_child(fixture)

		# Actual light
		var light: OmniLight3D = OmniLight3D.new()
		light.position.y = -0.1
		light.light_color = Color(0.7, 0.8, 1.0, 1)
		light.light_energy = 1.5
		light.omni_range = 6.0
		light.shadow_enabled = false
		root.add_child(light)


# ==========================================================================
# ENEMIES
# ==========================================================================
func _spawn_enemies(spawn_list: Array) -> void:
	for spawn_data: Dictionary in spawn_list:
		var enemy_type: String = spawn_data.get("type", "mage") as String
		var scene: PackedScene = skeleton_mage_scene
		match enemy_type:
			"warrior":
				scene = skeleton_warrior_scene
			"minion":
				scene = skeleton_minion_scene
			_:
				scene = skeleton_mage_scene

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
	print("[ZenithsLab] FINAL BOSS: ZENITH!")

	if hud and hud.has_method("show_message"):
		hud.show_message("ZENITH: You dare enter MY laboratory?!", 3.0)

	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar("ZENITH")

	# Dramatic boss entrance VFX — purple electric energy
	VFXHelper.spawn_boss_entrance(get_tree().root, Vector3(0, 0, -78), Color(0.6, 0.2, 1.0))

	var boss: Zenith = zenith_scene.instantiate() as Zenith
	boss.spawn_mage_scene = skeleton_mage_scene
	boss.spawn_minion_scene = skeleton_minion_scene
	boss_container.add_child(boss)
	boss.global_position = Vector3(0, 0, -78)

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
	print("[ZenithsLab] ZENITH DEFEATED! Oley saves the world!")

	if hud and hud.has_method("show_message"):
		hud.show_message("ZENITH DEFEATED! Oley is victorious!", 5.0)

	if player and player.clout_inventory:
		# Drop TWO grail items for the final boss
		for i: int in range(2):
			var grail_item: CloutItem = _clout_db.get_random_item(CloutItem.Rarity.GRAIL)
			if grail_item:
				player.clout_inventory.add_item(grail_item)

	await get_tree().create_timer(5.0).timeout
	GameManager.level_completed()


func _on_boss_phase_changed(phase: int) -> void:
	match phase:
		2:
			if hud and hud.has_method("show_message"):
				hud.show_message("ZENITH: Deploying countermeasures!", 2.0)
		3:
			if hud and hud.has_method("show_message"):
				hud.show_message("ZENITH enters OVERLOAD!", 2.0)


func _on_boss_health_changed(current_hp: int, max_hp: int) -> void:
	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(current_hp, max_hp)


func _on_enemy_died(enemy: EnemyBase) -> void:
	_enemies_alive -= 1

	if not (enemy is Zenith):
		if randf() < 0.3:  # Slightly higher drop rate in final level
			_spawn_clout_drop(enemy.global_position)


func _spawn_clout_drop(position: Vector3) -> void:
	var rarity_roll: float = randf()
	var item_rarity: CloutItem.Rarity

	if rarity_roll < 0.45:
		item_rarity = CloutItem.Rarity.MID
	elif rarity_roll < 0.85:
		item_rarity = CloutItem.Rarity.DRIP
	else:
		item_rarity = CloutItem.Rarity.GRAIL

	var item: CloutItem = _clout_db.get_random_item(item_rarity)
	if item and player and player.clout_inventory:
		if player.clout_inventory.add_item(item):
			print("[ZenithsLab] Dropped clout: %s" % item.item_name)


func _on_player_died() -> void:
	print("[ZenithsLab] Oley has fallen in Zenith's Laboratory...")
	GameManager.player_died()
	GameManager.purple_coins = 0
