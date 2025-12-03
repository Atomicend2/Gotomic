class_name PauseMenu
extends CanvasLayer

## PauseMenu
## Manages the game's pause menu and settings.
## Adheres to ALMIGHTY-1000 Protocol rules 86, 113, 381-440, 970.

# Signals (Rule F25)
signal game_resumed
signal game_quit_to_main_menu

# Cached nodes (Rule 316, 406, 757, 991)
var _pause_menu_container: VBoxContainer
var _settings_menu_container: Control

var _sensitivity_slider: HSlider
var _sensitivity_value_label: Label
var _master_volume_slider: HSlider
var _master_volume_value_label: Label
var _sfx_volume_slider: HSlider
var _sfx_volume_value_label: Label
var _music_volume_slider: HSlider
var _music_volume_value_label: Label

func _ready() -> void: # Rule F34
	process_mode = CanvasLayer.PROCESS_MODE_ALWAYS # Ensure the pause menu is always processed (Rule 113)
	visible = false # Start hidden

	# Cache UI nodes (Rule 381, 406)
	_pause_menu_container = get_node_or_null("VBoxContainer")
	_settings_menu_container = get_node_or_null("SettingsMenu")

	if not _pause_menu_container or not _settings_menu_container:
		push_error("PauseMenu: Missing main UI containers!")
		set_process(false)
		return

	# Cache settings UI nodes (Rule 316, 406)
	_sensitivity_slider = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_Sensitivity/HSlider_Sensitivity")
	_sensitivity_value_label = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_Sensitivity/Label_SensitivityValue")
	_master_volume_slider = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_MasterVolume/HSlider_MasterVolume")
	_master_volume_value_label = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_MasterVolume/Label_MasterVolumeValue")
	_sfx_volume_slider = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_SFXVolume/HSlider_SFXVolume")
	_sfx_volume_value_label = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_SFXVolume/Label_SFXVolumeValue")
	_music_volume_slider = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_MusicVolume/HSlider_MusicVolume")
	_music_volume_value_label = get_node_or_null("SettingsMenu/VBoxContainer/HBoxContainer_MusicVolume/Label_MusicVolumeValue")

	# Connect to GameManager pause signal (Rule 683, 758, 991)
	if GameManager.is_instance_valid(GameManager):
		GameManager.game_paused.connect(Callable(self, "_on_game_paused_toggled"))
		GameManager.settings_changed.connect(Callable(self, "_on_game_manager_settings_changed"))
		_initialize_settings_ui() # Initialize sliders with current settings (Rule 391)
	else:
		push_error("PauseMenu: GameManager autoload not found!")
		set_process(false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_game_paused_toggled(not visible) # Toggle visibility based on current state (Rule 113)
		event.handled = true # Rule F07/F19 Enforcement

func _on_game_paused_toggled(paused: bool) -> void: # Rule 113, 417
	visible = paused
	_pause_menu_container.visible = paused
	_settings_menu_container.visible = false # Hide settings if main pause menu shown

	# Manage mouse cursor visibility (Rule 429)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)

func _initialize_settings_ui() -> void: # Rule 391, 418
	if not GameManager.is_instance_valid(GameManager): return

	if is_instance_valid(_sensitivity_slider) and is_instance_valid(_sensitivity_value_label):
		_sensitivity_slider.value = GameManager.mouse_sensitivity
		_sensitivity_value_label.text = "%.2f" % GameManager.mouse_sensitivity
	if is_instance_valid(_master_volume_slider) and is_instance_valid(_master_volume_value_label):
		_master_volume_slider.value = GameManager.master_volume
		_master_volume_value_label.text = "%d%%" % (GameManager.master_volume * 100)
	if is_instance_valid(_sfx_volume_slider) and is_instance_valid(_sfx_volume_value_label):
		_sfx_volume_slider.value = GameManager.sfx_volume
		_sfx_volume_value_label.text = "%d%%" % (GameManager.sfx_volume * 100)
	if is_instance_valid(_music_volume_slider) and is_instance_valid(_music_volume_value_label):
		_music_volume_slider.value = GameManager.music_volume
		_music_volume_value_label.text = "%d%%" % (GameManager.music_volume * 100)

func _on_game_manager_settings_changed() -> void: # Rule 418
	# Update UI elements if settings change from another source (e.g., loaded save)
	_initialize_settings_ui()

# Button signal handlers (Rule 392, 428)
func _on_btn_resume_pressed() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.toggle_pause_game() # Will hide this menu via _on_game_paused_toggled
		game_resumed.emit()

func _on_btn_settings_pressed() -> void:
	_pause_menu_container.visible = false
	_settings_menu_container.visible = true
	_initialize_settings_ui() # Ensure settings UI is up-to-date

func _on_btn_quit_pressed() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.save_game() # Save game before quitting (Rule 558)
		GameManager.toggle_pause_game() # Unpause to allow scene transition
		game_quit_to_main_menu.emit()
		get_tree().change_scene_to_file("res://Scenes/Boot.tscn") # Go back to boot or main menu

func _on_btn_back_pressed() -> void:
	_settings_menu_container.visible = false
	_pause_menu_container.visible = true
	if GameManager.is_instance_valid(GameManager):
		GameManager.save_game() # Save settings when returning from settings menu

# Settings slider handlers (Rule 391)
func _on_h_slider_sensitivity_value_changed(value: float) -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.set_mouse_sensitivity(value)
	if is_instance_valid(_sensitivity_value_label):
		_sensitivity_value_label.text = "%.2f" % value

func _on_h_slider_master_volume_value_changed(value: float) -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.set_master_volume(value)
	if is_instance_valid(_master_volume_value_label):
		_master_volume_value_label.text = "%d%%" % (value * 100)

func _on_h_slider_sfx_volume_value_changed(value: float) -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.set_sfx_volume(value)
	if is_instance_valid(_sfx_volume_value_label):
		_sfx_volume_value_label.text = "%d%%" % (value * 100)

func _on_h_slider_music_volume_value_changed(value: float) -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.set_music_volume(value)
	if is_instance_valid(_music_volume_value_label):
		_music_volume_value_label.text = "%d%%" % (value * 100)