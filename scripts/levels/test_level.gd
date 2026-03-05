extends Node3D
class_name TestLevel

## Test Level - Hub with Branches layout
## Central hub room with 3 branching paths:
##   - North: Combat gauntlet (groups of skeleton minions)
##   - East: Exploration path (treasure chests, environmental storytelling)
##   - West: Mini-boss arena (tougher minion + reinforcements)
##
## This is a vertical slice test level for Oley's World.

@export var skeleton_minion_scene: PackedScene = preload("res://scenes/enemies/skeleton_minion.tscn")
@export var purple_coin_scene: PackedScene = preload("res://scenes/pickups/purple_coin.tscn")

# Enemy spawn data: [position, patrol_points (optional)]
var _north_spawns: Array = [
	{"pos": Vector3(0, 0, -20), "patrol": [Vector3(-3, 0, 0), Vector3(3, 0, 0)]},
	{"pos": Vector3(3, 0, -25), "patrol": []},
	{"pos": Vector3(-3, 0, -25), "patrol": []},
	{"pos": Vector3(0, 0, -32), "patrol": [Vector3(-2, 0, 0), Vector3(2, 0, 0)]},
	{"pos": Vector3(2, 0, -35), "patrol": []},
	{"pos": Vector3(-2, 0, -35), "patrol": []},
]

var _east_spawns: Array = [
	{"pos": Vector3(20, 0, -3), "patrol": [Vector3(0, 0, -3), Vector3(0, 0, 3)]},
	{"pos": Vector3(28, 0, 0), "patrol": [Vector3(-2, 0, 0), Vector3(2, 0, 0)]},
]

var _west_spawns: Array = [
	# Mini-boss area - tighter group
	{"pos": Vector3(-20, 0, 0), "patrol": [Vector3(-2, 0, -2), Vector3(2, 0, 2)]},
	{"pos": Vector3(-22, 0, 3), "patrol": []},
	{"pos": Vector3(-22, 0, -3), "patrol": []},
	{"pos": Vector3(-25, 0, 0), "patrol": [Vector3(-1, 0, -1), Vector3(1, 0, 1)]},
]

var _enemies_alive: int = 0
var _clout_db: CloutDatabase = CloutDatabase.new()

@onready var enemy_container: Node3D = $Enemies
@onready var pickup_container: Node3D = $Pickups if has_node("Pickups") else null
@onready var player: PlayerController = $Oley


func _ready() -> void:
	# Create pickups container if it doesn't exist
	if not pickup_container:
		pickup_container = Node3D.new()
		pickup_container.name = "Pickups"
		add_child(pickup_container)

	_spawn_enemies()
	_spawn_coins()

	if player:
		player.player_died.connect(_on_player_died)


func _spawn_enemies() -> void:
	var all_spawns := _north_spawns + _east_spawns + _west_spawns

	for spawn_data: Dictionary in all_spawns:
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

	print("[TestLevel] Spawned %d enemies" % _enemies_alive)


func _spawn_coins() -> void:
	"""Scatter purple coins around the map."""
	var coin_positions: Array[Vector3] = [
		Vector3(0, 0.5, -15),
		Vector3(5, 0.5, -20),
		Vector3(-5, 0.5, -20),
		Vector3(10, 0.5, -30),
		Vector3(-10, 0.5, -30),
		Vector3(20, 0.5, 0),
		Vector3(25, 0.5, 5),
		Vector3(-20, 0.5, 5),
		Vector3(-25, 0.5, -5),
	]

	for coin_pos: Vector3 in coin_positions:
		var coin: PurpleCoin = purple_coin_scene.instantiate() as PurpleCoin
		pickup_container.add_child(coin)
		coin.global_position = coin_pos

	print("[TestLevel] Spawned %d coins" % coin_positions.size())


func _on_enemy_died(enemy: EnemyBase) -> void:
	_enemies_alive -= 1
	print("[TestLevel] Enemy defeated! %d remaining" % _enemies_alive)

	# Chance to drop clout items
	if randf() < 0.3:  # 30% chance
		_spawn_clout_drop(enemy.global_position)

	if _enemies_alive <= 0:
		print("[TestLevel] ALL ENEMIES DEFEATED! Level complete!")
		GameManager.level_completed()


func _spawn_clout_drop(position: Vector3) -> void:
	"""Spawn a clout item drop at the given position."""
	var rarity_roll: float = randf()
	var item_rarity: CloutItem.Rarity

	if rarity_roll < 0.5:
		item_rarity = CloutItem.Rarity.MID
	elif rarity_roll < 0.85:
		item_rarity = CloutItem.Rarity.DRIP
	else:
		item_rarity = CloutItem.Rarity.GRAIL

	var item: CloutItem = _clout_db.get_random_item(item_rarity)
	if item and player and player.clout_inventory:
		if player.clout_inventory.add_item(item):
			print("[TestLevel] Dropped clout item: %s" % item.item_name)


func _on_player_died() -> void:
	print("[TestLevel] Oley has fallen...")
	GameManager.player_died()
	# Reset coins for next level
	GameManager.purple_coins = 0
