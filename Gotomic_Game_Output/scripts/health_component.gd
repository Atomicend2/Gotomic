extends Node

## Reusable health component for game entities.

@export var max_health: int = 100:
	set(value):
		max_health = max(0, value)
		if current_health > max_health:
			current_health = max_health
		emit_signal("health_changed", current_health, max_health)

@export var current_health: int = 100:
	set(value):
		current_health = clampi(value, 0, max_health)
		emit_signal("health_changed", current_health, max_health)
		if current_health <= 0:
			emit_signal("died")

signal health_changed(new_health: int, max_health: int)
signal died

func _ready() -> void:
	# Ensure current_health is within bounds at start
	current_health = clampi(current_health, 0, max_health)
	emit_signal("health_changed", current_health, max_health)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	if current_health <= 0:
		return # Already dead
		
	current_health -= amount
	print("Took %s damage. Current Health: %s/%s" % [amount, current_health, max_health])

func heal(amount: int) -> void:
	if amount <= 0:
		return
		
	current_health += amount
	print("Healed %s. Current Health: %s/%s" % [amount, current_health, max_health])

func is_dead() -> bool:
	return current_health <= 0

func get_health_percentage() -> float:
	if max_health == 0:
		return 0.0
	return float(current_health) / max_health