extends Node

## Boot
## Initial scene script for loading core game components and transitioning to the main game world.
## Adheres to ALMIGHTY-1000 Protocol rules 48, 84, 909, 996.

# Signals (Rule F25)
signal boot_finished

# Constants (Rule F25)
const MAIN_MENU_SCENE_PATH: String = "res://Scenes/MainMenu.tscn" # Placeholder for a main menu
const GAME_WORLD_SCENE_PATH: String = "res://Scenes/GameWorld.tscn" # The main game level to load

func _ready() -> void: # Rule F34
	print("Boot: Starting game boot sequence...")
	# Ensure GameManager is ready (it's an autoload, so it should be) (Rule 791)
	if not GameManager.is_instance_valid(GameManager):
		push_error("Boot: GameManager autoload not found! Critical error.")
		get_tree().quit()
		return

	# Preload necessary assets (Rule 909, 996)
	# For this project, a lot of preloading is handled implicitly by PackedScene/ResourceLoader.
	# More complex projects might explicitly use ResourceLoader.load_threaded_request.

	# Simulate a short loading delay
	await get_tree().create_timer(0.5).timeout

	print("Boot: Preloading complete. Loading game world.")
	# Load the main game scene after initial setup
	GameManager.load_level(GAME_WORLD_SCENE_PATH) # Rule 48
	boot_finished.emit()
	print("Boot: Boot sequence finished.")

func _on_timer_timeout() -> void:
	# This timer is just a visual delay for the "LOADING..." screen.
	# The actual loading logic is handled in _ready.
	pass