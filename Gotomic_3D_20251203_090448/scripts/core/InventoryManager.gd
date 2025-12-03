extends Node

## InventoryManager Autoload
## Manages the player's inventory items. For this prototype, it's a simple list.

signal item_added(item_name: String, quantity: int)
signal item_removed(item_name: String, quantity: int)
signal inventory_updated

var inventory: Dictionary = {} # Stores item_name: quantity

## Adds an item to the inventory. If the item already exists, its quantity is increased.
func add_item(item_name: String, quantity: int = 1) -> void:
	if quantity <= 0:
		printerr("Cannot add non-positive quantity of item.")
		return

	inventory[item_name] = inventory.get(item_name, 0) + quantity
	item_added.emit(item_name, quantity)
	inventory_updated.emit()
	print("Added %d x %s. Inventory: %s" % [quantity, item_name, inventory])

## Removes an item from the inventory.
## Returns true if items were successfully removed, false otherwise (e.g., not enough items).
func remove_item(item_name: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		printerr("Cannot remove non-positive quantity of item.")
		return false

	if inventory.has(item_name) and inventory[item_name] >= quantity:
		inventory[item_name] -= quantity
		if inventory[item_name] <= 0:
			inventory.erase(item_name)
		item_removed.emit(item_name, quantity)
		inventory_updated.emit()
		print("Removed %d x %s. Inventory: %s" % [quantity, item_name, inventory])
		return true
	else:
		print("Not enough %s to remove %d (Current: %d)" % [item_name, quantity, inventory.get(item_name, 0)])
		return false

## Gets the quantity of a specific item in the inventory.
func get_item_quantity(item_name: String) -> int:
	return inventory.get(item_name, 0)

## Checks if the inventory contains a specific item (at least one).
func has_item(item_name: String) -> bool:
	return inventory.has(item_name) and inventory[item_name] > 0

## Returns the entire inventory dictionary.
func get_inventory_data() -> Dictionary:
	return inventory.duplicate()