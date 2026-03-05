extends Node
class_name CloutDatabase

## Static database of all clout items in Oley's World
## Organized by rarity tier with stat bonuses

var mid_tier_items: Array[CloutItem] = []
var drip_tier_items: Array[CloutItem] = []
var grail_tier_items: Array[CloutItem] = []


func _init() -> void:
	_initialize_items()


func _initialize_items() -> void:
	"""Initialize all items in the database."""

	# -- MID TIER --
	mid_tier_items.append(CloutItem.new("Skechers", "Basic sneakers for mobility", CloutItem.Rarity.MID, Color.GRAY, {"speed": 1.1}))
	mid_tier_items.append(CloutItem.new("Old Navy Khakis", "Classic pants", CloutItem.Rarity.MID, Color.GRAY, {"reload_speed": 1.1}))
	mid_tier_items.append(CloutItem.new("Walmart Shades", "Budget-friendly eyewear", CloutItem.Rarity.MID, Color.GRAY, {"damage": 1.05}))
	mid_tier_items.append(CloutItem.new("Crocs", "Love it or hate it", CloutItem.Rarity.MID, Color.GRAY, {"speed": 1.15, "damage": 0.95}))

	# -- DRIP TIER --
	drip_tier_items.append(CloutItem.new("Supreme Box Logo Tee", "Peak hypebeast fashion", CloutItem.Rarity.DRIP, Color.LIGHT_BLUE, {"max_health": 1.2}))
	drip_tier_items.append(CloutItem.new("Jordan 4 Retros", "Legendary kicks", CloutItem.Rarity.DRIP, Color.LIGHT_BLUE, {"speed": 1.15, "jump": 1.1}))
	drip_tier_items.append(CloutItem.new("Off-White Belt", "Deconstructed luxury", CloutItem.Rarity.DRIP, Color.LIGHT_BLUE, {"belt_damage": 1.25}))
	drip_tier_items.append(CloutItem.new("Bape Hoodie", "Japanese streetwear", CloutItem.Rarity.DRIP, Color.LIGHT_BLUE, {"damage": 1.15, "max_health": 1.1}))

	# -- GRAIL TIER --
	grail_tier_items.append(CloutItem.new("Rick Owens FuturePunk Vampire Suit", "Ultimate drip energy", CloutItem.Rarity.GRAIL, Color.YELLOW, {"damage": 1.2, "lifesteal": 0.1}))
	grail_tier_items.append(CloutItem.new("Chrome Hearts Jacket", "Precious metals and leather", CloutItem.Rarity.GRAIL, Color.YELLOW, {"damage": 1.3, "max_health": 1.2}))
	grail_tier_items.append(CloutItem.new("Balenciaga Speed Trainers", "Speed of light", CloutItem.Rarity.GRAIL, Color.YELLOW, {"speed": 1.4, "dodge": 1.1}))


func get_random_item(rarity: CloutItem.Rarity) -> CloutItem:
	"""Get a random item of the specified rarity."""
	match rarity:
		CloutItem.Rarity.MID:
			if mid_tier_items.is_empty():
				return null
			return mid_tier_items[randi() % mid_tier_items.size()]
		CloutItem.Rarity.DRIP:
			if drip_tier_items.is_empty():
				return null
			return drip_tier_items[randi() % drip_tier_items.size()]
		CloutItem.Rarity.GRAIL:
			if grail_tier_items.is_empty():
				return null
			return grail_tier_items[randi() % grail_tier_items.size()]
	return null


func get_random_item_any() -> CloutItem:
	"""Get a random item from any rarity tier."""
	var all_items: Array[CloutItem] = []
	all_items.append_array(mid_tier_items)
	all_items.append_array(drip_tier_items)
	all_items.append_array(grail_tier_items)

	if all_items.is_empty():
		return null
	return all_items[randi() % all_items.size()]
