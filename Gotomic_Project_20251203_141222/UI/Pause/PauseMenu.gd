class_name PauseMenu
extends Control

#region Exported Variables
@export var resume_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var master_volume_slider: HSlider
@export var sfx_volume_slider: HSlider
@export var music_volume_slider: HSlider
@export var mouse_sensitivity_slider: HSlider
@export var settings_panel: Control
@export var main_panel: Control
#endregion

#region Private Variables
var _is_settings_visible: bool = false
#endregion

func _ready() -> void:
	hide() # Start hidden
	
	if GameManager.is_instance_valid(GameManager):
		GameManager.game_paused.connect(Callable(self, "_on_game_paused_state_changed"))
		
		# Connect button signals
		if is_instance_valid(resume_button):
			resume_button.pressed.connect(Callable(self, "resume_game"))
		if is_instance_valid(settings_button):
			settings_button.pressed.connect(Callable(self, "_toggle_settings"))
		if is_instance_valid(quit_button):
			quit_button.pressed.connect(Callable(self, "return_to_main_menu"))
		
		# Connect slider signals
		if is_instance_valid(master_volume_slider):
			master_volume_slider.value_changed.connect(GameManager.set_master_volume)
		if is_instance_valid(sfx_volume_slider):
			sfx_volume_slider.value_changed.connect(GameManager.set_sfx_volume)
		if is_instance_valid(music_volume_slider):
			music_volume_slider.value_changed.connect(GameManager.set_music_volume)
		if is_instance_valid(mouse_sensitivity_slider):
			mouse_sensitivity_slider.value_changed.connect(GameManager.set_mouse_sensitivity)
			
		_load_current_settings_to_ui()
	else:
		push_error("PauseMenu: GameManager not found!")

func _input(event: InputEvent) -> void:
	if GameManager.is_instance_valid(GameManager) and event.is_action_pressed("pause"):
		if visible:
			if _is_settings_visible:
				_toggle_settings() # Close settings first
			else:
				resume_game()
		else:
			pause_game()
		event.handled = true # Rule F07/F19 Enforcement

func pause_game() -> void:
	if not GameManager.is_game_paused:
		GameManager.is_game_paused = true
		show()
		_show_main_panel()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game() -> void:
	if GameManager.is_game_paused:
		GameManager.is_game_paused = false
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func return_to_main_menu() -> void:
	resume_game() # Unpause before returning
	GameManager.return_to_main_menu()

func _toggle_settings() -> void:
	_is_settings_visible = not _is_settings_visible
	if is_instance_valid(main_panel):
		main_panel.visible = not _is_settings_visible
	if is_instance_valid(settings_panel):
		settings_panel.visible = _is_settings_visible
	
	if _is_settings_visible:
		_load_current_settings_to_ui()

func _load_current_settings_to_ui() -> void:
	if GameManager.is_instance_valid(GameManager):
		if is_instance_valid(master_volume_slider):
			master_volume_slider.value = GameManager.master_volume
		if is_instance_valid(sfx_volume_slider):
			sfx_volume_slider.value = GameManager.sfx_volume
		if is_instance_valid(music_volume_slider):
			music_volume_slider.value = GameManager.music_volume
		if is_instance_valid(mouse_sensitivity_slider):
			mouse_sensitivity_slider.value = GameManager.mouse_sensitivity

func _show_main_panel() -> void:
	_is_settings_visible = false
	if is_instance_valid(main_panel):
		main_panel.visible = true
	if is_instance_valid(settings_panel):
		settings_panel.visible = false

func _on_game_paused_state_changed(paused: bool) -> void:
	if paused and get_parent() == get_tree().current_scene: # Only show if in GameWorld scene
		show()
		_show_main_panel()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)