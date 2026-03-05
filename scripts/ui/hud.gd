extends CanvasLayer

## HUD - Risk of Rain 2 inspired layout
## Top: Clout item icons | Top-right: Stage, timer, coins
## Bottom-left: Health bar with name/level | Bottom-right: 4 skill boxes

# -- Top bar --
@onready var item_bar: HBoxContainer = $Root/TopBar/ItemBar
@onready var stage_label: Label = $Root/TopBar/TopRight/StageLabel
@onready var timer_label: Label = $Root/TopBar/TopRight/TimerLabel
@onready var coins_label: Label = $Root/TopBar/TopRight/CoinsLabel

# -- Bottom-left health --
@onready var name_label: Label = $Root/BottomLeft/NameLabel
@onready var health_bar_bg: ColorRect = $Root/BottomLeft/HealthBarBG
@onready var health_bar: ColorRect = $Root/BottomLeft/HealthBarBG/HealthBar
@onready var health_text: Label = $Root/BottomLeft/HealthBarBG/HealthText
@onready var level_label: Label = $Root/BottomLeft/LevelLabel

# -- Bottom-right skills --
@onready var skill1_panel: PanelContainer = $Root/BottomRight/Skill1
@onready var skill1_overlay: ColorRect = $Root/BottomRight/Skill1/CooldownOverlay
@onready var skill1_name: Label = $Root/BottomRight/Skill1/VBox/Name
@onready var skill1_ammo: Label = $Root/BottomRight/Skill1/VBox/Ammo

@onready var skill2_panel: PanelContainer = $Root/BottomRight/Skill2
@onready var skill2_overlay: ColorRect = $Root/BottomRight/Skill2/CooldownOverlay
@onready var skill2_name: Label = $Root/BottomRight/Skill2/VBox/Name
@onready var skill2_info: Label = $Root/BottomRight/Skill2/VBox/Info

@onready var skill3_panel: PanelContainer = $Root/BottomRight/Skill3
@onready var skill3_overlay: ColorRect = $Root/BottomRight/Skill3/CooldownOverlay
@onready var skill3_name: Label = $Root/BottomRight/Skill3/VBox/Name
@onready var skill3_cd: Label = $Root/BottomRight/Skill3/VBox/Cooldown

@onready var skill4_panel: PanelContainer = $Root/BottomRight/Skill4
@onready var skill4_overlay: ColorRect = $Root/BottomRight/Skill4/CooldownOverlay
@onready var skill4_name: Label = $Root/BottomRight/Skill4/VBox/Name
@onready var skill4_cd: Label = $Root/BottomRight/Skill4/VBox/Cooldown

# -- Boss health bar --
@onready var boss_bar: VBoxContainer = $Root/BossBar
@onready var boss_name_label: Label = $Root/BossBar/BossName
@onready var boss_health_fill: ColorRect = $Root/BossBar/BossHealthBG/BossHealthFill
@onready var boss_health_text: Label = $Root/BossBar/BossHealthBG/BossHealthText

# -- Center message --
@onready var center_message: Label = $Root/CenterMessage

var _message_timer: float = 0.0
var _run_timer: float = 0.0
var player: PlayerController = null

# Rarity border colors for item icons
var RARITY_COLORS: Dictionary = {
	"MID": Color(0.5, 0.5, 0.5, 1),
	"DRIP": Color(0.4, 0.7, 1.0, 1),
	"GRAIL": Color(1.0, 0.85, 0.2, 1),
}


func _ready() -> void:
	await get_tree().process_frame
	player = _find_player()
	if player:
		player.health_changed.connect(_on_health_changed)
		player.player_died.connect(_on_player_died)

	GameManager.state_changed.connect(_on_game_state_changed)
	GameManager.coins_changed.connect(_on_coins_changed)

	# Connect weapon signals
	if player and player.weapons.size() > 0:
		# Connect weapon_switched signal if available
		if player.has_signal("weapon_switched"):
			player.weapon_switched.connect(_on_weapon_switched)

	# Connect clout inventory
	if player and player.clout_inventory:
		player.clout_inventory.inventory_changed.connect(_on_clout_changed)

	# Initial display
	_update_health_display(100, 100)
	_update_weapon_display()
	_update_item_bar()
	coins_label.text = "0"


func _process(delta: float) -> void:
	# Run timer
	_run_timer += delta
	var minutes: int = int(_run_timer) / 60
	var seconds: int = int(_run_timer) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Center message fade
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			center_message.text = ""

	# Update skill cooldowns
	_update_skill_cooldowns()

	# Highlight active weapon
	_update_weapon_highlight()


func _find_player() -> PlayerController:
	return _find_node_by_class(get_tree().root) as PlayerController


func _find_node_by_class(node: Node) -> Node:
	if node is PlayerController:
		return node
	for child: Node in node.get_children():
		var result: Node = _find_node_by_class(child)
		if result:
			return result
	return null


# -- Health --
func _on_health_changed(new_health: int, max_hp: int) -> void:
	_update_health_display(new_health, max_hp)


func _update_health_display(hp: int, max_hp: int) -> void:
	health_text.text = "%d / %d" % [hp, max_hp]

	# Scale the green bar width as a proportion of the BG
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	health_bar.anchor_right = ratio

	# Color shifts: green -> yellow -> red
	if ratio > 0.5:
		health_bar.color = Color(0.3, 0.85, 0.35, 1)
	elif ratio > 0.25:
		health_bar.color = Color(0.9, 0.75, 0.2, 1)
	else:
		health_bar.color = Color(0.9, 0.2, 0.2, 1)


func _on_player_died() -> void:
	show_message("Oley has fallen...", 3.0)


# -- Weapons --
func _update_weapon_display() -> void:
	if not player or player.weapons.size() == 0:
		return

	# Weapon 1 (Sword) cooldown
	if player.weapons.size() > 0:
		var weapon1: WeaponBase = player.weapons[0]
		if weapon1.is_ready:
			skill1_ammo.text = "Ready"
			skill1_ammo.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 0.9))
			skill1_overlay.visible = false
		else:
			skill1_ammo.text = "%.1fs" % max(0.0, weapon1.current_cooldown)
			skill1_ammo.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 0.9))
			skill1_overlay.visible = true

	# Weapon 2 (Bow) cooldown
	if player.weapons.size() > 1:
		var weapon2: WeaponBase = player.weapons[1]
		if weapon2.is_ready:
			skill2_info.text = "Ready"
			skill2_info.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 0.9))
			skill2_overlay.visible = false
		else:
			skill2_info.text = "%.1fs" % max(0.0, weapon2.current_cooldown)
			skill2_info.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 0.9))
			skill2_overlay.visible = true


func _update_weapon_highlight() -> void:
	if not player:
		return

	# Highlight the active weapon's skill box border
	var is_weapon1: bool = player.current_weapon_index == 0
	var weapon1_bg: ColorRect = $Root/BottomRight/Skill1/BG
	var weapon2_bg: ColorRect = $Root/BottomRight/Skill2/BG

	if is_weapon1:
		weapon1_bg.color = Color(0.2, 0.22, 0.3, 0.95)
		weapon2_bg.color = Color(0.12, 0.12, 0.15, 0.9)
	else:
		weapon1_bg.color = Color(0.12, 0.12, 0.15, 0.9)
		weapon2_bg.color = Color(0.2, 0.22, 0.3, 0.95)


func _on_weapon_switched(weapon_name: String) -> void:
	_update_weapon_display()


# -- Abilities / Skills --
func _update_skill_cooldowns() -> void:
	if not player:
		return

	# Weapon cooldowns
	_update_weapon_display()

	# Ability 1: Mewing (Skill3)
	if player.abilities.size() > 0:
		var mewing: AbilityBase = player.abilities[0]
		if mewing.is_ready:
			skill3_cd.text = "Ready"
			skill3_cd.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 0.9))
			skill3_overlay.visible = false
		else:
			skill3_cd.text = "%.1fs" % max(0.0, mewing.current_cooldown)
			skill3_cd.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 0.9))
			skill3_overlay.visible = true

	# Ability 2: Hypercritical Analysis (Skill4)
	if player.abilities.size() > 1:
		var hyper: AbilityBase = player.abilities[1]
		if hyper.is_ready:
			skill4_cd.text = "Ready"
			skill4_cd.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 0.9))
			skill4_overlay.visible = false
		else:
			skill4_cd.text = "%.1fs" % max(0.0, hyper.current_cooldown)
			skill4_cd.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 0.9))
			skill4_overlay.visible = true

	# Crit active indicator
	if player.crit_active:
		skill4_cd.text = "ACTIVE"
		skill4_cd.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))


# -- Clout Items (top bar icons) --
func _on_clout_changed() -> void:
	_update_item_bar()


func _update_item_bar() -> void:
	# Clear existing item icons
	for child: Node in item_bar.get_children():
		child.queue_free()

	if not player or not player.clout_inventory:
		return

	var items: Array[CloutItem] = player.clout_inventory.get_all_items()
	for item: CloutItem in items:
		var icon: PanelContainer = _create_item_icon(item)
		item_bar.add_child(icon)


func _create_item_icon(item: CloutItem) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 40)

	# Background colored by rarity
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	# Rarity border (inner colored rect)
	var border: ColorRect = ColorRect.new()
	border.color = item.get_rarity_color()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left = 2
	border.offset_top = 2
	border.offset_right = -2
	border.offset_bottom = -2
	panel.add_child(border)

	# Inner bg
	var inner: ColorRect = ColorRect.new()
	inner.color = item.icon_color.darkened(0.5)
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 4
	inner.offset_top = 4
	inner.offset_right = -4
	inner.offset_bottom = -4
	panel.add_child(inner)

	# First letter as icon
	var lbl: Label = Label.new()
	lbl.text = item.item_name.substr(0, 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(lbl)

	# Tooltip
	panel.tooltip_text = "%s [%s]\n%s" % [item.item_name, item.get_rarity_name(), item.description]

	return panel


# -- Coins --
func _on_coins_changed(new_total: int) -> void:
	coins_label.text = "%d" % new_total


# -- Game State --
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.LEVEL_COMPLETE:
			show_message("LEVEL COMPLETE!", 3.0)
		GameManager.GameState.GAME_OVER:
			show_message("GAME OVER", 3.0)
		GameManager.GameState.PAUSED:
			show_message("PAUSED", 0.0)
		GameManager.GameState.PLAYING:
			center_message.text = ""


func show_message(text: String, duration: float = 2.0) -> void:
	center_message.text = text
	if duration > 0:
		_message_timer = duration


# -- Boss Health Bar --
func update_boss_health(current_hp: int, max_hp: int) -> void:
	if not boss_bar:
		return

	# Show the bar when boss is active
	if not boss_bar.visible and current_hp > 0:
		boss_bar.visible = true

	# Update fill
	var ratio: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	boss_health_fill.anchor_right = ratio
	boss_health_text.text = "%d / %d" % [current_hp, max_hp]

	# Color shift: red → dark red as health drops
	if ratio > 0.33:
		boss_health_fill.color = Color(0.9, 0.15, 0.15, 1)
	else:
		boss_health_fill.color = Color(0.6, 0.1, 0.1, 1)

	# Hide bar when boss dies
	if current_hp <= 0:
		await get_tree().create_timer(2.0).timeout
		if boss_bar:
			boss_bar.visible = false


func show_boss_bar(boss_name: String) -> void:
	if boss_bar:
		boss_bar.visible = true
		boss_name_label.text = boss_name


func hide_boss_bar() -> void:
	if boss_bar:
		boss_bar.visible = false
