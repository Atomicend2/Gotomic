extends Control

class_name PauseMenu

signal resume_game
signal quit_game

func _ready() -> void:
	$Panel/VBoxContainer/ResumeButton.pressed.connect(Callable(self, "_on_resume_button_pressed"))
	$Panel/VBoxContainer/QuitButton.pressed.connect(Callable(self, "_on_quit_button_pressed"))
	hide()

func show_menu() -> void:
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func hide_menu() -> void:
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false

func _on_resume_button_pressed() -> void:
	resume_game.emit()
	hide_menu()

func _on_quit_button_pressed() -> void:
	quit_game.emit()
	get_tree().quit()

