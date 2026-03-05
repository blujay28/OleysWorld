extends Node

## GameManager - Autoloaded singleton for global game state.
## Manages game flow, scoring, and level transitions.
## Access anywhere via: GameManager.some_method()

# -- Game State --
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, LEVEL_COMPLETE, GAME_WON }

var current_state: GameState = GameState.PLAYING
var enemies_defeated: int = 0
var total_enemies: int = 0
var current_level: String = ""
var current_level_index: int = 0
var purple_coins: int = 0

# -- Level Order --
var level_scenes: Array[String] = [
	"res://scenes/levels/dades_house.tscn",
	"res://scenes/levels/french_quarter.tscn",
	"res://scenes/levels/zeniths_lab.tscn",
]

var level_names: Array[String] = [
	"Dade's House",
	"French Quarter",
	"Zenith's Laboratory",
]

# -- Signals --
signal state_changed(new_state: GameState)
signal enemy_count_updated(defeated: int, total: int)
signal coins_changed(new_total: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] Initialized - Oley's World")

	# Determine current level index from scene path
	var scene_path: String = ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	for i: int in range(level_scenes.size()):
		if scene_path == level_scenes[i]:
			current_level_index = i
			current_level = level_names[i]
			break

	print("[GameManager] Current level: %s (index %d)" % [current_level, current_level_index])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_state == GameState.PLAYING:
		toggle_pause()


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	emit_signal("state_changed", current_state)


func level_completed() -> void:
	current_state = GameState.LEVEL_COMPLETE
	emit_signal("state_changed", current_state)
	print("[GameManager] LEVEL COMPLETE! (%s)" % current_level)

	# Check if there's a next level
	var next_index: int = current_level_index + 1
	if next_index < level_scenes.size():
		# Load next level after delay
		print("[GameManager] Loading next level: %s" % level_names[next_index])
		await get_tree().create_timer(3.0).timeout
		load_level(next_index)
	else:
		# Game won!
		current_state = GameState.GAME_WON
		emit_signal("state_changed", current_state)
		print("[GameManager] GAME WON! Oley has defeated Zenith!")
		await get_tree().create_timer(5.0).timeout
		# Return to first level (could be main menu later)
		load_level(0)


func load_level(level_index: int) -> void:
	## Load a specific level by index
	if level_index < 0 or level_index >= level_scenes.size():
		print("[GameManager] Invalid level index: %d" % level_index)
		return

	current_level_index = level_index
	current_level = level_names[level_index]
	current_state = GameState.PLAYING
	enemies_defeated = 0
	get_tree().paused = false

	var err: int = get_tree().change_scene_to_file(level_scenes[level_index])
	if err != OK:
		print("[GameManager] Error loading level: %d" % err)


func player_died() -> void:
	current_state = GameState.GAME_OVER
	emit_signal("state_changed", current_state)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[GameManager] GAME OVER - Oley has fallen")

	# Restart current level after delay
	await get_tree().create_timer(3.0).timeout
	restart_level()


func restart_level() -> void:
	current_state = GameState.PLAYING
	enemies_defeated = 0
	get_tree().paused = false
	get_tree().reload_current_scene()


func register_enemy_defeated() -> void:
	enemies_defeated += 1
	emit_signal("enemy_count_updated", enemies_defeated, total_enemies)


func add_coins(amount: int) -> void:
	"""Add coins to the player's total."""
	purple_coins += amount
	coins_changed.emit(purple_coins)


func quit_game() -> void:
	get_tree().quit()
