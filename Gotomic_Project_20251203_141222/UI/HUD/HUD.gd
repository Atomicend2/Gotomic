class_name HUD
extends Control

#region Exported Variables
@export var health_bar: ProgressBar
@export var ammo_label: Label
@export var weapon_name_label: Label
@export var crosshair_center: Control
@export var crosshair_left: Control
@export var crosshair_right: Control
@export var crosshair_up: Control
@export var crosshair_down: Control
@export var interact_prompt_label: Label
@export var flashlight_bar: ProgressBar

@export var mobile_joystick: Control
@export var mobile_fire_button: Button
@export var mobile_ads_button: Button
@export var mobile_reload_button: Button
@export var mobile_sprint_button: Button
@export var mobile_interact_button: Button
@export var mobile_flashlight_button: Button

@export var crosshair_min_spread: float = 10.0
@export var crosshair_max_spread: float = 50.0
@export var crosshair_spread_speed: float = 5.0
#endregion

#region Private Variables
var _player_node: CharacterBody3D
var _current_spread: float = 0.0
var _target_spread: float = 0.0
#endregion

func _ready() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.register_hud(self)
		GameManager.player_health_changed.connect(update_health_display)
		GameManager.ammo_changed.connect(update_ammo_display)
		GameManager.weapon_switched.connect(update_weapon_display)
		GameManager.flashlight_energy_changed.connect(update_flashlight_display)
		GameManager.player_interact_prompt.connect(update_interact_prompt)
	else:
		push_error("HUD: GameManager not found!")

	_setup_mobile_controls()
	update_interact_prompt(false, "") # Hide prompt initially

func _process(delta: float) -> void:
	_update_crosshair_spread(delta)

func _setup_mobile_controls() -> void:
	# Connect mobile buttons to input actions
	if is_instance_valid(mobile_fire_button):
		mobile_fire_button.pressed.connect(func(): Input.action_press("touch_fire"))
		mobile_fire_button.released.connect(func(): Input.action_release("touch_fire"))
	
	if is_instance_valid(mobile_ads_button):
		mobile_ads_button.pressed.connect(func(): Input.action_press("touch_ads"))
		mobile_ads_button.released.connect(func(): Input.action_release("touch_ads"))

	if is_instance_valid(mobile_reload_button):
		mobile_reload_button.pressed.connect(func(): Input.action_press("touch_reload"))
		mobile_reload_button.released.connect(func(): Input.action_release("touch_reload"))
		
	if is_instance_valid(mobile_sprint_button):
		mobile_sprint_button.pressed.connect(func(): Input.action_press("touch_sprint"))
		mobile_sprint_button.released.connect(func(): Input.action_release("touch_sprint"))
		
	if is_instance_valid(mobile_interact_button):
		mobile_interact_button.pressed.connect(func(): Input.action_press("touch_interact"))
		mobile_interact_button.released.connect(func(): Input.action_release("touch_interact"))
		
	if is_instance_valid(mobile_flashlight_button):
		mobile_flashlight_button.pressed.connect(func(): Input.action_press("toggle_flashlight"))
		mobile_flashlight_button.released.connect(func(): Input.action_release("toggle_flashlight"))

	# Placeholder for joystick logic - requires a custom script
	if is_instance_valid(mobile_joystick):
		pass # Actual joystick logic would be in a separate script or handled by Godot's Input.get_vector() if mapped.

func set_player(player: CharacterBody3D) -> void:
	_player_node = player

func update_health_display(new_health: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = new_health
		health_bar.max_value = GameManager.player_node.max_health # Assuming player_node is valid
		if new_health <= 20: # Example critical health threshold
			health_bar.get_theme_stylebox("fill").bg_color = Color("red")
		else:
			health_bar.get_theme_stylebox("fill").bg_color = Color("green")
	
func update_ammo_display(current_ammo_in_mag: int, total_reserve_ammo: int) -> void:
	if is_instance_valid(ammo_label):
		ammo_label.text = str(current_ammo_in_mag) + " / " + str(total_reserve_ammo)

func update_weapon_display(weapon_name: String, _current_ammo: int, _total_ammo: int) -> void:
	if is_instance_valid(weapon_name_label):
		weapon_name_label.text = weapon_name
	update_ammo_display(_current_ammo, _total_ammo) # Also update ammo when weapon switches

func update_flashlight_display(current_energy: float, max_energy: float) -> void:
	if is_instance_valid(flashlight_bar):
		flashlight_bar.value = current_energy
		flashlight_bar.max_value = max_energy
		flashlight_bar.visible = true # Show when flashlight is active

func update_interact_prompt(visible: bool, message: String) -> void:
	if is_instance_valid(interact_prompt_label):
		interact_prompt_label.visible = visible
		interact_prompt_label.text = message

func set_crosshair_spread(spread_factor: float) -> void: # 0.0 (min) to 1.0 (max)
	_target_spread = lerpf(crosshair_min_spread, crosshair_max_spread, spread_factor)

func _update_crosshair_spread(delta: float) -> void:
	_current_spread = lerpf(_current_spread, _target_spread, crosshair_spread_speed * delta)
	
	if is_instance_valid(crosshair_left):
		crosshair_left.position = Vector2(-_current_spread, 0)
	if is_instance_valid(crosshair_right):
		crosshair_right.position = Vector2(_current_spread, 0)
	if is_instance_valid(crosshair_up):
		crosshair_up.position = Vector2(0, -_current_spread)
	if is_instance_valid(crosshair_down):
		crosshair_down.position = Vector2(0, _current_spread)