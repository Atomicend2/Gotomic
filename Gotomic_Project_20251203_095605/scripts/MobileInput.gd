extends Node

signal move_vector_changed(vector: Vector2)
signal jump_action_pressed
signal attack_action_pressed

var _move_vector: Vector2 = Vector2.ZERO
var _is_jump_active: bool = false
var _is_attack_active: bool = false

func get_move_vector() -> Vector2:
	return _move_vector

func set_move_vector(vector: Vector2) -> void:
	if _move_vector != vector:
		_move_vector = vector
		move_vector_changed.emit(_move_vector)

func is_jump_pressed() -> bool:
	var pressed_state: bool = _is_jump_active
	# Jump is a one-shot action, reset after queried
	_is_jump_active = false
	return pressed_state

func set_jump_pressed() -> void:
	_is_jump_active = true
	jump_action_pressed.emit()

func is_attack_pressed() -> bool:
	var pressed_state: bool = _is_attack_active
	# Attack might be continuous or one-shot, depending on game.
	# For this example, let's treat it as a one-shot until reset.
	# The PlayerController will reset it.
	return pressed_state

func set_attack_pressed(pressed: bool) -> void:
	_is_attack_active = pressed
	if pressed:
		attack_action_pressed.emit()

func reset_attack() -> void:
	_is_attack_active = false

func _input(event: InputEvent) -> void:
	# Consume input events from UI buttons to prevent them from propagating
	# This Autoload mostly acts as a state aggregator from the UI now.
	# If you want to enable raw touch screen input for other areas
	# without a button, this is where you'd add it.
	if event is InputEventScreenTouch and event.pressed:
		# Example: if touch is outside UI buttons, consider it for something else
		# For this project, all inputs are handled by TouchScreenButtons in HUD.
		pass