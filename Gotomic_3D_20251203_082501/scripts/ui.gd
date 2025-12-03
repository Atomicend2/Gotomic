class_name UI
extends CanvasLayer

signal movement_input(direction: Vector2)
signal camera_input(delta: Vector2)
signal jump_pressed

@onready var jump_button = $JumpButton
@onready var movement_area = $MovementArea
@onready var movement_touch_base = $MovementArea/MovementTouchBase
@onready var movement_touch_stick = $MovementArea/MovementTouchStick

var _movement_touch_idx: int = -1
var _movement_start_pos: Vector2 = Vector2.ZERO
var _camera_touch_idx: int = -1
var _camera_start_pos: Vector2 = Vector2.ZERO

func _ready():
	jump_button.pressed.connect(func(): jump_pressed.emit())
	movement_touch_base.hide()
	movement_touch_stick.hide()

func _input(event: InputEvent):
	if event is InputEventScreenTouch:
		_handle_touch_input(event)
	elif event is InputEventScreenDrag:
		_handle_drag_input(event)

func _handle_touch_input(event: InputEventScreenTouch):
	# Left half of screen for movement, right half for camera
	var is_left_half = event.position.x < get_viewport().size.x / 2.0
	
	if event.pressed:
		if is_left_half and _movement_touch_idx == -1:
			_movement_touch_idx = event.index
			_movement_start_pos = event.position
			
			movement_touch_base.global_position = _movement_start_pos - movement_touch_base.size / 2.0
			movement_touch_stick.global_position = _movement_start_pos - movement_touch_stick.size / 2.0
			movement_touch_base.show()
			movement_touch_stick.show()
			
		elif not is_left_half and _camera_touch_idx == -1:
			_camera_touch_idx = event.index
			_camera_start_pos = event.position
			
	else: # Released
		if event.index == _movement_touch_idx:
			_movement_touch_idx = -1
			_movement_start_pos = Vector2.ZERO
			movement_input.emit(Vector2.ZERO) # Stop movement
			movement_touch_base.hide()
			movement_touch_stick.hide()
			
		elif event.index == _camera_touch_idx:
			_camera_touch_idx = -1
			_camera_start_pos = Vector2.ZERO
			camera_input.emit(Vector2.ZERO) # Stop camera rotation (not really needed for instantaneous input, but good for consistency)

func _handle_drag_input(event: InputEventScreenDrag):
	if event.index == _movement_touch_idx:
		var current_pos = event.position
		var delta_pos = current_pos - _movement_start_pos
		var direction = delta_pos.normalized()
		
		# Move the virtual stick within the base's radius
		var max_radius = movement_touch_base.size.x / 2.0 - movement_touch_stick.size.x / 2.0
		var stick_offset = delta_pos.limit_length(max_radius)
		movement_touch_stick.global_position = _movement_start_pos + stick_offset - movement_touch_stick.size / 2.0
		
		# Emit movement direction (X for right/left, Y for forward/backward)
		movement_input.emit(Vector2(direction.x, direction.y))
		event.handled = true
		
	elif event.index == _camera_touch_idx:
		var camera_delta = event.relative
		camera_input.emit(camera_delta)
		event.handled = true