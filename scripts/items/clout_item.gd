extends Resource
class_name CloutItem

## Clout Item - A rare fashion item that provides stat bonuses
## Items can be equipped to modify player stats

enum Rarity { MID, DRIP, GRAIL }

@export var item_name: String = "Item"
@export var description: String = ""
@export var rarity: Rarity = Rarity.MID
@export var icon_color: Color = Color.WHITE
@export var stat_modifiers: Dictionary = {}  # {"stat_name": multiplier}


func _init(p_name: String = "", p_description: String = "", p_rarity: Rarity = Rarity.MID, p_color: Color = Color.WHITE, p_modifiers: Dictionary = {}) -> void:
	item_name = p_name
	description = p_description
	rarity = p_rarity
	icon_color = p_color
	stat_modifiers = p_modifiers


func get_rarity_name() -> String:
	"""Return the rarity as a string."""
	match rarity:
		Rarity.MID:
			return "MID"
		Rarity.DRIP:
			return "DRIP"
		Rarity.GRAIL:
			return "GRAIL"
	return "UNKNOWN"


func get_rarity_color() -> Color:
	"""Return a color based on rarity."""
	match rarity:
		Rarity.MID:
			return Color.GRAY
		Rarity.DRIP:
			return Color.LIGHT_BLUE
		Rarity.GRAIL:
			return Color.YELLOW
	return Color.WHITE
