class_name GameManager
extends Node

# Autoloaded script for global game management.

signal game_started
signal game_ended
signal player_score_changed(new_score: int)

var current_score: int = 0:
	set(value):
		if current_score != value:
			current_score = value
			player_score_changed.emit(current_score)
			print("Score changed to: ", current_score)

func _ready() -> void:
	# Initialize game state or load data here.
	print("GameManager initialized.")
	game_started.emit()

func add_score(amount: int) -> void:
	# Adds a specified amount to the current score.
	current_score += amount

func reset_game_state() -> void:
	# Resets all relevant game state variables.
	current_score = 0
	print("Game state reset.")
	game_ended.emit()
	game_started.emit()