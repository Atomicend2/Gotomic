extends Node

## GameManager Autoload
## Manages global game state, score, and game over conditions.

signal player_died
signal game_over
signal game_started

var score: int = 0
var game_active: bool = false
var player_is_alive: bool = true

func _ready() -> void:
	# Connect to player_died signal from external sources if needed
	# For this prototype, we'll assume player_died is emitted directly or via PlayerController.
	pass

## Called to start a new game.
func start_game() -> void:
	score = 0
	player_is_alive = true
	game_active = true
	game_started.emit()
	print("Game Started!")

## Called when the player's health reaches zero.
func on_player_death() -> void:
	if player_is_alive:
		player_is_alive = false
		game_active = false
		player_died.emit()
		game_over.emit() # For a simple game, player death is game over
		print("Player Died! Game Over.")
		# Additional logic for game over screen, restart, etc.

## Adds points to the player's score.
func add_score(amount: int) -> void:
	if game_active:
		score += amount
		print("Score: ", score)