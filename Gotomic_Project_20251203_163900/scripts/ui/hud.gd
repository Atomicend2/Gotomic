extends CanvasLayer

class_name HUD

signal pause_button_pressed
signal fire_button_state_changed(pressed: bool)
signal aim_button_state_changed(pressed: bool)
signal reload_button_state_changed(pressed: bool)
signal jump_button_state_changed(pressed: bool)
signal sprint_button_state_changed(pressed: bool)
signal crouch_button_state_changed(pressed: bool)
signal move_input_changed(direction: Vector2)
signal look_input_changed(delta: Vector2)

@onready var ammo_label: Label = $AmmoContainer/AmmoLabel
@onready var health_progress_bar: TextureProgressBar = $HealthContainer/HealthProgressBar
@onready var player_joystick_left: Control = $LeftJoystick
@onready var player_joystick_right: Control = $RightJoystick
@onready var fire_button: TouchScreenButton = $RightControls/FireButton
@onready var aim_button: TouchScreenButton = $RightControls/AimButton
@onready var reload_button: TouchScreenButton = $RightControls/ReloadButton
@onready var jump_button: TouchScreenButton = $RightControls/JumpButton
@onready var sprint_button: TouchScreenButton = $LeftControls/SprintButton
@onready var pause_button: TouchScreenButton = $TopControls/PauseButton

var _left_joystick_active: bool = false
var _right_joystick_active: bool = false
var _left_joystick_touch_idx: int = -1
var _right_joystick_touch_idx: int = -1
var _left_joystick_base_pos: Vector2 = Vector2.ZERO
var _right_joystick_base_pos: Vector2 = Vector2.ZERO

const JOYSTICK_RADIUS: float = 70.0 # Visual radius for joystick movement
const JOYSTICK_DEADZONE: float = 20.0 # Deadzone for input

func _ready() -> void:
	pause_button.pressed.connect(Callable(self, "_on_pause_button_pressed"))
	
	fire_button.pressed.connect(Callable(self, "_on_fire_button_pressed").bind(true))
	fire_button.released.connect(Callable(self, "_on_fire_button_pressed").bind(false))
	
	aim_button.pressed.connect(Callable(self, "_on_aim_button_pressed").bind(true))
	aim_button.released.connect(Callable(self, "_on_aim_button_pressed").bind(false))
	
	reload_button.pressed.connect(Callable(self, "_on_reload_button_pressed").bind(true))
	reload_button.released.connect(Callable(self, "_on_reload_button_pressed").bind(false))
	
	jump_button.pressed.connect(Callable(self, "_on_jump_button_pressed").bind(true))
	jump_button.released.connect(Callable(self, "_on_jump_button_pressed").bind(false))

	sprint_button.pressed.connect(Callable(self, "_on_sprint_button_pressed").bind(true))
	sprint_button.released.connect(Callable(self, "_on_sprint_button_pressed").bind(false))
	
	# Initial joystick positions for visual feedback
	_left_joystick_base_pos = player_joystick_left.global_position + player_joystick_left.size * 0.5
	_right_joystick_base_pos = player_joystick_right.global_position + player_joystick_right.size * 0.5

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if player_joystick_left.get_global_rect().has_point(event.position):
				_left_joystick_active = true
				_left_joystick_touch_idx = event.index
				_left_joystick_base_pos = event.position # Anchor joystick to touch start
				(player_joystick_left.get_child(0) as TextureRect).global_position = event.position - (player_joystick_left.get_child(0) as TextureRect).size * 0.5
				(player_joystick_left.get_child(1) as TextureRect).global_position = event.position - (player_joystick_left.get_child(1) as TextureRect).size * 0.5
			elif player_joystick_right.get_global_rect().has_point(event.position):
				_right_joystick_active = true
				_right_joystick_touch_idx = event.index
				_right_joystick_base_pos = event.position # Anchor joystick to touch start
				(player_joystick_right.get_child(0) as TextureRect).global_position = event.position - (player_joystick_right.get_child(0) as TextureRect).size * 0.5
				(player_joystick_right.get_child(1) as TextureRect).global_position = event.position - (player_joystick_right.get_child(1) as TextureRect).size * 0.5
		else:
			if event.index == _left_joystick_touch_idx:
				_left_joystick_active = false
				_left_joystick_touch_idx = -1
				_reset_joystick_visuals(player_joystick_left)
				move_input_changed.emit(Vector2.ZERO)
			elif event.index == _right_joystick_touch_idx:
				_right_joystick_active = false
				_right_joystick_touch_idx = -1
				_reset_joystick_visuals(player_joystick_right)
				look_input_changed.emit(Vector2.ZERO)
				
	elif event is InputEventScreenDrag:
		if event.index == _left_joystick_touch_idx and _left_joystick_active:
			_update_joystick(player_joystick_left, _left_joystick_base_pos, event.position, true)
		elif event.index == _right_joystick_touch_idx and _right_joystick_active:
			_update_joystick(player_joystick_right, _right_joystick_base_pos, event.position, false)

func _update_joystick(joystick_node: Control, base_pos: Vector2, current_pos: Vector2, is_move_joystick: bool) -> void:
	var offset: Vector2 = current_pos - base_pos
	var distance: float = offset.length()
	var clamped_offset: Vector2 = offset.normalized() * min(distance, JOYSTICK_RADIUS)

	# Update joystick knob visual position
	(joystick_node.get_child(1) as TextureRect).global_position = base_pos + clamped_offset - (joystick_node.get_child(1) as TextureRect).size * 0.5

	var normalized_input: Vector2 = clamped_offset / JOYSTICK_RADIUS
	if distance < JOYSTICK_DEADZONE:
		normalized_input = Vector2.ZERO # Apply deadzone

	if is_move_joystick:
		move_input_changed.emit(normalized_input)
	else:
		look_input_changed.emit(offset) # Emit raw offset for camera look

func _reset_joystick_visuals(joystick_node: Control) -> void:
	# Reset knob to center of base
	(joystick_node.get_child(1) as TextureRect).global_position = (joystick_node.get_child(0) as TextureRect).global_position + (joystick_node.get_child(0) as TextureRect).size * 0.5 - (joystick_node.get_child(1) as TextureRect).size * 0.5
	# Reset base to its original position (or make it appear/disappear on touch)
	# For now, it stays visible, so we just reset knob.

func update_ammo_display(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = "%d / %d" % [current_ammo, max_ammo]

func update_health_display(new_health: int, old_health: int) -> void:
	# Assuming max health is `health_progress_bar.max_value`
	health_progress_bar.value = new_health

func set_max_health_for_display(max_health_value: int) -> void:
	health_progress_bar.max_value = max_health_value
	health_progress_bar.value = max_health_value # Initialize

func _on_pause_button_pressed() -> void:
	pause_button_pressed.emit()

func _on_fire_button_pressed(pressed: bool) -> void:
	fire_button_state_changed.emit(pressed)

func _on_aim_button_pressed(pressed: bool) -> void:
	aim_button_state_changed.emit(pressed)

func _on_reload_button_pressed(pressed: bool) -> void:
	reload_button_state_changed.emit(pressed)

func _on_jump_button_pressed(pressed: bool) -> void:
	jump_button_state_changed.emit(pressed)

func _on_sprint_button_pressed(pressed: bool) -> void:
	sprint_button_state_changed.emit(pressed)

func _on_crouch_button_pressed(pressed: bool) -> void:
	crouch_button_state_changed.emit(pressed)

