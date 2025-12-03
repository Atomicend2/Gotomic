extends Node

# Global game state or utility functions
# For this prototype, it mainly holds signals and simple state.

signal player_health_changed(new_health: int)
signal player_ammo_changed(current_ammo: int, max_ammo: int)
signal enemy_defeated()
signal mission_objective_changed(objective_text: String)

var current_enemies_defeated: int = 0
var total_enemies_in_level: int = 0
var player_is_dead: bool = false

func reset_game_state() -> void:
	current_enemies_defeated = 0
	total_enemies_in_level = 0
	player_is_dead = false
	mission_objective_changed.emit("Eliminate all enemies.")
	player_health_changed.emit(100) # Reset player health display
	player_ammo_changed.emit(30, 30) # Reset player ammo display

func register_enemy() -> void:
	total_enemies_in_level += 1
	update_objective_text()

func enemy_was_defeated() -> void:
	current_enemies_defeated += 1
	enemy_defeated.emit() # Signal for the level to check win condition
	update_objective_text()

func update_objective_text() -> void:
	if total_enemies_in_level == 0:
		mission_objective_changed.emit("No enemies yet. Find them!")
	elif current_enemies_defeated >= total_enemies_in_level:
		mission_objective_changed.emit("Mission Complete! All enemies eliminated.")
	else:
		mission_objective_changed.emit("Eliminate enemies: %d/%d" % [current_enemies_defeated, total_enemies_in_level])

func game_over() -> void:
	player_is_dead = true
	mission_objective_changed.emit("MISSION FAILED: You were eliminated!")
	get_tree().paused = true # Pause game when player dies
	# You might want to show a game over screen here
	# For now, just a message and pause.
	print("GAME OVER - Player eliminated.")

func _ready() -> void:
	reset_game_state()
	print("Global script ready.")
