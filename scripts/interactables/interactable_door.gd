extends StaticBody3D
class_name InteractableDoor

## A door that can be opened/closed by pressing the interact key.
## Uses a Tween to swing open around its hinge (Y-axis rotation).
## Player must be within the InteractArea to trigger.

@export var open_angle: float = 100.0         # Degrees to swing open
@export var open_speed: float = 0.5           # Seconds to open/close
@export var auto_close_delay: float = 0.0     # 0 = no auto close
@export var is_locked: bool = false           # Locked doors won't open

var _is_open: bool = false
var _is_animating: bool = false
var _player_nearby: bool = false
var _closed_rotation_y: float = 0.0

@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var interact_area: Area3D = $InteractArea

signal door_opened
signal door_closed


func _ready() -> void:
	_closed_rotation_y = rotation_degrees.y
	add_to_group("interactables")

	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby and not _is_animating:
		if is_locked:
			print("[Door] Locked!")
			return
		toggle()


func toggle() -> void:
	if _is_animating:
		return
	if _is_open:
		close_door()
	else:
		open_door()


func open_door() -> void:
	if _is_open or _is_animating:
		return
	_is_animating = true

	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", _closed_rotation_y + open_angle, open_speed)
	tween.tween_callback(_on_open_finished)


func close_door() -> void:
	if not _is_open or _is_animating:
		return
	_is_animating = true

	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", _closed_rotation_y, open_speed)
	tween.tween_callback(_on_close_finished)


func _on_open_finished() -> void:
	_is_open = true
	_is_animating = false
	door_opened.emit()

	# Disable collision while open so player can walk through
	set_collision_layer_value(1, false)

	if auto_close_delay > 0:
		var timer: SceneTreeTimer = get_tree().create_timer(auto_close_delay)
		timer.timeout.connect(close_door)


func _on_close_finished() -> void:
	_is_open = false
	_is_animating = false
	door_closed.emit()

	# Re-enable collision when closed
	set_collision_layer_value(1, true)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		_player_nearby = true


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		_player_nearby = false


func unlock() -> void:
	is_locked = false
	print("[Door] Unlocked!")
