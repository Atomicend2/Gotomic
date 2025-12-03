extends Control

const JOYSTICK_DEADZONE: float = 0.1
const CAM_SENSITIVITY: float = 0.002 # Adjust for mobile camera drag

@onready var _health_label: Label = $HealthLabel
@onready var _ammo_label: Label = $AmmoLabel
@onready var _objective_label: Label = $ObjectiveLabel
@onready var _move_joystick_base: Panel = $TouchscreenControls/MoveJoystickBase
@onready var _move_joystick_handle: Panel = $TouchscreenControls/MoveJoystickHandle
@onready var _fire_button: Button = $TouchscreenControls/FireButton
@onready var _jump_button: Button = $TouchscreenControls/JumpButton

var _move_touch_idx: int = -1
var _move_joystick_center: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.ZERO

var _camera_touch_idx: int = -1
var _camera_drag_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	Global.player_health_changed.connect(_on_player_health_changed)
	Global.player_ammo_changed.connect(_on_player_ammo_changed)
	Global.mission_objective_changed.connect(_on_mission_objective_changed)
	
	_move_joystick_center = _move_joystick_base.position + _move_joystick_base.size / 2.0
	_move_joystick_handle.position = _move_joystick_center - _move_joystick_handle.size / 2.0
	
	_on_player_health_changed(100) # Initial display
	_on_player_ammo_changed(30, 30) # Initial display
	_on_mission_objective_changed("Eliminate all enemies: 0/0") # Initial display

func _input(event: InputEvent) -> void:
	if Global.player_is_dead:
		return
		
	# Handle Move Joystick
	if event is InputEventScreenTouch:
		if event.pressed:
			if _move_joystick_base.get_rect().has_point(event.position):
				_move_touch_idx = event.index
				_move_joystick_center = event.position # Center joystick at touch point
				_move_joystick_base.position = _move_joystick_center - _move_joystick_base.size / 2.0
				_move_joystick_handle.position = _move_joystick_center - _move_joystick_handle.size / 2.0
			elif not _fire_button.get_rect().has_point(event.position) and \
				 not _jump_button.get_rect().has_point(event.position) and \
				 _camera_touch_idx == -1: # Only assign camera drag if not hitting buttons or joystick
				_camera_touch_idx = event.index
				_camera_drag_start_pos = event.position
		elif event.index == _move_touch_idx:
			_move_touch_idx = -1
			_move_direction = Vector2.ZERO
			_move_joystick_base.position = Vector2(50, 500) # Reset joystick position
			_move_joystick_center = _move_joystick_base.position + _move_joystick_base.size / 2.0
			_move_joystick_handle.position = _move_joystick_center - _move_joystick_handle.size / 2.0
		elif event.index == _camera_touch_idx:
			_camera_touch_idx = -1
	
	if event is InputEventScreenDrag:
		if event.index == _move_touch_idx:
			var handle_position: Vector2 = event.position
			var vec: Vector2 = handle_position - _move_joystick_center
			var dist: float = vec.length()
			var max_dist: float = _move_joystick_base.size.x / 2.0 - _move_joystick_handle.size.x / 2.0

			if dist > max_dist:
				vec = vec.normalized() * max_dist
			
			_move_direction = vec / max_dist
			if _move_direction.length() < JOYSTICK_DEADZONE:
				_move_direction = Vector2.ZERO
			
			_move_joystick_handle.position = _move_joystick_center + vec - _move_joystick_handle.size / 2.0
		
		elif event.index == _camera_touch_idx:
			var mouse_motion_event: InputEventMouseMotion = InputEventMouseMotion.new()
			mouse_motion_event.relative = event.relative
			Input.parse_input_event(mouse_motion_event)

func _physics_process(delta: float) -> void:
	if Global.player_is_dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Ensure cursor is visible for potential UI
		return

	# Map joystick direction to input actions
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")

	if _move_direction.y < -JOYSTICK_DEADZONE:
		Input.action_press("move_forward", abs(_move_direction.y))
	elif _move_direction.y > JOYSTICK_DEADZONE:
		Input.action_press("move_backward", abs(_move_direction.y))

	if _move_direction.x < -JOYSTICK_DEADZONE:
		Input.action_press("move_left", abs(_move_direction.x))
	elif _move_direction.x > JOYSTICK_DEADZONE:
		Input.action_press("move_right", abs(_move_direction.x))

	# For mobile, make sure the mouse mode is captured for camera rotation via drag
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_player_health_changed(new_health: int) -> void:
	_health_label.text = "HP: %d" % new_health

func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	_ammo_label.text = "Ammo: %d/%d" % [current_ammo, max_ammo]

func _on_mission_objective_changed(objective_text: String) -> void:
	_objective_label.text = objective_text

func _on_fire_button_pressed() -> void:
	Input.action_press("shoot")

func _on_fire_button_released() -> void:
	Input.action_release("shoot")

func _on_jump_button_pressed() -> void:
	Input.action_press("jump")
	# Immediately release to simulate a quick tap
	Input.action_release("jump")

