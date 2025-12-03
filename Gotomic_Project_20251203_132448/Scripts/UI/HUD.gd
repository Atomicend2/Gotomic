class_name HUD
extends CanvasLayer

## HUD
## Handles the display of player health, ammo, weapon name, and crosshair.
## Adheres to ALMIGHTY-1000 Protocol rules 85, 114, 115, 186, 187, 381-440, 955.

# Signals (Rule F25)
signal pause_button_pressed

# Constants (Rule F25)
const CROSSHAIR_MIN_OFFSET: float = 5.0 # Distance from center for crosshair lines
const CROSSHAIR_MAX_OFFSET: float = 20.0 # Max distance for spread
const CROSSHAIR_LINE_LENGTH: float = 15.0 # Length of the lines

# Cached nodes (Rule 316, 406, 724, 757)
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_counter: Label
var _stamina_bar: ProgressBar
var _crosshair: Control
var _crosshair_lines: Array[ColorRect]
var _player: Player
var _player_combat: PlayerCombat
var _player_movement: PlayerMovement

func _ready() -> void:
	# Get UI nodes (Rule 381, 406)
	_health_bar = get_node_or_null("Container/HealthBar")
	_health_label = get_node_or_null("Container/HealthBar/HealthLabel")
	_ammo_counter = get_node_or_null("Container/AmmoCounter")
	_stamina_bar = get_node_or_null("Container/StaminaBar")
	_crosshair = get_node_or_null("Container/Crosshair")

	_crosshair_lines = [
		get_node_or_null("Container/Crosshair/LineH1"),
		get_node_or_null("Container/Crosshair/LineH2"),
		get_node_or_null("Container/Crosshair/LineV1"),
		get_node_or_null("Container/Crosshair/LineV2")
	]

	# Null checks (Rule 701, 724, 757, 991)
	if not _health_bar or not _health_label or not _ammo_counter or not _stamina_bar or not _crosshair:
		push_error("HUD: Missing one or more critical UI nodes!")
		set_process(false)
		return

	for line in _crosshair_lines:
		if not line:
			push_warning("HUD: Missing one or more crosshair line nodes.")
			break # Continue with other HUD elements

	# Connect to GameManager signals (Rule 414, 675)
	if GameManager.is_instance_valid(GameManager): # Rule 791, 758
		GameManager.player_health_changed.connect(Callable(self, "_on_player_health_changed"))
		GameManager.weapon_switched.connect(Callable(self, "_on_weapon_switched"))
		GameManager.weapon_ammo_changed.connect(Callable(self, "_on_weapon_ammo_changed"))
	else:
		push_error("HUD: GameManager not found!")
		set_process(false)
		return

	# Connect to Player signals (Rule 744)
	# Player node might not be ready immediately, so defer connection
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player: # Rule 719, 756
		_player.player_health_updated.connect(Callable(self, "_on_player_health_changed"))
		_player.player_stamina_updated.connect(Callable(self, "_on_player_stamina_updated"))
		_player_combat = _player.get_node_or_null("PlayerCombat")
		_player_movement = _player.get_node_or_null("PlayerMovement")

		if not _player_combat: push_warning("HUD: PlayerCombat script not found on Player.")
		if not _player_movement: push_warning("HUD: PlayerMovement script not found on Player.")
	else:
		push_error("HUD: Player node not found in scene!")
		set_process(false)
		return

	_update_touch_controls_visibility()

func _process(delta: float) -> void: # Rule 424 (use signals, but crosshair spread is frame-dependent)
	_update_crosshair_display() # Rule 186, 187, 385

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause_game() # Rule 389, 417
		event.handled = true # Rule F07/F19 Enforcement

func _on_player_health_changed(new_health: int, max_health: int) -> void: # Rule 186, 386
	if is_instance_valid(_health_bar):
		_health_bar.max_value = max_health
		_health_bar.value = new_health
	if is_instance_valid(_health_label):
		_health_label.text = "HEALTH: %d/%d" % [new_health, max_health]

func _on_weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int) -> void: # Rule 186, 217, 387
	_update_ammo_display(weapon_name, current_ammo, max_ammo)

func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int) -> void: # Rule 186, 387
	if is_instance_valid(_player_combat) and is_instance_valid(_player_combat._current_weapon): # Rule 779
		_update_ammo_display(_player_combat._current_weapon.weapon_name, current_ammo, max_ammo)

func _update_ammo_display(weapon_name: String, current_ammo: int, max_ammo: int) -> void: # Rule 387
	if is_instance_valid(_ammo_counter):
		_ammo_counter.text = "%s: %d/%d" % [weapon_name.to_upper(), current_ammo, max_ammo]

func _on_player_stamina_updated(current_stamina: float, max_stamina: float) -> void: # Rule 823
	if is_instance_valid(_stamina_bar):
		_stamina_bar.max_value = max_stamina
		_stamina_bar.value = current_stamina

func _update_crosshair_display() -> void: # Rule 115, 384, 385, 997
	if not is_instance_valid(_crosshair) or not is_instance_valid(_player_combat): # Rule 762
		return

	var current_spread = _player_combat.get_crosshair_spread() # Rule 196
	var dynamic_offset = lerp(CROSSHAIR_MIN_OFFSET, CROSSHAIR_MAX_OFFSET, current_spread)

	if _player_combat.is_ads_active(): # Rule 222
		# Hide crosshair in ADS
		_crosshair.visible = false
		return
	else:
		_crosshair.visible = true

	# Update crosshair lines positions (Rule 385)
	if _crosshair_lines.size() >= 4:
		_crosshair_lines[0].offset_left = -CROSSHAIR_LINE_LENGTH - dynamic_offset
		_crosshair_lines[0].offset_right = -dynamic_offset
		_crosshair_lines[1].offset_left = dynamic_offset
		_crosshair_lines[1].offset_right = CROSSHAIR_LINE_LENGTH + dynamic_offset
		_crosshair_lines[2].offset_top = -CROSSHAIR_LINE_LENGTH - dynamic_offset
		_crosshair_lines[2].offset_bottom = -dynamic_offset
		_crosshair_lines[3].offset_top = dynamic_offset
		_crosshair_lines[3].offset_bottom = CROSSHAIR_LINE_LENGTH + dynamic_offset

func _update_touch_controls_visibility() -> void: # Rule 28, 399
	var touch_controls = get_node_or_null("Container/TouchControls")
	if touch_controls:
		if OS.has_touchscreen_ui_hint():
			touch_controls.show()
			print("HUD: Showing touch controls.")
		else:
			touch_controls.hide()
			print("HUD: Hiding touch controls (no touchscreen detected).")
	else:
		push_warning("HUD: TouchControls node not found.")