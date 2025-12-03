extends Node

## ResourceManager Autoload
## Manages the player's resource counts and provides methods for adding/removing resources.

signal resource_changed(resource_name: String, new_amount: int)

var resources: Dictionary = {
	"Scrap": 0,
	"Energy": 0
}

func _ready() -> void:
	# Initialize default resource amounts or load from save data
	_update_ui_for_all_resources()

## Adds a specified amount of a resource.
func add_resource(resource_name: String, amount: int) -> void:
	if resources.has(resource_name):
		resources[resource_name] += amount
		resource_changed.emit(resource_name, resources[resource_name])
		print("Added %d %s. Current: %d" % [amount, resource_name, resources[resource_name]])
	else:
		printerr("Attempted to add unknown resource: ", resource_name)

## Removes a specified amount of a resource.
## Returns true if resources were successfully removed, false otherwise (e.g., not enough resources).
func remove_resource(resource_name: String, amount: int) -> bool:
	if resources.has(resource_name):
		if resources[resource_name] >= amount:
			resources[resource_name] -= amount
			resource_changed.emit(resource_name, resources[resource_name])
			print("Removed %d %s. Current: %d" % [amount, resource_name, resources[resource_name]])
			return true
		else:
			print("Not enough %s to remove %d (Current: %d)" % [resource_name, amount, resources[resource_name]])
			return false
	else:
		printerr("Attempted to remove unknown resource: ", resource_name)
		return false

## Gets the current amount of a resource.
func get_resource_amount(resource_name: String) -> int:
	return resources.get(resource_name, 0)

## Emits signals for all resources to ensure UI is updated on load.
func _update_ui_for_all_resources() -> void:
	for resource_name in resources.keys():
		resource_changed.emit(resource_name, resources[resource_name])