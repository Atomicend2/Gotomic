extends Node

class_name HealthComponent

signal died
signal health_changed(new_health: int, old_health: int)

@export var max_health: int = 100:
	set(value):
		max_health = max(0, value)
		_health = min(_health, max_health)
@export var _health: int = 100:
	set(value):
		var old_health: int = _health
		_health = clampi(value, 0, max_health)
		if _health != old_health:
			health_changed.emit(_health, old_health)
		if _health <= 0 and old_health > 0:
			died.emit()

func _ready() -> void:
	_health = max_health

func take_damage(amount: int) -> void:
	if is_dead():
		return
	_health -= amount
	print("Took damage: ", amount, ", Current health: ", _health)

func heal(amount: int) -> void:
	if is_dead():
		return
	_health += amount
	print("Healed: ", amount, ", Current health: ", _health)

func is_dead() -> bool:
	return _health <= 0

func get_health_percentage() -> float:
	return float(_health) / max_health

