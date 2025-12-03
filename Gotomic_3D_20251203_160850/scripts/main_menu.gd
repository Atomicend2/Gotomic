extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Reset game state when returning to main menu
	Global.reset_game_state()
	get_tree().paused = false # Ensure game is not paused if returning from a paused game state

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

