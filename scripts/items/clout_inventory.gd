extends Node
class_name CloutInventory

## Manages the player's equipped clout items
## Tracks stat modifications from items

var max_slots: int = 3
var equipped_items: Array[CloutItem] = []

# -- Signals --
signal inventory_changed
signal item_equipped(item: CloutItem)
signal item_removed(item: CloutItem)


func _init(p_max_slots: int = 3) -> void:
	max_slots = p_max_slots
	equipped_items.clear()


func add_item(item: CloutItem) -> bool:
	"""Try to add an item to inventory. Returns true if successful."""
	if item == null:
		return false

	if equipped_items.size() >= max_slots:
		return false

	equipped_items.append(item)
	item_equipped.emit(item)
	inventory_changed.emit()
	print("[CloutInventory] Equipped %s (%s)" % [item.item_name, item.get_rarity_name()])
	return true


func remove_item(index: int) -> bool:
	"""Remove an item at the given index. Returns true if successful."""
	if index < 0 or index >= equipped_items.size():
		return false

	var item: CloutItem = equipped_items[index]
	equipped_items.remove_at(index)
	item_removed.emit(item)
	inventory_changed.emit()
	print("[CloutInventory] Removed %s" % item.item_name)
	return true


func get_stat_modifier(stat_name: String) -> float:
	"""Get the combined stat multiplier for a given stat."""
	var multiplier: float = 1.0

	for item: CloutItem in equipped_items:
		if item.stat_modifiers.has(stat_name):
			var item_mult: float = item.stat_modifiers[stat_name] as float
			multiplier *= item_mult

	return multiplier


func get_all_items() -> Array[CloutItem]:
	"""Return a copy of all equipped items."""
	return equipped_items.duplicate()


func clear_inventory() -> void:
	"""Remove all items from inventory."""
	equipped_items.clear()
	inventory_changed.emit()
