class_name Boot
extends Node

func _ready() -> void:
	# Ensures GameManager is loaded and initialized first (as it's an autoload singleton)
	# Then transitions to the main menu.
	if GameManager.is_instance_valid(GameManager):
		print("Boot: GameManager initialized.")
		GameManager.return_to_main_menu() # Start at the main menu
	else:
		push_error("Boot: GameManager autoload not found!")
		get_tree().quit()