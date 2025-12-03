class_name MainMenu
extends Control

#region Exported Variables
@export var new_game_button: Button
@export var load_game_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var settings_panel: Control
@export var main_panel: Control

@export var master_volume_slider: HSlider
@export var sfx_volume_slider: HSlider
@export var music_volume_slider: HSlider
@export var mouse_sensitivity_slider: HSlider
#endregion

#region Private Variables
var _is_settings_visible: bool = false
#endregion

func _ready() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.game_state = 0 # Ensure GameManager knows we are in MainMenu
		
		# Connect button signals
		if is_instance_valid(new_game_button):
			new_game_button.pressed.connect(GameManager.start_new_game)
		if is_instance_valid(load_game_button):
			load_game_button.pressed.connect(GameManager.load_game)
		if is_instance_valid(settings_button):
			settings_button.pressed.connect(Callable(self, "_toggle_settings"))
		if is_instance_valid(quit_button):
			quit_button.pressed.connect(GameManager.quit_game)
		
		# Connect slider signals
		if is_instance_valid(master_volume_slider):
			master_volume_slider.value_changed.connect(GameManager.set_master_volume)
		if is_instance_valid(sfx_volume_slider):
			sfx_volume_slider.value_changed.connect(GameManager.set_sfx_volume)
		if is_instance_valid(music_volume_slider):
			music_volume_slider.value_changed.connect(GameManager.set_music_volume)
		if is_instance_valid(mouse_sensitivity_slider):
			mouse_sensitivity_slider.value_changed.connect(GameManager.set_mouse_sensitivity)

		_show_main_panel()
		_load_current_settings_to_ui()
	else:
		push_error("MainMenu: GameManager not found!")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Ensure cursor is visible in menu

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